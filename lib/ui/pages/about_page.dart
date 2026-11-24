import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_info.dart';
import '../../data/services/remote_manifest.dart';
import '../../data/services/url_opener.dart';
import '../../providers/remote_providers.dart';
import '../widgets/notice_dialogs.dart';

/// 关于（二级页面）：版本 / 项目链接 / 微信二维码 / 检查更新
class AboutPage extends ConsumerStatefulWidget {
  const AboutPage({super.key});

  @override
  ConsumerState<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends ConsumerState<AboutPage> {
  bool _checking = false;
  String? _msg;

  Future<void> _checkUpdate() async {
    setState(() {
      _checking = true;
      _msg = null;
    });
    try {
      final m = await RemoteManifestService.instance.fetch();
      if (!mounted) return;
      if (m == null) {
        setState(() => _msg = '检查失败：网络不通，或公告清单还没发布');
        return;
      }
      final latest = m.latest;
      if (latest == null || !latest.isNewer) {
        setState(() => _msg = '已经是最新版本 v$kAppVersionName（$kAppVersionCode）');
        return;
      }
      setState(() => _msg = null);
      await _showUpdate(latest);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _showUpdate(RemoteRelease r) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('新版本 v${r.versionName}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('当前 v$kAppVersionName（$kAppVersionCode）',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  )),
              if (r.notes.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(r.notes,
                    style: const TextStyle(fontSize: 12.5, height: 1.5)),
              ],
              const SizedBox(height: 10),
              SelectableText(
                accelerateUrl(r.apkUrl),
                style: TextStyle(
                  fontSize: 10.5,
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                  ClipboardData(text: accelerateUrl(r.apkUrl)));
              if (ctx.mounted) Navigator.of(ctx).pop(false);
            },
            child: const Text('复制链接'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('去下载'),
          ),
        ],
      ),
    );
    if (go == true && mounted) await runInAppUpdate(context, r);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final manifest = ref.watch(remoteManifestProvider).valueOrNull;
    final notice = manifest?.publicNotice;

    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: <Widget>[
          // 标题
          Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: scheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.inventory_2_outlined,
                    size: 26, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('计件助手',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('v$kAppVersionName（$kAppVersionCode）',
                      style: TextStyle(
                          fontSize: 11.5, color: scheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1) 项目链接
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.link),
              title: const Text('项目主页'),
              subtitle: Text(kProjectUrl,
                  style: const TextStyle(fontSize: 10.5)),
              trailing: const Icon(Icons.open_in_new, size: 16),
              onTap: () => UrlOpener.open(kProjectUrl),
            ),
          ),
          const SizedBox(height: 10),

          // 2) 微信二维码
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(Icons.qr_code_2, size: 18, color: scheme.primary),
                      const SizedBox(width: 6),
                      const Text('加我微信',
                          style: TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('扫码加好友',
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  Center(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (ctx) => Dialog(
                          child: InteractiveViewer(
                            child: Image.asset('assets/wechat_qr.png'),
                          ),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/wechat_qr.png',
                          width: 220,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 3) 检查更新
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.system_update_alt),
              title: const Text('检查更新'),
              subtitle: Text(
                _msg ?? '检查 GitHub 上的最新版本',
                style: TextStyle(
                  fontSize: 10.5,
                  color: _msg != null && _msg!.startsWith('检查失败')
                      ? scheme.error
                      : scheme.onSurfaceVariant,
                ),
              ),
              trailing: _checking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right, size: 18),
              onTap: _checking ? null : _checkUpdate,
            ),
          ),

          // 4) 当前公告（如果有）
          if (notice != null && notice.visible) ...<Widget>[
            const SizedBox(height: 10),
            Card(
              margin: EdgeInsets.zero,
              color: scheme.surfaceContainerHighest.withAlpha(60),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.campaign_outlined,
                            size: 16, color: scheme.primary),
                        const SizedBox(width: 5),
                        Text(notice.title,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(notice.body,
                        style: const TextStyle(fontSize: 11.5, height: 1.6)),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
          Text('预览',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () => handleUpdateDialog(
                  context,
                  RemoteRelease(
                    versionCode: kAppVersionCode + 1,
                    versionName: '${kAppVersionName.split('.').first}.'
                        '${int.parse(kAppVersionName.split('.')[1]) + 1}.0',
                    apkUrl: kProjectUrl,
                    notes: '· 新增多身份卡（每人一张卡，记录/报表/AI 全隔离）\n'
                        '· 颜色支持从货物实拍取色\n'
                        '· 多选汇总支持跨单位折算',
                    force: false,
                  ),
                  preview: true,
                ),
                icon: const Icon(Icons.system_update_alt, size: 16),
                label: const Text('更新弹窗', style: TextStyle(fontSize: 11.5)),
              ),
              OutlinedButton.icon(
                onPressed: () => showNoticeDialog(
                  context,
                  const RemoteNotice(
                    id: 'preview',
                    level: NoticeLevel.critical,
                    title: '关于计件单价的公告（预览）',
                    body: '这是一条公关公告的预览。正式公告由作者在 GitHub 的 '
                        'announcements/manifest.json 里发布，'
                        'App 启动时会自动拉取并弹出。',
                    active: true,
                  ),
                ),
                icon: const Icon(Icons.campaign_outlined, size: 16),
                label: const Text('公告弹窗', style: TextStyle(fontSize: 11.5)),
              ),
              OutlinedButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('停运页'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.pause_circle_outline,
                            size: 44, color: scheme.onSurfaceVariant),
                        const SizedBox(height: 10),
                        const Text('服务已暂停',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(
                          '系统维护中，预计今晚 22:00 恢复',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    actions: <Widget>[
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('知道了'),
                      ),
                    ],
                  ),
                ),
                icon: const Icon(Icons.pause_circle_outline, size: 16),
                label: const Text('停运页', style: TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
