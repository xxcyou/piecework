// 颜色名解析：精确 → 包含 → 关键词拆解 + 深浅修饰 → 稳定哈希色
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 颜色名 ⇄ 色值。
///
/// 现实里颜色名千奇百怪：「深藏青」「藏青蓝」「黑灰」「米黄色」「BLACK」…
/// 只做精确匹配会大量落空（用户看到的就是「没有色块」）。
/// 这里分三层兜底：
///   1. 精确 / 包含匹配（最长优先，避免「深灰」被「灰」抢走）
///   2. 关键词拆解 + 深浅修饰（深/暗 变暗，浅/淡 变亮）
///   3. 仍然不认识 → 用名字哈希出一个**稳定**的颜色（同一个词永远同一色）
/// 这样任何名字都有色块，且不会前后不一致。
/// 基础色表（含口语叫法）。值按「正色」给，深浅由修饰词再调整。
const Map<String, Color> kColorPalette = <String, Color>{
  '黑色': Color(0xFF1C1F24),
  '白色': Color(0xFFF7F8FA),
  '米白': Color(0xFFEDE6D6),
  '米色': Color(0xFFE8DCC3),
  '杏色': Color(0xFFE8CBA8),
  '香槟': Color(0xFFE6D2AE),
  '银色': Color(0xFFC8CDD4),
  '灰色': Color(0xFF9AA0A8),
  '深灰': Color(0xFF5B6169),
  '浅灰': Color(0xFFC9CDD4),
  '藏青': Color(0xFF243A63),
  '牛仔蓝': Color(0xFF4A6D9B),
  '雾霾蓝': Color(0xFF8FA6BF),
  '蓝色': Color(0xFF2F6BFF),
  '浅蓝': Color(0xFF9CC4F5),
  '天蓝': Color(0xFF7EC0EE),
  '酒红': Color(0xFF7B2C39),
  '红色': Color(0xFFD9343B),
  '粉红': Color(0xFFF3A5BE),
  '玫红': Color(0xFFC2185B),
  '豆沙': Color(0xFFB08B87),
  '绿色': Color(0xFF2E9E5B),
  '墨绿': Color(0xFF1F4A38),
  '军绿': Color(0xFF5A6B3B),
  '橄榄绿': Color(0xFF6E7535),
  '黄色': Color(0xFFF2C438),
  '姜黄': Color(0xFFD9A32B),
  '橙色': Color(0xFFF08A24),
  '紫色': Color(0xFF7B4FA8),
  '咖啡': Color(0xFF6B4A34),
  '棕色': Color(0xFF6B4A34),
  '褐色': Color(0xFF5E4433),
  '卡其': Color(0xFFC3B091),
  '驼色': Color(0xFFB98E63),
};

/// 单字/简称 → 正色名（拆解用）
const Map<String, String> _aliases = <String, String>{
  '黑': '黑色',
  '白': '白色',
  '灰': '灰色',
  '红': '红色',
  '蓝': '蓝色',
  '绿': '绿色',
  '黄': '黄色',
  '紫': '紫色',
  '橙': '橙色',
  '橘': '橙色',
  '粉': '粉红',
  '棕': '棕色',
  '褐': '褐色',
  '咖': '咖啡',
  '米': '米色',
  '金': '姜黄',
  '银': '银色',
  '藏': '藏青',
  '墨': '墨绿',
  '军': '军绿',
  '杏': '杏色',
  '驼': '驼色',
  '卡其': '卡其',
  'navy': '藏青',
  'black': '黑色',
  'white': '白色',
  'grey': '灰色',
  'gray': '灰色',
  'red': '红色',
  'blue': '蓝色',
  'green': '绿色',
  'yellow': '黄色',
  'purple': '紫色',
  'orange': '橙色',
  'pink': '粉红',
  'brown': '棕色',
  'beige': '米色',
  'khaki': '卡其',
};

/// 繁体 / 常见错写 → 简体
const Map<String, String> _normalize = <String, String>{
  '藍': '蓝',
  '紅': '红',
  '綠': '绿',
  '黃': '黄',
  '銀': '银',
  '軍': '军',
  '墨綠': '墨绿',
  '橘': '橙',
  '啡': '咖啡',
};

String _clean(String name) {
  var s = name.trim().toLowerCase();
  s = s.replaceAll(RegExp(r'[\s\-_/、,，。.()（）]'), '');
  _normalize.forEach((k, v) => s = s.replaceAll(k, v));
  return s;
}

/// 名字里有没有「深/浅」这类修饰
({Color color, String base, bool derived}) _resolve(String raw) {
  final s = _clean(raw);
  if (s.isEmpty) {
    return (color: const Color(0xFFB9C0CC), base: '', derived: true);
  }

  // 1) 精确（含别名）
  for (final e in kColorPalette.entries) {
    if (_clean(e.key) == s) {
      return (color: e.value, base: e.key, derived: false);
    }
  }
  final alias = _aliases[s];
  if (alias != null && kColorPalette.containsKey(alias)) {
    return (color: kColorPalette[alias]!, base: alias, derived: false);
  }

  // 2) 包含匹配（长键优先：「深灰」先于「灰」）
  final keys = kColorPalette.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final k in keys) {
    if (s.contains(_clean(k))) {
      return (color: kColorPalette[k]!, base: k, derived: false);
    }
  }

  // 3) 关键词拆解：逐字找别名
  for (final e in _aliases.entries) {
    if (s.contains(e.key) && kColorPalette.containsKey(e.value)) {
      return (color: kColorPalette[e.value]!, base: e.value, derived: true);
    }
  }

  // 4) 兜底：稳定哈希色（同一个词永远同一色）
  return (color: _hashColor(s), base: '', derived: true);
}

/// 深浅修饰：深/暗/浓 → 变暗；浅/淡/亮 → 变亮
Color _applyTone(String name, Color base) {
  final s = _clean(name);
  final dark = s.contains('深') || s.contains('暗') || s.contains('浓');
  final light = s.contains('浅') || s.contains('淡') || s.contains('亮');
  if (dark) return _shift(base, -0.22);
  if (light) return _shift(base, 0.28);
  return base;
}

Color _shift(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  final l = (hsl.lightness + amount).clamp(0.06, 0.96);
  return hsl.withLightness(l).toColor();
}

/// 稳定哈希色：色相由字符串决定，饱和度/亮度固定在柔和区间
Color _hashColor(String s) {
  var h = 0;
  for (final unit in s.codeUnits) {
    h = (h * 31 + unit) & 0x7fffffff;
  }
  final hue = (h % 360).toDouble();
  return HSLColor.fromAHSL(1, hue, 0.45, 0.62).toColor();
}

/// 颜色名 → 色值。**任何非空名字都会返回一个颜色**（可能来自修饰/哈希）。
Color colorOfName(String name) {
  if (name.trim().isEmpty) return const Color(0xFFB9C0CC);
  final r = _resolve(name);
  return _applyTone(name, r.color);
}

/// 这个名字是不是「正经认识」的颜色（用于区分：认识→实心色块；猜的→虚线边）
bool isKnownColorName(String name) {
  if (name.trim().isEmpty) return false;
  return !_resolve(name).derived;
}

/// 兼容旧调用：现在任何非空名字都有色块
bool hasSwatch(String name) => name.trim().isNotEmpty;

/// 色块上的文字颜色：按亮度选黑/白，避免白字白底、黑字黑底
Color onColor(Color bg) {
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
    if (e.key.length == 1) continue;
    final d = _dist(c, e.value);
    if (d < bestD) {
      bestD = d;
      best = e.key;
    }
  }
  // 很暗 / 很亮时补上修饰词，更贴近人的叫法
  final hsl = HSLColor.fromColor(c);
  if (hsl.lightness < 0.18 && !best.startsWith('深')) return '深$best';
  if (hsl.lightness > 0.86 && !best.startsWith('浅')) return '浅$best';
  return best;
}

double _dist(Color a, Color b) {
  final dr = (a.r - b.r) * 255;
  final dg = (a.g - b.g) * 255;
  final db = (a.b - b.b) * 255;
  return dr * dr * 0.3 + dg * dg * 0.59 + db * db * 0.71;
}
