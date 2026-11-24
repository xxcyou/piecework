import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/remote_manifest.dart';

/// 远端清单（运营状态 / 公关公告 / 最新版本）
///
/// 先用缓存秒开，再在后台拉最新的；拉不到就沿用缓存（离线也能用）。
final remoteManifestProvider = FutureProvider<RemoteManifest?>((ref) async {
  final svc = RemoteManifestService.instance;
  final cached = await svc.cached();
  if (await svc.shouldCheck()) {
    final fresh = await svc.fetch();
    if (fresh != null) return fresh;
  }
  return cached;
});

/// 已读/忽略记录（对话框判断用）
final remoteFlagsProvider = FutureProvider<RemoteFlags>((ref) async {
  return RemoteManifestService.instance.flags();
});
