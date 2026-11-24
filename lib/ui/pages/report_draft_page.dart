import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/models/piece_record.dart';
import '../../data/models/record_filter.dart';
import '../../data/services/report_service.dart';
import '../../providers/units_providers.dart';
import '../widgets/report_document.dart';

/// AI 报表草稿：用聊天里那张草稿的数据渲染成正式报表，可导出图片。
///
/// **不读数据库、不写数据库** —— 数据全部来自草稿本身。
class ReportDraftPage extends ConsumerStatefulWidget {
  const ReportDraftPage({super.key, required this.draft});

  final Map<String, dynamic> draft;

  @override
  ConsumerState<ReportDraftPage> createState() => _ReportDraftPageState();
}

class _ReportDraftPageState extends ConsumerState<ReportDraftPage> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _exporting = false;

  List<PieceRecord> get _records {
    final rows = widget.draft['rows'];
    if (rows is! List) return const <PieceRecord>[];
    final out = <PieceRecord>[];
    for (final raw in rows) {
      if (raw is! Map) continue;
      final m = raw.map((k, v) => MapEntry('$k', v));
      final r = PieceRecord()
        ..styleModel = (m['styleModel'] as String?) ?? ''
        ..color = (m['color'] as String?) ?? ''
        ..size = (m['size'] as String?) ?? ''
        ..unit = (m['unit'] as String?) ?? '件'
        ..quantity = (m['quantity'] as num?)?.toInt() ?? 0
        ..unitPrice = (m['unitPrice'] as num?)?.toDouble() ?? 0
        ..note = ''
        ..photoName = ''
        ..createdAt = DateTime.now();
      out.add(r);
    }
    return out;
  }

  Future<void> _exportPng() async {
    if (_records.isEmpty) {
      _toast('草稿里没有数据');
      return;
    }
    setState(() => _exporting = true);
    try {
      final png = await ReportService.capturePng(
        _boundaryKey,
        targetWidthPx: 2400,
      );
      final err = await ReportService.saveToGallery(
        png,
        name: '报表草稿_${Fmt.stamp(DateTime.now())}',
      );
      if (!mounted) return;
      _toast(err ?? '已保存到相册');
    } catch (e) {
      if (mounted) _toast('导出失败：$e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = (widget.draft['title'] as String?)?.trim() ?? '报表草稿';
    final subtitle = (widget.draft['subtitle'] as String?)?.trim() ?? '';
    final profile = (widget.draft['profile'] as String?)?.trim() ?? '';
    final mode = (widget.draft['mode'] as String?) ?? 'financial';
    final converter = ref.watch(unitConverterProvider);
    final records = _records;

    return Scaffold(
      appBar: AppBar(
        title: const Text('报表草稿'),
        actions: <Widget>[
          IconButton(
            tooltip: '导出图片',
            onPressed: _exporting ? null : _exportPng,
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.image_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
            decoration: BoxDecoration(
              color: scheme.primary.withAlpha(14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.info_outline, size: 14, color: scheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '草稿不会写入计件记录，本机数据不变',
                    style: TextStyle(fontSize: 10.5, color: scheme.primary),
                  ),
                ),
                Text(
                  '${records.length} 行 · ${converter.baseUnit}',
                  style: TextStyle(
                      fontSize: 10.5, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          RepaintBoundary(
            key: _boundaryKey,
            child: Material(
              color: Colors.white,
              child: ReportDocument(
                title: title,
                subtitle: subtitle,
                records: records,
                fontScale: 1,
                compact: mode != 'financial',
                showPhoto: false,
                generatedAt: DateTime.now(),
                rangeText: '',
                groupBy: mode == 'financial' ? GroupField.styleModel : GroupField.none,
                profileName: profile,
                salaryMode: mode == 'financial',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
