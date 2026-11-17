import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/core/theme.dart';
import 'package:piecework/data/models/option_item.dart';
import 'package:piecework/data/models/piece_record.dart';
import 'package:piecework/data/models/unit_rule.dart';
import 'package:piecework/data/services/unit_converter.dart';
import 'package:piecework/providers/options_providers.dart';
import 'package:piecework/providers/records_providers.dart';
import 'package:piecework/providers/units_providers.dart';
import 'package:piecework/data/models/app_setting.dart';
import 'package:piecework/data/services/photo_service.dart';
import 'package:piecework/providers/settings_providers.dart';
import 'package:piecework/ui/pages/records_page.dart';
import 'package:piecework/ui/pages/report_page.dart';

/// 生成「展示用截图」：注入假数据 → 渲染 → 存 PNG（docs/screenshots/）
///
/// 跑法：flutter test --update-goldens test/golden/screenshot_test.dart
/// 注意：中文必须加载真实字体，否则会全是方块（乱码）
Future<void> _loadCjkFont() async {
  const candidates = <String>[
    '/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf',
    '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    '/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc',
  ];
  for (final path in candidates) {
    final f = File(path);
    if (!f.existsSync()) continue;
    final bytes = await f.readAsBytes();
    // 同时注册成 Roboto（Material 默认）和 fallback，保证中文正常
    for (final family in <String>['Roboto', 'DroidSans']) {
      final loader = FontLoader(family)
        ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
      await loader.load();
    }
    return;
  }
  throw StateError('找不到中文字体，截图会出现方块');
}

PieceRecord _rec({
  required String style,
  required String color,
  required String size,
  required int qty,
  required double price,
  required DateTime at,
  String unit = '件',
}) {
  final r = PieceRecord();
  r.styleModel = style;
  r.color = color;
  r.size = size;
  r.unit = unit;
  r.quantity = qty;
  r.unitPrice = price;
  r.note = '';
  r.photoName = '';
  r.createdAt = at;
  return r;
}

/// 一组像真实工人记的数据（型号/颜色/码数/数量/单价都有，也有几条没填单价）
List<PieceRecord> _fakeRecords() {
  final now = DateTime(2026, 11, 17, 18, 30);
  return <PieceRecord>[
    _rec(style: 'A1023', color: '黑色', size: 'M', qty: 300, price: 0.45, at: now)
      ..photoName = 'c_fake0.jpg',
    _rec(style: 'A1023', color: '黑色', size: 'L', qty: 240, price: 0.45, at: now.subtract(const Duration(hours: 2))),
    _rec(style: 'B2087', color: '米白', size: 'S', qty: 180, price: 0.62, at: now.subtract(const Duration(hours: 5)))
      ..photoName = 'c_fake1.jpg',
    _rec(style: 'B2087', color: '藏青', size: 'M', qty: 420, price: 0.58, at: now.subtract(const Duration(days: 1, hours: 1)))
      ..photoName = 'c_fake2.jpg',
    _rec(style: 'C3311', color: '灰色', size: 'XL', qty: 96, price: 0.72, at: now.subtract(const Duration(days: 1, hours: 6)))
      ..photoName = 'c_fake4.jpg',
    _rec(style: 'A1023', color: '白色', size: 'M', qty: 150, price: 0.45, at: now.subtract(const Duration(days: 2)))
      ..photoName = 'c_fake5.jpg',
    _rec(style: 'D5590', color: '酒红', size: 'L', qty: 260, price: 0.5, at: now.subtract(const Duration(days: 2, hours: 4)))
      ..photoName = 'c_fake3.jpg',
    // 只记数量（真实用户常见）
    _rec(style: 'E7712', color: '', size: '', qty: 340, price: 0, at: now.subtract(const Duration(days: 3))),
    _rec(style: 'B2087', color: '米白', size: 'M', qty: 210, price: 0.62, at: now.subtract(const Duration(days: 3, hours: 5))),
    _rec(style: 'C3311', color: '黑色', size: 'S', qty: 500, price: 0.4, at: now.subtract(const Duration(days: 4))),
  ];
}

UnitConverter _converter() {
  final rule = UnitRule()
    ..fromUnit = '片'
    ..toUnit = '件'
    ..numerator = 1
    ..denominator = 2
    ..styleModel = ''
    ..createdAt = DateTime(2026);
  return UnitConverter(baseUnit: '件', rules: <UnitRule>[rule]);
}

class _SettingsStub extends SettingsNotifier {
  @override
  Future<AppSetting> build() async => AppSetting();
}

/// 模拟真实首页外壳：底部 4 个标签 + 录入按钮
class _HomePreview extends StatelessWidget {
  const _HomePreview({required this.child, required this.index});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: child,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add, size: 22),
        label: const Text('记一笔'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        height: 64,
        indicatorColor: scheme.primary.withAlpha(30),
        onDestinationSelected: (_) {},
        destinations: const <Widget>[
          NavigationDestination(
              icon: Icon(Icons.list_alt_outlined), label: '记录'),
          NavigationDestination(
              icon: Icon(Icons.insights_outlined), label: '报表'),
          NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined), label: 'AI'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined), label: '设置'),
        ],
      ),
    );
  }
}

class _OptionsStub extends OptionsNotifier {
  @override
  Future<Map<OptionKind, List<String>>> build() async => <OptionKind, List<String>>{
        OptionKind.styleModel: <String>['A1023', 'B2087', 'C3311', 'D5590', 'E7712'],
        OptionKind.color: <String>['黑色', '白色', '米白', '藏青', '灰色', '酒红'],
        OptionKind.size: <String>['S', 'M', 'L', 'XL'],
      };
}

void main() {
  setUpAll(() async {
    await _loadCjkFont();
  });

  setUp(() {
    // 让 PhotoService 指向假图片目录（截图里才有缩略图）
    PhotoService.instance.prime(Directory('test/golden/fixtures'));
  });

  Future<void> shot(
    WidgetTester tester,
    String name,
    Widget home, {
    Size size = const Size(1080, 2340),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          recordsProvider.overrideWith(
            (ref) => Stream<List<PieceRecord>>.value(_fakeRecords()),
          ),
          unitConverterProvider.overrideWithValue(_converter()),
          optionsProvider.overrideWith(() => _OptionsStub()),
          settingsProvider.overrideWith(() => _SettingsStub()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          locale: const Locale('zh', 'CN'),
          home: home,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../docs/screenshots/$name.png'),
    );
  }

  testWidgets('首页 · 记录列表', (tester) async {
    await shot(
      tester,
      'home_records',
      const _HomePreview(index: 0, child: RecordsPage()),
    );
  });

  testWidgets('报表', (tester) async {
    await shot(
      tester,
      'report',
      const _HomePreview(index: 1, child: ReportPage()),
    );
  });
}
