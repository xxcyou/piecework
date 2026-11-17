import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/data/services/terminal_service.dart';

/// 给 AI 用的轻量终端：能跑、有边界、危险命令拦得住。
void main() {
  final term = TerminalService.instance;

  group('能正常执行', () {
    test('echo 返回 stdout 和 0', () async {
      final r = await term.run('echo hello-dsh');
      expect(r.blocked, isFalse);
      expect(r.exitCode, 0);
      expect(r.stdout, 'hello-dsh');
      expect(r.stderr, isEmpty);
      expect(r.ok, isTrue);
    });

    test('stderr 单独收，非零退出码如实返回', () async {
      final r = await term.run('echo oops 1>&2; exit 3');
      expect(r.exitCode, 3);
      expect(r.stderr, 'oops');
      expect(r.ok, isFalse);
    });

    test('管道与重定向可用', () async {
      final r = await term.run("printf 'b\\na\\nc\\n' | sort | head -n 2");
      expect(r.stdout.trim().split('\n'), <String>['a', 'b']);
    });

    test('工作目录可指定', () async {
      final r = await term.run('pwd', cwd: '/tmp');
      expect(r.stdout.trim(), '/tmp');
    });

    test('结果能 JSON 化（给模型看）', () async {
      final r = await term.run('echo x');
      final json = r.toJson();
      expect(json['ok'], isTrue);
      expect(json['stdout'], 'x');
      expect(json['exitCode'], 0);
    });
  });

  group('边界', () {
    test('空命令被拒', () async {
      final r = await term.run('   ');
      expect(r.blocked, isTrue);
      expect(r.blockedReason, contains('空'));
    });

    test('超长命令被拒', () async {
      final r = await term.run('echo ${'a' * 2500}');
      expect(r.blocked, isTrue);
    });

    test('超时会强杀，并标记截断', () async {
      final r = await term.run('sleep 5', timeoutMs: 1000);
      expect(r.exitCode, -9);
      expect(r.truncated, isTrue);
      expect(r.stderr, contains('超时'));
    });

    test('输出超上限会截断', () async {
      final r = await term.run('seq 1 20000');
      expect(r.truncated, isTrue);
      expect(r.stdout.length, lessThanOrEqualTo(TerminalService.maxOutputChars));
    });
  });

  group('危险命令拦截', () {
    const denied = <String>[
      'rm -rf /',
      'rm -rf /data',
      'mkfs.ext4 /dev/block/sda1',
      'dd if=/dev/zero of=/dev/block/sda',
      'pm uninstall com.example.piecework',
      'pm clear com.example.piecework',
      'reboot',
      'su -c id',
      'settings put global adb_enabled 1',
      'am force-stop com.example.piecework',
      'killall -9 system_server',
      'chmod 777 /',
      'mount -o rw,remount /system',
      ':(){ :|:& };:',
    ];

    for (final cmd in denied) {
      test('拦：$cmd', () {
        expect(term.checkCommand(cmd), isNotNull);
      });
    }

    test('正常命令不误拦', () {
      const safe = <String>[
        'ls -l',
        'cat foo.txt',
        'df -h',
        'du -sh .',
        'getprop ro.product.model',
        'ls /sdcard/Download',
        'echo rm -rf',
        'grep -r foo .',
      ];
      for (final cmd in safe) {
        expect(term.checkCommand(cmd), isNull, reason: cmd);
      }
    });
  });
}
