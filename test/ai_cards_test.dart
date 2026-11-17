import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/data/models/chat_message.dart';
import 'package:piecework/data/models/option_item.dart';
import 'package:piecework/data/models/piece_record.dart';
import 'package:piecework/data/services/ai_tool_types.dart';
import 'package:piecework/data/services/ai_tools.dart';
import 'package:piecework/data/services/query_engine.dart';
import 'package:piecework/data/services/unit_converter.dart';
import 'package:piecework/data/models/unit_rule.dart';
import 'package:piecework/data/models/record_filter.dart';
import 'package:piecework/data/services/ai_service.dart';
import 'package:piecework/providers/chat_providers.dart';
import 'package:piecework/ui/widgets/ai_message_bubble.dart';

class _Host implements AiToolHost {
  @override
  Future<List<PieceRecord>> loadRecords() async => const <PieceRecord>[];
  @override
  Future<Map<OptionKind, List<String>>> loadOptions() async =>
      <OptionKind, List<String>>{};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('反问会进上下文（否则 AI 下一轮忘了自己问过什么）', () {
    test('带问题与候选', () {
      final json = jsonEncode(<String, dynamic>{
        'ask': <String, dynamic>{
          'question': '你指的是哪个型号？',
          'options': <dynamic>['A1023', 'B2'],
        },
      });
      final t = askTranscript(json);
      expect(t, contains('你指的是哪个型号'));
      expect(t, contains('A1023'));
      expect(t, isNot(contains('B1023')));
    });

    test('没有 ask 负载时返回 null', () {
      expect(askTranscript(''), isNull);
      expect(askTranscript('{"traces":[]}'), isNull);
      expect(askTranscript('{"ask":{"question":""}}'), isNull);
      expect(askTranscript('not json'), isNull);
    });
  });

  group('单位不许写死「件」', () {
    final ex = AiToolExecutor(
      host: _Host(),
      records: const <PieceRecord>[],
      options: const <OptionKind, List<String>>{},
    );

    ToolTrace traceFor(Map<String, dynamic> json) => ex.buildTraceFor(
          'aggregate_records',
          <String, dynamic>{},
          ToolOutcome(json: json),
          3,
        );

    test('全是「片」时摘要写片', () {
      final t = traceFor(<String, dynamic>{
        'recordCount': 3,
        'totalQuantity': 300,
        'units': <String>['片'],
        'baseUnit': '件',
        'mixedUnits': false,
        'totalAmount': 12.5,
      });
      expect(t.output, contains('300 片'));
      expect(t.output, isNot(contains('300 件')));
    });

    test('单单位但不是基准单位 → 卡片里也带折算值', () {
      final t = traceFor(<String, dynamic>{
        'recordCount': 2,
        'totalQuantity': 300,
        'totalBaseQuantity': 150.0,
        'units': <String>['片'],
        'baseUnit': '件',
        'mixedUnits': false,
        'totalAmount': 135,
      });
      expect(t.output, contains('300 片'));
      expect(t.output, contains('≈ 150 件'));
    });

    test('混单位时用基准单位并标折算', () {
      final t = traceFor(<String, dynamic>{
        'recordCount': 3,
        'totalQuantity': null,
        'totalBaseQuantity': 150.0,
        'units': <String>['片', '件'],
        'baseUnit': '件',
        'mixedUnits': true,
        'totalAmount': 20,
      });
      expect(t.output, contains('折算'));
      expect(t.output, contains('件'));
    });

    test('结果里没 units 时退回 baseUnit（不崩）', () {
      final t = traceFor(<String, dynamic>{
        'recordCount': 1,
        'totalQuantity': 5,
        'totalAmount': 1,
      });
      expect(t.output, contains('5'));
      expect(t.output, contains('条'));
    });
  });

  group('数量描述 quantityText（防止把「片」说成「件」）', () {
    UnitConverter conv2to1() {
      final rule = UnitRule()
        ..fromUnit = '片'
        ..toUnit = '件'
        ..numerator = 1
        ..denominator = 2
        ..styleModel = ''
        ..createdAt = DateTime(2026);
      return UnitConverter(baseUnit: '件', rules: <UnitRule>[rule]);
    }

    PieceRecord rec(String unit, int qty, {double price = 0.45}) => PieceRecord()
      ..styleModel = ''
      ..color = ''
      ..size = ''
      ..unit = unit
      ..quantity = qty
      ..unitPrice = price
      ..note = ''
      ..photoName = ''
      ..createdAt = DateTime(2026, 11, 16);

    test('300 片 + 2片=1件 → 「300 片（≈ 150 件）」', () {
      final res = QueryEngine.apply(
        <PieceRecord>[rec('片', 300)],
        const RecordFilter(),
        converter: conv2to1(),
      );
      expect(res.totalQuantity, 300);
      expect(res.totalBaseQuantity, 150);
      expect(res.quantityText, '300 片（≈ 150 件）');
      expect(res.quantityText, isNot(contains('300 件')));
    });

    test('本来就是件 → 不加折算', () {
      final res = QueryEngine.apply(
        <PieceRecord>[rec('件', 300)],
        const RecordFilter(),
        converter: conv2to1(),
      );
      expect(res.quantityText, '300 件');
    });

    test('混单位 → 用折算值 + 标注原始单位', () {
      final res = QueryEngine.apply(
        <PieceRecord>[rec('片', 100), rec('件', 20)],
        const RecordFilter(),
        converter: conv2to1(),
      );
      expect(res.mixedUnits, isTrue);
      expect(res.quantityText, contains('折算'));
      expect(res.quantityText, contains('件'));
      expect(res.quantityText, contains('片'));
    });
  });

  group('反问卡', () {
    testWidgets('有「跳过」按钮（用户不想回答时用）', (tester) async {
      final msg = ChatMessage()
        ..role = 'assistant'
        ..content = ''
        ..createdAt = DateTime.now()
        ..toolsJson = jsonEncode(<String, dynamic>{
          'ask': <String, dynamic>{
            'question': '你指的是哪个型号？',
            'options': <dynamic>['A1023', 'B2'],
          },
        });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: AiMessageBubble(message: msg)),
          ),
        ),
      );

      expect(find.text('你指的是哪个型号？'), findsOneWidget);
      expect(find.text('A1023'), findsOneWidget);
      expect(find.text('跳过'), findsOneWidget);
      expect(find.byIcon(Icons.fast_forward_rounded), findsOneWidget);
    });

    test('跳过文案明确告诉模型「按默认继续」', () {
      expect(skipAskText, contains('跳过'));
      expect(skipAskText, contains('默认'));
    });

    test('提示词要求「问完就停」且跳过不再问', () {
      final p = AiService.defaultSystemPrompt;
      expect(p, contains('问完就停'));
      expect(p, contains('不要再问'));
    });
  });

  group('计算过程卡要真的画出来', () {
    testWidgets('toolsJson 里有 calc 就渲染卡片', (tester) async {
      final msg = ChatMessage()
        ..role = 'assistant'
        ..content = '本周一共 224 件。'
        ..createdAt = DateTime.now()
        ..toolsJson = jsonEncode(<String, dynamic>{
          'calc': <String, dynamic>{
            'title': '本周件数',
            'steps': <dynamic>[
              <String, dynamic>{
                'label': '周一',
                'expression': '128 + 96',
                'result': '224',
              },
            ],
            'conclusion': '共 224 件',
          },
        });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: AiMessageBubble(message: msg)),
          ),
        ),
      );

      expect(find.text('本周件数'), findsOneWidget);
      expect(find.textContaining('128 + 96'), findsOneWidget);
      expect(find.textContaining('共 224 件'), findsWidgets);
    });
  });
}
