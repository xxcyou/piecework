import 'package:isar_community/isar.dart';

import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../models/piece_record.dart';
import '../models/profile.dart';

/// 身份卡仓储：增删改查 + **老数据迁移**（把没有归属的记录打给默认身份）。
///
/// 金融相关，所以迁移只做「补字段」，绝不删数据：
/// 先确保存在一个默认身份，再把 profileId == 0 的行统一挂过去。
class ProfileRepository {
  ProfileRepository(this._isar);

  final Isar _isar;

  Stream<List<Profile>> watchAll({bool includeArchived = false}) {
    if (includeArchived) {
      return _isar.profiles
          .where()
          .sortByCreatedAt()
          .watch(fireImmediately: true);
    }
    return _isar.profiles
        .filter()
        .archivedEqualTo(false)
        .sortByCreatedAt()
        .watch(fireImmediately: true);
  }

  Future<List<Profile>> all({bool includeArchived = false}) async {
    if (includeArchived) {
      return _isar.profiles.where().sortByCreatedAt().findAll();
    }
    return _isar.profiles
        .filter()
        .archivedEqualTo(false)
        .sortByCreatedAt()
        .findAll();
  }

  Future<Profile?> byId(Id id) => _isar.profiles.get(id);

  Future<Profile> create(
    String name, {
    String colorName = '',
    String note = '',
  }) async {
    final p = Profile()
      ..name = name.trim().isEmpty ? '未命名' : name.trim()
      ..colorName = colorName
      ..note = note
      ..createdAt = DateTime.now();
    await _isar.writeTxn(() => _isar.profiles.put(p));
    return p;
  }

  Future<void> update(Profile p) async {
    await _isar.writeTxn(() => _isar.profiles.put(p));
  }

  /// 每个身份下有多少条（不含回收站）
  Future<Map<int, int>> recordCounts() async {
    final rows = await _isar.pieceRecords.filter().deletedAtIsNull().findAll();
    final out = <int, int>{};
    for (final r in rows) {
      out[r.profileId] = (out[r.profileId] ?? 0) + 1;
    }
    return out;
  }

  /// 删除身份：**连它的记录一起软删除**（进回收站，可恢复），默认身份不允许删
  Future<int> deleteWithRecords(Id id) async {
    final p = await _isar.profiles.get(id);
    if (p == null || p.isDefault) return 0;
    var n = 0;
    await _isar.writeTxn(() async {
      final rows = await _isar.pieceRecords
          .filter()
          .profileIdEqualTo(id.toInt())
          .deletedAtIsNull()
          .findAll();
      for (final r in rows) {
        r.deletedAt = DateTime.now();
        await _isar.pieceRecords.put(r);
        n++;
      }
      await _isar.profiles.delete(id);
    });
    return n;
  }

  /// 确保有默认身份；并把历史上 profileId==0 的记录/对话挂过去。
  ///
  /// 返回默认身份。可重复调用（幂等）。
  Future<Profile> ensureDefault() async {
    final existing = await _isar.profiles.where().sortByCreatedAt().findAll();
    var def = existing.where((p) => p.isDefault).firstOrNull;
    if (def == null) {
      if (existing.isNotEmpty) {
        // 老库没有标记：把最早的当默认
        def = existing.first..isDefault = true;
        await _isar.writeTxn(() => _isar.profiles.put(def!));
      } else {
        def = Profile()
          ..name = '我'
          ..colorName = '藏青'
          ..note = ''
          ..isDefault = true
          ..createdAt = DateTime.now();
        await _isar.writeTxn(() => _isar.profiles.put(def!));
      }
    }

    final id = def.id;
    await _isar.writeTxn(() async {
      final orphans = await _isar.pieceRecords
          .filter()
          .profileIdEqualTo(0)
          .findAll();
      for (final r in orphans) {
        r.profileId = id;
        await _isar.pieceRecords.put(r);
      }
      final msgs =
          await _isar.chatMessages.filter().profileIdEqualTo(0).findAll();
      for (final m in msgs) {
        m.profileId = id;
        await _isar.chatMessages.put(m);
      }
      final sessions =
          await _isar.chatSessions.filter().profileIdEqualTo(0).findAll();
      for (final s in sessions) {
        s.profileId = id;
        await _isar.chatSessions.put(s);
      }
    });
    return def;
  }

  /// 把某个身份的记录搬到另一个身份（合并身份用，目前未接 UI）
  Future<int> moveRecords(Id from, Id to) async {
    var n = 0;
    await _isar.writeTxn(() async {
      final rows = await _isar.pieceRecords
          .filter()
          .profileIdEqualTo(from.toInt())
          .findAll();
      for (final r in rows) {
        r.profileId = to.toInt();
        await _isar.pieceRecords.put(r);
        n++;
      }
    });
    return n;
  }
}

/// 记录/对话的归属类型（备份与迁移共用）
class ProfileScope {
  const ProfileScope(this.profileId);
  final int profileId;

  static int of(PieceRecord r) => r.profileId;
  static int ofMessage(ChatMessage m) => m.profileId;
  static int ofSession(ChatSession s) => s.profileId;
}
