import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:piecework/data/services/ai_tools.dart';
import 'package:piecework/data/services/tool_bridge.dart';

/// 工具桥：让 `for ...; do @update_settings {...}; done` 这类复合语句里的
/// @工具名 也能执行（shell 不认识 @工具名，只能通过文件请求/应答转发）。
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('dsh_bridge_');
  });

  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  File req(String id, String suffix) =>
      File(p.join(tmp.path, 'dsh-tool', 'req', '$id.$suffix'));
  File res(String id) => File(p.join(tmp.path, 'dsh-tool', 'res', '$id.json'));

  test('生成 dsh-tool 和每个工具的 @脚本', () async {
    final bridge = ToolBridge(
      tmpDir: tmp,
      handler: (n, a) async => <String, dynamic>{'ok': true},
    );
    expect(await bridge.ensureScripts(<String>['query_records', 'update_settings']),
        isTrue);

    final main = File(p.join(bridge.binDir, 'dsh-tool'));
    expect(main.existsSync(), isTrue);
    final body = main.readAsStringSync();
    expect(body, contains('dir=/tmp/dsh-tool'));
    expect(body, contains(r'$dir/req/'));
    expect(body, contains('工具桥超时'));

    for (final t in <String>['@query_records', '@update_settings']) {
      final f = File(p.join(bridge.binDir, t));
      expect(f.existsSync(), isTrue, reason: t);
      expect(f.readAsStringSync(), contains('exec /tmp/dsh-tool/bin/dsh-tool'));
    }
  });

  test('收到请求 → 执行 handler → 写回 JSON', () async {
    final bridge = ToolBridge(
      tmpDir: tmp,
      handler: (name, args) async => <String, dynamic>{
        'ok': true,
        'tool': name,
        'args': args,
      },
    );
    await bridge.ensureScripts(<String>['update_settings']);
    bridge.start();

    await req('1-100', 'name').create(recursive: true);
    await req('1-100', 'name').writeAsString('update_settings');
    await req('1-100', 'args').writeAsString('{"theme":"dark"}');

    // 直接推一次，不赌定时器的调度时机
    await bridge.pumpNow();
    expect(res('1-100').existsSync(), isTrue, reason: '桥没有写回结果');

    final json = jsonDecode(res('1-100').readAsStringSync()) as Map;
    expect(json['tool'], 'update_settings');
    expect((json['args'] as Map)['theme'], 'dark');

    // 请求文件会被清理（删完有几十毫秒延迟，等一小会儿再断言）
    for (var i = 0; i < 20 && req('1-100', 'name').existsSync(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(req('1-100', 'name').existsSync(), isFalse);

    await bridge.dispose();
  });

  test('handler 抛异常也要回一个错误 JSON（不能让 shell 一直等）', () async {
    final bridge = ToolBridge(
      tmpDir: tmp,
      handler: (n, a) async => throw StateError('boom'),
    );
    await bridge.ensureScripts(<String>['x']);
    bridge.start();

    await req('2-1', 'name').create(recursive: true);
    await req('2-1', 'name').writeAsString('x');

    await bridge.pumpNow();
    expect(res('2-1').existsSync(), isTrue);
    final json = jsonDecode(res('2-1').readAsStringSync()) as Map;
    expect(json['ok'], isFalse);
    expect(json['error'].toString(), contains('boom'));

    await bridge.dispose();
  });

  test('dispose 后不再处理请求', () async {
    final bridge = ToolBridge(
      tmpDir: tmp,
      handler: (n, a) async => <String, dynamic>{'ok': true},
    );
    await bridge.ensureScripts(<String>['x']);
    bridge.start();
    await bridge.dispose();

    await req('3-1', 'name').create(recursive: true);
    await req('3-1', 'name').writeAsString('x');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(res('3-1').existsSync(), isFalse);
  });

  test('工具清单来自 schema（终端会为每个工具生成 @脚本）', () {
    final names = AiTools.toolNames;
    expect(names, contains('query_records'));
    expect(names, contains('update_settings'));
    expect(names, contains('create_records'));
    expect(names.length, greaterThan(20));
    // 不能有重复，否则会覆盖脚本
    expect(names.toSet().length, names.length);
  });
}
