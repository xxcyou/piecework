import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/data/models/option_item.dart';
import 'package:piecework/data/models/piece_record.dart';
import 'package:piecework/data/models/unit_item.dart';
import 'package:piecework/data/models/unit_rule.dart';
import 'package:piecework/data/services/ai_tool_types.dart';
import 'package:piecework/data/services/ai_tools.dart';

class _Host implements AiToolHost {
  @override
  Future<List<PieceRecord>> loadRecords() async => const <PieceRecord>[];
  @override
  Future<Map<OptionKind, List<String>>> loadOptions() async =>
      <OptionKind, List<String>>{};
  @override
  Future<List<UnitItem>> loadUnits() async => <UnitItem>[];
  @override
  Future<List<UnitRule>> loadUnitRules() async => <UnitRule>[];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// AI 算数必须走计算器：这里验证计算器本身算得对
void main() {
  AiToolExecutor build() => AiToolExecutor(
        host: _Host(),
        records: const <PieceRecord>[],
        options: const <OptionKind, List<String>>{},
      );

  Future<List<Map>> calc(List<String> exprs) async {
    final out = await build().execute('calculator', <String, dynamic>{
      'expressions': exprs,
    });
    return (out.json['results'] as List).cast<Map>();
  }

  test('用户报的那笔账：1150 件 = ¥650（不是 685）', () async {
    final r = await calc(<String>[
      '200+200', // 2301 件数
      '410+340', // 8316 件数
      '400*0.5', // 2301 金额
      '750*0.6', // 8316 金额
      '400*0.5+750*0.6', // 合计金额
      '200+200+410+340', // 合计件数
    ]);
    expect(r[0]['text'], '400');
    expect(r[1]['text'], '750');
    expect(r[2]['text'], '200');
    expect(r[3]['text'], '450');
    expect(r[4]['text'], '650');
    expect(r[5]['text'], '1150');
  });

  test('小数不漂（0.1+0.2）', () async {
    final r = await calc(<String>['0.1+0.2']);
    expect(r.first['text'], '0.3');
  });

  test('乘除与括号', () async {
    final r = await calc(<String>['(120+80)*0.45', '300/2', '1.2*3']);
    expect(r[0]['text'], '90');
    expect(r[1]['text'], '150');
    expect(r[2]['text'], '3.6');
  });

  test('算错/看不懂的算式给明确错误，不瞎编结果', () async {
    final out = await build().execute('calculator', <String, dynamic>{
      'expressions': <String>['1/0', 'abc', '1+'],
    });
    final rs = (out.json['results'] as List).cast<Map>();
    expect(rs.every((e) => e.containsKey('error')), isTrue);
    expect(out.json['ok'], isFalse);
  });

  test('空算式直接报错', () async {
    final out = await build().execute('calculator', <String, dynamic>{
      'expressions': <String>[],
    });
    expect(out.json['ok'], isFalse);
  });

  test('结果同时给一张计算过程卡', () async {
    final out = await build().execute('calculator', <String, dynamic>{
      'expressions': <String>['400*0.5+750*0.6'],
    });
    expect(out.calc, isNotNull);
    expect(out.calc!.steps.first.result, '650');
  });
}
