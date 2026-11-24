import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models/piece_record.dart';
import '../../data/services/unit_converter.dart';
import 'color_chip.dart';
import 'photo_thumb.dart';

/// 单条记录卡片。
///
/// 信息层级：型号（最大）→ 颜色/码数胶囊 → 数量×单价 → 时间/备注 → 右侧小计金额。
/// 这样扫一眼就能对上这批货，不用点进去。
class RecordCard extends StatelessWidget {
  const RecordCard({
    super.key,
    required this.record,
    this.selectionMode = false,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.onMore,
    this.converter = UnitConverter.identity,
    this.extraTag,
    this.extraTagColor,
  });

  final PieceRecord record;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMore;

  /// 由列表统一传入，避免每张卡都去 watch provider（长列表滚动会反复订阅）
  final UnitConverter converter;

  /// 操作快照视图里的标签：「已删除」「新建」「已修改」
  final String? extraTag;
  final Color? extraTagColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unit = record.unitOrBase;
    final needsConvert = unit != converter.baseUnit;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(11),
          decoration: cardDecoration(context).copyWith(
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : scheme.outlineVariant.withAlpha(140),
              width: selected ? 1.6 : 1,
            ),
            color: selected
                ? scheme.primary.withAlpha(12)
                : (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1B1E24)
                    : Colors.white),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (selectionMode) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 14, right: 2),
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    size: 21,
                    color: selected ? scheme.primary : scheme.outline,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              PhotoThumb(name: record.photoName, size: 62),
              const SizedBox(width: 11),
              Expanded(
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
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // 没填单价就显示「未计价」，不要甩一个 ¥0.00 让人以为白干
                        Text(
                          record.hasPrice
                              ? Money.yuan(record.subtotalMilli)
                              : '未计价',
                          style: TextStyle(
                            fontSize: record.hasPrice ? 15 : 12,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: record.hasPrice
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: <Widget>[
                        // 操作快照标签放最前，一眼看出这条是什么状态
                        if (extraTag != null && extraTag!.isNotEmpty)
                          TagChip(
                            label: extraTag!,
                            dense: true,
                            color: extraTagColor ?? scheme.error,
                            icon: extraTag == '已删除'
                                ? Icons.delete_outline
                                : (extraTag == '新建'
                                    ? Icons.add_circle_outline
                                    : Icons.edit_outlined),
                          ),
                        if (record.color.isNotEmpty)
                          ColorChip(name: record.color, size: 10)
                        else
                          TagChip(
                            label: '缺颜色',
                            dense: true,
                            color: scheme.outline,
                          ),
                        if (record.size.isNotEmpty)
                          TagChip(
                            label: record.size,
                            dense: true,
                            color: scheme.tertiary,
                          ),
                        // 忘记拍照的记录标出来，方便回头补拍
                        if (record.photoName.isEmpty)
                          TagChip(
                            label: '无图',
                            dense: true,
                            color: scheme.outline,
                            icon: Icons.image_not_supported_outlined,
                          ),
                        // 已结算的打个灰标，一眼能区分
                        if (record.isReported)
                          TagChip(
                            label: '已结算',
                            dense: true,
                            color: const Color(0xFF0E9F6E),
                            icon: Icons.check_circle_outline,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Text(
                          record.hasPrice
                              ? '${record.quantity} $unit × ¥${Money.plain(Money.toMilli(record.unitPrice))}'
                              : '${record.quantity} $unit · 未填单价',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: scheme.onSurfaceVariant,
                            height: 1.2,
                            fontFeatures: tabularFigures,
                          ),
                        ),
                        // 单位不是基准单位时，把折算值摆出来，一眼能对上这批货
                        if (needsConvert) ...<Widget>[
                          const SizedBox(width: 6),
                          Text(
                            '≈ ${UnitConverter.formatCenti(converter.centiBaseOf(record))} ${converter.baseUnit}',
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.primary.withAlpha(200),
                              height: 1.2,
                              fontFeatures: tabularFigures,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      record.note.isEmpty
                          ? Fmt.dateTime(record.createdAt)
                          : '${Fmt.dateTime(record.createdAt)} · ${record.note}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant.withAlpha(190),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (!selectionMode && onMore != null)
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: InkResponse(
                    onTap: onMore,
                    radius: 20,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.more_vert,
                        size: 18,
                        color: scheme.onSurfaceVariant.withAlpha(170),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
