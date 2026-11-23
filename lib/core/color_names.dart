import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 颜色名 ⇄ 色值：给「黑色 / 米白 / 藏青」这类中文颜色名配上色块，
/// 并从货物实拍里取色反推颜色名。
///
/// 为什么需要：列表里只写「黑色」看不出是哪块料；色块 + 对比度处理
/// 能让一眼分辨，同时避免白字白底看不清。

/// 常用颜色词（含口语叫法）→ 色值。顺序即「就近匹配」的候选池。
const Map<String, Color> kColorPalette = <String, Color>{
  '黑色': Color(0xFF1C1F24),
  '黑': Color(0xFF1C1F24),
  '白色': Color(0xFFF7F8FA),
  '白': Color(0xFFF7F8FA),
  '米白': Color(0xFFEDE6D6),
  '米色': Color(0xFFE8DCC3),
  '杏色': Color(0xFFE8CBA8),
  '灰色': Color(0xFF9AA0A8),
  '灰': Color(0xFF9AA0A8),
  '深灰': Color(0xFF5B6169),
  '浅灰': Color(0xFFC9CDD4),
  '藏青': Color(0xFF243A63),
  '藏蓝': Color(0xFF243A63),
  'navy': Color(0xFF243A63),
  '蓝色': Color(0xFF2F6BFF),
  '蓝': Color(0xFF2F6BFF),
  '浅蓝': Color(0xFF9CC4F5),
  '天蓝': Color(0xFF7EC0EE),
  '酒红': Color(0xFF7B2C39),
  '酒红色': Color(0xFF7B2C39),
  '红色': Color(0xFFD9343B),
  '红': Color(0xFFD9343B),
  '粉红': Color(0xFFF3A5BE),
  '粉色': Color(0xFFF3A5BE),
  '玫红': Color(0xFFC2185B),
  '绿色': Color(0xFF2E9E5B),
  '绿': Color(0xFF2E9E5B),
  '墨绿': Color(0xFF1F4A38),
  '军绿': Color(0xFF5A6B3B),
  '黄色': Color(0xFFF2C438),
  '黄': Color(0xFFF2C438),
  '姜黄': Color(0xFFD9A32B),
  '橙色': Color(0xFFF08A24),
  '橙': Color(0xFFF08A24),
  '紫色': Color(0xFF7B4FA8),
  '紫': Color(0xFF7B4FA8),
  '咖啡': Color(0xFF6B4A34),
  '棕色': Color(0xFF6B4A34),
  '卡其': Color(0xFFC3B091),
  '驼色': Color(0xFFB98E63),
};

/// 颜色名 → 色值（找不到就返回中性灰，由 UI 决定是否隐藏色块）
Color colorOfName(String name) {
  final n = name.trim().toLowerCase();
  if (n.isEmpty) return const Color(0xFFB9C0CC);
  // 精确匹配
  for (final e in kColorPalette.entries) {
    if (e.key.toLowerCase() == n) return e.value;
  }
  // 包含匹配（「深藏青」「黑灰色」这类写法）
  for (final e in kColorPalette.entries) {
    if (n.contains(e.key.toLowerCase())) return e.value;
  }
  return const Color(0xFFB9C0CC);
}

/// 这个颜色名有没有对应色块（没有就不画色块，只显示文字）
bool hasSwatch(String name) {
  final n = name.trim().toLowerCase();
  if (n.isEmpty) return false;
  for (final e in kColorPalette.entries) {
    if (e.key.toLowerCase() == n || n.contains(e.key.toLowerCase())) {
      return true;
    }
  }
  return false;
}

/// 色块上的文字颜色：按亮度选黑/白，避免白字白底、黑字黑底
Color onColor(Color bg) {
  // 相对亮度（sRGB 近似，够用）
  final l = 0.2126 * _lin(bg.r) + 0.7152 * _lin(bg.g) + 0.0722 * _lin(bg.b);
  return l > 0.55 ? const Color(0xFF1C1F24) : Colors.white;
}

double _lin(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

/// 从 RGB 反推最接近的中文颜色名（取色针用）
String nameOfColor(Color c) {
  var best = '灰色';
  var bestD = double.infinity;
  for (final e in kColorPalette.entries) {
    // 「黑」「白」这种单字只作为别名，不作为首选名
    if (e.key.length == 1) continue;
    final d = _dist(c, e.value);
    if (d < bestD) {
      bestD = d;
      best = e.key;
    }
  }
  return best;
}

double _dist(Color a, Color b) {
  final dr = (a.r - b.r) * 255;
  final dg = (a.g - b.g) * 255;
  final db = (a.b - b.b) * 255;
  return dr * dr * 0.3 + dg * dg * 0.59 + db * db * 0.11;
}
