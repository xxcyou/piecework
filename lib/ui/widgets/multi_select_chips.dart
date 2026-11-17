import 'package:flutter/material.dart';

/// 一组可多选的胶囊按钮（型号 / 颜色 / 码数筛选用）
class MultiSelectChips extends StatelessWidget {
  const MultiSelectChips({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.onClear,
    this.emptyHint = '暂无选项',
  });

  final String title;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final VoidCallback? onClear;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            if (selected.isNotEmpty) ...<Widget>[
              const SizedBox(width: 6),
              Text(
                '已选 ${selected.length}',
                style: TextStyle(fontSize: 11.5, color: scheme.primary),
              ),
              const Spacer(),
              if (onClear != null)
                TextButton(
                  onPressed: onClear,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 30),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('清空', style: TextStyle(fontSize: 12)),
                ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        if (options.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              emptyHint,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          )
        else
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: options.map((o) {
              final isOn = selected.contains(o);
              return FilterChip(
                label: Text(o, style: const TextStyle(fontSize: 12.5)),
                selected: isOn,
                onSelected: (_) => onToggle(o),
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                side: BorderSide(
                  color: isOn ? scheme.primary : scheme.outlineVariant,
                ),
                backgroundColor: Colors.transparent,
                selectedColor: scheme.primary.withAlpha(28),
                labelStyle: TextStyle(
                  color: isOn ? scheme.primary : scheme.onSurface,
                  fontWeight: isOn ? FontWeight.w600 : FontWeight.w400,
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
