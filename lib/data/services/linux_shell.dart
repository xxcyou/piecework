import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'tool_bridge.dart';

/// 一次交互式命令的结果
class ShellRun {
  const ShellRun({
    required this.output,
    required this.cwd,
    required this.exitCode,
    this.timedOut = false,
  });

  final String output;
  final String cwd;
  final int exitCode;
  final bool timedOut;
}

/// 一条**常驻**的 Linux shell（proot 里的 /bin/sh）。
///
/// 为什么不用「每条命令起一个新进程」：那样 `cd /` 只影响那一次调用，
/// 下一条 `ls` 又回到 /root，看起来就像「cd 没生效、ls 是空的」。
/// 这里保持一个进程，命令逐条写进它的 stdin，`cd`、`export`、别名都能累积。
///
/// 输出分帧：每条命令后面追加一行
/// `printf '\n__DSH_<token>__<PWD>__<exit>\n'`
/// 读到这行就知道这条命令跑完了，同时把 cwd 和退出码带回来。
class LinuxShell {
  LinuxShell._(this._proc, [this._bridge]);

  final Process _proc;

  /// 工具桥：shell 里 @工具名 的请求靠它转发回 App
  final ToolBridge? _bridge;
  final StringBuffer _out = StringBuffer();
  final StringBuffer _err = StringBuffer();
  StreamSubscription<String>? _outSub;
  StreamSubscription<String>? _errSub;

  String? _pendingToken;
  Completer<ShellRun>? _pending;

  bool _dead = false;

  bool get isAlive => !_dead;

  /// 启动一个 shell 进程（调用方负责准备好 proot 的路径/环境）
  static Future<LinuxShell> start({
    required String executable,
    required List<String> arguments,
    required Map<String, String> environment,
    required String workingDirectory,
    ToolBridge? bridge,
  }) async {
    final proc = await Process.start(
      executable,
      arguments,
      environment: environment,
      workingDirectory: workingDirectory,
    );
    final shell = LinuxShell._(proc, bridge);
    shell._attach();
    return shell;
  }

  void _attach() {
    _outSub = _proc.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(_onOut);
    _errSub = _proc.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(_onErr);
    _proc.exitCode.then((_) {
      _dead = true;
      _pending?.complete(
        ShellRun(
          output: _clean(_out.toString()) + _clean(_err.toString()),
          cwd: '',
          exitCode: -1,
        ),
      );
      _pending = null;
    });
  }

  void _onOut(String chunk) {
    _out.write(chunk);
    final token = _pendingToken;
    if (token == null) return;
    final parsed = parseMarker(_out.toString(), token);
    if (parsed == null) return;

    _pendingToken = null;
    final completer = _pending;
    _pending = null;
    _out.clear();
    final err = _clean(_err.toString());
    _err.clear();
    completer?.complete(
      ShellRun(
        output: (parsed.output + (err.isEmpty ? '' : err)).trimRight(),
        cwd: parsed.cwd,
        exitCode: parsed.exitCode,
      ),
    );
  }

  void _onErr(String chunk) => _err.write(chunk);

  /// 执行一条命令，等它跑完
  Future<ShellRun> run(String command, {int timeoutMs = 30000}) async {
    if (_dead) {
      return const ShellRun(output: 'shell 已经退出，请重新进入终端模式', cwd: '', exitCode: -1);
    }
    if (_pending != null) {
      return const ShellRun(output: '上一条命令还在跑', cwd: '', exitCode: -1);
    }

    final token = 'x${DateTime.now().microsecondsSinceEpoch}';
    final completer = Completer<ShellRun>();
    _pendingToken = token;
    _pending = completer;
    _out.clear();
    _err.clear();

    _proc.stdin.writeln(command);
    // 命令结束后打一个带 token / 当前目录 / 退出码的标记行
    _proc.stdin.writeln(
      "printf '\\n__DSH_%s__%s__%s\\n' '$token' \"\$PWD\" \"\$?\"",
    );
    await _proc.stdin.flush();

    try {
      return await completer.future.timeout(Duration(milliseconds: timeoutMs));
    } on TimeoutException {
      _dead = true;
      _pendingToken = null;
      _pending = null;
      try {
        _proc.kill(ProcessSignal.sigkill);
      } catch (_) {}
      final partial = _clean(_out.toString()).trimRight();
      return ShellRun(
        output: partial.isEmpty ? '（超时，没有输出）' : partial,
        cwd: '',
        exitCode: -1,
        timedOut: true,
      );
    }
  }

  Future<void> dispose() async {
    _dead = true;
    try {
      _proc.stdin.writeln('exit');
      await _proc.stdin.flush();
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 120));
    try {
      _proc.kill(ProcessSignal.sigkill);
    } catch (_) {}
    await _outSub?.cancel();
    await _errSub?.cancel();
    await _bridge?.dispose();
  }

  /// proot 自己会往 stderr 打 "proot warning/info"，不该出现在用户输出里
  static String _clean(String s) => s
      .split('\n')
      .where((l) => !l.startsWith('proot '))
      .join('\n');

  /// 从缓冲区里找标记行，返回「去掉标记后的输出 + cwd + exit」
  static ({String output, String cwd, int exitCode})? parseMarker(
    String buffer,
    String token,
  ) {
    final needle = '__DSH_${token}__';
    final idx = buffer.indexOf(needle);
    if (idx < 0) return null;

    // 标记行前面有一个我们自己 printf 出来的换行，连同命令输出末尾的换行一起去掉
    final output = buffer
        .substring(0, idx)
        .replaceFirst(RegExp(r'\n+$'), '');

    final rest = buffer.substring(idx + needle.length);
    final lineEnd = rest.indexOf('\n');
    final meta = lineEnd < 0 ? rest : rest.substring(0, lineEnd);
    final parts = meta.split('__');
    final cwd = parts.isNotEmpty ? parts[0] : '';
    final code = parts.length > 1 ? int.tryParse(parts[1].trim()) ?? 0 : 0;

    return (output: output, cwd: cwd, exitCode: code);
  }
}
