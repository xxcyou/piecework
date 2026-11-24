import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/money.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/pending_action.dart';
import '../../data/models/piece_record.dart';
import '../../data/models/record_filter.dart';
import '../../data/services/ai_tool_types.dart';
import '../../data/services/photo_service.dart';
import '../../data/models/operation_view.dart';
import '../../data/services/record_codec.dart';
import '../../providers/chat_providers.dart';
import '../../providers/terminal_providers.dart';
import '../pages/report_draft_page.dart';
import '../pages/record_edit_page.dart';
import 'photo_thumb.dart';
import 'terminal_card.dart';
import '../../providers/db_providers.dart';
import '../../providers/records_providers.dart';
import '../../providers/ui_providers.dart';
import '../pages/options_page.dart';
import '../pages/units_page.dart';

/// 对话气泡。
///
/// 用户消息：主色渐变、靠右。
/// AI 消息：白卡靠左，从上到下依次是
///   思考过程 → 正文 → 任务进度 → 反问 → 工具卡片
///   → 统计表 → 确认卡 → 动作按钮 → token 统计
/// 所有东西都在同一张卡里，不再有飘在气泡外面的按钮。
class AiMessageBubble extends ConsumerWidget {
  const AiMessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return message.isUser ? _buildUser(context, ref) : _buildAi(context, ref);
  }

  // ─────────────────────────── 用户 ───────────────────────────

  Widget _buildUser(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final hasImage = message.imageName.isNotEmpty;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        key: const ValueKey<String>('user-bubble'),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[scheme.primary, scheme.primary.withAlpha(215)],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(5),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: scheme.primary.withAlpha(45),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: SelectionArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              if (hasImage) _buildUserImage(),
              if (hasImage && message.content.isNotEmpty)
                const SizedBox(height: 6),
              if (message.content.isNotEmpty)
                Text(
                  message.content,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Colors.white,
                  ),
                ),
              const SizedBox(height: 5),
              // 底部一行：右对齐（失败提示 · 时间 · 撤回）
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (message.failReason.isNotEmpty) ...<Widget>[
                    _userActionChip(
                      icon: Icons.error_outline,
                      label: '发送失败',
                      danger: true,
                      onTap: () => _showFailReason(context, ref),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    Fmt.time(message.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withAlpha(165),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _userActionChip(
                    icon: Icons.undo_rounded,
                    label: '撤回',
                    onTap: () =>
                        ref.read(chatProvider.notifier).retract(message),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 用户气泡底部的小按钮：图标 + 文字（不是纯文本，避免被当成正文）
  Widget _userActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final bg = danger
        ? const Color(0xFFFFE0E0).withAlpha(46)
        : Colors.white.withAlpha(38);
    final fg = danger ? const Color(0xFFFFD9D9) : Colors.white.withAlpha(235);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: (danger ? const Color(0xFFFFB4B4) : Colors.white)
                  .withAlpha(70),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 11, color: fg),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 轻量弹窗：失败原因 + 重试
  Future<void> _showFailReason(BuildContext context, WidgetRef ref) async {
    final scheme = Theme.of(context).colorScheme;
    final reason = message.failReason;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
        contentPadding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
        actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
        title: const Row(
          children: <Widget>[
            Icon(Icons.error_outline, size: 18, color: Color(0xFFD32F2F)),
            SizedBox(width: 6),
            Text('发送失败', style: TextStyle(fontSize: 15)),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: SingleChildScrollView(
            child: SelectableText(
              reason,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('关闭'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('重试'),
          ),
        ],
      ),
    );
    if (go == true && context.mounted) {
      await ref.read(chatProvider.notifier).retry(message);
    }
  }

  Widget _buildUserImage() {
    final file = PhotoService.instance
            .syncFile(message.imageName, sub: PhotoService.chatDir) ??
        PhotoService.instance.syncFile(message.imageName);

    Widget fallback() => Container(
          width: 150,
          height: 90,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.broken_image_outlined,
            color: Colors.white70,
            size: 22,
          ),
        );

    if (file == null) return fallback();

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.file(
        file,
        width: 150,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
      ),
    );
  }

  // ─────────────────────────── AI ───────────────────────────

  Widget _buildAi(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stats = _parseJson(message.statsJson);
    final filter = _parseFilter(message.filterJson);

    final groups = (stats?['groups'] as List?)
            ?.whereType<Map>()
            .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
            .toList() ??
        const <Map<String, dynamic>>[];
    final summary = stats?['summary'] is Map
        ? (stats!['summary'] as Map).map((k, v) => MapEntry(k.toString(), v))
        : null;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.86,
        ),
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 9),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B1E24) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(5),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: scheme.outlineVariant.withAlpha(120)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 60 : 10),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (message.reasoning.trim().isNotEmpty)
                _ThinkingBlock(text: message.reasoning),

            _richText(context, message.content),

            ..._cards(context, ref, 'svgs', 'svg',
                (d) => _svgCard(context, ref, d)),
            ..._cards(context, ref, 'calcs', 'calc',
                (d) => _calcCard(context, ref, d)),
            ..._cards(context, ref, 'codes', 'code',
                (d) => _codeCard(context, ref, d)),
            ..._draftCards(context),

            _taskCard(context, ref),
            _askCard(context, ref),
            _toolsSection(context, ref),

            if (summary != null) ...<Widget>[
              const SizedBox(height: 10),
              _summaryRow(context, summary),
            ],
            if (groups.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              _groupTable(context, groups),
            ],

            if (message.actionJson.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              _actionCard(context, ref),
            ],

            if (filter != null || message.actionLogId != 0) ...<Widget>[
              const SizedBox(height: 8),
              _actionRow(context, ref, filter),
            ],

              _statsRow(context, scheme),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────── 展示类卡片 ───────────────────────

  Map<String, dynamic>? _toolsMap() {
    final raw = _tryDecode(message.toolsJson);
    if (raw is! Map) return null;
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }

  /// 同类卡片可能有多个：优先读列表键（svgs/calcs/codes），
  /// 老消息只有单个键（svg/calc/code）时也能显示。
  List<Widget> _cards(
    BuildContext context,
    WidgetRef ref,
    String listKey,
    String singleKey,
    Widget Function(Map<String, dynamic> data) build,
  ) {
    final raw = _toolsMap();
    if (raw == null) return const <Widget>[];
    final list = (raw[listKey] as List?)
        ?.whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
    if (list != null && list.isNotEmpty) {
      return <Widget>[for (final d in list) build(d)];
    }
    final single = raw[singleKey];
    if (single is Map) {
      return <Widget>[build(single.map((k, v) => MapEntry(k.toString(), v)))];
    }
    return const <Widget>[];
  }

  /// SVG 图表卡（白底，保证图表配色不被暗色主题破坏）
  Widget _svgCard(BuildContext context, WidgetRef ref,
      [Map<String, dynamic>? data]) {
    final block = SvgBlock.fromJson(data ?? _toolsMap()?['svg']);
    if (block == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.insights_outlined,
                  size: 14, color: Color(0xFF1F5AE0)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  block.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F5AE0),
                  ),
                ),
              ),
              InkResponse(
                onTap: () => _showSvgFullscreen(context, block),
                radius: 16,
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(Icons.open_in_full,
                      size: 13, color: Color(0xFF1F5AE0)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 点一下看大图（双指缩放）
          GestureDetector(
            onTap: () => _showSvgFullscreen(context, block),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: SvgPicture.string(
                block.svg,
                fit: BoxFit.contain,
                placeholderBuilder: (_) => const SizedBox(
                  height: 80,
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 全屏看图：双指缩放、拖动
  void _showSvgFullscreen(BuildContext context, SvgBlock block) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            foregroundColor: const Color(0xFF1B1E24),
            elevation: 0,
            title: Text(
              block.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            actions: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Text(
                    '双指缩放',
                    style: TextStyle(
                      fontSize: 11,
                      color: const Color(0xFF1B1E24).withAlpha(120),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: InteractiveViewer(
            minScale: 0.6,
            maxScale: 8,
            boundaryMargin: const EdgeInsets.all(80),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SvgPicture.string(
                  block.svg,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 计算过程表：把「怎么算出来的」摊开
  /// 报表草稿卡：一行摘要 + 「查看报表」按钮（可导出图片）
  List<Widget> _draftCards(BuildContext context) {
    final raw = _toolsMap()?['reportDrafts'];
    if (raw is! List || raw.isEmpty) return const <Widget>[];
    final scheme = Theme.of(context).colorScheme;
    return <Widget>[
      for (final d in raw)
        if (d is Map)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: scheme.primary.withAlpha(12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.primary.withAlpha(45)),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.table_chart_outlined,
                      size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          (d['title'] as String?) ?? '报表草稿',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${(d['rows'] as List?)?.length ?? 0} 行 · '
                          '合计 ${d['totalText'] ?? ''}',
                          style: TextStyle(
                              fontSize: 10.5,
                              color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(fontSize: 11.5),
                    ),
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => ReportDraftPage(
                          draft: d.map((k, v) => MapEntry('$k', v)),
                        ),
                      ),
                    ),
                    child: const Text('查看报表'),
                  ),
                ],
              ),
            ),
          ),
    ];
  }

  Widget _calcCard(BuildContext context, WidgetRef ref,
      [Map<String, dynamic>? data]) {
    final table = CalcTable.fromJson(data ?? _toolsMap()?['calc']);
    if (table == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    const accent = Color(0xFF0E9F6E);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
      decoration: BoxDecoration(
        color: accent.withAlpha(9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withAlpha(55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.calculate_outlined, size: 14, color: accent),
              const SizedBox(width: 5),
              Text(
                table.title,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          for (var i = 0; i < table.steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 18,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: scheme.onSurfaceVariant.withAlpha(150),
                        fontFeatures: tabularFigures,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Text(
                      table.steps[i].label,
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.4,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 4,
                    child: Text(
                      table.steps[i].expression,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.4,
                        color: scheme.onSurfaceVariant,
                        fontFeatures: tabularFigures,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 64,
                    child: Text(
                      table.steps[i].result,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: accent,
                        fontFeatures: tabularFigures,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (table.conclusion.isNotEmpty) ...<Widget>[
            const SizedBox(height: 3),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withAlpha(16),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                table.conclusion,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                  fontFeatures: tabularFigures,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 代码 / 命令卡（深色 + 高亮 + 一键复制）
  Widget _codeCard(BuildContext context, WidgetRef ref,
      [Map<String, dynamic>? data]) {
    final block = CodeBlock.fromJson(data ?? _toolsMap()?['code']);
    if (block == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1E24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withAlpha(80)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(10, 7, 6, 7),
            color: const Color(0xFF23262E),
            child: Row(
              children: <Widget>[
                const Icon(Icons.terminal,
                    size: 13, color: Color(0xFF8B93A1)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    block.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFC8CEDA),
                    ),
                  ),
                ),
                Text(
                  block.language,
                  style: const TextStyle(
                      fontSize: 9, color: Color(0xFF6B7280)),
                ),
                const SizedBox(width: 4),
                InkResponse(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: block.code));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已复制')),
                    );
                  },
                  radius: 16,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.copy_rounded,
                        size: 13, color: Color(0xFF8B93A1)),
                  ),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: SelectableText.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.55,
                    fontFamily: 'monospace',
                    color: Color(0xFFD6DCE8),
                  ),
                  children: _highlightCode(block.code),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 极简语法高亮：注释 / 字符串 / 数字 / 关键字
  static List<TextSpan> _highlightCode(String code) {
    const keywords = <String>{
      'select', 'from', 'where', 'group', 'by', 'order', 'limit', 'join',
      'on', 'and', 'or', 'not', 'null', 'insert', 'update', 'delete',
      'sum', 'count', 'avg', 'as', 'case', 'when', 'then', 'else', 'end',
      'sudo', 'adb', 'shell', 'git', 'cd', 'ls', 'cat', 'grep', 'awk',
      'var', 'final', 'const', 'class', 'void', 'return', 'if', 'for',
      'while', 'import', 'true', 'false',
    };

    final pattern = RegExp(
      r"""(#[^\n]*|//[^\n]*)|('[^']*'|"[^"]*")|(\b\d+(?:\.\d+)?\b)|([A-Za-z_][A-Za-z0-9_]*)""",
    );

    final spans = <TextSpan>[];
    var last = 0;

    for (final m in pattern.allMatches(code)) {
      if (m.start > last) {
        spans.add(TextSpan(text: code.substring(last, m.start)));
      }
      final text = m.group(0)!;
      if (m.group(1) != null) {
        spans.add(TextSpan(
          text: text,
          style: const TextStyle(
              color: Color(0xFF6B7280), fontStyle: FontStyle.italic),
        ));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(
          text: text,
          style: const TextStyle(color: Color(0xFF9ECE6A)),
        ));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(
          text: text,
          style: const TextStyle(color: Color(0xFFE0AF68)),
        ));
      } else if (keywords.contains(text.toLowerCase())) {
        spans.add(TextSpan(
          text: text,
          style: const TextStyle(
              color: Color(0xFF7AA2F7), fontWeight: FontWeight.w600),
        ));
      } else {
        spans.add(TextSpan(text: text));
      }
      last = m.end;
    }
    if (last < code.length) {
      spans.add(TextSpan(text: code.substring(last)));
    }
    return spans;
  }

  // ─────────────────────── 底部统计行 ───────────────────────

  Widget _statsRow(BuildContext context, ColorScheme scheme) {
    final tools = _toolCount();
    final parts = <String>[];
    if (message.totalTokens > 0) {
      parts.add('${_fmtTokens(message.totalTokens)} tokens');
      if (message.promptTokens > 0) {
        parts.add('入 ${_fmtTokens(message.promptTokens)}');
      }
      if (message.completionTokens > 0) {
        parts.add('出 ${_fmtTokens(message.completionTokens)}');
      }
    }
    if (tools > 0) parts.add('$tools 个工具');

    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        children: <Widget>[
          if (parts.isNotEmpty) ...<Widget>[
            Icon(Icons.bolt_outlined,
                size: 10, color: scheme.onSurfaceVariant.withAlpha(140)),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                parts.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  color: scheme.onSurfaceVariant.withAlpha(160),
                  fontFeatures: tabularFigures,
                  height: 1.2,
                ),
              ),
            ),
          ] else
            const Spacer(),
          Text(
            Fmt.time(message.createdAt),
            style: TextStyle(
              fontSize: 9,
              color: scheme.onSurfaceVariant.withAlpha(150),
            ),
          ),
        ],
      ),
    );
  }

  int _toolCount() {
    final raw = _tryDecode(message.toolsJson);
    if (raw is! Map) return 0;
    final traces = raw['traces'];
    return traces is List ? traces.length : 0;
  }

  static String _fmtTokens(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(2)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  // ─────────────────────── 动作按钮（卡内） ───────────────────────

  /// 打开「快照视图」：把这批记录摊出来，不管它们现在还在不在。
  ///
  /// 三种来源：
  /// * 写操作确认卡 → 用 action.ids，标签「已删除/新建/已修改」
  /// * 查询结果 → 用 filter.pinnedIds，标签「查询结果」
  /// * 都没有 → 提示无内容
  Future<void> _openSnapshot(
    BuildContext context,
    WidgetRef ref,
    RecordFilter? filter,
  ) async {
    final action = PendingAction.fromJson(_tryDecode(message.actionJson));

    if (action == null) {
      // 纯查询：用查询那一刻钉住的 id
      final ids = filter?.pinnedIds ?? const <int>[];
      if (ids.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('这条回答没有对应的记录明细')),
        );
        return;
      }

      final repo = ref.read(recordRepoProvider);
      final list = <PieceRecord>[];
      var missing = 0;
      for (final id in ids) {
        final r = await repo.byId(id);
        if (r == null) {
          missing++;
          continue;
        }
        list.add(r);
      }

      if (list.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('这批记录已经被彻底删除，没有可查看的内容')),
        );
        return;
      }

      ref.read(operationViewProvider.notifier).state = OperationView(
        title: filter?.summary ?? '查询结果',
        tag: '查询结果',
        records: list,
        note: missing > 0 ? '其中 $missing 条已彻底删除' : '',
      );
      ref.read(tabIndexProvider.notifier).go(0);
      return;
    }

    // 写操作：用 action 的 ids + 操作标签
    final repo = ref.read(recordRepoProvider);
    final list = <PieceRecord>[];
    var missing = 0;

    for (final id in action.ids) {
      final r = await repo.byId(id);
      if (r == null) {
        missing++;
        continue;
      }
      list.add(r);
    }

    // 新建操作：记录可能还没入库，用 items 里的快照
    if (action.kind == PendingKind.create && action.items.isNotEmpty) {
      for (final m in action.items) {
        list.add(RecordCodec.fromJson(m));
      }
    }

    if (list.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('这批记录已经被彻底删除，没有可查看的内容')),
      );
      return;
    }

    ref.read(operationViewProvider.notifier).state = OperationView(
      title: action.description,
      tag: action.kind.snapshotTag,
      records: list,
      note: missing > 0 ? '其中 $missing 条已彻底删除' : '',
    );
    ref.read(tabIndexProvider.notifier).go(0);
  }

  Widget _actionRow(BuildContext context, WidgetRef ref, RecordFilter? filter) {
    final scheme = Theme.of(context).colorScheme;
    final busy = ref.watch(chatBusyProvider);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        if (filter != null)
          FilledButton.tonalIcon(
            // 卡片末尾这个按钮 = 快照视图（AI 工具返回的按钮才走过滤）
            onPressed: () => _openSnapshot(context, ref, filter),
            icon: const Icon(Icons.arrow_forward_rounded, size: 15),
            label: const Text('查看这批记录'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(fontSize: 11.5),
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
        if (message.actionLogId != 0)
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : () async {
                    final ok =
                        await ref.read(chatProvider.notifier).undoAction(message);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text(ok ? '已撤销，数据已还原' : '这次操作已经撤销过了'),
                      ),
                    );
                  },
            icon: const Icon(Icons.undo, size: 14),
            label: const Text('撤销这次操作'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(fontSize: 11.5),
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error.withAlpha(80)),
            ),
          ),
      ],
    );
  }

  // ─────────────────────── 写操作确认卡 ───────────────────────

  Widget _actionCard(BuildContext context, WidgetRef ref) {
    final action = PendingAction.fromJson(_tryDecode(message.actionJson));
    if (action == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final danger = action.kind == PendingKind.delete ||
        action.kind == PendingKind.detachPhoto;
    final accent = danger ? scheme.error : scheme.primary;
    final busy = ref.watch(chatBusyProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: accent.withAlpha(14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                danger ? Icons.warning_amber_rounded : Icons.edit_note,
                size: 17,
                color: accent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '待确认 · 影响 ${action.affectedCount} 条',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            action.description,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: scheme.onSurface,
            ),
          ),
          // 修改前后对比（有数字就画双条形图，直观看出变化幅度）
          if (action.diff.isNotEmpty) ...<Widget>[
            const SizedBox(height: 9),
            _diffBlock(context, action.diff, accent),
          ],
          // 具体是哪几条：列前 5 条，剩下的报个数。
          // 图片对比已经逐条列过了就不再重复一遍。
          if (action.preview.isNotEmpty &&
              !action.diff.any(
                (d) => ((d['items'] as List?) ?? const <dynamic>[]).isNotEmpty,
              )) ...<Widget>[
            const SizedBox(height: 7),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withAlpha(55),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final line in action.preview)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('· ',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: scheme.onSurfaceVariant)),
                          Expanded(
                            child: Text(
                              line,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                height: 1.4,
                                color: scheme.onSurfaceVariant,
                                fontFeatures: tabularFigures,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (action.affectedCount > action.preview.length)
                    Text(
                      '… 还有 ${action.affectedCount - action.preview.length} 条',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: scheme.onSurfaceVariant.withAlpha(170),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: busy
                      ? null
                      : () =>
                          ref.read(chatProvider.notifier).cancelPending(message),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(36),
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: busy
                      ? null
                      : () => ref
                          .read(chatProvider.notifier)
                          .confirmPending(message),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(36),
                    backgroundColor: accent,
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: Text(action.kind.confirmLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────── Agent 任务卡 ───────────────────────

  Widget _taskCard(BuildContext context, WidgetRef ref) {
    final raw = _tryDecode(message.toolsJson);
    if (raw is! Map) return const SizedBox.shrink();
    final task = AgentTask.fromJson(raw['task']);
    if (task == null || task.steps.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final accent = task.done ? const Color(0xFF0E9F6E) : scheme.primary;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
      decoration: BoxDecoration(
        color: accent.withAlpha(9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withAlpha(55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                task.done ? Icons.task_alt : Icons.auto_awesome_motion,
                size: 14,
                color: accent,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  task.goal,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                    height: 1.3,
                  ),
                ),
              ),
              Text(
                '${task.doneCount}/${task.steps.length}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: accent,
                  fontFeatures: tabularFigures,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: task.progress,
              minHeight: 3.5,
              backgroundColor: accent.withAlpha(28),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 8),
          for (final s in task.steps) _stepRow(context, s, scheme, accent),
          if (task.summary.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withAlpha(14),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                task.summary,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.45,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
          if (task.followups.isNotEmpty) ...<Widget>[
            const SizedBox(height: 7),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final q in task.followups)
                  ActionChip(
                    label: Text(q, style: const TextStyle(fontSize: 10.5)),
                    onPressed: () =>
                        ref.read(chatProvider.notifier).send(text: q),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    side: BorderSide(color: accent.withAlpha(80)),
                    backgroundColor: accent.withAlpha(8),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepRow(
    BuildContext context,
    AgentStep s,
    ColorScheme scheme,
    Color accent,
  ) {
    final (IconData icon, Color color, bool spin) = switch (s.status) {
      AgentStepStatus.done => (
          Icons.check_circle_rounded,
          const Color(0xFF0E9F6E),
          false
        ),
      AgentStepStatus.running => (Icons.sync_rounded, accent, true),
      AgentStepStatus.failed => (Icons.error_rounded, scheme.error, false),
      AgentStepStatus.pending => (
          Icons.radio_button_unchecked,
          scheme.onSurfaceVariant.withAlpha(110),
          false
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: spin
                ? SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  )
                : Icon(icon, size: 13, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  s.title,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.35,
                    fontWeight: s.status == AgentStepStatus.running
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: s.status == AgentStepStatus.done
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                  ),
                ),
                if (s.detail.isNotEmpty)
                  Text(
                    s.detail,
                    style: TextStyle(
                      fontSize: 9.5,
                      height: 1.35,
                      color: scheme.onSurfaceVariant.withAlpha(190),
                      fontFeatures: tabularFigures,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────── AI 反问卡 ───────────────────────

  Widget _askCard(BuildContext context, WidgetRef ref) {
    final raw = _tryDecode(message.toolsJson);
    if (raw is! Map) return const SizedBox.shrink();
    final ask = AskPrompt.fromJson(raw['ask']);
    if (ask == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    const accent = Color(0xFFE8830C);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
      decoration: BoxDecoration(
        color: accent.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withAlpha(70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.help_outline, size: 14, color: accent),
              SizedBox(width: 5),
              Text(
                '还需要确认',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accent,
                  height: 1.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            ask.question,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: scheme.onSurface,
            ),
          ),
          if (ask.why.isNotEmpty) ...<Widget>[
            const SizedBox(height: 3),
            Text(
              ask.why,
              style: TextStyle(
                fontSize: 10,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (ask.options.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final o in ask.options)
                  ActionChip(
                    label: Text(o, style: const TextStyle(fontSize: 11.5)),
                    onPressed: () =>
                        ref.read(chatProvider.notifier).send(text: o),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    side: BorderSide(color: accent.withAlpha(90)),
                    backgroundColor: accent.withAlpha(12),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Text(
                '也可以直接回复',
                style: TextStyle(
                  fontSize: 9.5,
                  color: scheme.onSurfaceVariant.withAlpha(160),
                ),
              ),
              const Spacer(),
              // 不想回答：跳过，让 AI 按最合理的默认继续
              TextButton.icon(
                onPressed: () => ref
                    .read(chatProvider.notifier)
                    .send(text: skipAskText),
                icon: const Icon(Icons.fast_forward_rounded, size: 14),
                label: const Text('跳过', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────── 工具卡片 ───────────────────────

  Widget _toolsSection(BuildContext context, WidgetRef ref) {
    final raw = _tryDecode(message.toolsJson);
    if (raw is! Map) return const SizedBox.shrink();

    // 终端会话卡片（用户在输入框用「/ 」开的会话，结束后落库成普通卡片）
    final terminal = raw['terminal'];
    if (terminal is Map) {
      final lines = (terminal['lines'] as List?)
              ?.map(TerminalLine.fromJson)
              .toList() ??
          const <TerminalLine>[];
      return Padding(
        padding: const EdgeInsets.only(top: 9),
        child: TerminalCard(
          lines: lines,
          env: (terminal['env'] as String?) ?? 'linux',
          cwd: (terminal['cwd'] as String?) ?? '',
          onAsk: () {
            ref.read(chatDraftProvider.notifier).state =
                '刚才我在终端里跑的那些命令，帮我解释一下结果，有什么要注意的？';
          },
        ),
      );
    }

    // 图片卡片（show_photos 的结果；可能被调用多次 → 多组）
    List<Map<String, dynamic>> groupOf(Object? rawGroup) => (rawGroup as List?)
            ?.whereType<Map>()
            .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
            .toList() ??
        const <Map<String, dynamic>>[];

    final groups = <List<Map<String, dynamic>>>[
      for (final g in (raw['photoGroups'] as List?) ?? const <dynamic>[])
        groupOf(g),
    ];
    final photos = groups.isNotEmpty ? groups.first : groupOf(raw['photos']);
    if (photos.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _photoCards(context, photos),
            for (final g in groups.skip(1))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _photoCards(context, g),
              ),
          ],
        ),
      );
    }

    final traces = (raw['traces'] as List?)
            ?.whereType<Map>()
            .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
            .toList() ??
        const <Map<String, dynamic>>[];
    final actions = (raw['actions'] as List?)
            ?.whereType<Map>()
            .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
            .toList() ??
        const <Map<String, dynamic>>[];

    if (traces.isEmpty && actions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 回答结束后也能看到这次调了几次工具
          if (traces.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: <Widget>[
                  Icon(Icons.bolt_rounded,
                      size: 12, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 3),
                  Text(
                    '本次调用 ${traces.length} 次工具',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          for (final t in traces) _ToolRow(trace: t),
          for (final a in actions) _uiActionButton(context, ref, a),
        ],
      ),
    );
  }

  /// 修改前后对比：数字画双条形图，文字只显示「旧 → 新」
  Widget _diffBlock(
    BuildContext context,
    List<Map<String, dynamic>> diff,
    Color accent,
  ) {
    final scheme = Theme.of(context).colorScheme;

    String fmt(num v, {bool money = false}) {
      if (money) {
        return '¥${v.abs() < 1000 ? v.toStringAsFixed(2) : v.toStringAsFixed(0)}';
      }
      return v == v.roundToDouble()
          ? v.toStringAsFixed(0)
          : v.toStringAsFixed(2);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 9),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withAlpha(45),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: scheme.outlineVariant.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.compare_arrows_rounded, size: 13, color: accent),
              const SizedBox(width: 4),
              Text(
                '修改前后',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final row in diff) _diffRow(context, row, accent, fmt),
        ],
      ),
    );
  }

  Widget _diffRow(
    BuildContext context,
    Map<String, dynamic> row,
    Color accent,
    String Function(num, {bool money}) fmt,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final label = (row['label'] as String?) ?? '';
    final before = row['before'];
    final after = row['after'];
    final money = row['money'] == true;
    final unit = (row['unit'] as String?) ?? '';
    final perItem = row['perItem'] == true;

    // 图片变动：画「原图 → 新图」缩略图，比文字直观
    if (row.containsKey('photoBefore') || row.containsKey('photoAfter')) {
      final photoBefore = (row['photoBefore'] as String?) ?? '';
      final photoAfter = (row['photoAfter'] as String?) ?? '';
      final items = (row['items'] as List?)
              ?.whereType<Map>()
              .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
              .toList() ??
          const <Map<String, dynamic>>[];
      const maxShown = 6;

      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                SizedBox(
                  width: 62,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.3,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                _photoSide(scheme, photoBefore, '${before ?? ''}', '原'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 13, color: accent),
                ),
                _photoSide(scheme, photoAfter, '${after ?? ''}', '新',
                    accent: accent),
              ],
            ),
            // 逐条：这条记录原来是哪张图、会变成哪张图
            if (items.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              for (final it in items.take(maxShown))
                Padding(
                  padding: const EdgeInsets.only(left: 62, bottom: 4),
                  child: Row(
                    children: <Widget>[
                      _miniThumb(scheme, (it['photoBefore'] as String?) ?? ''),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Icon(Icons.arrow_right_alt,
                            size: 12, color: accent.withAlpha(170)),
                      ),
                      _miniThumb(scheme, (it['photoAfter'] as String?) ?? ''),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          (it['label'] as String?) ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            height: 1.3,
                            color: scheme.onSurface.withAlpha(210),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (items.length > maxShown)
                Padding(
                  padding: const EdgeInsets.only(left: 62, bottom: 2),
                  child: Text(
                    '…还有 ${items.length - maxShown} 条',
                    style: TextStyle(
                      fontSize: 9,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ],
        ),
      );
    }

    final b = before is num ? before : null;
    final a = after is num ? after : null;

    String text(Object? v) {
      if (v is num) return fmt(v, money: money);
      return (v ?? '').toString();
    }

    final delta = (a != null && b != null) ? a - b : null;
    final up = (delta ?? 0) > 0;

    Widget bars() {
      if (b == null || a == null) return const SizedBox.shrink();
      final maxV = [b.abs(), a.abs()].reduce((x, y) => x > y ? x : y);
      if (maxV <= 0) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 2),
        child: LayoutBuilder(
          builder: (_, c) {
            final w = c.maxWidth;
            return Column(
              children: <Widget>[
                _barLine(w, b.abs() / maxV, scheme.onSurfaceVariant.withAlpha(90),
                    '原', text(b) + (unit.isEmpty ? '' : ' $unit'), scheme),
                const SizedBox(height: 3),
                _barLine(w, a.abs() / maxV, accent, '新',
                    text(a) + (unit.isEmpty ? '' : ' $unit'), scheme),
              ],
            );
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              SizedBox(
                width: 62,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.3,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  perItem && b == null
                      ? '${text(before)} → ${text(after)}'
                      : '${text(before)} → ${text(after)}',
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (delta != null && delta != 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: (up ? const Color(0xFF0E9F6E) : scheme.error)
                        .withAlpha(22),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '${up ? '+' : '-'}${fmt(delta.abs(), money: money)}',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: up ? const Color(0xFF0E9F6E) : scheme.error,
                    ),
                  ),
                ),
            ],
          ),
          if (b != null && a != null) bars(),
          // 逐条列出（数量这类字段每条旧值可能不同）
          if ((row['items'] as List?)?.isNotEmpty == true &&
              !row.containsKey('photoBefore') &&
              !row.containsKey('photoAfter'))
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 2, left: 62),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final it in (row['items'] as List).take(6))
                    if (it is Map)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '${it['label']}：${it['before']} → ${it['after']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            height: 1.3,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 逐条对比里的迷你缩略图
  Widget _miniThumb(ColorScheme scheme, String name) {
    if (name.isEmpty) {
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withAlpha(70),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: scheme.outlineVariant.withAlpha(110)),
        ),
        child: Icon(Icons.block, size: 12, color: scheme.onSurfaceVariant.withAlpha(120)),
      );
    }
    return PhotoThumb(name: name, size: 26, radius: 5);
  }

  /// 对比卡片里的一侧图片（没有图就画个虚线占位）
  Widget _photoSide(
    ColorScheme scheme,
    String name,
    String label,
    String tag, {
    Color? accent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (name.isEmpty)
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withAlpha(70),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scheme.outlineVariant.withAlpha(120)),
            ),
            child: Icon(Icons.image_not_supported_outlined,
                size: 18, color: scheme.onSurfaceVariant.withAlpha(130)),
          )
        else
          PhotoThumb(name: name, size: 52, radius: 8),
        const SizedBox(height: 2),
        Row(
          children: <Widget>[
            Text(
              tag,
              style: TextStyle(
                fontSize: 8,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: accent ?? scheme.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 一条对比横条：左侧标签 + 条形 + 右侧数值
  Widget _barLine(
    double maxWidth,
    double ratio,
    Color color,
    String tag,
    String value,
    ColorScheme scheme,
  ) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 14,
          child: Text(
            tag,
            style: TextStyle(fontSize: 8.5, color: scheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Stack(
            children: <Widget>[
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withAlpha(110),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: ratio.clamp(0.02, 1.0),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 9,
            color: scheme.onSurfaceVariant,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  /// 图片卡片：横向滑一排，点开对应的记录
  Widget _photoCards(
    BuildContext context,
    List<Map<String, dynamic>> photos,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.photo_library_outlined,
                size: 13, color: scheme.primary),
            const SizedBox(width: 4),
            Text(
              '${photos.length} 张图（点开看记录）',
              style: TextStyle(
                fontSize: 10,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final p = photos[i];
              final name = (p['name'] as String?) ?? '';
              final id = (p['id'] as num?)?.toInt() ?? 0;
              final label = (p['label'] as String?) ?? '#$id';
              final refs = (p['refs'] as num?)?.toInt() ?? 1;
              final style = (p['styleModel'] as String?) ?? '';
              final size = (p['size'] as String?) ?? '';
              final color = (p['color'] as String?) ?? '';
              final recordId = (p['recordId'] as num?)?.toInt() ?? 0;
              final sub = <String>[
                if (style.isNotEmpty) style else '未填型号',
                if (color.isNotEmpty) color,
                if (size.isNotEmpty) size,
              ].join(' · ');

              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: recordId > 0
                    ? () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                RecordEditPage(recordId: recordId),
                          ),
                        )
                    : null,
                child: SizedBox(
                  width: 96,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Stack(
                        children: <Widget>[
                          PhotoThumb(name: name, size: 96, radius: 10),
                          Positioned(
                            left: 3,
                            top: 3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(150),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          if (refs > 1)
                            Positioned(
                              right: 3,
                              bottom: 3,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: scheme.primary.withAlpha(200),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  '$refs 条',
                                  style: const TextStyle(
                                      fontSize: 8, color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 9.5, height: 1.2),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _uiActionButton(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> a,
  ) {
    final kind = (a['kind'] as String?) ?? '';
    final label = (a['label'] as String?) ?? '';
    if (label.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 3, bottom: 3),
      child: FilledButton.tonalIcon(
        onPressed: () => _handleUiAction(context, ref, a),
        icon: Icon(
          kind == 'applyFilter' ? Icons.filter_alt_outlined : Icons.open_in_new,
          size: 15,
        ),
        label: Text(label),
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontSize: 12),
          minimumSize: const Size(0, 32),
        ),
      ),
    );
  }

  void _handleUiAction(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> a,
  ) {
    final kind = (a['kind'] as String?) ?? '';
    if (kind == 'applyFilter') {
      final raw = a['filter'];
      if (raw is Map) {
        jumpToRecords(
          ref,
          RecordFilter.fromJson(raw.map((k, v) => MapEntry(k.toString(), v))),
        );
      }
      return;
    }
    if (kind == 'openPage') {
      final target = (a['target'] as String?) ?? '';
      switch (target) {
        case 'records':
          ref.read(tabIndexProvider.notifier).go(0);
        case 'chat':
          ref.read(tabIndexProvider.notifier).go(1);
        case 'report':
          ref.read(tabIndexProvider.notifier).go(2);
        case 'settings':
          ref.read(tabIndexProvider.notifier).go(3);
        case 'units':
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const UnitsPage()),
          );
        case 'options':
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const OptionsPage()),
          );
      }
    }
  }

  static IconData _toolIcon(String name) => switch (name) {
        'query_records' => Icons.search,
        'aggregate_records' => Icons.functions,
        'list_available_options' => Icons.list_alt,
        'delete_records' => Icons.delete_outline,
        'update_records' => Icons.edit_outlined,
        'create_records' => Icons.add_circle_outline,
        'get_settings' => Icons.tune,
        'update_settings' => Icons.settings_outlined,
        'manage_options' => Icons.label_outline,
        'manage_units' => Icons.straighten,
        'set_unit_rule' => Icons.swap_horiz,
        'apply_filter' => Icons.filter_alt_outlined,
        'compare_periods' => Icons.compare_arrows,
        'top_n' => Icons.leaderboard_outlined,
        'open_page' => Icons.open_in_new,
        'manage_photos' => Icons.image_outlined,
        'ask_user' => Icons.help_outline,
        'plan_task' => Icons.checklist,
        'step_done' => Icons.check_circle_outline,
        'finish_task' => Icons.flag_outlined,
        _ => Icons.build_outlined,
      };

  // ─────────────────────── 统计展示 ───────────────────────

  Widget _summaryRow(BuildContext context, Map<String, dynamic> summary) {
    final scheme = Theme.of(context).colorScheme;
    final count = summary['recordCount'] ?? 0;
    // 优先折算值；旧消息没有这个字段时退回原始和
    final qty = summary['totalBaseQuantity'] ?? summary['totalQuantity'] ?? 0;
    final amount = summary['totalAmount'] ?? 0;
    // 单位要照抄结果：全是「片」就显示片，不能一律写件
    final rawUnits = summary['units'];
    final units =
        rawUnits is List ? rawUnits.map((e) => e.toString()).toList() : const <String>[];
    final baseUnit = (summary['baseUnit'] ?? '件').toString();
    final unit = units.length == 1 ? units.first : baseUnit;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primary.withAlpha(16),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _miniStat('记录', '$count', '条', scheme),
          _miniDivider(scheme),
          _miniStat(units.length == 1 ? '数量' : '数量(折算)', '$qty', unit, scheme),
          _miniDivider(scheme),
          _miniStat('金额', Money.format(Money.toMilli((amount as num?) ?? 0)), '元',
              scheme,
              highlight: true),
        ],
      ),
    );
  }

  Widget _miniStat(
    String label,
    String value,
    String unit,
    ColorScheme scheme, {
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(fontSize: 9.5, color: scheme.onSurfaceVariant),
          ),
          Text(
            '$value $unit',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: highlight ? scheme.primary : scheme.onSurface,
              fontFeatures: tabularFigures,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniDivider(ColorScheme scheme) => Container(
      width: 1,
      height: 22,
      color: scheme.outlineVariant.withAlpha(150));

  Widget _groupTable(BuildContext context, List<Map<String, dynamic>> groups) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: scheme.outlineVariant.withAlpha(150)),
      ),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withAlpha(70),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: Text('分组',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('数量',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('金额',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant)),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: groups.length,
              itemBuilder: (_, i) {
                final g = groups[i];
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        flex: 3,
                        child: Text(
                          '${g['key'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: scheme.onSurface),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          // 混单位时原始和没有意义，优先用折算后的值
                          '${g['baseQuantity'] ?? g['quantity'] ?? 0}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          Money.format(
                              Money.toMilli((g['amount'] as num?) ?? 0)),
                          textAlign: TextAlign.right,
                          style:
                              TextStyle(fontSize: 12, color: scheme.primary),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────── 正文渲染 ───────────────────────

  Widget _richText(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    final base = TextStyle(
      fontSize: 14,
      height: 1.55,
      color: scheme.onSurface,
    );

    final lines = text.split('\n');
    final children = <Widget>[];

    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 6));
        continue;
      }

      final isBullet = line.trimLeft().startsWith('- ') ||
          line.trimLeft().startsWith('• ');
      final content = isBullet ? line.trimLeft().substring(2) : line;
      final spans = _parseBold(content, base);

      children.add(
        Padding(
          padding: EdgeInsets.only(left: isBullet ? 4 : 0, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (isBullet)
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 6),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              Expanded(
                child: Text.rich(TextSpan(style: base, children: spans)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  static List<TextSpan> _parseBold(String line, TextStyle base) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    var last = 0;
    for (final m in regex.allMatches(line)) {
      if (m.start > last) {
        spans.add(TextSpan(text: line.substring(last, m.start)));
      }
      spans.add(TextSpan(
        text: m.group(1),
        style: base.copyWith(fontWeight: FontWeight.w700),
      ));
      last = m.end;
    }
    if (last < line.length) {
      spans.add(TextSpan(text: line.substring(last)));
    }
    if (spans.isEmpty) spans.add(TextSpan(text: line));
    return spans;
  }

  // ─────────────────────── 解析辅助 ───────────────────────

  static Object? _tryDecode(String raw) {
    if (raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _parseJson(String raw) {
    final obj = _tryDecode(raw);
    if (obj is Map) return obj.map((k, v) => MapEntry(k.toString(), v));
    return null;
  }

  static RecordFilter? _parseFilter(String raw) {
    final obj = _tryDecode(raw);
    if (obj is Map) {
      return RecordFilter.fromJson(
        obj.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return null;
  }
}

/// 思考过程：默认折叠，点开看模型怎么想的
class _ThinkingBlock extends StatefulWidget {
  const _ThinkingBlock({required this.text});

  final String text;

  @override
  State<_ThinkingBlock> createState() => _ThinkingBlockState();
}

class _ThinkingBlockState extends State<_ThinkingBlock> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withAlpha(55),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: scheme.outlineVariant.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                children: <Widget>[
                  Icon(Icons.psychology_outlined,
                      size: 13, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Text(
                    '思考过程',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${widget.text.length} 字',
                    style: TextStyle(
                      fontSize: 9,
                      color: scheme.onSurfaceVariant.withAlpha(150),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _open ? '收起' : '展开',
                    style: TextStyle(fontSize: 10, color: scheme.primary),
                  ),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    size: 14,
                    color: scheme.primary,
                  ),
                ],
              ),
            ),
          ),
          if (_open) ...<Widget>[
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: Text(
                  widget.text,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.55,
                    fontStyle: FontStyle.italic,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 一张工具卡片：点一下展开完整入参/结果
class _ToolRow extends StatefulWidget {
  const _ToolRow({required this.trace});

  final Map<String, dynamic> trace;

  @override
  State<_ToolRow> createState() => _ToolRowState();
}

class _ToolRowState extends State<_ToolRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = widget.trace;
    final ok = t['ok'] != false;
    final name = (t['name'] as String?) ?? '';
    final input = (t['input'] as String?) ?? '';
    final output = (t['output'] as String?) ?? '';
    final detail = (t['detail'] as String?) ?? '';
    final accent = ok ? scheme.primary : scheme.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withAlpha(10),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: accent.withAlpha(38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Row(
              children: <Widget>[
                Icon(
                  AiMessageBubble._toolIcon(name),
                  size: 13,
                  color: accent,
                ),
                const SizedBox(width: 5),
                Text(
                  (t['label'] as String?) ?? name,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    height: 1.3,
                  ),
                ),
                if (input.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      input,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                if (widget.trace['durationMs'] is int &&
                    (widget.trace['durationMs'] as int) > 0) ...<Widget>[
                  const SizedBox(width: 4),
                  Text(
                    '${widget.trace['durationMs']}ms',
                    style: TextStyle(
                      fontSize: 8.5,
                      color: scheme.onSurfaceVariant.withAlpha(140),
                      fontFeatures: tabularFigures,
                    ),
                  ),
                ],
                Icon(
                  _open ? Icons.expand_less : Icons.expand_more,
                  size: 13,
                  color: scheme.onSurfaceVariant.withAlpha(140),
                ),
              ],
            ),
          ),
          if (output.isNotEmpty && !_open) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              '→ $output',
              style: TextStyle(
                fontSize: 10,
                color: scheme.onSurface,
                fontFeatures: tabularFigures,
                height: 1.35,
              ),
            ),
          ],
          if (_open) ...<Widget>[
            const SizedBox(height: 6),
            _kv('工具', name, scheme),
            if (input.isNotEmpty) _kv('入参', input, scheme),
            if (output.isNotEmpty) _kv('结果', output, scheme),
            // 终端命令这类工具的完整输出，展开才看，避免刷屏
            if (detail.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 220),
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: (Theme.of(context).brightness == Brightness.dark
                          ? Colors.black
                          : const Color(0xFFF4F5F7)),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: scheme.outlineVariant.withAlpha(90)),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    detail,
                    style: TextStyle(
                      fontSize: 9.5,
                      height: 1.45,
                      fontFamily: 'monospace',
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _kv(String k, String v, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 34,
            child: Text(
              k,
              style: TextStyle(
                fontSize: 9.5,
                color: scheme.onSurfaceVariant.withAlpha(170),
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              v,
              style: TextStyle(
                fontSize: 10,
                height: 1.4,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
