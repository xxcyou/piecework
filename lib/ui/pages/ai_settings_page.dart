import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/ai_provider.dart';
import '../../data/services/model_catalog_service.dart';

import '../../data/models/app_setting.dart';
import '../../data/services/ai_service.dart';
import '../../providers/db_providers.dart';
import '../../providers/settings_providers.dart';

/// AI 接口配置页。
///
/// 兼容任何 OpenAI 协议的 /chat/completions 端点：
/// OpenAI、DeepSeek、Moonshot、通义、本地 vLLM / Ollama(OpenAI 兼容) 都能填。
class AiSettingsPage extends ConsumerStatefulWidget {
  const AiSettingsPage({super.key});

  @override
  ConsumerState<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends ConsumerState<AiSettingsPage> {
  final TextEditingController _baseUrlCtrl = TextEditingController();
  final TextEditingController _keyCtrl = TextEditingController();
  final TextEditingController _modelCtrl = TextEditingController();
  final TextEditingController _promptCtrl = TextEditingController();
  final TextEditingController _windowCtrl = TextEditingController();

  bool _inited = false;
  bool _obscure = true;
  bool _testing = false;
  int _windowTokens = 8192;
  bool _visionEnabled = false;
  int _thinkingLevel = 0;
  String _providerId = AiProviders.kilo.id;
  String _builtinModelId = AiProviders.defaultModelId;

  static const List<Map<String, String>> _presets = <Map<String, String>>[
    <String, String>{'name': 'OpenAI', 'url': 'https://api.openai.com/v1', 'model': 'gpt-4o-mini'},
    <String, String>{'name': 'DeepSeek', 'url': 'https://api.deepseek.com/v1', 'model': 'deepseek-chat'},
    <String, String>{'name': 'Moonshot', 'url': 'https://api.moonshot.cn/v1', 'model': 'moonshot-v1-8k'},
    <String, String>{'name': '本地 Ollama', 'url': 'http://127.0.0.1:11434/v1', 'model': 'qwen2.5:7b'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(settingsProvider).valueOrNull;
      if (s != null) _apply(s);
    });
  }

  Future<void> _applyWindow(String raw) async {
    final v = int.tryParse(raw.trim());
    if (v == null || v < 512) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('窗口至少 512 token')),
      );
      return;
    }
    final capped = v > 1000000 ? 1000000 : v;
    setState(() => _windowTokens = capped);
    _windowCtrl.text = '$capped';
    await ref
        .read(settingsProvider.notifier)
        .mutate((st) => st.contextWindowTokens = capped);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('上下文窗口已设为 $capped token')),
    );
  }

  @override
  void dispose() {
    _windowCtrl.dispose();
    _baseUrlCtrl.dispose();
    _keyCtrl.dispose();
    _modelCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  void _apply(AppSetting s) {
    if (!mounted || _inited) return;
    _baseUrlCtrl.text = s.aiBaseUrl;
    _keyCtrl.text = s.aiApiKey;
    _modelCtrl.text = s.aiModel;
    _promptCtrl.text = s.aiSystemPrompt;
    _windowTokens = s.contextWindowTokens;
    _windowCtrl.text = '${s.contextWindowTokens}';
    _visionEnabled = s.aiVisionEnabled;
    _thinkingLevel = s.aiThinkingLevel;
    _providerId = s.aiProviderId;
    _builtinModelId = s.aiBuiltinModelId;
    setState(() => _inited = true);
  }

  Future<void> _save() async {
    // 以「界面上选的提供商」为准，而不是库里那个旧值 ——
    // 之前用 s.aiProviderId 判断，切到自定义后立刻保存会把
    // 地址/密钥/模型三个字段整个丢掉，等于「切不回第三方提供商」。
    final custom = _providerId == AiProviders.customId;
    if (custom) {
      final url = _baseUrlCtrl.text.trim();
      final model = _modelCtrl.text.trim();
      if (url.isEmpty || model.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('自定义提供商要填接口地址和模型名称')),
        );
        return;
      }
    }

    await ref.read(settingsProvider.notifier).mutate((s) {
      if (custom) {
        s.aiBaseUrl = _baseUrlCtrl.text.trim();
        s.aiApiKey = _keyCtrl.text.trim();
        s.aiModel = _modelCtrl.text.trim();
      }
      s.aiSystemPrompt = _promptCtrl.text.trim();
      s.aiProviderId = _providerId;
      s.aiBuiltinModelId = _builtinModelId;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          custom ? '已切换到自定义提供商' : 'AI 配置已保存',
        ),
      ),
    );
  }

  /// 把真实生效的配置复制到剪贴板，方便定位「设置改了没生效」的问题
  Future<void> _copyDiagnostics() async {
    final s = ref.read(settingsProvider).valueOrNull;
    final cfg = ref.read(aiConfigProvider);
    final rows = await ref.read(settingsRepoProvider).rowCount();

    final buf = StringBuffer()
      ..writeln('=== 设置表行数：$rows ===')
      ..writeln('aiProviderId   = ${s?.aiProviderId ?? "(null)"}')
      ..writeln('aiBuiltinModel = ${s?.aiBuiltinModelId ?? "(null)"}')
      ..writeln('aiBaseUrl      = ${s?.aiBaseUrl ?? "(null)"}')
      ..writeln('aiModel        = ${s?.aiModel ?? "(null)"}')
      ..writeln('aiApiKey       = ${(s?.aiApiKey ?? "").isEmpty ? "(空)" : "已填"}')
      ..writeln('aiVision       = ${s?.aiVisionEnabled}')
      ..writeln('aiThinking     = ${s?.aiThinkingLevel}')
      ..writeln('--- 实际生效 ---')
      ..writeln('providerId     = ${cfg.providerId}')
      ..writeln('providerName   = ${cfg.providerName}')
      ..writeln('baseUrl        = ${cfg.baseUrl}')
      ..writeln('model          = ${cfg.model}')
      ..writeln('apiKey空       = ${cfg.apiKey.isEmpty}');

    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('诊断信息已复制，粘贴发我即可')),
    );
  }

  /// 一键切回内置免费提供商。
  ///
  /// 只切「用哪个提供商」，**不删**自定义的地址/密钥/模型 ——
  /// 删了以后再点「自定义」就是三个空框，很容易让人觉得「切不回第三方」。
  /// 内置模式本来就不读这三个字段，留着没有任何副作用。
  Future<void> _resetToBuiltin() async {
    await ref.read(settingsProvider.notifier).mutate((s) {
      s.aiProviderId = AiProviders.kilo.id;
      s.aiBuiltinModelId = AiProviders.defaultModelId;
      s.aiVisionEnabled = false;
      s.aiThinkingLevel = 0;
    });
    // 双保险：直接把本地状态也拨过去
    setState(() {
      _providerId = AiProviders.kilo.id;
      _builtinModelId = AiProviders.defaultModelId;
    });
    ref.invalidate(settingsProvider);
    ref.invalidate(aiConfigProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已切回 Kilo 免费模型（自定义配置已保留）')),
    );
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    try {
      // 内置提供商：用真实生效的配置（地址/模型都是固定的）
      // 自定义：用当前输入框（可能还没保存）
      final isCustom =
          (ref.read(aiConfigProvider).providerId.isEmpty
                  ? _providerId
                  : ref.read(aiConfigProvider).providerId) ==
              AiProviders.customId;

      final config = isCustom
          ? AiConfig(
              baseUrl: _baseUrlCtrl.text.trim(),
              apiKey: _keyCtrl.text.trim(),
              model: _modelCtrl.text.trim(),
              requiresApiKey: true,
              providerId: AiProviders.customId,
            )
          : ref.read(aiConfigProvider);

      final msg = await ref.read(aiServiceProvider).ping(config);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('✅ $msg')));
    } on AiException catch (e) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('连接失败'),
          content: SingleChildScrollView(child: Text(e.message)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final s = settingsAsync.valueOrNull;
    if (s != null && !_inited) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _apply(s));
    }

    final aiCfg = ref.watch(aiConfigProvider);
    // UI 只认实际生效的配置，不再用本地 _providerId 猜
    final effectiveProviderId =
        aiCfg.providerId.isEmpty ? _providerId : aiCfg.providerId;

    final catalogAsync = ref.watch(modelCatalogProvider);
    final catalog = catalogAsync.valueOrNull ??
        ModelCatalog.fallback(catalogAsync.hasError ? '拉取失败' : null);
    final models = catalog.models;

    // 上游把这个模型下架了 → 自动切到第一个可用，避免选到失效项
    if (models.isNotEmpty && !models.any((m) => m.id == _builtinModelId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final fb = models.first.id;
        setState(() => _builtinModelId = fb);
        ref
            .read(settingsProvider.notifier)
            .mutate((st) => st.aiBuiltinModelId = fb);
      });
    }

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 助手设置'),
        actions: <Widget>[
          TextButton(onPressed: _save, child: const Text('保存')),
          const SizedBox(width: 4),
        ],
      ),
      body: !_inited
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
              children: <Widget>[
                _card(
                  scheme,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        '提供商',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '免费模型偶尔会中途断流（复杂任务更明显），'
                          'App 会自动接着跑；想一次做完建议用自定义的收费模型。',
                          style: TextStyle(
                            fontSize: 10.5,
                            height: 1.5,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ),
                      SegmentedButton<String>(
                        segments: <ButtonSegment<String>>[
                          ButtonSegment<String>(
                            value: AiProviders.kilo.id,
                            label: const Text('Kilo 免费'),
                            icon: const Icon(Icons.card_giftcard, size: 15),
                          ),
                          ButtonSegment<String>(
                            value: AiProviders.customId,
                            label: const Text('自定义'),
                            icon: const Icon(Icons.tune, size: 15),
                          ),
                        ],
                        selected: <String>{effectiveProviderId},
                        onSelectionChanged: (v) async {
                          final target = v.first;
                          setState(() => _providerId = target);
                          try {
                            await ref
                                .read(settingsProvider.notifier)
                                .mutate((s) => s.aiProviderId = target);
                          } catch (e) {
                            // 写库失败就回滚 UI，别让人以为切成功了
                            if (!mounted) return;
                            setState(() => _providerId = effectiveProviderId);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('切换失败：$e')),
                            );
                          }
                        },
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        showSelectedIcon: false,
                      ),
                      const SizedBox(height: 8),
                      if (effectiveProviderId == AiProviders.kilo.id)
                        Text(
                          '${AiProviders.kilo.note}\n'
                          '地址固定为 ${AiProviders.kilo.baseUrl}，'
                          '模型能力已预设；免费模型免 Key，装完直接能用。',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.55,
                            color: scheme.onSurfaceVariant,
                          ),
                        )
                      else
                        Text(
                          '自己填地址和 Key。支持 OpenAI 兼容接口，'
                          '上下文窗口和模型能力由你设置。',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.55,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      const SizedBox(height: 8),
                      // 诊断 + 兜底：一眼看到库里存的是什么，切不动就一键重置
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              // 显示「实际生效」而不是库里残留的自定义字段 ——
                              // 内置模式下 aiModel 是历史值，显示它会误导成第三方模型
                              '生效：${aiCfg.providerId.isEmpty ? "?" : aiCfg.providerId}'
                              ' · ${aiCfg.model.isEmpty ? "未选模型" : aiCfg.model}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.5,
                                color: scheme.onSurfaceVariant.withAlpha(160),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _copyDiagnostics,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 28),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              textStyle: const TextStyle(fontSize: 10.5),
                            ),
                            child: const Text('复制诊断'),
                          ),
                          TextButton(
                            onPressed: _resetToBuiltin,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 28),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              textStyle: const TextStyle(fontSize: 10.5),
                            ),
                            child: const Text('重置为内置'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 内置提供商：模型下拉（能力固定）
                if (effectiveProviderId != AiProviders.customId) ...<Widget>[
                  _card(
                    scheme,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Text(
                              '模型',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              catalogAsync.isLoading
                                  ? '同步中…'
                                  : (catalog.fromCache
                                      ? '缓存 · ${_ago(catalog.fetchedAt)}'
                                      : '上游实时'),
                              style: TextStyle(
                                fontSize: 10,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: '从上游刷新模型列表',
                              onPressed: catalogAsync.isLoading
                                  ? null
                                  : () => refreshModelCatalog(ref),
                              icon: const Icon(Icons.refresh, size: 17),
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(
                                  minWidth: 30, minHeight: 30),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                        if (catalog.error != null) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            '${catalog.error}（正在用内置列表兜底）',
                            style:
                                TextStyle(fontSize: 10, color: scheme.error),
                          ),
                        ],
                        const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                          initialValue: _builtinModelId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: '主模型',
                            isDense: true,
                          ),
                          items: AiProviders.kilo.usableModels.map((m) {
                            final caps = <String>[
                              m.contextLabel,
                              if (m.supportsThinking) '会思考',
                              if (m.supportsVision) '能看图',
                            ].join(' · ');
                            return DropdownMenuItem<String>(
                              value: m.id,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  // 下拉项高度只有 48，两行必须压紧，否则 RenderFlex 溢出
                                  Text(
                                    m.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 12, height: 1.0),
                                  ),
                                  Text(
                                    caps,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 9,
                                      height: 1.0,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (v) async {
                            if (v == null) return;
                            setState(() => _builtinModelId = v);
                            await ref
                                .read(settingsProvider.notifier)
                                .mutate((s) => s.aiBuiltinModelId = v);
                          },
                        ),
                        const SizedBox(height: 8),
                        if (AiProviders.kilo
                                .modelById(_builtinModelId)
                                ?.note
                                .isNotEmpty ??
                            false)
                          Text(
                            AiProviders.kilo
                                .modelById(_builtinModelId)!
                                .note,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (effectiveProviderId == AiProviders.customId) ...<Widget>[
                _card(
                  scheme,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        '快速填充',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: _presets.map((p) {
                          return ActionChip(
                            label: Text(p['name']!,
                                style: const TextStyle(fontSize: 12)),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            onPressed: () {
                              setState(() {
                                _baseUrlCtrl.text = p['url']!;
                                if (_modelCtrl.text.trim().isEmpty) {
                                  _modelCtrl.text = p['model']!;
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ],

                _card(
                  scheme,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // 自定义才让改地址
                      if (effectiveProviderId == AiProviders.customId) ...<Widget>[
                      TextField(
                        controller: _baseUrlCtrl,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: '接口地址',
                          hintText: 'https://api.openai.com/v1',
                          helperText: '填到 /v1 即可，App 会自动补 /chat/completions',
                          helperMaxLines: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ] else ...<Widget>[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 9),
                          decoration: BoxDecoration(
                            color: scheme.primary.withAlpha(14),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                AiProviders.kilo.baseUrl,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.primary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '地址固定不可改。免费 Key 去 '
                                'app.kilo.ai/profile 用 GitHub 登录领取。',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  height: 1.4,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // 内置 Kilo 免 Key，直接就能用
                      if (effectiveProviderId == AiProviders.customId)
                        TextField(
                          controller: _keyCtrl,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'API 密钥',
                            hintText: 'sk-…',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 19,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 9),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withAlpha(16),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: const Color(0xFF10B981).withAlpha(70),
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(Icons.check_circle,
                                  size: 15, color: Color(0xFF10B981)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '免 Key，装完就能用。额度约 200 次/小时，'
                                  '超了等一会儿就好。',
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.45,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (effectiveProviderId == AiProviders.customId) ...<Widget>[
                        TextField(
                          controller: _modelCtrl,
                          decoration: const InputDecoration(
                            labelText: '模型名称',
                            hintText: 'gpt-4o-mini',
                            helperText: '必须支持 function calling（工具调用）',
                            helperMaxLines: 2,
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _testing ? null : _test,
                              icon: _testing
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.wifi_tethering, size: 17),
                              label: Text(_testing ? '测试中…' : '测试连接'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _save,
                              icon: const Icon(Icons.check, size: 17),
                              label: const Text('保存配置'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  scheme,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Text(
                            '自定义系统提示词',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => setState(() => _promptCtrl.clear()),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 28),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('清空',
                                style: TextStyle(fontSize: 11.5)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '留空则使用内置提示词。填写的内容会追加在内置提示词之后，'
                        '用来补充你的习惯（比如「回答尽量短」「金额按分列出」）。',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _promptCtrl,
                        minLines: 5,
                        maxLines: 12,
                        decoration: const InputDecoration(
                          hintText: '例如：\n回答尽量简短，先给结论再列数据。\n金额一律保留两位小数。',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
                // 以下三项只对「自定义提供商」开放
                if (effectiveProviderId == AiProviders.customId) ...<Widget>[
                const SizedBox(height: 12),
                _card(
                  scheme,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(Icons.image_outlined,
                              size: 18, color: scheme.primary),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              '模型支持图片输入',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                          Switch(
                            value: _visionEnabled,
                            onChanged: (v) async {
                              setState(() => _visionEnabled = v);
                              await ref
                                  .read(settingsProvider.notifier)
                                  .mutate((st) => st.aiVisionEnabled = v);
                            },
                          ),
                        ],
                      ),
                      Text(
                        _visionEnabled
                            ? '开启后：你拍/选的图片会随问题一起发给模型，AI 能看着图回答。'
                                '需要模型本身支持视觉（如 gpt-4o、qwen-vl、glm-4v）。'
                            : '关闭时：图片只存在本地（当货物实拍留档），不发给模型 —— '
                                '避免不支持视觉的模型直接报 400。',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.55,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // 内置模型：能力由模型决定，不给改
                if (effectiveProviderId != AiProviders.customId) ...<Widget>[
                  const SizedBox(height: 12),
                  _card(
                    scheme,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(Icons.auto_awesome,
                                size: 16, color: scheme.primary),
                            const SizedBox(width: 7),
                            const Text(
                              '模型能力（自动）',
                              style: TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        _capRow(
                          scheme,
                          '上下文',
                          _currentModel(models)?.contextLabel ?? '—',
                          true,
                        ),
                        _capRow(
                          scheme,
                          '思考',
                          (_currentModel(models)?.supportsThinking ?? false)
                              ? '支持 · 自动开启'
                              : '不支持',
                          _currentModel(models)?.supportsThinking ?? false,
                        ),
                        _capRow(
                          scheme,
                          '图片',
                          (_currentModel(models)?.supportsVision ?? false)
                              ? '支持 · 自动开启'
                              : '不支持',
                          _currentModel(models)?.supportsVision ?? false,
                        ),
                        _capRow(scheme, '工具', '支持（必需）', true),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                _card(
                  scheme,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(Icons.psychology_outlined,
                              size: 18, color: scheme.primary),
                          const SizedBox(width: 8),
                          const Text(
                            '思考等级',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _thinkingLevel == 0
                            ? '关闭：直接回答，最快最省。'
                            : '开启后模型会先思考再回答，回答里会出现可展开的「思考过程」。'
                                '需要模型支持（o1/o3、deepseek-reasoner、QwQ 等），'
                                '不支持的模型可能报 400。',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.55,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<int>(
                        segments: const <ButtonSegment<int>>[
                          ButtonSegment<int>(value: 0, label: Text('关')),
                          ButtonSegment<int>(value: 1, label: Text('低')),
                          ButtonSegment<int>(value: 2, label: Text('中')),
                          ButtonSegment<int>(value: 3, label: Text('高')),
                        ],
                        selected: <int>{_thinkingLevel},
                        onSelectionChanged: (s) async {
                          setState(() => _thinkingLevel = s.first);
                          await ref.read(settingsProvider.notifier).mutate(
                                (st) => st.aiThinkingLevel = s.first,
                              );
                        },
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        showSelectedIcon: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  scheme,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        '上下文窗口',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '占用超过 70% 会自动把早期对话压成摘要，只保留最近 12 条原文。',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<int>(
                        segments: const <ButtonSegment<int>>[
                          ButtonSegment<int>(value: 4096, label: Text('4k')),
                          ButtonSegment<int>(value: 8192, label: Text('8k')),
                          ButtonSegment<int>(value: 16384, label: Text('16k')),
                          ButtonSegment<int>(value: 32768, label: Text('32k')),
                          ButtonSegment<int>(value: 131072, label: Text('128k')),
                        ],
                        selected: <int>{_windowTokens},
                        onSelectionChanged: (s) async {
                          setState(() => _windowTokens = s.first);
                          await ref
                              .read(settingsProvider.notifier)
                              .mutate((st) => st.contextWindowTokens = s.first);
                        },
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        showSelectedIcon: false,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: _windowCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                labelText: '自定义窗口（token）',
                                hintText: '$_windowTokens',
                                isDense: true,
                              ),
                              onSubmitted: (v) => _applyWindow(v),
                              onTapOutside: (_) {
                                FocusScope.of(context).unfocus();
                                _applyWindow(_windowCtrl.text);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            onPressed: () => _applyWindow(_windowCtrl.text),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(60, 44),
                            ),
                            child: const Text('应用'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ],
                const SizedBox(height: 16),
                Text(
                  '提示：AI 只读取本机的计件记录，不会上传数据；'
                  '照片（货物实拍）仅作为对话上下文发送，App 明确要求模型不做文字识别、不靠照片猜数字。',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.6,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }

  AiModelPreset? _currentModel(List<AiModelPreset> models) {
    for (final m in models) {
      if (m.id == _builtinModelId) return m;
    }
    return models.isEmpty ? null : models.first;
  }

  Widget _capRow(
    ColorScheme scheme,
    String label,
    String value,
    bool ok,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 48,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ),
          Icon(
            ok ? Icons.check_circle : Icons.remove_circle_outline,
            size: 12,
            color: ok ? const Color(0xFF0E9F6E) : scheme.outline,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 11, color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return '刚刚';
    if (d.inMinutes < 60) return '${d.inMinutes} 分钟前';
    if (d.inHours < 24) return '${d.inHours} 小时前';
    return '${d.inDays} 天前';
  }

  Widget _card(ColorScheme scheme, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1B1E24)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withAlpha(140)),
      ),
      child: child,
    );
  }
}
