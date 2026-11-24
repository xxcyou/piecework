import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/format.dart';
import '../../data/models/app_setting.dart';
import '../../data/models/piece_record.dart';
import '../../data/models/record_filter.dart';
import '../../data/services/csv_service.dart';
import '../../data/services/report_service.dart';
import '../../providers/profile_providers.dart';
import '../../providers/records_providers.dart';
import '../../providers/settings_providers.dart';
import '../widgets/empty_state.dart';
import '../widgets/profile_switcher.dart';
import '../widgets/report_document.dart';
import '../../providers/work_mode_provider.dart';

/// 报表预览 / 导出页。
///
/// 预览用的就是最终导出的那张画布（RepaintBoundary），
/// 所以「所见即所得」：预览里字号多大、缩略图有没有，导出的 PNG 就什么样。
class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key});

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  final GlobalKey _boundaryKey = GlobalKey();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _subtitleCtrl = TextEditingController();

  bool _inited = false;
  bool _exporting = false;
  double _fontScale = 1.0;
  int _template = 0;
  bool _showPhoto = true;
  int _groupBy = 0; // 0=按日期 1=按型号 2=不分组

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(settingsProvider).valueOrNull;
      if (s != null) _apply(s);
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    super.dispose();
  }

  void _apply(AppSetting s) {
    if (!mounted || _inited) return;
    _titleCtrl.text = s.reportTitle;
    _subtitleCtrl.text = s.reportSubtitle;
    setState(() {
      _fontScale = s.reportFontScale.clamp(0.7, 1.8);
      _template = s.reportTemplate;
      _showPhoto = s.reportShowPhoto;
      _groupBy = s.reportGroupBy.clamp(0, 2);
      _inited = true;
    });
  }

  void _persist() {
    ref.read(settingsProvider.notifier).mutate((s) {
      s.reportTitle = _titleCtrl.text.trim();
      s.reportSubtitle = _subtitleCtrl.text.trim();
      s.reportFontScale = _fontScale;
      s.reportTemplate = _template;
      s.reportShowPhoto = _showPhoto;
      s.reportGroupBy = _groupBy;
    });
  }

  // ───────────────────────── 导出 ─────────────────────────

  Future<void> _exportPng(List<PieceRecord> records) async {
    if (records.isEmpty) {
      _toast('当前没有可导出的记录');
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
        name: '计件报表_${Fmt.stamp(DateTime.now())}',
      );
      if (!mounted) return;
      _toast(err ?? '已保存到系统相册「计件报表」');
    } catch (e) {
      if (mounted) _toast('导出失败：$e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportCsv(List<PieceRecord> records) async {
    if (records.isEmpty) {
      _toast('当前没有可导出的记录');
      return;
    }
    try {
      final bytes = CsvService.buildBytes(records);
      final name = CsvService.defaultFileName();

      String? saved;
      try {
        saved = await FilePicker.saveFile(
          dialogTitle: '保存 CSV',
          fileName: name,
          type: FileType.custom,
          allowedExtensions: const <String>['csv'],
          bytes: bytes,
        );
      } catch (_) {
        saved = null;
      }

      if (saved == null) {
        // 某些机型 SAF 不可用：退回到应用文档目录
        final dir = await getApplicationDocumentsDirectory();
        final f = File('${dir.path}/$name');
        await f.writeAsBytes(bytes, flush: true);
        saved = f.path;
      }

      if (!mounted) return;
      _toast('CSV 已保存：$saved');
    } catch (e) {
      if (mounted) _toast('导出 CSV 失败：$e');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.valueOrNull;
    if (settings != null && !_inited) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _apply(settings));
    }

    final result = ref.watch(filteredResultProvider);
    final filter = ref.watch(filterProvider);
    final scheme = Theme.of(context).colorScheme;

    final rangeText = _rangeText(filter);
    final compact = _template == 1;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('报表'),
            SizedBox(width: 8),
            ProfileChip(),
          ],
        ),
        actions: <Widget>[
          PopupMenuButton<String>(
            icon: const Icon(Icons.ios_share_outlined),
            tooltip: '导出',
            onSelected: (v) {
              if (v == 'png') {
                _exportPng(result.records);
              } else if (v == 'csv') {
                _exportCsv(result.records);
              } else if (v == 'reset') {
                setState(() {
                  _titleCtrl.text = '计件明细报表';
                  _subtitleCtrl.text = '';
                  _fontScale = 1.0;
                });
                _persist();
              }
            },
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'png',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.image_outlined, size: 19),
                  title: Text('导出高清 PNG 到相册'),
                ),
              ),
              PopupMenuItem<String>(
                value: 'csv',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.table_chart_outlined, size: 19),
                  title: Text('导出 CSV 表格'),
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'reset',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.restart_alt, size: 19),
                  title: Text('重置标题与字号'),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: <Widget>[
          _buildConfigBar(scheme, compact),
          Divider(height: 1, color: scheme.outlineVariant.withAlpha(120)),
          Expanded(
            child: result.records.isEmpty
                ? const EmptyState(
                    icon: Icons.insert_chart_outlined,
                    title: '没有可生成的报表',
                    subtitle: '先在记录页筛选出要导出的数据，或直接录入新记录。',
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withAlpha(18),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: RepaintBoundary(
                        key: _boundaryKey,
                        child: ReportDocument(
                          title: _titleCtrl.text,
                          subtitle: _subtitleCtrl.text,
                          records: result.records,
                          fontScale: _fontScale,
                          compact: compact,
                          showPhoto: _showPhoto,
                          generatedAt: DateTime.now(),
                          rangeText: rangeText,
                          groupBy: _groupField,
                          profileName:
                              ref.watch(activeProfileProvider)?.name ?? '',
                          salaryMode: ref.watch(salaryModeProvider),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exporting ? null : () => _exportCsv(result.records),
                  icon: const Icon(Icons.table_chart_outlined, size: 18),
                  label: const Text('导出 CSV'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed:
                      _exporting ? null : () => _exportPng(result.records),
                  icon: _exporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_rounded, size: 19),
                  label: Text(_exporting ? '导出中…' : '导出高清 PNG'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfigBar(ColorScheme scheme, bool compact) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              SegmentedButton<int>(
                segments: const <ButtonSegment<int>>[
                  ButtonSegment<int>(
                    value: 0,
                    label: Text('对外版', style: TextStyle(fontSize: 11.5)),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text('紧凑版', style: TextStyle(fontSize: 11.5)),
                  ),
                ],
                selected: <int>{_template},
                onSelectionChanged: (s) {
                  setState(() => _template = s.first);
                  _persist();
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                showSelectedIcon: false,
              ),
              const Spacer(),
              // 字号
              InkResponse(
                onTap: () {
                  setState(() => _fontScale =
                      (_fontScale - 0.1).clamp(0.7, 1.8));
                  _persist();
                },
                radius: 20,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.text_decrease,
                      size: 19, color: scheme.onSurfaceVariant),
                ),
              ),
              SizedBox(
                width: 42,
                child: Text(
                  '${(_fontScale * 100).round()}%',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              InkResponse(
                onTap: () {
                  setState(() => _fontScale =
                      (_fontScale + 0.1).clamp(0.7, 1.8));
                  _persist();
                },
                radius: 20,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.text_increase,
                      size: 19, color: scheme.onSurfaceVariant),
                ),
              ),
              // 分组方式：按日期 / 按型号 / 不分组
              PopupMenuButton<int>(
                tooltip: '分组方式',
                initialValue: _groupBy,
                onSelected: (v) {
                  setState(() => _groupBy = v);
                  _persist();
                },
                itemBuilder: (_) => const <PopupMenuEntry<int>>[
                  PopupMenuItem<int>(value: 0, child: Text('按日期分组')),
                  PopupMenuItem<int>(value: 1, child: Text('按型号分组')),
                  PopupMenuItem<int>(value: 2, child: Text('不分组')),
                ],
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.segment,
                          size: 14, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text(
                        switch (_groupBy) {
                          1 => '按型号',
                          2 => '不分组',
                          _ => '按日期',
                        },
                        style: TextStyle(
                          fontSize: 10.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!compact)
                IconButton(
                  tooltip: _showPhoto ? '隐藏缩略图' : '显示缩略图',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    _showPhoto
                        ? Icons.image_rounded
                        : Icons.hide_image_outlined,
                    size: 19,
                    color: _showPhoto ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    setState(() => _showPhoto = !_showPhoto);
                    _persist();
                  },
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _titleCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: '报表标题',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (_) => setState(() {}),
                  onEditingComplete: _persist,
                  onTapOutside: (_) {
                    FocusScope.of(context).unfocus();
                    _persist();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _subtitleCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: '副标题（选填）',
                    hintText: '如：XX 厂 11 月',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (_) => setState(() {}),
                  onEditingComplete: _persist,
                  onTapOutside: (_) {
                    FocusScope.of(context).unfocus();
                    _persist();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  GroupField get _groupField => switch (_groupBy) {
        1 => GroupField.styleModel,
        2 => GroupField.none,
        _ => GroupField.day,
      };

  static String _rangeText(RecordFilter filter) {
    final range = filter.resolveRange();
    if (range == null) return '全部时间';
    return '${Fmt.date(range.start)} ~ ${Fmt.date(range.end)}';
  }
}
