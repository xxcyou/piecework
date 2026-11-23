import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/core/color_names.dart';
import 'package:piecework/ui/widgets/color_chip.dart';

/// 颜色名 ⇄ 色值、取色反推、文字对比度
void main() {
  group('颜色名 → 色值', () {
    test('常见叫法都能命中', () {
      expect(colorOfName('黑色'), const Color(0xFF1C1F24));
      expect(colorOfName('藏青'), const Color(0xFF243A63));
      expect(hasSwatch('黑色'), isTrue);
      expect(hasSwatch('米白'), isTrue);
    });

    test('包含匹配：「深藏青」「黑灰色」', () {
      expect(hasSwatch('深藏青'), isTrue);
      expect(colorOfName('黑灰色'), const Color(0xFF1C1F24));
    });

    test('不认识的词不画色块', () {
      expect(hasSwatch('乱七八糟色'), isFalse);
      expect(hasSwatch(''), isFalse);
    });
  });

  group('文字对比度（不能白字白底）', () {
    test('浅色底 → 深色字', () {
      expect(onColor(const Color(0xFFFFFFFF)), const Color(0xFF1C1F24));
      expect(onColor(const Color(0xFFF7F8FA)), const Color(0xFF1C1F24));
      expect(onColor(const Color(0xFFF2C438)), const Color(0xFF1C1F24)); // 黄
    });

    test('深色底 → 白字', () {
      expect(onColor(const Color(0xFF1C1F24)), Colors.white);
      expect(onColor(const Color(0xFF243A63)), Colors.white); // 藏青
      expect(onColor(const Color(0xFF7B2C39)), Colors.white); // 酒红
    });
  });

  group('取色反推颜色名', () {
    test('纯黑 → 黑色系', () {
      final n = nameOfColor(const Color(0xFF141518));
      expect(n, anyOf('黑色', '深灰', '藏青', '咖啡', '酒红', '墨绿', '紫色'));
    });

    test('纯白 → 白/米白系', () {
      final n = nameOfColor(const Color(0xFFFAFAFA));
      expect(n, anyOf('白色', '米白'));
    });

    test('正红 → 红/酒红', () {
      final n = nameOfColor(const Color(0xFFD9343B));
      expect(n, anyOf('红色', '酒红', '玫红', '橙色'));
    });

    test('黄 → 黄/姜黄', () {
      final n = nameOfColor(const Color(0xFFF2C438));
      expect(n, anyOf('黄色', '姜黄', '杏色', '驼色'));
    });
  });

  group('色块组件', () {
    testWidgets('有对应颜色时画色块，文字用对比色', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: ColorChip(name: '黑色'))),
        ),
      );
      expect(find.text('黑色'), findsOneWidget);
      final text = tester.widget<Text>(find.text('黑色'));
      expect(text.style?.color, Colors.white);
    });

    testWidgets('不认识的词只显示文字', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: ColorChip(name: '神秘色'))),
        ),
      );
      expect(find.text('神秘色'), findsOneWidget);
    });
  });
}
