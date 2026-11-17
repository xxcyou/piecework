import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/money.dart';
import '../../data/services/unit_converter.dart';

/// 列表顶部的统计条：条数 / 总件数 / 总金额
class StatBar extends StatelessWidget {
  const StatBar({
    super.key,
    required this.count,
    required this.quantityCenti,
    required this.amountMilli,
    this.baseUnit = '件',
    this.mixedUnits = false,
    this.unpricedCount = 0,
    this.unpricedQuantity = 0,
  });

  final int count;

  /// 折算成基准单位的「百分之一」—— 混单位时只有这个才有意义
  final int quantityCenti;

  final String baseUnit;

  /// 是否混用了多种单位（显示小提示）
  final bool mixedUnits;

  /// 总金额（分）—— 只统计了填过单价的记录
  final int amountMilli;

  /// 没填单价的条数 / 件数（金额未计入）
  final int unpricedCount;
  final int unpricedQuantity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.primary.withAlpha(14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.primary.withAlpha(38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _Cell(label: '记录', value: Fmt.count(count), unit: '条'),
              _Divider(color: scheme.primary.withAlpha(50)),
              _Cell(
                label: mixedUnits ? '件数(折算)' : '件数',
                value: UnitConverter.formatCenti(quantityCenti),
                unit: baseUnit,
              ),
              _Divider(color: scheme.primary.withAlpha(50)),
              _Cell(
                label: unpricedCount > 0 ? '已知金额' : '金额',
                value: Money.format(amountMilli),
                unit: '元',
                highlight: true,
              ),
            ],
          ),
          // 有未计价的记录时必须说清楚，否则「金额」会被当成总工钱
          if (unpricedCount > 0) ...<Widget>[
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Icon(Icons.info_outline,
                    size: 12, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '另有 $unpricedCount 条（共 $unpricedQuantity $baseUnit）'
                    '没填单价，金额没算进去',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: scheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.label,
    required this.value,
    required this.unit,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String unit;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          RichText(
            text: TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: highlight ? 17 : 16,
                    fontWeight: FontWeight.w700,
                    color: highlight ? scheme.primary : scheme.onSurface,
                    height: 1.15,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 26, color: color);
}
