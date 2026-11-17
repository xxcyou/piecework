import 'package:isar_community/isar.dart';

part 'unit_rule.g.dart';

/// 单位换算规则：`denominator` 个 [fromUnit] = `numerator` 个 [toUnit]。
///
/// 用**整数分子/分母**而不是 double 系数，是为了让「100 片 = 30 件」这种
/// 除不尽的档位在批量折算时也精确：
///   100 片 → 100×30÷100 = 30 件
///   33 片  → 990 百分之一件 = 9.90 件（而不是 9.899999999999999）
///
/// [styleModel] 非空时表示这条规则只对该型号生效 —— 不同款裁片比例不同是常态。
/// 查找优先级：型号专属规则 > 全局规则 > 1:1。
@collection
class UnitRule {
  Id id = Isar.autoIncrement;

  /// 源单位，例如「片」
  @Index()
  late String fromUnit;

  /// 目标单位（通常等于基准单位「件」）
  late String toUnit;

  /// 分子：换算后数量
  late int numerator;

  /// 分母：换算前数量
  late int denominator;

  /// 仅对该型号生效；空串表示全局默认
  @Index()
  String styleModel = '';

  late DateTime createdAt;

  /// 1 个源单位 = factor 个目标单位
  double get factor => denominator == 0 ? 1 : numerator / denominator;

  String get label =>
      '$denominator $fromUnit = $numerator $toUnit'
      '${styleModel.isEmpty ? '' : '（$styleModel）'}';
}
