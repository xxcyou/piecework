import 'package:flutter/services.dart';

/// 用系统浏览器打开链接（更新下载页 / 项目主页 / 加好友）
class UrlOpener {
  static const MethodChannel _ch = MethodChannel('piecework/public_storage');

  static Future<bool> open(String url) async {
    if (url.trim().isEmpty) return false;
    try {
      final ok = await _ch.invokeMethod<bool>('openUrl', <String, dynamic>{
        'url': url,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}
