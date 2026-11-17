import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 一次性标记（「引导看过没有」这类），落在应用文档目录的小文件里。
///
/// 用文件而不是 Isar：这些标记跟业务数据无关，不参与备份/恢复，
/// 也不该污染 AppSetting 的字段。
class AppFlags {
  AppFlags._();

  static Future<File> _file(String name) async {
    final docs = await getApplicationDocumentsDirectory();
    return File(p.join(docs.path, 'flag_$name'));
  }

  static Future<bool> seen(String name) async {
    try {
      return await (await _file(name)).exists();
    } catch (_) {
      // 读不到就当已看过，别反复打扰
      return true;
    }
  }

  static Future<void> mark(String name) async {
    try {
      await (await _file(name)).writeAsString('1', flush: true);
    } catch (_) {}
  }

}
