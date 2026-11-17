import 'package:isar_community/isar.dart';

import '../models/option_item.dart';

/// 型号 / 颜色 / 码数 选项仓储（三者共用一张表，用 kind 区分）
class OptionRepository {
  OptionRepository(this._isar);

  final Isar _isar;

  Future<List<String>> values(OptionKind kind) async {
    final items = await _isar.optionItems
        .filter()
        .kindEqualTo(kind)
        .sortBySortOrder()
        .findAll();
    return items.map((e) => e.value).toList();
  }

  Future<Map<OptionKind, List<String>>> allGrouped() async {
    final items = await _isar.optionItems.where().sortBySortOrder().findAll();
    final map = <OptionKind, List<String>>{
      for (final k in OptionKind.values) k: <String>[],
    };
    for (final it in items) {
      map[it.kind]?.add(it.value);
    }
    return map;
  }

  /// 新增选项（已存在则忽略）。返回是否真的写入。
  Future<bool> add(OptionKind kind, String rawValue) async {
    final value = rawValue.trim();
    if (value.isEmpty) return false;

    final exist = await _isar.optionItems
        .filter()
        .kindEqualTo(kind)
        .valueEqualTo(value)
        .findFirst();
    if (exist != null) return false;

    final last = await _isar.optionItems
        .filter()
        .kindEqualTo(kind)
        .sortBySortOrderDesc()
        .findFirst();

    final item = OptionItem();
    item.kind = kind;
    item.value = value;
    item.sortOrder = (last?.sortOrder ?? 0) + 1;
    item.createdAt = DateTime.now();

    await _isar.writeTxn(() => _isar.optionItems.put(item));
    return true;
  }

  /// 批量补录（录入时输入了历史里没有的新值，顺手记进选项库）
  Future<void> addAll(OptionKind kind, Iterable<String> values) async {
    for (final v in values) {
      await add(kind, v);
    }
  }

  Future<void> remove(OptionKind kind, String value) async {
    await _isar.writeTxn(() async {
      await _isar.optionItems
          .filter()
          .kindEqualTo(kind)
          .valueEqualTo(value)
          .deleteAll();
    });
  }

  /// 首次启动写入默认选项（码数 S/M/L/XL/XXL + 常用颜色）
  Future<void> seedDefaults() async {
    final count = await _isar.optionItems.count();
    if (count > 0) return;

    final now = DateTime.now();
    final list = <OptionItem>[];
    for (final kind in OptionKind.values) {
      var order = 0;
      for (final v in kind.defaults) {
        final item = OptionItem();
        item.kind = kind;
        item.value = v;
        item.sortOrder = order++;
        item.createdAt = now;
        list.add(item);
      }
    }
    if (list.isEmpty) return;
    await _isar.writeTxn(() => _isar.optionItems.putAll(list));
  }

  /// 备份用：导出全部选项
  Future<List<OptionItem>> exportAll() => _isar.optionItems.where().findAll();

  Future<void> replaceAll(List<OptionItem> items) async {
    await _isar.writeTxn(() async {
      await _isar.optionItems.clear();
      await _isar.optionItems.putAll(items);
    });
  }
}
