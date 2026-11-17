import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/data/services/ai_service.dart';
import 'package:piecework/data/services/ai_tool_types.dart';
import 'package:piecework/data/services/linux_shell.dart';
import 'package:piecework/providers/terminal_providers.dart';
import 'package:piecework/ui/widgets/terminal_card.dart';

/// 「/ 」终端模式的状态机 + 终端卡片渲染。
void main() {
  group('终端会话状态机', () {
    test('begin 进入会话，finish 退出并返回快照', () {
      final n = TerminalSessionNotifier();
      expect(n.state.active, isFalse);

      n.begin();
      expect(n.state.active, isTrue);
      expect(n.state.lines, isEmpty);

      final snap = n.finish();
      expect(n.state.active, isFalse);
      expect(snap.active, isTrue); // 快照保留当时状态，供落库
    });

    test('run 先同步追加命令行并置忙，结束后追加输出', () async {
      final n = TerminalSessionNotifier()..begin();
      final future = n.run('echo hi'); // 不 await：先看同步状态

      expect(n.state.busy, isTrue);
      expect(n.state.lines.first.kind, TerminalLineKind.command);
      expect(n.state.lines.first.text, r'$ echo hi');

      await future;
      expect(n.state.busy, isFalse);
      expect(n.state.lines.length, greaterThan(1));
    });

    test('空命令直接忽略', () async {
      final n = TerminalSessionNotifier()..begin();
      await n.run('   ');
      expect(n.state.lines, isEmpty);
      expect(n.state.busy, isFalse);
    });

    test('危险命令被拦，写成红色错误行', () async {
      final n = TerminalSessionNotifier()..begin();
      await n.run('reboot');
      expect(
        n.state.lines.any((l) =>
            l.kind == TerminalLineKind.error && l.text.contains('拦')),
        isTrue,
      );
    });

    test('会话快照能 JSON 往返（落库后还能还原）', () {
      final n = TerminalSessionNotifier()..begin();
      n.state = n.state.copyWith(
        lines: const <TerminalLine>[
          TerminalLine(r'$ ls', kind: TerminalLineKind.command),
          TerminalLine('bin'),
          TerminalLine('oops', kind: TerminalLineKind.error),
        ],
      );
      final json = n.state.toJson();
      final lines = (json['lines'] as List).map(TerminalLine.fromJson).toList();
      expect(lines.length, 3);
      expect(lines[0].kind, TerminalLineKind.command);
      expect(lines[2].kind, TerminalLineKind.error);
      expect(json['env'], 'linux');
    });
  });

  group('终端模式的进入条件（严格：/ + 空格，且必须是刚敲出来的）', () {
    test('空输入框敲出「/ 」→ 进入', () {
      expect(shouldEnterTerminalMode(text: '/ ', previous: ''), isTrue);
    });

    test('先敲「/」再敲空格 → 进入', () {
      expect(shouldEnterTerminalMode(text: '/ ', previous: '/'), isTrue);
    });

    test('粘贴一段以 / 开头的代码 → 不进入', () {
      expect(
        shouldEnterTerminalMode(
          text: '/usr/bin/env python3 main.py',
          previous: '',
        ),
        isFalse,
      );
      expect(
        shouldEnterTerminalMode(
          text: '/ foo\nbar\nbaz',
          previous: '',
        ),
        isFalse,
      );
    });

    test('替换掉原来的一大段内容为「/ 」→ 不进入（不是打字触发）', () {
      expect(
        shouldEnterTerminalMode(text: '/ ', previous: 'hello world'),
        isFalse,
      );
    });

    test('斜杠不在第一个位置 → 永远不是终端模式', () {
      expect(hasTerminalPrefix('a / b'), isFalse);
      expect(hasTerminalPrefix('   / ls'), isFalse);
      expect(hasTerminalPrefix('// comment'), isFalse);
      expect(hasTerminalPrefix('/ls'), isFalse); // 第二字符不是空格
      expect(hasTerminalPrefix('/ ls'), isTrue);
    });

    test('已经在终端模式里继续打字，不算「进入」事件', () {
      expect(shouldEnterTerminalMode(text: '/ ls -l', previous: '/ '), isFalse);
    });
  });

  group('终端里调用 AI 工具（@工具名）', () {
    test('只写工具名 → 参数为空', () {
      final c = parseToolCommand('query_records');
      expect(c.name, 'query_records');
      expect(c.args, isEmpty);
      expect(c.rawArgs, isEmpty);
    });

    test('工具名 + JSON 参数', () {
      final c = parseToolCommand('query_records {"date_preset":"this_week","limit":5}');
      expect(c.name, 'query_records');
      expect(c.args!['date_preset'], 'this_week');
      expect(c.args!['limit'], 5);
    });

    test('工具名大小写不敏感、多余空格能容忍', () {
      final c = parseToolCommand('  @top_n   {"by":"quantity"}  ');
      expect(c.name, '@top_n'); // @ 由调用方先剥掉；这里只保证 trim + 小写
      final c2 = parseToolCommand('TOP_N {"by":"quantity"}');
      expect(c2.name, 'top_n');
      expect(c2.args!['by'], 'quantity');
    });

    test('参数不是 JSON 对象 → args 为 null（调用方提示用法）', () {
      expect(parseToolCommand('query_records abc').args, isNull);
      expect(parseToolCommand('query_records [1,2]').args, isNull);
      expect(parseToolCommand('query_records {"a":').args, isNull);
    });

    test('写操作不再被禁用（会生成确认卡片）', () {
      // 终端不再有「禁用清单」：写工具也能调，只是结果变成待确认动作
      final c = parseToolCommand('update_settings {"theme":"dark"}');
      expect(c.name, 'update_settings');
      expect(c.args!['theme'], 'dark');
      expect(c.pipeline, isEmpty);

      final c2 = parseToolCommand('create_records {"items":[{"quantity":10}]}');
      expect(c2.name, 'create_records');
      expect(c2.args, isNotNull);
    });

    test('@help 列出可用工具（不需要数据上下文）', () async {
      final n = TerminalSessionNotifier()..begin();
      await n.run('@help');
      expect(n.state.busy, isFalse);
      final text = n.state.lines.map((l) => l.text).join('\n');
      expect(text, contains('可用 AI 工具'));
      expect(text, contains('@query_records'));
      expect(text, contains('写操作'));
    });

    test('没接数据上下文时，@工具 给出明确提示而不是崩', () async {
      final n = TerminalSessionNotifier()..begin();
      await n.run('@query_records {}');
      expect(n.state.busy, isFalse);
      expect(
        n.state.lines.any((l) => l.text.contains('工具通道没接上')),
        isTrue,
      );
    });
  });

  group('常驻 shell 的输出分帧（cd 能累积的前提）', () {
    test('找到标记行：切出输出、cwd、退出码', () {
      final buf = 'bin\ndev\netc\n\n__DSH_xtoken__/etc__0\n';
      final r = LinuxShell.parseMarker(buf, 'xtoken');
      expect(r, isNotNull);
      expect(r!.output, 'bin\ndev\netc');
      expect(r.cwd, '/etc');
      expect(r.exitCode, 0);
    });

    test('命令无输出时也能正确切帧', () {
      final r = LinuxShell.parseMarker('\n__DSH_t1__/root__0\n', 't1');
      expect(r, isNotNull);
      expect(r!.output, '');
      expect(r.cwd, '/root');
    });

    test('非零退出码如实带回', () {
      final r = LinuxShell.parseMarker('ls: x: No such file\n__DSH_t2__/__1\n', 't2');
      expect(r!.exitCode, 1);
      expect(r.output, contains('No such file'));
    });

    test('还没收到标记行时返回 null（继续等）', () {
      expect(LinuxShell.parseMarker('partial output', 't3'), isNull);
    });

    test('标记 token 不匹配不算完成', () {
      expect(LinuxShell.parseMarker('a\n__DSH_other__/x__0\n', 'mine'), isNull);
    });

    test('多行输出原样保留', () {
      final r = LinuxShell.parseMarker(
        'line1\nline2\nline3\n\n__DSH_t4__/var__0\n',
        't4',
      );
      expect(r!.output.split('\n'), <String>['line1', 'line2', 'line3']);
    });
  });

  group('输入框尺寸不变', () {
    /// 复刻 chat_page 里的真实写法；宽度压到 190（手机上扣除两个图标按钮后
    /// 大约就是这个宽度），这样长 hint 会换行 —— 正是上次被撑高的原因。
    Widget build({required bool terminal, required bool busy}) => MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: <Widget>[
                  SizedBox(width: 34, height: 34),
                  const SizedBox(width: 2),
                  SizedBox(width: 34, height: 34),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 190,
                    child: Container(
                      decoration: terminal
                          ? BoxDecoration(
                              color: const Color(0xFF6750A4).withAlpha(12),
                              borderRadius: BorderRadius.circular(10),
                            )
                          : null,
                      child: TextField(
                        minLines: 1,
                        maxLines: 4,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontFamily: terminal ? 'monospace' : null,
                        ),
                        decoration: InputDecoration(
                          hintText: terminal
                              ? '输入命令，回车执行'
                              : (busy ? 'AI 正在思考…' : '问点什么，比如「本周多少件」'),
                          hintStyle: const TextStyle(fontSize: 13),
                          hintMaxLines: 1,
                          prefixText: terminal ? '❯ ' : null,
                          prefixStyle: const TextStyle(
                            fontSize: 13.5,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

    testWidgets('窄宽度下终端模式也不能变高', (tester) async {
      await tester.pumpWidget(build(terminal: false, busy: false));
      final normal = tester.getSize(find.byType(TextField)).height;

      await tester.pumpWidget(build(terminal: true, busy: false));
      final terminal = tester.getSize(find.byType(TextField)).height;

      expect(terminal, normal, reason: '终端模式不能把输入框撑高（hint 换行是元凶）');
    });

    testWidgets('长 hint 也不许换行', (tester) async {
      await tester.pumpWidget(build(terminal: false, busy: false));
      final oneLine = tester.getSize(find.byType(TextField)).height;
      expect(oneLine, lessThan(60), reason: '单行输入框高度应该在 40 上下');
    });
  });

  group('AI 知道终端模式的存在', () {
    test('系统提示词里写明了「/ 」终端与 @工具 用法', () {
      final p = AiService.defaultSystemPrompt;
      expect(p, contains('终端模式'));
      expect(p, contains('@工具名'));
      expect(p, contains('@help'));
      // 写操作在终端里也能用（生成确认卡片），提示词不能再说「不可用」
      expect(p, contains('确认卡片'));
      expect(p, isNot(contains('写操作（新建/修改/删除记录、改设置、管单位）在终端里**不可用**')));
    });
  });

  group('终端记录喂给 AI', () {
    String toolsJson(List<Map<String, String>> lines) =>
        jsonEncode(<String, dynamic>{
          'terminal': <String, dynamic>{
            'env': 'linux',
            'lines': lines,
          },
        });

    test('命令与输出都会进上下文', () {
      final text = terminalTranscript(toolsJson(<Map<String, String>>[
        <String, String>{'text': r'$ ls /etc', 'kind': 'command'},
        <String, String>{'text': 'alpine-release', 'kind': 'output'},
      ]));
      expect(text, isNotNull);
      expect(text, contains('终端'));
      expect(text, contains(r'$ ls /etc'));
      expect(text, contains('alpine-release'));
      expect(text, contains('可以直接引用'));
    });

    test('没有 terminal 负载 → null（普通消息不受影响）', () {
      expect(terminalTranscript(''), isNull);
      expect(terminalTranscript('{"traces":[]}'), isNull);
      expect(terminalTranscript('不是 json'), isNull);
      expect(
        terminalTranscript('{"terminal":{"lines":[]}}'),
        isNull,
      );
    });

    test('太长时保留最近的操作，并注明省略', () {
      final many = <Map<String, String>>[
        for (var i = 0; i < 400; i++)
          <String, String>{'text': 'line-$i-${'x' * 20}'},
      ];
      final text = terminalTranscript(toolsJson(many), maxChars: 300)!;
      expect(text.length, lessThan(500));
      expect(text, contains('更早的输出已省略'));
      expect(text, contains('line-399')); // 最新的还在
    });

    test('@工具调用也在记录里（AI 能看到自己工具的结果）', () {
      final text = terminalTranscript(toolsJson(<Map<String, String>>[
        <String, String>{'text': '@ @aggregate_records {"group_by":"styleModel"}', 'kind': 'command'},
        <String, String>{'text': '{"ok":true}', 'kind': 'output'},
      ]));
      expect(text, contains('@aggregate_records'));
      expect(text, contains('"ok":true'));
    });
  });

  group('终端卡片渲染', () {
    Future<void> pump(WidgetTester tester, Widget card) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: SingleChildScrollView(child: card))),
      );
    }

    testWidgets('展示命令与输出，标题带环境', (tester) async {
      await pump(
        tester,
        const TerminalCard(
          lines: <TerminalLine>[
            TerminalLine(r'$ ls /etc', kind: TerminalLineKind.command),
            TerminalLine('alpine-release'),
          ],
        ),
      );
      expect(find.text('终端 · linux'), findsOneWidget);
      expect(find.text(r'$ ls /etc'), findsOneWidget);
      expect(find.text('alpine-release'), findsOneWidget);
      // 结束态的卡片不再显示「进行中」提示
      expect(find.text('删掉「/ 」退出'), findsNothing);
    });

    testWidgets('进行中显示状态与提示', (tester) async {
      await pump(
        tester,
        const TerminalCard(lines: <TerminalLine>[], live: true),
      );
      expect(find.text('进行中'), findsOneWidget);
      expect(find.text('删掉「/ 」退出'), findsOneWidget);
      expect(find.textContaining('输入命令回车执行'), findsOneWidget);
    });

    testWidgets('运行中显示「运行中」', (tester) async {
      await pump(
        tester,
        const TerminalCard(lines: <TerminalLine>[], live: true, busy: true),
      );
      expect(find.text('运行中'), findsOneWidget);
    });
  });
}
