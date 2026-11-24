import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_info.dart';
import '../../data/services/remote_manifest.dart';
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

/// 更新弹窗的完整处理：去下载 / 忽略
Future<void> handleUpdateDialog(
  BuildContext context,
  RemoteRelease r, {
  bool preview = false,
}) async {
  final action = await showUpdateDialog(context, r, preview: preview);
  if (action == 'go') {
    if (preview) {
      await UrlOpener.open(kProjectUrl);
    } else {
      await UrlOpener.open(accelerateUrl(r.apkUrl));
    }
  } else if (action == 'skip') {
    await RemoteManifestService.instance.dismissVersion(r.versionCode);
  }
}
