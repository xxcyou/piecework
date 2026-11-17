import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../data/models/app_setting.dart';
import '../data/models/chat_message.dart';
import '../data/models/chat_session.dart';
import '../data/models/option_item.dart';
import '../data/models/pending_action.dart';
import '../data/models/operation_log.dart';
import '../data/models/piece_record.dart';
import '../data/models/unit_item.dart';
import '../data/models/unit_rule.dart';
import '../core/context_usage.dart';
import '../data/services/ai_service.dart';
import '../data/services/ai_tool_types.dart';
import '../data/services/ai_tools.dart';
import '../data/services/photo_service.dart';
import '../core/date_utils.dart';
import '../core/money.dart';
import '../data/services/record_codec.dart';
import '../data/services/unit_converter.dart';
import 'db_providers.dart';
import 'terminal_providers.dart';
import 'options_providers.dart';
import 'records_providers.dart';
import 'settings_providers.dart';
import 'units_providers.dart';

/// 是否正在等待 AI 回复
final chatBusyProvider = StateProvider<bool>((ref) => false);

/// 用户点「跳过」时发出去的那句话（模型据此按默认继续）
const String skipAskText = '（跳过这个问题，按你认为最合理的默认继续）';

/// 撤回时「留下哪些 / 删掉哪些」：从这条消息开始往后全删，
/// 相当于把上下文截断在这里。
({List<ChatMessage> keep, List<ChatMessage> removed}) splitForRetract(
  List<ChatMessage> all,
  Id id,
) {
  final idx = all.indexWhere((m) => m.id == id);
  if (idx < 0) {
    return (keep: all, removed: const <ChatMessage>[]);
  }
  return (
    keep: all.sublist(0, idx),
    removed: all.sublist(idx),
  );
}

/// 一次回答里所有待确认动作（老的单个 pendingAction 也算进来）
List<PendingAction> actionsOfReply(AiReply reply) =>
    reply.pendingActions.isNotEmpty
        ? reply.pendingActions
        : <PendingAction>[
            if (reply.pendingAction != null) reply.pendingAction!,
          ];

/// 输入框草稿：卡片上的「问 AI」按钮往这里塞一句话，聊天页取走后清空
final chatDraftProvider = StateProvider<String>((ref) => '');

/// 最近一次请求的错误信息（不落库，只用于界面提示）
final chatErrorProvider = StateProvider<String?>((ref) => null);

/// 流式输出中的临时内容（null = 没有正在进行的流）
class StreamingState {
  const StreamingState({
    this.content = '',
    this.reasoning = '',
    this.toolHint = '',
    this.toolCount = 0,
    this.tools = const <String>[],
  });

  final String content;
  final String reasoning;

  /// 正在调用的工具（中文名），空表示还没开始调
  final String toolHint;

  /// 本次回答累计调用了几次工具（界面上的 +1 +2 徽标）
  final int toolCount;

  /// 调过的工具名（按顺序，点 +N 时列出来）
  final List<String> tools;
}

final streamingProvider = StateProvider<StreamingState?>((ref) => null);

/// 模型开始新的一轮时重置流式状态：正文/思考清空，
/// 但**工具计数和上次调用的工具名要保留** —— 这样「等模型继续」的空档里
/// 用户还能看到刚才调了几次、调的是什么，而不是干等一个「正在思考…」
StreamingState nextTurnState(StreamingState? cur) => StreamingState(
      toolCount: cur?.toolCount ?? 0,
      toolHint: cur?.toolHint ?? '',
      tools: cur?.tools ?? const <String>[],
    );

/// 对话消息列表
class ChatNotifier extends AsyncNotifier<List<ChatMessage>> {
  /// 当前会话 id（切换会话时更新）
  int _sessionId = 1;

  /// 数据概览：让模型开口就知道「今天/本周/本月多少」，
  /// 不用先调一遍工具 —— 这是「变聪明」最直接的一招。
  static String _buildDigest(
    List<PieceRecord> records,
    UnitConverter converter,
  ) {
    final now = DateTime.now();

    String line(String label, DateTime from) {
      final list = records
          .where((r) => r.deletedAt == null && !r.createdAt.isBefore(from))
          .toList();
      if (list.isEmpty) return '$label：暂无记录';

      var qty = 0;
      var amt = 0;
      var centi = 0;
      final units = <String>{};
      for (final r in list) {
        qty += r.quantity;
        amt += r.subtotalMilli;
        centi += converter.centiBaseOf(r).toInt();
        units.add(r.unitOrBase);
      }

      final qtyText = units.length > 1
          ? '${(centi / 100).toStringAsFixed(1)} ${converter.baseUnit}（折算）'
          : '$qty ${units.isEmpty ? converter.baseUnit : units.first}';

      return '$label：${list.length} 条 · $qtyText · ¥${Money.format(amt)}';
    }

    final today = DateUtil.startOfDay(now);
    final week = today.subtract(Duration(days: today.weekday - 1));
    final month = DateTime(now.year, now.month, 1);
    final live = records.where((r) => r.deletedAt == null).toList();
    final pending = live.where((r) => r.status == RecordStatus.pending).length;

    // 最近用过的型号（帮模型猜用户想问哪个）
    final models = <String>{};
    for (final r in live.take(60)) {
      if (r.styleModel.isNotEmpty) models.add(r.styleModel);
    }

    return '''

【当前数据概览 · 系统自动注入，回答这类问题不必再调工具】
${line('今天', today)}
${line('本周', week)}
${line('本月', month)}
未上报 $pending 条 / 总记录 ${live.length} 条
最近型号：${models.take(8).join('、')}''';
  }

  /// 用户点了停止
  bool _cancelRequested = false;

  /// 停止当前回答（流式读取 / 工具循环会在下一个检查点退出）
  void cancel() {
    _cancelRequested = true;
    // UI 立刻恢复，不等请求真正结束
    ref.read(chatBusyProvider.notifier).state = false;
  }

  int get sessionId => _sessionId;

  @override
  Future<List<ChatMessage>> build() async {
    final settings = await ref.watch(settingsProvider.future);
    final repo = ref.watch(chatRepoProvider);

    final existing = await repo.sessionById(settings.chatSessionId);
    final s = existing ?? await repo.latestOrCreate();
    _sessionId = s.id;
    return repo.session(s.id);
  }

  // ───────────────────────── 会话管理 ─────────────────────────

  Future<void> switchTo(int id) async {
    final repo = ref.read(chatRepoProvider);
    _sessionId = id;
    await ref.read(settingsProvider.notifier).mutate((s) => s.chatSessionId = id);
    state = AsyncData(await repo.session(id));
    ref.invalidate(sessionsProvider);
  }

  Future<void> newSession() async {
    final repo = ref.read(chatRepoProvider);
    final s = await repo.createSession('新对话');
    await switchTo(s.id);
  }

  Future<void> renameSession(int id, String title) async {
    await ref.read(chatRepoProvider).renameSession(id, title);
    ref.invalidate(sessionsProvider);
    if (id == _sessionId) {
      final list = await ref.read(chatRepoProvider).session(id);
      state = AsyncData(list);
    }
  }

  Future<void> deleteSession(int id) async {
    final repo = ref.read(chatRepoProvider);
    await repo.deleteSession(id);
    ref.invalidate(sessionsProvider);
    if (id == _sessionId) {
      final latest = await repo.latestOrCreate();
      await switchTo(latest.id);
    }
  }

  /// 手动触发上下文压缩
  Future<void> compactContext() async {
    await _maybeCompact(force: true);
  }

  Future<void> send({
    required String text,
    Uint8List? imageBytes,
    String imageName = '',
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && imageBytes == null) return;
    if (ref.read(chatBusyProvider)) return;

    ref.read(chatBusyProvider.notifier).state = true;
    ref.read(chatErrorProvider.notifier).state = null;
    _cancelRequested = false;

    final repo = ref.read(chatRepoProvider);
    // 等设置真正落盘后再解析配置，避免首帧读到默认值
    await ref.read(settingsProvider.future);
    final sessionId = _sessionId;
    final history = List<ChatMessage>.from(state.valueOrNull ?? const []);

    // 1. 先把用户消息落库并上屏
    final userMsg = ChatMessage();
    userMsg.sessionId = sessionId;
    userMsg.role = 'user';
    userMsg.content = trimmed;
    userMsg.imageName = imageName;
    userMsg.createdAt = DateTime.now();
    await repo.add(userMsg);
    state = AsyncData(<ChatMessage>[...history, userMsg]);

    await _runReply(
      history: history,
      userText: trimmed,
      imageName: imageName,
      imageBytes: imageBytes,
      userMsg: userMsg,
    );
  }

  /// 跑一轮 AI（首次发送和「重试」共用同一套逻辑）
  Future<void> _runReply({
    required List<ChatMessage> history,
    required String userText,
    required String imageName,
    Uint8List? imageBytes,
    ChatMessage? userMsg,
  }) async {
    final repo = ref.read(chatRepoProvider);
    final sessionId = _sessionId;
    // 长会话：摘要 + 最近若干条，避免把整段历史塞进上下文
    final sessionRow = await repo.sessionById(sessionId);
    final historySummary = sessionRow?.summary ?? '';

    try {
      // 2. 取最新本地数据做只读快照
      // 注意：必须 await —— 用 valueOrNull 拿到 null 时会给模型一个空库，
      // 于是「查询全部多少钱」就变成 0 条 0 元（真实 bug）
      final records = await ref.read(recordsProvider.future);
      final options = await ref.read(optionsProvider.future);

      final executor = AiToolExecutor(
        host: _ChatToolHost(ref),
        records: records,
        options: options,
        // 本次带图提问：AI 新建记录时会把这张图关联上
        contextPhotoName: imageName,
      );
      // ── 唯一配置来源：aiConfigProvider ──
      // 这里**绝不能**再手搓 AiConfig 对象去读 settings.aiBaseUrl/aiModel：
      // 内置提供商（Kilo 免费）模式下，库里那三个字段是「自定义提供商」的
      // 历史残留（默认 https://api.openai.com/v1 + gpt-4o-mini）。
      // 绕过 aiConfigProvider 的后果就是：
      //   1) 选了内置免费模型，请求却打到第三方（OpenAI）；
      //   2) 没填 key 时 isConfigured=false，误报「还没配置 AI 接口」。
      final config = ref.read(aiConfigProvider);

      // 3. 调模型（流式；内部可能多轮工具调用）
      ref.read(streamingProvider.notifier).state = const StreamingState();
      final reply = await ref.read(aiServiceProvider).ask(
            config: config,
            history: history,
            userText: userText,
            imageBytes: imageBytes,
            historySummary: historySummary,
            executor: executor,
            onTurnStart: () {
              // 新的一轮（模型再次思考）：正文/思考清空，但**工具计数要保留**，
              // 否则每轮都归零，界面上的 +N 永远看不到
              ref.read(streamingProvider.notifier).state = nextTurnState(
                ref.read(streamingProvider.notifier).state,
              );
            },
            onDelta: (c, r) {
              final cur = ref.read(streamingProvider.notifier).state ??
                  const StreamingState();
              ref.read(streamingProvider.notifier).state = StreamingState(
                content: cur.content + c,
                // 用户关了「思考」就不显示思考过程
                // （有的模型即使不传 reasoning_effort 也会回 reasoning_content）
                reasoning: config.thinkingEnabled ? cur.reasoning + r : '',
                toolHint: cur.toolHint,
                toolCount: cur.toolCount,
                tools: cur.tools,
              );
            },
            dataDigest: _buildDigest(records, ref.read(unitConverterProvider)),
            isCancelled: () => _cancelRequested,
            onToolHint: (name, count) {
              final cur = ref.read(streamingProvider.notifier).state ??
                  const StreamingState();
              final label = toolLabel(name);
              ref.read(streamingProvider.notifier).state = StreamingState(
                content: cur.content,
                reasoning: cur.reasoning,
                toolHint: label,
                toolCount: count,
                tools: <String>[...cur.tools, label],
              );
            },
          );

      // 用户中途点了停止：把已收到的部分保存下来
      if (_cancelRequested) {
        final partial = reply.text.trim();
        if (partial.isNotEmpty) {
          final stopMsg = ChatMessage();
          stopMsg.sessionId = sessionId;
          stopMsg.role = 'assistant';
          stopMsg.content = '$partial\n\n（已停止）';
          stopMsg.createdAt = DateTime.now();
          stopMsg.reasoning = reply.reasoning;
          await repo.add(stopMsg);
          state = AsyncData(<ChatMessage>[
            ...(state.valueOrNull ?? const <ChatMessage>[]),
            stopMsg,
          ]);
        }
        return;
      }

      // 4. 助手消息落库
      final aiMsg = ChatMessage();
      aiMsg.sessionId = sessionId;
      aiMsg.role = 'assistant';
      aiMsg.content = reply.text;
      aiMsg.createdAt = DateTime.now();
      aiMsg.reasoning = config.thinkingEnabled ? reply.reasoning : '';
      aiMsg.numberWarning = reply.numberWarning ?? '';
      aiMsg.promptTokens = reply.promptTokens;
      aiMsg.completionTokens = reply.completionTokens;
      aiMsg.totalTokens = reply.totalTokens;
      if (reply.filter != null) {
        aiMsg.filterJson = jsonEncode(reply.filter!.toJson());
      }
      if (reply.stats != null || reply.groups != null) {
        aiMsg.statsJson = jsonEncode(<String, dynamic>{
          if (reply.stats != null) 'summary': reply.stats,
          if (reply.groups != null)
            'groups': reply.groups!.map((g) => g.toJson()).toList(),
        });
      }
      // 写操作提议：界面上渲染「确认执行」卡片，用户点了才落库。
      // 一条消息可能有多个写操作（改数量 + 关联图 + 删记录），
      // 第一张挂在这条回复上，其余的作为独立卡片消息插在后面。
      final allActions = actionsOfReply(reply);
      if (allActions.isNotEmpty) {
        aiMsg.actionJson = jsonEncode(allActions.first.toJson());
      }
      // 工具轨迹 + 界面动作 + agent 任务：渲染工具卡片、跳转按钮、执行计划
      if (reply.traces.isNotEmpty ||
          reply.uiActions.isNotEmpty ||
          reply.agentTask != null ||
          reply.ask != null ||
          reply.svg != null ||
          reply.calc != null ||
          reply.code != null ||
          reply.photos.isNotEmpty ||
          reply.svgs.length > 1 ||
          reply.calcs.length > 1 ||
          reply.codes.length > 1 ||
          reply.photoGroups.length > 1) {
        aiMsg.toolsJson = jsonEncode(<String, dynamic>{
          if (reply.traces.isNotEmpty)
            'traces': reply.traces.map((t) => t.toJson()).toList(),
          if (reply.uiActions.isNotEmpty)
            'actions': reply.uiActions.map((a) => a.toJson()).toList(),
          if (reply.agentTask != null) 'task': reply.agentTask!.toJson(),
          if (reply.ask != null) 'ask': reply.ask!.toJson(),
          // 单张（兼容老消息）
          if (reply.svg != null) 'svg': reply.svg!.toJson(),
          if (reply.calc != null) 'calc': reply.calc!.toJson(),
          if (reply.code != null) 'code': reply.code!.toJson(),
          if (reply.photos.isNotEmpty) 'photos': reply.photos,
          // 多张：同类卡片全部保留
          if (reply.svgs.length > 1)
            'svgs': reply.svgs.map((e) => e.toJson()).toList(),
          if (reply.calcs.length > 1)
            'calcs': reply.calcs.map((e) => e.toJson()).toList(),
          if (reply.codes.length > 1)
            'codes': reply.codes.map((e) => e.toJson()).toList(),
          if (reply.photoGroups.length > 1)
            'photoGroups': reply.photoGroups,
        });
      }
      await repo.add(aiMsg);
      state = AsyncData(<ChatMessage>[
        ...(state.valueOrNull ?? const <ChatMessage>[]),
        aiMsg,
      ]);

      // 其余确认卡片：各自一条消息，用户逐个点确认
      for (final extra in allActions.skip(1)) {
        final card = ChatMessage()
          ..sessionId = sessionId
          ..role = 'assistant'
          ..content = ''
          ..createdAt = DateTime.now()
          ..actionJson = jsonEncode(extra.toJson());
        await repo.add(card);
        state = AsyncData(<ChatMessage>[
          ...(state.valueOrNull ?? const <ChatMessage>[]),
          card,
        ]);
      }

      // 首条用户消息决定会话标题；同时刷新会话列表
      final after = state.valueOrNull ?? const <ChatMessage>[];
      final firstUser = after.where((m) => m.isUser).toList();
      await repo.touchSession(
        sessionId,
        messageCount: after.length,
        title:
            firstUser.length == 1 ? _titleFrom(firstUser.first.content) : null,
      );
      ref.invalidate(sessionsProvider);

      // 后台压缩长会话（不阻塞界面）
      unawaited(_maybeCompact());
    } on AiException catch (e) {
      await _markFailed(userMsg, e.message);
    } catch (e) {
      await _markFailed(userMsg, '出错了：$e');
    } finally {
      ref.read(chatBusyProvider.notifier).state = false;
      ref.read(streamingProvider.notifier).state = null;
    }
  }

  /// 发送失败：给那条用户消息打上红色感叹号，并保留原因供查看/重试
  Future<void> _markFailed(ChatMessage? msg, String reason) async {
    ref.read(chatErrorProvider.notifier).state = reason;
    if (msg == null) return;
    msg.failReason = reason;
    try {
      await ref.read(chatRepoProvider).add(msg);
    } catch (_) {}
    final list = state.valueOrNull;
    if (list != null) {
      state = AsyncData(<ChatMessage>[
        for (final m in list) m.id == msg.id ? msg : m,
      ]);
    }
  }

  /// 撤回一条自己的消息：**真的删掉**，并且把它之后的对话一起删掉
  /// —— 相当于上下文回到这里。文字会填回输入框，方便改了重发。
  Future<void> retract(ChatMessage msg) async {
    if (!msg.isUser) return;
    if (ref.read(chatBusyProvider)) return;
    final list = List<ChatMessage>.from(state.valueOrNull ?? const []);
    final split = splitForRetract(list, msg.id);
    if (split.removed.isEmpty) return;

    final removed = split.removed;
    final keep = split.keep;
    await ref.read(chatRepoProvider).deleteByIds(
          removed.map((m) => m.id).toList(),
        );
    state = AsyncData(keep);
    ref.read(chatDraftProvider.notifier).state = msg.content;
    ref.invalidate(sessionsProvider);
    await ref.read(chatRepoProvider).touchSession(
          _sessionId,
          messageCount: keep.length,
        );
  }

  /// 重试一条发送失败的消息：复用这条消息（不重复插入），重新跑一轮
  Future<void> retry(ChatMessage msg) async {
    if (ref.read(chatBusyProvider)) return;
    final list = List<ChatMessage>.from(state.valueOrNull ?? const []);
    final idx = list.indexWhere((m) => m.id == msg.id);
    if (idx < 0) return;

    ref.read(chatBusyProvider.notifier).state = true;
    ref.read(chatErrorProvider.notifier).state = null;
    _cancelRequested = false;

    msg.failReason = '';
    await ref.read(chatRepoProvider).add(msg);
    final history = list.sublist(0, idx);
    state = AsyncData(<ChatMessage>[...history, msg]);

    await _runReply(
      history: history,
      userText: msg.content,
      imageName: msg.imageName,
      userMsg: msg,
    );
  }

  /// 用户点了「确认执行」：这时才真正写库
  Future<void> confirmPending(ChatMessage msg) async {
    if (ref.read(chatBusyProvider)) return;

    final action = PendingAction.fromJson(_tryDecode(msg.actionJson));
    if (action == null || action.isEmpty) {
      await _finishAction(msg, '这条操作已经失效了，请重新让 AI 发起。');
      return;
    }

    ref.read(chatBusyProvider.notifier).state = true;
    ref.read(chatErrorProvider.notifier).state = null;
    final repo = ref.read(recordRepoProvider);
    final opLog = ref.read(opLogRepoProvider);

    // 撤销快照
    final before = <PieceRecord>[];
    final after = <PieceRecord>[];
    OpKind? opKind;

    try {
      final String done;
      switch (action.kind) {
        case PendingKind.delete:
          // 软删除：进回收站，30 天内可恢复。照片先留着，恢复后还要显示。
          for (final id in action.ids) {
            final r = await repo.byId(id);
            if (r != null && r.deletedAt == null) before.add(r);
          }
          await repo.deleteMany(action.ids);
          opKind = OpKind.delete;
          done = '已删除 ${action.ids.length} 条记录（在回收站可恢复）';

        case PendingKind.update:
          var n = 0;
          for (final id in action.ids) {
            final r = await repo.byId(id);
            if (r == null) continue;
            before.add(RecordCodec.fromJson(RecordCodec.toJson(r)));
            final c = action.changes;
            if (c['unitPrice'] is num) {
              r.unitPrice = (c['unitPrice'] as num).toDouble();
            }
            if (c['quantity'] is num) {
              r.quantity = (c['quantity'] as num).toInt();
            }
            if (c['note'] is String) r.note = c['note'] as String;
            if (c['color'] is String) r.color = c['color'] as String;
            if (c['size'] is String) r.size = c['size'] as String;
            if (c['styleModel'] is String) {
              r.styleModel = c['styleModel'] as String;
            }
            if (c['status'] is String) {
              final st = recordStatusFromWire(c['status']);
              r.status = st;
              r.reportedAt =
                  st == RecordStatus.reported ? DateTime.now() : null;
            }
            // 改录入时间：只给日期时保留这条记录原来的时刻
            final d = c['date'] as String?;
            final t = c['time'] as String?;
            if (d != null || t != null) {
              final parsed = DateTime.tryParse(d ?? '');
              final old = r.createdAt;
              var hour = old.hour;
              var minute = old.minute;
              if (t != null) {
                final parts = t.split(':');
                if (parts.length == 2) {
                  hour = int.tryParse(parts[0]) ?? hour;
                  minute = int.tryParse(parts[1]) ?? minute;
                }
              }
              r.createdAt = DateTime(
                parsed?.year ?? old.year,
                parsed?.month ?? old.month,
                parsed?.day ?? old.day,
                hour,
                minute,
              );
            }
            r.updatedAt = DateTime.now();
            await repo.save(r);
            n++;
          }
          opKind = OpKind.update;
          done = '已修改 $n 条记录';

        case PendingKind.create:
          var n = 0;
          var withPhoto = 0;
          for (final item in action.items) {
            final r = PieceRecord();
            r.styleModel = (item['styleModel'] as String?) ?? '';
            r.color = (item['color'] as String?) ?? '';
            r.size = (item['size'] as String?) ?? '';
            final u = (item['unit'] as String?)?.trim() ?? '';
            r.unit = u.isEmpty ? '件' : u;
            r.quantity = (item['quantity'] as num?)?.toInt() ?? 1;
            r.unitPrice = (item['unitPrice'] as num?)?.toDouble() ?? 0;
            r.note = (item['note'] as String?) ?? '';
            r.photoName = '';
            // 用户带图说话：把对话图复制进记录目录并关联
            final srcPhoto = (item['photoName'] as String?) ?? '';
            if (srcPhoto.isNotEmpty) {
              final copied =
                  await PhotoService.instance.copyToRecords(srcPhoto);
              if (copied != null) {
                r.photoName = copied;
                withPhoto++;
              }
            }
            // 支持 AI 指定的记录日期（用户说「记一条昨天的」）
            final at = DateTime.tryParse((item['createdAt'] as String?) ?? '');
            r.createdAt = at ?? DateTime.now();
            await repo.save(r);
            after.add(RecordCodec.fromJson(RecordCodec.toJson(r)));
            n++;
          }
          opKind = OpKind.create;
          done = withPhoto > 0
              ? '已新建 $n 条记录，其中 $withPhoto 条关联了照片'
              : '已新建 $n 条记录';

        case PendingKind.attachPhoto:
          var n = 0;
          for (final id in action.ids) {
            final r = await repo.byId(id);
            if (r == null) continue;
            // 图可能来自两处：
            // ① 对话里刚发的（chat_photos）→ 复制进记录目录；
            // ② 图库里已有的图（records 目录）→ 直接引用同一个文件（内容寻址，不重复存）
            var target =
                await PhotoService.instance.copyToRecords(action.photoName);
            if (target == null &&
                await PhotoService.instance.fileOf(action.photoName) != null) {
              target = action.photoName;
            }
            if (target == null) continue;
            final copied = target;
            final old = r.photoName;
            r.photoName = copied;
            r.updatedAt = DateTime.now();
            await repo.save(r);
            // 记录已经改指向新图了，再判断旧图还有没有人用（否则会漏删）
            if (old.isNotEmpty && old != copied) {
              await ref.read(photoGcProvider).deleteIfUnreferenced(old);
            }
            n++;
          }
          done = '已给 $n 条记录关联照片';

        case PendingKind.detachPhoto:
          var n = 0;
          for (final id in action.ids) {
            final r = await repo.byId(id);
            if (r == null || r.photoName.isEmpty) continue;
            final old = r.photoName;
            r.photoName = '';
            r.updatedAt = DateTime.now();
            await repo.save(r);
            // 先解引用再判重，避免把别条记录还在用的图删掉
            await ref.read(photoGcProvider).deleteIfUnreferenced(old);
            n++;
          }
          done = '已解除 $n 条记录的照片关联';
      }

      // 记一条操作日志，供「撤销这次操作」
      if (opKind != null) {
        final log = await opLog.record(
          kind: opKind,
          source: 'ai',
          summary: done,
          before: before,
          after: after,
        );
        msg.actionLogId = log.id;
        ref.invalidate(opLogsProvider);
      }

      await _finishAction(msg, '✅ $done');
    } catch (e) {
      ref.read(chatErrorProvider.notifier).state = '执行失败：$e';
    } finally {
      ref.read(chatBusyProvider.notifier).state = false;
    }
  }

  /// 撤销这次 AI 操作（把快照回放回去）
  Future<bool> undoAction(ChatMessage msg) async {
    if (msg.actionLogId == 0) return false;
    ref.read(chatBusyProvider.notifier).state = true;
    try {
      final ok = await ref.read(opLogRepoProvider).undo(msg.actionLogId);
      if (!ok) return false;
      msg.content = '${msg.content}\n\n↩️ 已撤销这次操作，数据已还原';
      msg.actionLogId = 0;
      await ref.read(chatRepoProvider).add(msg);
      _refreshList();
      ref.invalidate(opLogsProvider);
      return true;
    } catch (e) {
      ref.read(chatErrorProvider.notifier).state = '撤销失败：$e';
      return false;
    } finally {
      ref.read(chatBusyProvider.notifier).state = false;
    }
  }

  /// 用户点了「取消」：什么都不做
  Future<void> cancelPending(ChatMessage msg) async {
    await _finishAction(msg, '已取消，数据没有变化。');
  }

  Future<void> _finishAction(ChatMessage msg, String note) async {
    msg.actionJson = '';
    msg.content = msg.content.trim().isEmpty
        ? note
        : '${msg.content}\n\n$note';
    await ref.read(chatRepoProvider).add(msg);
    _refreshList();
  }

  void _refreshList() {
    final list = state.valueOrNull;
    if (list == null) return;
    state = AsyncData(<ChatMessage>[...list]);
  }

  static Object? _tryDecode(String raw) {
    if (raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  /// 超过阈值就把早期对话压成摘要（保留最近 12 条）
  Future<void> _maybeCompact({bool force = false}) async {
    final repo = ref.read(chatRepoProvider);
    final all = await repo.session(_sessionId);

    const keep = 12;
    if (all.length <= keep) return;

    // 按 token 占用判断，而不是死板的消息条数。
    // 窗口必须取「实际生效的模型」的上下文长度（内置模型是 256K/1M），
    // 不能用 settings.contextWindowTokens（那是自定义模式的 8192），
    // 否则内置大窗口模型也会被当成 8K，历史被过早压成摘要。
    await ref.read(settingsProvider.future);
    final config = ref.read(aiConfigProvider);
    final window = config.contextWindow > 0 ? config.contextWindow : 8192;
    var used = 600; // system prompt 粗估
    for (final m in all) {
      used += ContextUsage.estimateTokens(m.content) + 8;
    }
    final ratio = window <= 0 ? 0.0 : used / window;
    if (!force && ratio < 0.7 && all.length <= 24) return;

    final sessionRow = await repo.sessionById(_sessionId);
    final previous = sessionRow?.summary ?? '';
    final cut = all.length - keep;
    final toCompact = all.sublist(0, cut);
    if (toCompact.isEmpty) return;

    if (!config.isConfigured) return;

    try {
      final summary = await ref.read(aiServiceProvider).compressHistory(
            config: config,
            messages: toCompact,
            previousSummary: previous,
          );
      await repo.touchSession(
        _sessionId,
        summary: summary,
        summaryUpToId: toCompact.last.id,
        compactedCount: (sessionRow?.compactedCount ?? 0) + toCompact.length,
      );
      ref.invalidate(sessionsProvider);
    } catch (_) {
      // 压缩失败不影响正常对话，下次再试
    }
  }

  static String _titleFrom(String text) {
    final t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isEmpty) return '新对话';
    return t.length <= 20 ? t : '${t.substring(0, 20)}…';
  }

  /// 把终端里产生的「写操作」落成确认卡片：用户在聊天里点确认才真正落库
  Future<void> persistActionCard(PendingAction action) async {
    final repo = ref.read(chatRepoProvider);
    final msg = ChatMessage();
    msg.sessionId = _sessionId;
    msg.role = 'assistant';
    msg.content = '';
    msg.createdAt = DateTime.now();
    msg.actionJson = jsonEncode(action.toJson());
    await repo.add(msg);
    state = AsyncData(<ChatMessage>[
      ...(state.valueOrNull ?? const <ChatMessage>[]),
      msg,
    ]);
    ref.invalidate(sessionsProvider);
  }

  /// 把一次终端会话落库成普通卡片（内容为空，toolsJson 里带 terminal）
  Future<void> persistTerminalCard(TerminalSessionState session) async {
    if (!session.hasContent) return;
    final repo = ref.read(chatRepoProvider);
    final msg = ChatMessage();
    msg.sessionId = _sessionId;
    msg.role = 'assistant';
    msg.content = '';
    msg.createdAt = DateTime.now();
    msg.toolsJson = jsonEncode(<String, dynamic>{
      'terminal': session.toJson(),
    });
    await repo.add(msg);
    state = AsyncData(<ChatMessage>[
      ...(state.valueOrNull ?? const <ChatMessage>[]),
      msg,
    ]);
    await repo.touchSession(
      _sessionId,
      messageCount: (state.valueOrNull ?? const <ChatMessage>[]).length,
    );
    ref.invalidate(sessionsProvider);
  }

  Future<void> resetSession() async {
    final settings = await ref.read(settingsProvider.future);
    await ref.read(chatRepoProvider).clearSession(settings.chatSessionId);
    ref.read(chatErrorProvider.notifier).state = null;
    state = const AsyncData(<ChatMessage>[]);
  }
}

final chatProvider = AsyncNotifierProvider<ChatNotifier, List<ChatMessage>>(
  ChatNotifier.new,
);


/// 给「终端模式」用：构造一个能直接操作本机数据的工具执行器。
///
/// 终端里敲 `@query_records {...}` 时，走的就是这个执行器 —— 和 AI 在聊天里
/// 调用的是同一套工具、同一份数据、同一套安全边界。
Future<AiToolExecutor> buildChatToolExecutor(
  Ref ref, {
  String contextPhotoName = '',
}) async {
  // 必须 await：valueOrNull 为 null 时会退化成「空库」，查询全部就变成 0 条
  final records = await ref.read(recordsProvider.future);
  final options = await ref.read(optionsProvider.future);
  return AiToolExecutor(
    host: _ChatToolHost(ref),
    records: records,
    options: options,
    contextPhotoName: contextPhotoName,
  );
}

/// 把 App 的仓储能力暴露给 AI 工具。
///
/// 这就是「AI 对 App 有掌控权」的落点：改设置、加单位、配换算、删记录，
/// 全都通过这里落到真实数据库，而不是只读快照。
class _ChatToolHost implements AiToolHost {
  _ChatToolHost(this.ref);

  final Ref ref;

  @override
  Future<List<PieceRecord>> loadRecords() => ref.read(recordRepoProvider).all();

  @override
  Future<Map<OptionKind, List<String>>> loadOptions() =>
      ref.read(optionRepoProvider).allGrouped();

  @override
  Future<AppSetting?> loadSettings() =>
      ref.read(settingsRepoProvider).current();

  @override
  Future<void> updateSettings(void Function(AppSetting s) fn) async {
    final repo = ref.read(settingsRepoProvider);
    final s = await repo.ensureRow();
    fn(s);
    await repo.save(s);
    ref.invalidate(settingsProvider);
  }

  @override
  Future<bool> addOption(OptionKind kind, String value) async {
    final ok = await ref.read(optionRepoProvider).add(kind, value);
    if (ok) ref.invalidate(optionsProvider);
    return ok;
  }

  @override
  Future<void> removeOption(OptionKind kind, String value) async {
    await ref.read(optionRepoProvider).remove(kind, value);
    ref.invalidate(optionsProvider);
  }

  @override
  Future<List<UnitItem>> loadUnits() => ref.read(unitRepoProvider).units();

  @override
  Future<List<UnitRule>> loadUnitRules() =>
      ref.read(unitRepoProvider).rules();

  @override
  Future<bool> addUnit(String name) async {
    final ok = await ref.read(unitRepoProvider).addUnit(name);
    if (ok) ref.invalidate(unitsProvider);
    return ok;
  }

  @override
  Future<void> removeUnit(String name) async {
    await ref.read(unitRepoProvider).removeUnit(name);
    ref.invalidate(unitsProvider);
  }

  @override
  Future<void> setBaseUnit(String name) async {
    await ref.read(unitRepoProvider).setBase(name);
    ref.invalidate(unitsProvider);
  }

  @override
  Future<String?> copyChatPhotoToRecords(String chatPhotoName) =>
      PhotoService.instance.copyToRecords(chatPhotoName);

  @override
  Future<List<OperationLog>> loadOperations({int limit = 10}) =>
      ref.read(opLogRepoProvider).recent(limit: limit);

  @override
  Future<bool> undoOperation(int logId) async {
    final ok = await ref.read(opLogRepoProvider).undo(logId);
    if (ok) {
      ref.invalidate(opLogsProvider);
      ref.invalidate(recordsProvider);
    }
    return ok;
  }

  @override
  Future<List<PieceRecord>> loadDeleted() =>
      ref.read(recordRepoProvider).deleted();

  @override
  Future<int> restoreDeleted(List<int> ids) async {
    await ref.read(recordRepoProvider).restoreMany(ids);
    ref.invalidate(deletedRecordsProvider);
    return ids.length;
  }

  @override
  Future<void> saveUnitRule({
    required String fromUnit,
    required String toUnit,
    required int numerator,
    required int denominator,
    String styleModel = '',
  }) async {
    await ref.read(unitRepoProvider).saveRule(
          fromUnit: fromUnit,
          toUnit: toUnit,
          numerator: numerator,
          denominator: denominator,
          styleModel: styleModel,
        );
    ref.invalidate(unitsProvider);
  }
}


/// 会话列表（按最近更新倒序）
class SessionsNotifier extends AsyncNotifier<List<ChatSession>> {
  @override
  Future<List<ChatSession>> build() => ref.watch(chatRepoProvider).sessions();

  Future<void> refresh() async {
    state = AsyncData(await ref.read(chatRepoProvider).sessions());
  }
}

final sessionsProvider =
    AsyncNotifierProvider<SessionsNotifier, List<ChatSession>>(
  SessionsNotifier.new,
);


/// 当前会话（标题、摘要、压缩进度）
final currentSessionProvider = Provider<ChatSession?>((ref) {
  final id = ref.watch(settingsProvider).valueOrNull?.chatSessionId ?? 0;
  final list = ref.watch(sessionsProvider).valueOrNull ?? const <ChatSession>[];
  for (final s in list) {
    if (s.id == id) return s;
  }
  return list.isEmpty ? null : list.first;
});

/// 上下文占用（输入栏上方那条细进度条的数据源）
final chatContextUsageProvider = Provider<ContextUsage>((ref) {
  final msgs = ref.watch(chatProvider).valueOrNull ?? const <ChatMessage>[];
  final session = ref.watch(currentSessionProvider);

  var used = 600; // system prompt 粗估
  if (session != null && session.summary.isNotEmpty) {
    used += ContextUsage.estimateTokens(session.summary);
  }
  for (final m in msgs) {
    used += ContextUsage.estimateTokens(m.content) + 8;
  }

  return ContextUsage(
    usedTokens: used,
    windowTokens: ref.watch(aiConfigProvider).contextWindow,
    messageCount: msgs.length,
    compactedCount: session?.compactedCount ?? 0,
  );
});


/// 最近的操作日志（AI 页/设置页展示撤销入口）
final opLogsProvider = FutureProvider<List<OperationLog>>((ref) async {
  return ref.watch(opLogRepoProvider).recent(limit: 30);
});
