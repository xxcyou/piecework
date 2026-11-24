import 'package:isar_community/isar.dart';

import '../models/chat_message.dart';
import '../models/chat_session.dart';

/// 对话历史仓储
class ChatRepository {
  ChatRepository(this._isar);

  final Isar _isar;

  Future<List<ChatMessage>> session(int sessionId) => _isar.chatMessages
      .filter()
      .sessionIdEqualTo(sessionId)
      .sortByCreatedAt()
      .findAll();

  Stream<List<ChatMessage>> watchSession(int sessionId) => _isar.chatMessages
      .filter()
      .sessionIdEqualTo(sessionId)
      .sortByCreatedAt()
      .watch(fireImmediately: true);

  Future<void> add(ChatMessage message) async {
    await _isar.writeTxn(() => _isar.chatMessages.put(message));
  }

  /// 按 id 批量删（撤回消息用）
  Future<void> deleteByIds(List<Id> ids) async {
    if (ids.isEmpty) return;
    await _isar.writeTxn(() => _isar.chatMessages.deleteAll(ids));
  }

  // ───────────────────────── 会话管理 ─────────────────────────

  /// 会话列表；[profileId] 非空时只列该身份的会话
  Future<List<ChatSession>> sessions({int? profileId}) {
    if (profileId == null) {
      return _isar.chatSessions.where().sortByUpdatedAtDesc().findAll();
    }
    return _isar.chatSessions
        .filter()
        .profileIdEqualTo(profileId)
        .sortByUpdatedAtDesc()
        .findAll();
  }

  Future<ChatSession?> sessionById(Id id) => _isar.chatSessions.get(id);

  /// 最近一个会话；没有就建一个（按身份隔离）
  Future<ChatSession> latestOrCreate({int? profileId}) async {
    final list = await sessions(profileId: profileId);
    if (list.isNotEmpty) return list.first;
    return createSession('新对话', profileId: profileId);
  }

  Future<ChatSession> createSession(String title, {int? profileId}) async {
    final now = DateTime.now();
    final s = ChatSession();
    s.profileId = profileId ?? 0;
    s.title = title.trim().isEmpty ? '新对话' : title.trim();
    s.createdAt = now;
    s.updatedAt = now;
    s.messageCount = 0;
    await _isar.writeTxn(() => _isar.chatSessions.put(s));
    return s;
  }

  Future<void> renameSession(Id id, String title) async {
    final s = await _isar.chatSessions.get(id);
    if (s == null) return;
    s.title = title.trim().isEmpty ? s.title : title.trim();
    s.updatedAt = DateTime.now();
    await _isar.writeTxn(() => _isar.chatSessions.put(s));
  }

  /// 删会话连同它的消息一起删
  Future<void> deleteSession(Id id) async {
    await _isar.writeTxn(() async {
      await _isar.chatMessages.filter().sessionIdEqualTo(id.toInt()).deleteAll();
      await _isar.chatSessions.delete(id);
    });
  }

  /// 更新会话的冗余状态（消息数 / 摘要 / 压缩进度 / 标题）
  Future<void> touchSession(
    Id id, {
    int? messageCount,
    String? summary,
    int? summaryUpToId,
    int? compactedCount,
    String? title,
  }) async {
    final s = await _isar.chatSessions.get(id);
    if (s == null) return;
    if (messageCount != null) s.messageCount = messageCount;
    if (summary != null) s.summary = summary;
    if (summaryUpToId != null) s.summaryUpToId = summaryUpToId;
    if (compactedCount != null) s.compactedCount = compactedCount;
    if (title != null && title.trim().isNotEmpty) s.title = title.trim();
    s.updatedAt = DateTime.now();
    await _isar.writeTxn(() => _isar.chatSessions.put(s));
  }

  Future<void> clearSession(int sessionId) async {
    await _isar.writeTxn(() async {
      await _isar.chatMessages
          .filter()
          .sessionIdEqualTo(sessionId)
          .deleteAll();
    });
  }
}
