import 'package:isar_community/isar.dart';

part 'chat_session.g.dart';

/// 一次对话会话。
///
/// 为什么要独立成表：所有消息塞进一个 sessionId 会互相污染 ——
/// 上个月查 A1023 的筛选条件会带进这个月问 B2001 的上下文里。
/// 每个会话有自己的历史、自己的压缩摘要。
@collection
class ChatSession {
  Id id = Isar.autoIncrement;

  /// 标题：默认取首条用户消息前 20 字，可重命名
  @Index()
  late String title;

  late DateTime createdAt;

  @Index()
  late DateTime updatedAt;

  /// 消息条数（冗余字段，列表页不用再查一遍）
  int messageCount = 0;

  /// 早期对话压缩成的摘要（覆盖 [summaryUpToId] 之前的消息）
  String summary = '';

  /// 摘要已经覆盖到哪条消息（含该 id）
  int summaryUpToId = 0;

  /// 被压缩掉的消息条数（UI 显示「已压缩 N 条」）
  int compactedCount = 0;
}
