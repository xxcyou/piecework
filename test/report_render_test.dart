import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/core/theme.dart';
import 'package:piecework/data/models/piece_record.dart';
import 'package:piecework/data/models/record_filter.dart';
import 'package:piecework/data/models/unit_rule.dart';
import 'package:piecework/data/services/unit_converter.dart';
import 'package:piecework/providers/units_providers.dart';
import 'package:piecework/ui/widgets/report_document.dart';

PieceRecord rec({
  required String style,
  required String color,
  required String size,
  required int qty,
  required double price,
  required DateTime at,
  String unit = '件',
  String note = '',
}) {
  final r = PieceRecord();
  r.styleModel = style;
  r.color = color;
  r.size = size;
  r.unit = unit;
  r.quantity = qty;
  r.unitPrice = price;
  r.note = note;
  r.photoName = '';
  r.createdAt = at;
  return r;
}

UnitRule rule(String from, int num, int den, {String style = ''}) {
  final r = UnitRule();
  r.fromUnit = from;
  r.toUnit = '件';
  r.numerator = num;
  r.denominator = den;
  r.styleModel = style;
  r.createdAt = DateTime(2026);
  return r;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final converter = UnitConverter(
    baseUnit: '件',
    rules: <UnitRule>[
      rule('片', 30, 100, style: 'A1023'),
      rule('片', 50, 100),
    ],
  );

  final data = <PieceRecord>[
    // 11-13
    rec(style: 'A1023', color: '黑色', size: 'M', qty: 20, price: 12.50,
        at: DateTime(2026, 11, 13, 9, 15)),
    rec(style: 'A1023', color: '白色', size: 'L', qty: 30, price: 12.50,
        at: DateTime(2026, 11, 13, 10, 32)),
    rec(style: 'B2001', color: '藏青', size: 'XL', qty: 100, price: 0.01,
        unit: '片', at: DateTime(2026, 11, 13, 14, 8), note: '裁片'),
    // 11-12
    rec(style: 'B2001', color: '黑色', size: 'M', qty: 45, price: 8.00,
        at: DateTime(2026, 11, 12, 8, 40)),
    rec(style: 'C3002', color: '卡其', size: 'S', qty: 12, price: 33.30,
        at: DateTime(2026, 11, 12, 16, 5), note: '返工'),
    // 11-11
    rec(style: 'A1023', color: '黑色', size: 'M', qty: 60, price: 12.35,
        at: DateTime(2026, 11, 11, 11, 22)),
    rec(style: 'C3002', color: '米白', size: 'L', qty: 8, price: 33.30,
        at: DateTime(2026, 11, 11, 15, 48)),
  ];

  Future<void> render(WidgetTester tester, {
    required bool compact,
    required String outName,
    GroupField groupBy = GroupField.day,
  }) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          unitConverterProvider.overrideWithValue(converter),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: Scaffold(
            backgroundColor: Colors.grey,
            body: SingleChildScrollView(
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 400,
                  child: ReportDocument(
                    title: '计件明细报表',
                    subtitle: '示范数据 · 含混合单位',
                    records: data,
                    fontScale: 1.0,
                    compact: compact,
                    showPhoto: true,
                    generatedAt: DateTime(2026, 11, 13, 18, 50),
                    rangeText: '2026-11-11 ~ 2026-11-13',
                    groupBy: groupBy,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;

    // widget test 里 toImage 必须放进 runAsync，否则会等不到帧而挂起
    ui.Image? image;
    ByteData? bytes;
    await tester.runAsync(() async {
      image = await boundary.toImage(pixelRatio: 3.0);
      bytes = await image!.toByteData(format: ui.ImageByteFormat.png);
    });
    image?.dispose();

    final dir = Directory('build/preview');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    File('build/preview/$outName')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  testWidgets('渲染对外版报表', (tester) async {
    await render(tester, compact: false, outName: 'report_external.png');
  });

  testWidgets('渲染紧凑版报表', (tester) async {
    await render(tester, compact: true, outName: 'report_compact.png');
  });

  testWidgets('渲染按型号分组', (tester) async {
    await render(
      tester,
      compact: true,
      outName: 'report_by_style.png',
      groupBy: GroupField.styleModel,
    );
  });
}
