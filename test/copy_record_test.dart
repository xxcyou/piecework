import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/data/models/option_item.dart';
import 'package:piecework/data/models/pending_action.dart';
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

/// 复制记录做同款（UI 的「复制这条」+ AI 的 copy_from_ids）
void main() {
  PieceRecord rec() => PieceRecord()
    ..id = 7
    ..styleModel = 'A1023'
    ..color = '黑色'
    ..size = 'M'
    ..unit = '片'
    ..quantity = 300
    ..unitPrice = 0.45
    ..note = '第一批'
    ..photoName = 'c_aaa.jpg'
    ..createdAt = DateTime(2026, 11, 10);

  AiToolExecutor build() => AiToolExecutor(
        host: _Host(),
        records: <PieceRecord>[rec()],
        options: const <OptionKind, List<String>>{},
      );

  test('copy_from_ids 照搬型号/颜色/码数/单价/图片', () async {
    final out = await build().execute('create_records', <String, dynamic>{
      'copy_from_ids': <int>[7],
    });
    expect(out.json['ok'], isTrue);
    final item = out.pendingAction!.items.first;
    expect(item['styleModel'], 'A1023');
    expect(item['color'], '黑色');
    expect(item['size'], 'M');
    expect(item['quantity'], 300);
    expect(item['unitPrice'], 0.45);
    expect(item['photoName'], 'c_aaa.jpg');
    expect(item['unit'], '片');
  });

  test('复制时能覆盖数量和日期', () async {
    final out = await build().execute('create_records', <String, dynamic>{
      'copy_from_ids': <int>[7],
      'set_quantity': 500,
      'set_date': '2026-11-20',
    });
    final item = out.pendingAction!.items.first;
    expect(item['quantity'], 500);
    expect(item['createdAt'], contains('2026-11-20'));
    // 没覆盖的字段仍然照搬
    expect(item['styleModel'], 'A1023');
    expect(item['unitPrice'], 0.45);
  });

  test('复制是「新建」，不是改原记录', () async {
    final out = await build().execute('create_records', <String, dynamic>{
      'copy_from_ids': <int>[7],
    });
    expect(out.pendingAction!.kind, PendingKind.create);
    expect(out.pendingAction!.ids, isEmpty); // 新建不带 ids
    expect(out.pendingAction!.items.length, 1);
  });

  test('id 不存在时不会凭空造一条', () async {
    final out = await build().execute('create_records', <String, dynamic>{
      'copy_from_ids': <int>[999],
    });
    expect(out.json['ok'], isFalse);
    expect(out.json['error'].toString(), contains('items'));
  });
}
