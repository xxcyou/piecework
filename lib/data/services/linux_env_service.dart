import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'linux_shell.dart';
import 'tool_bridge.dart';
import 'terminal_service.dart';

/// 轻量级 Linux 环境：proot + Alpine minirootfs。
///
/// 给 AI 的终端用（没有终端界面）。和 Android 自带的 `/system/bin/sh` 相比：
/// * 是**真正的 Linux 用户态**（Alpine，musl，busybox），有 `cat/grep/sed/awk/python` 等；
/// * `apk add` 能装包（走宿主网络，DNS 用内置 resolv.conf）；
/// * `id` 显示 root（proot 的 `-0` 假 root），但**改不了真系统** ——
///   proot 只是把 rootfs 里的路径重映射，宿主仍然是 App 的沙箱 uid。
///
/// 落点：`<AppDocuments>/linux/`
/// ```
/// bin/proot                libexec/loader, loader32
/// lib/libtalloc.so.2       lib/libandroid-shmem.so
/// rootfs/                  Alpine 根文件系统
/// tmp/                     PROOT_TMP_DIR
/// .installed               安装完成标记
/// ```
/// 首次使用把 assets 里的包解开（约 4MB，1~3 秒），之后直接用。
class LinuxEnvService {
  LinuxEnvService._();

  static final LinuxEnvService instance = LinuxEnvService._();

  static const String _assetDir = 'assets/linux';

  /// proot 本体以 `lib*.so` 的形式随 APK 分发，运行时在 nativeLibraryDir 里。
  /// （Android 10+ 不允许执行应用数据目录里的可执行文件，只能从这里 exec。）
  static const MethodChannel _channel = MethodChannel('piecework/public_storage');

  static const List<String> _libs = <String>[
    'libtalloc.so.2',
    'libandroid-shmem.so',
  ];

  /// 原生库目录（含 libproot.so 等）；拿不到就返回 null
  Future<String?> nativeLibDir() async {
    try {
      return await _channel.invokeMethod<String>('nativeLibDir');
    } catch (_) {
      return null;
    }
  }

  Directory? _root;

  Future<Directory> _linuxDir() async {
    if (_root != null) return _root!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'linux'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return _root = dir;
  }

  File _marker(Directory dir) => File(p.join(dir.path, '.installed'));

  /// 装好了没（只看标记文件，够快）
  Future<bool> isInstalled() async {
    try {
      final dir = await _linuxDir();
      return await _marker(dir).exists();
    } catch (_) {
      return false;
    }
  }

  /// 安装（幂等）。返回耗时毫秒。
  Future<int> ensureInstalled() async {
    final started = DateTime.now();
    final dir = await _linuxDir();
    if (await _marker(dir).exists()) return 0;

    // 1) 依赖库（proot 本体和 loader 在 nativeLibraryDir，不用解压）
    for (final name in _libs) {
      final bytes = await rootBundle.load('$_assetDir/$name');
      final f = File(p.join(dir.path, 'lib', name));
      await f.parent.create(recursive: true);
      await f.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
    }

    // 2) rootfs：用系统 tar 解（保留符号链接与权限，Dart 解 tar 不保 symlink）
    final rootfs = Directory(p.join(dir.path, 'rootfs'));
    if (!await rootfs.exists()) await rootfs.create(recursive: true);
    final tarball = File(p.join(dir.path, 'alpine.tar.gz'));
    final asset = await rootBundle.load('$_assetDir/alpine.tar.gz');
    await tarball.writeAsBytes(
      asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
      flush: true,
    );
    final untar = await Process.run(
      Platform.isAndroid ? '/system/bin/tar' : '/bin/tar',
      <String>['-xzf', tarball.path, '-C', rootfs.path],
    );
    if (untar.exitCode != 0) {
      throw StateError('解压 Alpine 失败：${untar.stderr}');
    }
    await tarball.delete();

    // 3) DNS：Android 没有 /etc/resolv.conf，写一个进去，apk 才能联网
    final resolv = File(p.join(rootfs.path, 'etc', 'resolv.conf'));
    await resolv.parent.create(recursive: true);
    await resolv.writeAsString(
      'nameserver 1.1.1.1\nnameserver 8.8.8.8\nnameserver 223.5.5.5\n',
      flush: true,
    );

    // 4) 临时目录 + 完成标记
    await Directory(p.join(dir.path, 'tmp')).create(recursive: true);
    await _marker(dir).writeAsString(DateTime.now().toIso8601String());

    return DateTime.now().difference(started).inMilliseconds;
  }



  /// proot 的调用参数与环境（run 和常驻 shell 共用）
  Future<({String proot, String rootfs, List<String> args, Map<String, String> env})>
      _invocation() async {
    final dir = await _linuxDir();
    final libDir = await nativeLibDir();
    if (libDir == null || libDir.isEmpty) {
      throw StateError('拿不到 nativeLibraryDir，proot 无法执行');
    }
    final proot = p.join(libDir, 'libproot.so');
    final rootfs = p.join(dir.path, 'rootfs');
    return (
      proot: proot,
      rootfs: rootfs,
      args: <String>[
        '-0',
        '-r', rootfs,
        '-b', '/dev',
        '-b', '/proc',
        '-b', '/sys',
        '-w', '/root',
        // 把应用的 tmp 目录挂进 rootfs：AI 把工具结果写进 <docs>/linux/tmp/xxx.json，
        // 在 shell 里就能用 /tmp/xxx.json 接管道（cat /tmp/x.json | grep ...）
        '-b', '${dir.path}/tmp:/tmp',
      ],
      env: <String, String>{
        'PROOT_TMP_DIR': p.join(dir.path, 'tmp'),
        'PROOT_LOADER': p.join(libDir, 'libprootloader.so'),
        'PROOT_LOADER_32': p.join(libDir, 'libprootloader32.so'),
        'LD_LIBRARY_PATH': '${p.join(dir.path, 'lib')}:$libDir',
        'PATH': '/system/bin:/system/xbin',
        'HOME': p.join(dir.path, 'tmp'),
        'TMPDIR': p.join(dir.path, 'tmp'),
        'TERM': 'dumb',
        'LANG': 'C.UTF-8',
      },
    );
  }

  /// 开一条**常驻** shell（终端模式用）：cd / export 能累积，不像一次性命令那样每条都回到 /root
  Future<LinuxShell> openShell({ToolBridge? bridge}) async {
    await ensureInstalled();
    final inv = await _invocation();
    final dir = await _linuxDir();
    bridge?.start();
    return LinuxShell.start(
      bridge: bridge,
      executable: inv.proot,
      arguments: <String>[...inv.args, '/bin/sh'],
      environment: <String, String>{
        ...inv.env,
        // 常驻 shell 里直接把 PATH 设成 Linux 的，省得每条命令都 export；
        // 工具桥目录排最前，@工具名 才能直接当命令用
        'PATH': bridge == null
            ? '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
            : '/tmp/dsh-tool/bin:'
                '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
        'HOME': '/root',
        'TMPDIR': '/tmp',
      },
      workingDirectory: dir.path,
    );
  }

  /// 在 Linux 环境里跑一条命令
  Future<TerminalResult> run(
    String command, {
    int timeoutMs = 30000,
    ToolBridge? bridge,
  }) async {
    final blocked = TerminalService.instance.checkCommand(command);
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

    final started = DateTime.now();
    try {
      await ensureInstalled();
    } catch (e) {
      return TerminalResult(
        command: command,
        exitCode: -1,
        stdout: '',
        stderr: 'Linux 环境安装失败：$e',
        durationMs: DateTime.now().difference(started).inMilliseconds,
      );
    }

    final dir = await _linuxDir();
    final libDir = await nativeLibDir();
    if (libDir == null || libDir.isEmpty) {
      return TerminalResult(
        command: command,
        exitCode: -1,
        stdout: '',
        stderr: '拿不到 nativeLibraryDir，proot 无法执行',
        durationMs: DateTime.now().difference(started).inMilliseconds,
      );
    }
    final proot = p.join(libDir, 'libproot.so');
    final rootfs = p.join(dir.path, 'rootfs');
    final limit = timeoutMs.clamp(3000, TerminalService.maxTimeoutMs);

    // 命令里先补 PATH：proot 不会帮我们设，Android 的 PATH 在 rootfs 里全是无效路径
    // 有工具桥时，把 /tmp/dsh-tool/bin 放进 PATH，@工具名 才能在脚本里用
    final pathPrefix = bridge == null
        ? '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
        : '/tmp/dsh-tool/bin:'
            '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin';
    final wrapped =
        'export PATH=$pathPrefix; '
        'export HOME=/root; cd /root 2>/dev/null || cd /; $command';

    final args = <String>[
      '-0', // 假 root
      '-r', rootfs,
      '-b', '/dev',
      '-b', '/proc',
      '-b', '/sys',
      '-w', '/root',
      // 和常驻 shell 保持一致：应用 tmp 目录挂到 /tmp
      '-b', '${dir.path}/tmp:/tmp',
      '/bin/sh',
      '-c', wrapped,
    ];

    bridge?.start();
    Process proc;
    try {
      proc = await Process.start(
        proot,
        args,
        workingDirectory: dir.path,
        environment: <String, String>{
          'PROOT_TMP_DIR': p.join(dir.path, 'tmp'),
          'PROOT_LOADER': p.join(libDir, 'libprootloader.so'),
          'PROOT_LOADER_32': p.join(libDir, 'libprootloader32.so'),
          // 依赖库（libtalloc.so.2 等）在应用目录；nativeLibraryDir 兜底
          'LD_LIBRARY_PATH': '${p.join(dir.path, 'lib')}:$libDir',
          'PATH': '/system/bin:/system/xbin',
          'HOME': p.join(dir.path, 'tmp'),
          'TMPDIR': p.join(dir.path, 'tmp'),
          'TERM': 'dumb',
          'LANG': 'C.UTF-8',
        },
      );
    } catch (e) {
      return TerminalResult(
        command: command,
        exitCode: -1,
        stdout: '',
        stderr: '启动 proot 失败：$e',
        durationMs: DateTime.now().difference(started).inMilliseconds,
      );
    }

    final out = StringBuffer();
    final err = StringBuffer();
    var truncated = false;

    void collect(StringBuffer into, String chunk) {
      if (into.length >= TerminalService.maxOutputChars) {
        truncated = true;
        return;
      }
      final room = TerminalService.maxOutputChars - into.length;
      if (chunk.length > room) {
        into.write(chunk.substring(0, room));
        truncated = true;
      } else {
        into.write(chunk);
      }
    }

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

    await Future.wait(<Future<void>>[outFuture, errFuture]).timeout(
      const Duration(seconds: 3),
      onTimeout: () => const <void>[],
    );
    if (exitCode == -9) {
      collect(err, '\n[已超时 ${limit ~/ 1000}s，进程被强制结束]');
    }
    await bridge?.dispose();

    return TerminalResult(
      command: command,
      exitCode: exitCode,
      stdout: out.toString().trimRight(),
      stderr: err.toString().trimRight(),
      durationMs: DateTime.now().difference(started).inMilliseconds,
      truncated: truncated,
    );
  }

  /// 给 AI 看的环境说明
  static const String description =
      'Alpine Linux（proot 模拟，假 root）。有 busybox 全套命令（cat/grep/sed/awk/find/'
      'tar/wget 等），可以用 apk add 装包（走宿主网络）。文件系统是隔离的 rootfs，'
      '改不了 Android 系统本身。';
}
