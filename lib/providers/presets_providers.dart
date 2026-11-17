import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../data/models/filter_preset.dart';
import '../data/models/record_filter.dart';
import 'db_providers.dart';

/// 筛选预设
class PresetsNotifier extends AsyncNotifier<List<FilterPreset>> {
  @override
  Future<List<FilterPreset>> build() {
    return ref.watch(presetRepoProvider).all();
  }

  Future<void> save(String name, RecordFilter filter) async {
    await ref.read(presetRepoProvider).save(name, encode(filter));
    state = AsyncData(await ref.read(presetRepoProvider).all());
  }

  Future<void> remove(Id id) async {
    await ref.read(presetRepoProvider).remove(id);
    state = AsyncData(await ref.read(presetRepoProvider).all());
  }

  /// RecordFilter → 存库字符串
  static String encode(RecordFilter f) =>
      jsonEncode(<String, dynamic>{'filter': f.toJson()});

  /// 存库字符串 → RecordFilter（解析失败返回 null，不抛异常）
  static RecordFilter? decode(FilterPreset preset) {
    try {
      final obj = jsonDecode(preset.payload);
      if (obj is Map && obj['filter'] is Map) {
        return RecordFilter.fromJson(
          (obj['filter'] as Map).map((k, v) => MapEntry(k.toString(), v)),
        );
      }
      if (obj is Map) {
        return RecordFilter.fromJson(
          obj.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
    } catch (_) {
      // 旧版本 / 手工改坏的 JSON：直接忽略
    }
    return null;
  }
}

final presetsProvider =
    AsyncNotifierProvider<PresetsNotifier, List<FilterPreset>>(
  PresetsNotifier.new,
);
