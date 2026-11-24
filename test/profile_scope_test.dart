import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/data/models/option_item.dart';
import 'package:piecework/data/models/piece_record.dart';
import 'package:piecework/data/models/unit_item.dart';
import 'package:piecework/data/models/unit_rule.dart';
import 'package:piecework/data/services/ai_service.dart';
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

/// 多身份隔离：AI 新建/复制的记录必须打到当前身份下
void main() {
  PieceRecord rec(int id, int profileId) => PieceRecord()
    ..id = id
    ..profileId = profileId
    ..styleModel = 'A1'
    ..color = '黑'
    ..size = 'M'
    ..unit = '件'
    ..quantity = 100
    ..unitPrice = 1
    ..note = ''
    ..photoName = ''
    ..createdAt = DateTime(2026, 11, 20);

  AiToolExecutor build(int profileId) => AiToolExecutor(
        host: _Host(),
        // 执行器只拿到「当前身份」的记录（recordsProvider 已过滤）
        records: <PieceRecord>[rec(1, profileId)],
        options: const <OptionKind, List<String>>{},
        profileId: profileId,
        profileName: profileId == 7 ? '张三' : '我',
      );

  test('AI 新建记录带上当前身份 id', () async {
    final out = await build(7).execute('create_records', <String, dynamic>{
      'items': <dynamic>[
        <String, dynamic>{'quantity': 300},
      ],
    });
    expect(out.pendingAction!.items.first['profileId'], 7);
  });

  test('复制同款也打到当前身份', () async {
    final out = await build(7).execute('create_records', <String, dynamic>{
      'copy_from_ids': <int>[1],
    });
    expect(out.pendingAction!.items.first['profileId'], 7);
  });

  test('换一个身份，执行器看到的是另一份数据', () async {
    final mine = build(1);
    final zhang = build(7);
    expect(mine.records.single.profileId, 1);
    expect(zhang.records.single.profileId, 7);
    // 各自查询只命中自己的那一条
    final a = await mine.execute('aggregate_records', <String, dynamic>{});
    final b = await zhang.execute('aggregate_records', <String, dynamic>{});
    expect(a.json['recordCount'], 1);
    expect(b.json['recordCount'], 1);
  });

  test('提示词写明多身份规则', () {
    final p = AiService.defaultSystemPrompt;
    expect(p, contains('多身份'));
    expect(p, contains('当前身份卡'));
    expect(p, contains('切换身份卡'));
  });
}
