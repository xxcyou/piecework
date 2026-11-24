import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/money.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/chat_session.dart';
import '../../data/services/photo_service.dart';
import '../../providers/chat_providers.dart';
import '../../providers/terminal_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/ui_providers.dart';
import '../tour_keys.dart';
import '../widgets/ai_message_bubble.dart';
import '../widgets/profile_switcher.dart';
import '../widgets/thinking_header.dart';
import '../widgets/tool_calls_sheet.dart';
import '../widgets/tool_count_chip.dart';
import '../widgets/terminal_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/prompt_cards.dart';
import 'ai_settings_page.dart';
import 'camera_capture_page.dart';

/// AI 助手对话页。
///
/// 数据流向：本地 Isar（只读快照）→ 工具执行器 → 模型 → 结构化回答。
/// 照片是货物实拍，模型被明确要求**不做文字识别、不靠照片猜数字**。
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();
  Uint8List? _pendingImage;

  /// 输入框是否处于终端模式（以「/ 」开头）
  bool _terminalMode = false;

  /// 上一次的输入内容：用来区分「手动敲出 / 」和「粘贴进来的 / 」
  String _lastInput = '';

  @override
  void initState() {
    super.initState();
    _textCtrl.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _textCtrl.removeListener(_onInputChanged);
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      // reverse: true 的列表，offset 0 就是底部（最新消息）
      _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  // ───────────────────────── 会话管理 ─────────────────────────

  void _showSessions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => Consumer(
        builder: (ctx, ref2, _) {
          final sessions = ref2.watch(sessionsProvider).valueOrNull ??
              const <ChatSession>[];
          final current = ref2.read(chatProvider.notifier).sessionId;
          final scheme = Theme.of(ctx).colorScheme;

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.68,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 12, 6),
                    child: Row(
                      children: <Widget>[
                        Text(
                          '对话',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${sessions.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            await ref2.read(chatProvider.notifier).newSession();
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('新对话'),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: sessions.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('还没有会话'),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: sessions.length,
                            itemBuilder: (_, i) {
                              final s = sessions[i];
                              final on = s.id == current;
                              return ListTile(
                                dense: true,
                                selected: on,
                                leading: Icon(
                                  on
                                      ? Icons.chat_bubble
                                      : Icons.chat_bubble_outline,
                                  size: 18,
                                  color: on
                                      ? scheme.primary
                                      : scheme.onSurfaceVariant,
                                ),
                                title: Text(
                                  s.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight:
                                        on ? FontWeight.w700 : FontWeight.w400,
                                    color: on
                                        ? scheme.primary
                                        : scheme.onSurface,
                                  ),
                                ),
                                subtitle: Text(
                                  '${s.messageCount} 条 · ${Fmt.relative(s.updatedAt)}'
                                  '${s.compactedCount > 0 ? ' · 已压缩 ${s.compactedCount} 条' : ''}',
                                  style: const TextStyle(fontSize: 10.5),
                                ),
                                trailing: PopupMenuButton<String>(
                                  icon: Icon(Icons.more_horiz,
                                      size: 18, color: scheme.onSurfaceVariant),
                                  onSelected: (v) async {
                                    if (v == 'rename') {
                                      Navigator.of(ctx).pop();
                                      await _renameSession(context, ref2, s);
                                    } else if (v == 'delete') {
                                      Navigator.of(ctx).pop();
                                      await ref2
                                          .read(chatProvider.notifier)
                                          .deleteSession(s.id);
                                    }
                                  },
                                  itemBuilder: (_) =>
                                      const <PopupMenuEntry<String>>[
                                    PopupMenuItem<String>(
                                      value: 'rename',
                                      child: Text('重命名'),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Text('删除会话'),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.of(ctx).pop();
                                  ref2
                                      .read(chatProvider.notifier)
                                      .switchTo(s.id);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _renameSession(
    BuildContext context,
    WidgetRef ref,
    ChatSession s,
  ) async {
    final ctrl = TextEditingController(text: s.title);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名会话'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: '标题'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty) return;
    await ref.read(chatProvider.notifier).renameSession(s.id, name);
  }

  // ───────────────────────── 发送 ─────────────────────────

  /// 停止当前回答（流式读取和工具循环会在下一个检查点退出）
  void _stop() {
    ref.read(chatProvider.notifier).cancel();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已停止'),
        duration: Duration(milliseconds: 900),
      ),
    );
  }

  /// 输入框内容变化：进入 / 退出终端模式
  void _onInputChanged() {
    final text = _textCtrl.text;
    final previous = _lastInput;
    _lastInput = text;

    final hasPrefix = hasTerminalPrefix(text);
    if (hasPrefix == _terminalMode) return;

    final notifier = ref.read(terminalSessionProvider.notifier);
    if (hasPrefix) {
      // 只有「输入框刚好变成 / 」（/ → / ）才算主动进入终端；
      // 粘贴一整段以 / 开头的代码不算，避免误触发
      if (!shouldEnterTerminalMode(text: text, previous: previous)) return;
      setState(() => _terminalMode = true);
      notifier.begin();
      return;
    }

    setState(() => _terminalMode = false);
    // 「/ 」被删掉 → 结束会话，落库成普通卡片
    final session = notifier.finish();
    if (session.hasContent) {
      ref.read(chatProvider.notifier).persistTerminalCard(session);
    }
  }

  Future<void> _send() async {
    // 终端模式：回车直接执行命令，不走 AI
    if (_terminalMode) {
      final cmd = _textCtrl.text.substring(2);
      if (cmd.trim().isEmpty) return;
      final notifier = ref.read(terminalSessionProvider.notifier)..begin();
      // 保持「/ 」前缀，命令执行完还停在终端模式
      _textCtrl.value = const TextEditingValue(
        text: '/ ',
        selection: TextSelection.collapsed(offset: 2),
      );
      _scrollToBottom();
      await notifier.run(cmd);
      _scrollToBottom();
      return;
    }

    final text = _textCtrl.text.trim();
    final image = _pendingImage;
    if (text.isEmpty && image == null) return;
    if (ref.read(chatBusyProvider)) return;

    String imageName = '';
    Uint8List? payload;
    if (image != null) {
      // 发之前先压到 1280px，控制 base64 体积
      payload = PhotoService.instance.compressJpeg(
        image,
        maxSide: 1280,
        quality: 82,
      );
      imageName = await PhotoService.instance.saveBytes(
        payload,
        sub: PhotoService.chatDir,
      );
    }

    _textCtrl.clear();
    setState(() => _pendingImage = null);
    _scrollToBottom();

    await ref.read(chatProvider.notifier).send(
          text: text,
          imageBytes: payload,
          imageName: imageName,
        );
    _scrollToBottom();
  }

  Future<void> _pickFromGallery() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final f = result.files.single;

      // file_picker 11：Android 上通常只给 path，Web 上只给 bytes。
      // 用 Object? 中转，两条路都兜住。
      final Object? raw = f.bytes;
      Uint8List? bytes = raw is Uint8List ? raw : null;
      if (bytes == null) {
        final path = f.path;
        if (path != null) {
          bytes = await File(path).readAsBytes();
        }
      }
      if (bytes == null) return;
      if (!mounted) return;
      setState(() => _pendingImage = bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择图片失败：$e')),
      );
    }
  }

  Future<void> _takePhoto() async {
    final bytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute<Uint8List>(builder: (_) => const CameraCapturePage()),
    );
    if (bytes == null || !mounted) return;
    setState(() => _pendingImage = bytes);
  }

  Future<void> _clearChat() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空对话'),
        content: const Text('只清空聊天记录，不影响任何计件数据。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(chatProvider.notifier).resetSession();
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(chatProvider);
    final busy = ref.watch(chatBusyProvider);
    final config = ref.watch(aiConfigProvider);
    final session = ref.watch(currentSessionProvider);
    final streaming = ref.watch(streamingProvider);
    final terminal = ref.watch(terminalSessionProvider);
    final scheme = Theme.of(context).colorScheme;

    // 卡片上的「问 AI 这段」按钮 → 把草稿塞进输入框并聚焦
    final draft = ref.watch(chatDraftProvider);
    if (draft.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _textCtrl.text = draft;
        _textCtrl.selection =
            TextSelection.collapsed(offset: draft.length);
        ref.read(chatDraftProvider.notifier).state = '';
        _focusNode.requestFocus();
      });
    }

    final messages = async.valueOrNull ?? const <ChatMessage>[];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 2,
        // 会话名本身就是入口，省掉一排图标
        title: InkWell(
          onTap: () => _showSessions(context, ref),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.forum_outlined, size: 16, color: scheme.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    session?.title ?? 'AI 助手',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Icon(Icons.expand_more,
                    size: 18, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          const Center(child: ProfileChip()),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            tooltip: '更多',
            onSelected: (v) async {
              switch (v) {
                case 'compact':
                  await ref.read(chatProvider.notifier).compactContext();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已把早期对话压缩成摘要')),
                  );
                case 'clear':
                  await _clearChat();
                case 'settings':
                  ref.read(tabIndexProvider.notifier).go(3);
              }
            },
            itemBuilder: (_) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'compact',
                enabled: messages.length > 12,
                child: const ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.compress, size: 18),
                  title: Text('压缩上下文', style: TextStyle(fontSize: 13)),
                ),
              ),
              PopupMenuItem<String>(
                value: 'clear',
                enabled: messages.isNotEmpty,
                child: const ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_sweep_outlined, size: 18),
                  title: Text('清空对话', style: TextStyle(fontSize: 13)),
                ),
              ),
              PopupMenuItem<String>(
                value: 'settings',
                child: const ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.tune, size: 18),
                  title: Text('AI 设置', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 2),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (!config.isConfigured) _buildConfigHint(scheme),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyState(
                icon: Icons.error_outline,
                title: '对话加载失败',
                subtitle: '$e',
              ),
              data: (_) => messages.isEmpty && !terminal.active
                  ? _buildWelcome(scheme, busy)
                  // reverse: true —— 打开就停在最新一条，不用手动往下拉
                  : ListView.builder(
                      controller: _scrollCtrl,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      itemCount: messages.length +
                          (streaming != null ? 1 : 0) +
                          (terminal.active ? 1 : 0),
                      itemBuilder: (_, i) {
                        // 终端会话进行中：最新一条永远是实时终端卡片
                        if (terminal.active && i == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TerminalCard(
                              lines: terminal.lines,
                              env: terminal.env,
                              live: true,
                              busy: terminal.busy,
                              cwd: terminal.cwd,
                            ),
                          );
                        }
                        final base = terminal.active ? i - 1 : i;
                        // 流式中：最底部先放一个临时气泡
                        if (streaming != null && base == 0) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: _StreamingBubble(),
                          );
                        }
                        final offset = streaming != null ? base - 1 : base;
                        final idx = messages.length - 1 - offset;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AiMessageBubble(message: messages[idx]),
                        );
                      },
                    ),
            ),
          ),
          _buildContextBar(scheme),
          if (busy) _buildThinking(scheme),
          _buildInputBar(scheme, busy),
        ],
      ),
    );
  }

  Widget _buildConfigHint(ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withAlpha(120),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.info_outline, size: 16, color: scheme.error),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              '还没配置 AI 接口。填好地址/密钥/模型后就能提问了。',
              style: TextStyle(fontSize: 11.5, color: scheme.onErrorContainer),
            ),
          ),
          TextButton(
            onPressed: () => ref.read(tabIndexProvider.notifier).go(3),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 30),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('去设置', style: TextStyle(fontSize: 11.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome(ColorScheme scheme, bool busy) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 头部
          Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      scheme.primary,
                      scheme.primary.withAlpha(180),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: scheme.primary.withAlpha(50),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome,
                    size: 22, color: Colors.white),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '问我就行，数据都在本机',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '能查、能改、能删、能调设置，改数据前会让你确认',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '挑一个场景开始',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 9),
          PromptCards(
            enabled: !busy,
            onPick: (q) {
              _textCtrl.text = q;
              _send();
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Icon(Icons.lock_outline,
                  size: 12, color: scheme.onSurfaceVariant.withAlpha(150)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '数据不出本机；照片是货物实拍，只作参考，不做文字识别\n'
                  '输入「/ 」进入终端：可直接跑 Linux 命令，或用 @工具名 调 AI 工具',
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.5,
                    color: scheme.onSurfaceVariant.withAlpha(170),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 常驻状态条：
  /// * 第一行左侧永远显示「现在实际在用什么模型」（点一下直达 AI 设置）
  /// * 第一行右侧是上下文占用，第二行是那条 2.5px 的细进度条
  ///
  /// 模型名常驻是为了避免猜：以前只在「新会话」时显示，
  /// 一开口就看不见了，容易让人怀疑是不是偷偷换了模型。
  Widget _buildContextBar(ColorScheme scheme) {
    final usage = ref.watch(chatContextUsageProvider);
    final cfg = ref.watch(aiConfigProvider);

    final color = usage.isCritical
        ? scheme.error
        : (usage.shouldCompact ? const Color(0xFFE8830C) : scheme.primary);
    final notConfigured = cfg.model.trim().isEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 5, 14, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Flexible(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const AiSettingsPage(),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (notConfigured ? scheme.error : scheme.primary)
                          .withAlpha(18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          notConfigured
                              ? Icons.error_outline
                              : Icons.bolt,
                          size: 11,
                          color: notConfigured ? scheme.error : scheme.primary,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            notConfigured ? '未配置模型 · 点这里设置' : cfg.displayTarget,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: notConfigured
                                  ? scheme.error
                                  : scheme.primary,
                            ),
                          ),
                        ),
                        if (notConfigured) ...<Widget>[
                          const SizedBox(width: 2),
                          Icon(Icons.chevron_right,
                              size: 12, color: scheme.error),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                usage.label,
                style: TextStyle(
                  fontSize: 9.5,
                  color: usage.messageCount == 0
                      ? scheme.onSurfaceVariant.withAlpha(150)
                      : color,
                  fontFeatures: tabularFigures,
                  height: 1.2,
                ),
              ),
              if (usage.compactedCount > 0) ...<Widget>[
                const SizedBox(width: 5),
                Text(
                  '· 已压缩 ${usage.compactedCount}',
                  style: TextStyle(
                    fontSize: 9,
                    color: scheme.onSurfaceVariant.withAlpha(160),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: usage.ratio,
              minHeight: 2.5,
              backgroundColor: scheme.outlineVariant.withAlpha(70),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThinking(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(strokeWidth: 1.8, color: scheme.primary),
          ),
          const SizedBox(width: 8),
          Text(
            '正在查本地数据…',
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(ColorScheme scheme, bool busy) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15181E) : Colors.white,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withAlpha(120)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Column(
            children: <Widget>[
              if (_pendingImage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: <Widget>[
                      Stack(
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(
                              _pendingImage!,
                              width: 58,
                              height: 58,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: -4,
                            right: -4,
                            child: InkResponse(
                              onTap: () => setState(() => _pendingImage = null),
                              radius: 14,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: scheme.error,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    size: 13, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '图片会一起发给 AI（仅作参考，不做文字识别）',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              // 紧凑输入条：图标按钮压到 34×34，间距收到 2，不浪费横向空间
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  _InputIconButton(
                    tooltip: '拍照',
                    icon: Icons.photo_camera_outlined,
                    onTap: busy ? null : _takePhoto,
                  ),
                  const SizedBox(width: 2),
                  _InputIconButton(
                    tooltip: '从相册选择',
                    icon: Icons.image_outlined,
                    onTap: busy ? null : _pickFromGallery,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    // 终端模式只换「底色 + 字色 + 等宽 + ❯ 前缀」，
                    // 不改 padding / border / prefixIcon —— 输入框高度必须和普通模式一致
                    child: Container(
                      decoration: _terminalMode
                          ? BoxDecoration(
                              color: scheme.primary.withAlpha(12),
                              borderRadius: BorderRadius.circular(10),
                            )
                          : null,
                      child: TextField(
                        key: TourKeys.aiInput,
                        controller: _textCtrl,
                        focusNode: _focusNode,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontFamily: _terminalMode ? 'monospace' : null,
                          color: _terminalMode ? scheme.primary : null,
                          fontWeight:
                              _terminalMode ? FontWeight.w600 : FontWeight.w400,
                        ),
                        decoration: InputDecoration(
                          hintText: _terminalMode
                              ? '输入命令，回车执行'
                              : (busy ? 'AI 正在思考…' : '问点什么，比如「本周多少件」'),
                          hintStyle: const TextStyle(fontSize: 13),
                          // 关键：hint 一长就会自动换行把输入框撑高，
                          // 锁死 1 行 + 省略号，终端模式和普通模式高度才一致
                          hintMaxLines: 1,
                          // 行内前缀：不占额外高度（prefixIcon 会把输入框撑高）
                          prefixText: _terminalMode ? '❯ ' : null,
                          prefixStyle: TextStyle(
                            fontSize: 13.5,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  SizedBox(
                    width: 40,
                    height: 40,
                    // 输出中变成停止键，点一下立刻中断
                    child: busy
                        ? FilledButton(
                            onPressed: _stop,
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                              backgroundColor: Theme.of(context).colorScheme.error,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Icon(Icons.stop_rounded, size: 20),
                          )
                        : FilledButton(
                            key: TourKeys.aiSend,
                            onPressed: _send,
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Icon(Icons.arrow_upward_rounded,
                                size: 18),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// 输入条上的小图标按钮：34×34、无多余内边距，避免横向留白
class _InputIconButton extends StatelessWidget {
  const _InputIconButton({
    required this.tooltip,
    required this.icon,
    this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: SizedBox(
          width: 34,
          height: 40,
          child: Icon(
            icon,
            size: 19,
            color: onTap == null
                ? scheme.onSurfaceVariant.withAlpha(90)
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}


/// 流式输出的临时气泡：边收边显示，带一个闪烁光标
class _StreamingBubble extends ConsumerWidget {
  const _StreamingBubble();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(streamingProvider);
    if (state == null) return const SizedBox.shrink();

    final hasContent = state.content.isNotEmpty;
    final hasReasoning = state.reasoning.isNotEmpty;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.86,
        ),
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B1E24) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(5),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: scheme.primary.withAlpha(60)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 60 : 8),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            if (state.toolCount > 0)
              Positioned(
                top: 0,
                right: 0,
                child: ToolCountChip(
                  count: state.toolCount,
                  dense: true,
                  onTap: () => showToolCallsSheet(
                    context,
                    tools: state.tools,
                    count: state.toolCount,
                  ),
                ),
              ),
            Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 标题行：思考期间一直在
            ThinkingHeader(hasContent: hasContent, toolCount: 0),

            // 空档：工具已经调完、模型还没开始吐字 —— 别让用户干等
            if (state.toolCount > 0 && !hasContent && !hasReasoning)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  state.toolHint.isEmpty
                      ? '已调用 ${state.toolCount} 次工具，等模型继续…'
                      : '已调用 ${state.toolCount} 次工具（最近：${state.toolHint}），等模型继续…',
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.4,
                    color: scheme.onSurfaceVariant.withAlpha(200),
                  ),
                ),
              ),
            if (hasReasoning) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                state.reasoning,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                  color: scheme.onSurfaceVariant.withAlpha(190),
                ),
              ),
            ],

            // 正文流式
            if (hasContent)
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: scheme.onSurface,
                  ),
                  children: <InlineSpan>[
                    TextSpan(text: state.content),
                    TextSpan(
                      text: ' ▍',
                      style: TextStyle(color: scheme.primary),
                    ),
                  ],
                ),
              ),

            // 正在调工具：明确告诉用户在干什么，别让他干等
            if (state.toolHint.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: hasContent || hasReasoning ? 6 : 0),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.7,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(scheme.primary),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '正在调用「${state.toolHint}」…',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
            ),
          ],
        ),
      ),
    );
  }
}
