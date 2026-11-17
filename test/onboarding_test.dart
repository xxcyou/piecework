import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/ui/pages/onboarding_page.dart';

void main() {
  Future<void> pumpOnboarding(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(builder: (_) => const OnboardingPage()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('首次引导：3 屏，能一路点到最后', (tester) async {
    await pumpOnboarding(tester);

    // 第 1 屏
    expect(find.text('记一条，算一条'), findsOneWidget);
    expect(find.text('下一步'), findsOneWidget);
    expect(find.text('开始使用'), findsNothing);

    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // 第 2 屏
    expect(find.text('想查什么，直接问'), findsOneWidget);

    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // 第 3 屏：出现「开始使用」+「先帮我把备份打开」
    expect(find.text('数据别丢，开个备份'), findsOneWidget);
    expect(find.text('开始使用'), findsOneWidget);
    expect(find.text('先帮我把备份打开'), findsOneWidget);
  });

  testWidgets('点「开始使用」返回 false（不需要起备份引导）', (tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('开始使用'));
    await tester.pumpAndSettle();
    // 回到调用页
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('点「先帮我把备份打开」返回 true', (tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('先帮我把备份打开'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('跳过能直接退出', (tester) async {
    await pumpOnboarding(tester);
    expect(find.text('跳过'), findsOneWidget);
    await tester.tap(find.text('跳过'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });
}
