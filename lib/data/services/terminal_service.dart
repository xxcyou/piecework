import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 一次终端执行的结果。
class TerminalResult {
  const TerminalResult({
    required this.command,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.durationMs,
    this.truncated = false,
    this.blockedReason,
  });

  final String command;
  final int exitCode;
  final String stdout;
  final String stderr;
  final int durationMs;

  /// 输出被截断（超过 [TerminalService.maxOutputChars]）
  final bool truncated;

  /// 非空表示命令被安全策略拦下，根本没执行
  final String? blockedReason;

  bool get blocked => blockedReason != null;
  bool get ok => !blocked && exitCode == 0;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'ok': ok,
        if (blocked) 'blocked': blockedReason,
        if (!blocked) 'exitCode': exitCode,
        if (stdout.isNotEmpty) 'stdout': stdout,
        if (stderr.isNotEmpty) 'stderr': stderr,
        if (truncated) 'truncated': true,
        'durationMs': durationMs,
      };
}

/// 给 AI 用的「轻量级终端」：在本机跑一条 shell 命令。
///
/// 只给 AI 用，没有终端界面。
///
/// 边界（都是必要的，因为执行者是模型）：
/// * 工作目录固定在 App 文档目录，避免一上来就在 `/` 里乱翻；
/// * 默认 15 秒超时、最多 60 秒，超时直接 SIGKILL；
/// * 输出各截断到 [maxOutputChars]，别把整屏日志灌进上下文；
/// * 破坏性命令（rm -rf /、pm uninstall、reboot、mkfs…）直接拦掉。
class TerminalService {
  TerminalService._();

  static final TerminalService instance = TerminalService._();

  /// 单条流最多保留多少字符
  static const int maxOutputChars = 8000;

  static const int defaultTimeoutMs = 15000;
  static const int maxTimeoutMs = 60000;

  /// 这些命令一律不执行（正则，忽略大小写）
  static final List<RegExp> _denyPatterns = <RegExp>[
    RegExp(r'\brm\s+(-[a-z]*r[a-z]*f|-[a-z]*f[a-z]*r)\s+/(\s|$)',
        caseSensitive: false),
    RegExp(r'\brm\s+-[a-z]*r[a-z]*\s+/(data|system|sdcard|storage)\b',
        caseSensitive: false),
    RegExp(r'\bmkfs(\.|\s|$)', caseSensitive: false),
    RegExp(r'\bdd\s+.*of=/dev/', caseSensitive: false),
    RegExp(r'\bpm\s+(uninstall|clear)\b', caseSensitive: false),
    RegExp(r'\b(reboot|shutdown|halt|poweroff)\b', caseSensitive: false),
    RegExp(r'\b(su|sudo)\b', caseSensitive: false),
    RegExp(r'\bsettings\s+put\b', caseSensitive: false),
    RegExp(r'\bsvc\s+(power|data|wifi)\b', caseSensitive: false),
    RegExp(r'\bam\s+force-stop\b', caseSensitive: false),
    RegExp(r'\bkillall\b', caseSensitive: false),
    RegExp(r'>\s*/dev/block/', caseSensitive: false),
    RegExp(r'\bchmod\s+777\s+/', caseSensitive: false),
    RegExp(r'\bmount\s+-o\s+rw\b', caseSensitive: false),
    RegExp(r'\bfastboot\b', caseSensitive: false),
    RegExp(r':\(\)\s*\{', caseSensitive: false), // fork 炸弹
  ];

  String get _shell => Platform.isAndroid ? '/system/bin/sh' : '/bin/sh';

  /// 拦不拦
  String? checkCommand(String command) {
    final cmd = command.trim();
    if (cmd.isEmpty) return '命令是空的';
    if (cmd.length > 2000) return '命令太长（上限 2000 字符）';
    for (final re in _denyPatterns) {
      if (re.hasMatch(cmd)) {
        return '这条命令会动系统或别的 App 的数据，已被拦下：${re.pattern}';
      }
    }
    return null;
  }

  /// 执行一条命令（不抛异常，失败也返回结果）
  Future<TerminalResult> run(
    String command, {
    int timeoutMs = defaultTimeoutMs,
    String? cwd,
  }) async {
    final started = DateTime.now();
    final blocked = checkCommand(command);
    if (blocked != null) {
      return TerminalResult(
        command: command,
        exitCode: -1,
        stdout: '',
        stderr: '',
        durationMs: 0,
        blockedReason: blocked,
      );
    }

    final limit = timeoutMs.clamp(1000, maxTimeoutMs);
    String workDir;
    try {
      workDir = cwd ?? (await getApplicationDocumentsDirectory()).path;
    } catch (_) {
      workDir = Directory.current.path;
    }

    final env = <String, String>{
      'PATH': Platform.isAndroid
          ? '/sbin:/system/sbin:/system/bin:/system/xbin:/vendor/bin'
          : (Platform.environment['PATH'] ?? '/usr/bin:/bin'),
      'HOME': workDir,
      'TMPDIR': workDir,
      'LANG': 'C.UTF-8',
      'TERM': 'dumb',
    };

    Process proc;
    try {
      proc = await Process.start(
        _shell,
        <String>['-c', command],
        workingDirectory: workDir,
        environment: env,
        runInShell: false,
      );
    } catch (e) {
      return TerminalResult(
        command: command,
        exitCode: -1,
        stdout: '',
        stderr: '启动 shell 失败：$e',
        durationMs: DateTime.now().difference(started).inMilliseconds,
      );
    }

    final out = StringBuffer();
    final err = StringBuffer();
    var truncated = false;

    void collect(StringBuffer into, String chunk) {
      if (into.length >= maxOutputChars) {
        truncated = true;
        return;
      }
      final room = maxOutputChars - into.length;
      if (chunk.length > room) {
        into.write(chunk.substring(0, room));
        truncated = true;
      } else {
        into.write(chunk);
      }
    }

    // 用 forEach 收集：它的 Future 在流关闭（进程退出、管道 EOF）时才完成。
    // 之前用 listen + cancel 会丢掉还在管道里的最后一段输出。
    final outFuture = proc.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .forEach((d) => collect(out, d));
    final errFuture = proc.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .forEach((d) => collect(err, d));

    var exitCode = -1;
    try {
      exitCode = await proc.exitCode.timeout(Duration(milliseconds: limit));
    } on TimeoutException {
      truncated = true;
      proc.kill(ProcessSignal.sigkill);
      exitCode = -9;
    }

    // 进程已经退出，两条流会自然 EOF；给 3 秒兜底，避免极端情况下挂住
    await Future.wait(<Future<void>>[outFuture, errFuture]).timeout(
      const Duration(seconds: 3),
      onTimeout: () => const <void>[],
    );
    if (exitCode == -9) {
      collect(err, '\n[已超时 ${limit ~/ 1000}s，进程被强制结束]');
    }

    return TerminalResult(
      command: command,
      exitCode: exitCode,
      stdout: out.toString().trimRight(),
      stderr: err.toString().trimRight(),
      durationMs: DateTime.now().difference(started).inMilliseconds,
      truncated: truncated,
    );
  }
}
