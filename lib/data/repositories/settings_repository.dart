import 'package:isar_community/isar.dart';

import '../models/app_setting.dart';

/// 全局设置仓储（整库单行）
class SettingsRepository {
  SettingsRepository(this._isar);

  final Isar _isar;

  /// 取设置行，不存在则创建
  Future<AppSetting> ensureRow() async {
    final all = await _isar.appSettings.where().findAll();
    if (all.isNotEmpty) {
      all.sort((a, b) => a.id.compareTo(b.id));
      final latest = all.last;
      // 清理历史遗留的多余行（只留最新一条）
      if (all.length > 1) {
        final stale =
            all.take(all.length - 1).map((e) => e.id).toList();
        await _isar.writeTxn(() => _isar.appSettings.deleteAll(stale));
      }
      return latest;
    }

    final s = AppSetting();
    await _isar.writeTxn(() => _isar.appSettings.put(s));
    return s;
  }

  /// 彻底清空设置表（诊断用：多条脏数据一次清干净）
  Future<void> clearAll() async {
    await _isar.writeTxn(() => _isar.appSettings.clear());
  }

  /// 当前表里有几条记录（诊断用）
  Future<int> rowCount() => _isar.appSettings.count();

  Future<void> save(AppSetting setting) async {
    await _isar.writeTxn(() => _isar.appSettings.put(setting));
  }

  /// 取**最新**那条设置。
  ///
  /// 历史原因：恢复备份时曾经会新建一条 AppSetting（autoIncrement 产生新 id），
  /// 库里可能留下多条。findFirst() 会读到最旧那条，导致「设置改了但没生效」。
  Future<AppSetting?> current() async {
    final all = await _isar.appSettings.where().findAll();
    if (all.isEmpty) return null;
    all.sort((a, b) => a.id.compareTo(b.id));
    return all.last;
  }
}
