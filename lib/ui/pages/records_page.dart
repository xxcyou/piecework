import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/models/operation_log.dart';
import '../../data/models/operation_view.dart';
import '../../data/services/unit_converter.dart';
import '../../data/models/piece_record.dart';
import '../../data/models/record_filter.dart';
import '../../data/services/record_codec.dart';
import '../../data/services/selection_summary.dart';
import '../../providers/db_providers.dart';
import '../../providers/records_providers.dart';
import '../../providers/units_providers.dart';
import '../widgets/empty_state.dart';
import '../widgets/record_card.dart';
import '../widgets/stat_bar.dart';
import 'filter_page.dart';
import 'record_edit_page.dart';

/// 记录列表页：统计条 + 筛选摘要 + 卡片列表 + 批量选择
class RecordsPage extends ConsumerWidget {
  const RecordsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opView = ref.watch(operationViewProvider);
    final async = ref.watch(recordsProvider);
    final result = ref.watch(filteredResultProvider);
    final filter = ref.watch(filterProvider);
    final selection = ref.watch(selectionProvider);
    final selectionMode = ref.watch(selectionModeProvider);
    final scheme = Theme.of(context).colorScheme;
    final converter = ref.watch(unitConverterProvider);

    // 筛选一变，分页回到第一批
    ref.listen<RecordFilter>(filterProvider, (prev, next) {
      if (prev != next) ref.read(visibleCountProvider.notifier).reset();
    });

    final total = result.records.length;
    final visible = math.min(ref.watch(visibleCountProvider), total);
    final hasMore = visible < total;

    // 操作快照视图：把这次操作涉及的记录摊出来（含已删除的）
    if (opView != null) {
      return _operationScaffold(context, ref, opView, converter);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(selectionMode ? '已选 ${selection.length} 项' : '计件记录'),
        leading: selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: '退出多选',
                onPressed: () {
                  ref.read(selectionModeProvider.notifier).exit();
                  ref.read(selectionProvider.notifier).clear();
                },
              )
            : null,
        actions: <Widget>[
          if (selectionMode) ...<Widget>[
            IconButton(
              tooltip: '全选',
              icon: const Icon(Icons.select_all),
              onPressed: () => ref
                  .read(selectionProvider.notifier)
                  .selectAll(result.records.map((e) => e.id)),
            ),
            IconButton(
              tooltip: '标记为已上报',
              icon: const Icon(Icons.check_circle_outline),
              onPressed: selection.isEmpty
                  ? null
                  : () => _markReported(
                        context,
                        ref,
                        result.records,
                        selection,
                        true,
                      ),
            ),
            IconButton(
              tooltip: '撤销上报',
              icon: const Icon(Icons.undo),
              onPressed: selection.isEmpty
                  ? null
                  : () => _markReported(
                        context,
                        ref,
                        result.records,
                        selection,
                        false,
                      ),
            ),
            IconButton(
              tooltip: '汇总所选（数量 / 金额）',
              icon: const Icon(Icons.calculate_outlined),
              onPressed: selection.isEmpty
                  ? null
                  : () => _showSelectionSummary(
                        context,
                        ref,
                        result.records
                            .where((r) => selection.contains(r.id))
                            .toList(),
                      ),
            ),
            IconButton(
              tooltip: '删除',
              icon: Icon(Icons.delete_outline,
                  color: selection.isEmpty ? null : scheme.error),
              onPressed: selection.isEmpty
                  ? null
                  : () => _deleteSelected(context, ref, result.records, selection),
            ),
            const SizedBox(width: 2),
          ] else ...<Widget>[
            IconButton(
              tooltip: '排序',
              icon: const Icon(Icons.swap_vert),
              onPressed: () => _showSortSheet(context, ref, filter),
            ),
            IconButton(
              tooltip: '筛选',
              icon: Badge(
                isLabelVisible: filter.activeCount > 0,
                label: Text('${filter.activeCount}'),
                child: const Icon(Icons.filter_list),
              ),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const FilterPage()),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
            child: StatBar(
              count: result.count,
              quantityCenti: result.totalCentiBase,
              amountMilli: result.totalAmountMilli,
              baseUnit: result.baseUnit,
              mixedUnits: result.mixedUnits,
              unpricedCount: result.unpricedCount,
              unpricedQuantity: result.unpricedQuantity,
            ),
          ),
          // 锁定的记录里有些被删了 → 明确告知，避免以为「少了几条」
          if (filter.isPinned && result.count < filter.pinnedIds.length)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 2),
              child: Row(
                children: <Widget>[
                  Icon(Icons.info_outline,
                      size: 12, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    '这批记录里有 ${filter.pinnedIds.length - result.count} 条已被删除',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          if (filter.isActive)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
              child: Row(
                children: <Widget>[
                  Icon(Icons.filter_alt_outlined,
                      size: 13, color: scheme.primary),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      filter.summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(filterProvider.notifier).reset(),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('清除筛选', style: TextStyle(fontSize: 11.5)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyState(
                icon: Icons.storage_outlined,
                title: '读取本地数据库失败',
                subtitle: '$e',
              ),
              data: (_) {
                if (result.records.isEmpty) {
                  return EmptyState(
                    icon: Icons.inbox_outlined,
                    title: filter.isActive ? '没有符合条件的记录' : '还没有录入任何记录',
                    subtitle: filter.isActive
                        ? '放宽筛选条件试试，或点右下角「录入」新增一条。'
                        : '点右下角「录入」，拍照登记第一条计件记录。',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => _onRefresh(ref),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 110),
                    // 分块加载：只渲染前 visible 条，滚到底再追加一批
                    itemCount: visible + (hasMore ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i >= visible) {
                        return _LoadMoreTile(
                          shown: visible,
                          total: total,
                          onVisible: () =>
                              ref.read(visibleCountProvider.notifier).more(),
                        );
                      }
                      final r = result.records[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        // 卡片各自成层，滚动时只重绘变动的部分
                        child: RepaintBoundary(
                          child: RecordCard(
                            record: r,
                            converter: converter,
                            selectionMode: selectionMode,
                            selected: selection.contains(r.id),
                            onTap: () {
                              if (selectionMode) {
                                ref
                                    .read(selectionProvider.notifier)
                                    .toggle(r.id);
                              } else {
                                Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        RecordEditPage(recordId: r.id),
                                  ),
                                );
                              }
                            },
                            onLongPress: () {
                              if (!selectionMode) {
                                ref
                                    .read(selectionModeProvider.notifier)
                                    .enter();
                                ref
                                    .read(selectionProvider.notifier)
                                    .toggle(r.id);
                              }
                            },
                            onMore: () => _showRecordMenu(context, ref, r),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 下拉刷新：清掉筛选 + 回到第一批
  Future<void> _onRefresh(WidgetRef ref) async {
    ref.read(filterProvider.notifier).reset();
    ref.read(visibleCountProvider.notifier).reset();
    ref.read(selectionProvider.notifier).clear();
    ref.read(selectionModeProvider.notifier).exit();
    // 等 Stream 把新数据推上来，刷新动画才不至于一闪而过
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  // ───────────────────────── 排序 ─────────────────────────

  void _showSortSheet(
    BuildContext context,
    WidgetRef ref,
    RecordFilter filter,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text('排序方式',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              for (final f in SortField.values)
                ListTile(
                  dense: true,
                  title: Text('按${f.label}'),
                  trailing: filter.sortField == f
                      ? Icon(
                          filter.ascending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 18,
                          color: Theme.of(ctx).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    ref.read(filterProvider.notifier).setSort(f);
                    Navigator.of(ctx).pop();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────── 单条操作菜单 ───────────────────────

  void _showRecordMenu(BuildContext context, WidgetRef ref, PieceRecord r) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.checklist_rounded),
              title: const Text('多选'),
              subtitle: const Text(
                '勾选多条后可以汇总数量/金额、批量上报或删除',
                style: TextStyle(fontSize: 11),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                ref.read(selectionModeProvider.notifier).enter();
                ref.read(selectionProvider.notifier).toggle(r.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: const Text('复制'),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => RecordEditPage(seed: r),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑这条记录'),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => RecordEditPage(recordId: r.id),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                r.isReported
                    ? Icons.undo
                    : Icons.check_circle_outline,
              ),
              title: Text(r.isReported ? '撤销上报标记' : '标记为已上报'),
              subtitle: Text(
                r.isReported
                    ? '改回「未上报」，会重新出现在默认列表里'
                    : '上报后默认列表不再显示这条',
                style: const TextStyle(fontSize: 11),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                final repo = ref.read(recordRepoProvider);
                final before =
                    RecordCodec.fromJson(RecordCodec.toJson(r));
                r.status = r.isReported
                    ? RecordStatus.pending
                    : RecordStatus.reported;
                r.reportedAt = r.isReported ? null : DateTime.now();
                r.updatedAt = DateTime.now();
                await repo.save(r);
                await ref.read(opLogRepoProvider).record(
                      kind: OpKind.update,
                      source: 'manual',
                      summary: r.isReported ? '标记 1 条为已上报' : '撤销 1 条上报标记',
                      before: <PieceRecord>[before],
                    );
              },
            ),
            if (r.photoName.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.image_not_supported_outlined),
                title: const Text('移除关联照片'),
                subtitle: const Text('只删照片，记录保留', style: TextStyle(fontSize: 11)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final before =
                      RecordCodec.fromJson(RecordCodec.toJson(r));
                  final old = r.photoName;
                  r.photoName = '';
                  r.updatedAt = DateTime.now();
                  await ref.read(recordRepoProvider).save(r);
                  // 只有没有任何记录再引用时才删文件
                  await ref.read(photoGcProvider).deleteIfUnreferenced(old);
                  await ref.read(opLogRepoProvider).record(
                        kind: OpKind.update,
                        source: 'manual',
                        summary: '移除 1 条记录的照片',
                        before: <PieceRecord>[before],
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已移除照片，记录保留')),
                    );
                  }
                },
              ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: scheme.error),
              title: Text('删除这条记录', style: TextStyle(color: scheme.error)),
              onTap: () async {
                Navigator.of(ctx).pop();
                final ok = await _confirmDelete(context, 1);
                if (ok) {
                  await ref.read(recordRepoProvider).deleteById(r.id);
                  await ref.read(opLogRepoProvider).record(
                        kind: OpKind.delete,
                        source: 'manual',
                        summary: '删除 1 条记录',
                        before: <PieceRecord>[r],
                      );
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── 批量删除 ─────────────────────────

  Future<void> _deleteSelected(
    BuildContext context,
    WidgetRef ref,
    List<PieceRecord> all,
    Set<int> selection,
  ) async {
    final targets = all.where((e) => selection.contains(e.id)).toList();
    if (targets.isEmpty) return;

    final ok = await _confirmDelete(context, targets.length);
    if (!ok) return;

    // 软删除：进回收站，30 天内可恢复；照片也先留着
    final affected = await ref
        .read(recordRepoProvider)
        .deleteMany(targets.map((e) => e.id).toList());

    if (affected.isNotEmpty) {
      await ref.read(opLogRepoProvider).record(
            kind: OpKind.delete,
            source: 'manual',
            summary: '删除 ${affected.length} 条记录',
            before: affected,
          );
    }

    ref.read(selectionProvider.notifier).clear();
    ref.read(selectionModeProvider.notifier).exit();
  }

  /// 多选汇总：数量（跨单位自动折算）+ 金额 + 按型号·颜色·码数分组小计
  void _showSelectionSummary(
    BuildContext context,
    WidgetRef ref,
    List<PieceRecord> picked,
  ) {
    final converter = ref.read(unitConverterProvider);
    final sum = SelectionSummary.of(picked, converter);
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        maxChildSize: 0.92,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.calculate_outlined, size: 18, color: scheme.primary),
                const SizedBox(width: 6),
                Text('所选 ${sum.count} 条',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            // 数量
            _sumRow(
              scheme,
              '数量',
              sum.mixedUnits
                  ? '${Money.format(Money.toMilli(sum.baseQty))} ${sum.baseUnit}（折算）'
                  : '${sum.qty} ${sum.units.isEmpty ? '' : sum.units.first}',
              note: sum.mixedUnits
                  ? '原始单位：${sum.units.join(' + ')}；按单位换算规则折算'
                  : null,
            ),
            // 金额
            _sumRow(
              scheme,
              '金额',
              Money.format(sum.amountMilli),
              note: sum.unpricedCount > 0
                  ? '另有 ${sum.unpricedCount} 条未计价（共 ${sum.unpricedQty} 件），'
                      '金额未包含它们'
                  : null,
              highlight: true,
            ),
            if (sum.lines.length > 1) ...<Widget>[
              const SizedBox(height: 14),
              Text('按型号 · 颜色 · 码数分组',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              for (final l in sum.lines)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withAlpha(45),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(l.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600)),
                          ),
                          Text(
                            '${l.count} 条',
                            style: TextStyle(
                                fontSize: 11, color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: <Widget>[
                          Text(
                            l.mixedUnits
                                ? '${(l.centiBase / 100).toStringAsFixed(2)} ${sum.baseUnit}（折算）'
                                : '${l.qty} ${l.units.isEmpty ? '' : l.units.first}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const Spacer(),
                          Text(
                            Money.format(l.amountMilli),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                      if (l.unpricedCount > 0)
                        Text(
                          '其中 ${l.unpricedCount} 条未计价',
                          style: TextStyle(
                              fontSize: 10.5, color: scheme.error),
                        ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 10),
            Text(
              '金额按「整数厘」累加，不会出现浮点误差；跨单位数量按设置里的换算规则折算。',
              style: TextStyle(
                  fontSize: 10.5, height: 1.5, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sumRow(
    ColorScheme scheme,
    String label,
    String value, {
    String? note,
    bool highlight = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: highlight ? scheme.primary.withAlpha(14) : scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(label,
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant)),
              const Spacer(),
              Text(value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: highlight ? scheme.primary : scheme.onSurface,
                  )),
            ],
          ),
          if (note != null) ...<Widget>[
            const SizedBox(height: 3),
            Text(note,
                style: TextStyle(
                    fontSize: 10.5,
                    height: 1.4,
                    color: scheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }

  /// 批量改上报状态
  Future<void> _markReported(
    BuildContext context,
    WidgetRef ref,
    List<PieceRecord> all,
    Set<int> selection,
    bool reported,
  ) async {
    final targets = all.where((e) => selection.contains(e.id)).toList();
    if (targets.isEmpty) return;

    final repo = ref.read(recordRepoProvider);
    final now = DateTime.now();

    // 快照旧状态，支持撤回
    final before = targets
        .map((r) => RecordCodec.fromJson(RecordCodec.toJson(r)))
        .toList();

    for (final r in targets) {
      r.status = reported ? RecordStatus.reported : RecordStatus.pending;
      r.reportedAt = reported ? now : null;
      r.updatedAt = now;
      await repo.save(r);
    }

    await ref.read(opLogRepoProvider).record(
          kind: OpKind.update,
          source: 'manual',
          summary: reported
              ? '标记 ${targets.length} 条为已上报'
              : '撤销 ${targets.length} 条的上报标记',
          before: before,
        );

    ref.read(selectionProvider.notifier).clear();
    ref.read(selectionModeProvider.notifier).exit();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reported
              ? '已把 ${targets.length} 条标记为已上报'
              : '已撤销 ${targets.length} 条的上报标记'),
        ),
      );
    }
  }

  /// 操作快照视图：伪造列表，展示这次操作涉及的记录
  Widget _operationScaffold(
    BuildContext context,
    WidgetRef ref,
    OperationView view,
    UnitConverter converter,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final accent = view.tag == '已删除'
        ? scheme.error
        : (view.tag == '新建' ? const Color(0xFF0E9F6E) : scheme.primary);

    return Scaffold(
      appBar: AppBar(
        title: const Text('操作快照'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: '关闭',
          onPressed: () =>
              ref.read(operationViewProvider.notifier).state = null,
        ),
      ),
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            color: accent.withAlpha(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.history_toggle_off, size: 15, color: accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        view.title,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: accent,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '这是操作那一刻的快照，共 ${view.count} 条'
                  '${view.note.isEmpty ? "" : "（${view.note}）"}',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 30),
              itemCount: view.records.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RecordCard(
                  record: view.records[i],
                  converter: converter,
                  extraTag: view.tag,
                  extraTagColor: accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, int count) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('将把 $count 条记录移入回收站（保留 30 天，可随时恢复）。\n'
          '30 天后自动彻底删除，照片也会一并清理。'),
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
            child: const Text('删除'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}


/// 滚到底时自动加载下一批（只构建一次，加载完自身就被替换掉）
class _LoadMoreTile extends StatefulWidget {
  const _LoadMoreTile({
    required this.shown,
    required this.total,
    required this.onVisible,
  });

  final int shown;
  final int total;
  final VoidCallback onVisible;

  @override
  State<_LoadMoreTile> createState() => _LoadMoreTileState();
}

class _LoadMoreTileState extends State<_LoadMoreTile> {
  @override
  void initState() {
    super.initState();
    // 这一块被构建出来，说明用户滚到底了
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onVisible();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '加载更多…（${widget.shown}/${widget.total}）',
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
