import 'package:flutter/material.dart';

import '../../data/services/photo_service.dart';

/// 照片缩略图。文件不存在 / 读取失败时显示占位，不会让整张卡片崩掉。
class PhotoThumb extends StatelessWidget {
  const PhotoThumb({
    super.key,
    required this.name,
    this.size = 62,
    this.radius = 12,
    this.sub = PhotoService.recordsDir,
  });

  final String name;
  final double size;
  final double radius;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // size 允许传 double.infinity（放进 AspectRatio 里铺满）：
    // 但 cacheWidth 必须是有限值，否则 (infinity * 3).round() 会直接抛异常，
    // 表现就是「点开大图一片灰白」。
    final finite = size.isFinite;

    Widget placeholder() => Container(
          width: finite ? size : null,
          height: finite ? size : null,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withAlpha(120),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Icon(
            Icons.image_not_supported_outlined,
            size: (finite ? size : 96) * 0.34,
            color: scheme.onSurfaceVariant.withAlpha(120),
          ),
        );

    if (name.isEmpty) return placeholder();

    final file = PhotoService.instance.syncFile(name, sub: sub);
    if (file == null) return placeholder();

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.file(
        file,
        width: finite ? size : null,
        height: finite ? size : null,
        fit: BoxFit.cover,
        cacheWidth: finite ? (size * 3).round() : null,
        errorBuilder: (_, __, ___) => placeholder(),
      ),
    );
  }
}
