import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/core/money.dart';
import 'package:piecework/data/models/pending_action.dart';
import 'package:piecework/data/models/piece_record.dart';
import 'package:piecework/data/models/unit_rule.dart';
import 'package:piecework/data/services/unit_converter.dart';
import 'package:piecework/data/models/record_filter.dart';
import 'package:piecework/data/services/csv_service.dart';
import 'package:piecework/data/services/query_engine.dart';

PieceRecord rec({
  String style = 'A1023',
  String color = '黑色',
  String size = 'M',
  int qty = 10,
  double price = 12.5,
  DateTime? at,
  String note = '',
  String photo = '',
}) {
  final r = PieceRecord();
  r.styleModel = style;
  r.color = color;
  r.size = size;
  r.quantity = qty;
  r.unitPrice = price;
  r.note = note;
  r.photoName = photo;
  r.createdAt = at ?? DateTime(2026, 11, 13, 10, 0);
  return r;
}

void main() {
  group('QueryEngine 过滤', () {
    final data = <PieceRecord>[
      rec(style: 'A1023', color: '黑色', size: 'M', qty: 10, price: 12.5),
      rec(style: 'A1023', color: '白色', size: 'L', qty: 20, price: 12.5),
      rec(style: 'B2001', color: '黑色', size: 'M', qty: 5, price: 8.0),
      rec(style: 'B2001', color: '藏青', size: 'XL', qty: 30, price: 8.0),
    ];

    test('不限条件返回全部', () {
      final r = QueryEngine.apply(data, RecordFilter.empty);
      expect(r.count, 4);
      expect(r.totalQuantity, 65);
      expect(r.totalAmount, 10 * 12.5 + 20 * 12.5 + 5 * 8.0 + 30 * 8.0);
    });

    test('按型号多选过滤', () {
      final r = QueryEngine.apply(
        data,
        const RecordFilter(styleModels: <String>{'A1023'}),
      );
      expect(r.count, 2);
      expect(r.totalQuantity, 30);
    });

    test('型号 + 颜色组合过滤', () {
      final r = QueryEngine.apply(
        data,
        const RecordFilter(
          styleModels: <String>{'A1023'},
          colors: <String>{'黑色'},
        ),
      );
      expect(r.count, 1);
      expect(r.records.single.size, 'M');
    });

    test('码数多选', () {
      final r = QueryEngine.apply(
        data,
        const RecordFilter(sizes: <String>{'M', 'XL'}),
      );
      expect(r.count, 3); // A1023/M, B2001/M, B2001/XL
    });

    test('数量区间（含端点）', () {
      final r = QueryEngine.apply(
        data,
        const RecordFilter(minQty: 10, maxQty: 20),
      );
      expect(r.count, 2);
      expect(r.totalQuantity, 30);
    });

    test('时间范围：今天', () {
      final r = QueryEngine.apply(
        data,
        const RecordFilter(quick: QuickRange.today),
        now: DateTime(2026, 11, 13, 18, 0),
      );
      expect(r.count, 4);
    });

    test('时间范围：昨天应查不到', () {
      final r = QueryEngine.apply(
        data,
        const RecordFilter(quick: QuickRange.yesterday),
        now: DateTime(2026, 11, 13, 18, 0),
      );
      expect(r.count, 0);
      expect(r.totalAmount, 0);
    });
  });

  group('QueryEngine 排序', () {
    final data = <PieceRecord>[
      rec(qty: 5, price: 10),
      rec(qty: 30, price: 10),
      rec(qty: 12, price: 10),
    ];

    test('按数量降序', () {
      final r = QueryEngine.apply(
        data,
        const RecordFilter(sortField: SortField.quantity),
      );
      expect(r.records.map((e) => e.quantity).toList(), <int>[30, 12, 5]);
    });

    test('按数量升序', () {
      final r = QueryEngine.apply(
        data,
        const RecordFilter(sortField: SortField.quantity, ascending: true),
      );
      expect(r.records.map((e) => e.quantity).toList(), <int>[5, 12, 30]);
    });
  });

  group('QueryEngine 分组', () {
    final data = <PieceRecord>[
      rec(color: '黑色', qty: 10, price: 10),
      rec(color: '黑色', qty: 5, price: 10),
      rec(color: '白色', qty: 20, price: 10),
    ];

    test('按颜色汇总，件数倒序', () {
      final groups = QueryEngine.group(data, GroupField.color);
      expect(groups.length, 2);
      expect(groups.first.key, '白色');
      expect(groups.first.quantity, 20);
      expect(groups.last.key, '黑色');
      expect(groups.last.quantity, 15);
      expect(groups.last.amount, 150);
    });

    test('group=none 只返回合计', () {
      final groups = QueryEngine.group(data, GroupField.none);
      expect(groups.length, 1);
      expect(groups.single.quantity, 35);
    });

    test('按日期分组 key 为 yyyy-MM-dd', () {
      final groups = QueryEngine.group(
        <PieceRecord>[
          rec(at: DateTime(2026, 11, 13)),
          rec(at: DateTime(2026, 11, 12)),
        ],
        GroupField.day,
      );
      expect(groups.map((e) => e.key).toList(), <String>['2026-11-12', '2026-11-13']);
    });
  });

  group('RecordFilter JSON 往返', () {
    test('完整条件可无损还原', () {
      final f = RecordFilter(
        quick: QuickRange.custom,
        customStart: DateTime(2026, 11, 1),
        customEnd: DateTime(2026, 11, 13),
        styleModels: <String>{'A1023', 'B2001'},
        colors: <String>{'黑色'},
        sizes: <String>{'M', 'L'},
        minQty: 5,
        maxQty: 100,
        sortField: SortField.amount,
        ascending: true,
      );
      final back = RecordFilter.fromJson(f.toJson());
      expect(back, f);
      expect(back.summary, contains('型号:A1023'));
      expect(back.activeCount, 5);
    });

    test('空条件 JSON 往返', () {
      final back = RecordFilter.fromJson(RecordFilter.empty.toJson());
      expect(back, RecordFilter.empty);
      expect(back.isActive, isFalse);
      expect(back.summary, '未上报记录');
    });

    test('脏数据不抛异常', () {
      final back = RecordFilter.fromJson(<String, dynamic>{
        'quick': 'not_a_value',
        'styleModels': 'not_a_list',
        'minQty': 'abc',
      });
      expect(back.quick, QuickRange.all);
      expect(back.styleModels, isEmpty);
      expect(back.minQty, isNull);
    });
  });

  group('CsvService', () {
    test('包含 BOM、表头与合计行', () {
      final csv = CsvService.build(<PieceRecord>[
        rec(style: 'A1023', color: '黑色', size: 'M', qty: 10, price: 12.5),
        rec(style: 'B2001', color: '白色', size: 'L', qty: 20, price: 8),
      ]);
      expect(csv.startsWith('\uFEFF'), isTrue, reason: 'Excel 需要 UTF-8 BOM');
      expect(csv, contains('款式型号'));
      expect(csv, contains('A1023'));
      expect(csv, contains('合计'));
      expect(csv, contains('285.00')); // 125 + 160
      expect(csv, contains('共 2 条记录'));
    });
  });

  group('照片条件（忘记拍照的场景）', () {
    final data = <PieceRecord>[
      rec(style: 'A1', photo: 'a.jpg'),
      rec(style: 'A2', photo: ''),
      rec(style: 'A3', photo: 'c.jpg'),
      rec(style: 'A4', photo: ''),
    ];

    test('默认 any 全都要', () {
      expect(QueryEngine.apply(data, RecordFilter.empty).count, 4);
    });

    test('只查缺照片的', () {
      final r = QueryEngine.apply(
        data,
        const RecordFilter(photoFilter: PhotoFilter.noPhoto),
      );
      expect(r.count, 2);
      expect(r.records.map((e) => e.styleModel).toList(), <String>['A2', 'A4']);
    });

    test('只查有照片的', () {
      final r = QueryEngine.apply(
        data,
        const RecordFilter(photoFilter: PhotoFilter.hasPhoto),
      );
      expect(r.count, 2);
    });

    test('缺照片 + 型号组合', () {
      final r = QueryEngine.apply(
        data,
        const RecordFilter(
          photoFilter: PhotoFilter.noPhoto,
          styleModels: <String>{'A4'},
        ),
      );
      expect(r.count, 1);
    });

    test('photoFilter 参与 JSON 往返与 activeCount', () {
      const f = RecordFilter(photoFilter: PhotoFilter.noPhoto);
      expect(f.activeCount, 1);
      expect(f.summary, contains('缺照片'));
      expect(RecordFilter.fromJson(f.toJson()).photoFilter, PhotoFilter.noPhoto);
    });

    test('旧备份没有 photoFilter 字段时退化为 any', () {
      final back = RecordFilter.fromJson(<String, dynamic>{'quick': 'today'});
      expect(back.photoFilter, PhotoFilter.any);
    });

    test('蛇形参数解析', () {
      expect(photoFilterFromWire('no_photo'), PhotoFilter.noPhoto);
      expect(photoFilterFromWire('has_photo'), PhotoFilter.hasPhoto);
      expect(photoFilterFromWire(null), PhotoFilter.any);
    });
  });

  group('PendingAction（AI 写操作）', () {
    test('删除动作 JSON 往返', () {
      const a = PendingAction(
        kind: PendingKind.delete,
        description: '删除 2 条记录（共 15 件）',
        ids: <int>[1, 2],
      );
      final back = PendingAction.fromJson(a.toJson())!;
      expect(back.kind, PendingKind.delete);
      expect(back.ids, <int>[1, 2]);
      expect(back.affectedCount, 2);
    });

    test('修改动作带 changes', () {
      const a = PendingAction(
        kind: PendingKind.update,
        description: '改单价',
        ids: <int>[7],
        changes: <String, dynamic>{'unitPrice': 12.5, 'note': '返工'},
      );
      final back = PendingAction.fromJson(a.toJson())!;
      expect(back.changes['unitPrice'], 12.5);
      expect(back.changes['note'], '返工');
    });

    test('新建动作按 items 计数', () {
      const a = PendingAction(
        kind: PendingKind.create,
        description: '新建 2 条',
        items: <Map<String, dynamic>>[
          <String, dynamic>{'styleModel': 'A1', 'quantity': 10, 'unitPrice': 5},
          <String, dynamic>{'styleModel': 'A2', 'quantity': 20, 'unitPrice': 5},
        ],
      );
      expect(a.affectedCount, 2);
      expect(PendingAction.fromJson(a.toJson())!.items.length, 2);
    });

    test('脏 JSON 返回 null 而不抛异常', () {
      expect(PendingAction.fromJson(null), isNull);
      expect(PendingAction.fromJson('not a map'), isNull);
    });
  });

  group('财务精度（整数厘）', () {
    test('1000 条 0.1 元累加精确等于 100.00', () {
      final list = List<PieceRecord>.generate(1000, (_) => rec(qty: 1, price: 0.1));
      final r = QueryEngine.apply(list, RecordFilter.empty);
      // double 直接累加会得到 99.9999999999986
      expect(r.totalAmountMilli, 100000); // 100000 厘 = 100.00 元
      expect(Money.format(r.totalAmountMilli), '100.00');
    });

    test('两位小数单价 × 大数量不漂', () {
      final list = <PieceRecord>[
        rec(qty: 37, price: 12.35), // 456.95
        rec(qty: 13, price: 8.07), // 104.91
      ];
      final r = QueryEngine.apply(list, RecordFilter.empty);
      expect(r.totalAmountMilli, (45695 + 10491) * 10);
      expect(Money.format(r.totalAmountMilli), '561.86');
    });

    test('分组小计之和 == 总计（对账必须闭合）', () {
      final list = <PieceRecord>[
        rec(at: DateTime(2026, 11, 12), qty: 7, price: 3.33),
        rec(at: DateTime(2026, 11, 12), qty: 11, price: 1.07),
        rec(at: DateTime(2026, 11, 13), qty: 19, price: 0.99),
        rec(at: DateTime(2026, 11, 13), qty: 3, price: 12.35),
      ];
      final r = QueryEngine.apply(list, RecordFilter.empty);
      final groups = QueryEngine.group(r.records, GroupField.day);
      final sum = groups.fold(0, (s, g) => s + g.amountMilli);
      expect(sum, r.totalAmountMilli);
    });

    test('单价支持三位小数（0.001 档位），四位判非法', () {
      // 关键回归：0.001 元不能再被抹成 0
      expect(Money.toMilli(0.001), 1);
      expect(Money.parsePrice('0.001'), 0.001);
      expect(Money.parsePrice('12.345'), 12.345);
      expect(Money.parsePrice('12.3456'), isNull);
      expect(Money.parsePrice('12.35'), 12.35);
      expect(Money.parsePrice(''), 0);
      expect(Money.parsePrice('-1'), isNull);
    });

    test('0.001 元 × 1000 件 = 1.00 元', () {
      final r = rec(qty: 1000, price: 0.001);
      expect(r.subtotalMilli, 1000); // 1000 厘
      expect(Money.format(r.subtotalMilli), '1.00');
    });

    test('有厘位时显示三位小数，否则两位', () {
      expect(Money.format(1), '0.001');
      expect(Money.format(10), '0.01');
      expect(Money.format(1000), '1.00');
      expect(Money.format(12345), '12.345');
      expect(Money.format(12350), '12.35');
    });

    test('千分位格式化', () {
      expect(Money.format(123456789), '123,456.789'); // 123456789 厘
      expect(Money.plain(123456789), '123456.789');
      expect(Money.yuan(0), '¥0.00');
    });
  });

  group('单位换算（片 ↔ 件）', () {
    UnitRule rule(String from, int num, int den,
        {String style = '', String to = '件'}) {
      final r = UnitRule();
      r.fromUnit = from;
      r.toUnit = to;
      r.numerator = num;
      r.denominator = den;
      r.styleModel = style;
      r.createdAt = DateTime(2026);
      return r;
    }

    final converter = UnitConverter(
      baseUnit: '件',
      rules: <UnitRule>[
        rule('片', 50, 100), // 全局：100 片 = 50 件
        rule('片', 30, 100, style: 'A1023'), // 该款：100 片 = 30 件
      ],
    );

    test('全局规则 100 片 = 50 件', () {
      expect(converter.centiBasePerUnit('片'), 50);
      expect(converter.toCentiBase(100, '片'), 5000); // 50.00 件
    });

    test('型号专属规则优先于全局', () {
      expect(converter.centiBasePerUnit('片', styleModel: 'A1023'), 30);
      expect(converter.toCentiBase(100, '片', styleModel: 'A1023'), 3000);
      // 别的型号仍走全局
      expect(converter.toCentiBase(100, '片', styleModel: 'B2001'), 5000);
    });

    test('除不尽的档位不漂（33 片 × 0.3 = 9.90 件）', () {
      expect(converter.toCentiBase(33, '片', styleModel: 'A1023'), 990);
      expect(UnitConverter.formatCenti(990), '9.90');
    });

    test('基准单位恒等', () {
      expect(converter.centiBasePerUnit('件'), 100);
      expect(converter.toCentiBase(7, '件'), 700);
    });

    test('未配置规则的单位按 1:1 处理', () {
      expect(converter.centiBasePerUnit('打'), 100);
      expect(converter.hasRule('打'), isFalse);
    });

    test('金额按记录自己的单位算，折算只影响数量', () {
      // 用非 A1023 的型号，走全局规则（100 片 = 50 件）
      final r = rec(style: 'B2001', qty: 100, price: 0.01)..unit = '片';
      expect(r.subtotalMilli, 1000); // 100 片 × ¥0.01 = ¥1.00（1000 厘）
      expect(converter.centiBaseOf(r), 5000); // 折算 50.00 件
    });

    test('锁定 id：忽略型号/日期条件，只认那批记录', () {
      final a = PieceRecord()
        ..id = 1
        ..styleModel = 'A'
        ..quantity = 10
        ..unitPrice = 1
        ..createdAt = DateTime(2026, 11, 1);
      final b = PieceRecord()
        ..id = 2
        ..styleModel = 'B'
        ..quantity = 20
        ..unitPrice = 1
        ..createdAt = DateTime(2026, 11, 2);
      final c = PieceRecord()
        ..id = 3
        ..styleModel = 'C'
        ..quantity = 30
        ..unitPrice = 1
        ..createdAt = DateTime(2026, 11, 3);

      // 只锁 1 和 3，即使 quick=all、型号为空也应命中 2 条
      final filter = RecordFilter(pinnedIds: <int>[1, 3]);
      final result = QueryEngine.apply(<PieceRecord>[a, b, c], filter);

      expect(result.count, 2);
      expect(result.totalQuantity, 40);
      expect(result.records.map((e) => e.id), <int>[1, 3]);
    });

    test('锁定 id：记录被改型号后仍能查到', () {
      final a = PieceRecord()
        ..id = 1
        ..styleModel = '旧型号'
        ..quantity = 10
        ..unitPrice = 1
        ..createdAt = DateTime(2026, 11, 1);

      final filter = RecordFilter(pinnedIds: <int>[1]);
      // 模拟用户后来把型号改了
      a.styleModel = '新型号';

      final result = QueryEngine.apply(<PieceRecord>[a], filter);
      expect(result.count, 1);
      expect(result.records.single.styleModel, '新型号');
    });

    test('锁定 id 的筛选能 JSON 往返', () {
      const filter = RecordFilter(pinnedIds: <int>[7, 8, 9]);
      final back = RecordFilter.fromJson(filter.toJson());
      expect(back.pinnedIds, <int>[7, 8, 9]);
      expect(back.isPinned, isTrue);
      expect(back.summary, contains('这批记录'));
    });

    test('链式换算：100片=30打，1打=12件 → 1片=3.6件', () {
      final conv = UnitConverter(
        baseUnit: '件',
        rules: <UnitRule>[
          rule('片', 30, 100, to: '打'),
          rule('打', 12, 1, to: '件'),
        ],
      );
      expect(conv.factorBetween('片', '件'), closeTo(3.6, 1e-9));
      expect(conv.centiBasePerUnit('片'), 360);
    });

    test('反向换算：只配 片→件，也能算 件→片', () {
      final conv = UnitConverter(
        baseUnit: '件',
        rules: <UnitRule>[rule('片', 50, 100)],
      );
      expect(conv.factorBetween('件', '片'), closeTo(2.0, 1e-9));
    });

    test('目标单位不是基准也能配', () {
      final conv = UnitConverter(
        baseUnit: '件',
        rules: <UnitRule>[
          rule('片', 30, 100, to: '打'),
          rule('打', 12, 1, to: '件'),
        ],
      );
      expect(conv.factorBetween('片', '打'), closeTo(0.3, 1e-9));
      expect(conv.hasRule('片'), isTrue);
    });

    test('没有路径时退化为 1:1', () {
      final conv = UnitConverter(
        baseUnit: '件',
        rules: <UnitRule>[rule('片', 50, 100)],
      );
      expect(conv.factorBetween('套', '件'), isNull);
      expect(conv.centiBasePerUnit('套'), 100);
    });

    test('折算后总计与分组小计闭合', () {
      final list = <PieceRecord>[
        rec(style: 'A1023', qty: 100, price: 0.01)..unit = '片',
        rec(style: 'B2001', qty: 100, price: 0.02)..unit = '片',
        rec(style: 'A1023', qty: 10, price: 12.00)..unit = '件',
      ];
      final r = QueryEngine.apply(list, RecordFilter.empty, converter: converter);
      expect(r.totalAmountMilli, 1000 + 2000 + 120000);
      // 30.00 + 50.00 + 10.00 = 90.00 件
      expect(r.totalCentiBase, 3000 + 5000 + 1000);
      final groups = QueryEngine.group(r.records, GroupField.styleModel, converter: converter);
      expect(groups.fold(0, (s, g) => s + g.centiBase), r.totalCentiBase);
    });
  });

  group('小计计算', () {
    test('quantity × unitPrice 无浮点漂移', () {
      expect(rec(qty: 3, price: 0.1).subtotal, closeTo(0.3, 1e-9));
      expect(rec(qty: 7, price: 12.35).subtotal, closeTo(86.45, 1e-9));
    });
  });
}
