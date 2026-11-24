import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/core/color_names.dart';

/// 颜色名解析要「尽量都认出来」，不能因为写法奇怪就没色块
void main() {
  bool known(String n) => isKnownColorName(n);

  group('常见写法都能出颜色', () {
    test('精确 / 别名', () {
      expect(known('黑色'), isTrue);
      expect(known('黑'), isTrue);
      expect(known('BLACK'), isTrue);
      expect(known('navy'), isTrue);
    });

    test('包含匹配（长键优先）', () {
      expect(known('深藏青'), isTrue);
      expect(known('藏青蓝'), isTrue);
      // 「深灰」不能被「灰」抢走：深灰应比灰色暗
      final deep = colorOfName('深灰');
      final grey = colorOfName('灰色');
      expect(deep.computeLuminance(), lessThan(grey.computeLuminance()));
    });

    test('关键词拆解：黑灰 / 米黄色 / 酒红调', () {
      expect(known('黑灰色'), isTrue);
      expect(known('米黄色'), isTrue);
      expect(known('酒红色系'), isTrue);
    });

    test('深浅修饰会改亮度', () {
      final base = colorOfName('蓝色');
      final deep = colorOfName('深蓝色');
      final light = colorOfName('浅蓝色');
      expect(deep.computeLuminance(), lessThan(base.computeLuminance()));
      expect(light.computeLuminance(), greaterThan(base.computeLuminance()));
    });

    test('完全不认识的词也给稳定色（同词同色）', () {
      final a = colorOfName('乱七八糟色');
      final b = colorOfName('乱七八糟色');
      final d = colorOfName('另一个怪名字');
      expect(a, b);
      expect(a, isNot(d));
      expect(isKnownColorName('乱七八糟色'), isFalse);
      expect(hasSwatch('乱七八糟色'), isTrue);
    });

    test('空名字不画色块', () {
      expect(hasSwatch(''), isFalse);
      expect(hasSwatch('   '), isFalse);
    });
  });

  group('取色反推带深浅修饰', () {
    test('很暗的颜色会加「深」', () {
      final n = nameOfColor(const Color(0xFF0B0C0E));
      expect(n.startsWith('深') || n.contains('黑'), isTrue);
    });

    test('很亮的颜色会加「浅」', () {
      final n = nameOfColor(const Color(0xFFFDFDFD));
      expect(n.startsWith('浅') || n.contains('白'), isTrue);
    });
  });
}
