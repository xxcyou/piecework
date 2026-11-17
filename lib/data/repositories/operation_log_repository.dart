import 'dart:convert';

import 'package:isar_community/isar.dart';

import '../models/operation_log.dart';
import '../models/piece_record.dart';
import '../services/record_codec.dart';

/// 操作日志仓储 + 撤销引擎。
///
/// 每次写操作都留一份快照，撤销时按类型回放 —— 这就是「AI 理解错了也能撤回」的底座。
class OperationLogRepository {
  OperationLogRepository(this._isar);

  final Isar _isar;

  /// 记一条操作（before = 操作前的记录，after = 新建的记录）
  Future<OperationLog> record({
    required OpKind kind,
    required String source,
    required String summary,
    List<PieceRecord> before = const <PieceRecord>[],
    List<PieceRecord> after = const <PieceRecord>[],
  }) async {
    final log = OperationLog();
    log.kind = kind.wireName;
    log.source = source;
    log.summary = summary;
    log.recordCount = before.isNotEmpty ? before.length : after.length;
    log.payload = jsonEncode(<String, dynamic>{
      'before': before.map(RecordCodec.toJson).toList(),
      'after': after.map(RecordCodec.toJson).toList(),
    });
    log.createdAt = DateTime.now();
    await _isar.writeTxn(() => _isar.operationLogs.put(log));
    return log;
  }

  Future<List<OperationLog>> recent({int limit = 50}) async {
    final list = await _isar.operationLogs
        .where()
        .sortByCreatedAtDesc()
        .findAll();
    return list.take(limit).toList();
  }

  Future<OperationLog?> byId(Id id) => _isar.operationLogs.get(id);

  /// 撤销一次操作。返回 false 表示已撤销过或数据异常。
  Future<bool> undo(Id logId) async {
    final log = await _isar.operationLogs.get(logId);
    if (log == null || log.undone) return false;

    Map<String, dynamic> data;
    try {
      final raw = jsonDecode(log.payload);
      if (raw is! Map) return false;
      data = raw.map((k, v) => MapEntry(k.toString(), v));
    } catch (_) {
      return false;
    }

    List<Map<String, dynamic>> list(Object? v) {
      if (v is! List) return const <Map<String, dynamic>>[];
      return v
          .whereType<Map>()
          .map((e) => e.map((k, vv) => MapEntry(k.toString(), vv)))
          .toList();
    }

    final before = list(data['before']);
    final after = list(data['after']);
    final now = DateTime.now();

    switch (log.kindEnum) {
      case OpKind.delete:
        // 删掉的 → 从回收站捞回来
        for (final j in before) {
          final r = RecordCodec.fromJson(j);
          r.deletedAt = null;
          await _isar.writeTxn(() => _isar.pieceRecords.put(r));
        }
      case OpKind.create:
        // 新建的 → 软删（进回收站，还能再救一次）
        for (final j in after) {
          final r = RecordCodec.fromJson(j);
          r.deletedAt = now;
          await _isar.writeTxn(() => _isar.pieceRecords.put(r));
        }
      case OpKind.update:
        // 改过的 → 把旧值写回去
        for (final j in before) {
          final r = RecordCodec.fromJson(j);
          await _isar.writeTxn(() => _isar.pieceRecords.put(r));
        }
      case OpKind.restore:
        // 恢复过的 → 再删一次
        for (final j in before) {
          final r = RecordCodec.fromJson(j);
          r.deletedAt = now;
          await _isar.writeTxn(() => _isar.pieceRecords.put(r));
        }
    }

    log.undone = true;
    log.undoneAt = now;
    await _isar.writeTxn(() => _isar.operationLogs.put(log));
    return true;
  }

  /// 清理超过 [days] 天的日志
  Future<int> purgeOlderThan(int days) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final old = await _isar.operationLogs
        .filter()
        .createdAtLessThan(cutoff)
        .findAll();
    if (old.isEmpty) return 0;
    await _isar.writeTxn(
      () => _isar.operationLogs.deleteAll(old.map((e) => e.id).toList()),
    );
    return old.length;
  }
}
