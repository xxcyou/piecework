import '../../core/format.dart';
import '../../core/money.dart';
import '../models/piece_record.dart';
import '../models/record_filter.dart';
import 'unit_converter.dart';

/// 一次筛选的执行结果。
///
/// 金额一律以**整数分**保存（[totalAmountMilli]），显示时再转元。
class QueryResult {
  const QueryResult({
    required this.records,
    required this.totalQuantity,
    required this.totalAmountMilli,
    required this.filter,
    this.totalCentiBase = 0,
    this.baseUnit = '件',
    this.units = const <String>{},
    this.unpricedCount = 0,
    this.unpricedQuantity = 0,
    this.pricedCentiBase = 0,
  });

  final List<PieceRecord> records;

  /// 原始数量之和（跨单位时没有可比性，仅作参考）
  final int totalQuantity;

  /// 折算成基准单位的「百分之一」，跨单位汇总看这个
  final int totalCentiBase;

  /// 基准单位名
  final String baseUnit;

  /// 本批记录里出现过的单位（件/片/打…）
  final Set<String> units;

  /// 是否混用了多种单位。
  /// 为 true 时 [totalQuantity] 是「件+片」的裸和，**没有意义**。
  bool get mixedUnits => units.length > 1;

  /// 折算后的基准单位数量
  double get totalBaseQuantity => totalCentiBase / 100;

  /// 没填单价的条数 / 件数（[totalAmountMilli] 只统计了已知单价的部分）
  final int unpricedCount;
  final int unpricedQuantity;

  /// 金额是否只是「已知部分」
  bool get amountIsPartial => unpricedCount > 0;

  /// 一句可以直接念给用户听的数量描述。
  ///
  /// 为什么在 Dart 里拼：模型很容易把 `totalQuantity`（原始裸和）直接说成「件」，
  /// 而实际单位可能是「片」。这里把单位、折算值一次说清，模型逐字引用即可。
  String get quantityText {
    if (records.isEmpty) return '0 $baseUnit';
    if (mixedUnits) {
      final raw = units.join(' + ');
      return '${_fmt(totalBaseQuantity)} $baseUnit（折算，原始单位：$raw）';
    }
    final unit = units.isEmpty ? baseUnit : units.first;
    if (unit == baseUnit) return '$totalQuantity $unit';
    // 单一单位但不是基准单位：原数量 + 折算值
    final base = _fmt(totalBaseQuantity);
    if ((totalBaseQuantity - totalQuantity).abs() < 0.005) {
      // 没有换算规则（1:1），就不用画蛇添足
      return '$totalQuantity $unit';
    }
    return '$totalQuantity $unit（≈ $base $baseUnit）';
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  /// 填过单价的那部分记录的基准单位数量（百分之一）
  ///
  /// 平均单价必须只除以这部分：把「未计价」的件数也算进分母，
  /// 会得出一个明显偏低的假均价。
  final int pricedCentiBase;

  /// 每个基准单位的平均单价（元）。跨单位时只有这个才有意义。
  ///
  /// 金额单位是「厘」(1/1000 元)，数量单位是「百分之一基准单位」，
  /// 所以 元/件 = (milli/1000) / (centi/100) = milli / (centi × 10)。
  double get averagePerBaseUnit =>
      pricedCentiBase > 0 ? totalAmountMilli / (pricedCentiBase * 10) : 0;



  /// 总金额（分）
  final int totalAmountMilli;

  final RecordFilter filter;

  int get count => records.length;
  bool get isEmpty => records.isEmpty;

  /// 总金额（元），仅用于显示
  double get totalAmount => Money.toYuan(totalAmountMilli);

  static const QueryResult empty = QueryResult(
    records: <PieceRecord>[],
    totalQuantity: 0,
    totalAmountMilli: 0,
    filter: RecordFilter.empty,
  );

  /// 给 AI 用的紧凑摘要（不把每条记录都塞进上下文）
  Map<String, dynamic> toSummaryJson() => <String, dynamic>{
        'recordCount': count,
        'totalQuantity': mixedUnits ? null : totalQuantity,
        'totalBaseQuantity': totalBaseQuantity,
        'baseUnit': baseUnit,
        'mixedUnits': mixedUnits,
        'units': units.toList(),
        'averagePricePerBaseUnit':
            double.parse(averagePerBaseUnit.toStringAsFixed(4)),
        'totalAmount': Money.toYuan(totalAmountMilli),
        // 模型直接引用这一句就不会把「片」说成「件」
        'quantityText': quantityText,
        // 金额只包含填过单价的部分；有未计价时要让界面/AI 都说清楚
        if (unpricedCount > 0) 'unpricedCount': unpricedCount,
        if (unpricedCount > 0) 'unpricedQuantity': unpricedQuantity,
        'amountIsPartial': amountIsPartial,
        'filterSummary': filter.summary,
      };
}

/// 分组统计的一行。金额同样以分累加。
class GroupStat {
  GroupStat({
    required this.key,
    this.count = 0,
    this.quantity = 0,
    this.amountMilli = 0,
    this.centiBase = 0,
    this.unpricedCount = 0,
    this.unpricedQuantity = 0,
  });

  final String key;
  int count;
  int quantity;
  int amountMilli;

  /// 折算成基准单位的百分之一
  int centiBase;

  /// 这批里「没填单价」的条数 / 件数（金额未计入 [amountMilli]）
  int unpricedCount;
  int unpricedQuantity;

  double get amount => Money.toYuan(amountMilli);
  double get baseQuantity => centiBase / 100;

  void add(PieceRecord r, {UnitConverter converter = UnitConverter.identity}) {
    count++;
    quantity += r.quantity;
    amountMilli += r.subtotalMilli;
    centiBase += converter.centiBaseOf(r);
    if (!r.hasPrice) {
      unpricedCount++;
      unpricedQuantity += r.quantity;
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'key': key,
        'recordCount': count,
        'quantity': quantity,
        'baseQuantity': baseQuantity,
        'amount': Money.toYuan(amountMilli),
        // 有未计价的记录时，金额只是「已知部分」，必须让上层说清楚
        if (unpricedCount > 0) 'unpricedCount': unpricedCount,
        if (unpricedCount > 0) 'unpricedQuantity': unpricedQuantity,
      };
}

/// 纯函数查询引擎。
///
/// 为什么在内存里过滤而不是拼 Isar Query：
/// 个人计件数据量级是「几千条」，全量读进内存再过滤 < 5ms，
/// 而动态拼 Isar 的 QueryBuilder 需要处理大量泛型分支，容易出错。
/// 数据量如果真的上到十万级，再换成 `isar.pieceRecords.filter()` 组合查询即可，
/// 上层 [QueryEngine] 的签名不用动。
class QueryEngine {
  QueryEngine._();

  static QueryResult apply(
    List<PieceRecord> source,
    RecordFilter filter, {
    DateTime? now,
    UnitConverter converter = UnitConverter.identity,
  }) {
    // 锁定 id 模式：只认这批记录，忽略其他条件。
    // 记录后来被改了型号/颜色/数量，点「查看这批记录」看到的还是同一批。
    if (filter.isPinned) {
      final order = <int, int>{};
      for (var i = 0; i < filter.pinnedIds.length; i++) {
        order[filter.pinnedIds[i]] = i;
      }
      final picked = source.where((r) => order.containsKey(r.id)).toList()
        ..sort((a, b) => (order[a.id] ?? 1 << 30)
            .compareTo(order[b.id] ?? 1 << 30));

      var pq = 0;
      var pa = 0;
      var pc = 0;
      final pu = <String>{};
      for (final r in picked) {
        pq += r.quantity;
        pa += r.subtotalMilli;
        pc += converter.centiBaseOf(r);
        pu.add(r.unitOrBase);
      }

      return QueryResult(
        records: picked,
        totalQuantity: pq,
        units: pu,
        totalAmountMilli: pa,
        totalCentiBase: pc,
        baseUnit: converter.baseUnit,
        filter: filter,
      );
    }

    final range = filter.resolveRange(now);

    final list = <PieceRecord>[];
    for (final r in source) {
      if (range != null) {
        if (r.createdAt.isBefore(range.start)) continue;
        if (r.createdAt.isAfter(range.end)) continue;
      }
      if (filter.styleModels.isNotEmpty && !filter.styleModels.contains(r.styleModel)) {
        continue;
      }
      if (filter.colors.isNotEmpty && !filter.colors.contains(r.color)) continue;
      if (filter.sizes.isNotEmpty && !filter.sizes.contains(r.size)) continue;
      if (filter.minQty != null && r.quantity < filter.minQty!) continue;
      if (filter.maxQty != null && r.quantity > filter.maxQty!) continue;

      // 上报状态：默认只看未上报，避免重复上报
      if (filter.statusFilter == StatusFilter.pendingOnly &&
          r.status != RecordStatus.pending) {
        continue;
      }
      if (filter.statusFilter == StatusFilter.reportedOnly &&
          r.status != RecordStatus.reported) {
        continue;
      }

      // 照片条件：忘记拍照是常态，缺图的记录要能单独捞出来补拍
      if (filter.photoFilter == PhotoFilter.hasPhoto && r.photoName.isEmpty) {
        continue;
      }
      if (filter.photoFilter == PhotoFilter.noPhoto && r.photoName.isNotEmpty) {
        continue;
      }

      // 缺信息条件：只记了件数的记录要能单独捞出来补录
      if (filter.missing.isNotEmpty) {
        var allMissing = true;
        for (final m in filter.missing) {
          final absent = switch (m) {
            MissingField.styleModel => r.styleModel.trim().isEmpty,
            MissingField.color => r.color.trim().isEmpty,
            MissingField.size => r.size.trim().isEmpty,
            MissingField.price => !r.hasPrice,
          };
          if (!absent) {
            allMissing = false;
            break;
          }
        }
        if (!allMissing) continue;
      }

      list.add(r);
    }

    list.sort((a, b) {
      final c = switch (filter.sortField) {
        SortField.createdAt => a.createdAt.compareTo(b.createdAt),
        SortField.quantity => a.quantity.compareTo(b.quantity),
        // 金额排序也走整数分，避免相等值因浮点误差排错位
        SortField.amount => a.subtotalMilli.compareTo(b.subtotalMilli),
      };
      // 同值时用 id 兜底，保证排序稳定（批量删除时顺序不会跳）
      final stable = c != 0 ? c : a.id.compareTo(b.id);
      return filter.ascending ? stable : -stable;
    });

    var qty = 0;
    var amtCents = 0;
    var centi = 0;
    var unpricedCount = 0;
    var unpricedQty = 0;
    var pricedCenti = 0;
    final units = <String>{};
    for (final r in list) {
      qty += r.quantity;
      amtCents += r.subtotalMilli;
      final c = converter.centiBaseOf(r);
      centi += c;
      units.add(r.unitOrBase);
      if (r.hasPrice) {
        pricedCenti += c;
      } else {
        unpricedCount++;
        unpricedQty += r.quantity;
      }
    }

    return QueryResult(
      records: list,
      totalQuantity: qty,
      units: units,
      totalAmountMilli: amtCents,
      totalCentiBase: centi,
      baseUnit: converter.baseUnit,
      filter: filter,
      unpricedCount: unpricedCount,
      unpricedQuantity: unpricedQty,
      pricedCentiBase: pricedCenti,
    );
  }

  /// 按维度分组汇总
  static List<GroupStat> group(
    List<PieceRecord> records,
    GroupField field, {
    UnitConverter converter = UnitConverter.identity,
  }) {
    if (field == GroupField.none) {
      final g = GroupStat(key: '合计');
      for (final r in records) {
        g.add(r, converter: converter);
      }
      return <GroupStat>[g];
    }

    final map = <String, GroupStat>{};
    for (final r in records) {
      final key = switch (field) {
        GroupField.styleModel => r.styleModel.isEmpty ? '（未填）' : r.styleModel,
        GroupField.color => r.color.isEmpty ? '（未填）' : r.color,
        GroupField.size => r.size.isEmpty ? '（未填）' : r.size,
        GroupField.day => Fmt.date(r.createdAt),
        GroupField.month => Fmt.date(r.createdAt).substring(0, 7),
        GroupField.none => '合计',
      };
      (map[key] ??= GroupStat(key: key)).add(r, converter: converter);
    }

    final out = map.values.toList();
    if (field == GroupField.day || field == GroupField.month) {
      out.sort((a, b) => a.key.compareTo(b.key)); // 时间维度正序
    } else {
      out.sort((a, b) => b.quantity.compareTo(a.quantity)); // 其余按件数倒序
    }
    return out;
  }

  /// 可选值清单（给 AI 提示“库里到底有哪些型号/颜色/码数”）
  static Map<String, List<String>> distinctValues(List<PieceRecord> records) {
    final styles = <String>{};
    final colors = <String>{};
    final sizes = <String>{};
    for (final r in records) {
      if (r.styleModel.isNotEmpty) styles.add(r.styleModel);
      if (r.color.isNotEmpty) colors.add(r.color);
      if (r.size.isNotEmpty) sizes.add(r.size);
    }
    final s = styles.toList()..sort();
    final c = colors.toList()..sort();
    final z = sizes.toList()..sort();
    return <String, List<String>>{'styleModels': s, 'colors': c, 'sizes': z};
  }
}
