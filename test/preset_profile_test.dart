import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/data/models/filter_preset.dart';
import 'package:piecework/data/repositories/preset_repository.dart';

/// 筛选预设按身份隔离
void main() {
  FilterPreset p(int id, int profileId, String name) => FilterPreset()
    ..id = id
    ..profileId = profileId
    ..name = name
    ..payload = '{}'
    ..createdAt = DateTime(2026, 11, 25);

  final all = <FilterPreset>[
    p(1, 1, '我的：本周黑色'),
    p(2, 7, '张三：只看 A1023'),
    p(3, 0, '老预设（未打标）'),
  ];

  test('身份 1 只看到自己的预设', () {
    final got = filterPresetsForProfile(all, 1, activeIsDefault: false);
    expect(got.map((e) => e.name), <String>['我的：本周黑色']);
  });

  test('身份 7 只看到自己的预设', () {
    final got = filterPresetsForProfile(all, 7, activeIsDefault: false);
    expect(got.map((e) => e.name), <String>['张三：只看 A1023']);
  });

  test('默认身份能看到未打标的老预设', () {
    final got = filterPresetsForProfile(all, 1, activeIsDefault: true);
    expect(got.length, 2);
    expect(got.map((e) => e.name), contains('老预设（未打标）'));
  });

  test('非默认身份看不到老预设（不混环境）', () {
    final got = filterPresetsForProfile(all, 7, activeIsDefault: false);
    expect(got.any((e) => e.name == '老预设（未打标）'), isFalse);
  });

  test('未初始化身份时不过滤', () {
    expect(filterPresetsForProfile(all, 0, activeIsDefault: false).length, 3);
  });

  test('空列表不炸', () {
    expect(
      filterPresetsForProfile(const <FilterPreset>[], 7, activeIsDefault: false),
      isEmpty,
    );
  });
}
