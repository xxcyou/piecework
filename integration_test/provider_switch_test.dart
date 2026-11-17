import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:piecework/main.dart' as app;
import 'package:piecework/providers/settings_providers.dart';

/// 只在 .dev 包上跑（applicationId 带 .dev），**不会碰到真实数据**。
///
/// 目标：验证「设置 → AI 助手设置 → 点自定义」真的能切过去。
/// 之前的 bug：点自定义没反应，一直停在 Kilo 免费。
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

  testWidgets('点「自定义」必须真的切过去', (tester) async {
    app.main();
    await tester.pump();
    await realWait(tester, 3500);

    // 空库启动会弹「本机还没有任何记录」→ 先关掉
    if (find.text('先不用').evaluate().isNotEmpty) {
      await tester.tap(find.text('先不用'));
      await settle(tester);
      await realWait(tester, 400);
    }

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp).first),
      listen: false,
    );

    // 进设置页 → AI 接口配置
    await tester.tap(find.text('设置'));
    await settle(tester);
    await realWait(tester, 400);
    await tester.tap(find.text('AI 接口配置'));
    await settle(tester);
    await realWait(tester, 800);

    expect(find.text('AI 助手设置'), findsOneWidget);

    // 初始应为内置
    expect(container.read(aiConfigProvider).providerId, 'kilo');

    // 点自定义
    await tester.tap(find.text('自定义'));
    await settle(tester);
    await realWait(tester, 800);

    final after = container.read(aiConfigProvider);
    // ignore: avoid_print
    print('点自定义后 → providerId=${after.providerId} baseUrl=${after.baseUrl} model=${after.model}');
    expect(after.providerId, 'custom', reason: '点了自定义还是没切过去');
    // 界面上应该出现地址输入框
    expect(find.widgetWithText(TextField, '接口地址'), findsOneWidget);

    // 再点回内置
    await tester.tap(find.text('Kilo 免费'));
    await settle(tester);
    await realWait(tester, 600);
    expect(container.read(aiConfigProvider).providerId, 'kilo');
  }, timeout: const Timeout(Duration(minutes: 4)));
}
