import '../models/piece_record.dart';
import 'unit_converter.dart';

/// 财务模式下的「按型号汇总」一行。
///
/// 财务模式只看**型号**：颜色、码数、备注都不参与合并
/// （用户口径：就是找型号统计而已，数据太多看起来花眼）。
/// 同型号下单价可能不同 → 单价栏显示「不一」，金额仍是各条相加。
class SalaryGroup {
  SalaryGroup({
    required this.styleModel,
    required this.count,
    required this.qty,
    required this.centiBase,
    required this.amountMilli,
    required this.units,
    required this.unitPrices,
    required this.records,
  });

  final String styleModel;
  final int count;

  /// 原始数量之和（同单位时直接看这个）
  final int qty;

  /// 折算到基准单位的百分之一（跨单位用）
  final int centiBase;

  final int amountMilli;

  /// 这组里出现过的单位
  final Set<String> units;

  /// 这组里出现过的单价（去重）
  final Set<double> unitPrices;

  final List<PieceRecord> records;

  bool get mixedUnits => units.length > 1;

  /// 单价一致时返回它，不一致返回 null
  double? get singlePrice => unitPrices.length == 1 ? unitPrices.first : null;

  String get label => styleModel.isEmpty ? '（未填型号）' : styleModel;
}

/// 按型号汇总（财务模式）
List<SalaryGroup> groupSalary(
  List<PieceRecord> records,
  UnitConverter converter,
) {
  final map = <String, List<PieceRecord>>{};
  for (final r in records) {
    map.putIfAbsent(r.styleModel.trim(), () => <PieceRecord>[]).add(r);
  }

  final out = <SalaryGroup>[];
  for (final entry in map.entries) {
    final list = entry.value;
    var qty = 0;
    var centi = 0;
    var amount = 0;
    final units = <String>{};
    final prices = <double>{};
    for (final r in list) {
      qty += r.quantity;
      centi += converter.centiBaseOf(r).toInt();
      amount += r.subtotalMilli;
      units.add(r.unitOrBase);
      if (r.hasPrice) prices.add(r.unitPrice);
    }
    out.add(
      SalaryGroup(
        styleModel: entry.key,
        count: list.length,
        qty: qty,
        centiBase: centi,
        amountMilli: amount,
        units: units,
        unitPrices: prices,
        records: list,
      ),
    );
  }

  // 金额大的在前
  out.sort((a, b) {
    final c = b.amountMilli.compareTo(a.amountMilli);
    return c != 0 ? c : b.qty.compareTo(a.qty);
  });
  return out;
}
