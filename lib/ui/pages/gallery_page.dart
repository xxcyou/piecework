import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/money.dart';
import '../../data/models/piece_record.dart';
import '../../providers/photo_library_providers.dart';
import '../../providers/records_providers.dart';
import '../widgets/photo_thumb.dart';
import 'record_edit_page.dart';

/// 图库：本机所有货物实拍，按编号 + 拍摄顺序排。
///
/// 用途：
/// * 点开一张图 → 看它被哪些记录引用（数量/单价/时间）；
/// * 长按 → 复制编号（`#12`），贴给 AI 说「把 #12 关联到新记录」；
/// * AI 也能用编号调用 `show_photos` 把图片卡片展示出来。
class GalleryPage extends ConsumerStatefulWidget {
  const GalleryPage({super.key});

  @override
  ConsumerState<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends ConsumerState<GalleryPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(photoLibraryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('图库'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                async.valueOrNull == null
                    ? ''
                    : '${async.valueOrNull!.length} 张',
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('读图库失败：$e')),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.photo_library_outlined,
                      size: 44, color: scheme.onSurfaceVariant.withAlpha(120)),
                  const SizedBox(height: 10),
                  const Text('还没有图片'),
                  const SizedBox(height: 4),
                  Text(
                    '给记录拍一张货物实拍，就会出现在这里',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          final q = _query.trim().toLowerCase();
          final shown = q.isEmpty
              ? entries
              : entries.where((e) {
                  return e.label.toLowerCase().contains(q) ||
                      e.id.toLowerCase().contains(q) ||
                      e.name.toLowerCase().contains(q);
                }).toList();

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '搜型号 / 颜色 / 码数 / 编号（#12）',
                    hintStyle: const TextStyle(fontSize: 12.5),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 34, minHeight: 0),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.66,
                  ),
                  itemCount: shown.length,
                  itemBuilder: (_, i) {
                    final e = shown[i];
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openDetail(e),
                      onLongPress: () async {
                        await Clipboard.setData(ClipboardData(text: e.id));
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已复制编号 ${e.id}')),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Stack(
                            children: <Widget>[
                              PhotoThumb(name: e.name, size: 104, radius: 12),
                              Positioned(
                                left: 4,
                                top: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(150),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    e.id,
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              if (e.refs > 1)
                                Positioned(
                                  right: 4,
                                  bottom: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: scheme.primary.withAlpha(200),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${e.refs} 条',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            e.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 10.5, height: 1.2),
                          ),
                          Text(
                            Fmt.date(e.at),
                            style: TextStyle(
                              fontSize: 9,
                              height: 1.2,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openDetail(PhotoLibraryEntry e) async {
    final records =
        (ref.read(recordsProvider).valueOrNull ?? const <PieceRecord>[])
            .where((r) => r.photoName == e.name)
            .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.94,
          builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.primary.withAlpha(24),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      e.id,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e.label,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: '复制编号',
                    icon: const Icon(Icons.copy, size: 17),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: e.id));
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('已复制 ${e.id}')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: PhotoThumb(name: e.name, size: double.infinity),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '被 ${records.length} 条记录引用（同一张图只存一份，删记录不会删图）',
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              for (final r in records)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: PhotoThumb(name: r.photoName, size: 38, radius: 8),
                  title: Text(
                    '${r.styleModel.isEmpty ? '未填型号' : r.styleModel}'
                    '${r.color.isEmpty ? '' : ' · ${r.color}'}'
                    '${r.size.isEmpty ? '' : ' · ${r.size}'}',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  subtitle: Text(
                    '${Fmt.dateTime(r.createdAt)} · ${r.quantity}${r.unitOrBase}'
                    '${r.hasPrice ? ' · ${Money.yuan(r.subtotalMilli)}' : ' · 未计价'}',
                    style: const TextStyle(fontSize: 10.5),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => RecordEditPage(recordId: r.id),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
