import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/providers/photo_library_providers.dart';

void main() {
  group('相册条目（复用已有图）', () {
    PhotoLibraryEntry e({String s = '', String c = '', String z = '', int refs = 1}) =>
        PhotoLibraryEntry(
          name: 'c1.jpg',
          styleModel: s,
          color: c,
          size: z,
          at: DateTime(2026, 11, 15),
          refs: refs,
          number: 12,
        );

    test('标签：型号 · 颜色 · 码数，空值自动省略', () {
      expect(e(s: 'A1023', c: '黑色', z: 'M').label, 'A1023 · 黑色 · M');
      expect(e(s: 'A1023', z: 'M').label, 'A1023 · M');
      expect(e(c: '黑色').label, '未填型号 · 黑色');
      expect(e().label, '未填型号');
    });

    test('引用数用于提示「多条记录共用一张图」', () {
      expect(e(refs: 3).refs, 3);
    });

    test('编号用于 AI 精确引用', () {
      expect(e().id, '#12');
    });
  });
}
