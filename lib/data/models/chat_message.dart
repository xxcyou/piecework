import 'package:isar_community/isar.dart';

part 'chat_message.g.dart';

/// AI 对话消息。
///
/// 只落库「用户看到的」消息；发给模型的 tool / assistant(tool_calls) 中间态
/// 仅在单次请求内存在，不污染历史记录。
@collection
class ChatMessage {
  Id id = Isar.autoIncrement;

  /// 会话 ID（本项目只用一个会话，保留字段方便以后扩展多会话）
  @Index()
  late int sessionId;

  /// 'user' | 'assistant'
  late String role;

  late String content;

  /// 用户随消息发送的图片文件名（相对 `<AppDocuments>/chat_photos/`）
  String imageName = '';

  /// 若本次回答基于一次本地检索，这里存 RecordFilter 的 JSON，
  /// UI 据此渲染「查看这批记录 →」按钮，一键跳到筛选后的列表。
  String filterJson = '';

  /// 结构化统计快照（分组汇总卡片用），JSON
  String statsJson = '';

  /// 待用户确认的写操作（PendingAction 的 JSON）。
  /// 非空时气泡下方会渲染「确认执行 / 取消」卡片，用户点了才真正写库。
  String actionJson = '';

  /// 本次回答调用过的工具轨迹（ToolTrace 数组）与界面动作（UiAction 数组），
  /// JSON：{"traces":[...], "actions":[...]}。聊天里那张「工具卡片」靠它渲染。
  String toolsJson = '';

  /// 这次回答执行写操作后生成的 OperationLog id。
  /// 非 0 时气泡里会出现「撤销这次操作」按钮。
  int actionLogId = 0;

  /// 模型的思考过程（DeepSeek 的 reasoning_content / OpenAI 的 reasoning）
  String reasoning = '';

  /// 数字校验警告（非空说明 AI 报的数与数据库不一致，需提示用户）
  String numberWarning = '';

  /// 发送失败的原因（非空时消息旁边显示红色感叹号，可查看原因并重试）
  String failReason = '';

  /// 本次消耗的 token（来自接口 usage）
  int promptTokens = 0;
  int completionTokens = 0;
  int totalTokens = 0;

  @Index()
  late DateTime createdAt;

  bool get isUser => role == 'user';
}
