import 'package:isar_community/isar.dart';

part 'profile.g.dart';

/// 身份卡：一个「我」或一个手下的工人。
///
/// 为什么要有它：包工头下面几个人，各自记各自的件数；
/// 数据必须**按身份隔离** —— 列表、报表、AI 对话、汇总都只看当前身份，
/// 不然一笔账混进别人头上就是事故。
@collection
class Profile {
  Id id = Isar.autoIncrement;

  /// 名字，例如「我」「张三」
  @Index()
  late String name;

  /// 头像：一个 emoji（👷 🧑‍🏭 🐱 …），空 = 用名字首字
  String avatar = '';

  /// 兼容老字段：以前用颜色块，现在头像优先，颜色只做次要强调
  String colorName = '';

  /// 备注（工种、工号、电话…）
  String note = '';

  late DateTime createdAt;

  /// 归档：不删除，但默认不在切换列表里出现
  bool archived = false;

  /// 默认身份（第一个创建的，不可删除）
  bool isDefault = false;
}
