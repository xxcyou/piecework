import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/data/models/option_item.dart';
import 'package:piecework/data/models/piece_record.dart';
import 'package:piecework/data/models/record_filter.dart';
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

/// 回归：筛选参数都应是「可选，不填=不限」
/// 之前 status 默认 pendingOnly，模型漏填就把已上报的记录全过滤掉 → 汇总全空
void main() {
  PieceRecord rec(int qty, {bool reported = false}) {
    final r = PieceRecord()
      ..styleModel = 'A1'
      ..color = ''
      ..size = ''
      ..unit = '件'
      ..quantity = qty
      ..unitPrice = 1
      ..note = ''
      ..photoName = ''
      ..createdAt = DateTime(2026, 11, 18);
    if (reported) r.status = RecordStatus.reported;
    return r;
  }

  AiToolExecutor build(List<PieceRecord> list) => AiToolExecutor(
        host: _Host(),
        records: list,
        options: const <OptionKind, List<String>>{},
      );

  test('status 不传 = 不限（已上报的也算进来）', () async {
    final ex = build(<PieceRecord>[rec(10), rec(20, reported: true)]);
    final out = await ex.execute('aggregate_records', <String, dynamic>{});
    expect(out.json['recordCount'], 2);
    expect(out.json['totalQuantity'], 30);
  });

  test('显式传 pending 才只算未上报', () async {
    final ex = build(<PieceRecord>[rec(10), rec(20, reported: true)]);
    final out = await ex.execute('aggregate_records', <String, dynamic>{
      'status': 'pending',
    });
    expect(out.json['recordCount'], 1);
  });

  test('显式传 reported 只算已上报', () async {
    final ex = build(<PieceRecord>[rec(10), rec(20, reported: true)]);
    final out = await ex.execute('aggregate_records', <String, dynamic>{
      'status': 'reported',
    });
    expect(out.json['recordCount'], 1);
  });

  test('空数组/空字符串视为不限', () async {
    final ex = build(<PieceRecord>[rec(10), rec(20)]);
    final out = await ex.execute('query_records', <String, dynamic>{
      'style_models': <String>[],
      'colors': <String>[],
      'sizes': <String>[''],
    });
    expect(out.json['recordCount'], 2);
  });

  test('筛成 0 条时告诉模型「不加筛选有多少」，别直接说没有', () async {
    final ex = build(<PieceRecord>[rec(10), rec(20)]);
    final out = await ex.execute('query_records', <String, dynamic>{
      'style_models': <String>['不存在的型号'],
    });
    expect(out.json['recordCount'], 0);
    expect(out.json['unfilteredRecordCount'], 2);
    expect(out.json['hint'].toString(), contains('放宽'));
  });

  test('库里真的是空的时候说明原因', () async {
    final ex = build(const <PieceRecord>[]);
    final out = await ex.execute('aggregate_records', <String, dynamic>{});
    expect(out.json['emptyReason'], contains('还没有任何记录'));
  });

  test('statusFilterFromWire: 空值不再默认 pending', () {
    expect(statusFilterFromWire(null), StatusFilter.all);
    expect(statusFilterFromWire(''), StatusFilter.all);
    expect(statusFilterFromWire('pending'), StatusFilter.pendingOnly);
    expect(statusFilterFromWire('reported'), StatusFilter.reportedOnly);
  });
}
