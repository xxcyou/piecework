import 'package:isar_community/isar.dart';

import '../models/filter_preset.dart';

/// 筛选预设仓储
class PresetRepository {
  PresetRepository(this._isar);

  final Isar _isar;

  /// 某个身份的预设（profileId 为空则全部，备份导出用）
  Future<List<FilterPreset>> all({int? profileId}) {
    if (profileId == null) {
      return _isar.filterPresets.where().sortByCreatedAtDesc().findAll();
    }
    return _isar.filterPresets
        .filter()
        .profileIdEqualTo(profileId)
        .sortByCreatedAtDesc()
        .findAll();
  }

  Future<List<FilterPreset>> allLegacy() =>
      _isar.filterPresets.where().sortByCreatedAtDesc().findAll();

  /// 同名覆盖，方便“更新已有预设”
  Future<void> save(String name, String payloadJson, {int profileId = 0}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final exist = await _isar.filterPresets
        .filter()
        .profileIdEqualTo(profileId)
        .nameEqualTo(trimmed)
        .findFirst();
    if (exist != null) {
      exist.payload = payloadJson;
      await _isar.writeTxn(() => _isar.filterPresets.put(exist));
      return;
    }

    final p = FilterPreset();
    p.name = trimmed;
    p.payload = payloadJson;
    p.profileId = profileId;
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

/// 筛选预设按身份过滤（纯函数，便于测试）
List<FilterPreset> filterPresetsForProfile(
  List<FilterPreset> all,
  int profileId, {
  required bool activeIsDefault,
}) {
  if (profileId == 0) return all;
  return all
      .where((p) =>
          p.profileId == profileId || (p.profileId == 0 && activeIsDefault))
      .toList();
}
