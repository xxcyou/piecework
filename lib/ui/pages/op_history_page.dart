import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/models/operation_log.dart';
import '../../providers/chat_providers.dart';
import '../../providers/db_providers.dart';
import '../../providers/records_providers.dart';

/// 操作历史：所有写操作（新增/修改/删除/结算）都在这里，任何一条都能撤回。
///
/// 保留 30 天，和回收站同一个周期。
class OpHistoryPage extends ConsumerWidget {
  const OpHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(opLogsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('操作历史')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('读取失败：$e')),
        data: (logs) {
          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.history,
                      size: 40, color: scheme.onSurfaceVariant.withAlpha(120)),
                  const SizedBox(height: 10),
                  Text(
                    '还没有操作记录',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '新增、修改、删除、结算都会记在这里，可随时撤回',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant.withAlpha(170),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 7),
            itemBuilder: (_, i) => _LogTile(log: logs[i]),
          );
        },
      ),
    );
  }
}

class _LogTile extends ConsumerWidget {
  const _LogTile({required this.log});

  final OperationLog log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final undone = log.undone;
    final (icon, color) = switch (log.kindEnum) {
      OpKind.delete => (Icons.delete_outline, scheme.error),
      OpKind.update => (Icons.edit_outlined, scheme.primary),
      OpKind.create => (Icons.add_circle_outline, const Color(0xFF0E9F6E)),
      OpKind.restore => (Icons.restore, const Color(0xFFE8830C)),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1B1E24)
            : Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: undone
              ? scheme.outlineVariant.withAlpha(90)
              : color.withAlpha(55),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: (undone ? scheme.outline : color).withAlpha(22),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              undone ? Icons.undo : icon,
              size: 15,
              color: undone ? scheme.outline : color,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        log.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                          color: undone
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                          decoration: undone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    if (log.isAi) ...<Widget>[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: scheme.primary.withAlpha(24),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'AI',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${Fmt.relative(log.createdAt)} · ${log.recordCount} 条'
                  '${undone ? " · 已撤销" : ""}',
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant.withAlpha(190),
                  ),
                ),
              ],
            ),
          ),
          if (!undone)
            TextButton(
              onPressed: () => _undo(context, ref),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: scheme.error,
              ),
              child: const Text('撤回', style: TextStyle(fontSize: 11.5)),
            ),
        ],
      ),
    );
  }

  Future<void> _undo(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('撤回这次操作？'),
        content: Text(
          '${log.summary}\n\n'
          '撤回会把数据还原到操作之前的状态。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('撤回'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final done = await ref.read(opLogRepoProvider).undo(log.id);
    ref.invalidate(opLogsProvider);
    ref.invalidate(recordsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(done ? '已撤回，数据已还原' : '这条操作已经撤回过或数据异常')),
    );
  }
}
