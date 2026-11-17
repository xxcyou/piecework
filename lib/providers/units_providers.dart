import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/unit_item.dart';
import '../data/models/unit_rule.dart';
import '../data/services/unit_converter.dart';
import 'db_providers.dart';

/// 单位配置快照
class UnitConfig {
  const UnitConfig({required this.units, required this.rules});

  final List<UnitItem> units;
  final List<UnitRule> rules;

  static const UnitConfig fallback = UnitConfig(
    units: <UnitItem>[],
    rules: <UnitRule>[],
  );

  String get baseUnit {
    for (final u in units) {
      if (u.isBase) return u.name;
    }
    return '件';
  }

  List<String> get names => units.map((e) => e.name).toList();

  UnitConverter get converter =>
      UnitConverter(baseUnit: baseUnit, rules: rules);
}

class UnitsNotifier extends AsyncNotifier<UnitConfig> {
  @override
  Future<UnitConfig> build() async {
    final repo = ref.watch(unitRepoProvider);
    final units = await repo.units();
    final rules = await repo.rules();
    return UnitConfig(units: units, rules: rules);
  }

  Future<void> _refresh() async {
    final repo = ref.read(unitRepoProvider);
    state = AsyncData(UnitConfig(
      units: await repo.units(),
      rules: await repo.rules(),
    ));
  }

  Future<bool> addUnit(String name) async {
    final ok = await ref.read(unitRepoProvider).addUnit(name);
    if (ok) await _refresh();
    return ok;
  }

  Future<void> removeUnit(String name) async {
    await ref.read(unitRepoProvider).removeUnit(name);
    await _refresh();
  }

  Future<void> setBase(String name) async {
    await ref.read(unitRepoProvider).setBase(name);
    await _refresh();
  }

  Future<void> saveRule({
    required String fromUnit,
    required String toUnit,
    required int numerator,
    required int denominator,
    String styleModel = '',
  }) async {
    await ref.read(unitRepoProvider).saveRule(
          fromUnit: fromUnit,
          toUnit: toUnit,
          numerator: numerator,
          denominator: denominator,
          styleModel: styleModel,
        );
    await _refresh();
  }

  Future<void> removeRule(int id) async {
    await ref.read(unitRepoProvider).removeRule(id);
    await _refresh();
  }
}

final unitsProvider = AsyncNotifierProvider<UnitsNotifier, UnitConfig>(
  UnitsNotifier.new,
);

/// 换算器（供查询引擎 / 报表使用）
final unitConverterProvider = Provider<UnitConverter>((ref) {
  final cfg = ref.watch(unitsProvider).valueOrNull;
  return cfg?.converter ?? UnitConverter.identity;
});

/// 可选单位名列表（录入页用）
final unitNamesProvider = Provider<List<String>>((ref) {
  final cfg = ref.watch(unitsProvider).valueOrNull;
  final names = cfg?.names ?? const <String>[];
  return names.isEmpty ? const <String>['件'] : names;
});

/// 基准单位名
final baseUnitProvider = Provider<String>((ref) {
  final cfg = ref.watch(unitsProvider).valueOrNull;
  return cfg?.baseUnit ?? '件';
});
