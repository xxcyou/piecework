import '../models/piece_record.dart';
import '../models/unit_rule.dart';

/// 单位换算器。
///
/// 规则是**有向图**，不强制指向基准单位：
/// ```
/// 100 片 = 30 打      片 --0.3--> 打
/// 1 打   = 12 件      打 --12--> 件
/// ```
/// 折算「片 → 件」会走链式路径：0.3 × 12 = 3.6 件/片。
/// 也支持反向走（只配了 片→件，问「1 件等于多少片」也能算）。
///
/// 折算结果用「百分之一基准单位」的整数表示，累加不漂。
class UnitConverter {
  const UnitConverter({
    required this.baseUnit,
    required this.rules,
  });

  /// 无规则时的直通换算器（所有单位都按 1:1 处理）
  static const UnitConverter identity = UnitConverter(
    baseUnit: '件',
    rules: <UnitRule>[],
  );

  /// 基准单位，默认「件」
  final String baseUnit;

  final List<UnitRule> rules;

  /// 按型号筛选规则：型号专属优先于全局
  List<UnitRule> _rulesFor(String styleModel) {
    final own = styleModel.isEmpty
        ? const <UnitRule>[]
        : rules.where((r) => r.styleModel == styleModel).toList();
    final global = rules.where((r) => r.styleModel.isEmpty).toList();
    return <UnitRule>[...own, ...global];
  }

  /// 1 个 [from] 等于多少个 [to]；找不到路径返回 null。
  double? factorBetween(String from, String to, {String styleModel = ''}) {
    final f = from.trim().isEmpty ? baseUnit : from.trim();
    final t = to.trim().isEmpty ? baseUnit : to.trim();
    if (f == t) return 1.0;

    final pool = _rulesFor(styleModel);
    return _search(f, t, pool, <String>{}, 0);
  }

  double? _search(
    String from,
    String to,
    List<UnitRule> pool,
    Set<String> visited,
    int depth,
  ) {
    if (depth > 6) return null;
    if (from == to) return 1.0;
    if (!visited.add(from)) return null;

    for (final r in pool) {
      // 正向：from → to
      if (r.fromUnit == from && r.denominator > 0) {
        final f = r.numerator / r.denominator;
        if (r.toUnit == to) return f;
        final rest = _search(r.toUnit, to, pool, visited, depth + 1);
        if (rest != null) return f * rest;
      }
      // 反向：只配了 A→B，问 B→A 也能算
      if (r.toUnit == from && r.numerator > 0) {
        final f = r.denominator / r.numerator;
        if (r.fromUnit == to) return f;
        final rest = _search(r.fromUnit, to, pool, visited, depth + 1);
        if (rest != null) return f * rest;
      }
    }

    // 关键：回溯时要撤销访问标记，否则并行的另一条路径会被误剪
    visited.remove(from);
    return null;
  }

  /// 1 个 [unit] 等于多少个「百分之一基准单位」
  ///
  /// 例：1 片 = 0.5 件 → 返回 50；1 件 = 1 件 → 返回 100。
  int centiBasePerUnit(String unit, {String styleModel = ''}) {
    final u = unit.trim().isEmpty ? baseUnit : unit.trim();
    if (u == baseUnit) return 100;

    final factor = factorBetween(u, baseUnit, styleModel: styleModel);
    // 没配规则、或规则配成 0/负数 → 一律按 1:1，绝不返回 0
    // （返回 0 会让整批记录折算成 0 件，直接毁掉统计）
    if (factor == null || factor <= 0 || !factor.isFinite) return 100;
    final centi = (factor * 100).round();
    return centi <= 0 ? 100 : centi;
  }

  /// 数量 → 折算后的「百分之一基准单位」
  int toCentiBase(int quantity, String unit, {String styleModel = ''}) {
    return quantity * centiBasePerUnit(unit, styleModel: styleModel);
  }

  /// 一条记录折算成基准单位的百分之一
  int centiBaseOf(PieceRecord r) => toCentiBase(
        r.quantity,
        r.unitOrBase,
        styleModel: r.styleModel,
      );

  /// 折算后的基准数量
  double baseQuantityOf(PieceRecord r) => centiBaseOf(r) / 100;

  /// 百分之一基准单位 → 展示字符串
  static String formatCenti(int centi) => (centi / 100).toStringAsFixed(2);

  /// 该单位能否折算到基准单位
  bool hasRule(String unit, {String styleModel = ''}) {
    final u = unit.trim().isEmpty ? baseUnit : unit.trim();
    if (u == baseUnit) return true;
    return factorBetween(u, baseUnit, styleModel: styleModel) != null;
  }

  /// 展示用描述，例如「1 片 = 0.50 件」
  String describe(String unit, {String styleModel = ''}) {
    final u = unit.trim().isEmpty ? baseUnit : unit.trim();
    if (u == baseUnit) return '基准单位';
    final f = factorBetween(u, baseUnit, styleModel: styleModel);
    if (f == null) return '未配置换算（按 1:1）';
    return '1 $u = ${f.toStringAsFixed(4)} $baseUnit';
  }
}
