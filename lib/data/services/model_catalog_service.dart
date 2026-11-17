import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_provider.dart';

/// 模型目录：从上游 `/models` 拉取，与内置预设合并。
///
/// 合并规则（这是关键）：
/// * 上游有、本地预设也有 → 用**预设的能力**（上下文/思考/图片是查证过的，更准）
/// * 上游有、本地没有 → 用上游返回的字段解析；解析不出来给保守默认值
/// * 本地有、上游没有 → **不展示**（上游下架了就别让人选到失效模型）
/// * 只保留免费模型（`:free` 后缀，或上游 pricing 为 0）
class ModelCatalog {
  const ModelCatalog({
    required this.models,
    required this.fetchedAt,
    this.fromCache = false,
    this.error,
  });

  final List<AiModelPreset> models;
  final DateTime fetchedAt;
  final bool fromCache;

  /// 拉取失败时的原因（此时 models 用内置兜底）
  final String? error;

  bool get isEmpty => models.isEmpty;

  static ModelCatalog fallback(String? error) => ModelCatalog(
        models: AiProviders.kilo.usableModels,
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(0),
        error: error,
      );
}

class ModelCatalogService {
  ModelCatalogService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// 缓存有效期
  static const Duration ttl = Duration(hours: 12);

  /// 拉上游模型列表
  Future<ModelCatalog> fetch({
    required String baseUrl,
    required String apiKey,
    List<AiModelPreset> known = const <AiModelPreset>[],
  }) async {
    var b = baseUrl.trim();
    while (b.endsWith('/')) {
      b = b.substring(0, b.length - 1);
    }
    if (b.endsWith('/chat/completions')) {
      b = b.substring(0, b.length - '/chat/completions'.length);
    }

    final uri = Uri.tryParse('$b/models');
    if (uri == null || !uri.hasScheme) {
      return ModelCatalog.fallback('接口地址不合法：$baseUrl');
    }

    try {
      final resp = await _client.get(
        uri,
        headers: <String, String>{
          if (apiKey.trim().isNotEmpty)
            'Authorization': 'Bearer ${apiKey.trim()}',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 25));

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        return ModelCatalog.fallback(
          '拉取模型失败（HTTP ${resp.statusCode}）',
        );
      }

      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      final raw = decoded is Map ? decoded['data'] : decoded;
      if (raw is! List) {
        return ModelCatalog.fallback('模型列表格式异常');
      }

      final models = _merge(raw, known);
      if (models.isEmpty) {
        return ModelCatalog.fallback('上游没有可用的免费模型');
      }

      return ModelCatalog(models: models, fetchedAt: DateTime.now());
    } catch (e) {
      return ModelCatalog.fallback('拉取模型失败：$e');
    }
  }

  /// 上游 → 本地模型列表
  List<AiModelPreset> _merge(
    List<dynamic> raw,
    List<AiModelPreset> known,
  ) {
    final byId = <String, AiModelPreset>{
      for (final m in known) m.id: m,
    };

    final out = <AiModelPreset>[];
    final seen = <String>{};

    for (final item in raw) {
      if (item is! Map) continue;
      final m = item.map((k, v) => MapEntry(k.toString(), v));

      final id = (m['id'] as String?)?.trim() ?? '';
      if (id.isEmpty || seen.contains(id)) continue;
      if (!_isFree(m, id)) continue;
      seen.add(id);

      final preset = byId[id];
      if (preset != null) {
        // 预设里查证过的能力更可信
        if (preset.supportsTools) out.add(preset);
        continue;
      }

      // 上游新增：尽力解析
      final ctx = _contextWindow(m);
      final caps = _capabilities(m);
      final model = AiModelPreset(
        id: id,
        label: _prettyLabel(id),
        contextWindow: ctx,
        supportsThinking: caps.contains('reasoning'),
        supportsVision: caps.contains('vision'),
        supportsTools: caps.contains('tools'),
        supportsStream: true,
        note: '上游新增',
      );
      // 本 App 依赖工具，不支持的不展示
      if (model.supportsTools) out.add(model);
    }

    // 预设里有但上游没返回 → 说明下架了，不展示
    out.sort((a, b) {
      // 支持思考的排前面，其次上下文大的
      if (a.supportsThinking != b.supportsThinking) {
        return a.supportsThinking ? -1 : 1;
      }
      return b.contextWindow.compareTo(a.contextWindow);
    });
    return out;
  }

  /// 是否免费：`:free` 后缀，或 pricing 全 0
  static bool _isFree(Map<String, dynamic> m, String id) {
    if (id.toLowerCase().endsWith(':free')) return true;
    final pricing = m['pricing'];
    if (pricing is Map) {
      final p = pricing['prompt'];
      final c = pricing['completion'];
      final pz = (p is num && p == 0) || p == '0' || p == '0.0';
      final cz = (c is num && c == 0) || c == '0' || c == '0.0';
      if (pz && cz) return true;
    }
    // 没有 pricing 字段时，不认作免费（避免把付费模型混进来）
    return false;
  }

  static int _contextWindow(Map<String, dynamic> m) {
    for (final key in <String>[
      'context_length',
      'context_window',
      'max_context_length',
      'max_input_tokens',
    ]) {
      final v = m[key];
      if (v is num && v > 0) return v.toInt();
    }
    final top = m['top_provider'];
    if (top is Map) {
      final v = top['context_length'];
      if (v is num && v > 0) return v.toInt();
    }
    return 128000; // 保守默认
  }

  static Set<String> _capabilities(Map<String, dynamic> m) {
    final caps = <String>{};

    final params = m['supported_parameters'];
    if (params is List) {
      for (final p in params) {
        if (p == 'tools' || p == 'tool_choice') caps.add('tools');
        if (p == 'reasoning' || p == 'include_reasoning') {
          caps.add('reasoning');
        }
      }
    }

    final arch = m['architecture'];
    if (arch is Map) {
      final mods = arch['input_modalities'];
      if (mods is List && mods.contains('image')) caps.add('vision');
      if (mods is List && mods.contains('text')) caps.add('text');
    }

    // 没有任何 supported_parameters 信息时，按"支持工具"处理
    // （Kilo 网关声明整体支持 function calling）
    if (!caps.contains('tools') && params is! List) caps.add('tools');

    return caps;
  }

  /// `nvidia/nemotron-3-ultra-550b-a55b:free` → `Nemotron 3 Ultra 550B`
  static String _prettyLabel(String id) {
    var s = id;
    final slash = s.lastIndexOf('/');
    if (slash >= 0) s = s.substring(slash + 1);
    final colon = s.indexOf(':');
    if (colon >= 0) s = s.substring(0, colon);

    final parts = s.split(RegExp(r'[-_]'));
    final buf = <String>[];
    for (final p in parts) {
      if (p.isEmpty) continue;
      // 纯数字/单位保留原样
      if (RegExp(r'^\d').hasMatch(p)) {
        buf.add(p.toUpperCase());
      } else {
        buf.add(p[0].toUpperCase() + p.substring(1));
      }
    }
    return buf.isEmpty ? id : buf.join(' ');
  }
}
