import 'package:isar_community/isar.dart';

import '../models/unit_item.dart';
import '../models/unit_rule.dart';

/// 单位与换算规则仓储
class UnitRepository {
  UnitRepository(this._isar);

  final Isar _isar;

  Future<List<UnitItem>> units() =>
      _isar.unitItems.where().sortBySortOrder().findAll();

  Future<List<UnitRule>> rules() => _isar.unitRules.where().findAll();

  /// 首次启动写入「件（基准）/ 片 / 打」
  Future<void> seedDefaults() async {
    final count = await _isar.unitItems.count();
    if (count > 0) return;

    final now = DateTime.now();
    const names = <String>['件', '片', '打'];
    final list = <UnitItem>[];
    for (var i = 0; i < names.length; i++) {
      final u = UnitItem();
      u.name = names[i];
      u.isBase = i == 0;
      u.sortOrder = i;
      u.createdAt = now;
      list.add(u);
    }
    await _isar.writeTxn(() => _isar.unitItems.putAll(list));
  }

  Future<bool> addUnit(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) return false;

    final exist =
        await _isar.unitItems.filter().nameEqualTo(name).findFirst();
    if (exist != null) return false;

    final last = await _isar.unitItems.where().sortBySortOrderDesc().findFirst();

    final u = UnitItem();
    u.name = name;
    u.isBase = false;
    u.sortOrder = (last?.sortOrder ?? 0) + 1;
    u.createdAt = DateTime.now();
    await _isar.writeTxn(() => _isar.unitItems.put(u));
    return true;
  }

  /// 删除单位（基准单位不可删）。已有记录里的单位字符串保持不变。
  Future<void> removeUnit(String name) async {
    final item = await _isar.unitItems.filter().nameEqualTo(name).findFirst();
    if (item == null || item.isBase) return;
    await _isar.writeTxn(() => _isar.unitItems.delete(item.id));
  }

  /// 切换基准单位（全表只保留一个）
  Future<void> setBase(String name) async {
    final all = await _isar.unitItems.where().findAll();
    await _isar.writeTxn(() async {
      for (final u in all) {
        u.isBase = u.name == name;
      }
      await _isar.unitItems.putAll(all);
    });
  }

  /// 保存换算规则（同 fromUnit + styleModel 覆盖）
  Future<void> saveRule({
    required String fromUnit,
    required String toUnit,
    required int numerator,
    required int denominator,
    String styleModel = '',
  }) async {
    if (denominator <= 0 || numerator <= 0) return;

    final exist = await _isar.unitRules
        .filter()
        .fromUnitEqualTo(fromUnit)
        .styleModelEqualTo(styleModel)
        .findFirst();

    final rule = exist ?? UnitRule();
    rule.fromUnit = fromUnit;
    rule.toUnit = toUnit;
    rule.numerator = numerator;
    rule.denominator = denominator;
    rule.styleModel = styleModel;
    if (exist == null) rule.createdAt = DateTime.now();

    await _isar.writeTxn(() => _isar.unitRules.put(rule));
  }

  Future<void> removeRule(Id id) async {
    await _isar.writeTxn(() => _isar.unitRules.delete(id));
  }
}
