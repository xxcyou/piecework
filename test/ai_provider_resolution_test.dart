import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/data/models/ai_provider.dart';
import 'package:piecework/data/services/ai_service.dart';
import 'package:piecework/providers/settings_providers.dart';

/// 回归测试：内置免费模型必须真的被用上。
///
/// 曾经的事故：聊天发送路径绕过 aiConfigProvider，直接读
/// `settings.aiBaseUrl / aiModel`（历史默认值 = api.openai.com + gpt-4o-mini），
/// 结果「设置里选了 Kilo 免费模型」→ 请求打到第三方；
/// 没填 Key 时还会误报「还没配置 AI 接口」。
void main() {
  group('内置提供商模型解析（防「设置选 A、实际跑 B」）', () {
    test('默认模型来自内置预设，1M 上下文 + 支持工具', () {
      final m = resolveBuiltinModel(
        preset: AiProviders.kilo,
        modelId: '',
      );
      expect(m, isNotNull);
      expect(m!.id, AiProviders.defaultModelId);
      expect(m.contextWindow, 1000000);
      expect(m.supportsTools, isTrue);
    });

    test('用户选中的预设模型原样生效', () {
      final m = resolveBuiltinModel(
        preset: AiProviders.kilo,
        modelId: 'nvidia/nemotron-3.5-super-vl:free',
      );
      expect(m!.id, 'nvidia/nemotron-3.5-super-vl:free');
      expect(m.supportsVision, isTrue);
    });

    test('上游目录新增的模型也原样生效，不能静默退回第一个', () {
      final cache = jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'inclusionai/ling-3.2-flash:free',
          'label': 'Ling 3.2 Flash',
          'contextWindow': 262000,
          'supportsThinking': true,
          'supportsTools': true,
        },
      ]);
      final m = resolveBuiltinModel(
        preset: AiProviders.kilo,
        modelId: 'inclusionai/ling-3.2-flash:free',
        cacheJson: cache,
      );
      expect(m!.id, 'inclusionai/ling-3.2-flash:free');
      expect(m.contextWindow, 262000);
      expect(m.supportsThinking, isTrue);
    });

    test('缓存缺失时也不改 id（给保守默认能力）', () {
      final m = resolveBuiltinModel(
        preset: AiProviders.kilo,
        modelId: 'some/new-free-model:free',
        cacheJson: '',
      );
      expect(m!.id, 'some/new-free-model:free');
      expect(m.supportsTools, isTrue);
      expect(m.contextWindow, greaterThan(0));
    });

    test('缓存 JSON 坏掉不抛异常', () {
      final m = resolveBuiltinModel(
        preset: AiProviders.kilo,
        modelId: 'x/y:free',
        cacheJson: '{not json',
      );
      expect(m!.id, 'x/y:free');
    });
  });

  group('内置提供商的请求目标', () {
    test('地址是 Kilo 网关，不是第三方 OpenAI', () {
      final cfg = AiConfig(
        baseUrl: AiProviders.kilo.baseUrl,
        apiKey: '',
        model: AiProviders.defaultModelId,
        requiresApiKey: false,
        providerId: AiProviders.kilo.id,
      );
      expect(cfg.baseUrl.contains('kilo'), isTrue);
      expect(cfg.baseUrl.contains('openai'), isFalse);
      expect(cfg.chatUrl, 'https://api.kilo.ai/api/gateway/chat/completions');
    });

    test('免 Key 也算配置完成（不再误报「还没配置 AI 接口」）', () {
      final cfg = AiConfig(
        baseUrl: AiProviders.kilo.baseUrl,
        apiKey: '',
        model: AiProviders.defaultModelId,
        requiresApiKey: false,
      );
      expect(cfg.isConfigured, isTrue);
    });

    test('界面上显示的模型名：内置用短名，自定义用 id', () {
      final builtin = AiConfig(
        baseUrl: AiProviders.kilo.baseUrl,
        apiKey: '',
        model: 'nvidia/nemotron-3-ultra-550b-a55b:free',
        modelLabel: 'Nemotron 3 Ultra 550B',
        providerName: 'Kilo（免费）',
        providerId: 'kilo',
        requiresApiKey: false,
      );
      expect(builtin.displayModel, 'Nemotron 3 Ultra 550B');
      expect(builtin.displayTarget, 'Kilo（免费） · Nemotron 3 Ultra 550B');

      final custom = AiConfig(
        baseUrl: 'https://api.example.com/v1',
        apiKey: 'sk-x',
        model: 'my-model',
        providerName: '自定义',
        providerId: 'custom',
      );
      expect(custom.displayModel, 'my-model');
      expect(custom.displayTarget, '自定义 · my-model');

      final empty = AiConfig(baseUrl: '', apiKey: '', model: '');
      expect(empty.displayModel, '');
    });

    test('自定义提供商没填 Key 时才算未配置', () {
      final cfg = AiConfig(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: '',
        model: 'gpt-4o-mini',
      );
      expect(cfg.isConfigured, isFalse);
    });
  });

  group('结构性约束：AiConfig 只能由白名单构造', () {
    /// 允许自己 new AiConfig 的地方：
    /// * ai_service.dart —— 定义处
    /// * settings_providers.dart —— 唯一解析入口 aiConfigProvider
    /// * ai_settings_page.dart —— 「测试连接」用输入框里的未保存值
    const allowed = <String>{
      'lib/data/services/ai_service.dart',
      'lib/providers/settings_providers.dart',
      'lib/ui/pages/ai_settings_page.dart',
    };

    test('别处再手搓 AiConfig 就是绕过提供商解析（本 bug 的成因）', () {
      final offenders = <String>[];
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final path = f.path.replaceAll(r'\', '/');
        if (allowed.contains(path)) continue;
        if (f.readAsStringSync().contains('AiConfig(')) offenders.add(path);
      }
      expect(offenders, isEmpty,
          reason: '这些文件绕过了 aiConfigProvider，内置免费模型会被静默换成第三方');
    });
  });
}
