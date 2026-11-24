import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/profile.dart';
import 'db_providers.dart';
import 'settings_providers.dart';

/// 所有身份卡（不含归档）
final profilesProvider = StreamProvider<List<Profile>>((ref) {
  return ref.watch(profileRepoProvider).watchAll();
});

/// 当前身份卡 id（存在设置里，重启后保持）
///
/// 0 = 还没初始化（main 会先跑 ensureDefault 再进界面）
final activeProfileIdProvider = Provider<int>((ref) {
  final s = ref.watch(settingsProvider).valueOrNull;
  return s?.activeProfileId ?? 0;
});

/// 当前身份卡对象（找不到就退回第一个）
final activeProfileProvider = Provider<Profile?>((ref) {
  final list = ref.watch(profilesProvider).valueOrNull ?? const <Profile>[];
  if (list.isEmpty) return null;
  final id = ref.watch(activeProfileIdProvider);
  return list.where((p) => p.id == id).firstOrNull ??
      list.where((p) => p.isDefault).firstOrNull ??
      list.first;
});

/// 切换身份卡
Future<void> switchProfile(Ref ref, int profileId) async {
  await ref.read(settingsProvider.notifier).mutate((s) {
    s.activeProfileId = profileId;
  });
}
