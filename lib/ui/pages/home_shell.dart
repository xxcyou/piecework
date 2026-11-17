import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/app_flags.dart';
import '../../data/services/secure_backup_service.dart';
import '../../providers/records_providers.dart';
import '../../providers/ui_providers.dart';
import '../widgets/secure_backup_card.dart';
import '../widgets/tutorials.dart';
import 'chat_page.dart';
import 'onboarding_page.dart';
import 'record_edit_page.dart';
import 'records_page.dart';
import 'report_page.dart';
import 'settings_page.dart';

/// 主框架：4 个标签页 + 录入悬浮按钮
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startup());
  }

  /// 启动后的引导顺序（只跑一次）：
  /// 1. 首次启动 → 3 屏欢迎引导（可跳过，可顺手去开备份）
  /// 2. 库是空的 → 提示从公共目录的加密备份恢复（重装场景）
  /// 3. 有数据但没开备份 → 提示一次去开（带聚光灯引导）
  Future<void> _startup() async {
    if (_started) return;
    _started = true;

    // 等记录加载完（Isar 首帧还在 loading）
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      if (ref.read(recordsProvider).valueOrNull != null) break;
    }
    if (!mounted) return;
    final empty = (ref.read(recordsProvider).valueOrNull ?? const []).isEmpty;

    // 1) 首次启动引导
    if (!await AppFlags.seen('onboarded')) {
      if (empty) {
        final goBackup = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(builder: (_) => const OnboardingPage()),
        );
        await AppFlags.mark('onboarded');
        if (!mounted) return;
        if (goBackup == true) {
          await runTutorialById(context, ref, 'backup');
          return;
        }
      } else {
        // 老用户（已有数据）升级上来，不打扰
        await AppFlags.mark('onboarded');
      }
    }
    if (!mounted) return;

    // 2) 空库 → 恢复引导
    if (empty) {
      await _offerRestore();
      return;
    }

    // 3) 有数据但没开备份
    await _maybeOfferBackupSetup();
  }

  /// 全新安装 / 库是空的 → 提示从公共目录的加密备份恢复。
  ///
  /// 为什么不能「自动读」：Android 在卸载时会把 SAF 的持久化 URI 授权一起
  /// 收回，重装后 App 拿不到任何目录权限，必须由用户再点一次「允许」。
  /// 所以这里能做的就是主动提示 + 直接拉起系统选择器。
  Future<void> _offerRestore() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('本机还没有任何记录'),
        content: const Text(
          '如果是刚重装 App：之前做过的加密备份还在公共目录里，'
          '选一下那个文件夹就能恢复（需要当初设置的备份密码）。',
          style: TextStyle(height: 1.5),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('先不用'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('去恢复'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    await SecureBackupFlow.restoreFromFolder(context: context, ref: ref);
  }

  /// 有数据但备份没配好 → 弹一次提示，点「开始引导」直接走聚光灯教程
  Future<void> _maybeOfferBackupSetup() async {
    final svc = SecureBackupService.instance;
    final cfg = await svc.load();
    if (cfg.ready) return;
    if (await svc.promptSeen()) return;
    await svc.markPromptSeen();
    if (!mounted) return;

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.shield_outlined,
            color: Theme.of(ctx).colorScheme.primary, size: 30),
        title: const Text('先花 30 秒，把防丢失打开'),
        content: const Text(
          '现在数据只在本机：卸载、换手机、清数据都会没。\n'
          '开启「加密自动备份」后，数据会自动加密存到你选的公共文件夹，'
          '以后重装也能一键找回。',
          style: TextStyle(height: 1.6),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('以后再说'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('开始引导'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    await runTutorialById(context, ref, 'backup');
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(tabIndexProvider);

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const <Widget>[
          RecordsPage(),
          ChatPage(),
          ReportPage(),
          SettingsPage(),
        ],
      ),
      floatingActionButton: index == 0
          ? FloatingActionButton.extended(
              onPressed: () => openRecordEditor(context),
              icon: const Icon(Icons.add_a_photo_outlined, size: 20),
              label: const Text('录入'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        height: 64,
        selectedIndex: index,
        onDestinationSelected: (i) => ref.read(tabIndexProvider.notifier).go(i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: '记录',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'AI 助手',
          ),
          NavigationDestination(
            icon: Icon(Icons.ios_share_outlined),
            selectedIcon: Icon(Icons.ios_share),
            label: '报表',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}

/// 打开「新增记录」页（供 FAB 与空状态复用）
Future<void> openRecordEditor(BuildContext context) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => const RecordEditPage()),
  );
}
