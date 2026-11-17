import 'package:isar_community/isar.dart';

part 'app_setting.g.dart';

/// 全局设置。整库只有一行（仓储层保证单例）。
@collection
class AppSetting {
  Id id = Isar.autoIncrement;

  // ── AI 配置 ─────────────────────────────────────────────
  /// **自定义提供商**的接口地址，兼容 OpenAI 协议，例如：
  ///   https://api.openai.com/v1
  ///   https://api.deepseek.com/v1
  ///   http://192.168.1.10:8000/v1
  ///
  /// 内置提供商（aiProviderId = 'kilo'）**不使用**这个字段，
  /// 地址/模型由 AiProviders 里的预设固定。默认留空，
  /// 绝不要在这里塞第三方默认值 —— 否则内置模式会被悄悄带偏。
  String aiBaseUrl = '';

  // ── 云备份（WebDAV）──
  /// 服务器地址，例如 https://dav.example.com/remote.php/dav/files/me
  String webdavUrl = '';
  String webdavUser = '';
  String webdavPass = '';
  /// 远程目录，默认 /piecework/
  String webdavDir = '/piecework/';
  /// 总开关：开了才会自动把加密备份传到云端
  bool webdavEnabled = false;

  /// 自定义提供商的密钥；内置提供商免 Key，不用这个字段
  String aiApiKey = '';

  /// 自定义提供商的模型名；内置提供商请用 aiBuiltinModelId
  String aiModel = '';

  /// 自定义系统提示词；留空则使用内置默认提示词
  String aiSystemPrompt = '';

  // ── 外观 ────────────────────────────────────────────────
  /// 0 = 跟随系统, 1 = 亮色, 2 = 暗色
  int themeModeIndex = 0;

  // ── 报表 ────────────────────────────────────────────────
  /// 报表字号缩放（0.7 ~ 1.6）
  double reportFontScale = 1.0;

  String reportTitle = '计件明细报表';

  String reportSubtitle = '';

  /// 0 = 对外版（带缩略图）, 1 = 自用紧凑版
  int reportTemplate = 0;

  /// 对外版是否显示缩略图
  bool reportShowPhoto = true;

  /// 报表分组方式：0 = 按日期，1 = 按型号，2 = 不分组
  int reportGroupBy = 0;

  // ── 录入默认值 ───────────────────────────────────────────
  /// 新增记录时预填的单价（0 表示不预填）
  double defaultUnitPrice = 0;

  // ── 维护 ────────────────────────────────────────────────
  /// 上次备份时间（毫秒时间戳，0 表示从未备份）
  int lastBackupMs = 0;

  /// 当前对话会话 ID
  int chatSessionId = 1;

  /// 上下文窗口大小（token）。占用超过 70% 会自动压缩早期对话。
  int contextWindowTokens = 8192;

  /// 上游模型列表缓存（JSON）与时间戳
  String aiModelCacheJson = '';
  DateTime? aiModelCacheAt;

  /// 提供商 id：'kilo'（内置免费）或 'custom'
  String aiProviderId = 'kilo';

  /// 内置提供商的模型 id（自定义时留空，用 aiModel）
  String aiBuiltinModelId = 'nvidia/nemotron-3-ultra-550b-a55b:free';

  /// 思考等级：0=关 1=低 2=中 3=高（对应 reasoning_effort）
  int aiThinkingLevel = 0;

  /// 模型是否支持图片输入（多模态）。
  /// 关掉时照片只存本地（当货物实拍留档），不会塞进请求 —— 避免不支持 vision 的模型直接 400。
  bool aiVisionEnabled = false;
}
