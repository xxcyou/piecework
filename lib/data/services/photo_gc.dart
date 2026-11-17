import 'package:isar_community/isar.dart';

import '../models/chat_message.dart';
import '../models/piece_record.dart';
import 'photo_service.dart';

/// 图片引用计数与安全删除。
///
/// 规则（用户明确要求）：
/// * 一张图可以被多条记录共用（内容相同就共用同一份文件）；
/// * 删记录**不等于**删图 —— 只有当**没有任何记录**（含回收站里的）还引用它时，
///   文件才可以删；
/// * 因此所有「删图片」的地方都必须走 [deleteIfUnreferenced]，
///   不要再直接调 `PhotoService.delete`。
///
/// 计数是实时查库算出来的，不额外维护计数器 —— 计数器一旦漂移就会删错图，
/// 而这里的数据量（几千条）查一次也就毫秒级。
class PhotoGc {
  PhotoGc(this._isar);

  final Isar _isar;

  /// 这张图被多少条记录引用（**包含回收站里的记录**，
  /// 否则「删记录 → 图没了 → 从回收站恢复却看不到图」）
  Future<int> refCount(
    String name, {
    String sub = PhotoService.recordsDir,
  }) async {
    if (name.isEmpty) return 0;
    if (sub == PhotoService.chatDir) {
      return _isar.chatMessages
          .filter()
          .imageNameEqualTo(name)
          .count();
    }
    return _isar.pieceRecords
        .filter()
        .photoNameEqualTo(name)
        .count();
  }

  /// 批量查每张图被引用几次：{文件名: 次数}
  Future<Map<String, int>> refCounts({String sub = PhotoService.recordsDir}) async {
    final out = <String, int>{};
    if (sub == PhotoService.chatDir) {
      final rows = await _isar.chatMessages.where().findAll();
      for (final c in rows) {
        if (c.imageName.isEmpty) continue;
        out[c.imageName] = (out[c.imageName] ?? 0) + 1;
      }
      return out;
    }
    final rows = await _isar.pieceRecords.where().findAll();
    for (final r in rows) {
      if (r.photoName.isEmpty) continue;
      out[r.photoName] = (out[r.photoName] ?? 0) + 1;
    }
    return out;
  }

  /// 没有引用才删文件；返回是否真的删了
  Future<bool> deleteIfUnreferenced(
    String name, {
    String sub = PhotoService.recordsDir,
  }) async {
    if (name.isEmpty) return false;
    final n = await refCount(name, sub: sub);
    if (n > 0) return false;
    await PhotoService.instance.delete(name, sub: sub);
    return true;
  }

  /// 清理所有「没有任何引用」的孤儿图，返回删除张数
  Future<int> cleanOrphans({String sub = PhotoService.recordsDir}) async {
    final counts = await refCounts(sub: sub);
    final names = await PhotoService.instance.listNames(sub: sub);
    var removed = 0;
    for (final n in names) {
      if ((counts[n] ?? 0) > 0) continue;
      await PhotoService.instance.delete(n, sub: sub);
      removed++;
    }
    return removed;
  }
}
