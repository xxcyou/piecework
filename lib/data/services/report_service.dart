import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:gal/gal.dart';

/// 报表导出：把 RepaintBoundary 里的报表画布抓成 PNG，再存进系统相册。
class ReportService {
  ReportService._();

  /// 抓图。
  ///
  /// [targetWidthPx] 是期望的导出像素宽度（默认 2400，约等于 A4 300dpi 的 80%，
  /// 手机上放大看文字依然锐利）。实际倍率按画布逻辑宽度换算，并夹在 1.0~8.0，
  /// 防止小屏设备算出离谱的倍率导致内存溢出。
  static Future<Uint8List> capturePng(
    GlobalKey boundaryKey, {
    int targetWidthPx = 2400,
  }) async {
    final ctx = boundaryKey.currentContext;
    if (ctx == null) {
      throw StateError('报表还没渲染完成，请稍后再试。');
    }
    final obj = ctx.findRenderObject();
    if (obj is! RenderRepaintBoundary) {
      throw StateError('导出区域不是 RepaintBoundary，请检查 ReportPage 结构。');
    }

    final logicalWidth = obj.size.width;
    if (logicalWidth <= 0) {
      throw StateError('报表宽度为 0，无法导出。');
    }

    var ratio = targetWidthPx / logicalWidth;
    if (ratio < 1.0) ratio = 1.0;
    if (ratio > 8.0) ratio = 8.0;

    final ui.Image image = await obj.toImage(pixelRatio: ratio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('PNG 编码失败。');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  /// 存入系统相册（相册名「计件报表」）。
  ///
  /// 返回 null 表示成功，返回字符串表示失败原因。
  static Future<String?> saveToGallery(
    Uint8List png, {
    required String name,
  }) async {
    try {
      var granted = await Gal.hasAccess();
      if (!granted) {
        granted = await Gal.requestAccess();
      }
      if (!granted) {
        return '没有相册写入权限。请到系统设置里允许本应用访问照片。';
      }
      await Gal.putImageBytes(png, name: name, album: '计件报表');
      return null;
    } on GalException catch (e) {
      return '保存失败：${e.type.name}（${e.platformException.message}）';
    } catch (e) {
      return '保存失败：$e';
    }
  }
}
