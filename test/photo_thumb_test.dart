import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/data/services/photo_service.dart';
import 'package:piecework/ui/widgets/photo_thumb.dart';

/// 图库大图曾经是「灰白一片」：PhotoThumb 传了 size: double.infinity，
/// 里面 (size * 3).round() 直接抛异常。这组测试守住两种尺寸都能渲染。
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('thumb_');
    PhotoService.instance.prime(tmp);
    // 1x1 透明 PNG
    final png = Uint8List.fromList(<int>[
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ]);
    final dir = Directory('${tmp.path}/${PhotoService.recordsDir}');
    await dir.create(recursive: true);
    await File('${dir.path}/c_test.png').writeAsBytes(png);
  });

  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  testWidgets('有限尺寸正常渲染图片', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: PhotoThumb(name: 'c_test.png', size: 64))),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('无限尺寸（图库大图）也不能抛异常', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: const PhotoThumb(name: 'c_test.png', size: double.infinity),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
    final size = tester.getSize(find.byType(Image));
    expect(size.width, greaterThan(100));
    expect(size.height, greaterThan(100));
  });

  testWidgets('文件不存在时不崩（占位或空图都行，不能抛布局异常）', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: PhotoThumb(name: 'missing.png', size: 64)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(PhotoThumb), findsOneWidget);
    // 图片解码失败的报错是预期的（会走 errorBuilder），这里只关心组件树没崩
    tester.takeException();
  });
}
