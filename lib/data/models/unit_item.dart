import 'package:isar_community/isar.dart';

part 'unit_item.g.dart';

/// 计量单位（件 / 片 / 打 / 套 …）。可增删。
///
/// 其中一个标记为 [isBase]（基准单位，默认「件」）：
/// 所有跨单位汇总都会先折算成它，报表里的「件数」就是它。
@collection
class UnitItem {
  Id id = Isar.autoIncrement;

  /// 单位名，例如「件」「片」「打」
  @Index()
  late String name;

  /// 是否基准单位（全表只应有一个）
  late bool isBase;

  late int sortOrder;

  late DateTime createdAt;
}
