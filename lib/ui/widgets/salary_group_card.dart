import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../data/models/piece_record.dart';
import '../../data/services/salary_summary.dart';
import 'color_chip.dart';

/// 工资模式的一行：同款汇总（型号·颜色·码数 / 数量 / 单价 / 金额）
///
/// 不显示日期 —— 工资模式只看「做了多少、该拿多少钱」。
class SalaryGroupCard extends StatelessWidget {
  const SalaryGroupCard({
    super.key,
    required this.group,
    required this.baseUnit,
    required this.onTap,
  });

  final SalaryGroup group;
  final String baseUnit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mixed = group.unit != baseUnit;
    return Material(
      color: scheme.surfaceContainerHighest.withAlpha(40),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            group.styleModel.isEmpty
                                ? '（未填型号）'
                                : group.styleModel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (group.color.isNotEmpty) ...<Widget>[
                          const SizedBox(width: 6),
                          ColorChip(name: group.color, size: 9.5),
                        ],
                        if (group.size.isNotEmpty) ...<Widget>[
                          const SizedBox(width: 6),
                          Text(group.size,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: scheme.onSurfaceVariant)),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    Money.format(group.amountMilli),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Text(
                    mixed
                        ? '${(group.centiBase / 100).toStringAsFixed(2)} $baseUnit（折算）'
                        : '${group.qty} ${group.unit}',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  const SizedBox(width: 8),
                  Text('× ${Money.plain(Money.toMilli(group.unitPrice))}',
                      style: TextStyle(
                          fontSize: 11.5, color: scheme.onSurfaceVariant)),
                  const Spacer(),
                  Text('${group.count} 条',
                      style: TextStyle(
                          fontSize: 10.5, color: scheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 点开一组 → 看这一组里的逐条明细（可编辑）
Future<void> showSalaryGroupDetail(
  BuildContext context,
  SalaryGroup group,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: <Widget>[
          Text(group.label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            '共 ${group.count} 条 · 合计 ${group.qty} ${group.unit} · '
            '${Money.format(group.amountMilli)}',
            style: const TextStyle(fontSize: 11.5),
          ),
          const SizedBox(height: 10),
          for (final r in group.records)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${r.quantity} ${r.unitOrBase}'
                      '${r.note.isEmpty ? '' : ' · ${r.note}'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(Money.format(r.subtotalMilli),
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

/// 工资模式列表头部：一条总账
class SalaryTotalBar extends StatelessWidget {
  const SalaryTotalBar({
    super.key,
    required this.groups,
    required this.baseUnit,
    required this.totalAmountMilli,
    required this.totalCount,
    required this.totalCenti,
  });

  final List<SalaryGroup> groups;
  final String baseUnit;
  final int totalAmountMilli;
  final int totalCount;
  final int totalCenti;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 2, 14, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: scheme.primary.withAlpha(16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.primary.withAlpha(40)),
      ),
      child: Row(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('合计工资',
                  style: TextStyle(
                      fontSize: 11, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(
                Money.format(totalAmountMilli),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text('${groups.length} 款',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                '${(totalCenti / 100).toStringAsFixed(totalCenti % 100 == 0 ? 0 : 2)} '
                '$baseUnit · $totalCount 条',
                style: TextStyle(
                    fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
