import 'package:flutter/material.dart';

/// 流式回答时气泡右上角的小徽标：`+1` `+2` …
///
/// 工具调用往往一闪而过（尤其查询类，几十毫秒就回来了），
/// 只靠「正在调用…」那行文字，用户会怀疑到底有没有真的调。
/// 这个计数只增不减，回答结束前一直挂在气泡上。
class ToolCountChip extends StatelessWidget {
  const ToolCountChip({
    super.key,
    required this.count,
    this.dense = false,
    this.onTap,
  });

  final int count;
  final bool dense;

  /// 点一下看「调了哪些工具」
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 5 : 6,
        vertical: dense ? 1.5 : 2,
      ),
      decoration: BoxDecoration(
        color: scheme.primary.withAlpha(24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.primary.withAlpha(90)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.bolt_rounded, size: dense ? 10 : 11, color: scheme.primary),
          const SizedBox(width: 2),
          Text(
            '+$count',
            style: TextStyle(
              fontSize: dense ? 9.5 : 10,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return body;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: body,
    );
  }
}
