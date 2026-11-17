import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';

import '../../core/format.dart';
import '../../core/money.dart';
import '../models/piece_record.dart';

/// CSV 导出（Excel / WPS / Numbers 直接可开）
class CsvService {
  CsvService._();

  static String build(List<PieceRecord> records) {
    final rows = <List<String>>[
      <String>[
        '录入时间', '款式型号', '颜色', '码数', '单位', '数量',
        '单件单价', '小计金额', '状态', '备注', '照片文件名',
      ],
    ];

    var totalQty = 0;
    var totalAmountMilli = 0;
    for (final r in records) {
      totalQty += r.quantity;
      totalAmountMilli += r.subtotalMilli;
      rows.add(<String>[
        Fmt.dateTime(r.createdAt),
        r.styleModel,
        r.color,
        r.size,
        r.unitOrBase,
        r.quantity.toString(),
        Money.plain(Money.toMilli(r.unitPrice)),
        Money.plain(r.subtotalMilli),
        r.status.label,
        r.note,
        r.photoName,
      ]);
    }

    rows.add(<String>['合计', '', '', '', '', totalQty.toString(), '',
      Money.plain(totalAmountMilli), '共 ${records.length} 条记录', '', '']);

    // 按日期汇总区块：Excel 打开就能直接核对每天做了多少、多少钱
    rows.add(<String>[]);
    rows.add(<String>['按日期汇总']);
    rows.add(<String>['日期', '记录数', '件数', '金额']);

    final byDay = <String, List<PieceRecord>>{};
    for (final r in records) {
      (byDay[Fmt.date(r.createdAt)] ??= <PieceRecord>[]).add(r);
    }
    final days = byDay.keys.toList()..sort();
    for (final d in days) {
      final list = byDay[d]!;
      final qty = list.fold(0, (s, r) => s + r.quantity);
      final cents = list.fold(0, (s, r) => s + r.subtotalMilli);
      rows.add(<String>[d, '${list.length}', '$qty', Money.plain(cents)]);
    }

    final csv = const ListToCsvConverter().convert(rows);

    // 前置 BOM：不加的话 Excel 打开中文会乱码
    return '\uFEFF$csv';
  }

  static Uint8List buildBytes(List<PieceRecord> records) =>
      Uint8List.fromList(utf8.encode(build(records)));

  static String defaultFileName() => '计件明细_${Fmt.stamp(DateTime.now())}.csv';
}
