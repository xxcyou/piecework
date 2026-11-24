import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/remote_manifest.dart';
import 'notice_dialogs.dart';

/// 启动闸门：
/// * 清单说「不运营」→ 直接挡在停运页（可重试）
/// * 有新版本 → 弹更新公告（可去下载 / 本次忽略）
/// * 有公关公告 → 弹公告（同一条只弹一次）
class NoticeGate extends ConsumerStatefulWidget {
  const NoticeGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NoticeGate> createState() => _NoticeGateState();
}

class _NoticeGateState extends ConsumerState<NoticeGate>
    with WidgetsBindingObserver {
  RemoteManifest? _manifest;
  RemoteFlags _flags = RemoteFlags();
  bool _checking = false;
  bool _shownThisSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 回到前台再检查一次（节流 6 小时；不打断用户当前操作，只更新状态）
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // 允许再次弹窗：新公告/新版本可能在这期间发布
    _shownThisSession = false;
    _refresh(silent: true);
  }

  Future<void> _boot() async {
    final svc = RemoteManifestService.instance;
    // 先用缓存秒开，避免白屏
    final cached = await svc.cached();
    final flags = await svc.flags();
    if (!mounted) return;
    setState(() {
      _manifest = cached;
      _flags = flags;
    });
    // 每次启动都拉一次最新清单（就一个 JSON，很轻）——
    // 不能等 6 小时，否则作者刚发新版，用户当天根本收不到提示
    await _refresh(silent: true);
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final fresh = await RemoteManifestService.instance.fetch();
      final flags = await RemoteManifestService.instance.flags();
      if (!mounted) return;
      setState(() {
        if (fresh != null) _manifest = fresh;
        _flags = flags;
      });
      if (!silent && fresh == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('检查失败：网络不通或清单还没发布')),
        );
      }
      _maybeShowDialogs();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _maybeShowDialogs() {
    if (_shownThisSession) return;
    final m = _manifest;
    if (m == null) return;
    if (!m.operating) return; // 停运页已经接管

    final latest = m.latest;
    if (latest != null &&
        latest.isNewer &&
        _flags.dismissedVersionCode != latest.versionCode) {
      _shownThisSession = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showUpdate(latest));
      return;
    }

    final notice = m.publicNotice;
    if (notice != null &&
        notice.visible &&
        _flags.dismissedNoticeId != notice.id) {
      _shownThisSession = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showNotice(notice));
    }
  }

  Future<void> _showUpdate(RemoteRelease r) => handleUpdateDialog(context, r);

  Future<void> _showNotice(RemoteNotice n) async {
    if (!mounted) return;
    await showNoticeDialog(context, n);
    await RemoteManifestService.instance.dismissNotice(n.id);
  }

  @override
  Widget build(BuildContext context) {
    final m = _manifest;
    if (m != null && !m.operating) {
      return _StoppedPage(
        message: m.operatingMessage,
        checking: _checking,
        onRetry: () => _refresh(),
      );
    }
    // 清单到齐后（含缓存）尝试弹一次
    if (m != null && !_shownThisSession) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowDialogs());
    }
    return widget.child;
  }
}

/// 停运页：不运营时直接挡在这里
class _StoppedPage extends StatelessWidget {
  const _StoppedPage({
    required this.message,
    required this.checking,
    required this.onRetry,
  });

  final String message;
  final bool checking;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.pause_circle_outline,
                    size: 56, color: scheme.onSurfaceVariant),
                const SizedBox(height: 14),
                const Text(
                  '服务已暂停',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  message.isEmpty ? '作者暂时关闭了这个版本，请稍后再来。' : message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: checking ? null : onRetry,
                  icon: checking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
