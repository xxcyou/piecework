import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:piecework/main.dart' as app;
import 'package:piecework/providers/chat_providers.dart';
import 'package:piecework/providers/settings_providers.dart';

/// 真机回归：AI 提供商解析必须「说到做到」。
///
/// 曾经的两个 bug：
///   1) 聊天发送路径手搓 AiConfig 读 settings.aiBaseUrl/aiModel
///      （历史默认值 api.openai.com + gpt-4o-mini）→ 选了内置免费模型，
///      请求却打到第三方；没 Key 时还误报「还没配置 AI 接口」。
///   2) 一键重置会把自定义地址/密钥/模型全清掉，且 `_save` 用库里的旧
///      providerId 判断 → 切到第三方时三个字段被丢弃 → 「切不回第三方提供商」。
///
/// 一个 testWidgets 跑完：内置生效 → 真发一句 → 切自定义 → 切回内置 →
/// 再切自定义（配置还在）。注意 app.main() 只能调一次，所以不能拆成两个用例。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, {int frames = 12}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  Future<void> realWait(WidgetTester tester, int ms) async {
    await tester
        .runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await settle(tester, frames: 4);
  }

  testWidgets('内置 Kilo 生效 + 能切到第三方再切回来', (tester) async {
    app.main();
    await tester.pump();
    await realWait(tester, 3500);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp).first),
      listen: false,
    );

    // ══ 1. 实际生效的配置：必须是内置 Kilo，不是第三方 ══
    var cfg = container.read(aiConfigProvider);
    expect(cfg.providerId, 'kilo', reason: '内置提供商没有被解析出来');
    expect(cfg.baseUrl.contains('kilo'), isTrue,
        reason: '地址被第三方接管了：${cfg.baseUrl}');
    expect(cfg.baseUrl.contains('openai'), isFalse,
        reason: '还在打 OpenAI：${cfg.baseUrl}');
    expect(cfg.model, isNotEmpty);
    expect(cfg.requiresApiKey, isFalse);
    expect(cfg.isConfigured, isTrue, reason: '免 Key 却被判成未配置');

    // ══ 2. 界面上不该再出现「还没配置 AI 接口」 ══
    await tester.tap(find.text('AI 助手'));
    await settle(tester);
    await realWait(tester, 600);

    expect(find.textContaining('还没配置 AI 接口'), findsNothing);
    expect(find.textContaining('kilo ·'), findsOneWidget);

    // ══ 3. 真的发一句，确认请求链路通（不是 401 / 网络错误）══
    container.read(chatErrorProvider.notifier).state = null;

    await tester.enterText(find.byType(TextField).last, '你好，简单回一句就行');
    await settle(tester);
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await settle(tester);

    for (var i = 0; i < 60; i++) {
      await realWait(tester, 1000);
      if (container.read(chatBusyProvider) == false) break;
    }
    expect(container.read(chatErrorProvider), isNull,
        reason: 'AI 请求失败：${container.read(chatErrorProvider)}');

    // ══ 4. 设置页：切到自定义，填三个字段，保存 ══
    await tester.tap(find.text('设置'));
    await settle(tester);
    await realWait(tester, 500);
    await tester.tap(find.text('AI 接口配置'));
    await settle(tester);
    await realWait(tester, 700);
    expect(find.text('AI 助手设置'), findsOneWidget);

    await tester.tap(find.text('自定义'));
    await settle(tester);
    await realWait(tester, 500);

    final urlField = find.widgetWithText(TextField, '接口地址');
    final keyField = find.widgetWithText(TextField, 'API 密钥');
    final modelField = find.widgetWithText(TextField, '模型名称');
    expect(urlField, findsOneWidget, reason: '切到自定义后没出现地址输入框');

    await tester.ensureVisible(urlField);
    await settle(tester);
    await tester.enterText(urlField, 'https://api.example.com/v1');
    await tester.enterText(keyField, 'sk-test-123');
    await tester.enterText(modelField, 'my-model');
    await settle(tester);

    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await settle(tester);
    await realWait(tester, 800);

    cfg = container.read(aiConfigProvider);
    expect(cfg.providerId, 'custom', reason: '选了自定义却没生效（又被回落成内置了）');
    expect(cfg.baseUrl, 'https://api.example.com/v1');
    expect(cfg.model, 'my-model');
    expect(cfg.isConfigured, isTrue);

    // ══ 5. 切回内置 ══
    await tester.tap(find.text('Kilo 免费'));
    await settle(tester);
    await realWait(tester, 500);
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await settle(tester);
    await realWait(tester, 700);

    cfg = container.read(aiConfigProvider);
    expect(cfg.providerId, 'kilo');
    expect(cfg.baseUrl.contains('kilo'), isTrue);

    // ══ 6. 再切回自定义：字段必须还在，且立刻生效（不用重填）══
    await tester.tap(find.text('自定义'));
    await settle(tester);
    await realWait(tester, 500);

    expect(find.text('https://api.example.com/v1'), findsWidgets,
        reason: '切回自定义后地址丢了，等于「切不回第三方」');

    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await settle(tester);
    await realWait(tester, 700);

    cfg = container.read(aiConfigProvider);
    expect(cfg.providerId, 'custom');
    expect(cfg.baseUrl, 'https://api.example.com/v1');
    expect(cfg.model, 'my-model');

    // ══ 7. 收尾：恢复成内置免费模型，别在设备上留一个连不上的第三方配置 ══
    await tester.tap(find.text('Kilo 免费'));
    await settle(tester);
    await realWait(tester, 500);
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await settle(tester);
    await realWait(tester, 700);
    expect(container.read(aiConfigProvider).providerId, 'kilo');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
