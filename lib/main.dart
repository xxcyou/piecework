import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/models/app_setting.dart';
import 'data/models/chat_message.dart';
import 'data/models/chat_session.dart';
import 'data/models/filter_preset.dart';
import 'data/models/operation_log.dart';
import 'data/models/option_item.dart';
import 'data/models/piece_record.dart';
import 'data/models/profile.dart';
import 'data/models/unit_item.dart';
import 'data/models/unit_rule.dart';
import 'data/repositories/operation_log_repository.dart';
import 'data/repositories/option_repository.dart';
import 'data/repositories/profile_repository.dart';
import 'data/repositories/record_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/unit_repository.dart';
import 'data/services/auto_backup_service.dart';
import 'data/services/photo_gc.dart';
import 'data/services/secure_backup_service.dart';
import 'data/services/photo_service.dart';
import 'providers/db_providers.dart';

/// 启动流程：
/// 1. 初始化 Flutter 绑定
/// 2. 在应用私有目录打开 Isar 数据库
/// 3. 首次启动写入默认选项（S/M/L/XL/XXL + 常用颜色）与默认设置
/// 4. 用 ProviderScope 把 Isar 注入 Riverpod
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final docs = await getApplicationDocumentsDirectory();

  final isar = await Isar.open(
    <CollectionSchema<dynamic>>[
      PieceRecordSchema,
      OptionItemSchema,
      FilterPresetSchema,
      ChatMessageSchema,
      ChatSessionSchema,
      AppSettingSchema,
      UnitItemSchema,
      UnitRuleSchema,
      OperationLogSchema,
      ProfileSchema,
    ],
    directory: docs.path,
    name: 'piecework',
  );

  // 让照片服务缓存文档目录，列表缩略图才能同步取 File
  PhotoService.instance.prime(docs);

  // 自动备份：数据有变动就防抖备份（防崩溃/误删）
  AutoBackupService.instance.attach(isar);
  // 加密备份（公共目录）需要 Isar 才能打包
  SecureBackupService.instance.attach(isar);

  // 回收站保留 30 天，操作日志保留 30 天
  try {
    final purged = await RecordRepository(isar).purgeOlderThan(30);
    final gc = PhotoGc(isar);
    for (final r in purged) {
      if (r.photoName.isEmpty) continue;
      // 回收站里彻底删除后，才轮到判断图还有没有人用
      await gc.deleteIfUnreferenced(r.photoName);
    }
    await OperationLogRepository(isar).purgeOlderThan(30);
  } catch (_) {
    // 清理失败不影响启动
  }

  // 身份卡：确保有默认身份，并把历史上没有归属的记录/对话挂过去（只补字段，不删数据）
  final profileRepo = ProfileRepository(isar);
  final defaultProfile = await profileRepo.ensureDefault();

  // 幂等：已有数据时直接跳过
  await OptionRepository(isar).seedDefaults();
  await UnitRepository(isar).seedDefaults();
  final settingsRepo = SettingsRepository(isar);
  final setting = await settingsRepo.ensureRow();

  // 当前身份：没设过 / 指向已删除的身份 → 回到默认身份
  if (setting.activeProfileId == 0 ||
      await profileRepo.byId(setting.activeProfileId) == null) {
    setting.activeProfileId = defaultProfile.id;
    await settingsRepo.save(setting);
  }

  // 注意：**不要**再把「选了自定义但没填完」自动改回内置。
  // 那是用户明确做出的选择，偷偷改掉会让人以为「切不回第三方提供商」。
  // 没填完时 aiConfigProvider 会返回未配置状态，界面提示去设置页补全即可。

  // 一次性迁移：内置提供商模式下，清掉老版本留下的「第三方默认值」。
  // 老版本把 OpenAI 的地址/模型当默认值写进库（api.openai.com + gpt-4o-mini），
  // 内置模式本该完全不看这两个字段，但它们会污染诊断信息、
  // 也会在切回自定义时把用户误导到第三方。只清「恰好等于旧默认值」的，
  // 用户真填过的自定义地址不动。
  if (setting.aiProviderId != 'custom' &&
      setting.aiBaseUrl.trim() == 'https://api.openai.com/v1' &&
      setting.aiModel.trim() == 'gpt-4o-mini') {
    setting.aiBaseUrl = '';
    setting.aiModel = '';
    await settingsRepo.save(setting);
  }

  runApp(
    ProviderScope(
      overrides: <Override>[
        isarProvider.overrideWithValue(isar),
      ],
      child: const PieceworkApp(),
    ),
  );
}
