import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/app_info.dart';

/// 下载进度（0..1，未知总量时为 null）
typedef UpdateProgress = void Function(double? fraction, int received, int total);

/// 应用内自动更新：下载 APK → 交给系统安装器（不是跳浏览器）
class UpdateInstaller {
  UpdateInstaller._();

  static final UpdateInstaller instance = UpdateInstaller._();

  static const MethodChannel _ch = MethodChannel('piecework/public_storage');

  /// 当前下载的客户端（取消时用）
  http.Client? _client;

  /// 取消正在进行的下载
  void cancel() {
    _client?.close();
    _client = null;
  }

  /// 下载 APK 到应用私有目录，返回文件路径
  ///
  /// * 每块之间 20 秒没数据就报错（防止进度条一直卡着不动）
  /// * 支持 [cancel]
  Future<String> download(
    String url, {
    UpdateProgress? onProgress,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'update'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File(p.join(dir.path, 'piecework-$kAppVersionCode.apk'));
    if (await file.exists()) await file.delete();

    final client = http.Client();
    _client = client;
    try {
      final req = http.Request('GET', Uri.parse(url));
      final res = await client.send(req).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        throw FormatException('下载失败：HTTP ${res.statusCode}');
      }
      final total = res.contentLength ?? 0;
      var received = 0;
      final sink = file.openWrite();
      try {
        await for (final chunk in res.stream.timeout(timeout)) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(
            total > 0 ? received / total : null,
            received,
            total,
          );
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      if (received < 1024) {
        throw const FormatException('下载内容不完整（文件太小）');
      }
      if (total > 0 && received != total) {
        throw FormatException('下载不完整：$received / $total 字节，请重试');
      }
      return file.path;
    } finally {
      _client = null;
      client.close();
    }
  }

  /// 打开「安装未知应用」设置页
  Future<bool> openInstallSettings() async {
    try {
      final ok =
          await _ch.invokeMethod<bool>('openInstallSettings', const <String, dynamic>{});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 把安装包存到系统「下载」目录，返回可点开的地址（最后的兜底）
  Future<String?> exportToDownloads(String apkPath) async {
    try {
      return await _ch.invokeMethod<String>('exportApk', <String, dynamic>{
        'path': apkPath,
      });
    } catch (_) {
      return null;
    }
  }

  /// 调起系统安装器；返回 (成功?, 走哪条通道, 错误信息)
  Future<({bool ok, String via, String message})> install(String apkPath) async {
    try {
      final r = await _ch.invokeMethod<dynamic>('installApk', <String, dynamic>{
        'path': apkPath,
      });
      if (r is Map) {
        return (
          ok: r['ok'] == true,
          via: '${r['via'] ?? ''}',
          message: '${r['error'] ?? ''}',
        );
      }
      return (ok: r == true, via: 'intent', message: '');
    } on PlatformException catch (e) {
      return (ok: false, via: '', message: e.message ?? e.code);
    } catch (e) {
      return (ok: false, via: '', message: '$e');
    }
  }

  /// 下载并安装（一步到位）
  Future<({bool ok, String via, String message})> downloadAndInstall(
    String apkUrl, {
    UpdateProgress? onProgress,
  }) async {
    final path = await download(accelerateUrl(apkUrl), onProgress: onProgress);
    return install(path);
  }
}
