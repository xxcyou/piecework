import 'package:flutter/material.dart';

/// 时间区间工具（周一为一周起点，符合国内习惯）。
class DateUtil {
  DateUtil._();

  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  /// 本周一 00:00
  static DateTime startOfWeek(DateTime d) {
    final s = startOfDay(d);
    return s.subtract(Duration(days: s.weekday - 1));
  }

  static DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  static DateTime endOfMonth(DateTime d) =>
      DateTime(d.year, d.month + 1, 1).subtract(const Duration(milliseconds: 1));

  static DateTime yesterday(DateTime d) => startOfDay(d).subtract(const Duration(days: 1));

  /// 把 DateTimeRange 转成闭区间 [start, end]，end 自动扩到当天 23:59:59.999
  static DateTimeRange normalize(DateTimeRange r) => DateTimeRange(
        start: startOfDay(r.start),
        end: endOfDay(r.end),
      );

  /// 区间内天数（含首尾）
  static int daysIn(DateTimeRange r) =>
      startOfDay(r.end).difference(startOfDay(r.start)).inDays + 1;
}
