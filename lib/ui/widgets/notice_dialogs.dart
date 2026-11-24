import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_info.dart';
import '../../data/services/remote_manifest.dart';
import '../../data/services/update_installer.dart';
import '../../data/services/url_opener.dart';

/// 更新弹窗：返回 'go' / 'skip' / 'later'
Future<String?> showUpdateDialog(
  BuildContext context,
  RemoteRelease r, {
  bool preview = false,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: !r.force,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: <Widget>[
          const Icon(Icons.system_update_alt, size: 20),
          const SizedBox(width: 6),
          Expanded(child: Text('发现新版本 v${r.versionName}')),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '当前 v$kAppVersionName（$kAppVersionCode）',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
              if (r.notes.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(r.notes,
                    style: const TextStyle(fontSize: 12.5, height: 1.5)),
              ],
              const SizedBox(height: 10),
              SelectableText(
                accelerateUrl(r.apkUrl),
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
              if (preview) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  '（这是模拟预览，不会真的下载）',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Theme.of(ctx).colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () async {
            await Clipboard.setData(
                ClipboardData(text: accelerateUrl(r.apkUrl)));
            if (ctx.mounted) Navigator.of(ctx).pop('copy');
          },
          child: const Text('复制链接'),
        ),
        if (!r.force)
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('skip'),
            child: const Text('本次忽略'),
          ),
        if (!r.force)
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('later'),
            child: const Text('稍后'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop('go'),
          child: const Text('立即更新'),
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

/// 下载 + 安装（带进度条）。失败给出人话提示，并允许改用浏览器下载兜底。
Future<void> runInAppUpdate(BuildContext context, RemoteRelease r) async {
  final progress = ValueNotifier<double?>(0);
  final received = ValueNotifier<int>(0);
  final total = ValueNotifier<int>(0);

  if (!context.mounted) return;
  // 进度弹窗（不可取消，避免下载一半退出）
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('正在下载更新'),
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
                          : '已下载 ${(received.value / 1024 / 1024).toStringAsFixed(1)} MB',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '下载完成后会直接调起系统安装器，覆盖安装，数据不丢。',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  ({bool ok, String message}) result;
  try {
    result = await UpdateInstaller.instance.downloadAndInstall(
      r.apkUrl,
      onProgress: (f, got, t) {
        progress.value = f;
        received.value = got;
        total.value = t;
      },
    );
  } catch (e) {
    result = (ok: false, message: '$e');
  }

  if (!context.mounted) return;
  // 关掉进度弹窗
  Navigator.of(context, rootNavigator: true).pop();
  progress.dispose();
  received.dispose();
  total.dispose();

  if (result.ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('下载完成，请在系统弹窗里点「安装」')),
    );
    return;
  }

  final needPerm = result.message.contains('安装未知应用') ||
      result.message.contains('need_permission');
  final retry = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(needPerm ? '需要允许安装' : '自动更新失败'),
      content: Text(
        needPerm
            ? '系统里还没允许本应用「安装未知应用」。\n'
                '刚才已经帮你打开设置页，允许之后再点一次「立即更新」即可。'
            : '原因：${result.message}',
        style: const TextStyle(fontSize: 12.5, height: 1.5),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop('browser'),
          child: const Text('用浏览器下载'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop('ok'),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
  if (retry == 'browser') {
    await UrlOpener.open(accelerateUrl(r.apkUrl));
  }
}
