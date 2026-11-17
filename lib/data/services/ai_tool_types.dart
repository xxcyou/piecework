import 'dart:convert';

import '../models/app_setting.dart';
import '../models/operation_log.dart';
import '../models/option_item.dart';
import '../models/piece_record.dart';
import '../models/record_filter.dart';
import '../models/unit_item.dart';
import '../models/unit_rule.dart';


/// 解析「@工具名 {json} [| 管道]」这类命令（AI 终端和用户终端共用）。
///
/// * `name` —— 工具名（小写）
/// * `args` —— 参数；`null` 表示给了参数但不是 JSON 对象
/// * `rawArgs` —— 原始参数文本
/// * `pipeline` —— `|` 之后的管道部分（含 `|`），没有则为空串
({String name, Map<String, dynamic>? args, String rawArgs, String pipeline})
    parseToolCommand(String expr) {
  final text = expr.trim();
  if (text.isEmpty) {
    return (name: '', args: const {}, rawArgs: '', pipeline: '');
  }

  var head = text;
  var pipeline = '';
  final bar = _findPipelineBar(text);
  if (bar > 0) {
    head = text.substring(0, bar).trim();
    pipeline = text.substring(bar).trim();
  }

  final space = head.indexOf(RegExp(r'\s'));
  if (space < 0) {
    return (
      name: head.toLowerCase(),
      args: const {},
      rawArgs: '',
      pipeline: pipeline,
    );
  }
  final name = head.substring(0, space).toLowerCase();
  final raw = head.substring(space + 1).trim();
  if (raw.isEmpty) {
    return (name: name, args: const {}, rawArgs: '', pipeline: pipeline);
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return (
        name: name,
        args: decoded.map((k, v) => MapEntry(k.toString(), v)),
        rawArgs: raw,
        pipeline: pipeline,
      );
    }
  } catch (_) {
    // 落到下面返回 args: null
  }
  return (name: name, args: null, rawArgs: raw, pipeline: pipeline);
}

/// 找「参数结束后的第一个 `|`」：跳过 JSON 字符串里的竖线
int _findPipelineBar(String text) {
  var inString = false;
  var depth = 0;
  var escaped = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (ch == '\\') {
        escaped = true;
      } else if (ch == '"') {
        inString = false;
      }
      continue;
    }
    if (ch == '"') {
      inString = true;
      continue;
    }
    if (ch == '{' || ch == '[') depth++;
    if (ch == '}' || ch == ']') depth--;
    if (ch == '|' && depth <= 0) return i;
  }
  return -1;
}

/// 把一条「终端会话卡片」渲染成给模型看的纯文本。
///
/// 终端卡片正文是空的（内容是 toolsJson.terminal），如果不做这一步，
/// AI 就完全不知道用户刚才在终端里干了什么。这里把它拼成
/// 「$ 命令 / 输出」的流水账，作为对话历史的一部分喂给模型。
///
/// 太长时**保留最近的操作**（末尾），并在开头注明截断。
String? terminalTranscript(String toolsJson, {int maxChars = 2000}) {
  if (toolsJson.trim().isEmpty) return null;
  Object? raw;
  try {
    raw = jsonDecode(toolsJson);
  } catch (_) {
    return null;
  }
  if (raw is! Map) return null;
  final term = raw['terminal'];
  if (term is! Map) return null;
  final lines = term['lines'];
  if (lines is! List || lines.isEmpty) return null;

  final env = (term['env'] as String?) ?? 'linux';
  final buf = StringBuffer()
    ..writeln('【用户刚在终端里手动执行过命令（环境：$env）】')
    ..writeln('（这是他自己的操作记录，回答时可以直接引用，不用重新执行）');

  for (final item in lines) {
    if (item is String) {
      buf.writeln(item);
      continue;
    }
    if (item is! Map) continue;
    final text = (item['text'] as String?) ?? '';
    if (text.isEmpty) continue;
    buf.writeln(text);
  }

  var out = buf.toString().trimRight();
  if (out.length > maxChars) {
    out = '…（更早的输出已省略）\n'
        '${out.substring(out.length - maxChars)}';
  }
  return out;
}

/// 把一条「反问卡片」渲染成给模型看的文本。
///
/// 反问时助手消息正文通常是空的（问题在 toolsJson.ask 里）。如果只按 content
/// 拼历史，模型下一轮就看不到自己问过什么，用户一回答它就又从头问一遍。
String? askTranscript(String toolsJson) {
  if (toolsJson.trim().isEmpty) return null;
  Object? raw;
  try {
    raw = jsonDecode(toolsJson);
  } catch (_) {
    return null;
  }
  if (raw is! Map) return null;
  final ask = raw['ask'];
  if (ask is! Map) return null;
  final q = (ask['question'] as String?)?.trim() ?? '';
  if (q.isEmpty) return null;

  final options = <String>[
    for (final o in (ask['options'] as List?) ?? const <dynamic>[])
      if (o is String) o else if (o is Map) (o['label'] as String?) ?? '',
  ].where((e) => e.isNotEmpty).toList();

  final buf = StringBuffer('（我向你提问：$q')
    ..write(options.isEmpty ? '）' : '；候选：${options.join(' / ')}）');
  return buf.toString();
}

/// 一次工具调用的可视轨迹 —— 聊天里那张「工具卡片」的数据源。
class ToolTrace {
  const ToolTrace({
    required this.name,
    required this.label,
    this.input = '',
    this.output = '',
    this.detail = '',
    this.ok = true,
    this.durationMs = 0,
  });

  final String name;

  /// 中文短名，例如「查询记录」
  final String label;

  /// 入参摘要，例如「本周 · 黑色 · M码」
  final String input;

  /// 结果摘要，例如「3 条 · 70 件 · ¥1,240.00」
  final String output;

  /// 展开后看的明细（例如终端命令的完整输出）。空表示没有额外明细。
  final String detail;

  final bool ok;

  /// 这次工具调用耗时（毫秒）
  final int durationMs;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'label': label,
        'input': input,
        'output': output,
        if (detail.isNotEmpty) 'detail': detail,
        'ok': ok,
        'durationMs': durationMs,
      };

  static ToolTrace? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    return ToolTrace(
      name: (m['name'] as String?) ?? '',
      label: (m['label'] as String?) ?? '',
      input: (m['input'] as String?) ?? '',
      output: (m['output'] as String?) ?? '',
      detail: (m['detail'] as String?) ?? '',
      ok: m['ok'] != false,
      durationMs: (m['durationMs'] as num?)?.toInt() ?? 0,
    );
  }

  static List<ToolTrace> listFromJson(Object? raw) {
    if (raw is! List) return const <ToolTrace>[];
    return raw
        .map(ToolTrace.fromJson)
        .whereType<ToolTrace>()
        .toList(growable: false);
  }
}

/// 工具希望界面做的事（跳页 / 应用筛选 / 导出）
enum UiActionKind { openPage, applyFilter, exportReport }

class UiAction {
  const UiAction({
    required this.kind,
    this.target = '',
    this.filter,
    this.label = '',
  });

  final UiActionKind kind;

  /// openPage 时是页面名；exportReport 时是 png/csv
  final String target;

  final RecordFilter? filter;

  /// 按钮文案
  final String label;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind.name,
        'target': target,
        'filter': filter?.toJson(),
        'label': label,
      };

  static UiAction? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    final kindName = (m['kind'] as String?) ?? '';
    final kind = UiActionKind.values.firstWhere(
      (k) => k.name == kindName,
      orElse: () => UiActionKind.openPage,
    );
    final rawFilter = m['filter'];
    return UiAction(
      kind: kind,
      target: (m['target'] as String?) ?? '',
      label: (m['label'] as String?) ?? '',
      filter: rawFilter is Map
          ? RecordFilter.fromJson(
              rawFilter.map((k, v) => MapEntry(k.toString(), v)))
          : null,
    );
  }

  static List<UiAction> listFromJson(Object? raw) {
    if (raw is! List) return const <UiAction>[];
    return raw.map(UiAction.fromJson).whereType<UiAction>().toList(growable: false);
  }
}

/// 工具执行器需要「动 App」时回调宿主（由 ChatNotifier 实现）。
///
/// 这样 AI 就能改设置、加单位、配换算、删记录 —— 而不只是读数据。
abstract class AiToolHost {
  Future<List<PieceRecord>> loadRecords();

  Future<Map<OptionKind, List<String>>> loadOptions();

  Future<AppSetting?> loadSettings();

  Future<void> updateSettings(void Function(AppSetting s) fn);

  Future<bool> addOption(OptionKind kind, String value);

  Future<void> removeOption(OptionKind kind, String value);

  Future<List<UnitItem>> loadUnits();

  Future<List<UnitRule>> loadUnitRules();

  Future<bool> addUnit(String name);

  Future<void> removeUnit(String name);

  Future<void> setBaseUnit(String name);

  Future<void> saveUnitRule({
    required String fromUnit,
    required String toUnit,
    required int numerator,
    required int denominator,
    String styleModel,
  });

  /// 把对话里发的图片复制进记录照片目录，返回新的文件名。
  /// 关联图片靠它 —— 记录只能引用 photos/ 下的文件。
  Future<String?> copyChatPhotoToRecords(String chatPhotoName);

  /// 最近的操作日志（查历史 / 撤销用）
  Future<List<OperationLog>> loadOperations({int limit});

  /// 撤销某条操作，返回是否成功
  Future<bool> undoOperation(int logId);

  /// 回收站里匹配的记录（恢复用）
  Future<List<PieceRecord>> loadDeleted();

  /// 从回收站恢复指定记录
  Future<int> restoreDeleted(List<int> ids);
}


// ─────────────────────────── Agent 任务 ───────────────────────────

enum AgentStepStatus { pending, running, done, failed }

extension AgentStepStatusX on AgentStepStatus {
  String get wireName => name;

  static AgentStepStatus fromWire(Object? v) => switch (v) {
        'running' => AgentStepStatus.running,
        'done' => AgentStepStatus.done,
        'failed' => AgentStepStatus.failed,
        _ => AgentStepStatus.pending,
      };
}

/// 执行计划里的一步
class AgentStep {
  AgentStep({
    required this.id,
    required this.title,
    this.status = AgentStepStatus.pending,
    this.detail = '',
  });

  final String id;
  final String title;
  AgentStepStatus status;

  /// 这一步的结果摘要，例如「42 条 · 1,280 件」
  String detail;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'status': status.wireName,
        'detail': detail,
      };

  static AgentStep? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    return AgentStep(
      id: (m['id'] as String?) ?? '',
      title: (m['title'] as String?) ?? '',
      status: AgentStepStatusX.fromWire(m['status']),
      detail: (m['detail'] as String?) ?? '',
    );
  }
}

/// 一次 agent 任务的完整状态：目标 + 步骤 + 总结 + 后续建议
class AgentTask {
  AgentTask({
    required this.goal,
    required this.steps,
    this.summary = '',
    this.followups = const <String>[],
    this.done = false,
  });

  final String goal;
  final List<AgentStep> steps;
  String summary;
  List<String> followups;
  bool done;

  int get doneCount =>
      steps.where((s) => s.status == AgentStepStatus.done).length;

  double get progress => steps.isEmpty ? 0 : doneCount / steps.length;

  AgentStep? get running {
    for (final s in steps) {
      if (s.status == AgentStepStatus.running) return s;
    }
    return null;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'goal': goal,
        'steps': steps.map((s) => s.toJson()).toList(),
        'summary': summary,
        'followups': followups,
        'done': done,
      };

  static AgentTask? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    final steps = <AgentStep>[];
    final rawSteps = m['steps'];
    if (rawSteps is List) {
      for (final e in rawSteps) {
        final s = AgentStep.fromJson(e);
        if (s != null) steps.add(s);
      }
    }
    final followups = <String>[];
    final rawF = m['followups'];
    if (rawF is List) {
      for (final e in rawF) {
        if (e is String && e.trim().isNotEmpty) followups.add(e.trim());
      }
    }
    return AgentTask(
      goal: (m['goal'] as String?) ?? '',
      steps: steps,
      summary: (m['summary'] as String?) ?? '',
      followups: followups,
      done: m['done'] == true,
    );
  }
}


/// AI 主动向用户提问（信息不足时用）。
///
/// 比让模型"说一句请补充"强的地方：能带选项，用户点一下就能回答，
/// 不用自己组织语言。
class AskPrompt {
  const AskPrompt({
    required this.question,
    this.options = const <String>[],
    this.why = '',
  });

  final String question;

  /// 可点选的答案（2~6 个）
  final List<String> options;

  /// 为什么需要这个信息
  final String why;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'question': question,
        'options': options,
        'why': why,
      };

  static AskPrompt? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    final q = (m['question'] as String?)?.trim() ?? '';
    if (q.isEmpty) return null;
    final opts = <String>[];
    final rawOpts = m['options'];
    if (rawOpts is List) {
      for (final e in rawOpts) {
        if (e is String && e.trim().isNotEmpty) opts.add(e.trim());
      }
    }
    return AskPrompt(
      question: q,
      options: opts,
      why: (m['why'] as String?)?.trim() ?? '',
    );
  }
}


// ─────────────────────── 展示类卡片（不改数据）───────────────────────

/// AI 画的 SVG 图（柱状图/折线图/饼图等）
class SvgBlock {
  const SvgBlock({required this.title, required this.svg});

  final String title;
  final String svg;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'svg': svg,
      };

  static SvgBlock? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    final svg = (m['svg'] as String?) ?? '';
    if (svg.trim().isEmpty) return null;
    return SvgBlock(
      title: (m['title'] as String?) ?? '图表',
      svg: svg,
    );
  }
}

/// 算法过程表里的一步
class CalcStep {
  const CalcStep({
    required this.label,
    required this.expression,
    required this.result,
  });

  final String label;
  final String expression;
  final String result;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'label': label,
        'expression': expression,
        'result': result,
      };

  static CalcStep? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    return CalcStep(
      label: (m['label'] as String?) ?? '',
      expression: (m['expression'] as String?) ?? '',
      result: (m['result'] as String?) ?? '',
    );
  }
}

/// 算法过程表：把「怎么算出来的」摊开，用于核对正确性
class CalcTable {
  const CalcTable({
    required this.title,
    required this.steps,
    this.conclusion = '',
  });

  final String title;
  final List<CalcStep> steps;
  final String conclusion;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'steps': steps.map((e) => e.toJson()).toList(),
        'conclusion': conclusion,
      };

  static CalcTable? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    final steps = <CalcStep>[];
    final rawSteps = m['steps'];
    if (rawSteps is List) {
      for (final e in rawSteps) {
        final s = CalcStep.fromJson(e);
        if (s != null) steps.add(s);
      }
    }
    if (steps.isEmpty) return null;
    return CalcTable(
      title: (m['title'] as String?) ?? '计算过程',
      steps: steps,
      conclusion: (m['conclusion'] as String?) ?? '',
    );
  }
}

/// 代码 / 命令卡片
class CodeBlock {
  const CodeBlock({
    required this.title,
    required this.language,
    required this.code,
  });

  final String title;
  final String language;
  final String code;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'language': language,
        'code': code,
      };

  static CodeBlock? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    final code = (m['code'] as String?) ?? '';
    if (code.trim().isEmpty) return null;
    return CodeBlock(
      title: (m['title'] as String?) ?? '代码',
      language: (m['language'] as String?) ?? 'text',
      code: code,
    );
  }
}


/// 工具中文名（界面提示、trace 共用）
String toolLabel(String name) => switch (name) {
      'query_records' => '查询记录',
      'aggregate_records' => '分组汇总',
      'list_available_options' => '读取选项',
      'delete_records' => '删除记录',
      'update_records' => '修改记录',
      'create_records' => '新建记录',
      'get_settings' => '读取设置',
      'update_settings' => '修改设置',
      'manage_options' => '维护选项',
      'manage_units' => '维护单位',
      'set_unit_rule' => '配置换算',
      'apply_filter' => '应用筛选',
      'compare_periods' => '周期对比',
      'top_n' => '排行榜',
      'open_page' => '打开页面',
      'manage_photos' => '图片关联',
      'ask_user' => '向用户提问',
      'find_duplicates' => '查重',
      'check_anomalies' => '数据体检',
      'list_operations' => '操作历史',
      'undo_operation' => '撤销操作',
      'restore_records' => '回收站恢复',
      'export_report' => '导出报表',
      'predict_income' => '收入预估',
      'unit_convert' => '单位换算',
      'explain_conversion' => '换算核对',
      'render_svg' => '绘制图表',
      'show_calculation' => '计算过程',
      'show_code' => '代码展示',
      'run_terminal' => '执行命令',
      'plan_task' => '制定计划',
      'step_done' => '完成步骤',
      'finish_task' => '收尾',
      _ => name,
    };
