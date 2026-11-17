/// 内置 AI 提供商与模型预设。
///
/// 内置项**固定不可改**（地址/能力/上下文都是查证过的），
/// 用户只能切模型；想调参数就用「自定义提供商」。
class AiModelPreset {
  const AiModelPreset({
    required this.id,
    required this.label,
    required this.contextWindow,
    this.supportsThinking = false,
    this.supportsVision = false,
    this.supportsTools = true,
    this.supportsStream = true,
    this.note = '',
  });

  /// 接口里的 model 名
  final String id;

  /// 界面显示名
  final String label;

  /// 上下文窗口（token）
  final int contextWindow;

  final bool supportsThinking;
  final bool supportsVision;

  /// 是否支持 function calling —— 本 App 依赖工具，false 的直接不展示
  final bool supportsTools;

  final bool supportsStream;
  final String note;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'label': label,
        'contextWindow': contextWindow,
        'supportsThinking': supportsThinking,
        'supportsVision': supportsVision,
        'supportsTools': supportsTools,
        'supportsStream': supportsStream,
        'note': note,
      };

  static AiModelPreset? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    final id = (m['id'] as String?) ?? '';
    if (id.isEmpty) return null;
    return AiModelPreset(
      id: id,
      label: (m['label'] as String?) ?? id,
      contextWindow: (m['contextWindow'] as num?)?.toInt() ?? 128000,
      supportsThinking: m['supportsThinking'] == true,
      supportsVision: m['supportsVision'] == true,
      supportsTools: m['supportsTools'] != false,
      supportsStream: m['supportsStream'] != false,
      note: (m['note'] as String?) ?? '',
    );
  }

  /// 上下文窗口的短标签，例如 1M / 262K
  String get contextLabel {
    if (contextWindow >= 1000000) {
      final m = contextWindow / 1000000;
      return '${m.toStringAsFixed(m == m.roundToDouble() ? 0 : 1)}M';
    }
    return '${(contextWindow / 1000).round()}K';
  }
}

class AiProviderPreset {
  const AiProviderPreset({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.models,
    this.signupUrl = '',
    this.note = '',
    this.requiresApiKey = true,
  });

  final String id;
  final String name;
  final String baseUrl;
  final List<AiModelPreset> models;

  /// 去哪儿拿免费 Key
  final String signupUrl;

  final String note;
  final bool requiresApiKey;

  /// 支持工具的模型（本 App 只认这些）
  List<AiModelPreset> get usableModels =>
      models.where((m) => m.supportsTools).toList();

  AiModelPreset? modelById(String id) {
    for (final m in models) {
      if (m.id == id) return m;
    }
    return null;
  }
}

/// 内置提供商：Kilo（免费网关，OpenAI 兼容）
///
/// 数据来源：kilo.ai 网关文档 + freellm.net 的模型清单（2026-10 抓取）。
/// 免费额度约 200 请求/小时，需要 GitHub 登录换 API Key。
class AiProviders {
  AiProviders._();

  static const String customId = 'custom';

  static const AiProviderPreset kilo = AiProviderPreset(
    id: 'kilo',
    name: 'Kilo（免费）',
    baseUrl: 'https://api.kilo.ai/api/gateway',
    signupUrl: 'https://app.kilo.ai/profile',
    note: '免费额度约 200 次/小时，用 GitHub 登录即可领 Key，不需要信用卡。',
    models: <AiModelPreset>[
      // ── 默认主模型：1M 上下文 + 推理 ──
      AiModelPreset(
        id: 'nvidia/nemotron-3-ultra-550b-a55b:free',
        label: 'Nemotron 3 Ultra 550B',
        contextWindow: 1000000,
        supportsThinking: true,
        note: '默认推荐：1M 上下文，会推理，适合查账算数',
      ),
      AiModelPreset(
        id: 'nvidia/nemotron-3.5-super-vl:free',
        label: 'Nemotron 3.5 Super VL',
        contextWindow: 1000000,
        supportsThinking: true,
        supportsVision: true,
        note: '1M 上下文 + 能看图',
      ),
      AiModelPreset(
        id: 'nvidia/nemotron-3.5-lightning:free',
        label: 'Nemotron 3.5 Lightning',
        contextWindow: 1000000,
        supportsThinking: true,
        note: '1M 上下文，速度优先',
      ),
      AiModelPreset(
        id: 'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free',
        label: 'Nemotron 3 Nano Omni 30B',
        contextWindow: 256000,
        supportsThinking: true,
        supportsVision: true,
        note: '小模型里少见的「会推理 + 能看图」',
      ),
      AiModelPreset(
        id: 'nvidia/nemotron-3-super-120b-a12b:free',
        label: 'Nemotron 3 Super 120B',
        contextWindow: 262000,
        supportsThinking: true,
      ),
      AiModelPreset(
        id: 'dots-studio/dots-3-note-preview:free',
        label: 'Dots 3 Note Preview',
        contextWindow: 512000,
        note: '512K 上下文',
      ),
      AiModelPreset(
        id: 'recursive/flint-v1.0:free',
        label: 'Flint v1.0',
        contextWindow: 262000,
      ),
      AiModelPreset(
        id: 'xingchen-agi/xing4.0-29b-a4b:free',
        label: '星尘 4.0 29B',
        contextWindow: 262000,
      ),
      AiModelPreset(
        id: 'poolside/laguna-s-2.1:free',
        label: 'Laguna S 2.1',
        contextWindow: 262000,
      ),
      AiModelPreset(
        id: 'poolside/laguna-xs-2.1:free',
        label: 'Laguna XS 2.1',
        contextWindow: 262000,
        note: '更轻更快',
      ),
      AiModelPreset(
        id: 'cohere/north-mini-code:free',
        label: 'Cohere North Mini',
        contextWindow: 256000,
      ),
      AiModelPreset(
        id: 'kilo-auto/free',
        label: 'Kilo 自动路由',
        contextWindow: 256000,
        note: '由网关自己挑模型，不固定',
      ),
      AiModelPreset(
        id: 'reflection/beam-free',
        label: 'Reflection Beam',
        contextWindow: 1000000,
      ),
      AiModelPreset(
        id: 'stealth/glyph-cluster',
        label: 'Glyph Cluster',
        contextWindow: 256000,
      ),
      AiModelPreset(
        id: 'liquid/lfm-2.5-2.6b:free',
        label: 'Liquid LFM 2.5 2.6B',
        contextWindow: 64000,
        note: '超小模型，只适合简单问答',
      ),
      // content-safety 是审核模型，不能当主模型用 —— 故意不列
    ],
  );

  static const List<AiProviderPreset> builtin = <AiProviderPreset>[kilo];

  static AiProviderPreset? byId(String id) {
    for (final p in builtin) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// 默认主模型
  static const String defaultModelId =
      'nvidia/nemotron-3-ultra-550b-a55b:free';
}
