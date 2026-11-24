import '../models/piece_record.dart';
import 'unit_converter.dart';

/// 工资模式下的「同款汇总」一行。
///
/// 同款 = 型号 + 颜色 + 码数 + 单价 + 单位 全相同。
/// 单价不同不能合并（否则算出来的工资是错的）。
class SalaryGroup {
  SalaryGroup({
    required this.styleModel,
    required this.color,
    required this.size,
    required this.unit,
    required this.unitPrice,
    required this.count,
    required this.qty,
    required this.centiBase,
    required this.amountMilli,
    required this.records,
  });

  final String styleModel;
  final String color;
  final String size;
  final String unit;
  final double unitPrice;
  final int count;

  /// 原始数量之和（单位一致）
  final int qty;

  /// 折算到基准单位的百分之一（跨单位时用）
  final int centiBase;

  final int amountMilli;
  final List<PieceRecord> records;

  String get label {
    final parts = <String>[
      styleModel.isEmpty ? '（未填型号）' : styleModel,
      if (color.isNotEmpty) color,
      if (size.isNotEmpty) size,
    ];
    return parts.join(' · ');
  }
}

/// 按「同款」汇总（工资模式）
List<SalaryGroup> groupSalary(
  List<PieceRecord> records,
  UnitConverter converter,
) {
  final map = <String, List<PieceRecord>>{};
  for (final r in records) {
    final key = <String>[
      r.styleModel,
      r.color,
      r.size,
      r.unitOrBase,
      r.unitPrice.toStringAsFixed(4),
    ].join('|');
    map.putIfAbsent(key, () => <PieceRecord>[]).add(r);
  }

  final out = <SalaryGroup>[];
  for (final list in map.values) {
    final first = list.first;
    var qty = 0;
    var centi = 0;
    var amount = 0;
    for (final r in list) {
      qty += r.quantity;
      centi += converter.centiBaseOf(r).toInt();
      amount += r.subtotalMilli;
    }
    out.add(
      SalaryGroup(
        styleModel: first.styleModel,
        color: first.color,
        size: first.size,
        unit: first.unitOrBase,
        unitPrice: first.unitPrice,
        count: list.length,
        qty: qty,
        centiBase: centi,
        amountMilli: amount,
        records: list,
      ),
    );
  }

  // 金额大的在前，方便一眼看主要收入
  out.sort((a, b) {
    final c = b.amountMilli.compareTo(a.amountMilli);
    return c != 0 ? c : b.qty.compareTo(a.qty);
  });
  return out;
}
