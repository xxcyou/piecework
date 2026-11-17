import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:piecework/main.dart' as app;

/// 真机端到端。
///
/// 两个坑：
/// 1. `app.main()` 只能调一次 —— 重复调用会二次 Isar.open 直接抛异常；
/// 2. 不能用 `pumpAndSettle` —— Isar 打开期间有 loading 指示器（无限动画），
///    pumpAndSettle 会一直等不到稳定。所以统一用「显式 pump + runAsync 等真实异步」。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// 推进若干帧（替代 pumpAndSettle）
  Future<void> settle(WidgetTester tester, {int frames = 12}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  /// 等待真实世界异步（Isar / 文件 IO）完成
  Future<void> realWait(WidgetTester tester, int ms) async {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await settle(tester, frames: 4);
  }

  testWidgets('无图录入 → 列表 → 缺照片筛选 → 四标签页', (tester) async {
    final stamp = DateTime.now().millisecondsSinceEpoch % 100000;
    final style = 'T$stamp';

    app.main();
    await tester.pump();
    await realWait(tester, 3000);

    // ── 1. 首页 ──
    expect(find.text('计件记录'), findsOneWidget);

    // ── 2. 录入（全程不拍照）──
    await tester.tap(find.text('录入'));
    await settle(tester);
    await realWait(tester, 600);

    expect(find.text('录入记录'), findsOneWidget);
    expect(find.text('拍下工票留档（可跳过）'), findsOneWidget);

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(6));

    await tester.enterText(fields.at(0), style);
    await tester.enterText(fields.at(1), '黑色');
    await tester.enterText(fields.at(2), 'M');
    await tester.enterText(fields.at(3), '10');
    await tester.enterText(fields.at(4), '12.50');
    await settle(tester);

    expect(find.text('¥125.00'), findsWidgets);

    // ── 3. 保存 ──
    await tester.tap(find.text('保存记录'));
    await settle(tester);
    await realWait(tester, 1200);

    expect(find.text('计件记录'), findsOneWidget);
    expect(find.text(style), findsWidgets);
    expect(find.text('10 件 × ¥12.50'), findsWidgets);
    expect(find.text('无图'), findsWidgets);

    // ── 4. 筛选：只看缺照片 ──
    await tester.tap(find.byIcon(Icons.filter_list));
    await settle(tester);
    await realWait(tester, 500);

    expect(find.text('筛选'), findsOneWidget);
    expect(find.text('照片'), findsOneWidget);

    // 「照片」区在筛选页下方，必须先滚到可见再点，否则 tap 会点到屏幕外
    final photoChip = find.text('缺照片');
    await tester.ensureVisible(photoChip);
    await settle(tester);
    await tester.tap(photoChip);
    await settle(tester);
    await tester.tap(find.text('应用筛选'));
    await settle(tester);
    await realWait(tester, 500);

    expect(find.text(style), findsWidgets);
    expect(find.text('清除筛选'), findsOneWidget);

    await tester.tap(find.text('清除筛选'));
    await settle(tester);

    // ── 5. 四个标签页 ──
    await tester.tap(find.text('AI 助手'));
    await settle(tester);
    expect(find.text('问我就行，数据都在本机'), findsOneWidget);

    await tester.tap(find.text('报表'));
    await settle(tester);
    await realWait(tester, 500);
    expect(find.text('导出高清 PNG'), findsOneWidget);

    await tester.tap(find.text('设置'));
    await settle(tester);
    expect(find.text('AI 接口配置'), findsOneWidget);

    await tester.tap(find.text('记录'));
    await settle(tester);
    expect(find.text('计件记录'), findsOneWidget);
  });
}
