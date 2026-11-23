import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/data/models/piece_record.dart';
import 'package:piecework/data/models/unit_rule.dart';
import 'package:piecework/data/services/selection_summary.dart';
import 'package:piecework/data/services/unit_converter.dart';

/// 多选汇总（金融相关，必须严格）
void main() {
  PieceRecord rec({
    required int qty,
    required double price,
    String unit = '件',
    String style = 'A1',
    String color = '黑',
    String size = 'M',
  }) =>
      PieceRecord()
        ..styleModel = style
        ..color = color
        ..size = size
        ..unit = unit
        ..quantity = qty
        ..unitPrice = price
        ..note = ''
        ..photoName = ''
        ..createdAt = DateTime(2026, 11, 20);

  UnitConverter conv() {
    final rule = UnitRule()
      ..fromUnit = '片'
      ..toUnit = '件'
      ..numerator = 1
      ..denominator = 2
      ..styleModel = ''
      ..createdAt = DateTime(2026);
    return UnitConverter(baseUnit: '件', rules: <UnitRule>[rule]);
  }

  test('同单位：数量直接相加，金额精确到分', () {
    final s = SelectionSummary.of(<PieceRecord>[
      rec(qty: 300, price: 0.45),
      rec(qty: 120, price: 0.45),
    ], conv());
    expect(s.count, 2);
    expect(s.qty, 420);
    expect(s.mixedUnits, isFalse);
    expect(s.amountMilli, 189000); // ¥189.00
  });

  test('不同单位：折算成基准单位，并保留原始单位明细', () {
    final s = SelectionSummary.of(<PieceRecord>[
      rec(qty: 300, price: 0.45, unit: '片'),
      rec(qty: 20, price: 0.9, unit: '件'),
    ], conv());
    expect(s.mixedUnits, isTrue);
    expect(s.units, <String>{'片', '件'});
    expect(s.qty, 320); // 原始裸和（仅参考）
    expect(s.baseQty, 170); // 300片=150件 + 20件
    expect(s.baseUnit, '件');
  });

  test('未计价单独计数，金额只算已计价', () {
    final s = SelectionSummary.of(<PieceRecord>[
      rec(qty: 100, price: 0.5),
      rec(qty: 60, price: 0),
    ], conv());
    expect(s.count, 2);
    expect(s.amountMilli, 50000); // 只算第一条 ¥50
    expect(s.unpricedCount, 1);
    expect(s.unpricedQty, 60);
  });

  test('相同的合并成一行，不同的各占一行', () {
    final s = SelectionSummary.of(<PieceRecord>[
      rec(qty: 100, price: 0.5, style: 'A1'),
      rec(qty: 50, price: 0.5, style: 'A1'),
      rec(qty: 30, price: 0.8, style: 'B2'),
    ], conv());
    expect(s.lines.length, 2);
    final a1 = s.lines.firstWhere((l) => l.label.contains('A1'));
    expect(a1.count, 2);
    expect(a1.qty, 150);
    expect(a1.amountMilli, 75000); // 150 × ¥0.5
  });

  test('金额累加不漂（0.1+0.2 这类）', () {
    final s = SelectionSummary.of(<PieceRecord>[
      rec(qty: 1, price: 0.1),
      rec(qty: 1, price: 0.2),
    ], conv());
    expect(s.amountMilli, 300); // ¥0.30，而不是 0.30000000000000004
  });

  test('空选择不炸', () {
    final s = SelectionSummary.of(const <PieceRecord>[], conv());
    expect(s.count, 0);
    expect(s.amountMilli, 0);
    expect(s.lines, isEmpty);
  });
}
