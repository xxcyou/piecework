import 'dart:ui' show FontFeature;

import 'package:intl/intl.dart';

/// 金额计算工具。
///
/// **财务级要求：绝不能用 double 直接累加金额。**
/// 0.1 + 0.2 = 0.30000000000000004，一千条记录累加下来能差出几毛钱，对账时说不清。
///
/// 所以：**内部最小单位是「厘」（1/1000 元）**，所有运算在 int 域完成。
///
/// 为什么不是「分」：裁片、辅料这类单价可能低到 0.001 元，
/// 按分算 `(0.001 * 100).round() = 0`，直接把钱抹没了。
/// 用厘：`(0.001 * 1000).round() = 1`，1000 件正好 1.00 元。
///
/// 显示时自适应：有厘位就出 3 位小数（0.001），否则 2 位（12.35）。
class Money {
  Money._();

  static final NumberFormat _g2 = NumberFormat('#,##0.00');
  static final NumberFormat _g3 = NumberFormat('#,##0.000');
  static final NumberFormat _p2 = NumberFormat('0.00');
  static final NumberFormat _p3 = NumberFormat('0.000');

  /// 元 → 厘（四舍五入到 0.001 元）
  static int toMilli(num yuan) => (yuan * 1000).round();

  /// 厘 → 元
  static double toYuan(int milli) => milli / 1000;

  /// 数量 × 单价(元) → 小计(厘)
  static int multiply(int quantity, num unitPriceYuan) =>
      quantity * toMilli(unitPriceYuan);

  /// 是否有厘位（决定显示 2 位还是 3 位小数）
  static bool hasSubCent(int milli) => milli % 10 != 0;

  /// 带千分位：1,234.56 / 1,234.567
  static String format(int milli) => hasSubCent(milli)
      ? _g3.format(toYuan(milli))
      : _g2.format(toYuan(milli));

  /// 不带千分位（窄表格列用）
  static String plain(int milli) => hasSubCent(milli)
      ? _p3.format(toYuan(milli))
      : _p2.format(toYuan(milli));

  /// 带货币符号：¥1,234.56
  static String yuan(int milli) => '¥${format(milli)}';

  /// 校验用户输入的单价：最多三位小数、非负、可解析
  static double? parsePrice(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 0;
    final v = double.tryParse(t);
    if (v == null || v < 0) return null;
    // 超过三位小数直接判非法，避免「看着 0.0012、实际按 0.001 算」的对账纠纷
    final dot = t.indexOf('.');
    if (dot >= 0 && t.length - dot - 1 > 3) return null;
    return v;
  }
}

/// 等宽数字样式：表格里金额右对齐时，位数对齐才不会看着乱。
const List<FontFeature> tabularFigures = <FontFeature>[
  FontFeature.tabularFigures(),
];
