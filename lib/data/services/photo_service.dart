import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 照片文件管理。
///
/// 存储位置：`<AppDocuments>/photos/`（货物实拍）与 `<AppDocuments>/chat_photos/`（AI 对话图）。
/// 这两个目录都在 **应用私有沙盒** 内：
/// * 不会出现在系统相册；
/// * 卸载 App 才会被系统清掉；
/// * 备份时按需打包（见 BackupService）。
///
/// 数据库里只存文件名，不存绝对路径 —— 沙盒路径会随系统版本/迁移变化。
class PhotoService {
  PhotoService._();

  static final PhotoService instance = PhotoService._();

  static const String recordsDir = 'photos';
  static const String chatDir = 'chat_photos';

  /// 应用文档目录缓存：由 main() 调 [prime] 注入，
  /// 这样列表里的缩略图可以**同步**拿到 File，不必每个格子都 await 一次。
  Directory? _docsCache;

  void prime(Directory docs) => _docsCache = docs;

  /// 同步取文件句柄（未 prime 时返回 null，UI 侧做空占位）
  File? syncFile(String name, {String sub = recordsDir}) {
    final docs = _docsCache;
    if (docs == null || name.isEmpty) return null;
    return File(p.join(docs.path, sub, name));
  }

  /// 保存原始字节 → 压缩 → 落盘，返回文件名
  ///
  /// **内容寻址去重**：文件名由压缩后字节的 SHA-256 决定，
  /// 同一张图（哪怕分两次拍/传）只会存一份，多出来的记录直接引用同一个文件名。
  Future<String> saveBytes(
    Uint8List raw, {
    String sub = recordsDir,
    int maxSide = 1600,
    int quality = 85,
  }) async {
    final compressed = compressJpeg(raw, maxSide: maxSide, quality: quality);
    return storeDeduped(compressed, sub: sub);
  }

  /// 内容寻址的文件名：`c<sha256 前 32 位>.jpg`
  static String contentName(Uint8List bytes) {
    final digest = sha256.convert(bytes).toString();
    return 'c${digest.substring(0, 32)}.jpg';
  }

  /// 字节直接落盘（不压缩），已存在同内容文件就复用，返回文件名
  Future<String> storeDeduped(Uint8List bytes, {String sub = recordsDir}) async {
    final name = contentName(bytes);
    final dir = await _subDir(sub);
    final file = File(p.join(dir.path, name));
    if (!await file.exists()) {
      await file.writeAsBytes(bytes, flush: true);
    }
    return name;
  }

  /// 纯 Dart 压缩：长边限制到 [maxSide]，JPEG 质量 [quality]
  Uint8List compressJpeg(
    Uint8List raw, {
    int maxSide = 1600,
    int quality = 85,
  }) {
    try {
      final decoded = img.decodeImage(raw);
      if (decoded == null) return raw;

      img.Image out = decoded;
      if (decoded.width > maxSide || decoded.height > maxSide) {
        out = decoded.width >= decoded.height
            ? img.copyResize(
                decoded,
                width: maxSide,
                interpolation: img.Interpolation.average,
              )
            : img.copyResize(
                decoded,
                height: maxSide,
                interpolation: img.Interpolation.average,
              );
      }
      return Uint8List.fromList(img.encodeJpg(out, quality: quality));
    } catch (_) {
      // 解码失败（极少见的格式）就原样保存，至少不丢这张货图
      return raw;
    }
  }

  Future<Directory> _subDir(String sub) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, sub));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 取文件对象（不存在返回 null）
  Future<File?> fileOf(String name, {String sub = recordsDir}) async {
    if (name.isEmpty) return null;
    final dir = await _subDir(sub);
    final f = File(p.join(dir.path, name));
    return await f.exists() ? f : null;
  }

  Future<Uint8List?> bytesOf(String name, {String sub = recordsDir}) async {
    final f = await fileOf(name, sub: sub);
    if (f == null) return null;
    try {
      return await f.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String name, {String sub = recordsDir}) async {
    if (name.isEmpty) return;
    final f = await fileOf(name, sub: sub);
    if (f != null) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  Future<void> deleteMany(Iterable<String> names, {String sub = recordsDir}) async {
    for (final n in names) {
      await delete(n, sub: sub);
    }
  }

  /// 列出目录里全部文件名（清理统计用）
  Future<List<String>> listNames({String sub = recordsDir}) async {
    final dir = await _subDir(sub);
    final out = <String>[];
    await for (final entity in dir.list()) {
      if (entity is File) out.add(p.basename(entity.path));
    }
    return out;
  }

  /// 把对话里发的图片复制一份进记录照片目录。
  ///
  /// 记录只能引用 `photos/` 下的文件，所以关联前必须复制。
  /// 复制走内容寻址：**同一张图只会存一份**，多条记录共用同一个文件名；
  /// 删记录时由 [PhotoGc.deleteIfUnreferenced] 判断还有没有人用。
  Future<String?> copyToRecords(String chatPhotoName) async {
    final bytes = await bytesOf(chatPhotoName, sub: chatDir);
    if (bytes == null) return null;
    return storeDeduped(bytes, sub: recordsDir);
  }

  /// 恢复备份时写入图片
  Future<void> writeRaw(String name, Uint8List bytes, {String sub = recordsDir}) async {
    final dir = await _subDir(sub);
    final f = File(p.join(dir.path, name));
    await f.writeAsBytes(bytes, flush: true);
  }
}
