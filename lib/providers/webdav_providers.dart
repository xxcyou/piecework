import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/webdav_service.dart';
import 'settings_providers.dart';

/// 当前 WebDAV 配置（跟着设置走）
final webDavConfigProvider = Provider<WebDavConfig>((ref) {
  final s = ref.watch(settingsProvider).valueOrNull;
  return WebDavConfig(
    url: s?.webdavUrl ?? '',
    username: s?.webdavUser ?? '',
    password: s?.webdavPass ?? '',
    dir: (s?.webdavDir ?? '').isEmpty ? '/piecework/' : s!.webdavDir,
    enabled: s?.webdavEnabled ?? false,
  );
});

/// 云端备份列表（下拉刷新时 invalidate）
final webDavFilesProvider = FutureProvider<List<WebDavFile>>((ref) async {
  final cfg = ref.watch(webDavConfigProvider);
  if (!cfg.ready) return const <WebDavFile>[];
  return WebDavService(cfg).list();
});
