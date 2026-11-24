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

  /// 下载 APK 到应用私有目录，返回文件路径
  Future<String> download(
    String url, {
    UpdateProgress? onProgress,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'update'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File(p.join(dir.path, 'piecework-$kAppVersionCode.apk'));
    if (await file.exists()) await file.delete();

    final client = http.Client();
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
      return file.path;
    } finally {
      client.close();
    }
  }

  /// 调起系统安装器；返回 (成功?, 错误信息)
  Future<({bool ok, String message})> install(String apkPath) async {
    try {
      final ok = await _ch.invokeMethod<bool>('installApk', <String, dynamic>{
        'path': apkPath,
      });
      return (ok: ok ?? false, message: '');
    } on PlatformException catch (e) {
      return (ok: false, message: e.message ?? e.code);
    } catch (e) {
      return (ok: false, message: '$e');
    }
  }

  /// 下载并安装（一步到位）
  Future<({bool ok, String message})> downloadAndInstall(
    String apkUrl, {
    UpdateProgress? onProgress,
  }) async {
    final path = await download(accelerateUrl(apkUrl), onProgress: onProgress);
    return install(path);
  }
}
