import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/data/models/app_setting.dart';
import 'package:piecework/data/models/option_item.dart';
import 'package:piecework/data/models/piece_record.dart';
import 'package:piecework/data/models/unit_item.dart';
import 'package:piecework/data/models/unit_rule.dart';
import 'package:piecework/data/services/ai_tool_types.dart';
import 'package:piecework/data/services/ai_tools.dart';

class _Host implements AiToolHost {
  final List<String> log = <String>[];
  final AppSetting setting = AppSetting();

  @override
  Future<AppSetting?> loadSettings() async => setting;

  @override
  Future<void> updateSettings(void Function(AppSetting s) fn) async => fn(setting);
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

/// AI 报表草稿：可以塞虚构数据，但不写进计件记录
void main() {
  PieceRecord rec(int qty, double price, String style) => PieceRecord()
    ..styleModel = style
    ..color = '黑'
    ..size = 'M'
    ..unit = '件'
    ..quantity = qty
    ..unitPrice = price
    ..note = ''
    ..photoName = ''
    ..createdAt = DateTime(2026, 11, 20);

  AiToolExecutor build({List<PieceRecord>? records}) => AiToolExecutor(
        host: _Host(),
        records: records ?? const <PieceRecord>[],
        options: const <OptionKind, List<String>>{},
        profileId: 1,
        profileName: '张三',
      );

  test('只用虚拟行生成报表：给出表格与合计，且不产生待确认写操作', () async {
    final out = await build().execute('build_report_draft', <String, dynamic>{
      'title': '11 月工资表',
      'mode': 'financial',
      'rows': <dynamic>[
        <String, dynamic>{'style_model': 'A1023', 'quantity': 300, 'unit_price': 0.45},
        <String, dynamic>{'style_model': 'B2087', 'quantity': 120, 'unit_price': 1.2},
      ],
    });
    expect(out.json['ok'], isTrue);
    expect(out.json['rowCount'], 2);
    expect(out.json['totalText'], '279.00'); // 135 + 144
    expect(out.json['note'].toString(), contains('没有写入'));
    // 关键：没有写操作提议
    expect(out.pendingAction, isNull);
    expect(out.calc, isNotNull);
  });

  test('财务模式按型号汇总（同型号不同单价合并，单价显示不一）', () async {
    final out = await build().execute('build_report_draft', <String, dynamic>{
      'mode': 'financial',
      'rows': <dynamic>[
        <String, dynamic>{'style_model': 'A1', 'quantity': 100, 'unit_price': 0.5},
        <String, dynamic>{'style_model': 'A1', 'quantity': 100, 'unit_price': 0.6},
      ],
    });
    expect(out.json['rowCount'], 1);
    expect(out.json['totalText'], '110.00');
    final rows = out.json['rows'] as List;
    expect((rows.first as Map)['unitPrice'], '不一');
  });

  test('审计模式逐条列出', () async {
    final out = await build().execute('build_report_draft', <String, dynamic>{
      'mode': 'audit',
      'rows': <dynamic>[
        <String, dynamic>{'style_model': 'A1', 'quantity': 10, 'unit_price': 1},
        <String, dynamic>{'style_model': 'A1', 'quantity': 20, 'unit_price': 1},
      ],
    });
    expect(out.json['rowCount'], 2);
    expect(out.json['totalText'], '30.00');
  });

  test('可以把真实记录并进来（但不改库）', () async {
    final out = await build(records: <PieceRecord>[rec(100, 0.5, 'R1')])
        .execute('build_report_draft', <String, dynamic>{
      'mode': 'financial',
      'include_records': true,
      'rows': <dynamic>[
        <String, dynamic>{'style_model': 'X9', 'quantity': 50, 'unit_price': 1},
      ],
    });
    expect(out.json['rowCount'], 2);
    expect(out.json['realRows'], 1);
    expect(out.json['virtualRows'], 1);
    expect(out.json['totalText'], '100.00'); // 50 + 50
  });

  test('一行都没有 → 明确报错，不生成空表', () async {
    final out = await build().execute('build_report_draft', <String, dynamic>{});
    expect(out.json['ok'], isFalse);
    expect(out.json['error'].toString(), contains('rows'));
  });

  test('AI 能切工作模式（update_settings.work_mode）', () async {
    final host = _Host();
    final ex = AiToolExecutor(
      host: host,
      records: const <PieceRecord>[],
      options: const <OptionKind, List<String>>{},
      profileId: 1,
    );
    final out = await ex.execute('update_settings', <String, dynamic>{
      'work_mode': 'audit',
    });
    expect(out.json['ok'], isTrue);
    expect((out.json['applied'] as Map?)?['workMode'], 'audit');
  });

  test('草稿里带结构化行，前端可直接渲染报表', () async {
    final out = await build().execute('build_report_draft', <String, dynamic>{
      'title': '11 月工资表',
      'mode': 'financial',
      'rows': <dynamic>[
        <String, dynamic>{'style_model': 'A1', 'quantity': 300, 'unit_price': 0.5},
      ],
    });
    final draft = out.reportDraft!;
    expect(draft['title'], '11 月工资表');
    expect(draft['mode'], 'financial');
    final rows = draft['rows'] as List;
    final row = rows.first as Map;
    expect(row['styleModel'], 'A1');
    expect(row['quantity'], 300);
    expect(row['unitPrice'], 0.5);
    expect(row['amountMilli'], 150000); // 300 × 0.5 = 150 元
  });

  test('数量 0 的行被丢掉（避免脏数据）', () async {
    final out = await build().execute('build_report_draft', <String, dynamic>{
      'rows': <dynamic>[
        <String, dynamic>{'style_model': 'A1', 'quantity': 0},
        <String, dynamic>{'style_model': 'A2', 'quantity': 5, 'unit_price': 2},
      ],
    });
    expect(out.json['rowCount'], 1);
    expect(out.json['totalText'], '10.00');
  });
}
