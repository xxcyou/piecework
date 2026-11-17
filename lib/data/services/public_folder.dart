import 'dart:io';

import 'package:flutter/services.dart';

/// 公共目录里的一个文件
class FolderFile {
  const FolderFile({
    required this.name,
    required this.size,
    required this.modified,
  });

  final String name;
  final int size;

  /// 毫秒时间戳
  final int modified;

  DateTime get modifiedAt => DateTime.fromMillisecondsSinceEpoch(modified);
}

/// 公共存储（/storage/emulated/0/...）访问桥。
///
/// Android 10+ 不能直接按路径写公共目录，必须先由用户通过系统文件选择器
/// 授权一个文件夹（SAF），App 才能拿到**持久化**读写权限。
/// 这里只是 Dart 侧的薄封装，真正的实现见 MainActivity.kt。
class PublicFolder {
  PublicFolder._();

  static const MethodChannel _channel = MethodChannel('piecework/public_storage');

  /// 只在 Android 上可用（桌面/测试环境没有这个通道）
  static bool get supported => Platform.isAndroid;

  /// 弹系统文件夹选择器，用户点「允许」后返回授权的目录
  static Future<FolderGrant?> pick() async {
    if (!supported) return null;
    final raw = await _channel.invokeMapMethod<String, dynamic>('pickFolder');
    if (raw == null) return null;
    final uri = raw['uri'] as String?;
    if (uri == null || uri.isEmpty) return null;
    return FolderGrant(uri: uri, label: (raw['label'] as String?) ?? '已授权目录');
  }

  /// 之前授权的目录现在还有效吗（用户可能在系统设置里撤销过）
  static Future<bool> hasPermission(String uri) async {
    if (!supported || uri.isEmpty) return false;
    try {
      return await _channel.invokeMethod<bool>('hasPermission', <String, dynamic>{
            'uri': uri,
          }) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> write(String uri, String name, Uint8List bytes) async {
    if (!supported) throw UnsupportedError('公共目录只在 Android 上可用');
    await _channel.invokeMethod<String>('writeFile', <String, dynamic>{
      'uri': uri,
      'name': name,
      'bytes': bytes,
    });
  }

  static Future<List<FolderFile>> list(String uri, {String prefix = ''}) async {
    if (!supported || uri.isEmpty) return const <FolderFile>[];
    final raw = await _channel.invokeListMethod<dynamic>('listFiles', <String, dynamic>{
      'uri': uri,
      'prefix': prefix,
    });
    if (raw == null) return const <FolderFile>[];
    final out = <FolderFile>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final name = e['name'] as String?;
      if (name == null) continue;
      out.add(FolderFile(
        name: name,
        size: (e['size'] as num?)?.toInt() ?? 0,
        modified: (e['modified'] as num?)?.toInt() ?? 0,
      ));
    }
    return out;
  }

  static Future<Uint8List> read(String uri, String name) async {
    if (!supported) throw UnsupportedError('公共目录只在 Android 上可用');
    final bytes = await _channel.invokeMethod<Uint8List>('readFile', <String, dynamic>{
      'uri': uri,
      'name': name,
    });
    return bytes ?? Uint8List(0);
  }

  static Future<bool> delete(String uri, String name) async {
    if (!supported || uri.isEmpty) return false;
    return await _channel.invokeMethod<bool>('deleteFile', <String, dynamic>{
          'uri': uri,
          'name': name,
        }) ??
        false;
  }
}

class FolderGrant {
  const FolderGrant({required this.uri, required this.label});

  final String uri;
  final String label;
}
