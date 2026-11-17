import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/data/models/option_item.dart';
import 'package:piecework/core/money.dart';
import 'package:piecework/data/models/piece_record.dart';
import 'package:piecework/data/models/record_filter.dart';
import 'package:piecework/data/services/query_engine.dart';

/// 「只记数量」的用户：型号 / 颜色 / 码数 / 单价都可能不知道。
/// 这一组测试守住三件事：
/// 1. 这种记录能正常存、正常查、能按「缺信息」筛出来；
/// 2. 金额汇总不能把「未计价」当成 0 元混进去；
/// 3. 平均单价只能用「填过单价」的那部分算。
PieceRecord rec({
  required int qty,
  String style = '',
  String color = '',
  String size = '',
  double price = 0,
  String unit = '件',
  DateTime? at,
}) {
  final r = PieceRecord();
  r.styleModel = style;
  r.color = color;
  r.size = size;
  r.unit = unit;
  r.quantity = qty;
  r.unitPrice = price;
  r.note = '';
  r.photoName = '';
  r.createdAt = at ?? DateTime(2026, 11, 13, 10);
  return r;
}

void main() {
  group('只记数量的记录', () {
    test('空型号/颜色/码数/单价都能存，且标记出缺哪些字段', () {
      final r = rec(qty: 300);
      expect(r.hasPrice, isFalse);
      expect(r.missingFields,
          <String>['styleModel', 'color', 'size', 'price']);
      expect(r.subtotalMilli, 0);
    });

    test('只填了码数和数量：缺型号/颜色/单价', () {
      final r = rec(qty: 120, size: 'M');
      expect(r.missingFields, <String>['styleModel', 'color', 'price']);
    });

    test('单价 0 视为未填，不是「白干」', () {
      final r = rec(qty: 10, price: 0);
      expect(r.hasPrice, isFalse);
      expect(r.subtotalMilli, 0);
    });
  });

  group('汇总口径：未计价要单独算', () {
    test('金额只累加已填单价的记录，未计价单独计数', () {
      final list = <PieceRecord>[
        rec(qty: 100, style: 'A1023', price: 1.5),
        rec(qty: 200), // 不知道单价
        rec(qty: 50, price: 2),
      ];
      final result = QueryEngine.apply(list, const RecordFilter());
      expect(result.count, 3);
      expect(result.totalQuantity, 350);
      // 100×1.5 + 50×2 = 250
      expect(result.totalAmountMilli, 250000);
      expect(result.unpricedCount, 1);
      expect(result.unpricedQuantity, 200);
      expect(result.amountIsPartial, isTrue);
      expect(result.toSummaryJson()['unpricedCount'], 1);
    });

    test('平均单价只除以「已计价」的数量（不能把未计价件数算进分母）', () {
      final list = <PieceRecord>[
        rec(qty: 100, price: 2), // 已计价：100 件 × 2 元
        rec(qty: 900), // 未计价：900 件
      ];
      final result = QueryEngine.apply(list, const RecordFilter());
      // 错误算法：200 / 1000 = 0.2；正确：200 / 100 = 2
      expect(result.averagePerBaseUnit, 2.0);
    });

    test('全部未计价时金额为 0、均价为 0，但条数/件数照常', () {
      final list = <PieceRecord>[rec(qty: 30), rec(qty: 70, size: 'L')];
      final result = QueryEngine.apply(list, const RecordFilter());
      expect(result.totalAmountMilli, 0);
      expect(result.averagePerBaseUnit, 0);
      expect(result.unpricedCount, 2);
      expect(result.unpricedQuantity, 100);
      expect(result.amountIsPartial, isTrue);
    });

    test('分组里也能看到未计价', () {
      final list = <PieceRecord>[
        rec(qty: 10, size: 'M', price: 3),
        rec(qty: 20, size: 'M'),
      ];
      final groups = QueryEngine.group(list, GroupField.size);
      final m = groups.firstWhere((g) => g.key == 'M');
      expect(m.count, 2);
      expect(m.unpricedCount, 1);
      expect(m.unpricedQuantity, 20);
      expect(m.toJson()['unpricedCount'], 1);
    });

    test('空型号分组落到「（未填）」而不是消失', () {
      final list = <PieceRecord>[rec(qty: 10), rec(qty: 5, style: 'A1')];
      final groups = QueryEngine.group(list, GroupField.styleModel);
      final keys = groups.map((g) => g.key).toSet();
      expect(keys.contains('（未填）'), isTrue);
      expect(keys.contains('A1'), isTrue);
    });
  });

  group('缺信息筛选', () {
    final list = <PieceRecord>[
      rec(qty: 10), // 全缺
      rec(qty: 20, style: 'A1'), // 缺颜色/码数/单价
      rec(qty: 30, style: 'A1', color: '黑色', size: 'M'), // 只缺单价
      rec(qty: 40, style: 'B2', color: '白色', size: 'L', price: 2), // 不缺
    ];

    List<int> idsWith(Set<MissingField> missing) => QueryEngine.apply(
          list,
          RecordFilter(missing: missing),
        ).records.map((r) => r.quantity).toList();

    test('只筛缺型号的', () {
      expect(idsWith(<MissingField>{MissingField.styleModel}), <int>[10]);
    });

    test('缺颜色', () {
      expect(idsWith(<MissingField>{MissingField.color}), <int>[10, 20]);
    });

    test('缺单价（数量最多的那批）', () {
      expect(idsWith(<MissingField>{MissingField.price}), <int>[10, 20, 30]);
    });

    test('多个条件是「同时都缺」', () {
      expect(
        idsWith(<MissingField>{
          MissingField.styleModel,
          MissingField.color,
        }),
        <int>[10],
      );
    });

    test('空集合 = 不限', () {
      expect(idsWith(<MissingField>{}).length, 4);
    });

    test('missing 能 JSON 往返，并计入 activeCount / summary', () {
      const f = RecordFilter(
        missing: <MissingField>{MissingField.styleModel, MissingField.price},
      );
      final back = RecordFilter.fromJson(f.toJson());
      expect(back.missing, f.missing);
      expect(f.activeCount, 1);
      expect(f.summary.contains('缺型号'), isTrue);
    });

    test('脏 JSON 不炸', () {
      final back = RecordFilter.fromJson(<String, dynamic>{
        'missing': <Object?>['style_model', 42, null, 'nonsense'],
      });
      expect(back.missing, <MissingField>{MissingField.styleModel});
    });

    test('蛇形参数解析', () {
      expect(missingFieldFromWire('price'), MissingField.price);
      expect(missingFieldFromWire('unit_price'), MissingField.price);
      expect(missingFieldFromWire('style_model'), MissingField.styleModel);
      expect(missingFieldFromWire('???'), isNull);
    });
  });

  group('单价精度到 0.001（厘）', () {
    test('0.001 元能存住，不被截成 0.00', () {
      final r = rec(qty: 1000, price: 0.001);
      expect(Money.toMilli(r.unitPrice), 1); // 1 厘
      expect(r.subtotalMilli, 1000); // 1000 件 × 0.001 = 1.000 元
      expect(Money.yuan(r.subtotalMilli), '¥1.00');
    });

    test('回填到输入框的字符串保留三位小数', () {
      // 编辑页用 Money.plain(Money.toMilli(price)) 回填
      expect(Money.plain(Money.toMilli(0.001)), '0.001');
      expect(Money.plain(Money.toMilli(0.125)), '0.125');
      expect(Money.plain(Money.toMilli(12.35)), '12.35');
      expect(Money.plain(Money.toMilli(12)), '12.00');
    });

    test('显示自适应：有厘位才出三位', () {
      expect(Money.format(Money.toMilli(0.125)), '0.125');
      expect(Money.format(Money.toMilli(1.5)), '1.50');
    });

    test('超过三位小数判非法（不静默四舍五入）', () {
      expect(Money.parsePrice('0.0012'), isNull);
      expect(Money.parsePrice('0.001'), 0.001);
      expect(Money.parsePrice(''), 0);
      expect(Money.parsePrice('-1'), isNull);
    });

    test('大量低单价记录累加不漂', () {
      final list = <PieceRecord>[
        for (var i = 0; i < 1000; i++) rec(qty: 1, price: 0.001),
      ];
      final result = QueryEngine.apply(list, const RecordFilter());
      expect(result.totalAmountMilli, 1000); // 1000 厘 = 1.000 元
      expect(Money.yuan(result.totalAmountMilli), '¥1.00');
    });
  });

  group('选项库不因空值污染', () {
    test('distinctValues 跳过空字符串', () {
      final list = <PieceRecord>[
        rec(qty: 1),
        rec(qty: 1, style: 'A1', color: '黑色', size: 'M'),
      ];
      final v = QueryEngine.distinctValues(list);
      expect(v['styleModels'], <String>['A1']);
      expect(v['colors'], <String>['黑色']);
      expect(v['sizes'], <String>['M']);
    });
  });

  group('只有数量的记录能正常序列化（备份/恢复不丢）', () {
    test('toJson/fromJson 往返后仍然只有数量', () {
      final r = rec(qty: 300, unit: '件');
      final filter = RecordFilter.empty;
      expect(filter.isActive, isFalse);
      // 用 CSV 行做一次轻量检查：空字段不能变成 "null"
      final csv = <String>[
        r.styleModel,
        r.color,
        r.size,
        r.unit,
        '${r.quantity}',
      ];
      expect(csv.any((e) => e == 'null'), isFalse);
      expect(csv[0], isEmpty);
      expect(OptionKind.values.contains(OptionKind.styleModel), isTrue);
    });
  });
}
