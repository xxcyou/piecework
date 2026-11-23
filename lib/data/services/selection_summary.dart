import '../models/piece_record.dart';
import 'unit_converter.dart';

/// 一条分组小计（型号+颜色+码数相同的记录合并成一行）
class SummaryLine {
  SummaryLine({
    required this.label,
    required this.units,
    required this.count,
    required this.qty,
    required this.centiBase,
    required this.amountMilli,
    required this.unpricedCount,
    required this.unpricedQty,
  });

  final String label;
  final Set<String> units;
  final int count;

  /// 原始数量之和（单位一致时才有意义）
  final int qty;

  /// 折算到基准单位的「百分之一」，整数累加不漂
  final int centiBase;

  final int amountMilli;
  final int unpricedCount;
  final int unpricedQty;

  bool get mixedUnits => units.length > 1;
  bool get singleUnit => units.length == 1;
}

/// 多选汇总：条数 / 数量 / 金额 / 按「型号·颜色·码数」分组小计。
///
/// 金融相关，所以：
/// * 金额用 **整数厘** 累加（[PieceRecord.subtotalMilli]），不碰浮点；
/// * 数量分两种口径：原始数量（同单位才有意义）+ 折算基准数量（整数百分位）；
/// * 未计价（单价 0）单独计数，金额只累加已计价的部分，绝不当成 0 元混进去。
class SelectionSummary {
  SelectionSummary._({
    required this.count,
    required this.units,
    required this.qty,
    required this.centiBase,
    required this.baseUnit,
    required this.amountMilli,
    required this.unpricedCount,
    required this.unpricedQty,
    required this.lines,
  });

  final int count;
  final Set<String> units;
  final int qty;
  final int centiBase;
  final String baseUnit;
  final int amountMilli;
  final int unpricedCount;
  final int unpricedQty;
  final List<SummaryLine> lines;

  bool get mixedUnits => units.length > 1;
  bool get priced => count - unpricedCount > 0;

  /// 折算后的基准数量（保留两位）
  double get baseQty => centiBase / 100.0;

  static SelectionSummary of(
    List<PieceRecord> records,
    UnitConverter converter,
  ) {
    final byKey = <String, List<PieceRecord>>{};
    for (final r in records) {
      final key = <String>[
        r.styleModel.isEmpty ? '（未填型号）' : r.styleModel,
        r.color.isEmpty ? '' : r.color,
        r.size.isEmpty ? '' : r.size,
      ].where((e) => e.isNotEmpty).join(' · ');
      byKey.putIfAbsent(key, () => <PieceRecord>[]).add(r);
    }

    final lines = <SummaryLine>[];
    var count = 0, qty = 0, centi = 0, amount = 0, unpriced = 0, unpricedQty = 0;
    final units = <String>{};

    for (final e in byKey.entries) {
      final list = e.value;
      var lQty = 0, lCenti = 0, lAmount = 0, lUnpriced = 0, lUnpricedQty = 0;
      final lUnits = <String>{};
      for (final r in list) {
        lQty += r.quantity;
        lCenti += converter.centiBaseOf(r).toInt();
        lUnits.add(r.unitOrBase);
        if (r.hasPrice) {
          lAmount += r.subtotalMilli;
        } else {
          lUnpriced++;
          lUnpricedQty += r.quantity;
        }
      }
      count += list.length;
      qty += lQty;
      centi += lCenti;
      amount += lAmount;
      unpriced += lUnpriced;
      unpricedQty += lUnpricedQty;
      units.addAll(lUnits);
      lines.add(
        SummaryLine(
          label: e.key,
          units: lUnits,
          count: list.length,
          qty: lQty,
          centiBase: lCenti,
          amountMilli: lAmount,
          unpricedCount: lUnpriced,
          unpricedQty: lUnpricedQty,
        ),
      );
    }

    // 组内按金额降序，金额相同按数量降序
    lines.sort((a, b) {
      final c = b.amountMilli.compareTo(a.amountMilli);
      return c != 0 ? c : b.qty.compareTo(a.qty);
    });

    return SelectionSummary._(
      count: count,
      units: units,
      qty: qty,
      centiBase: centi,
      baseUnit: converter.baseUnit,
      amountMilli: amount,
      unpricedCount: unpriced,
      unpricedQty: unpricedQty,
      lines: lines,
    );
  }
}
