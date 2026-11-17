import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/data/models/chat_message.dart';
import 'package:piecework/data/models/pending_action.dart';
import 'package:piecework/data/models/piece_record.dart';
import 'package:piecework/data/services/ai_tools.dart';
import 'package:piecework/ui/widgets/ai_message_bubble.dart';

/// 「修改前后对比卡片」的数据与渲染
void main() {
  PieceRecord rec(int qty, double price, {String style = 'A1'}) => PieceRecord()
    ..id = 1
    ..styleModel = style
    ..color = '黑色'
    ..size = 'M'
    ..unit = '片'
    ..quantity = qty
    ..unitPrice = price
    ..note = ''
    ..photoName = ''
    ..createdAt = DateTime(2026, 11, 17);

  group('对比数据 buildUpdateDiff', () {
    test('改数量：合计与每条都给出前后值', () {
      final diff = buildUpdateDiff(
        <PieceRecord>[rec(300, 0.45), rec(100, 0.45)],
        <String, dynamic>{'quantity': 350},
      );
      final total = diff.firstWhere((d) => d['label'] == '数量合计');
      expect(total['before'], 400);
      expect(total['after'], 700); // 350 × 2 条
      expect(total['unit'], '片');
      final perItem = diff.firstWhere((d) => d['label'] == '每条数量');
      // 逐条列出：每条记录原来多少 → 改成多少
      final items = perItem['items'] as List;
      expect(items.length, 2);
      expect((items.first as Map)['before'], '300片');
      expect((items.first as Map)['after'], '350片');
      expect((items.first as Map)['label'], contains('A1'));
      // 数量变了，金额也应跟着变
      final amount = diff.firstWhere((d) => d['label'] == '金额合计');
      expect(amount['before'], closeTo(180.0, 0.01)); // 400 × 0.45
      expect(amount['after'], closeTo(315.0, 0.01)); // 700 × 0.45
    });

    test('改单价：给出单价与金额对比', () {
      final diff = buildUpdateDiff(
        <PieceRecord>[rec(100, 0.45)],
        <String, dynamic>{'unitPrice': 0.5},
      );
      final price = diff.firstWhere((d) => d['label'] == '单价');
      expect(price['before'], 0.45);
      expect(price['after'], 0.5);
      expect(price['money'], isTrue);
      final amount = diff.firstWhere((d) => d['label'] == '金额合计');
      expect(amount['before'], closeTo(45.0, 0.01));
      expect(amount['after'], closeTo(50.0, 0.01));
    });

    test('改文字字段：旧 → 新', () {
      final diff = buildUpdateDiff(
        <PieceRecord>[rec(10, 1)],
        <String, dynamic>{'styleModel': 'B2'},
      );
      final row = diff.firstWhere((d) => d['label'] == '型号');
      expect(row['before'], 'A1');
      expect(row['after'], 'B2');
    });

    test('值没变就不显示（不制造噪音）', () {
      final diff = buildUpdateDiff(
        <PieceRecord>[rec(10, 1, style: 'A1')],
        <String, dynamic>{'styleModel': 'A1'},
      );
      expect(diff, isEmpty);
    });

    test('多条记录型号不一致时显示「多个值」', () {
      final diff = buildUpdateDiff(
        <PieceRecord>[rec(10, 1, style: 'A1'), rec(10, 1, style: 'C3')],
        <String, dynamic>{'styleModel': 'B2'},
      );
      final row = diff.firstWhere((d) => d['label'] == '型号');
      expect(row['before'], '多个值');
    });
  });

  group('图片变动的对比', () {
    test('从无图关联到 #1', () {
      final diff = buildPhotoDiff(
        records: <PieceRecord>[rec(300, 0.45), rec(120, 0.45)],
        afterName: 'c_new.jpg',
        detach: false,
      );
      expect(diff.single['label'], '关联图片');
      expect(diff.single['before'], '无图');
      expect(diff.single['photoBefore'], '');
      expect(diff.single['photoAfter'], 'c_new.jpg');
    });

    test('解除关联：原图 → 无图', () {
      final diff = buildPhotoDiff(
        records: <PieceRecord>[
          rec(300, 0.45)..photoName = 'c_a.jpg',
          rec(120, 0.45)..photoName = 'c_a.jpg',
        ],
        afterName: '',
        detach: true,
      );
      expect(diff.single['label'], '解除图片');
      expect(diff.single['after'], '无图');
      expect(diff.single['photoBefore'], 'c_a.jpg');
      expect(diff.single['photoAfter'], '');
    });

    test('原来多张不同时说明清楚', () {
      final diff = buildPhotoDiff(
        records: <PieceRecord>[
          rec(300, 0.45)..photoName = 'c_a.jpg',
          rec(120, 0.45)..photoName = 'c_b.jpg',
        ],
        afterName: 'c_new.jpg',
        detach: false,
      );
      expect(diff.single['before'], contains('多张不同'));
      expect(diff.single['photoBefore'], '');
    });

    test('逐条列出：每条记录是哪条、原来哪张图、改成哪张', () {
      final diff = buildPhotoDiff(
        records: <PieceRecord>[
          rec(300, 0.45, style: 'A1023')..photoName = 'c_a.jpg',
          rec(120, 0.45, style: 'B2'),
        ],
        afterName: 'c_new.jpg',
        detach: false,
      );
      final items = diff.single['items'] as List;
      expect(items.length, 2);
      final first = items.first as Map;
      expect(first['label'], contains('A1023'));
      expect(first['label'], contains('300'));
      expect(first['photoBefore'], 'c_a.jpg');
      expect(first['photoAfter'], 'c_new.jpg');
      final second = items[1] as Map;
      expect(second['label'], contains('B2'));
      expect(second['photoBefore'], '');
      // 编号要先 ensure 才有；没有编号时退回「有图」也算对
      expect(second['after'].toString(), isNotEmpty);
    });
  });

  group('确认卡片渲染对比图', () {
    testWidgets('有 diff 就画「修改前后」和差值', (tester) async {
      final action = PendingAction(
        kind: PendingKind.update,
        description: '修改 1 条记录：数量=350',
        ids: <int>[1],
        changes: <String, dynamic>{'quantity': 350},
        diff: <Map<String, dynamic>>[
          <String, dynamic>{
            'label': '数量合计',
            'before': 300,
            'after': 350,
            'unit': '片',
          },
          <String, dynamic>{
            'label': '金额合计',
            'before': 135.0,
            'after': 157.5,
            'money': true,
          },
        ],
      );
      final msg = ChatMessage()
        ..role = 'assistant'
        ..content = ''
        ..createdAt = DateTime.now()
        ..actionJson = jsonEncode(action.toJson());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: AiMessageBubble(message: msg)),
            ),
          ),
        ),
      );

      expect(find.text('修改前后'), findsOneWidget);
      expect(find.textContaining('300'), findsWidgets);
      expect(find.textContaining('350'), findsWidgets);
      expect(find.text('+50'), findsOneWidget);
      expect(find.text('+¥22.50'), findsOneWidget);
    });

    testWidgets('图片变动画「原 → 新」缩略图', (tester) async {
      final action = PendingAction(
        kind: PendingKind.attachPhoto,
        description: '给 2 条记录关联图库 #1',
        ids: <int>[1, 2],
        photoName: 'c_new.jpg',
        diff: <Map<String, dynamic>>[
          <String, dynamic>{
            'label': '关联图片',
            'before': '无图',
            'after': '有图',
            'photoBefore': '',
            'photoAfter': 'c_new.jpg',
          },
        ],
      );
      final msg = ChatMessage()
        ..role = 'assistant'
        ..content = ''
        ..createdAt = DateTime.now()
        ..actionJson = jsonEncode(action.toJson());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: AiMessageBubble(message: msg)),
            ),
          ),
        ),
      );

      expect(find.text('修改前后'), findsOneWidget);
      expect(find.text('关联图片'), findsOneWidget);
      expect(find.text('无图'), findsOneWidget);
      // 有图那一侧是缩略图（文件不存在时也会渲染占位图标）
      expect(find.byIcon(Icons.image_not_supported_outlined), findsWidgets);
    });
  });
}
