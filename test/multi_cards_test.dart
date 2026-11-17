import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/data/models/chat_message.dart';
import 'package:piecework/data/services/ai_service.dart';
import 'package:piecework/ui/widgets/ai_message_bubble.dart';

/// 同类卡片要能显示多张（3 张图 / 2 张计算过程），不能只剩最后一张
void main() {
  ChatMessage msgWith(Map<String, dynamic> tools) => ChatMessage()
    ..role = 'assistant'
    ..content = '看这几张'
    ..createdAt = DateTime.now()
    ..toolsJson = jsonEncode(tools);

  Future<void> pump(WidgetTester tester, ChatMessage m) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: AiMessageBubble(message: m)),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> calc(String title) => <String, dynamic>{
        'title': title,
        'steps': <dynamic>[
          <String, dynamic>{'label': 'a', 'expression': '1+1', 'result': '2'},
        ],
        'conclusion': '$title 结论',
      };

  testWidgets('3 张计算过程卡全部显示', (tester) async {
    await pump(
      tester,
      msgWith(<String, dynamic>{
        'calcs': <dynamic>[calc('第一张'), calc('第二张'), calc('第三张')],
      }),
    );
    expect(find.text('第一张'), findsOneWidget);
    expect(find.text('第二张'), findsOneWidget);
    expect(find.text('第三张'), findsOneWidget);
  });

  testWidgets('老消息只有单个 calc 也能显示', (tester) async {
    await pump(tester, msgWith(<String, dynamic>{'calc': calc('老卡片')}));
    expect(find.text('老卡片'), findsOneWidget);
  });

  testWidgets('多组图片卡片都渲染', (tester) async {
    await pump(
      tester,
      msgWith(<String, dynamic>{
        'photoGroups': <dynamic>[
          <dynamic>[
            <String, dynamic>{'id': 1, 'label': '#1', 'name': 'a.jpg'},
          ],
          <dynamic>[
            <String, dynamic>{'id': 2, 'label': '#2', 'name': 'b.jpg'},
          ],
        ],
      }),
    );
    expect(find.textContaining('#1'), findsWidgets);
    expect(find.textContaining('#2'), findsWidgets);
  });

  test('提示词要求支持并行与多张卡片', () {
    final p = AiService.defaultSystemPrompt;
    expect(p, contains('并行'));
    expect(p, contains('3 张'));
  });
}
