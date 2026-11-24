import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/app_info.dart';

/// 公告级别
enum NoticeLevel { info, warning, critical }

NoticeLevel noticeLevelFrom(Object? v) => switch (v) {
      'critical' => NoticeLevel.critical,
      'warning' => NoticeLevel.warning,
      _ => NoticeLevel.info,
    };

/// 一条公告（公关公告）
class RemoteNotice {
  const RemoteNotice({
    required this.id,
    required this.level,
    required this.title,
    required this.body,
    required this.active,
    this.expiresAt,
  });

  final String id;
  final NoticeLevel level;
  final String title;
  final String body;
  final bool active;
  final DateTime? expiresAt;

  bool get visible {
    if (!active) return false;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return false;
    return title.trim().isNotEmpty || body.trim().isNotEmpty;
  }

  static RemoteNotice? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    final id = (m['id'] as String?)?.trim() ?? '';
    final title = (m['title'] as String?)?.trim() ?? '';
    final body = (m['body'] as String?)?.trim() ?? '';
    if (id.isEmpty && title.isEmpty && body.isEmpty) return null;
    return RemoteNotice(
      id: id.isEmpty ? title.hashCode.toString() : id,
      level: noticeLevelFrom(m['level']),
      title: title,
      body: body,
      active: m['active'] != false,
      expiresAt: DateTime.tryParse((m['expiresAt'] as String?) ?? ''),
    );
  }
}

/// 最新版本信息（用 GitHub Releases 当下载源）
class RemoteRelease {
  const RemoteRelease({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.notes,
    required this.force,
  });

  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String notes;
  final bool force;

  /// 有没有比当前版本更新
  bool get isNewer => versionCode > kAppVersionCode;

  static RemoteRelease? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    final code = (m['versionCode'] as num?)?.toInt() ?? 0;
    if (code <= 0) return null;
    return RemoteRelease(
      versionCode: code,
      versionName: (m['versionName'] as String?)?.trim() ?? '$code',
      apkUrl: (m['apkUrl'] as String?)?.trim() ?? '',
      notes: (m['notes'] as String?)?.trim() ?? '',
      force: m['force'] == true,
    );
  }
}

/// 远端清单：运营状态 + 公关公告 + 最新版本
class RemoteManifest {
  const RemoteManifest({
    required this.operating,
    required this.operatingMessage,
    required this.publicNotice,
    required this.latest,
    required this.fetchedAt,
  });

  final bool operating;
  final String operatingMessage;
  final RemoteNotice? publicNotice;
  final RemoteRelease? latest;
  final DateTime fetchedAt;

  static RemoteManifest? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    return RemoteManifest(
      operating: m['operating'] != false,
      operatingMessage: (m['operatingMessage'] as String?)?.trim() ?? '',
      publicNotice: RemoteNotice.fromJson(m['publicNotice']),
      latest: RemoteRelease.fromJson(m['latest']),
      fetchedAt: DateTime.tryParse((m['fetchedAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'operating': operating,
        'operatingMessage': operatingMessage,
        'publicNotice': publicNotice == null
            ? null
            : <String, dynamic>{
                'id': publicNotice!.id,
                'level': publicNotice!.level.name,
                'title': publicNotice!.title,
                'body': publicNotice!.body,
                'active': publicNotice!.active,
                'expiresAt': publicNotice!.expiresAt?.toIso8601String(),
              },
        'latest': latest == null
            ? null
            : <String, dynamic>{
                'versionCode': latest!.versionCode,
                'versionName': latest!.versionName,
                'apkUrl': latest!.apkUrl,
                'notes': latest!.notes,
                'force': latest!.force,
              },
        'fetchedAt': fetchedAt.toIso8601String(),
      };
}

/// 远端状态（已读/忽略记录）
class RemoteFlags {
  RemoteFlags({
    this.lastCheckMs = 0,
    this.dismissedNoticeId = '',
    this.dismissedVersionCode = 0,
    this.dismissedOperating = false,
  });

  int lastCheckMs;
  String dismissedNoticeId;
  int dismissedVersionCode;
  bool dismissedOperating;

  static RemoteFlags fromJson(Map<String, dynamic> m) => RemoteFlags(
        lastCheckMs: (m['lastCheckMs'] as num?)?.toInt() ?? 0,
        dismissedNoticeId: (m['dismissedNoticeId'] as String?) ?? '',
        dismissedVersionCode: (m['dismissedVersionCode'] as num?)?.toInt() ?? 0,
        dismissedOperating: m['dismissedOperating'] == true,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lastCheckMs': lastCheckMs,
        'dismissedNoticeId': dismissedNoticeId,
        'dismissedVersionCode': dismissedVersionCode,
        'dismissedOperating': dismissedOperating,
      };
}

/// 远端清单服务：拉取 / 缓存 / 节流
///
/// 为什么要缓存：机场/地铁里没网时不能让 App 打不开 ——
/// 先用上次成功拉到的清单，拉不到就当「一切正常」。
class RemoteManifestService {
  RemoteManifestService._();

  static final RemoteManifestService instance = RemoteManifestService._();

  /// 自动检查节流：6 小时内不重复拉
  static const Duration checkInterval = Duration(hours: 6);

  RemoteManifest? _cached;
  RemoteFlags _flags = RemoteFlags();
  bool _loaded = false;

  File? _cacheFile;
  File? _flagsFile;

  Future<Directory> _docs() => getApplicationDocumentsDirectory();

  Future<File> _cache() async =>
      _cacheFile ??= File(p.join((await _docs()).path, 'remote_manifest.json'));

  Future<File> _flagsPath() async =>
      _flagsFile ??= File(p.join((await _docs()).path, 'remote_flags.json'));

  Future<void> _loadLocal() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final f = await _cache();
      if (await f.exists()) {
        _cached = RemoteManifest.fromJson(jsonDecode(await f.readAsString()));
      }
    } catch (_) {}
    try {
      final f = await _flagsPath();
      if (await f.exists()) {
        final raw = jsonDecode(await f.readAsString());
        if (raw is Map) {
          _flags = RemoteFlags.fromJson(raw.map((k, v) => MapEntry('$k', v)));
        }
      }
    } catch (_) {}
  }

  Future<void> _saveFlags() async {
    try {
      final f = await _flagsPath();
      await f.writeAsString(jsonEncode(_flags.toJson()), flush: true);
    } catch (_) {}
  }

  Future<void> _saveCache(RemoteManifest m) async {
    try {
      final f = await _cache();
      await f.writeAsString(jsonEncode(m.toJson()), flush: true);
    } catch (_) {}
  }

  /// 缓存里的清单（可能是上次拉的）
  Future<RemoteManifest?> cached() async {
    await _loadLocal();
    return _cached;
  }

  Future<RemoteFlags> flags() async {
    await _loadLocal();
    return _flags;
  }

  /// 是否需要自动检查（6 小时一次）
  Future<bool> shouldCheck() async {
    await _loadLocal();
    if (_flags.lastCheckMs == 0) return true;
    final last = DateTime.fromMillisecondsSinceEpoch(_flags.lastCheckMs);
    return DateTime.now().difference(last) > checkInterval;
  }

  /// 拉取清单：先走加速地址，失败再走原始地址
  Future<RemoteManifest?> fetch() async {
    for (final url in <String>[kManifestAcceleratedUrl, kManifestRawUrl]) {
      try {
        final res = await http
            .get(Uri.parse(url), headers: <String, String>{
          'Cache-Control': 'no-cache',
        }).timeout(const Duration(seconds: 12));
        if (res.statusCode != 200) continue;
        final m = RemoteManifest.fromJson(jsonDecode(res.body));
        if (m == null) continue;
        await _loadLocal();
        _cached = m;
        _flags.lastCheckMs = DateTime.now().millisecondsSinceEpoch;
        await _saveCache(m);
        await _saveFlags();
        return m;
      } catch (_) {
        // 换下一个地址
      }
    }
    return null;
  }

  Future<void> dismissNotice(String id) async {
    await _loadLocal();
    _flags.dismissedNoticeId = id;
    await _saveFlags();
  }

  Future<void> dismissVersion(int code) async {
    await _loadLocal();
    _flags.dismissedVersionCode = code;
    await _saveFlags();
  }

  Future<void> dismissOperating() async {
    await _loadLocal();
    _flags.dismissedOperating = true;
    await _saveFlags();
  }

  /// 测试用：重置内存状态
  void debugReset() {
    _loaded = false;
    _cached = null;
    _flags = RemoteFlags();
    _cacheFile = null;
    _flagsFile = null;
  }
}
