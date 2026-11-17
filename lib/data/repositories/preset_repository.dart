import 'package:isar_community/isar.dart';

import '../models/filter_preset.dart';

/// 筛选预设仓储
class PresetRepository {
  PresetRepository(this._isar);

  final Isar _isar;

  Future<List<FilterPreset>> all() =>
      _isar.filterPresets.where().sortByCreatedAtDesc().findAll();

  /// 同名覆盖，方便“更新已有预设”
  Future<void> save(String name, String payloadJson) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final exist =
        await _isar.filterPresets.filter().nameEqualTo(trimmed).findFirst();
    if (exist != null) {
      exist.payload = payloadJson;
      await _isar.writeTxn(() => _isar.filterPresets.put(exist));
      return;
    }

    final p = FilterPreset();
    p.name = trimmed;
    p.payload = payloadJson;
    p.createdAt = DateTime.now();
    await _isar.writeTxn(() => _isar.filterPresets.put(p));
  }

  Future<void> remove(Id id) async {
    await _isar.writeTxn(() => _isar.filterPresets.delete(id));
  }

  Future<List<FilterPreset>> exportAll() => _isar.filterPresets.where().findAll();

  Future<void> replaceAll(List<FilterPreset> list) async {
    await _isar.writeTxn(() async {
      await _isar.filterPresets.clear();
      await _isar.filterPresets.putAll(list);
    });
  }
}
