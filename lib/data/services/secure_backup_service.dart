import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart';

import 'backup_service.dart';
import 'public_folder.dart';

/// 加密自动备份（写到公共目录，卸载/清数据都还在）。
///
/// 三个要求：
/// 1. **公共目录**：备份落在 /storage/emulated/0/ 下用户授权的文件夹里，
///    不再是应用私有目录（私有目录一卸载就没了）；
/// 2. **加密**：AES-256-GCM，文件被拷走也读不出内容；
/// 3. **先拿权限**：Android 10+ 必须由用户用系统选择器授权文件夹（SAF），
///    这里只处理已授权的 URI，权限失效会明确报错让用户重新授权。
///
/// 密钥 = PBKDF2-HMAC-SHA256(密码, 固定盐, 12 万次, 32 字节)。
/// 盐是固定的，所以**换手机 / 重装 App 后输入同一个密码就能解开旧备份**。
/// 派生出的密钥存在设置文件里（应用沙箱），密码本身不落盘。
class SecureBackupService {
  SecureBackupService._();

  static final SecureBackupService instance = SecureBackupService._();

  /// 文件头：'PWBK' + 版本 1
  static const List<int> _magic = <int>[0x50, 0x57, 0x42, 0x4B, 0x01];

  /// 固定盐（跨设备/跨重装可复现同一把密钥）
  static const String _salt = 'piecework.secure.backup.v1';

  static const int _iterations = 120000;
  static const int _keyLength = 32;

  /// 公共目录里最多留几份
  static const int keepCount = 10;

  static const String filePrefix = 'piecework_backup_';
  static const String fileExt = '.pwb';

  File? _configFile;
  File? _promptFlagFile;

  /// 「还没开启备份」的提示是否已经弹过（只弹一次，别烦人）
  Future<bool> promptSeen() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      _promptFlagFile ??= File(p.join(docs.path, 'backup_prompt_seen'));
      return await _promptFlagFile!.exists();
    } catch (_) {
      return true;
    }
  }

  Future<void> markPromptSeen() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      _promptFlagFile ??= File(p.join(docs.path, 'backup_prompt_seen'));
      await _promptFlagFile!.writeAsString('1', flush: true);
    } catch (_) {}
  }

  Future<File> _cfg() async {
    if (_configFile != null) return _configFile!;
    final docs = await getApplicationDocumentsDirectory();
    return _configFile = File(p.join(docs.path, 'secure_backup.json'));
  }

  Future<SecureBackupConfig> load() async {
    try {
      final f = await _cfg();
      if (!await f.exists()) return SecureBackupConfig.empty();
      final raw = jsonDecode(await f.readAsString());
      if (raw is! Map) return SecureBackupConfig.empty();
      return SecureBackupConfig.fromJson(raw.cast<String, dynamic>());
    } catch (_) {
      return SecureBackupConfig.empty();
    }
  }

  Future<void> save(SecureBackupConfig cfg) async {
    final f = await _cfg();
    await f.writeAsString(jsonEncode(cfg.toJson()), flush: true);
  }

  /// 设置/修改备份密码：只存派生出来的密钥，密码不落盘
  Future<void> setPassword(String password) async {
    final cfg = await load();
    cfg.keyB64 = base64Encode(deriveKey(password));
    await save(cfg);
  }

  Future<void> clearPassword() async {
    final cfg = await load();
    cfg.keyB64 = '';
    await save(cfg);
  }

  // ───────────────────────── 加密 ─────────────────────────

  /// PBKDF2-HMAC-SHA256 派生 32 字节密钥
  static Uint8List deriveKey(String password) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(
        Uint8List.fromList(utf8.encode(_salt)),
        _iterations,
        _keyLength,
      ));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  static Uint8List _randomBytes(int n) {
    final rnd = Random.secure();
    final out = Uint8List(n);
    for (var i = 0; i < n; i++) {
      out[i] = rnd.nextInt(256);
    }
    return out;
  }

  /// AES-256-GCM 加密；输出 = 魔数 + nonce(12) + 密文 + tag(16)
  static Uint8List encryptBytes(Uint8List plain, Uint8List key) {
    final nonce = _randomBytes(12);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)));
    final sealed = cipher.process(plain);

    final out = BytesBuilder(copy: false)
      ..add(_magic)
      ..add(nonce)
      ..add(sealed);
    return out.takeBytes();
  }

  /// 解密；密码不对会抛 [FormatException]（GCM 校验失败）
  static Uint8List decryptBytes(Uint8List blob, Uint8List key) {
    if (blob.length < _magic.length + 12 + 16) {
      throw const FormatException('文件太短，不是有效的加密备份');
    }
    for (var i = 0; i < _magic.length; i++) {
      if (blob[i] != _magic[i]) {
        throw const FormatException('不是本 App 的加密备份（文件头不对）');
      }
    }
    final nonce = Uint8List.sublistView(blob, _magic.length, _magic.length + 12);
    final sealed = Uint8List.sublistView(blob, _magic.length + 12);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)));
    try {
      return cipher.process(sealed);
    } catch (_) {
      throw const FormatException('解密失败：密码不对，或文件被改过');
    }
  }

  // ───────────────────────── 自动备份 ─────────────────────────

  static String stampName([DateTime? at]) {
    final t = at ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '$filePrefix${t.year}${two(t.month)}${two(t.day)}'
        '_${two(t.hour)}${two(t.minute)}${two(t.second)}$fileExt';
  }

  /// 把一份备份 zip 加密写进公共目录；没配好就返回 null（静默跳过）
  Future<String?> runAuto(Uint8List zipBytes) async {
    final cfg = await load();
    if (!cfg.ready) return null;
    if (!await PublicFolder.hasPermission(cfg.folderUri)) {
      throw const FormatException('备份文件夹的授权已失效，请到设置里重新选择文件夹');
    }
    final key = base64Decode(cfg.keyB64);
    final enc = encryptBytes(zipBytes, Uint8List.fromList(key));
    final name = stampName();
    await PublicFolder.write(cfg.folderUri, name, enc);

    cfg.lastMs = DateTime.now().millisecondsSinceEpoch;
    cfg.lastName = name;
    await save(cfg);

    await _prune(cfg.folderUri);
    return name;
  }

  Future<void> _prune(String folderUri) async {
    try {
      final files = await listBackups();
      if (files.length <= keepCount) return;
      final sorted = files.toList()
        ..sort((a, b) => b.name.compareTo(a.name)); // 名字带时间戳，倒序=最新在前
      for (final f in sorted.skip(keepCount)) {
        await PublicFolder.delete(folderUri, f.name);
      }
    } catch (_) {
      // 清理失败不影响本次备份
    }
  }

  Future<List<FolderFile>> listBackups() async {
    final cfg = await load();
    if (cfg.folderUri.isEmpty) return const <FolderFile>[];
    final files = await PublicFolder.list(cfg.folderUri, prefix: filePrefix);
    files.sort((a, b) => b.name.compareTo(a.name));
    return files;
  }

  /// 读一份加密备份并解密成备份 zip 字节
  Future<Uint8List> readDecrypted(String name, String password) async {
    final cfg = await load();
    if (cfg.folderUri.isEmpty) {
      throw const FormatException('还没选择备份文件夹');
    }
    final blob = await PublicFolder.read(cfg.folderUri, name);
    if (blob.isEmpty) throw FormatException('读不到文件：$name');
    final key = deriveKey(password);
    return decryptBytes(blob, key);
  }

  /// 用当前已保存的密钥直接恢复（不用再输密码）
  Future<Uint8List> readDecryptedWithSavedKey(String name) async {
    final cfg = await load();
    if (cfg.folderUri.isEmpty) throw const FormatException('还没选择备份文件夹');
    if (cfg.keyB64.isEmpty) throw const FormatException('还没设置备份密码');
    final blob = await PublicFolder.read(cfg.folderUri, name);
    if (blob.isEmpty) throw FormatException('读不到文件：$name');
    return decryptBytes(blob, Uint8List.fromList(base64Decode(cfg.keyB64)));
  }

  /// 用已保存的密钥加密（给云备份上传用，不落本地）
  Future<Uint8List> encryptWithSavedKey(Uint8List zipBytes) async {
    final cfg = await load();
    if (cfg.keyB64.isEmpty) throw const FormatException('还没设置备份密码');
    return encryptBytes(
      zipBytes,
      Uint8List.fromList(base64Decode(cfg.keyB64)),
    );
  }

  /// 从「云端下载回来的加密字节」恢复整个库
  Future<RestoreReport> restoreFromBytes(Uint8List blob) async {
    final cfg = await load();
    if (cfg.keyB64.isEmpty) throw const FormatException('还没设置备份密码');
    final zip =
        decryptBytes(blob, Uint8List.fromList(base64Decode(cfg.keyB64)));
    final isar = _isar;
    if (isar == null) throw StateError('数据库还没就绪');
    return BackupService(isar).restore(zip);
  }

  /// 从一份加密备份恢复整个库
  Future<RestoreReport> restore(String name, {String? password}) async {
    final Uint8List zip;
    if (password != null && password.isNotEmpty) {
      zip = await readDecrypted(name, password);
    } else {
      zip = await readDecryptedWithSavedKey(name);
    }
    final isar = _isar;
    if (isar == null) throw StateError('数据库还没就绪');
    return BackupService(isar).restore(zip);
  }

  Isar? _isar;

  /// 由 main() 在启动时注入
  void attach(Isar isar) => _isar = isar;
}

/// 加密备份配置（存 `AppDocuments/secure_backup.json`）
class SecureBackupConfig {
  SecureBackupConfig({
    this.folderUri = '',
    this.folderLabel = '',
    this.keyB64 = '',
    this.lastMs = 0,
    this.lastName = '',
  });

  factory SecureBackupConfig.empty() => SecureBackupConfig();

  /// 用户授权过的公共目录（SAF tree URI）
  String folderUri;

  /// 给人看的目录名
  String folderLabel;

  /// PBKDF2 派生的密钥（base64）
  String keyB64;

  /// 最近一次成功备份的时间
  int lastMs;

  /// 最近一次备份的文件名
  String lastName;

  bool get folderReady => folderUri.isNotEmpty;
  bool get hasPassword => keyB64.isNotEmpty;
  bool get ready => folderReady && hasPassword;

  DateTime? get lastAt =>
      lastMs == 0 ? null : DateTime.fromMillisecondsSinceEpoch(lastMs);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'folderUri': folderUri,
        'folderLabel': folderLabel,
        'keyB64': keyB64,
        'lastMs': lastMs,
        'lastName': lastName,
      };

  static SecureBackupConfig fromJson(Map<String, dynamic> m) => SecureBackupConfig(
        folderUri: (m['folderUri'] as String?) ?? '',
        folderLabel: (m['folderLabel'] as String?) ?? '',
        keyB64: (m['keyB64'] as String?) ?? '',
        lastMs: (m['lastMs'] as num?)?.toInt() ?? 0,
        lastName: (m['lastName'] as String?) ?? '',
      );
}
