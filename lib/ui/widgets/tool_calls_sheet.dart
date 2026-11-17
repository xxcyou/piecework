import 'package:flutter/material.dart';

/// 点「+N」弹出的轻量清单：这次到底调了哪些工具
Future<void> showToolCallsSheet(
  BuildContext context, {
  required List<String> tools,
  int? count,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      final total = count ?? tools.length;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.bolt_rounded, size: 16, color: scheme.primary),
                  const SizedBox(width: 5),
                  Text(
                    '本次调用 $total 次工具',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (tools.isEmpty)
                Text(
                  '还没有工具调用记录',
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant),
                )
              else
                for (var i = 0; i < tools.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: scheme.primary.withAlpha(22),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tools[i],
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: 4),
              Text(
                '回答结束后，每条工具的输入输出会完整留在工具卡片里',
                style: TextStyle(
                  fontSize: 10.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
