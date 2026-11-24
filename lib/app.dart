import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'providers/settings_providers.dart';
import 'ui/pages/home_shell.dart';
import 'ui/widgets/notice_gate.dart';

/// 应用根组件：主题 / 语言 / 首页
class PieceworkApp extends ConsumerWidget {
  const PieceworkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    // 让自动备份服务始终拿到最新的云备份配置
    ref.watch(webDavSyncProvider);

    return MaterialApp(
      title: '计件助手',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const <Locale>[
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // 启动闸门：不运营 → 停运页；有新版/公告 → 弹窗
      home: const NoticeGate(child: HomeShell()),
    );
  }
}
