import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/option_item.dart';
import 'db_providers.dart';

/// 型号 / 颜色 / 码数 的维护列表
class OptionsNotifier extends AsyncNotifier<Map<OptionKind, List<String>>> {
  @override
  Future<Map<OptionKind, List<String>>> build() {
    return ref.watch(optionRepoProvider).allGrouped();
  }

  Future<void> _refresh() async {
    state = AsyncData(await ref.read(optionRepoProvider).allGrouped());
  }

  Future<bool> add(OptionKind kind, String value) async {
    final ok = await ref.read(optionRepoProvider).add(kind, value);
    if (ok) await _refresh();
    return ok;
  }

  Future<void> remove(OptionKind kind, String value) async {
    await ref.read(optionRepoProvider).remove(kind, value);
    await _refresh();
  }

  /// 录入时输入了列表里没有的新值 → 静默补录，下次就能联想出来
  Future<void> ensureValue(OptionKind kind, String value) async {
    final v = value.trim();
    if (v.isEmpty) return;
    final current = state.valueOrNull?[kind] ?? const <String>[];
    if (current.contains(v)) return;
    await add(kind, v);
  }
}

final optionsProvider =
    AsyncNotifierProvider<OptionsNotifier, Map<OptionKind, List<String>>>(
  OptionsNotifier.new,
);

/// 某一类选项的便捷读取（同步）
final optionsForProvider = Provider.family<List<String>, OptionKind>((ref, kind) {
  final map = ref.watch(optionsProvider).valueOrNull;
  return map?[kind] ?? const <String>[];
});
