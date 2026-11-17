import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/money.dart';
import '../../data/models/operation_log.dart';
import '../../data/models/piece_record.dart';
import '../../data/services/photo_service.dart';
import '../../providers/chat_providers.dart';
import '../../providers/db_providers.dart';
import '../../providers/records_providers.dart';

/// 回收站：删除的记录保留 30 天，随时可恢复。
///
/// 删除是软删除（`deletedAt` 非空），照片也一起留着 —— 恢复后缩略图还在。
class TrashPage extends ConsumerWidget {
  const TrashPage({super.key});

  static const int keepDays = 30;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(deletedRecordsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('回收站'),
        actions: <Widget>[
          TextButton(
            onPressed: () => _clearAll(context, ref),
            child: Text('清空', style: TextStyle(color: scheme.error)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('读取失败：$e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.delete_outline,
                      size: 42, color: scheme.onSurfaceVariant.withAlpha(110)),
                  const SizedBox(height: 10),
                  Text(
                    '回收站是空的',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '删除的记录会在这里保留 $keepDays 天',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant.withAlpha(170),
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.info_outline,
                        size: 13, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${list.length} 条 · 删除后保留 $keepDays 天，到期自动彻底清除',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 30),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 7),
                  itemBuilder: (_, i) => _TrashTile(record: list[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final list = ref.read(deletedRecordsProvider).valueOrNull ?? const <PieceRecord>[];
    if (list.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空回收站？'),
        content: Text(
          '将永久删除 ${list.length} 条记录及照片，之后无法恢复。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('永久删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final repo = ref.read(recordRepoProvider);
    await repo.purgeMany(list.map((e) => e.id).toList());
    await PhotoService.instance.deleteMany(
      list.map((e) => e.photoName).where((n) => n.isNotEmpty),
    );
    ref.invalidate(deletedRecordsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已永久删除 ${list.length} 条')),
    );
  }
}

class _TrashTile extends ConsumerWidget {
  const _TrashTile({required this.record});

  final PieceRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final deletedAt = record.deletedAt ?? DateTime.now();
    final left = TrashPage.keepDays - DateTime.now().difference(deletedAt).inDays;
    final urgent = left <= 3;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1B1E24)
            : Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: scheme.outlineVariant.withAlpha(130)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  record.styleModel.isEmpty ? '（未填型号）' : record.styleModel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Text(
                Money.yuan(record.subtotalMilli),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                  fontFeatures: tabularFigures,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${record.color.isEmpty ? "—" : record.color} · '
            '${record.size.isEmpty ? "—" : record.size} · '
            '${record.quantity} ${record.unitOrBase} × '
            '¥${Money.plain(Money.toMilli(record.unitPrice))}',
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
              fontFeatures: tabularFigures,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: <Widget>[
              Text(
                '删除于 ${Fmt.dateTime(deletedAt)}',
                style: TextStyle(
                  fontSize: 10,
                  color: scheme.onSurfaceVariant.withAlpha(180),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '还剩 $left 天',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: urgent ? FontWeight.w700 : FontWeight.w400,
                  color: urgent ? scheme.error : scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _restore(context, ref),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('恢复', style: TextStyle(fontSize: 11.5)),
              ),
              TextButton(
                onPressed: () => _purge(context, ref),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: scheme.error,
                ),
                child: const Text('彻底删除', style: TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    await ref.read(recordRepoProvider).restore(record.id);
    await ref.read(opLogRepoProvider).record(
          kind: OpKind.restore,
          source: 'manual',
          summary: '恢复记录：${record.styleModel}',
          before: <PieceRecord>[record],
        );
    ref.invalidate(deletedRecordsProvider);
    ref.invalidate(opLogsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已恢复到记录列表')),
    );
  }

  Future<void> _purge(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('彻底删除？'),
        content: const Text('这条记录和照片会被永久删除，无法恢复。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('永久删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await ref.read(recordRepoProvider).purge(record.id);
    if (record.photoName.isNotEmpty) {
      await PhotoService.instance.delete(record.photoName);
    }
    ref.invalidate(deletedRecordsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已永久删除')),
    );
  }
}
