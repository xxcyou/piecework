import 'package:flutter/material.dart';

import 'tool_count_chip.dart';

/// 流式回答顶部的标题行：`◐ 正在思考…  ⚡+2`
///
/// 计数徽标紧跟在标题右边，只要还在思考就一直显示；
/// 思考结束（气泡被正式消息替换）自然就没了。
class ThinkingHeader extends StatelessWidget {
  const ThinkingHeader({
    super.key,
    required this.hasContent,
    required this.toolCount,
  });

  /// 是否已经开始吐正文（决定文案是「思考」还是「回答」）
  final bool hasContent;

  /// 已经调用了几次工具（0 时不显示徽标）
  final int toolCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        SizedBox(
          width: 11,
          height: 11,
          child: CircularProgressIndicator(
            strokeWidth: 1.6,
            valueColor: AlwaysStoppedAnimation<Color>(scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          hasContent ? '正在回答…' : '正在思考…',
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
        if (toolCount > 0) ...<Widget>[
          const SizedBox(width: 6),
          ToolCountChip(count: toolCount, dense: true),
        ],
      ],
    );
  }
}
