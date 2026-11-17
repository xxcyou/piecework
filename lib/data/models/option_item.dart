import 'package:isar_community/isar.dart';

part 'option_item.g.dart';

/// 可维护的选项类型：型号 / 颜色 / 码数
enum OptionKind {
  styleModel,
  color,
  size,
}

extension OptionKindX on OptionKind {
  String get label => switch (this) {
        OptionKind.styleModel => '型号',
        OptionKind.color => '颜色',
        OptionKind.size => '码数',
      };

  /// 首次启动时写入的默认项（码数按需求预置 S~XXL）
  List<String> get defaults => switch (this) {
        OptionKind.styleModel => const <String>[],
        OptionKind.color => const <String>[
          '黑色', '白色', '灰色', '红色', '蓝色', '藏青', '卡其', '米白', '粉色', '绿色',
        ],
        OptionKind.size => const <String>['S', 'M', 'L', 'XL', 'XXL'],
      };
}

/// 选项条目。型号 / 颜色 / 码数共用一张表，用 [kind] 区分。
///
/// 为什么不拆三张表：三者的增删改查逻辑完全一致，
/// 共用一张表可以让「选项管理」页面和备份逻辑都只有一份实现。
@collection
class OptionItem {
  Id id = Isar.autoIncrement;

  @enumerated
  @Index()
  late OptionKind kind;

  @Index()
  late String value;

  /// 手动排序用，越小越靠前
  /// （Isar 的 sortBy 只能用于索引字段，所以这里必须加 @Index）
  @Index()
  late int sortOrder;

  late DateTime createdAt;
}
