import 'package:flutter/material.dart';

/// Material 3 主题配置。
///
/// 刻意**不设置** `cardTheme` / `tabBarTheme` / `dialogTheme`：
/// 这几个字段在 Flutter 3.27 之后类型由 `XxxTheme` 改成了 `XxxThemeData`，
/// 写死任何一个都会在另一侧的 SDK 上编译失败。组件样式全部在使用处直接给，
/// 保证 Flutter 3.19 ~ 4.x 全区间可编译。
class AppTheme {
  AppTheme._();

  /// 品牌主色（靛蓝，长时间看数字不刺眼）
  static const Color seed = Color(0xFF2E6BFF);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? const Color(0xFF111318) : const Color(0xFFF6F7FB),
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: isDark ? const Color(0xFF111318) : const Color(0xFFF6F7FB),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: isDark ? const Color(0xFF1B1E24) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withAlpha(120),
        thickness: 1,
        space: 1,
      ),
    );
  }
}

/// 统一的卡片外观：圆角 + 极轻描边，不使用 elevation 阴影（更“简约”）。
BoxDecoration cardDecoration(BuildContext context, {Color? color}) {
  final scheme = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: color ??
        (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1B1E24)
            : Colors.white),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: scheme.outlineVariant.withAlpha(140), width: 1),
  );
}

/// 小号标签（型号 / 颜色 / 码数 用的胶囊）
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.color,
    this.dense = false,
    this.icon,
  });

  final String label;
  final Color? color;
  final bool dense;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = color ?? scheme.primary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: base.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 10 : 12, color: base),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: dense ? 11 : 12,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: base,
            ),
          ),
        ],
      ),
    );
  }
}
