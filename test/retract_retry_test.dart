import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/data/models/chat_message.dart';
import 'package:piecework/providers/chat_providers.dart';
import 'package:piecework/ui/widgets/ai_message_bubble.dart';

/// 撤回（真删 + 截断上下文）与发送失败（红色感叹号 + 重试）
void main() {
  ChatMessage msg(int id, String role, String text, {String fail = ''}) =>
      ChatMessage()
        ..id = id
        ..sessionId = 1
        ..role = role
        ..content = text
        ..failReason = fail
        ..createdAt = DateTime(2026, 11, 17, 12, id);

  group('撤回：截断到这条消息之前', () {
    test('删掉这条及其之后的全部消息', () {
      final all = <ChatMessage>[
        msg(1, 'user', '第一条'),
        msg(2, 'assistant', '回答一'),
        msg(3, 'user', '第二条'),
        msg(4, 'assistant', '回答二'),
      ];
      final split = splitForRetract(all, 3);
      expect(split.keep.length, 2);
      expect(split.keep.last.content, '回答一');
      expect(split.removed.length, 2);
      expect(split.removed.first.content, '第二条');
    });

    test('撤回第一条 → 全清空（上下文从头开始）', () {
      final all = <ChatMessage>[
        msg(1, 'user', '第一条'),
        msg(2, 'assistant', '回答一'),
      ];
      final split = splitForRetract(all, 1);
      expect(split.keep, isEmpty);
      expect(split.removed.length, 2);
    });

    test('id 不存在时不动任何东西', () {
      final all = <ChatMessage>[msg(1, 'user', 'a')];
      final split = splitForRetract(all, 99);
      expect(split.keep.length, 1);
      expect(split.removed, isEmpty);
    });
  });

  group('布局', () {
    testWidgets('长消息也不会溢出（IntrinsicWidth 有上限）', (tester) async {
      final m = msg(1, 'user', '很长的消息：' * 60);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: AiMessageBubble(message: m)),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('撤回'), findsOneWidget);
    });
  });

  group('撤回按钮的位置', () {
    testWidgets('在气泡内部的右下角', (tester) async {
      final m = msg(1, 'user', '记一下今天 300 片');
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: AiMessageBubble(message: m)),
          ),
        ),
      );

      // 用胶囊里的文字量位置（图标在胶囊内部靠左，量它会有偏差）
      final chip = tester.getRect(find.text('撤回'));
      final bubble =
          tester.getRect(find.byKey(const ValueKey<String>('user-bubble')));

      // 右：离气泡右边缘很近
      expect(bubble.right - chip.right, lessThan(30)); // 气泡内边距 12 + 胶囊内边距 6
      // 下：在底部
      expect(bubble.bottom - chip.bottom, lessThan(22));
      // 确实在气泡内部靠右
      expect(chip.right, lessThan(bubble.right));
      expect(chip.center.dx, greaterThan(bubble.center.dx));
    });
  });

  group('发送失败：红色感叹号 + 原因 + 重试', () {
    testWidgets('用户消息下面有「撤回」', (tester) async {
      final m = msg(1, 'user', '记一下今天 300 片');
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: AiMessageBubble(message: m)),
          ),
        ),
      );
      expect(find.text('撤回'), findsOneWidget);
      // 撤回是「图标 + 文字」的小胶囊，不是正文
      expect(find.byIcon(Icons.undo_rounded), findsOneWidget);
      expect(find.byIcon(Icons.error), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('失败时显示感叹号，点开能看到原因并重试', (tester) async {
      final m = msg(1, 'user', '记一下今天 300 片',
          fail: '网络连接失败：SocketException: Failed host lookup');
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: AiMessageBubble(message: m)),
          ),
        ),
      );

      expect(find.text('发送失败'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      await tester.tap(find.byIcon(Icons.error_outline));
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed host lookup'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      expect(find.text('关闭'), findsOneWidget);
    });
  });
}
