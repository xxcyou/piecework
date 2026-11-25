import 'package:isar_community/isar.dart';

part 'filter_preset.g.dart';

/// 保存下来的筛选方案（设置页「筛选预设」）。
///
/// [payload] 存 `RecordFilter` 的 JSON 字符串，这样以后给筛选条件加字段
/// 也不需要动数据库 schema。
@collection
class FilterPreset {
  Id id = Isar.autoIncrement;

  /// 归属身份卡（0 = 早期未打标，归默认身份）
  @Index()
  int profileId = 0;

  /// 预设名称，例如「本周黑色M码」
  late String name;

  /// RecordFilter.toJson() 的结果
  late String payload;

  @Index()
  late DateTime createdAt;
}
