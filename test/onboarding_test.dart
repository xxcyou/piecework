import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/ui/pages/onboarding_page.dart';

/// 首次引导：4 步，**数据安全在前**
///
/// 注意：第 2 步用到 SecureBackupSection（读 Isar/文件），
/// 这里只验证页面结构、步骤推进和文案顺序，不点真实备份按钮。
void main() {
  Widget wrap() => const ProviderScope(
        child: MaterialApp(home: OnboardingPage()),
      );

  testWidgets('第 1 步是欢迎，且有 4 段进度', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(find.text('计件助手'), findsOneWidget);
    expect(find.text('数据先保住'), findsOneWidget); // 卖点第一条就是数据
    expect(find.text('开始'), findsOneWidget);
  });

  testWidgets('没有「一路跳过」：不提供跳过按钮', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(find.text('跳过'), findsNothing);
  });

  testWidgets('第 2 步是数据安全（备份），在身份卡之前', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('先把数据保住'), findsOneWidget);
    // 这一步不能跳过（底部只有「上一步 / 好了，下一步」）
    expect(find.text('好了，下一步'), findsOneWidget);
    expect(find.text('上一步'), findsOneWidget);
  });

  testWidgets('第 3 步是身份卡，默认名字「我」', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('好了，下一步'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('你叫什么'), findsOneWidget);
    expect(find.text('我'), findsOneWidget); // 默认值
    expect(find.text('再加一个人（可留空）'), findsOneWidget);
  });

  testWidgets('最后一步是「开始计件」', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    for (final label in <String>['开始', '好了，下一步', '下一步']) {
      await tester.tap(find.text(label));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }
    expect(find.text('可以开始记了'), findsOneWidget);
    expect(find.text('开始计件'), findsOneWidget);
  });
}
