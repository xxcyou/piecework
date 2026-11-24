import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/app_flags.dart';
import '../../providers/records_providers.dart';
import '../../providers/ui_providers.dart';
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

    // 首次启动：4 步引导（数据安全在前，身份卡在后）
    if (!await AppFlags.seen('onboarded')) {
      if (empty) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const OnboardingPage()),
        );
      }
      // 老用户（已有数据）升级上来不打扰，只记一下
      await AppFlags.mark('onboarded');
    }
    // 恢复数据 / 备份设置都放到「设置」里，启动时不再弹
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
