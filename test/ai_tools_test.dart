import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/data/models/app_setting.dart';
import 'package:piecework/data/models/option_item.dart';
import 'package:piecework/data/models/operation_log.dart';
import 'package:piecework/data/models/pending_action.dart';
import 'package:piecework/data/models/piece_record.dart';
import 'package:piecework/data/models/record_filter.dart';
import 'package:piecework/data/models/unit_item.dart';
import 'package:piecework/data/models/unit_rule.dart';
import 'package:piecework/data/services/ai_tool_types.dart';
import 'package:piecework/data/services/ai_tools.dart';

/// 记录 AI 对 App 做了什么，用来断言
class FakeHost implements AiToolHost {
  FakeHost({List<PieceRecord>? records}) : _records = records ?? <PieceRecord>[];

  final List<PieceRecord> _records;
  final AppSetting setting = AppSetting();
  final List<String> log = <String>[];
  final List<UnitItem> units = <UnitItem>[];
  final List<UnitRule> rules = <UnitRule>[];
  final Map<OptionKind, List<String>> options = <OptionKind, List<String>>{
    OptionKind.styleModel: <String>['A1023'],
    OptionKind.color: <String>['黑色'],
    OptionKind.size: <String>['M'],
  };

  @override
  Future<List<PieceRecord>> loadRecords() async => _records;

  @override
  Future<Map<OptionKind, List<String>>> loadOptions() async => options;

  @override
  Future<AppSetting?> loadSettings() async => setting;

  @override
  Future<void> updateSettings(void Function(AppSetting s) fn) async {
    fn(setting);
    log.add('updateSettings');
  }

  @override
  Future<bool> addOption(OptionKind kind, String value) async {
    options[kind] = <String>[...?options[kind], value];
    log.add('addOption:$value');
    return true;
  }

  @override
  Future<void> removeOption(OptionKind kind, String value) async {
    options[kind] = <String>[...?options[kind]]..remove(value);
    log.add('removeOption:$value');
  }

  @override
  Future<List<UnitItem>> loadUnits() async => units;

  @override
  Future<List<UnitRule>> loadUnitRules() async => rules;

  @override
  Future<bool> addUnit(String name) async {
    final u = UnitItem();
    u.name = name;
    u.isBase = false;
    u.sortOrder = units.length;
    u.createdAt = DateTime(2026);
    units.add(u);
    log.add('addUnit:$name');
    return true;
  }

  @override
  Future<void> removeUnit(String name) async {
    units.removeWhere((u) => u.name == name);
    log.add('removeUnit:$name');
  }

  @override
  Future<void> setBaseUnit(String name) async {
    for (final u in units) {
      u.isBase = u.name == name;
    }
    log.add('setBase:$name');
  }

  @override
  Future<String?> copyChatPhotoToRecords(String chatPhotoName) async {
    log.add('copyPhoto:$chatPhotoName');
    return 'copied_$chatPhotoName';
  }

  // ── 身份卡（测试桩）──
  final List<Map<String, dynamic>> profiles = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 1,
      'name': '我',
      'avatar': '👷',
      'records': 3,
      'isDefault': true,
      'isActive': true,
      'archived': false,
    },
    <String, dynamic>{
      'id': 2,
      'name': '张三',
      'avatar': '🐱',
      'records': 1,
      'isDefault': false,
      'isActive': false,
      'archived': false,
    },
  ];
  final List<String> profileLog = <String>[];

  @override
  Future<List<Map<String, dynamic>>> listProfiles() async => profiles;

  @override
  Future<int> createProfile(String name, {String avatar = ''}) async {
    profileLog.add('create:$name:$avatar');
    return 9;
  }

  @override
  Future<void> renameProfile(int id, String name) async {
    profileLog.add('rename:$id:$name');
  }

  @override
  Future<void> switchProfile(int id) async {
    profileLog.add('switch:$id');
  }

  @override
  Future<int> copyRecordsToProfile(List<int> ids, int targetProfileId) async {
    profileLog.add('copy:${ids.join(",")}->$targetProfileId');
    return ids.length;
  }

  final List<OperationLog> ops = <OperationLog>[];
  final List<PieceRecord> deletedList = <PieceRecord>[];

  @override
  Future<List<OperationLog>> loadOperations({int limit = 10}) async =>
      ops.take(limit).toList();

  @override
  Future<bool> undoOperation(int logId) async {
    log.add('undo:$logId');
    return true;
  }

  @override
  Future<List<PieceRecord>> loadDeleted() async => deletedList;

  @override
  Future<int> restoreDeleted(List<int> ids) async {
    log.add('restore:${ids.length}');
    return ids.length;
  }

  @override
  Future<void> saveUnitRule({
    required String fromUnit,
    required String toUnit,
    required int numerator,
    required int denominator,
    String styleModel = '',
  }) async {
    final r = UnitRule();
    r.fromUnit = fromUnit;
    r.toUnit = toUnit;
    r.numerator = numerator;
    r.denominator = denominator;
    r.styleModel = styleModel;
    r.createdAt = DateTime(2026);
    rules.add(r);
    log.add('rule:$denominator$fromUnit=$numerator$toUnit');
  }
}

PieceRecord rec({
  String style = 'A1023',
  String color = '黑色',
  String size = 'M',
  int qty = 10,
  double price = 12.5,
  DateTime? at,
}) {
  final r = PieceRecord();
  r.styleModel = style;
  r.color = color;
  r.size = size;
  r.quantity = qty;
  r.unitPrice = price;
  r.note = '';
  r.photoName = '';
  r.createdAt = at ?? DateTime.now();
  return r;
}


PieceRecord _rec({
  required int qty,
  double price = 0,
  String style = '',
  String color = '',
  String size = '',
}) {
  final r = PieceRecord();
  r.styleModel = style;
  r.color = color;
  r.size = size;
  r.unit = '件';
  r.quantity = qty;
  r.unitPrice = price;
  r.note = '';
  r.photoName = '';
  r.createdAt = DateTime(2026, 11, 13, 9);
  return r;
}

void main() {
  final now = DateTime.now();

  AiToolExecutor build(List<PieceRecord> records, FakeHost host) =>
      AiToolExecutor(
        host: host,
        records: records,
        options: host.options,
      );

  group('设置类工具', () {
    test('get_settings 返回完整设置快照', () async {
      final host = FakeHost();
      host.setting.themeModeIndex = 2;
      host.setting.reportTitle = '我的报表';
      final ex = build(<PieceRecord>[], host);

      final out = await ex.execute('get_settings', <String, dynamic>{});
      expect(out.json['ok'], isTrue);
      expect(out.json['theme'], 'dark');
      expect(out.json['reportTitle'], '我的报表');
      expect(out.trace, isNotNull);
      expect(out.trace!.label, '读取设置');
    });

    test('update_settings 主题/模板/分组立即生效', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);

      final out = await ex.execute('update_settings', <String, dynamic>{
        'theme': 'light',
        'report_template': 'compact',
        'report_group': 'styleModel',
        'report_font_scale': 1.3,
      });

      expect(out.json['ok'], isTrue);
      expect(host.setting.themeModeIndex, 1);
      expect(host.setting.reportTemplate, 1);
      expect(host.setting.reportGroupBy, 1);
      expect(host.setting.reportFontScale, 1.3);
    });

    test('update_settings 空参数不报错', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      final out = await ex.execute('update_settings', <String, dynamic>{});
      expect(out.json['ok'], isFalse);
      expect(out.json['message'], '没有可应用的设置项');
    });
  });

  group('单位与选项工具', () {
    test('manage_units 新增单位', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      final out = await ex.execute('manage_units', <String, dynamic>{
        'action': 'add',
        'name': '套',
      });
      expect(out.json['ok'], isTrue);
      expect(host.log, contains('addUnit:套'));
    });

    test('set_unit_rule 写入 100 片 = 30 件', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      final out = await ex.execute('set_unit_rule', <String, dynamic>{
        'from_unit': '片',
        'to_unit': '件',
        'numerator': 30,
        'denominator': 100,
      });
      expect(out.json['ok'], isTrue);
      expect(host.rules.single.numerator, 30);
      expect(host.rules.single.denominator, 100);
      expect(host.rules.single.factor, 0.3);
    });

    test('set_unit_rule 分母为 0 被拒绝', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      final out = await ex.execute('set_unit_rule', <String, dynamic>{
        'from_unit': '片',
        'to_unit': '件',
        'numerator': 30,
        'denominator': 0,
      });
      expect(out.json['ok'], isFalse);
      expect(host.rules, isEmpty);
    });

    test('manage_options 新增颜色', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      final out = await ex.execute('manage_options', <String, dynamic>{
        'action': 'add',
        'kind': 'color',
        'value': '藏青',
      });
      expect(out.json['ok'], isTrue);
      expect(host.options[OptionKind.color], contains('藏青'));
    });
  });

  group('查询增强工具', () {
    final data = <PieceRecord>[
      rec(style: 'A1023', qty: 30, price: 10, at: now),
      rec(style: 'A1023', qty: 20, price: 10, at: now),
      rec(style: 'B2001', qty: 5, price: 20, at: now),
    ];

    test('top_n 按件数排第一是 A1023', () async {
      final host = FakeHost();
      final ex = build(data, host);
      final out = await ex.execute('top_n', <String, dynamic>{
        'dimension': 'styleModel',
        'metric': 'quantity',
        'limit': 5,
        'date_preset': 'all',
      });
      expect(out.json['ok'], isTrue);
      final ranking = out.json['ranking'] as List;
      expect(ranking.length, 2);
      expect((ranking.first as Map)['key'], 'A1023');
      expect((ranking.first as Map)['quantity'], 50);
    });

    test('top_n 按金额排第一是 B2001', () async {
      final host = FakeHost();
      final ex = build(data, host);
      final out = await ex.execute('top_n', <String, dynamic>{
        'dimension': 'styleModel',
        'metric': 'amount',
        'date_preset': 'all',
      });
      final ranking = out.json['ranking'] as List;
      // A1023: 500 元；B2001: 100 元
      expect((ranking.first as Map)['key'], 'A1023');
    });

    test('apply_filter 产生跳转动作', () async {
      final host = FakeHost();
      final ex = build(data, host);
      final out = await ex.execute('apply_filter', <String, dynamic>{
        'style_models': <String>['A1023'],
        'date_preset': 'all',
      });
      expect(out.json['ok'], isTrue);
      expect(out.uiActions.length, 1);
      expect(out.uiActions.single.kind, UiActionKind.applyFilter);
      expect(out.uiActions.single.filter!.styleModels, contains('A1023'));
      expect(out.uiActions.single.label, contains('2 条'));
    });

    test('open_page 产生页面动作', () async {
      final host = FakeHost();
      final ex = build(data, host);
      final out = await ex.execute('open_page', <String, dynamic>{
        'page': 'report',
      });
      expect(out.uiActions.single.kind, UiActionKind.openPage);
      expect(out.uiActions.single.target, 'report');
      expect(out.uiActions.single.label, '打开报表页');
    });

    test('compare_periods 给出增减', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[
        rec(qty: 10, price: 10, at: now), // 今天
        rec(qty: 5, price: 10, at: now.subtract(const Duration(days: 1))),
      ], host);

      final out = await ex.execute('compare_periods', <String, dynamic>{
        'period_a': 'today',
        'period_b': 'yesterday',
      });
      expect(out.json['ok'], isTrue);
      expect((out.json['a'] as Map)['quantity'], 10);
      expect((out.json['b'] as Map)['quantity'], 5);
      expect((out.json['delta'] as Map)['quantity'], 5);
    });

    test('每个工具都会产出 trace', () async {
      final host = FakeHost();
      final ex = build(data, host);
      for (final name in <String>[
        'query_records',
        'aggregate_records',
        'list_available_options',
        'get_settings',
        'top_n',
        'open_page',
      ]) {
        final out = await ex.execute(name, <String, dynamic>{'date_preset': 'all'});
        expect(out.trace, isNotNull, reason: '$name 缺 trace');
        expect(out.trace!.label, isNotEmpty, reason: '$name label 为空');
      }
    });
  });

  group('图片关联', () {
    test('带图提问时 create_records 自动关联图片', () async {
      final host = FakeHost();
      final ex = AiToolExecutor(
        host: host,
        records: const <PieceRecord>[],
        options: host.options,
        contextPhotoName: 'chat_001.jpg',
      );

      final out = await ex.execute('create_records', <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'style_model': 'A1023',
            'quantity': 30,
            'unit_price': 12.0,
          },
        ],
      });

      final items = out.pendingAction!.items;
      expect(items.single['photoName'], 'chat_001.jpg');
    });

    test('不带图时 photoName 为空', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      final out = await ex.execute('create_records', <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'style_model': 'A1023',
            'quantity': 30,
            'unit_price': 12.0,
          },
        ],
      });
      expect(out.pendingAction!.items.single['photoName'], '');
    });

    test('attach_photo=false 时不关联', () async {
      final host = FakeHost();
      final ex = AiToolExecutor(
        host: host,
        records: const <PieceRecord>[],
        options: host.options,
        contextPhotoName: 'chat_001.jpg',
      );
      final out = await ex.execute('create_records', <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'style_model': 'A1023',
            'quantity': 30,
            'unit_price': 12.0,
            'attach_photo': false,
          },
        ],
      });
      expect(out.pendingAction!.items.single['photoName'], '');
    });

    test('manage_photos attach 生成待确认动作', () async {
      final host = FakeHost();
      final ex = AiToolExecutor(
        host: host,
        records: <PieceRecord>[rec(style: 'A1023')],
        options: host.options,
        contextPhotoName: 'chat_002.jpg',
      );
      final out = await ex.execute('manage_photos', <String, dynamic>{
        'action': 'attach',
        'date_preset': 'all',
      });
      expect(out.pendingAction!.kind, PendingKind.attachPhoto);
      expect(out.pendingAction!.photoName, 'chat_002.jpg');
      expect(out.pendingAction!.affectedCount, 1);
    });

    test('manage_photos attach 但没带图时明确报错', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[rec()], host);
      final out = await ex.execute('manage_photos', <String, dynamic>{
        'action': 'attach',
        'date_preset': 'all',
      });
      expect(out.json['ok'], isFalse);
      // 现在会提示三种指定方式，而不是简单说「没有图片」
      expect(out.json['error'], contains('photo_id'));
      expect(out.json['error'], contains('photo_name'));
    });

    test('manage_photos detach 只挑有图的记录', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[
        rec(style: 'A1')..photoName = 'a.jpg',
        rec(style: 'A2'),
      ], host);
      final out = await ex.execute('manage_photos', <String, dynamic>{
        'action': 'detach',
        'date_preset': 'all',
      });
      expect(out.pendingAction!.kind, PendingKind.detachPhoto);
      expect(out.pendingAction!.affectedCount, 1);
    });

    test('manage_photos detach 全都没图时报错', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[rec()], host);
      final out = await ex.execute('manage_photos', <String, dynamic>{
        'action': 'detach',
        'date_preset': 'all',
      });
      expect(out.json['ok'], isFalse);
      expect(out.json['error'], contains('本来就没有照片'));
    });
  });

  group('展示类卡片', () {
    test('render_svg 生成图块', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      final out = await ex.execute('render_svg', <String, dynamic>{
        'title': '型号占比',
        'svg': '<svg viewBox="0 0 100 100"><rect width="10" height="10"/></svg>',
      });
      expect(out.svg, isNotNull);
      expect(out.svg!.title, '型号占比');
      expect(out.svg!.svg.startsWith('<svg'), isTrue);
    });

    test('render_svg 拒绝非 SVG 与超大内容', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);

      final bad = await ex.execute('render_svg', <String, dynamic>{
        'title': 'x',
        'svg': '<div>not svg</div>',
      });
      expect(bad.json['ok'], isFalse);

      final big = await ex.execute('render_svg', <String, dynamic>{
        'title': 'x',
        'svg': '<svg>${'a' * 30000}</svg>',
      });
      expect(big.json['ok'], isFalse);
      expect(big.json['error'], contains('太大'));
    });

    test('show_calculation 生成步骤表', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      final out = await ex.execute('show_calculation', <String, dynamic>{
        'title': '折算过程',
        'steps': <Map<String, String>>[
          <String, String>{
            'label': '白色 4 条',
            'expression': '67+67+69+71',
            'result': '274 件',
          },
          <String, String>{
            'label': '粉色 4 条折算',
            'expression': '276×4×0.5',
            'result': '552 件',
          },
        ],
        'conclusion': '合计 826 件',
      });
      expect(out.calc, isNotNull);
      expect(out.calc!.steps.length, 2);
      expect(out.calc!.conclusion, '合计 826 件');
    });

    test('show_calculation 空步骤被拒', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      final out = await ex.execute('show_calculation', <String, dynamic>{
        'title': 'x',
        'steps': <Map<String, String>>[],
      });
      expect(out.json['ok'], isFalse);
    });

    test('show_code 生成代码块', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      final out = await ex.execute('show_code', <String, dynamic>{
        'title': '查询本月',
        'language': 'sql',
        'code': 'SELECT SUM(quantity) FROM records WHERE month = 11;',
      });
      expect(out.code, isNotNull);
      expect(out.code!.language, 'sql');
      expect(out.code!.code, contains('SELECT'));
    });

    test('三种卡片 JSON 往返', () {
      final svg = SvgBlock.fromJson(
        const SvgBlock(title: 't', svg: '<svg></svg>').toJson(),
      );
      expect(svg!.title, 't');

      final calc = CalcTable.fromJson(
        const CalcTable(
          title: 'c',
          steps: <CalcStep>[
            CalcStep(label: 'a', expression: '1+1', result: '2'),
          ],
        ).toJson(),
      );
      expect(calc!.steps.single.result, '2');

      final code = CodeBlock.fromJson(
        const CodeBlock(title: 'x', language: 'bash', code: 'ls -la').toJson(),
      );
      expect(code!.code, 'ls -la');
    });
  });

  group('单位混算防护', () {
    test('混单位时 totalQuantity 置空，均价走 base', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[
        rec(style: 'A1', qty: 100, price: 0.01)..unit = '片',
        rec(style: 'A1', qty: 10, price: 12.0)..unit = '件',
      ], host);

      final out = await ex.execute('aggregate_records', <String, dynamic>{
        'date_preset': 'all',
        'status': 'all',
      });

      final auth = out.json['authoritative'] as Map;
      expect(auth['mixedUnits'], true);
      // 关键：跨单位时不能再给裸和
      expect(auth['totalQuantity'], isNull);
      expect((auth['units'] as List), containsAll(<String>['件', '片']));
      // 均价按折算后的基准单位算：(1 + 120) / 110
      expect((auth['averagePricePerBaseUnit'] as num), closeTo(1.1, 1e-6));
    });

    test('单一单位时 totalQuantity 正常可用', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[
        rec(style: 'A1', qty: 20, price: 10),
        rec(style: 'A2', qty: 30, price: 10),
      ], host);

      final out = await ex.execute('query_records', <String, dynamic>{
        'date_preset': 'all',
        'status': 'all',
      });
      final auth = out.json['authoritative'] as Map;
      expect(auth['mixedUnits'], false);
      expect(auth['totalQuantity'], 50);
    });

    test('query_records 也带混单位标记', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[
        rec(qty: 5, price: 1)..unit = '打',
        rec(qty: 5, price: 1)..unit = '件',
      ], host);
      final out = await ex.execute('query_records', <String, dynamic>{
        'date_preset': 'all',
        'status': 'all',
      });
      final auth = out.json['authoritative'] as Map;
      expect(auth['mixedUnits'], true);
      expect(auth['totalQuantity'], isNull);
    });
  });

  group('业务工具增强', () {
    test('find_duplicates 找出同日同规格同数量', () async {
      final host = FakeHost();
      final day = DateTime(2026, 11, 13, 10);
      final ex = build(<PieceRecord>[
        rec(style: 'A1', qty: 20, at: day),
        rec(style: 'A1', qty: 20, at: day),
        rec(style: 'A2', qty: 30, at: day),
      ], host);

      final out = await ex.execute('find_duplicates', <String, dynamic>{
        'date_preset': 'all',
        'status': 'all',
      });
      expect(out.json['ok'], isTrue);
      expect(out.json['duplicateGroups'], 1);
      expect(out.json['duplicateRecords'], 2);
    });

    test('check_anomalies 报缺图与未上报', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[
        rec(qty: 10, at: DateTime.now().subtract(const Duration(days: 10))),
        rec(qty: 10, at: DateTime.now())..photoName = 'a.jpg',
      ], host);

      final out = await ex.execute('check_anomalies', <String, dynamic>{
        'stale_days': 7,
      });
      final issues = out.json['issues'] as Map;
      expect(issues['noPhoto'], 1);
      expect(issues['stalePending'], 1);
    });

    test('predict_income 给出日均与本月预估', () async {
      final host = FakeHost();
      final now = DateTime.now();
      final ex = build(<PieceRecord>[
        rec(qty: 10, price: 10, at: now),
        rec(qty: 10, price: 10, at: now),
      ], host);

      final out = await ex.execute('predict_income', <String, dynamic>{
        'lookback_days': 7,
      });
      expect(out.json['ok'], isTrue);
      expect((out.json['averagePerDay'] as num) > 0, isTrue);
      expect((out.json['predictedMonthTotal'] as num) > 0, isTrue);
    });

    test('unit_convert 100 片 = 50 件', () async {
      final host = FakeHost();
      host.units.addAll(<UnitItem>[
        () {
          final u = UnitItem();
          u.name = '件';
          u.isBase = true;
          u.sortOrder = 0;
          u.createdAt = DateTime(2026);
          return u;
        }(),
        () {
          final u = UnitItem();
          u.name = '片';
          u.isBase = false;
          u.sortOrder = 1;
          u.createdAt = DateTime(2026);
          return u;
        }(),
      ]);
      host.rules.add(() {
        final r = UnitRule();
        r.fromUnit = '片';
        r.toUnit = '件';
        r.numerator = 50;
        r.denominator = 100;
        r.styleModel = '';
        r.createdAt = DateTime(2026);
        return r;
      }());

      final ex = build(<PieceRecord>[], host);
      final out = await ex.execute('unit_convert', <String, dynamic>{
        'quantity': 100,
        'from_unit': '片',
        'to_unit': '件',
      });
      expect(out.json['ok'], isTrue);
      expect(out.json['result'], 50.0);
    });

    test('list_operations 返回历史', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      final out = await ex.execute('list_operations', <String, dynamic>{});
      expect(out.json['ok'], isTrue);
      expect(out.json['count'], 0);
    });

    test('undo_operation 没日志时明确报错', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      final out = await ex.execute('undo_operation', <String, dynamic>{});
      expect(out.json['ok'], isFalse);
    });

    test('restore_records 回收站为空时报错', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      final out = await ex.execute('restore_records', <String, dynamic>{});
      expect(out.json['ok'], isFalse);
      expect(out.json['error'], contains('回收站是空的'));
    });

    test('export_report 生成跳转动作', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[rec()], host);
      final out = await ex.execute('export_report', <String, dynamic>{
        'format': 'png',
        'date_preset': 'all',
      });
      expect(out.uiActions.single.target, 'report');
      expect(out.uiActions.single.label, contains('报表'));
    });

    test('删除确认卡带前 5 条预览', () async {
      final host = FakeHost();
      final ex = build(
        List<PieceRecord>.generate(8, (i) => rec(style: 'S$i', qty: 10)),
        host,
      );
      final out = await ex.execute('delete_records', <String, dynamic>{
        'date_preset': 'all',
        'status': 'all',
        'reason': '测试',
      });
      expect(out.pendingAction!.preview.length, 5);
      expect(out.pendingAction!.affectedCount, 8);
    });
  });

  group('反问工具（信息不足时）', () {
    test('ask_user 生成问题与可点选项', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);

      final out = await ex.execute('ask_user', <String, dynamic>{
        'question': '这条记录是什么型号？',
        'options': <String>['A1023', 'B2001', '新建型号'],
        'why': '型号是必填项',
      });

      expect(out.ask, isNotNull);
      expect(out.ask!.question, '这条记录是什么型号？');
      expect(out.ask!.options.length, 3);
      expect(out.ask!.why, '型号是必填项');
      expect(out.trace!.label, '向用户提问');
      expect(out.json['optionCount'], 3);
    });

    test('空问题被拒绝', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      final out = await ex.execute('ask_user', <String, dynamic>{
        'question': '   ',
      });
      expect(out.json['ok'], isFalse);
      expect(out.ask, isNull);
    });

    test('选项最多保留 6 个', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      final out = await ex.execute('ask_user', <String, dynamic>{
        'question': '选一个',
        'options': List<String>.generate(10, (i) => '选项$i'),
      });
      expect(out.ask!.options.length, 6);
    });

    test('AskPrompt JSON 往返', () {
      const a = AskPrompt(
        question: '哪批记录？',
        options: <String>['本周', '上周'],
        why: '指代不明',
      );
      final back = AskPrompt.fromJson(a.toJson())!;
      expect(back.question, '哪批记录？');
      expect(back.options.length, 2);
      expect(back.why, '指代不明');
    });

    test('脏 JSON 返回 null', () {
      expect(AskPrompt.fromJson(null), isNull);
      expect(AskPrompt.fromJson(<String, dynamic>{'question': ''}), isNull);
    });
  });

  group('Agent 执行协议', () {
    test('plan_task 建立计划，首步自动 running', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);

      final out = await ex.execute('plan_task', <String, dynamic>{
        'goal': '整理本月账目',
        'steps': <Map<String, String>>[
          <String, String>{'id': 's1', 'title': '查询本月记录'},
          <String, String>{'id': 's2', 'title': '按型号汇总'},
          <String, String>{'id': 's3', 'title': '核对总计'},
        ],
      });

      final task = out.agentTask!;
      expect(task.goal, '整理本月账目');
      expect(task.steps.length, 3);
      expect(task.steps.first.status, AgentStepStatus.running);
      expect(task.steps[1].status, AgentStepStatus.pending);
      expect(task.progress, 0);
    });

    test('step_done 推进进度并自动激活下一步', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      await ex.execute('plan_task', <String, dynamic>{
        'goal': 'G',
        'steps': <Map<String, String>>[
          <String, String>{'id': 's1', 'title': 'A'},
          <String, String>{'id': 's2', 'title': 'B'},
        ],
      });

      final out = await ex.execute('step_done', <String, dynamic>{
        'step_id': 's1',
        'result': '42 条 · 1,280 件',
      });

      final task = out.agentTask!;
      expect(task.steps[0].status, AgentStepStatus.done);
      expect(task.steps[0].detail, '42 条 · 1,280 件');
      expect(task.steps[1].status, AgentStepStatus.running);
      expect(task.doneCount, 1);
      expect(task.progress, closeTo(0.5, 1e-9));
    });

    test('finish_task 收口：全部置 done + 带后续建议', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      await ex.execute('plan_task', <String, dynamic>{
        'goal': 'G',
        'steps': <Map<String, String>>[
          <String, String>{'id': 's1', 'title': 'A'},
          <String, String>{'id': 's2', 'title': 'B'},
        ],
      });
      await ex.execute('step_done', <String, dynamic>{
        'step_id': 's1',
        'result': 'done',
      });

      final out = await ex.execute('finish_task', <String, dynamic>{
        'summary': '合计 1,280 件，与明细一致',
        'followups': <String>['导出这个月报表', '看看上周对比'],
      });

      final task = out.agentTask!;
      expect(task.done, isTrue);
      expect(task.summary, contains('1,280'));
      expect(task.followups.length, 2);
      expect(
        task.steps.every((s) => s.status == AgentStepStatus.done),
        isTrue,
      );
      expect(task.progress, 1.0);
    });

    test('没计划时 step_done 给明确错误而不是崩', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      final out = await ex.execute('step_done', <String, dynamic>{
        'step_id': 's1',
        'result': 'x',
      });
      expect(out.json['ok'], isFalse);
      expect(out.json['error'], contains('plan_task'));
    });

    test('步骤超过 8 个会被截断', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      final out = await ex.execute('plan_task', <String, dynamic>{
        'goal': 'G',
        'steps': List<Map<String, String>>.generate(
          12,
          (i) => <String, String>{'id': 's$i', 'title': '步骤$i'},
        ),
      });
      expect(out.agentTask!.steps.length, 8);
    });

    test('AgentTask JSON 往返', () {
      final t = AgentTask(
        goal: '目标',
        steps: <AgentStep>[
          AgentStep(
            id: 's1',
            title: '第一步',
            status: AgentStepStatus.done,
            detail: '结果',
          ),
        ],
        summary: '总结',
        followups: <String>['追问'],
        done: true,
      );
      final back = AgentTask.fromJson(t.toJson())!;
      expect(back.goal, '目标');
      expect(back.steps.single.status, AgentStepStatus.done);
      expect(back.followups.single, '追问');
      expect(back.done, isTrue);
    });
  });

  group('ToolTrace / UiAction 序列化', () {
    test('往返不丢字段', () {
      const t = ToolTrace(
        name: 'query_records',
        label: '查询记录',
        input: '本周',
        output: '3 条',
        ok: true,
      );
      final back = ToolTrace.fromJson(t.toJson())!;
      expect(back.name, 'query_records');
      expect(back.output, '3 条');
    });

    test('动作带 filter 可还原', () {
      final a = UiAction(
        kind: UiActionKind.applyFilter,
        label: '查看',
        filter: const RecordFilterBuilderProbe().build(),
      );
      final back = UiAction.fromJson(a.toJson())!;
      expect(back.kind, UiActionKind.applyFilter);
      expect(back.filter, isNotNull);
    });
  });

  group('工具卡片要说人话（不能只写「完成」）', () {
    test('run_terminal 的摘要带命令、退出码和首行输出', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      final out = await ex.execute('run_terminal', <String, dynamic>{
        'command': 'echo hello-summary',
        'env': 'android',
      });
      final trace = ex.buildTraceFor('run_terminal', <String, dynamic>{
        'command': 'echo hello-summary',
        'env': 'android',
      }, out, 5);
      expect(trace.input, contains('echo hello-summary'));
      expect(trace.input, contains('android'));
      expect(trace.output, contains('exit 0'));
      expect(trace.output, contains('hello-summary'));
      expect(trace.output, isNot('完成'));
      expect(trace.detail, contains('echo hello-summary'));
      expect(trace.detail, contains('hello-summary'));
    });

    test('查询类工具摘要带条数/件数/金额', () async {
      final host = FakeHost();
      final list = <PieceRecord>[
        _rec(qty: 10, price: 2, style: 'A1'),
        _rec(qty: 5, price: 3, style: 'A1'),
      ];
      final ex = build(list, host);
      final out = await ex.execute('aggregate_records', <String, dynamic>{});
      final trace = ex.buildTraceFor(
          'aggregate_records', <String, dynamic>{}, out, 3);
      expect(trace.output, contains('2 条'));
      expect(trace.output, contains('15 件'));
      expect(trace.output, contains('¥35.00'));
    });

    test('数据体检摘要列出具体问题', () async {
      final host = FakeHost();
      final list = <PieceRecord>[_rec(qty: 10), _rec(qty: 20)];
      final ex = build(list, host);
      final out = await ex.execute('check_anomalies', <String, dynamic>{});
      final trace =
          ex.buildTraceFor('check_anomalies', <String, dynamic>{}, out, 2);
      expect(trace.output, isNot('完成'));
      expect(trace.output, contains('缺照片'));
    });

    test('未知结果兜底也要摊开字段，不写「完成」', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      final out = await ex.execute('list_available_options', <String, dynamic>{});
      final trace = ex.buildTraceFor(
          'list_available_options', <String, dynamic>{}, out, 1);
      expect(trace.output, isNot('完成'));
      expect(trace.output, contains('型号'));
    });
  });

  group('终端里调工具（@工具名）', () {
    test('@help 列出可调用的工具', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      final out = await ex.execute('run_terminal', <String, dynamic>{
        'command': '@help',
      });
      expect(out.json['ok'], isTrue);
      expect((out.json['tools'] as List).contains('query_records'), isTrue);
    });

    test('@query_records 直接返回工具结果', () async {
      final host = FakeHost();
      final list = <PieceRecord>[_rec(qty: 10, price: 2, style: 'A1')];
      final ex = build(list, host);
      final out = await ex.execute('run_terminal', <String, dynamic>{
        'command': r'@query_records {"limit":5}',
      });
      expect(out.json['ok'], isTrue);
      expect(out.json['tool'], 'query_records');
      final result = out.json['result'] as Map<String, dynamic>;
      expect(result['recordCount'], 1);
    });

    test('工具 JSON 能接管道（取数 + 文本处理一步完成）', () async {
      final host = FakeHost();
      final list = <PieceRecord>[_rec(qty: 10, price: 2, style: 'A1')];
      final ex = build(list, host);
      final out = await ex.execute('run_terminal', <String, dynamic>{
        'command': r'@query_records {"limit":5} | grep -c recordCount',
        'env': 'android', // 宿主机上跑 /bin/sh，验证管道真的执行了
      });
      expect(out.json['ok'], isTrue);
      expect(out.json['pipeline'], contains('grep'));
      // grep -c 数的是「匹配行数」，只要管道真的跑起来就会是正整数
      final counted = int.tryParse((out.json['output'] as String).trim());
      expect(counted, isNotNull);
      expect(counted! > 0, isTrue);
    });

    test('参数不是 JSON → 明确报错', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      final out = await ex.execute('run_terminal', <String, dynamic>{
        'command': '@query_records abc',
      });
      expect(out.json['ok'], isFalse);
      expect(out.json['error'].toString(), contains('JSON'));
    });

    test('禁止 @run_terminal 套娃', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      final out = await ex.execute('run_terminal', <String, dynamic>{
        'command': r'@run_terminal {"command":"ls"}',
      });
      expect(out.json['ok'], isFalse);
      expect(out.json['error'].toString(), contains('套娃'));
    });
  });

  group('用已有图关联（manage_photos + photo_id）', () {
    PieceRecord withPhoto(String name, {String style = 'A1'}) {
      final r = _rec(qty: 10, price: 2, style: style);
      r.photoName = name;
      return r;
    }

    test('按图库编号关联到另一条记录（不用重新上传）', () async {
      final host = FakeHost();
      final list = <PieceRecord>[
        withPhoto('c_one.jpg', style: 'A1'),
        _rec(qty: 5, style: 'B2'), // 这条没图
      ];
      final ex = build(list, host);

      // 先拿编号
      final shown = await ex.execute('show_photos', <String, dynamic>{});
      final id = shown.photos.first['id'] as int;

      final out = await ex.execute('manage_photos', <String, dynamic>{
        'action': 'attach',
        'photo_id': id,
        'style_models': <String>['B2'],
      });
      expect(out.json['ok'], isTrue);
      expect(out.pendingAction, isNotNull);
      expect(out.pendingAction!.photoName, 'c_one.jpg');
      expect(out.pendingAction!.description, contains('#$id'));
    });

    test('按文件名关联也行', () async {
      final host = FakeHost();
      final list = <PieceRecord>[withPhoto('c_two.jpg'), _rec(qty: 3)];
      final ex = build(list, host);
      final out = await ex.execute('manage_photos', <String, dynamic>{
        'action': 'attach',
        'photo_name': 'c_two.jpg',
      });
      expect(out.json['ok'], isTrue);
      expect(out.pendingAction!.photoName, 'c_two.jpg');
    });

    test('编号不存在 → 明确报错并指路', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[_rec(qty: 1)], host);
      final out = await ex.execute('manage_photos', <String, dynamic>{
        'action': 'attach',
        'photo_id': 999,
      });
      expect(out.json['ok'], isFalse);
      expect(out.json['error'].toString(), contains('999'));
      expect(out.json['error'].toString(), contains('show_photos'));
    });

    test('没带图也没给编号 → 提示三种指定方式', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[_rec(qty: 1)], host);
      final out = await ex.execute('manage_photos', <String, dynamic>{
        'action': 'attach',
      });
      expect(out.json['ok'], isFalse);
      expect(out.json['error'].toString(), contains('photo_id'));
      expect(out.json['error'].toString(), contains('photo_name'));
    });

    test('action=list 列出图库编号', () async {
      final host = FakeHost();
      final list = <PieceRecord>[withPhoto('c_a.jpg'), withPhoto('c_b.jpg')];
      final ex = build(list, host);
      final out = await ex.execute('manage_photos', <String, dynamic>{
        'action': 'list',
      });
      expect(out.json['ok'], isTrue);
      final photos = out.json['photos'] as List;
      expect(photos.length, 2);
      expect((photos.first as Map)['id'], isA<int>());
      expect((photos.first as Map)['name'], isNotNull);
    });
  });

  group('录入时间可以指定（补录昨天/上周）', () {
    test('create_records 带 date → 待确认项里带 createdAt', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      final out = await ex.execute('create_records', <String, dynamic>{
        'items': <dynamic>[
          <String, dynamic>{
            'style_model': 'A1',
            'quantity': 300,
            'date': '2026-11-10',
          },
        ],
      });
      expect(out.json['ok'], isTrue);
      final item = out.pendingAction!.items.first;
      expect(item['createdAt'], contains('2026-11-10'));
    });

    test('不带 date 时没有 createdAt（用当前时间）', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      final out = await ex.execute('create_records', <String, dynamic>{
        'items': <dynamic>[
          <String, dynamic>{'quantity': 10},
        ],
      });
      expect(out.pendingAction!.items.first.containsKey('createdAt'), isFalse);
    });
  });

  group('AI 也能改录入时间（set_date / set_time）', () {
    test('set_date → 待确认 changes 里带 date', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[_rec(qty: 100)], host);
      final out = await ex.execute('update_records', <String, dynamic>{
        'date_preset': 'all',
        'set_date': '2026-11-10',
      });
      expect(out.json['ok'], isTrue);
      expect(out.pendingAction!.changes['date'], '2026-11-10');
      // 对比卡片里有「记录时间」这一行
      expect(
        out.pendingAction!.diff.any((d) => d['label'] == '记录时间'),
        isTrue,
      );
    });

    test('set_time → changes 里带 time', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[_rec(qty: 100)], host);
      final out = await ex.execute('update_records', <String, dynamic>{
        'date_preset': 'all',
        'set_time': '9:30',
      });
      expect(out.pendingAction!.changes['time'], '09:30');
    });

    test('日期格式不对 → 明确报错', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[_rec(qty: 100)], host);
      final out = await ex.execute('update_records', <String, dynamic>{
        'date_preset': 'all',
        'set_date': '11月10日',
      });
      expect(out.json['ok'], isFalse);
      expect(out.json['error'].toString(), contains('YYYY-MM-DD'));
    });
  });

  group('展示图片（show_photos）', () {
    PieceRecord withPhoto(String name, {String style = 'A1', String size = 'M'}) {
      final r = _rec(qty: 10, price: 2, style: style, size: size);
      r.photoName = name;
      return r;
    }

    test('按型号筛出图片卡片，带编号', () async {
      final host = FakeHost();
      final list = <PieceRecord>[
        withPhoto('c_aaa.jpg', style: 'A1'),
        withPhoto('c_bbb.jpg', style: 'B2'),
      ];
      final ex = build(list, host);
      final out = await ex.execute('show_photos', <String, dynamic>{
        'style_model': 'A1',
      });
      expect(out.json['ok'], isTrue);
      expect(out.photos.length, 1);
      expect(out.photos.single['name'], 'c_aaa.jpg');
      expect((out.photos.single['id'] as int) > 0, isTrue);
      expect(out.photos.single['label'], startsWith('#'));
    });

    test('按编号精确挑图', () async {
      final host = FakeHost();
      final list = <PieceRecord>[
        withPhoto('c_ccc.jpg'),
        withPhoto('c_ddd.jpg'),
      ];
      final ex = build(list, host);
      final first = await ex.execute('show_photos', <String, dynamic>{});
      final id = first.photos.first['id'] as int;

      final out = await ex.execute('show_photos', <String, dynamic>{
        'photo_ids': <int>[id],
      });
      expect(out.photos.length, 1);
      expect(out.photos.single['id'], id);
    });

    test('没图时给出人话提示，而不是空卡片', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[_rec(qty: 5)], host);
      final out = await ex.execute('show_photos', <String, dynamic>{});
      expect(out.photos, isEmpty);
      expect(out.json['count'], 0);
      expect(out.json['message'], contains('没有匹配的图片'));
    });

    test('limit 生效（默认 6，最多 20）', () async {
      final host = FakeHost();
      final list = <PieceRecord>[
        for (var i = 0; i < 10; i++) withPhoto('c_$i.jpg'),
      ];
      final ex = build(list, host);
      final out = await ex.execute('show_photos', <String, dynamic>{'limit': 3});
      expect(out.photos.length, 3);
    });

    test('同一张图被多条记录引用时合并成一张，并带引用数', () async {
      final host = FakeHost();
      final list = <PieceRecord>[
        withPhoto('c_shared.jpg'),
        withPhoto('c_shared.jpg', style: 'A2'),
      ];
      final ex = build(list, host);
      final out = await ex.execute('show_photos', <String, dynamic>{});
      expect(out.photos.length, 1);
      expect(out.photos.single['refs'], 2);
    });
  });

  group('轻量终端（run_terminal）', () {
    test('能执行普通命令并把输出交给模型', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      // 宿主机没有 aarch64 的 proot，这里显式走 android shell
      final out = await ex.execute('run_terminal', <String, dynamic>{
        'command': 'echo hi-from-tool',
        'env': 'android',
      });
      expect(out.json['ok'], isTrue);
      expect(out.json['stdout'], 'hi-from-tool');
      expect(out.json['exitCode'], 0);
    });

    test('空命令明确报错', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      final out = await ex.execute('run_terminal', <String, dynamic>{
        'command': '   ',
      });
      expect(out.json['ok'], isFalse);
      expect(out.json['error'], contains('不能为空'));
    });

    test('危险命令被拦，且提示别硬试', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      final out = await ex.execute('run_terminal', <String, dynamic>{
        'command': 'reboot',
      });
      expect(out.json['ok'], isFalse);
      expect(out.json['error'].toString(), contains('拦下'));
      expect(out.json['hint'], isNotNull);
    });

    test('工具名有中文标签（气泡里显示「执行命令」）', () {
      expect(toolLabel('run_terminal'), '执行命令');
    });
  });

  group('只记数量的用户（缺字段是常态）', () {
    test('create_records 只给 quantity 也能生成确认卡', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      final out = await ex.execute('create_records', <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{'quantity': 300},
        ],
      });
      expect(out.pendingAction, isNotNull);
      final item = out.pendingAction!.items.single;
      expect(item['quantity'], 300);
      expect(item['styleModel'], '');
      expect(item['unitPrice'], 0.0);
      expect(out.json['ok'], isTrue);
    });

    test('create_records 数量为 0 才拒绝', () async {
      final host = FakeHost();
      final ex = build(<PieceRecord>[], host);
      final out = await ex.execute('create_records', <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{'style_model': 'A1', 'quantity': 0},
        ],
      });
      expect(out.json['ok'], isFalse);
      expect(out.pendingAction, isNull);
    });

    test('aggregate_records 明确给出未计价条数，金额只是已知部分', () async {
      final host = FakeHost();
      final list = <PieceRecord>[
        _rec(qty: 100, price: 2, style: 'A1'),
        _rec(qty: 300), // 不知道单价
      ];
      final ex = build(list, host);
      final out = await ex.execute('aggregate_records', <String, dynamic>{});
      final auth = out.json['authoritative'] as Map<String, dynamic>;
      expect(auth['totalAmount'], 200.0);
      expect(auth['unpricedCount'], 1);
      expect(auth['unpricedQuantity'], 300);
      expect(auth['note'].toString().contains('未计价'), isTrue);
    });

    test('query_records 支持 missing 参数', () async {
      final host = FakeHost();
      final list = <PieceRecord>[
        _rec(qty: 100), // 全缺
        _rec(qty: 50, style: 'A1', price: 1),
      ];
      final ex = build(list, host);
      final out = await ex.execute('query_records', <String, dynamic>{
        'missing': <String>['style_model', 'price'],
      });
      expect(out.json['recordCount'], 1);
      final rows = out.json['records'] as List<dynamic>;
      expect((rows.single as Map)['quantity'], 100);
    });
  });
}

/// 小工具：造一个带条件的 RecordFilter
class RecordFilterBuilderProbe {
  const RecordFilterBuilderProbe();
  RecordFilter build() => const RecordFilter(
        styleModels: <String>{'A1023'},
      );
}
