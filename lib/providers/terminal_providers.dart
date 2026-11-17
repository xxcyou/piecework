import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/ai_tool_types.dart';
import '../data/services/ai_tools.dart';
import '../data/services/linux_env_service.dart';
import '../data/services/linux_shell.dart';
import '../data/services/tool_bridge.dart';
import '../data/services/terminal_service.dart';
import 'chat_providers.dart';

/// 输入框里「终端模式」的判定。
///
/// 进入条件**很严格**：第一个字符必须是 `/`、第二个必须是空格，而且必须是
/// **刚刚变成这两个字符**（`/` → `/ `）。这样粘贴一大段以 `/` 开头的代码
/// （`/usr/bin/env ...`、`/ foo`）不会误进终端模式。
bool shouldEnterTerminalMode({
  required String text,
  required String previous,
}) =>
    text == '/ ' && previous.length <= 1;

/// 当前是否处于终端前缀状态（第一字符 `/` + 第二字符空格）
bool hasTerminalPrefix(String text) => text.startsWith('/ ');

/// 终端卡片里的一行
class TerminalLine {
  const TerminalLine(this.text, {this.kind = TerminalLineKind.output});

  final String text;
  final TerminalLineKind kind;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'text': text,
        'kind': kind.name,
      };

  static TerminalLine fromJson(Object? raw) {
    if (raw is String) return TerminalLine(raw);
    if (raw is! Map) return const TerminalLine('');
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    final kind = TerminalLineKind.values.firstWhere(
      (k) => k.name == m['kind'],
      orElse: () => TerminalLineKind.output,
    );
    return TerminalLine((m['text'] as String?) ?? '', kind: kind);
  }
}

enum TerminalLineKind { command, output, error, info }

/// 一次终端会话（用户在 AI 页用「/ 」进入的模式）
class TerminalSessionState {
  const TerminalSessionState({
    this.active = false,
    this.busy = false,
    this.env = 'linux',
    this.lines = const <TerminalLine>[],
    this.startedAt,
    this.cwd = '',
  });

  final bool active;
  final bool busy;
  final String env;
  final List<TerminalLine> lines;
  final DateTime? startedAt;

  /// shell 当前目录（常驻 shell 才有；用来在卡片标题上显示 /etc 这种）
  final String cwd;

  bool get hasContent => lines.isNotEmpty;

  TerminalSessionState copyWith({
    bool? active,
    bool? busy,
    String? env,
    List<TerminalLine>? lines,
    DateTime? startedAt,
    String? cwd,
  }) =>
      TerminalSessionState(
        active: active ?? this.active,
        busy: busy ?? this.busy,
        env: env ?? this.env,
        lines: lines ?? this.lines,
        startedAt: startedAt ?? this.startedAt,
        cwd: cwd ?? this.cwd,
      );

  /// 存进 ChatMessage.toolsJson 的形状
  Map<String, dynamic> toJson() => <String, dynamic>{
        'env': env,
        'lines': lines.map((l) => l.toJson()).toList(),
        if (cwd.isNotEmpty) 'cwd': cwd,
        if (startedAt != null) 'startedAt': startedAt!.millisecondsSinceEpoch,
      };
}

/// 终端会话状态机。
///
/// 生命周期：输入框出现「/ 」→ [begin]；每回车一次 → [run]；
/// 「/ 」被删掉 → [finish]（由 chat_page 负责把结果落库成普通卡片）。
class TerminalSessionNotifier extends StateNotifier<TerminalSessionState> {
  TerminalSessionNotifier([this._ref]) : super(const TerminalSessionState());

  /// 工具通道需要它读本机数据；纯 shell 场景可以不给（测试里就是这样）
  final Ref? _ref;

  /// 常驻 shell：cd / export 能累积
  LinuxShell? _shell;

  /// 进入终端模式（幂等）
  void begin() {
    if (state.active) return;
    state = const TerminalSessionState(active: true, busy: false);
  }

  /// 退出（只清状态；落库由调用方做）
  TerminalSessionState finish() {
    final snapshot = state;
    _shell?.dispose();
    _shell = null;
    state = const TerminalSessionState();
    return snapshot;
  }

  /// shell 里 @工具名 的请求 → 走真正的工具执行器
  Future<Map<String, dynamic>> _handleBridgeCall(
    String name,
    Map<String, dynamic> args,
  ) async {
    final ref = _ref;
    if (ref == null) {
      return <String, dynamic>{'ok': false, 'error': '工具通道没接上'};
    }
    final executor = await buildChatToolExecutor(ref);
    final outcome = await executor.execute(name, args);
    final pending = outcome.pendingAction;
    if (pending != null) {
      await ref.read(chatProvider.notifier).persistActionCard(pending);
    }
    return outcome.json;
  }

  Future<LinuxShell?> _ensureShell() async {
    if (_shell != null && _shell!.isAlive) return _shell;
    try {
      ToolBridge? bridge;
      if (_ref != null) {
        final docs = await getApplicationDocumentsDirectory();
        bridge = ToolBridge(
          tmpDir: Directory(p.join(docs.path, 'linux', 'tmp')),
          handler: _handleBridgeCall,
        );
        await bridge.ensureScripts(AiTools.toolNames);
      }
      _shell = await LinuxEnvService.instance.openShell(bridge: bridge);
      return _shell;
    } catch (e) {
      state = state.copyWith(
        lines: <TerminalLine>[
          ...state.lines,
          TerminalLine('打开 Linux 失败：$e', kind: TerminalLineKind.error),
        ],
        busy: false,
      );
      return null;
    }
  }

  /// 执行一条命令，把输出追加到会话里
  Future<void> run(String raw) async {
    final command = raw.trim();
    if (command.isEmpty || state.busy) return;
    if (!state.active) state = state.copyWith(active: true);

    // `@工具名 {...}` → 调用 AI 工具（读本机数据），不走 shell
    if (command.startsWith('@')) {
      _append(<TerminalLine>[
        TerminalLine('@ ${command.substring(1)}', kind: TerminalLineKind.command),
      ]);
      state = state.copyWith(busy: true);
      try {
        await _runTool(command.substring(1).trim());
      } finally {
        state = state.copyWith(busy: false);
      }
      return;
    }

    final lines = <TerminalLine>[
      ...state.lines,
      TerminalLine('\$ $command', kind: TerminalLineKind.command),
    ];
    state = state.copyWith(lines: lines, busy: true);

    // 危险命令先拦（和执行层是同一套规则）
    final blocked = TerminalService.instance.checkCommand(command);
    if (blocked != null) {
      state = state.copyWith(
        lines: <TerminalLine>[
          ...state.lines,
          TerminalLine('⛔ $blocked', kind: TerminalLineKind.error),
        ],
        busy: false,
      );
      return;
    }

    final shell = await _ensureShell();
    if (shell == null) return;

    try {
      final result = await shell.run(command);
      final next = <TerminalLine>[...state.lines];
      if (result.timedOut) {
        next.add(const TerminalLine('⏱ 超时，shell 已重启',
            kind: TerminalLineKind.info));
      } else {
        if (result.output.isNotEmpty) {
          for (final l in result.output.split('\n')) {
            next.add(TerminalLine(l));
          }
        } else {
          next.add(const TerminalLine('（无输出）', kind: TerminalLineKind.info));
        }
        if (result.exitCode != 0) {
          next.add(TerminalLine('[exit ${result.exitCode}]',
              kind: TerminalLineKind.info));
        }
      }
      state = state.copyWith(
        lines: next,
        busy: false,
        cwd: result.cwd.isEmpty ? state.cwd : result.cwd,
      );
    } catch (e) {
      state = state.copyWith(
        lines: <TerminalLine>[
          ...state.lines,
          TerminalLine('执行失败：$e', kind: TerminalLineKind.error),
        ],
        busy: false,
      );
    }
  }
  // ───────────────────── AI 工具通道（@工具名） ─────────────────────

  Future<void> _runTool(String expr) async {
    if (expr.isEmpty || expr == 'help' || expr == 'tools') {
      _append(const <TerminalLine>[
        TerminalLine('可用 AI 工具（用法：@工具名 {"参数":"值"}）',
            kind: TerminalLineKind.info),
        TerminalLine('@query_records   @aggregate_records   @top_n   @compare_periods',
            kind: TerminalLineKind.info),
        TerminalLine('@list_available_options   @check_anomalies   @find_duplicates',
            kind: TerminalLineKind.info),
        TerminalLine('@predict_income   @unit_convert   @explain_conversion',
            kind: TerminalLineKind.info),
        TerminalLine('@get_settings   @list_operations   @update_settings',
            kind: TerminalLineKind.info),
        TerminalLine('@create_records  @update_records  @delete_records  @set_unit_rule',
            kind: TerminalLineKind.info),
        TerminalLine('写操作会先生成确认卡片放到聊天里，你去点「确认」才真正落库。',
            kind: TerminalLineKind.info),
      ]);
      return;
    }

    final call = parseToolCommand(expr);
    if (call.args == null) {
      _append(<TerminalLine>[
        TerminalLine('@${call.name} 参数必须是 JSON 对象，例如：', kind: TerminalLineKind.error),
        TerminalLine('  @query_records {"date_preset":"this_week"}',
            kind: TerminalLineKind.info),
      ]);
      return;
    }
    final ref = _ref;
    if (ref == null) {
      _append(<TerminalLine>[
        TerminalLine('工具通道没接上（缺少 App 数据上下文）', kind: TerminalLineKind.error),
      ]);
      return;
    }

    try {
      final executor = await buildChatToolExecutor(ref);
      final outcome = await executor.execute(call.name, call.args!);
      final json = outcome.json;

      // 写操作（新建/修改/删除/关联图片）：生成确认卡片放到聊天里，
      // 用户点「确认」才落库 —— 终端不静默改数据
      final pending = outcome.pendingAction;
      if (pending != null) {
        await ref.read(chatProvider.notifier).persistActionCard(pending);
        _append(<TerminalLine>[
          TerminalLine('待确认：${pending.description}',
              kind: TerminalLineKind.info),
          TerminalLine('已生成确认卡片，去聊天里点「确认」才会生效。',
              kind: TerminalLineKind.info),
        ]);
      }

      // 带管道：把 JSON 落盘，交给这条会话的 shell 接着处理
      if (call.pipeline.isNotEmpty) {
        final shell = await _ensureShell();
        if (shell == null) return;
        final docs = await getApplicationDocumentsDirectory();
        final tmpDir = Directory(p.join(docs.path, 'linux', 'tmp'));
        if (!await tmpDir.exists()) await tmpDir.create(recursive: true);
        final name = 'tool_${DateTime.now().microsecondsSinceEpoch}.json';
        final file = File(p.join(tmpDir.path, name));
        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(json),
          flush: true,
        );
        final r = await shell.run('cat /tmp/$name ${call.pipeline}');
        try {
          await file.delete();
        } catch (_) {}
        _append(<TerminalLine>[
          ...r.output.split('\n').map((l) => TerminalLine(l)),
          if (r.exitCode != 0)
            TerminalLine('[exit ${r.exitCode}]', kind: TerminalLineKind.info),
        ]);
        return;
      }

      final pretty = const JsonEncoder.withIndent('  ').convert(json);
      final lines = pretty.split('\n');
      const maxLines = 60;
      _append(<TerminalLine>[
        ...lines.take(maxLines).map((l) => TerminalLine(l)),
        if (lines.length > maxLines)
          TerminalLine('…（还有 ${lines.length - maxLines} 行，已截断）',
              kind: TerminalLineKind.info),
        if (json['ok'] == false)
          TerminalLine('[工具返回失败]', kind: TerminalLineKind.error),
      ]);
    } catch (e) {
      _append(<TerminalLine>[
        TerminalLine('调用 @${call.name} 失败：$e', kind: TerminalLineKind.error),
      ]);
    }
  }

  void _append(List<TerminalLine> lines) {
    state = state.copyWith(lines: <TerminalLine>[...state.lines, ...lines]);
  }
}

final terminalSessionProvider =
    StateNotifierProvider<TerminalSessionNotifier, TerminalSessionState>(
  (ref) => TerminalSessionNotifier(ref),
);
