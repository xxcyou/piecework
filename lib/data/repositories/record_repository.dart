import 'package:isar_community/isar.dart';

import '../models/piece_record.dart';

/// 计件记录仓储：所有数据库读写都从这里走，UI/Provider 不直接碰 Isar。
class RecordRepository {
  RecordRepository(this._isar);

  final Isar _isar;

  /// 全量读取（按录入时间倒序，**不含回收站**）。
  Future<List<PieceRecord>> all() => _isar.pieceRecords
      .filter()
      .deletedAtIsNull()
      .sortByCreatedAtDesc()
      .findAll();

  /// 响应式监听：录入/编辑/删除后列表会自动刷新（不含回收站）
  Stream<List<PieceRecord>> watchAll() => _isar.pieceRecords
      .filter()
      .deletedAtIsNull()
      .sortByCreatedAtDesc()
      .watch(fireImmediately: true);

  /// 回收站：已软删除的记录，最近删的在前
  Future<List<PieceRecord>> deleted() => _isar.pieceRecords
      .filter()
      .deletedAtIsNotNull()
      .sortByDeletedAtDesc()
      .findAll();

  Stream<List<PieceRecord>> watchDeleted() => _isar.pieceRecords
      .filter()
      .deletedAtIsNotNull()
      .sortByDeletedAtDesc()
      .watch(fireImmediately: true);

  Future<PieceRecord?> byId(Id id) => _isar.pieceRecords.get(id);

  /// 新增或更新。返回主键。
  Future<Id> save(PieceRecord record) async {
    return _isar.writeTxn(() async {
      return _isar.pieceRecords.put(record);
    });
  }

  /// 软删除：进回收站，30 天内可恢复
  Future<void> deleteById(Id id) async {
    final r = await _isar.pieceRecords.get(id);
    if (r == null) return;
    r.deletedAt = DateTime.now();
    await _isar.writeTxn(() => _isar.pieceRecords.put(r));
  }

  /// 批量软删除，返回受影响的记录（撤销快照用）
  Future<List<PieceRecord>> deleteMany(Iterable<Id> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return const <PieceRecord>[];

    final affected = <PieceRecord>[];
    final now = DateTime.now();
    for (final id in list) {
      final r = await _isar.pieceRecords.get(id);
      if (r == null || r.deletedAt != null) continue;
      r.deletedAt = now;
      affected.add(r);
    }
    if (affected.isEmpty) return const <PieceRecord>[];
    await _isar.writeTxn(() => _isar.pieceRecords.putAll(affected));
    return affected;
  }

  /// 从回收站恢复
  Future<void> restore(Id id) async {
    final r = await _isar.pieceRecords.get(id);
    if (r == null) return;
    r.deletedAt = null;
    await _isar.writeTxn(() => _isar.pieceRecords.put(r));
  }

  Future<void> restoreMany(Iterable<Id> ids) async {
    final list = <PieceRecord>[];
    for (final id in ids) {
      final r = await _isar.pieceRecords.get(id);
      if (r == null) continue;
      r.deletedAt = null;
      list.add(r);
    }
    if (list.isEmpty) return;
    await _isar.writeTxn(() => _isar.pieceRecords.putAll(list));
  }

  /// 物理删除（回收站里「彻底删除」/ 30 天自动清理）
  Future<void> purge(Id id) async {
    await _isar.writeTxn(() => _isar.pieceRecords.delete(id));
  }

  Future<int> purgeMany(Iterable<Id> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return 0;
    return _isar.writeTxn(() => _isar.pieceRecords.deleteAll(list));
  }

  /// 清理回收站里超过 [days] 天的记录，返回被清掉的记录（用于删照片）
  Future<List<PieceRecord>> purgeOlderThan(int days) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final old = await _isar.pieceRecords
        .filter()
        .deletedAtIsNotNull()
        .deletedAtLessThan(cutoff)
        .findAll();
    if (old.isEmpty) return const <PieceRecord>[];
    await _isar.writeTxn(
      () => _isar.pieceRecords.deleteAll(old.map((e) => e.id).toList()),
    );
    return old;
  }

  Future<void> clear() async {
    await _isar.writeTxn(() => _isar.pieceRecords.clear());
  }

  Future<void> putAll(List<PieceRecord> list) async {
    if (list.isEmpty) return;
    await _isar.writeTxn(() => _isar.pieceRecords.putAll(list));
  }

  Future<int> count() => _isar.pieceRecords.count();
}
