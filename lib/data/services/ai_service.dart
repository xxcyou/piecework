import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import '../models/pending_action.dart';
import '../models/record_filter.dart';
import 'ai_tool_types.dart';
import 'ai_tools.dart';
import 'query_engine.dart';

/// AI 接口配置（来自设置页）
class AiConfig {
  const AiConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.systemPrompt = '',
    this.visionEnabled = false,
    this.thinkingLevel = 0,
    this.contextWindow = 8192,
    this.supportsTools = true,
    this.supportsStream = true,
    this.providerName = '',
    this.requiresApiKey = true,
    this.providerId = '',
    this.modelLabel = '',
  });

  final String baseUrl;
  final String apiKey;
  final String model;
  final String systemPrompt;

  /// 模型是否支持图片输入
  final bool visionEnabled;

  /// 思考等级：0=关 1=低 2=中 3=高
  final int thinkingLevel;

  /// 上下文窗口（token）
  final int contextWindow;

  /// 模型是否支持 function calling
  final bool supportsTools;

  /// 模型是否支持流式
  final bool supportsStream;

  /// 提供商显示名（Kilo / 自定义）
  final String providerName;

  /// 是否需要 API Key（内置 Kilo 免 Key，开箱即用）
  final bool requiresApiKey;

  /// 实际生效的提供商 id（'kilo' / 'custom'）
  final String providerId;

  /// 模型的友好显示名（内置模型有中文/英文短名；自定义模式为空，直接用 id）
  final String modelLabel;

  /// 界面上要显示的模型名：优先友好名，没有就退回 id
  String get displayModel =>
      modelLabel.trim().isEmpty ? model.trim() : modelLabel.trim();

  /// 界面上要显示的「提供商 · 模型」
  String get displayTarget {
    final m = displayModel.isEmpty ? '未配置模型' : displayModel;
    if (providerName.trim().isNotEmpty) return '$providerName · $m';
    return providerId.isEmpty ? m : '$providerId · $m';
  }

  bool get thinkingEnabled => thinkingLevel > 0;

  String get reasoningEffort =>
      <String>['', 'low', 'medium', 'high'][thinkingLevel.clamp(0, 3)];

  bool get isConfigured {
    if (baseUrl.trim().isEmpty || model.trim().isEmpty) return false;
    if (requiresApiKey && apiKey.trim().isEmpty) return false;
    return true;
  }

  /// 兼容用户填 `https://x/v1`、`https://x/v1/`、`https://x/v1/chat/completions` 三种写法
  String get chatUrl {
    var b = baseUrl.trim();
    while (b.endsWith('/')) {
      b = b.substring(0, b.length - 1);
    }
    if (b.endsWith('/chat/completions')) return b;
    return '$b/chat/completions';
  }
}

/// AI 一次完整回答的结果
class AiReply {
  const AiReply({
    required this.text,
    this.filter,
    this.groups,
    this.stats,
    this.pendingAction,
    this.pendingActions = const <PendingAction>[],
    this.traces = const <ToolTrace>[],
    this.uiActions = const <UiAction>[],
    this.agentTask,
    this.ask,
    this.svg,
    this.calc,
    this.code,
    this.photos = const <Map<String, dynamic>>[],
    this.svgs = const <SvgBlock>[],
    this.calcs = const <CalcTable>[],
    this.codes = const <CodeBlock>[],
    this.photoGroups = const <List<Map<String, dynamic>>>[],
    this.reasoning = '',
    this.numberWarning,
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
  });

  final String text;

  /// 本次回答涉及的筛选条件（有值就显示「查看这批记录」）
  final RecordFilter? filter;

  /// 分组汇总（有值就渲染统计表格）
  final List<GroupStat>? groups;

  /// 总计快照
  final Map<String, dynamic>? stats;

  /// 写操作提议（非空则界面上会出现「确认执行」卡片）
  final PendingAction? pendingAction;

  /// 一次回答里可能有多张确认卡片（改数量 + 关联图 + 删记录…）
  final List<PendingAction> pendingActions;

  /// 本次回答调用过的工具（渲染工具卡片）
  final List<ToolTrace> traces;

  /// 工具希望界面做的动作（跳页 / 应用筛选）
  final List<UiAction> uiActions;

  /// agent 任务（计划 / 进度 / 总结）
  final AgentTask? agentTask;

  /// AI 向用户的反问（带选项）
  final AskPrompt? ask;

  /// 展示类卡片
  final SvgBlock? svg;
  final CalcTable? calc;
  final CodeBlock? code;

  /// 本次回答要展示的图片卡片（第一组，兼容旧代码）
  final List<Map<String, dynamic>> photos;

  /// 一次回答里可能有多张同类卡片（3 张图 / 2 张计算过程…），全部保留
  final List<SvgBlock> svgs;
  final List<CalcTable> calcs;
  final List<CodeBlock> codes;
  final List<List<Map<String, dynamic>>> photoGroups;

  /// 模型思考过程（reasoning_content / reasoning）
  final String reasoning;

  /// 数字校验警告（非空说明 AI 报的数与数据库不一致）
  final String? numberWarning;

  /// 本次消耗 token（接口 usage 累加）
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
}

class AiException implements Exception {
  AiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 调用 OpenAI 兼容接口（/chat/completions + function calling）。
///
/// 关键设计：
/// * 模型**只拿到工具返回的 JSON**，拿不到原始数据库文件；
/// * 图片（货物实拍）以 base64 多模态消息发送，但系统提示词禁止识别文字、禁止靠照片猜数字；
/// * 每轮最多 5 次工具调用，防止模型陷入死循环烧 token。
class AiService {
  AiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String defaultSystemPrompt = '''
你是「计件助手」App 内的数据助理，服务对象是一位做服装计件的师傅。

【效率铁律 —— 用最少的往返把事办完】
0. 系统已注入「当前数据概览」（今天/本周/本月/未上报/最近型号）。
   这些数字**直接引用**，不要再调 query_records 查一遍。
1. 需要多个互不依赖的数据时，**一次性把所有工具调用发出来**（会并发执行），
   不要一轮一个慢慢来。例：同时查"本周总数"和"型号排行"。
2. 明细默认 12 条就够。用户没明确说"全部"就不要加 limit。
3. 已经查过的数据不要重复查；直接用上一轮结果。
4. 能用 aggregate_records 一次算完的，不要先 query_records 再自己加。

【数字铁律 —— 违反会导致虚报工钱，极其严重】
1. 回答里出现的**每一个**数字（条数、件数、金额），必须**逐字复制**工具返回的字段：
   - 条数 → `recordCount`
   - 件数 → `totalQuantity`（跨单位时用 `totalBaseQuantity`）
   - 金额 → `totalAmount`
   工具结果里有一块 `authoritative`，那就是唯一可信来源。
2. **绝对禁止心算**。不要写「20+30+45=95 件」这种式子，也不要对明细逐条求和。
   需要总数就直接抄 `authoritative` 里的值。
3. 工具返回 `truncated: true` 时，明细只返回了一部分，
   但 `recordCount` / `totalQuantity` / `totalAmount` 是**全量**统计 —— 报总数用它们，
   不要说「共 30 条」如果实际是 200 条。
4. 没调工具就不要给任何数字。不确定就说「我需要查一下」。
5. 金额保留工具给的精度，不要自己四舍五入或凑整。
6. 工具返回 `unpricedCount > 0` 时，说明**还有一部分没填单价**：
   报金额必须补一句「另有 N 条（共 M 件）未计价，没算进这个金额」，
   不要把「已知金额」说成「总工钱」。

【单位不能混算 —— 这条最容易出错，务必遵守】
6. 工具返回 `mixedUnits: true` 时，说明这批记录**混用了不同单位**（比如既有「件」又有「片」）：
   - `totalQuantity` 会是 `null`，因为「100 件 + 50 片」这种裸和**没有任何意义**；
   - 件数只能用 `totalBaseQuantity`（已经折算成基准单位）；
   - **平均单价只能用 `averagePricePerBaseUnit`**，绝对不要自己用 totalAmount ÷ totalQuantity。
7. 就算 `mixedUnits: false`，算平均也要用 `averagePricePerBaseUnit`，
   不要自己除法 —— 你的除法不可靠。
8. 提到数量时带上单位：「1280 件」，不要只写「1280」。
9. 用户质疑「件数怎么不对」「怎么算出 1300 多」时，**必须**调 `explain_conversion`
   逐条列出每条记录的原始数量/单位/折算值，不要自己解释或猜。
10. `explain_conversion` 返回 `consistent: false` 时，说明换算自洽性检查没过，
    直接告诉用户「换算有问题，已列出每条明细，请检查单位换算规则」，不要硬解释。

【数据来源】
你只能通过工具读取本机数据库里的计件记录。每条记录包含：款式型号、颜色、码数、数量、单件单价、小计金额、录入时间、备注。

**很多记录只有数量**：师傅常常只知道自己做了多少件，型号/颜色/码数/单价都不知道
（单价要等公司结算）。所以这些字段**为空是正常的**，不是数据出错：
- 空型号在汇总里会显示成「（未填）」；
- 单价为 0 表示**未计价**（不是白干），汇总里会单独给 `unpricedCount` / `unpricedQuantity`；
- 遇到这种记录**不要反复追问**，也不要说「数据不完整/异常」。
用户上传的照片是**货物本身的实拍**（方便他自己认货、回忆这批是什么），不是工票。
**不要识别照片里的任何文字**，也不要根据照片猜测数量、单价或款式编码。

【工作方式】
1. 任何涉及「有哪些记录 / 多少件 / 多少钱 / 哪些款式」的问题，必须先调用工具取数，绝不凭记忆或想象作答。
2. 问明细用 query_records；问汇总用 aggregate_records；不确定型号/颜色的准确写法时先调用 list_available_options。
3. 用户说「这个款式」「上周那批」等模糊指代时，结合上文对话里的筛选条件推断；推断不出来就反问一句。
4. 用简体中文回答，简洁直接。金额按工具给的精度原样输出（单价可能是 0.001 这种三位小数，不要自己凑成两位），件数用整数。
5. 汇总类回答给出：记录条数、总件数、总金额。分组时按件数从多到少分行列出。
6. 明细超过 10 条时只列前 10 条，并说明「还有 N 条，可在记录页查看」。
7. 不要使用 Markdown 标题（#），可以用 - 列表和 **加粗**。
8. 回答末尾不要重复数据来源说明。
9. 用户说「删掉 / 改一下 / 补录」时，你**可以**调用 delete_records / update_records / create_records。
   这些工具不会立即执行，只会在界面上生成一张确认卡片，等用户点确认才落库。
   所以你要在回答里明确说：「我准备删除 N 条（明细如下），请在下方卡片确认」。
10. 发起删除前，必须先用 query_records 看一眼范围，确认不是误伤。删除不可逆，宁可少删。
11. 用户口述「今天 A1023 黑色 M 码 30 件单价 12」这类内容时，用 create_records 批量录入。
    用户只说了「今天做了 300 件」这种，也一样用 create_records：
    `items: [{"quantity": 300}]` 就够，其他字段不传。
12. 用户说「没拍照片的那些」，用 query_records 并传 photo=no_photo。
13. 你能改设置（update_settings）、管单位（manage_units / set_unit_rule）、
    管选项（manage_options）、跳页面（open_page）、应用筛选（apply_filter）、
    做周期对比（compare_periods）、出排行榜（top_n）。
    用户说「换成暗色」「100 片 = 30 件」「打开报表」「本周比上周怎么样」
    「哪个款做得最多」时，直接调对应工具，不要反问他怎么做。
14. 改设置、加单位、配换算这类操作是**立即生效**的，做完回一句确认就行；
    只有删/改/新建**记录**才需要用户点确认卡片。

15. 你有一台「轻量级 Linux 终端」：调 `run_terminal` 执行 shell 命令。
    默认跑在**内置的 Alpine Linux**（proot 模拟，`env: "linux"`）：
    - 是真正的 Linux 用户态：busybox 全套（cat/grep/sed/awk/find/tar/wget…）、`apk add` 能装包；
    - 工作目录 `/root`，`id` 显示 root，但只影响这个隔离的 rootfs，动不了 Android 系统；
    - 适合：算数、处理文本、生成/转换文件、跑脚本、看环境信息；
    - 命令以 `@` 开头时，`run_terminal` 会直接执行你自己的工具：
      `@query_records {"date_preset":"this_week"}` 拿到工具 JSON；
      还能接管道：`@aggregate_records {"group_by":"styleModel"} | head -20`
      —— 一条调用里完成「取数 + 文本处理」，比先调工具再自己数更快。
    也可以 `env: "android"` 跑手机自带的 `/system/bin/sh`：只有 toybox 的少量命令，
    适合看 App 自己的目录、`getprop` 之类的设备信息。
    怎么用才不惹麻烦：
    - 命令写短，一次干一件事；linux 默认 30 秒超时，别跑 `top`、`tail -f`、`ping` 这种会挂住的；
    - 输出截断到 8000 字符，看尾部就 `| tail -n 50`；
    - `rm -rf /`、`pm uninstall`、`reboot`、`su`、`mount` 这类会被安全策略拦下，别反复试；
    - 只用来**查看、计算、生成**，不要拿它去改用户的数据或系统设置；
    - 首次调用 linux 会自动解压环境（1~3 秒），别当成卡住；
    - App 没有 Android 存储权限，`/sdcard/...` 读不到是正常的。

【图片与编号】
每张货物实拍都有一个**编号**（`#12`），图库里能看到，用户也可以长按复制编号。
- 用户说「把 #12 关联到这条」「看看 #12」时，用编号精确定位；
- **关联已有图不用重新上传**：`manage_photos` 传 `photo_id`（#12 传 12）即可，
  也可以用 `photo_name`；不知道编号就先 `manage_photos(action=list)` 或 `show_photos`；
- 想给用户看图时调 `show_photos`（可按编号、也可按型号/颜色/码数筛），
  它会在对话里渲染成**图片卡片**，用户点一下就能进对应记录；
- 不要凭空描述图片内容，也不要猜图里是什么款式。

【终端模式（用户自己也有一条终端）】
用户可以在输入框敲「/ 」（斜杠+空格）进入终端模式，那个界面里：
- 直接敲命令 → 跑在内置 Alpine Linux（proot）里，和你调 run_terminal 的环境一样；
- 敲 `@工具名 {json参数}` → **直接调用你手上的这些工具**（同一个执行器、同一份数据），
  例如 `@query_records {"date_preset":"this_week"}`、`@aggregate_records {"group_by":"styleModel"}`；
  `@工具名` 在 shell 里也是真命令（`/tmp/dsh-tool/bin/@xxx`），所以能写进
  `for t in dark light; do @update_settings {"theme":"\$t"}; done` 这种循环里；
- `@help` 列出可用工具；
- 写操作（新建/修改/删除记录、改设置、管单位）在终端里**也能用**：
  调完之后会生成一张确认卡片放进聊天，用户点「确认」才真正落库；
- 所以用户想在终端里改设置/删记录，你可以直接告诉他用 `@update_settings {...}`
  或 `@delete_records {...}`，不用拦着他。
所以：
- 用户问「能不能像命令行那样查」「有没有快捷方式」时，告诉他敲「/ 」进终端、
  用 `@工具名` 直接调工具；
- 用户在终端里跑出结果后贴给你看，直接基于那些数字回答，不要再自己查一遍；
- 不要把终端说成「另一个 AI」或「外部程序」——它是这个 App 自带的。

【多身份（重要）】
- 你看到的记录**只有当前身份卡**的数据，别的身份的账你根本看不到，也不要臆测；
- 新建记录会自动记到当前身份名下；用户说「记到张三头上」而当前身份不是张三时，
  告诉他要先切换身份卡（界面右上角），不要自己改归属；
- 回答里可以带上身份名（例如「张三本周 1,200 片」），方便对账。

【复制同款】
用户说「照昨天那条再来一条」「同款再来 300 片」时，**别让他重填**：
用 `create_records` 的 `copy_from_ids`（先 query_records 拿到 id），
型号/颜色/码数/单价/图片会照搬，再用 `set_quantity` / `set_date` 覆盖需要的字段。

【改录入时间】
`update_records` 支持 `set_date`（YYYY-MM-DD）和 `set_time`（HH:mm）：
- 用户说「把这条改到昨天」「这条是 10 号的」→ 传 `set_date`；
- 只想改时刻就传 `set_time`；两个都给就一起改；
- 只给 `set_date` 时，每条记录**原来的时刻会保留**，不用自己补 00:00。

【修改前的对比】
`update_records` 的确认卡上会自动画「修改前后」对比（数量/金额的双条形图 + 差值），
返回里也有 `diff` 数组。所以你只要点出**关键变化**就行，例如
「数量 300 → 350，金额多 ¥22.5」，不要把整张表再抄一遍。

【并行调用（能一起做就别一个一个来）】
- 互不依赖的**只读查询**可以**在同一条消息里一次发起多个工具调用**，
  系统会并行执行：例如同时查「本周汇总」和「本月汇总」、或一次要 3 张图表；
- 写操作（新建/修改/删除/关联图片）必须串行，一次一个，别混在并行里；
- 用户要「3 张图」「两张对比表」这种，就**调用 3 次**，每张卡都会单独显示，
  不要只画一张然后说"其余类似"。

【一条消息里有多个需求（很容易只做一半）】
用户经常一口气说三件事，例如「把昨天那批数量改成 300、顺便关联 #1 的图、再看看本周一共多少」。
- 先在脑子里把需求**拆成条目**，然后**逐个调用工具全部做完**，最后再统一总结；
- **不要**做完第一个就停下来汇报，也不要因为「已经生成确认卡片」就跳过剩下的需求；
- 写操作会各自生成一张确认卡片，几张卡片可以同时存在，用户逐个点确认；
- 某个需求确实缺信息时，用 ask_user 单独问那一个，**其它需求照样先做完**；
- 全部做完后，回答里按条目逐条说结果（做了什么、影响几条、还剩什么待确认）。

【展示卡片（该用就用，别只在正文里干说）】
你手上有三个「画卡片」的工具，用户能看到卡片本身，比正文里的纯文字清楚：
- `show_calculation`：**算数/对账**必须用它。把每一步写成
  `steps: [{"label":"本周件数","expression":"128 + 96","result":"224"}]`，
  正文里只给结论，不要重复算式；
- `render_svg`：用户要「画个图 / 趋势 / 占比」时用；
- `show_code`：要展示脚本或命令时用。
什么时候一定要用 show_calculation：用户问「怎么算出来的」「对得上吗」，
或者你做了两步以上的加减乘除 —— 别把算式埋在正文里，那样用户看不到卡片。

【筛选参数都是可选的（很容易踩的坑）】
- `query_records` / `aggregate_records` 的时间、型号、颜色、码数、数量区间、状态
  **全部可选**：不填就是「不限」。不要为了「写全」把所有参数都填上 ——
  多填一个条件就少一批数据，经常直接把结果筛成 0 条；
- `status` 不填 = **不限（含已上报）**；只有用户明确说「只看没上报的」才填 pending；
- 工具返回 `emptyReason` / `unfilteredRecordCount` 时，说明是**你的条件太窄**：
  去掉部分条件重查，**不要**直接告诉用户「没有记录」；
- 用户问「全部/一共/总共」时，就别带任何筛选（最多带时间范围）。

【单位口径（最容易说错的一条，务必照做）】
- **报数量时优先逐字引用工具返回的 `quantityText`**，例如
  「300 片（≈ 150 件）」——它已经把原单位、折算值都写好了，照抄就不会错；
- 没有 `quantityText` 时：`totalQuantity` 的单位是 `units` 里的那个（**不是件**），
  `totalBaseQuantity` 才是折算成 `baseUnit` 的数；
- **绝对禁止**把 `totalQuantity` 说成「件」：记录是「片」时 300 就是 300 片，
  折成件是 `totalBaseQuantity`（比如 150 件）；
- 用户看到数字对不上会立刻发现，宁可多写一句「≈ 150 件」，也不要只报一个错单位。

【反问要「问完就停」，以及用户跳过怎么办】
- 调用 `ask_user` 之后**必须停下来**：这一轮到此结束，等用户回答；
  不要在同一个回合里既提问又自己回答，也不要再调别的工具；
- 用户回答后（下一轮）再根据他的答案继续，**不要重复问同一个问题**；
- 用户点了「跳过」（你会看到一条 `（跳过这个问题，按你认为最合理的默认继续）`）：
  就**不要再问**，直接按最合理的默认往下做，并在回答开头用一句话说明
  你假设了什么（例如「没填型号，我按未分类记」）。

【信息不足时要反问，不要瞎猜也不要硬拒绝】
- 用户说「记一下今天的」但没说数量 → 调 `ask_user` 问数量（这是唯一必须知道的）。
- 用户只说数量、没说型号/颜色/码数/单价 → **直接记，不要追问**。
  这些字段留空就行，以后能补就补（界面上有「缺信息」筛选可以补录）。
  最多在回答末尾提一句「型号/单价没填，之后可以补」，不要连问三个问题。
- 用户说「把那个改一下」「上周那批」指代不明 → 问「你指的是哪批」，能列出候选就列。
- 用户提到的型号/颜色在库里不存在 → 问「是新建这个型号，还是你指的是 A1023？」
- 一次只问一个问题；能给出 2~6 个候选答案就放进 options，用户点一下就行。
- **不要为了反问而反问**：能从数据推断的（比如库里只有一种型号）就直接用，别问。
- 反问之后**停下来等**，不要自己编一个答案继续往下做。

【数量单位换算】
- 记录可能用「片 / 打」等非基准单位录入。回答时如果涉及这类记录，
  要同时给出折算后的数（例：「100 片 ≈ 50 件」）。
- `aggregate_records` 返回的 `baseQuantity` 就是折算后的基准单位数量，直接用，别自己算。

【上报状态（重要业务口径）】
- 每条记录有状态：`pending`（未上报，默认）/ `reported`（已上报公司）。
- **默认所有查询只看未上报的**。用户问「本周多少件」时，指的是还没上报的那部分。
- 用户说「这些我都上报了」→ 调 update_records 传 set_status: reported。
- 用户问「都上报了吗 / 已上报多少」→ 查询时传 status: all 或 reported。
- 已上报的记录默认不会出现在列表里，这是故意的，别当成数据丢了。

【图片能力（重要）】
15. 用户**发图 + 说「记一下 A1023 黑色 M 码 30 件」**时：直接调 create_records，
    记录会**自动关联这张图**（不需要额外操作）。
16. 用户说「把这张图关联到刚才那条 / XX 记录」→ 调 manage_photos(action: attach)，
    会自动匹配记录并关联。
17. 用户说「把照片删掉 / 解除图片关联」→ 调 manage_photos(action: detach)，
    会生成确认卡片，用户确认后才删文件。
18. 照片是货物实拍，用来认货/回忆，你**不靠照片猜数字**（数量、单价、件数一律以工具数据为准）；
    但可以把它关联到记录上当参考。别跟用户说「没这个功能」。

【执行协议 —— 你是一个会干活的助手，不是复读机】
先判断任务复杂度：

* 简单问题（一次查询就能答完）→ **直接查、直接答**，不要 plan_task。
  例：「本周多少件」「A1023 黑色 M 码有多少」「总工钱多少」

* 复杂任务（多步、要判断、要操作）→ **必须 plan_task**，让用户看到进度。
  例：「把这个月的账整理一下」「把上周那批单价改掉再重新汇总」
      「设置 100 片 = 30 件，然后检查折算对不对」「对比本周和上周，找出差距原因」

复杂任务的标准流程：
1. `plan_task` 列出 2~6 步（标题 10 字以内，用户会看到进度条）
2. 逐步执行，**每完成一步调 `step_done`**，result 写清结果（如「42 条 · 1,280 件」）
3. 全部做完调 `finish_task`：summary 一句话总结结论，followups 给 2~3 个用户可能想接着问的问题
4. 没调 finish_task 就不算完成，不要中途停下说「已完成」

执行时不要复述计划，直接干活；finish_task 之后再用一两句话交代结论。

【禁止】
- 不要编造不存在的记录。
- 不要在用户还没点确认时就声称「已删除」「已修改」—— 你只能说你准备了什么操作。
- 不要一次删除超过 50 条；超过就先跟用户确认是不是真要全删。
''';

  /// 发一次完整提问（可能包含多轮工具调用）
  Future<AiReply> ask({
    required AiConfig config,
    required List<ChatMessage> history,
    required String userText,
    required AiToolExecutor executor,
    Uint8List? imageBytes,
    String historySummary = '',
    int maxRounds = 12,
    int historyLimit = 12,
    void Function(String contentDelta, String reasoningDelta)? onDelta,
    void Function()? onTurnStart,
    /// 工具进度：label=中文名，count=本次回答累计调用了几次工具
    void Function(String toolLabel, int count)? onToolHint,
    bool Function()? isCancelled,
    String dataDigest = '',
  }) async {
    if (!config.isConfigured) {
      throw AiException('还没配置 AI 接口。请到「设置 → AI 助手」填写接口地址、密钥和模型名称。');
    }

    final systemPrompt = config.systemPrompt.trim().isEmpty
        ? defaultSystemPrompt
        : '$defaultSystemPrompt\n\n【用户自定义补充要求】\n${config.systemPrompt.trim()}';

    // 把「库里实际有哪些型号/颜色/码数」直接写进 system，减少模型瞎猜
    final snapshot = executor.optionsSnapshot();
    final optionHint = StringBuffer()
      ..writeln()
      ..writeln('【当前可选值（来自设置页维护的列表）】')
      ..writeln('型号：${_join(snapshot['styleModels'])}')
      ..writeln('颜色：${_join(snapshot['colors'])}')
      ..writeln('码数：${_join(snapshot['sizes'])}');

    final messages = <Map<String, dynamic>>[
      <String, dynamic>{
        'role': 'system',
        'content': '$systemPrompt$optionHint$dataDigest',
      },
    ];

    // 早期对话的压缩摘要（长会话靠它省 token）
    if (historySummary.trim().isNotEmpty) {
      messages.add(<String, dynamic>{
        'role': 'system',
        'content': '【早期对话摘要】\n${historySummary.trim()}',
      });
    }

    // 历史只取最近 N 条纯文本（不带图，避免 token 爆炸）
    final recent = history.length > historyLimit
        ? history.sublist(history.length - historyLimit)
        : history;
    for (final h in recent) {
      // 终端卡片正文是空的，但里面的命令与输出必须让模型看到，
      // 否则「我刚在终端里做过什么」它一无所知。
      final isTerminal = h.content.trim().isEmpty &&
          terminalTranscript(h.toolsJson) != null;
      final isAsk = h.content.trim().isEmpty &&
          !isTerminal &&
          askTranscript(h.toolsJson) != null;
      final text = h.content.trim().isNotEmpty
          ? h.content
          : (terminalTranscript(h.toolsJson) ??
              askTranscript(h.toolsJson) ??
              '');
      if (text.trim().isEmpty) continue;
      messages.add(<String, dynamic>{
        // 终端记录是「用户自己敲的」→ user；
        // 反问是「我说过的话」→ assistant（这样模型知道是自己问的，不会重复问）
        'role': isTerminal ? 'user' : (isAsk ? 'assistant' : (h.isUser ? 'user' : 'assistant')),
        'content': text,
      });
    }

    // 当前这一问
    final question = userText.trim();
    final hasImage = imageBytes != null && imageBytes.isNotEmpty;

    if (hasImage && config.visionEnabled) {
      // 模型支持看图：走多模态消息
      messages.add(<String, dynamic>{
        'role': 'user',
        'content': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'text',
            'text': question.isEmpty ? '这是我拍的照片，请结合本机记录回答我的问题。' : question,
          },
          <String, dynamic>{
            'type': 'image_url',
            'image_url': <String, dynamic>{
              'url': 'data:image/jpeg;base64,${base64Encode(imageBytes)}',
            },
          },
        ],
      });
    } else if (hasImage) {
      // 模型不支持看图：照片只存本地，不塞进请求（否则很多模型直接 400）
      messages.add(<String, dynamic>{
        'role': 'user',
        'content': '${question.isEmpty ? "我发了一张照片，帮我记一下。" : question}'
            '\n\n（用户同时发了一张货物实拍，已存到本机。当前模型未开启图片输入，'
            '你看不到图像内容，不要猜测照片里有什么。）',
      });
    } else {
      if (question.isEmpty) throw AiException('请输入问题，或先说一句想查什么。');
      messages.add(<String, dynamic>{'role': 'user', 'content': question});
    }

    RecordFilter? lastFilter;
    List<GroupStat>? lastGroups;
    Map<String, dynamic>? lastStats;
    PendingAction? lastAction;
    final traces = <ToolTrace>[];
    final actions = <UiAction>[];
    final pendingActions = <PendingAction>[];
    var lastContent = '';
    var toolCallCount = 0;
    // 同类卡片可能有多张（画 3 张图、算 2 次），全部收集
    final svgs = <SvgBlock>[];
    final calcs = <CalcTable>[];
    final codes = <CodeBlock>[];
    final photoGroups = <List<Map<String, dynamic>>>[];
    AgentTask? lastTask;
    AskPrompt? lastAsk;
    final reasoningBuf = StringBuffer();
    var promptTokens = 0;
    var completionTokens = 0;
    var totalTokens = 0;

    for (var round = 0; round < maxRounds; round++) {
      // 用户点了停止
      if (isCancelled?.call() == true) {
        return AiReply(
          text: reasoningBuf.isEmpty ? '' : '',
          filter: lastFilter,
          groups: lastGroups,
          stats: lastStats,
          reasoning: reasoningBuf.toString(),
          traces: traces,
          uiActions: actions,
          agentTask: lastTask,
          ask: lastAsk,
          svg: svgs.isEmpty ? null : svgs.first,
          calc: calcs.isEmpty ? null : calcs.first,
          code: codes.isEmpty ? null : codes.first,
          photos: photoGroups.isEmpty ? const <Map<String, dynamic>>[] : photoGroups.first,
          svgs: svgs,
          calcs: calcs,
          codes: codes,
          photoGroups: photoGroups,
        );
      }

      final payload = <String, dynamic>{
        'model': config.model,
        'messages': messages,
        'temperature': 0.2,
        'tools': AiTools.schema,
        'tool_choice': 'auto',
        // 只有明确开启时才带，避免不支持思考的模型直接 400
        if (config.thinkingEnabled) 'reasoning_effort': config.reasoningEffort,
      };

      // 新一轮开始：清空上一轮的流式缓冲
      onTurnStart?.call();

      // 优先走流式；接口不支持时自动回退到整包
      final turn = await _streamOnce(
        config,
        payload,
        onDelta: onDelta,
        onToolName: (n) => onToolHint?.call(n, toolCallCount),
        isCancelled: isCancelled,
        fallback: () => _postJson(config, payload),
      );

      promptTokens += turn.promptTokens;
      completionTokens += turn.completionTokens;
      totalTokens += turn.totalTokens;

      final reasoning = turn.reasoning;
      if (reasoning.trim().isNotEmpty) {
        if (reasoningBuf.isNotEmpty) reasoningBuf.write('\n');
        reasoningBuf.write(reasoning.trim());
      }

      final toolCalls = turn.toolCalls;
      final content = turn.content.trim();
      if (content.isNotEmpty) lastContent = content;

      if (toolCalls.isEmpty) {
        return AiReply(
          text: content.isEmpty ? '（模型没有返回内容）' : content,
          filter: lastFilter,
          groups: lastGroups,
          stats: lastStats,
          pendingAction: lastAction,
          traces: traces,
          uiActions: actions,
          agentTask: lastTask,
          ask: lastAsk,
          svg: svgs.isEmpty ? null : svgs.first,
          calc: calcs.isEmpty ? null : calcs.first,
          code: codes.isEmpty ? null : codes.first,
          photos: photoGroups.isEmpty ? const <Map<String, dynamic>>[] : photoGroups.first,
          svgs: svgs,
          calcs: calcs,
          codes: codes,
          photoGroups: photoGroups,
          reasoning: reasoningBuf.toString(),
          // 数字校验暂时停用：误报多，用户明确要求去掉弹窗式警告。
          // 防错主要靠工具返回的 authoritative 块 + 提示词铁律。
          numberWarning: null,
          promptTokens: promptTokens,
          completionTokens: completionTokens,
          totalTokens: totalTokens,
        );
      }

      // 把 assistant 的 tool_calls 回填，否则下一轮 tool 消息会因缺少配对而被拒
      messages.add(<String, dynamic>{
        'role': 'assistant',
        'content': content,
        'tool_calls': toolCalls,
      });

      // ① 先把工具调用全部解析出来
      final parsed =
          <({Map<String, dynamic> call, String name, Map<String, dynamic> args})>[];

      for (final tc in toolCalls) {
        final fn = tc['function'];
        final name = (fn is Map ? fn['name'] as String? : null) ?? '';
        final rawArgs =
            (fn is Map ? fn['arguments'] as String? : null) ?? '{}';

        Map<String, dynamic> args = <String, dynamic>{};
        var ok = true;
        try {
          final decoded = jsonDecode(rawArgs);
          if (decoded is Map<String, dynamic>) {
            args = decoded;
          } else if (decoded is Map) {
            args = decoded.map((k, v) => MapEntry(k.toString(), v));
          }
        } catch (_) {
          ok = false;
          messages.add(<String, dynamic>{
            'role': 'tool',
            'tool_call_id': tc['id'],
            'content': jsonEncode(<String, dynamic>{
              'ok': false,
              'error': '参数不是合法 JSON：$rawArgs',
            }),
          });
        }
        if (ok) parsed.add((call: tc, name: name, args: args));
      }

      // ② 纯查询类并发跑；带副作用的必须串行（顺序不能乱）
      const parallelSafe = <String>{
        'query_records',
        'aggregate_records',
        'top_n',
        'compare_periods',
        'explain_conversion',
        'check_anomalies',
        'find_duplicates',
        'list_operations',
        'get_settings',
        'list_available_options',
        'unit_convert',
        'predict_income',
      };

      final canParallel = parsed.length > 1 &&
          parsed.every((e) => parallelSafe.contains(e.name));
      final outcomes = <({Map<String, dynamic> call, ToolOutcome outcome})>[];

      if (canParallel) {
        toolCallCount += parsed.length;
        onToolHint?.call('${parsed.length} 个查询', toolCallCount);
        final results = await Future.wait(
          parsed.map((e) => executor.execute(e.name, e.args)),
        );
        for (var i = 0; i < parsed.length; i++) {
          outcomes.add((call: parsed[i].call, outcome: results[i]));
        }
      } else {
        for (final e in parsed) {
          if (isCancelled?.call() == true) break;
          toolCallCount += 1;
          onToolHint?.call(e.name, toolCallCount);
          final outcome = await executor.execute(e.name, e.args);
          outcomes.add((call: e.call, outcome: outcome));
        }
      }

      // ③ 统一处理结果
      for (final item in outcomes) {
        final tc = item.call;
        final outcome = item.outcome;

        if (outcome.filter != null) lastFilter = outcome.filter;
        if (outcome.groups != null) lastGroups = outcome.groups;
        if (outcome.stats != null) lastStats = outcome.stats;
        if (outcome.pendingAction != null) {
          lastAction = outcome.pendingAction;
          // 一条消息可能有多个写操作（改数量 + 关联图…），全部收下，
          // 否则用户只会看到最后一张确认卡片
          final a = outcome.pendingAction!;
          final dup = pendingActions.any(
            (p) => p.kind == a.kind && listEquals(p.ids, a.ids),
          );
          if (!dup) pendingActions.add(a);
        }
        if (outcome.trace != null) traces.add(outcome.trace!);
        if (outcome.uiActions.isNotEmpty) actions.addAll(outcome.uiActions);
        if (outcome.agentTask != null) lastTask = outcome.agentTask;

        if (outcome.ask != null) {
          lastAsk = outcome.ask;
          // 反问 = 流程暂停，等用户回答
          return AiReply(
            text: content,
            filter: lastFilter,
            groups: lastGroups,
            stats: lastStats,
            traces: traces,
            uiActions: actions,
            agentTask: lastTask,
            ask: lastAsk,
            pendingActions: pendingActions,
            reasoning: reasoningBuf.toString(),
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            totalTokens: totalTokens,
          );
        }

        if (outcome.svg != null) svgs.add(outcome.svg!);
        if (outcome.calc != null) calcs.add(outcome.calc!);
        if (outcome.code != null) codes.add(outcome.code!);
        if (outcome.photos.isNotEmpty) photoGroups.add(outcome.photos);

        messages.add(<String, dynamic>{
          'role': 'tool',
          'tool_call_id': tc['id'],
          'content': jsonEncode(outcome.json),
        });
      }
    }

    return AiReply(
      // 轮数用完时：有正文就照实返回（别丢掉已经做完的部分），
      // 没有正文才提示拆分
      text: lastContent.isNotEmpty
          ? lastContent
          : '这件事需要更多轮推理才做得完。可以拆成两三个小问题再问一次，'
              '我会接着做。',
      filter: lastFilter,
      groups: lastGroups,
      stats: lastStats,
      pendingAction: lastAction,
      pendingActions: pendingActions,
      traces: traces,
      uiActions: actions,
      agentTask: lastTask,
      ask: lastAsk,
      svg: svgs.isEmpty ? null : svgs.first,
      calc: calcs.isEmpty ? null : calcs.first,
      code: codes.isEmpty ? null : codes.first,
      svgs: svgs,
      calcs: calcs,
      codes: codes,
      photoGroups: photoGroups,
      reasoning: reasoningBuf.toString(),
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: totalTokens,
    );
  }

  /// 把一段历史对话压缩成事实摘要（用于长会话的上下文压缩）。
  ///
  /// 不传 tools，纯文本总结。保留：筛选条件、关键数字、用户偏好、未完成待办。
  Future<String> compressHistory({
    required AiConfig config,
    required List<ChatMessage> messages,
    String previousSummary = '',
  }) async {
    if (messages.isEmpty) return previousSummary;

    final body = messages
        .map((m) => '${m.isUser ? "用户" : "助手"}：${m.content}')
        .join('\n');

    final input = previousSummary.isEmpty
        ? body
        : '已有摘要：\n$previousSummary\n\n新增对话：\n$body';

    final data = await _postJson(config, <String, dynamic>{
      'model': config.model,
      'messages': <Map<String, dynamic>>[
        <String, dynamic>{
          'role': 'system',
          'content': '把这段「计件助手」对话压缩成 200 字以内的事实摘要。'
              '必须保留：查询条件（时间范围/型号/颜色/码数）、关键数字（件数/金额）、'
              '用户偏好、未完成的待办。不要编造，不要加评论，不要用列表符号。',
        },
        <String, dynamic>{'role': 'user', 'content': input},
      ],
      'temperature': 0.1,
    });

    final choices = data['choices'];
    if (choices is List && choices.isNotEmpty) {
      final msg = (choices.first as Map)['message'];
      if (msg is Map) {
        final text = (msg['content'] as String?)?.trim() ?? '';
        if (text.isNotEmpty) return text;
      }
    }
    return previousSummary;
  }

  /// 连通性测试：发一条最小请求，验证地址 / 密钥 / 模型是否可用。
  /// 成功返回一句人话，失败抛 [AiException]。
  Future<String> ping(AiConfig config) async {
    if (!config.isConfigured) {
      throw AiException('配置不完整：地址、密钥、模型都要填。');
    }
    final data = await _postJson(config, <String, dynamic>{
      'model': config.model,
      'messages': <Map<String, dynamic>>[
        <String, dynamic>{'role': 'user', 'content': 'ping'},
      ],
      'max_tokens': 8,
    });
    final choices = data['choices'];
    if (choices is List && choices.isNotEmpty) {
      return '连接正常，模型可用。';
    }
    return '接口有响应，但返回结构不符合 OpenAI 规范。';
  }

  /// 一次流式请求。
  ///
  /// SSE 解析规则：
  /// * 每行 `data: {...}` 是一帧，`data: [DONE]` 结束；
  /// * 正文在 `choices[0].delta.content`；
  /// * 思考在 `delta.reasoning_content`（DeepSeek）或 `delta.reasoning`（OpenAI）；
  /// * 工具调用是**分片**到达的，按 `delta.tool_calls[i].index` 拼接。
  ///
  /// 如果接口不认 `stream: true`（返回 4xx），自动回退到整包请求。
  Future<_Turn> _streamOnce(
    AiConfig config,
    Map<String, dynamic> payload, {
    void Function(String contentDelta, String reasoningDelta)? onDelta,
    void Function(String toolLabel)? onToolName,
    bool Function()? isCancelled,
    required Future<Map<String, dynamic>> Function() fallback,
  }) async {
    final uri = Uri.tryParse(config.chatUrl);
    if (uri == null || !uri.hasScheme) {
      throw AiException('接口地址格式不对：${config.baseUrl}');
    }

    // 模型声明不支持流式 → 直接整包，别浪费一次失败往返
    if (!config.supportsStream) {
      final data = await fallback();
      return _turnFromWhole(data);
    }

    http.StreamedResponse resp;
    try {
      final req = http.Request('POST', uri)
        ..headers.addAll(<String, String>{
          'Content-Type': 'application/json; charset=utf-8',
          // 空 Key 就别发这个头 —— 有些网关会当成「无效凭证」直接 401
          if (config.apiKey.trim().isNotEmpty)
            'Authorization': 'Bearer ${config.apiKey.trim()}',
          'Accept': 'text/event-stream',
        })
        ..bodyBytes = utf8.encode(jsonEncode(<String, dynamic>{
          ...payload,
          'stream': true,
          // 让部分服务在流末尾附带 usage
          'stream_options': <String, dynamic>{'include_usage': true},
        }));

      resp = await _client
          .send(req)
          .timeout(const Duration(seconds: 100));
    } on TimeoutException {
      throw AiException('请求超时（100 秒）。检查网络，或换一个更快的模型。');
    } catch (e) {
      throw AiException('网络请求失败：$e');
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final body = await resp.stream.bytesToString();
      // 不支持流式 → 回退整包
      if (resp.statusCode == 400 ||
          resp.statusCode == 422 ||
          resp.statusCode == 404) {
        final data = await fallback();
        return _turnFromWhole(data);
      }
      throw AiException(_describeHttpError(resp.statusCode, body));
    }

    final content = StringBuffer();
    final reasoning = StringBuffer();
    final calls = <int, _ToolCallAcc>{};
    var promptTokens = 0;
    var completionTokens = 0;
    var totalTokens = 0;
    var gotAny = false;

    try {
      // allowMalformed: SVG/长文本流里可能被切断在多字节字符中间，
      // 严格解码会直接抛 FormatException（就是「流式解析失败」的来源）
      await for (final line in resp.stream
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())) {
        // 停止键：立刻断开，保留已收到的内容
        if (isCancelled?.call() == true) break;
        final trimmed = line.trim();
        if (trimmed.isEmpty || !trimmed.startsWith('data:')) continue;

        final data = trimmed.substring(5).trim();
        if (data == '[DONE]') break;

        dynamic decoded;
        try {
          decoded = jsonDecode(data);
        } catch (_) {
          continue;
        }
        if (decoded is! Map) continue;
        gotAny = true;

        final usage = decoded['usage'];
        if (usage is Map) {
          promptTokens = (usage['prompt_tokens'] as num?)?.toInt() ?? promptTokens;
          completionTokens =
              (usage['completion_tokens'] as num?)?.toInt() ?? completionTokens;
          totalTokens =
              (usage['total_tokens'] as num?)?.toInt() ?? totalTokens;
        }

        final choices = decoded['choices'];
        if (choices is! List || choices.isEmpty) continue;
        final delta = (choices.first as Map)['delta'];
        if (delta is! Map) continue;

        final c = (delta['content'] as String?) ?? '';
        final r = ((delta['reasoning_content'] ?? delta['reasoning'])
                as String?) ??
            '';
        if (c.isNotEmpty) content.write(c);
        if (r.isNotEmpty) reasoning.write(r);
        if (c.isNotEmpty || r.isNotEmpty) {
          onDelta?.call(c, r);
        }

        final tc = delta['tool_calls'];
        if (tc is List) {
          for (final item in tc) {
            if (item is! Map) continue;
            final idx = (item['index'] as num?)?.toInt() ?? 0;
            final acc = calls.putIfAbsent(idx, _ToolCallAcc.new);
            final id = item['id'] as String?;
            if (id != null && id.isNotEmpty) acc.id = id;
            final fn = item['function'];
            if (fn is Map) {
              final name = fn['name'] as String?;
              if (name != null && name.isNotEmpty) {
                final isNew = acc.name.isEmpty;
                acc.name = name;
                // 模型开始输出某个工具调用 → 立刻告诉界面
                if (isNew) onToolName?.call(name);
              }
              final args = fn['arguments'] as String?;
              if (args != null && args.isNotEmpty) acc.args.write(args);
            }
          }
        }
      }
    } on TimeoutException {
      // 超时但有内容 → 用已有的，不打断
      if (content.isEmpty && reasoning.isEmpty && calls.isEmpty) {
        throw AiException('流式读取超时。');
      }
    } catch (e) {
      if (!gotAny && content.isEmpty && reasoning.isEmpty && calls.isEmpty) {
        // 一帧都没收到 → 当作不支持流式，回退整包
        final data = await fallback();
        return _turnFromWhole(data);
      }
      // 收到过内容 → 保留已有部分，不再抛「解析失败」
      // （绘图这类长输出最容易在中间断，硬抛会让用户白等）
    }

    final toolCalls = <Map<String, dynamic>>[
      for (final e in (calls.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key))))
        <String, dynamic>{
          'id': e.value.id,
          'type': 'function',
          'function': <String, dynamic>{
            'name': e.value.name,
            'arguments': e.value.args.toString(),
          },
        },
    ];

    return _Turn(
      content: content.toString(),
      reasoning: reasoning.toString(),
      toolCalls: isCancelled?.call() == true
          ? const <Map<String, dynamic>>[]
          : toolCalls,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: totalTokens,
    );
  }

  /// 整包响应 → 统一的 _Turn
  _Turn _turnFromWhole(Map<String, dynamic> data) {
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) {
      throw AiException('接口没有返回 choices，请检查模型名称是否正确。');
    }
    final message = (choices.first as Map)['message'];
    if (message is! Map) {
      throw AiException('接口返回的 message 格式异常。');
    }
    final usage = data['usage'];
    return _Turn(
      content: (message['content'] as String?) ?? '',
      reasoning: ((message['reasoning_content'] ?? message['reasoning'])
              as String?) ??
          '',
      toolCalls: (message['tool_calls'] as List?)
              ?.whereType<Map>()
              .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
              .toList() ??
          const <Map<String, dynamic>>[],
      promptTokens: (usage is Map ? (usage['prompt_tokens'] as num?)?.toInt() : 0) ?? 0,
      completionTokens:
          (usage is Map ? (usage['completion_tokens'] as num?)?.toInt() : 0) ?? 0,
      totalTokens:
          (usage is Map ? (usage['total_tokens'] as num?)?.toInt() : 0) ?? 0,
    );
  }

  Future<Map<String, dynamic>> _postJson(
    AiConfig config,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.tryParse(config.chatUrl);
    if (uri == null || !uri.hasScheme) {
      throw AiException('接口地址格式不对：${config.baseUrl}');
    }

    http.Response resp;
    try {
      resp = await _client
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json; charset=utf-8',
              // 空 Key 就别发这个头 —— 有些网关会当成「无效凭证」直接 401
          if (config.apiKey.trim().isNotEmpty)
            'Authorization': 'Bearer ${config.apiKey.trim()}',
              'Accept': 'application/json',
            },
            body: utf8.encode(jsonEncode(body)),
          )
          .timeout(const Duration(seconds: 100));
    } on TimeoutException {
      throw AiException('请求超时（100 秒）。检查网络，或换一个更快的模型。');
    } catch (e) {
      throw AiException('网络请求失败：$e');
    }

    final text = utf8.decode(resp.bodyBytes, allowMalformed: true);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw AiException(_describeHttpError(resp.statusCode, text));
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      throw AiException('接口返回的不是 JSON：${_brief(text)}');
    }

    if (decoded is! Map) {
      throw AiException('接口返回结构异常：${_brief(text)}');
    }
    final map = decoded.map((k, v) => MapEntry(k.toString(), v));

    if (map['error'] != null) {
      throw AiException('接口报错：${_brief(jsonEncode(map['error']))}');
    }
    return map;
  }

  String _describeHttpError(int code, String body) {
    final brief = _brief(body);
    switch (code) {
      case 401:
        return '密钥无效或未授权（401）。检查 API Key。\n$brief';
      case 403:
        return '访问被拒绝（403）。密钥可能没有该模型的权限。\n$brief';
      case 404:
        return '接口地址不存在（404）。确认地址以 /v1 结尾，且服务端支持 /chat/completions。\n$brief';
      case 400:
      case 422:
        return '请求被拒绝（$code）。常见原因：模型不支持 function calling / tools，'
            '或参数不被接受。换一个支持工具调用的模型试试。\n$brief';
      case 429:
        return '请求太频繁或额度用尽（429）。\n$brief';
      default:
        if (code >= 500) return '服务端错误（$code）。稍后再试。\n$brief';
        return '请求失败（$code）。\n$brief';
    }
  }

  static String _brief(String s) {
    final one = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return one.length <= 400 ? one : '${one.substring(0, 400)}…';
  }

  static String _join(List<String>? v) =>
      (v == null || v.isEmpty) ? '（暂无）' : v.join('、');

  void dispose() => _client.close();
}


/// 一次流式请求的结果
class _Turn {
  const _Turn({
    required this.content,
    required this.reasoning,
    required this.toolCalls,
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
  });

  final String content;
  final String reasoning;
  final List<Map<String, dynamic>> toolCalls;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
}

/// 工具调用的分片累加器
class _ToolCallAcc {
  String id = '';
  String name = '';
  final StringBuffer args = StringBuffer();
}
