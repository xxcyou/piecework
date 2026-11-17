import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_setting.dart';
import '../data/services/auto_backup_service.dart';
import '../data/models/ai_provider.dart';
import '../data/services/ai_service.dart';
import '../data/services/model_catalog_service.dart';
import 'db_providers.dart';

/// 全局设置（异步加载 + 可直接改字段后保存）
class SettingsNotifier extends AsyncNotifier<AppSetting> {
  @override
  Future<AppSetting> build() {
    return ref.watch(settingsRepoProvider).ensureRow();
  }

  /// 就地修改并落库
  Future<void> mutate(void Function(AppSetting s) fn) async {
    // 不用 await future：settings 还在 loading 时 await 会拿到旧对象，
    // 快速连续切换会把最后一次改动吞掉
    final current = state.valueOrNull;
    if (current == null) {
      final loaded = await future;
      fn(loaded);
      await ref.read(settingsRepoProvider).save(loaded);
      ref.invalidateSelf();
      ref.invalidate(aiConfigProvider);
      return;
    }
    fn(current);
    await ref.read(settingsRepoProvider).save(current);

    // 关键：不能只 `state = AsyncData(current)` ——
    // current 是同一个对象引用，Riverpod 按 == 判定「没变」，
    // 下游 aiConfigProvider 不会重建，于是 UI 看着改了、实际还在用旧配置。
    // invalidateSelf 会重新执行 build()，从库里读出真正的新对象。
    ref.invalidateSelf();
    ref.invalidate(aiConfigProvider);
  }

  Future<void> save(AppSetting setting) async {
    await ref.read(settingsRepoProvider).save(setting);
    state = AsyncData(setting);
  }
}

/// 设置一变，就把云备份配置同步给自动备份服务（它不依赖 Riverpod）
final webDavSyncProvider = Provider<void>((ref) {
  ref.listen(settingsProvider, (_, next) {
    final s = next.valueOrNull;
    if (s != null) AutoBackupService.instance.setWebDav(s);
  }, fireImmediately: true);
});

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSetting>(
  SettingsNotifier.new,
);

/// 由设置派生的 Material 主题模式
final themeModeProvider = Provider<ThemeMode>((ref) {
  final s = ref.watch(settingsProvider).valueOrNull;
  return switch (s?.themeModeIndex ?? 0) {
    1 => ThemeMode.light,
    2 => ThemeMode.dark,
    _ => ThemeMode.system,
  };
});

/// 由设置派生的 AI 配置
final aiConfigProvider = Provider<AiConfig>((ref) {
  // 只监听真正影响请求的字段：对象引用没变但字段变了也能感知
  final s = ref.watch(
    settingsProvider.select((a) => a.valueOrNull),
  );
  // 显式读一次关键字段，确保 select 命中变化
  final _ = ref.watch(
    settingsProvider.select(
      (a) => '${a.valueOrNull?.aiProviderId}|'
          '${a.valueOrNull?.aiBuiltinModelId}|'
          '${a.valueOrNull?.aiBaseUrl}|'
          '${a.valueOrNull?.aiModel}|'
          '${a.valueOrNull?.aiApiKey}|'
          '${a.valueOrNull?.aiVisionEnabled}|'
          '${a.valueOrNull?.aiThinkingLevel}|'
          '${a.valueOrNull?.contextWindowTokens}',
    ),
  );
  final providerId = s?.aiProviderId ?? AiProviders.kilo.id;

  // ── 自定义提供商：只要用户「选了自定义」，就按自定义返回 ──
  //
  // 以前这里是「配置完整才用它，否则静默回落内置」，
  // 结果是：选了第三方、字段没填全（或被一键重置清空了），
  // 请求会偷偷跑到 Kilo，用户看到的就是「切不回第三方提供商」。
  // 现在改成显式表达：字段没填全 → isConfigured=false →
  // 界面提示去设置页补全，绝不偷偷换提供商。
  if (providerId == AiProviders.customId) {
    return AiConfig(
      baseUrl: (s?.aiBaseUrl ?? '').trim(),
      apiKey: (s?.aiApiKey ?? '').trim(),
      model: (s?.aiModel ?? '').trim(),
      systemPrompt: s?.aiSystemPrompt ?? '',
      visionEnabled: s?.aiVisionEnabled ?? false,
      thinkingLevel: s?.aiThinkingLevel ?? 0,
      contextWindow: s?.contextWindowTokens ?? 8192,
      providerName: '自定义',
      providerId: AiProviders.customId,
      requiresApiKey: true,
      // 自定义模式没有预设名，直接显示用户填的模型 id
      modelLabel: '',
    );
  }

  // ── 内置提供商：地址/模型/能力全固定，用户只切模型 ──
  final preset = AiProviders.byId(providerId) ?? AiProviders.kilo;
  final model = resolveBuiltinModel(
    preset: preset,
    modelId: s?.aiBuiltinModelId ?? '',
    cacheJson: s?.aiModelCacheJson ?? '',
  );

  if (model == null) {
    return AiConfig(
      baseUrl: preset.baseUrl,
      apiKey: s?.aiApiKey ?? '',
      model: '',
      systemPrompt: s?.aiSystemPrompt ?? '',
      contextWindow: 8192,
      providerName: preset.name,
    );
  }

  return AiConfig(
    baseUrl: preset.baseUrl,
    // 内置提供商免 Key。这里必须置空：
    // 库里 aiApiKey 可能是你之前给自定义提供商填的，
    // 带过去会被网关判成 INVALID_TOKEN 直接 401。
    apiKey: '',
    requiresApiKey: false,
    providerId: preset.id,
    model: model.id,
    // 内置模型用预设里的短名（如「Nemotron 3 Ultra 550B」），
    // 比裸 id 好认，也避免用户猜「现在到底用哪个」
    modelLabel: model.label,
    systemPrompt: s?.aiSystemPrompt ?? '',
    // 内置模型的能力完全由解析结果决定 —— 用户改不了
    visionEnabled: model.supportsVision,
    thinkingLevel: model.supportsThinking ? 2 : 0,
    contextWindow: model.contextWindow,
    supportsTools: model.supportsTools,
    supportsStream: model.supportsStream,
    providerName: preset.name,
  );
});

/// 解析「内置提供商」当前实际生效的模型。
///
/// 顺序：硬编码预设 → 上游模型目录缓存 → 该提供商第一个可用模型。
/// **绝不因为「id 不在预设里」就静默换成别的模型** ——
/// 设置页允许选上游新增的免费模型，那些 id 不在预设里；
/// 以前这里会退回 `usableModels.first`，于是「设置页选 A、实际跑 B」，
/// 表现得就像设置没生效、被别的提供商接管了。
AiModelPreset? resolveBuiltinModel({
  required AiProviderPreset preset,
  required String modelId,
  String cacheJson = '',
}) {
  final raw = modelId.trim();
  if (raw.isEmpty) {
    return preset.modelById(AiProviders.defaultModelId) ??
        (preset.usableModels.isEmpty ? null : preset.usableModels.first);
  }
  return preset.modelById(raw) ?? _resolveCachedModel(cacheJson, raw);
}

/// 从「上游模型目录缓存」里按 id 找回模型能力。
///
/// 设置页展示的是 `ModelCatalog`（上游 /models 与内置预设合并后的结果），
/// 用户可能选中一个只存在于上游的免费模型。这个函数保证
/// 「选中的 id」不会被静默替换成别的模型。
///
/// 缓存里查不到时，按保守默认值（128K / 支持工具 / 支持流式）认下这个 id：
/// 上游删模型的情况由设置页下次拉目录时自动纠正，不需要这里猜。
AiModelPreset? _resolveCachedModel(String cacheJson, String modelId) {
  final id = modelId.trim();
  if (id.isEmpty) return null;

  if (cacheJson.isNotEmpty) {
    try {
      final raw = jsonDecode(cacheJson);
      if (raw is List) {
        for (final e in raw) {
          final m = AiModelPreset.fromJson(e);
          if (m != null && m.id == id) return m;
        }
      }
    } catch (_) {
      // 缓存坏了就落到下面的保守默认值
    }
  }

  return AiModelPreset(
    id: id,
    label: id,
    contextWindow: 128000,
    supportsTools: true,
    supportsStream: true,
    note: '上游目录模型',
  );
}


/// 上游模型目录（带 12 小时缓存）
///
/// 上游删了模型 → 这里跟着消失；上游加了 → 自动出现。
/// 拉取失败时退回内置列表，不会让设置页变空。
final modelCatalogProvider = FutureProvider<ModelCatalog>((ref) async {
  final config = ref.watch(aiConfigProvider);
  final setting = ref.watch(settingsProvider).valueOrNull;

  final known = AiProviders.byId(setting?.aiProviderId ?? '')?.models ??
      AiProviders.kilo.models;

  // 地址都没填才用内置兜底；Kilo 免 Key，空 Key 也能拉
  if (config.baseUrl.trim().isEmpty) {
    return ModelCatalog(
      models: known.where((m) => m.supportsTools).toList(),
      fetchedAt: DateTime.now(),
    );
  }

  // 缓存命中
  final cacheAt = setting?.aiModelCacheAt;
  final cacheJson = setting?.aiModelCacheJson ?? '';
  if (cacheJson.isNotEmpty &&
      cacheAt != null &&
      DateTime.now().difference(cacheAt) < ModelCatalogService.ttl) {
    try {
      final raw = jsonDecode(cacheJson);
      if (raw is List) {
        final models = raw
            .map(AiModelPreset.fromJson)
            .whereType<AiModelPreset>()
            .toList();
        if (models.isNotEmpty) {
          return ModelCatalog(
            models: models,
            fetchedAt: cacheAt,
            fromCache: true,
          );
        }
      }
    } catch (_) {
      // 缓存坏了就重新拉
    }
  }

  final catalog = await ModelCatalogService().fetch(
    baseUrl: config.baseUrl,
    apiKey: config.apiKey,
    known: known,
  );

  if (catalog.error == null && catalog.models.isNotEmpty) {
    await ref.read(settingsProvider.notifier).mutate((s) {
      s.aiModelCacheJson =
          jsonEncode(catalog.models.map((m) => m.toJson()).toList());
      s.aiModelCacheAt = catalog.fetchedAt;
    });
  }

  return catalog;
});

/// 强制刷新上游模型列表
Future<void> refreshModelCatalog(WidgetRef ref) async {
  await ref.read(settingsProvider.notifier).mutate((s) {
    s.aiModelCacheJson = '';
    s.aiModelCacheAt = null;
  });
  ref.invalidate(modelCatalogProvider);
}
