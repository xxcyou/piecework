import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 图片编号：把内容寻址的长文件名（`c3f9a...jpg`）映射成短编号 `#12`。
///
/// 为什么需要：文件名是 SHA-256 前 32 位，人和模型都记不住。
/// 有了编号，用户可以说「把 #12 那张图关联到新记录」，AI 也能用 `photo_ids: [12]`
/// 精确挑图。
///
/// 落点：`<AppDocuments>/photo_index.json`
/// ```json
/// {"next": 13, "map": {"c3f9a....jpg": 1, "c7b2e....jpg": 2}}
/// ```
/// 编号一旦分配就**不再变**（除非文件被删），所以对话里说过的 #12 一直有效。
class PhotoIndexService {
  PhotoIndexService._();

  static final PhotoIndexService instance = PhotoIndexService._();

  final Map<String, int> _map = <String, int>{};
  int _next = 1;
  bool _loaded = false;
  File? _file;

  Future<File> _cfg() async {
    if (_file != null) return _file!;
    final docs = await getApplicationDocumentsDirectory();
    return _file = File(p.join(docs.path, 'photo_index.json'));
  }

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final f = await _cfg();
      if (!await f.exists()) return;
      final raw = jsonDecode(await f.readAsString());
      if (raw is! Map) return;
      final map = raw['map'];
      if (map is Map) {
        for (final e in map.entries) {
          final v = e.value;
          if (v is num) _map[e.key.toString()] = v.toInt();
        }
      }
      final next = raw['next'];
      _next = next is num ? next.toInt() : _map.length + 1;
    } catch (_) {
      // 读坏了就从 1 重新开始，不阻塞主流程
    }
  }

  Future<void> _save() async {
    try {
      final f = await _cfg();
      await f.writeAsString(
        jsonEncode(<String, dynamic>{'next': _next, 'map': _map}),
        flush: true,
      );
    } catch (_) {}
  }

  /// 确保编号表已加载（工具里按编号查图之前调用）
  Future<void> ensureLoaded() => _load();

  /// 给一批图片分配编号（幂等）。[names] 的顺序决定新编号的先后，
  /// 调用方按「最早出现」排序，编号就跟拍摄顺序一致。
  Future<void> ensure(List<String> names) async {
    await _load();
    var changed = false;
    for (final name in names) {
      if (name.isEmpty) continue;
      if (_map.containsKey(name)) continue;
      _map[name] = _next++;
      changed = true;
    }
    if (changed) await _save();
  }

  /// 查编号（没分配过返回 null）
  int? numberOf(String name) {
    if (!_loaded) return null;
    return _map[name];
  }

  /// `#12`；没编号时返回空串
  String label(String name) {
    final n = numberOf(name);
    return n == null ? '' : '#$n';
  }

  /// 按编号反查文件名
  String? nameOf(int number) {
    for (final e in _map.entries) {
      if (e.value == number) return e.key;
    }
    return null;
  }

  /// 全部编号（给 AI 用）
  Map<String, int> get all => Map<String, int>.unmodifiable(_map);
}
