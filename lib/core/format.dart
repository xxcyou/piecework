import 'package:intl/intl.dart';

/// 全项目统一的格式化工具。
class Fmt {
  Fmt._();

  static final DateFormat _dateTime = DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat _date = DateFormat('yyyy-MM-dd');
  static final DateFormat _time = DateFormat('HH:mm');
  static final DateFormat _monthDay = DateFormat('MM-dd');
  static final DateFormat _stamp = DateFormat('yyyyMMdd_HHmmss');
  static final NumberFormat _money = NumberFormat('#,##0.00');
  static final NumberFormat _int = NumberFormat('#,##0');

  static String dateTime(DateTime d) => _dateTime.format(d);
  static String date(DateTime d) => _date.format(d);
  static String time(DateTime d) => _time.format(d);
  static String monthDay(DateTime d) => _monthDay.format(d);
  static String stamp(DateTime d) => _stamp.format(d);

  /// 金额：两位小数 + 千分位
  static String money(num v) => _money.format(v);

  /// 金额：两位小数，不带千分位（报表窄列用）
  static String moneyPlain(num v) => v.toStringAsFixed(2);

  /// 整数千分位
  static String count(num v) => _int.format(v);

  static const List<String> _weekdays = <String>[
    '周一', '周二', '周三', '周四', '周五', '周六', '周日',
  ];

  /// 星期几（周一为一周起点）
  static String weekday(DateTime d) => _weekdays[d.weekday - 1];

  /// 相对时间：刚刚 / 3 分钟前 / 今天 14:22 / 昨天 09:10 / 11-08 14:22
  static String relative(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final dayGap = today.difference(that).inDays;
    if (dayGap == 0) return '今天 ${_time.format(d)}';
    if (dayGap == 1) return '昨天 ${_time.format(d)}';
    if (dayGap < 7) return '$dayGap 天前';
    if (d.year == now.year) return _monthDay.format(d);
    return _date.format(d);
  }
}
