import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:isar_community/isar.dart';
import 'package:pointycastle/export.dart';

import 'backup_service.dart';

/// 免设置的自动备份：**不需要用户做任何配置**。
///
/// * 落点：`下载/Piecework/`（公共目录，卸载重装也还在）
/// * 加密：AES-256-GCM，密钥由 Android ID 派生（同一台机器重装能解开，
///   换机器/别人拿到文件也解不开）
/// * 频率：数据一变就防抖备份；保留最近 [keepCount] 份
///
/// 用户就算完全不去设置备份，也不怕误删/重装丢数据。
class DeviceBackupService {
  DeviceBackupService._();

  static final DeviceBackupService instance = DeviceBackupService._();

  static const MethodChannel _ch = MethodChannel('piecework/public_storage');
  static const String prefix = 'piecework_auto_';
  static const String ext = '.pwb';
  static const int keepCount = 5;

  /// 文件头：PWBK v1（与加密备份一致，便于人工识别）
  static const List<int> _magic = <int>[0x50, 0x57, 0x42, 0x4B, 0x01];
  static const String _salt = 'piecework.device.backup.v1';
  static const int _iterations = 60000;

  String? _androidId;

  Future<String> _deviceId() async {
    if (_androidId != null) return _androidId!;
    try {
      final id = await _ch.invokeMethod<String>('deviceId');
      _androidId = (id == null || id.isEmpty) ? 'unknown' : id;
    } catch (_) {
      _androidId = 'unknown';
    }
    return _androidId!;
  }

  Future<Uint8List> _key() async {
    final id = await _deviceId();
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(
        Uint8List.fromList(utf8.encode(_salt)),
        _iterations,
        32,
      ));
    return derivator.process(Uint8List.fromList(utf8.encode(id)));
  }

  /// 加密（测试也走它）
  Future<Uint8List> encryptBytes(Uint8List plain) async {
    final key = await _key();
    final iv = Uint8List.fromList(
      List<int>.generate(12, (_) => Random.secure().nextInt(256)),
    );
    final gcm = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)),
      );
    final enc = gcm.process(plain);
    return Uint8List.fromList(<int>[..._magic, ...iv, ...enc]);
  }

  /// 解密（测试也走它）
  Future<Uint8List> decryptBytes(Uint8List blob) async {
    if (blob.length < 20) throw const FormatException('备份文件不完整');
    for (var i = 0; i < _magic.length; i++) {
      if (blob[i] != _magic[i]) throw const FormatException('不是本 App 的备份');
    }
    final iv = blob.sublist(_magic.length, _magic.length + 12);
    final body = blob.sublist(_magic.length + 12);
    final key = await _key();
    final gcm = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
    return gcm.process(body);
  }

  String _stampName(DateTime t) =>
      '$prefix${t.year}${_2(t.month)}${_2(t.day)}_'
      '${_2(t.hour)}${_2(t.minute)}${_2(t.second)}$ext';

  String _2(int v) => v.toString().padLeft(2, '0');

  /// 做一次免设置备份，返回文件名（失败返回 null，不打扰用户）
  Future<String?> run(Isar isar) async {
    try {
      final zip = await BackupService(isar).createBackup();
      final enc = await encryptBytes(zip);
      final name = _stampName(DateTime.now());
      await _ch.invokeMethod<String>('writeBackup', <String, dynamic>{
        'name': name,
        'bytes': enc,
      });
      await _prune();
      return name;
    } catch (_) {
      return null;
    }
  }

  Future<void> _prune() async {
    try {
      final files = await list();
      final auto = files.where((f) => f.name.startsWith(prefix)).toList()
        ..sort((a, b) => b.modified.compareTo(a.modified));
      for (final f in auto.skip(keepCount)) {
        await _ch.invokeMethod<dynamic>('deleteBackup', <String, dynamic>{
          'name': f.name,
        });
      }
    } catch (_) {}
  }

  /// 公共目录里的备份列表（最近的在前）
  Future<List<DeviceBackupFile>> list() async {
    try {
      final raw = await _ch.invokeMethod<List<dynamic>>('listBackups');
      final out = <DeviceBackupFile>[];
      for (final e in raw ?? const <dynamic>[]) {
        if (e is! Map) continue;
        final name = '${e['name'] ?? ''}';
        if (!name.endsWith(ext)) continue;
        out.add(
          DeviceBackupFile(
            name: name,
            size: (e['size'] as num?)?.toInt() ?? 0,
            modified: DateTime.fromMillisecondsSinceEpoch(
              (e['modified'] as num?)?.toInt() ?? 0,
            ),
          ),
        );
      }
      out.sort((a, b) => b.modified.compareTo(a.modified));
      return out;
    } catch (_) {
      return const <DeviceBackupFile>[];
    }
  }

  /// 从公共目录恢复某一份备份
  Future<RestoreReport> restore(Isar isar, String name) async {
    final raw = await _ch.invokeMethod<Uint8List>('readBackup', <String, dynamic>{
      'name': name,
    });
    if (raw == null || raw.isEmpty) {
      throw const FormatException('读不到这个备份文件');
    }
    final zip = await decryptBytes(raw);
    return BackupService(isar).restore(zip);
  }
}

class DeviceBackupFile {
  const DeviceBackupFile({
    required this.name,
    required this.size,
    required this.modified,
  });

  final String name;
  final int size;
  final DateTime modified;
}
