import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/piece_record.dart';
import '../data/services/photo_index_service.dart';
import '../data/services/photo_service.dart';
import '../ui/widgets/photo_thumb.dart';
import 'db_providers.dart';
import 'records_providers.dart';

/// 相册里的一张「已经用过的图」
class PhotoLibraryEntry {
  const PhotoLibraryEntry({
    required this.name,
    required this.styleModel,
    required this.color,
    required this.size,
    required this.at,
    required this.refs,
    required this.number,
  });

  final String name;

  /// 这张图第一次被哪条记录用上（用来在列表里标注「A1023 · M」）
  final String styleModel;
  final String color;
  final String size;
  final DateTime at;

  /// 有多少条记录在引用它（内容寻址，同一张图只存一份）
  final int refs;

  /// 图库编号（#12 里的 12），AI 可以用它精确引用这张图
  final int number;

  String get id => '#$number';

  String get label {
    final parts = <String>[
      if (styleModel.isNotEmpty) styleModel else '未填型号',
      if (color.isNotEmpty) color,
      if (size.isNotEmpty) size,
    ];
    return parts.join(' · ');
  }
}

/// 相册：本机所有**记录用过的照片**，按时间倒序。
///
/// 为什么要它：新建一条记录时，如果这个型号以前拍过图，没必要重拍/重传 ——
/// 直接引用同一份文件就行（图片是内容寻址的，多引用一份不占额外空间）。
final photoLibraryProvider = FutureProvider<List<PhotoLibraryEntry>>((ref) async {
  final records = ref.watch(recordsProvider).valueOrNull ?? const <PieceRecord>[];
  final gc = ref.read(photoGcProvider);

  final counts = await gc.refCounts();
  final newest = <String, PhotoLibraryEntry>{};

  for (final r in records) {
    final name = r.photoName;
    if (name.isEmpty) continue;
    final old = newest[name];
    if (old == null || r.createdAt.isAfter(old.at)) {
      newest[name] = PhotoLibraryEntry(
        name: name,
        styleModel: r.styleModel,
        color: r.color,
        size: r.size,
        at: r.createdAt,
        refs: counts[name] ?? 0,
        number: 0, // 下面统一分配
      );
    }
  }

  // 只保留文件真的还在的（记录可能引用着一张早被删掉的图）
  final alive = <PhotoLibraryEntry>[];
  for (final e in newest.values) {
    if (await PhotoService.instance.fileOf(e.name) != null) alive.add(e);
  }
  // 编号按「最早出现」的顺序分配，跟拍摄顺序一致；分配后不再变
  alive.sort((a, b) => a.at.compareTo(b.at));
  await PhotoIndexService.instance.ensure(alive.map((e) => e.name).toList());

  final out = <PhotoLibraryEntry>[
    for (final e in alive)
      PhotoLibraryEntry(
        name: e.name,
        styleModel: e.styleModel,
        color: e.color,
        size: e.size,
        at: e.at,
        refs: e.refs,
        number: PhotoIndexService.instance.numberOf(e.name) ?? 0,
      ),
  ];
  out.sort((a, b) => b.at.compareTo(a.at));
  return out;
});

/// 打开「选一张已有的图」面板；返回选中的文件名（取消返回 null）
Future<String?> pickExistingPhoto(
  BuildContext context,
  WidgetRef ref, {
  String preferStyleModel = '',
}) async {
  final entries = await ref.read(photoLibraryProvider.future);
  if (!context.mounted) return null;
  if (entries.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('还没有任何照片：先随便给一条记录拍一张，之后就能复用')),
    );
    return null;
  }

  final preferred = preferStyleModel.trim();
  final same = preferred.isEmpty
      ? const <PhotoLibraryEntry>[]
      : entries.where((e) => e.styleModel == preferred).toList();
  final others = entries.where((e) => !same.contains(e)).toList();

  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      Widget grid(List<PhotoLibraryEntry> list) => GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.72,
            ),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final e = list[i];
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.of(ctx).pop(e.name),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    PhotoThumb(name: e.name, size: 64, radius: 10),
                    const SizedBox(height: 3),
                    Text(
                      e.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 9.5, height: 1.2),
                    ),
                    Text(
                      e.refs > 1 ? '被 ${e.refs} 条引用' : '1 条记录在用',
                      style: TextStyle(
                        fontSize: 8.5,
                        height: 1.2,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            },
          );

      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        maxChildSize: 0.92,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.photo_library_outlined,
                    size: 17, color: scheme.primary),
                const SizedBox(width: 6),
                const Text(
                  '选一张已有的图',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  '共 ${entries.length} 张',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '同一张图只存一份，多条记录共用不占额外空间；删记录也不会把图删掉。',
              style: TextStyle(
                fontSize: 10.5,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (same.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                '同型号（$preferred）',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              grid(same),
            ],
            if (others.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                same.isEmpty ? '全部照片' : '其他照片',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              grid(others),
            ],
          ],
        ),
      );
    },
  );
}
