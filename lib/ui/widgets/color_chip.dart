import 'package:flutter/material.dart';

import '../../core/color_names.dart';

/// 颜色小色块 + 文字。色块用真实颜色，文字按亮度自动黑白，
/// 不会出现「白字白底看不见」。
class ColorChip extends StatelessWidget {
  const ColorChip({
    super.key,
    required this.name,
    this.size = 10,
    this.fontSize = 11,
    this.filled = true,
  });

  final String name;
  final double size;
  final double fontSize;

  /// true = 整颗胶囊用该颜色当底色（列表卡片用）
  /// false = 只有一个小圆点（表单里用）
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = name.trim().isEmpty ? '未填颜色' : name.trim();
    if (!hasSwatch(name)) {
      return Text(
        text,
        style: TextStyle(fontSize: fontSize, color: scheme.onSurfaceVariant),
      );
    }
    final c = colorOfName(name);
    final fg = onColor(c);

    if (!filled) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(color: scheme.outlineVariant.withAlpha(140)),
            ),
          ),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: fontSize)),
        ],
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: size * 0.55, vertical: 2),
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(size),
        border: Border.all(color: scheme.outlineVariant.withAlpha(120)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.25,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
