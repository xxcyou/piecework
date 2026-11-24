import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/data/models/option_item.dart';
import 'package:piecework/data/models/piece_record.dart';
import 'package:piecework/data/models/unit_item.dart';
import 'package:piecework/data/models/unit_rule.dart';
import 'package:piecework/data/services/ai_service.dart';
import 'package:piecework/data/services/ai_tool_types.dart';
import 'package:piecework/data/services/ai_tools.dart';

class _Host implements AiToolHost {
  final List<String> calls = <String>[];
  @override
  Future<List<Map<String, dynamic>>> listProfiles() async => <Map<String, dynamic>>[
        <String, dynamic>{'id': 1, 'name': '我', 'records': 3, 'isDefault': true, 'isActive': true},
        <String, dynamic>{'id': 7, 'name': '张三', 'records': 1, 'isDefault': false, 'isActive': false},
      ];
  @override
  Future<int> createProfile(String name, {String avatar = ''}) async {
    calls.add('create:$name:$avatar');
    return 9;
  }
  @override
  Future<void> renameProfile(int id, String name) async => calls.add('rename:$id:$name');
  @override
  Future<void> switchProfile(int id) async => calls.add('switch:$id');
  @override
  Future<int> copyRecordsToProfile(List<int> ids, int target) async {
    calls.add('copy:${ids.join(",")}->$target');
    return ids.length;
  }

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

  group('AI 管理身份卡', () {
    test('list 返回身份卡清单', () async {
      final out = await build(1).execute('manage_profiles', <String, dynamic>{
        'action': 'list',
      });
      expect(out.json['ok'], isTrue);
      expect((out.json['profiles'] as List).length, 2);
    });

    test('create 带名字和头像', () async {
      final host = _Host();
      final ex = AiToolExecutor(
        host: host,
        records: const <PieceRecord>[],
        options: const <OptionKind, List<String>>{},
        profileId: 1,
      );
      final out = await ex.execute('manage_profiles', <String, dynamic>{
        'action': 'create',
        'name': '李四',
        'avatar': '🐱',
      });
      expect(out.json['ok'], isTrue);
      expect(host.calls, contains('create:李四:🐱'));
    });

    test('create 缺名字 → 明确报错', () async {
      final out = await build(1).execute('manage_profiles', <String, dynamic>{
        'action': 'create',
      });
      expect(out.json['ok'], isFalse);
      expect(out.json['error'].toString(), contains('name'));
    });

    test('copy_records 按 id 复制到目标身份', () async {
      final host = _Host();
      final ex = AiToolExecutor(
        host: host,
        records: <PieceRecord>[rec(1, 1), rec(2, 1)],
        options: const <OptionKind, List<String>>{},
        profileId: 1,
      );
      final out = await ex.execute('manage_profiles', <String, dynamic>{
        'action': 'copy_records',
        'profile_id': 7,
        'record_ids': <int>[1, 2],
      });
      expect(out.json['copied'], 2);
      expect(host.calls, contains('copy:1,2->7'));
    });

    test('copy_records 没给 id 时按筛选条件挑（只在本身份范围内）', () async {
      final host = _Host();
      final ex = AiToolExecutor(
        host: host,
        records: <PieceRecord>[rec(1, 1), rec(2, 1)],
        options: const <OptionKind, List<String>>{},
        profileId: 1,
      );
      final out = await ex.execute('manage_profiles', <String, dynamic>{
        'action': 'copy_records',
        'profile_id': 7,
      });
      expect(out.json['copied'], 2);
    });

    test('switch 调用宿主切换', () async {
      final host = _Host();
      final ex = AiToolExecutor(
        host: host,
        records: const <PieceRecord>[],
        options: const <OptionKind, List<String>>{},
        profileId: 1,
      );
      await ex.execute('manage_profiles', <String, dynamic>{
        'action': 'switch',
        'profile_id': 7,
      });
      expect(host.calls, contains('switch:7'));
    });
  });

  test('提示词写明多身份规则', () {
    final p = AiService.defaultSystemPrompt;
    expect(p, contains('多身份'));
    expect(p, contains('当前身份卡'));
    expect(p, contains('切换身份卡'));
  });
}
