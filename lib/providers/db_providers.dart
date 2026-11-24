import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../data/repositories/chat_repository.dart';
import '../data/repositories/operation_log_repository.dart';
import '../data/repositories/option_repository.dart';
import '../data/repositories/preset_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/record_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/unit_repository.dart';
import '../data/services/ai_service.dart';
import '../data/services/backup_service.dart';
import '../data/services/photo_gc.dart';

/// 由 `main()` 在启动时 override，注入已经打开的 Isar 实例。
final isarProvider = Provider<Isar>(
  (ref) => throw UnimplementedError('isarProvider 必须在 main() 中 override'),
);

final profileRepoProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(isarProvider)),
);

final recordRepoProvider = Provider<RecordRepository>(
  (ref) => RecordRepository(ref.watch(isarProvider)),
);

final optionRepoProvider = Provider<OptionRepository>(
  (ref) => OptionRepository(ref.watch(isarProvider)),
);

final presetRepoProvider = Provider<PresetRepository>(
  (ref) => PresetRepository(ref.watch(isarProvider)),
);

final settingsRepoProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(isarProvider)),
);

final chatRepoProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(isarProvider)),
);

final unitRepoProvider = Provider<UnitRepository>(
  (ref) => UnitRepository(ref.watch(isarProvider)),
);

final opLogRepoProvider = Provider<OperationLogRepository>(
  (ref) => OperationLogRepository(ref.watch(isarProvider)),
);

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(isarProvider)),
);

/// 图片引用计数 / 安全删除（删记录不等于删图）
final photoGcProvider = Provider<PhotoGc>(
  (ref) => PhotoGc(ref.watch(isarProvider)),
);

final aiServiceProvider = Provider<AiService>((ref) {
  final service = AiService();
  ref.onDispose(service.dispose);
  return service;
});
