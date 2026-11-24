import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_info.dart';
import '../../data/services/remote_manifest.dart';
import '../../data/services/update_installer.dart';
import '../../data/services/url_opener.dart';

/// 更新弹窗：返回 'go' / 'skip' / 'later'
///
/// 按钮只留两个（稍后 / 立即更新），「忽略本次版本」放到内容区底部的小链接，
/// 避免 4 个按钮挤成两行、排版错乱。
Future<String?> showUpdateDialog(
  BuildContext context,
  RemoteRelease r, {
  bool preview = false,
}) {
  final scheme = Theme.of(context).colorScheme;
  return showDialog<String>(
    context: context,
    barrierDismissible: !r.force,
    builder: (ctx) => AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      title: Row(
        children: <Widget>[
          Icon(Icons.system_update_alt, size: 20, color: scheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '发现新版本 v${r.versionName}',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '当前 v$kAppVersionName（$kAppVersionCode）'
                '${r.force ? ' · 必须更新' : ''}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (r.notes.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withAlpha(60),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    r.notes,
                    style: const TextStyle(fontSize: 12.5, height: 1.6),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              if (preview)
                Text(
                  '预览',
                  style: TextStyle(fontSize: 11, color: scheme.primary),
                ),
              if (!r.force && !preview) ...<Widget>[
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop('skip'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: scheme.onSurfaceVariant,
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                    child: const Text('忽略此版本'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: <Widget>[
        if (!r.force)
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('later'),
            child: const Text('稍后'),
          )
        else
          const SizedBox.shrink(),
        FilledButton.icon(
          onPressed: () => Navigator.of(ctx).pop('go'),
          icon: const Icon(Icons.download_rounded, size: 17),
          label: Text(preview ? '预览' : '更新'),
        ),
      ],
    ),
  );
}

/// 公关公告弹窗
Future<void> showNoticeDialog(BuildContext context, RemoteNotice n) async {
  final scheme = Theme.of(context).colorScheme;
  final color = switch (n.level) {
    NoticeLevel.critical => scheme.error,
    NoticeLevel.warning => const Color(0xFFE8830C),
    NoticeLevel.info => scheme.primary,
  };
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: <Widget>[
          Icon(
            n.level == NoticeLevel.critical
                ? Icons.campaign
                : Icons.notifications_active_outlined,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              n.title.isEmpty ? '公告' : n.title,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Text(n.body,
              style: const TextStyle(fontSize: 12.5, height: 1.6)),
        ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}

/// 更新弹窗的完整处理：**应用内自动更新**（下载 APK → 系统安装器）/ 忽略
Future<void> handleUpdateDialog(
  BuildContext context,
  RemoteRelease r, {
  bool preview = false,
}) async {
  final action = await showUpdateDialog(context, r, preview: preview);
  if (action == 'skip') {
    await RemoteManifestService.instance.dismissVersion(r.versionCode);
    return;
  }
  if (action != 'go') return;

  if (preview) {
    // 预览模式不真的下载
    await UrlOpener.open(kProjectUrl);
    return;
  }
  await runInAppUpdate(context, r);
}

/// 下载 → 确认 → 安装（带进度条）
///
/// 下载和安装拆成两步：安装器万一没弹，用户能再点一次，不用重新下载。
Future<void> runInAppUpdate(BuildContext context, RemoteRelease r) async {
  final progress = ValueNotifier<double?>(0);
  final received = ValueNotifier<int>(0);
  final total = ValueNotifier<int>(0);

  var cancelled = false;
  if (!context.mounted) return;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('下载中'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ValueListenableBuilder<double?>(
              valueListenable: progress,
              builder: (_, v, __) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  LinearProgressIndicator(
                    value: v,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<int>(
                    valueListenable: total,
                    builder: (_, t, __) => Text(
                      t > 0
                          ? '${((v ?? 0) * 100).toStringAsFixed(0)}%'
                              ' · ${(received.value / 1024 / 1024).toStringAsFixed(1)}'
                              ' / ${(t / 1024 / 1024).toStringAsFixed(1)} MB'
                          : '${(received.value / 1024 / 1024).toStringAsFixed(1)} MB',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              cancelled = true;
              UpdateInstaller.instance.cancel();
              Navigator.of(ctx).pop();
            },
            child: const Text('取消'),
          ),
        ],
      ),
    ),
  );

  String? path;
  String err = '';
  try {
    path = await UpdateInstaller.instance
        .download(r.apkUrl, onProgress: (f, got, t) {
      progress.value = f;
      received.value = got;
      total.value = t;
    });
  } catch (e) {
    err = '$e';
  }

  if (cancelled) {
    // 用户主动取消：清掉半截文件，静默返回
    try {
      final f = File(path ?? '');
      if (await f.exists()) await f.delete();
    } catch (_) {}
    progress.dispose();
    received.dispose();
    total.dispose();
    return;
  }
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();
  progress.dispose();
  received.dispose();
  total.dispose();

  if (path == null) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('下载失败'),
        content: Text(err, style: const TextStyle(fontSize: 12)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              UrlOpener.open(accelerateUrl(r.apkUrl));
            },
            child: const Text('浏览器下载'),
          ),
        ],
      ),
    );
    return;
  }

  // 下载完成 → 确认安装（可重复点）
  var trying = true;
  while (trying) {
    if (!context.mounted) return;
    final go = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('已下载 v${r.versionName}'),
        content: const Text(
          '点「安装」调起系统安装器。\n没反应就点「存到下载」，去文件管理器里点那个 APK 装。',
          style: TextStyle(fontSize: 12.5, height: 1.5),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('export'),
            child: const Text('存到下载'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('later'),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('install'),
            child: const Text('安装'),
          ),
        ],
      ),
    );
    if (go == 'export') {
      final uri = await UpdateInstaller.instance.exportToDownloads(path);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uri == null
              ? '存到下载失败'
              : '已存到「下载」目录，去文件管理器点它安装'),
        ),
      );
      return;
    }
    if (go != 'install') return;

    final res = await UpdateInstaller.instance.install(path);
    if (res.ok) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已调起安装器（${res.via}）')),
      );
      return;
    }
    trying = false;
    if (!context.mounted) return;
    final needPerm = res.message.contains('安装未知应用') ||
        res.message.contains('need_permission');
    final retry = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(needPerm ? '需要允许安装' : '没调起安装器'),
        content: Text(
          needPerm
              ? '打开「安装未知应用」权限后再试。'
              : '${res.message}\n\n安装包已下好，可以重试或用浏览器重新下载。',
          style: const TextStyle(fontSize: 12.5, height: 1.5),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('browser'),
            child: const Text('浏览器下载'),
          ),
          if (needPerm)
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop('settings'),
              child: const Text('去允许'),
            )
          else
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop('again'),
              child: const Text('重试'),
            ),
        ],
      ),
    );
    if (retry == 'browser') {
      await UrlOpener.open(accelerateUrl(r.apkUrl));
      return;
    } else if (retry == 'settings') {
      await UpdateInstaller.instance.openInstallSettings();
      return;
    } else if (retry == 'again') {
      trying = true;
    }
  }
}
