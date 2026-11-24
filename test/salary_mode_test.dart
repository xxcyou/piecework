import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/data/models/piece_record.dart';
import 'package:piecework/data/models/unit_rule.dart';
import 'package:piecework/data/services/salary_summary.dart';
import 'package:piecework/data/services/unit_converter.dart';

/// 工资模式：同款自动汇总
void main() {
  PieceRecord rec({
    required int qty,
    required double price,
    String style = 'A1',
    String color = '黑',
    String size = 'M',
    String unit = '件',
    int day = 1,
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
        ..createdAt = DateTime(2026, 11, day);

  UnitConverter conv() => UnitConverter(baseUnit: '件', rules: <UnitRule>[]);

  test('同款合并成一行，数量金额相加', () {
    final g = groupSalary(<PieceRecord>[
      rec(qty: 100, price: 0.5, day: 1),
      rec(qty: 50, price: 0.5, day: 3),
    ], conv());
    expect(g.length, 1);
    expect(g.first.count, 2);
    expect(g.first.qty, 150);
    expect(g.first.amountMilli, 75000);
    expect(g.first.label, 'A1 · 黑 · M');
  });

  test('单价不同不合并（否则工资算错）', () {
    final g = groupSalary(<PieceRecord>[
      rec(qty: 100, price: 0.5),
      rec(qty: 100, price: 0.6),
    ], conv());
    expect(g.length, 2);
  });

  test('颜色/码数/型号不同都分开', () {
    final g = groupSalary(<PieceRecord>[
      rec(qty: 10, price: 1),
      rec(qty: 10, price: 1, color: '白'),
      rec(qty: 10, price: 1, size: 'L'),
      rec(qty: 10, price: 1, style: 'B2'),
    ], conv());
    expect(g.length, 4);
  });

  test('按金额从大到小排（主要收入在前）', () {
    final g = groupSalary(<PieceRecord>[
      rec(qty: 10, price: 1, style: '小'),
      rec(qty: 100, price: 5, style: '大'),
    ], conv());
    expect(g.first.styleModel, '大');
  });

  test('未计价的行金额为 0，但数量照算', () {
    final g = groupSalary(<PieceRecord>[rec(qty: 300, price: 0)], conv());
    expect(g.first.amountMilli, 0);
    expect(g.first.qty, 300);
  });

  test('空列表不炸', () {
    expect(groupSalary(const <PieceRecord>[], conv()), isEmpty);
  });
}
