import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_providers.dart';

/// 工作模式：0 = 财务模式（默认），1 = 审计模式
final workModeProvider = Provider<int>((ref) {
  final s = ref.watch(settingsProvider).valueOrNull;
  return s?.workMode ?? 0;
});

/// 是否财务模式
final salaryModeProvider = Provider<bool>((ref) => ref.watch(workModeProvider) == 0);

Future<void> setWorkMode(WidgetRef ref, int mode) async {
  await ref.read(settingsProvider.notifier).mutate((s) => s.workMode = mode);
}
