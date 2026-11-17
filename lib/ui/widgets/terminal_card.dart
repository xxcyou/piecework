import 'package:flutter/material.dart';

import '../../providers/terminal_providers.dart';

/// 聊天里的终端卡片。
///
/// * 会话进行中（[live] = true）：底部有个闪烁光标，标题写「终端会话 · 进行中」；
/// * 会话结束：变成普通卡片，只展示历史命令与输出。
class TerminalCard extends StatelessWidget {
  const TerminalCard({
    super.key,
    required this.lines,
    this.env = 'linux',
    this.live = false,
    this.busy = false,
    this.cwd = '',
    this.onAsk,
  });

  final List<TerminalLine> lines;
  final String env;
  final bool live;
  final bool busy;

  /// shell 当前目录（常驻 shell 才有）
  final String cwd;

  /// 结束态卡片上的「问 AI」回调；为空则不显示按钮
  final VoidCallback? onAsk;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF0E1116) : const Color(0xFF1B1F27);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: live
              ? scheme.primary.withAlpha(160)
              : scheme.outlineVariant.withAlpha(90),
          width: live ? 1.2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 标题栏：像终端窗口的 tab
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(10),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.terminal,
                    size: 13, color: scheme.primary.withAlpha(220)),
                const SizedBox(width: 5),
                Text(
                  cwd.isEmpty ? '终端 · $env' : '终端 · $env · $cwd',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withAlpha(220),
                    height: 1.2,
                  ),
                ),
                const SizedBox(width: 6),
                if (live)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: scheme.primary.withAlpha(40),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      busy ? '运行中' : '进行中',
                      style: TextStyle(
                        fontSize: 8.5,
                        color: scheme.primary,
                        height: 1.2,
                      ),
                    ),
                  ),
                const Spacer(),
                if (live)
                  Text(
                    '删掉「/ 」退出',
                    style: TextStyle(
                      fontSize: 8.5,
                      color: Colors.white.withAlpha(110),
                      height: 1.2,
                    ),
                  ),
              ],
            ),
          ),
          // 输出区
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (lines.isEmpty)
                  Text(
                    '输入命令回车执行（Alpine Linux）；用 @help 看能调用的 AI 工具',
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.5,
                      fontFamily: 'monospace',
                      color: Colors.white.withAlpha(120),
                    ),
                  ),
                for (final l in lines) _line(l),
                if (live && !busy)
                  Text(
                    '❯ ',
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.5,
                      fontFamily: 'monospace',
                      color: scheme.primary,
                    ),
                  ),
                // 结束后的卡片：告诉用户这段操作已经进了 AI 的上下文
                if (!live && lines.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '这段操作已并入对话，AI 知道刚才做了什么',
                          style: TextStyle(
                            fontSize: 9,
                            height: 1.4,
                            color: Colors.white.withAlpha(110),
                          ),
                        ),
                      ),
                      if (onAsk != null)
                        TextButton(
                          onPressed: onAsk,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 26),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: const Color(0xFF7FE3A1),
                            textStyle: const TextStyle(fontSize: 9.5),
                          ),
                          child: const Text('问 AI 这段'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(TerminalLine l) {
    final color = switch (l.kind) {
      TerminalLineKind.command => const Color(0xFF7FE3A1),
      TerminalLineKind.error => const Color(0xFFFF8A80),
      TerminalLineKind.info => const Color(0xFF9AA4B2),
      TerminalLineKind.output => Colors.white.withAlpha(225),
    };
    return Text(
      l.text.isEmpty ? ' ' : l.text,
      style: TextStyle(
        fontSize: 10.5,
        height: 1.5,
        fontFamily: 'monospace',
        color: color,
      ),
    );
  }
}
