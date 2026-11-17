import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/providers/chat_providers.dart';
import 'package:piecework/ui/widgets/thinking_header.dart';
import 'package:piecework/ui/widgets/tool_calls_sheet.dart';
import 'package:piecework/ui/widgets/tool_count_chip.dart';

/// 调用工具时的 +1 +2 徽标
void main() {
  test('StreamingState 默认没有工具计数', () {
    const s = StreamingState();
    expect(s.toolCount, 0);
  });

  test('新的一轮不能把累计计数清零（否则 +N 永远看不到）', () {
    final before = const StreamingState(
      content: '上一轮的正文',
      reasoning: '上一轮的思考',
      toolHint: '查询记录',
      toolCount: 2,
    );
    final next = nextTurnState(before);
    expect(next.toolCount, 2); // 计数保留
    expect(next.toolHint, '查询记录'); // 上次调的工具名也保留（空档里有信息）
    expect(next.content, isEmpty); // 正文清空
    expect(next.reasoning, isEmpty);
    // 没有上一轮状态时从 0 开始
    expect(nextTurnState(null).toolCount, 0);
  });

  testWidgets('徽标显示 +N', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: ToolCountChip(count: 3))),
      ),
    );
    expect(find.text('+3'), findsOneWidget);
  });

  group('思考标题行', () {
    testWidgets('还没调工具时只有标题，没有徽标', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ThinkingHeader(hasContent: false, toolCount: 0),
          ),
        ),
      );
      expect(find.text('正在思考…'), findsOneWidget);
      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('调过工具 → 标题右边出现 +N', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ThinkingHeader(hasContent: false, toolCount: 2),
          ),
        ),
      );
      expect(find.text('正在思考…'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      // 徽标在标题右边
      final title = tester.getRect(find.text('正在思考…'));
      final chip = tester.getRect(find.text('+2'));
      expect(chip.left, greaterThan(title.right));
      expect(chip.center.dy, closeTo(title.center.dy, 6));
    });

    testWidgets('开始吐正文时文案变「正在回答…」，计数保留', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ThinkingHeader(hasContent: true, toolCount: 3),
          ),
        ),
      );
      expect(find.text('正在回答…'), findsOneWidget);
      expect(find.text('+3'), findsOneWidget);
    });
  });

  testWidgets('点 +N 弹出「调了哪些工具」清单', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ToolCountChip(
                count: 3,
                onTap: () => showToolCallsSheet(
                  ctx,
                  tools: const <String>['查询记录', '分组汇总', '执行命令'],
                  count: 3,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('+3'));
    await tester.pumpAndSettle();

    expect(find.text('本次调用 3 次工具'), findsOneWidget);
    expect(find.text('查询记录'), findsOneWidget);
    expect(find.text('分组汇总'), findsOneWidget);
    expect(find.text('执行命令'), findsOneWidget);
  });

  testWidgets('不同次数显示不同', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              ToolCountChip(count: 1),
              ToolCountChip(count: 12),
            ],
          ),
        ),
      ),
    );
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('+12'), findsOneWidget);
  });
}
