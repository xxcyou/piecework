import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:piecework/main.dart' as app;

/// 只在 .dev 包上跑（applicationId 带 .dev），不碰真实数据。
///
/// 验证：教程关卡 → 点「开启加密自动备份」→ 聚光灯引导能正常走完 4 步。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, {int frames = 12}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  Future<void> realWait(WidgetTester tester, int ms) async {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await settle(tester, frames: 4);
  }

  testWidgets('教程关卡 → 备份引导能走完', (tester) async {
    app.main();
    await tester.pump();
    await realWait(tester, 3500);

    // 空库启动的提示先关掉
    for (final label in <String>['先不用', '以后再说']) {
      if (find.text(label).evaluate().isNotEmpty) {
        await tester.tap(find.text(label));
        await settle(tester);
        await realWait(tester, 400);
      }
    }

    await tester.tap(find.text('设置'));
    await settle(tester);
    await realWait(tester, 400);

    expect(find.text('教程关卡'), findsOneWidget);
    await tester.tap(find.text('教程关卡'));
    await settle(tester);
    await realWait(tester, 500);

    expect(find.text('新手教程'), findsOneWidget);
    expect(find.text('开启加密自动备份（必做）'), findsOneWidget);

    // 点「4 步 · 开始」
    await tester.tap(find.textContaining('开始').first);
    await settle(tester);
    await realWait(tester, 1200);

    // 引导第一屏
    expect(find.text('这是唯一的备份通道'), findsOneWidget);
    expect(find.text('1/4'), findsOneWidget);

    // 逐步点下去
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('下一步'));
      await settle(tester);
      await realWait(tester, 700);
    }
    expect(find.text('4/4'), findsOneWidget);
    expect(find.text('开始用'), findsOneWidget);

    await tester.tap(find.text('开始用'));
    await settle(tester);
    await realWait(tester, 500);

    // 引导层已关闭，回到设置页
    expect(find.text('这是唯一的备份通道'), findsNothing);
    expect(find.text('加密自动备份'), findsWidgets);
  }, timeout: const Timeout(Duration(minutes: 4)));
}
