import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/license.dart';
import 'settings_providers.dart';

/// 设备码（由 Android ID 派生）
final deviceCodeProvider = FutureProvider<String>((ref) async {
  try {
    final id = await const MethodChannel('piecework/public_storage')
        .invokeMethod<String>('deviceId');
    return deviceCodeFrom(id ?? 'unknown');
  } catch (_) {
    return deviceCodeFrom('unknown');
  }
});

/// AI 是否已激活
///
/// **每次启动都重新验签**：把激活码存下来只为了少打字，
/// 判断始终靠签名 —— 换设备/改库/还原备份都过不了。
final aiActivatedProvider = Provider<bool>((ref) {
  final s = ref.watch(settingsProvider).valueOrNull;
  final code = s?.aiLicenseCode ?? '';
  if (code.isEmpty) return false;
  final device = ref.watch(deviceCodeProvider).valueOrNull;
  if (device == null) return false;
  return verifyActivationCode(code, device);
});

/// 激活：校验通过才写入
Future<({bool ok, String message})> activateAi(
  WidgetRef ref,
  String input,
) async {
  final device = await ref.read(deviceCodeProvider.future);
  final code = normalizeCode(input);
  if (code.isEmpty) {
    return (ok: false, message: '激活码是空的');
  }
  if (!verifyActivationCode(code, device)) {
    return (ok: false, message: '激活码不对，或不是这台设备的');
  }
  await ref.read(settingsProvider.notifier).mutate((s) {
    s.aiLicenseCode = input.trim();
  });
  return (ok: true, message: '已激活');
}
