import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/models/piece_record.dart';
import '../../data/services/unit_converter.dart';
import '../../providers/records_providers.dart';
import '../../providers/units_providers.dart';

/// 单位换算自检：把「规则」和「每条记录怎么折算的」全摊开。
///
/// 数字对不上时，先来这里看一眼，比问 AI 靠谱。
class UnitDiagnosisPage extends ConsumerWidget {
  const UnitDiagnosisPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final cfg = ref.watch(unitsProvider).valueOrNull;
    final records =
        ref.watch(recordsProvider).valueOrNull ?? const <PieceRecord>[];

    if (cfg == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('换算自检')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final conv = cfg.converter;
    final sample = records.take(30).toList();
    final totalCenti =
        records.fold<int>(0, (s, r) => s + conv.centiBaseOf(r));
    final totalMilli =
        records.fold<int>(0, (s, r) => s + r.subtotalMilli);

    final buffer = StringBuffer()
      ..writeln('=== 单位 ===')
      ..writeln(cfg.units
          .map((u) => '${u.name}${u.isBase ? "(基准)" : ""}')
          .join('、'))
      ..writeln()
      ..writeln('=== 规则 ===');

    if (cfg.rules.isEmpty) {
      buffer.writeln('(无规则，全部按 1:1)');
    } else {
      for (final r in cfg.rules) {
        buffer.writeln(
          '${r.denominator} ${r.fromUnit} = ${r.numerator} ${r.toUnit}'
          '${r.styleModel.isEmpty ? "(全局)" : "(${r.styleModel})"}'
          '  → 1 ${r.fromUnit} = ${(r.numerator / r.denominator).toStringAsFixed(4)} ${r.toUnit}',
        );
      }
    }

    buffer
      ..writeln()
      ..writeln('=== 折算明细（前 30 条）===')
      ..writeln('型号 | 颜色 | 单位 | 数量 | 1单位= | 折算 | 金额');

    for (final r in sample) {
      final per = conv.centiBasePerUnit(
        r.unitOrBase,
        styleModel: r.styleModel,
      );
      buffer.writeln(
        '${r.styleModel} | ${r.color} | ${r.unitOrBase} | ${r.quantity} | '
        '${(per / 100).toStringAsFixed(4)} | '
        '${(r.quantity * per / 100).toStringAsFixed(2)} | '
        '${Money.plain(r.subtotalMilli)}',
      );
    }

    buffer
      ..writeln()
      ..writeln('=== 合计 ===')
      ..writeln('记录 ${records.length} 条')
      ..writeln('原始数量之和 ${records.fold<int>(0, (s, r) => s + r.quantity)}')
      ..writeln('折算后 ${UnitConverter.formatCenti(totalCenti)} ${cfg.baseUnit}')
      ..writeln('金额 ${Money.format(totalMilli)} 元');

    final report = buffer.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('换算自检'),
        actions: <Widget>[
          IconButton(
            tooltip: '复制报告',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: report));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('报告已复制，可直接粘贴发给我')),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
        children: <Widget>[
          _card(
            scheme,
            title: '单位',
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: cfg.units
                  .map((u) => Chip(
                        label: Text(
                          '${u.name}${u.isBase ? " · 基准" : ""}',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: u.isBase
                            ? scheme.primary.withAlpha(24)
                            : null,
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 10),
          _card(
            scheme,
            title: '换算规则',
            child: cfg.rules.isEmpty
                ? Text(
                    '没有任何规则 —— 所有单位按 1:1 折算',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: cfg.rules
                        .map((r) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '${r.denominator} ${r.fromUnit} = '
                                '${r.numerator} ${r.toUnit}'
                                '${r.styleModel.isEmpty ? "" : "（${r.styleModel}）"}'
                                '\n   → 1 ${r.fromUnit} = '
                                '${(r.numerator / r.denominator).toStringAsFixed(4)} ${r.toUnit}',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.5,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 10),
          _card(
            scheme,
            title: '合计',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '记录 ${records.length} 条 · '
                  '原始和 ${records.fold<int>(0, (s, r) => s + r.quantity)}'
                  '（混单位时无意义）',
                  style: TextStyle(
                      fontSize: 11, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  '折算后 ${UnitConverter.formatCenti(totalCenti)} ${cfg.baseUnit}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '金额 ${Money.format(totalMilli)} 元',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _card(
            scheme,
            title: '折算明细（前 30 条）',
            child: records.isEmpty
                ? Text('没有记录',
                    style: TextStyle(
                        fontSize: 11, color: scheme.onSurfaceVariant))
                : Column(
                    children: <Widget>[
                      for (final r in sample)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                flex: 3,
                                child: Text(
                                  '${r.styleModel} ${r.color} ${r.size}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10.5),
                                ),
                              ),
                              SizedBox(
                                width: 62,
                                child: Text(
                                  '${r.quantity}${r.unitOrBase}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontFeatures: tabularFigures,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 56,
                                child: Text(
                                  '×${(conv.centiBasePerUnit(r.unitOrBase, styleModel: r.styleModel) / 100).toStringAsFixed(2)}',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: scheme.onSurfaceVariant,
                                    fontFeatures: tabularFigures,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 58,
                                child: Text(
                                  (r.quantity *
                                          conv.centiBasePerUnit(
                                              r.unitOrBase,
                                              styleModel: r.styleModel) /
                                          100)
                                      .toStringAsFixed(1),
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.primary,
                                    fontFeatures: tabularFigures,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _card(ColorScheme scheme, {required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      decoration: BoxDecoration(
        color: scheme.brightness == Brightness.dark
            ? const Color(0xFF1B1E24)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withAlpha(130)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
