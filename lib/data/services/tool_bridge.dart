import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// 工具执行回调：给工具名 + 参数，返回结果 JSON
typedef ToolHandler = Future<Map<String, dynamic>> Function(
  String name,
  Map<String, dynamic> args,
);

/// 把 App 的 AI 工具「接」进 Linux shell。
///
/// 为什么需要它：`@query_records {...}` 直接写在命令行开头时，Dart 侧能拦下来；
/// 但一旦写进 `for` / `while` / `if` 这种复合语句，命令是**shell**在解释执行，
/// 它会把 `@query_records` 当成一个不存在的程序（`not found`）。
///
/// 做法：在 `<tmp>/dsh-tool/bin/` 里放一组脚本：
/// * `dsh-tool <name> [json]` —— 把请求写进 `req/`，轮询 `res/` 等结果；
/// * `@<name>` —— 每个工具一个同名脚本，内部转给 `dsh-tool`。
/// Dart 侧起一个 80ms 的轮询器，看到请求就执行工具、把 JSON 写回去。
/// 这样 `for t in dark light; do @update_settings {"theme":"$t"}; done`
/// 也能逐条生效。
class ToolBridge {
  ToolBridge({required this.tmpDir, required this.handler});

  /// 应用侧 `<AppDocuments>/linux/tmp`（proot 里就是 /tmp）
  final Directory tmpDir;
  final ToolHandler handler;

  Timer? _timer;
  bool _busy = false;
  bool _disposed = false;

  Directory get _root => Directory(p.join(tmpDir.path, 'dsh-tool'));
  Directory get _reqDir => Directory(p.join(_root.path, 'req'));
  Directory get _resDir => Directory(p.join(_root.path, 'res'));

  /// shell 里加进 PATH 的目录
  String get binDir => p.join(_root.path, 'bin');

  /// 生成脚本（幂等）。返回是否成功。
  Future<bool> ensureScripts(List<String> tools) async {
    try {
      await _reqDir.create(recursive: true);
      await _resDir.create(recursive: true);
      final bin = Directory(binDir);
      await bin.create(recursive: true);

      const main = r'''#!/bin/sh
# dsh-tool <工具名> [JSON 参数]
# 由 App 内的 ToolBridge 轮询 req/ 目录，执行工具后把结果写进 res/
name="$1"
if [ $# -gt 0 ]; then shift; fi
args="$*"
dir=/tmp/dsh-tool
mkdir -p "$dir/req" "$dir/res" 2>/dev/null
id="$$-$(date +%s)"
printf '%s' "$name" > "$dir/req/$id.name"
printf '%s' "$args" > "$dir/req/$id.args"
i=0
while [ ! -f "$dir/res/$id.json" ]; do
  i=$((i+1))
  if [ "$i" -gt 400 ]; then break; fi
  sleep 0.05 2>/dev/null || sleep 1
done
if [ -f "$dir/res/$id.json" ]; then
  cat "$dir/res/$id.json"
else
  echo '{"ok":false,"error":"工具桥超时：App 没有响应（可能切到后台了）"}'
fi
rm -f "$dir/req/$id.name" "$dir/req/$id.args" "$dir/res/$id.json" 2>/dev/null
''';

      final mainFile = File(p.join(binDir, 'dsh-tool'));
      await mainFile.writeAsString(main, flush: true);
      await Process.run('chmod', <String>['755', mainFile.path]);

      for (final tool in tools) {
        final f = File(p.join(binDir, '@$tool'));
        await f.writeAsString(
          '#!/bin/sh\nexec /tmp/dsh-tool/bin/dsh-tool $tool "\$@"\n',
          flush: true,
        );
        await Process.run('chmod', <String>['755', f.path]);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 测试用：立刻处理一遍待办请求（不依赖定时器，避免偶发超时）
  Future<void> pumpNow() => _pump();

  void start() {
    if (_disposed) return;
    _timer ??= Timer.periodic(
      const Duration(milliseconds: 80),
      (_) => unawaited(_pump()),
    );
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }

  /// 扫一遍请求目录，处理掉待执行的工具调用
  Future<void> _pump() async {
    if (_busy || _disposed) return;
    _busy = true;
    try {
      if (!await _reqDir.exists()) return;
      final entries = await _reqDir.list().toList();
      for (final e in entries) {
        if (e is! File || !e.path.endsWith('.name')) continue;
        final id = p.basenameWithoutExtension(e.path);
        String name = '';
        try {
          name = (await e.readAsString()).trim();
        } catch (_) {
          continue;
        }
        if (name.isEmpty) continue;

        final argsFile = File(p.join(_reqDir.path, '$id.args'));
        var args = <String, dynamic>{};
        try {
          if (await argsFile.exists()) {
            final raw = (await argsFile.readAsString()).trim();
            if (raw.isNotEmpty) {
              final decoded = jsonDecode(raw);
              if (decoded is Map) {
                args = decoded.map((k, v) => MapEntry(k.toString(), v));
              }
            }
          }
        } catch (_) {
          args = <String, dynamic>{};
        }

        Map<String, dynamic> result;
        try {
          result = await handler(name, args);
        } catch (err) {
          result = <String, dynamic>{'ok': false, 'error': '$err'};
        }

        try {
          await _resDir.create(recursive: true);
          await File(p.join(_resDir.path, '$id.json'))
              .writeAsString(jsonEncode(result), flush: true);
        } catch (_) {}
        try {
          await e.delete();
          if (await argsFile.exists()) await argsFile.delete();
        } catch (_) {}
      }
    } catch (_) {
      // 轮询失败不打扰用户，下一轮再试
    } finally {
      _busy = false;
    }
  }
}
