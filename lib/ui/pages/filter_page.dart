import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/models/filter_preset.dart';
import '../../data/models/option_item.dart';
import '../../data/models/piece_record.dart';
import '../../data/models/record_filter.dart';
import '../../data/services/query_engine.dart';
import '../../providers/options_providers.dart';
import '../../providers/presets_providers.dart';
import '../../providers/records_providers.dart';
import '../widgets/multi_select_chips.dart';

/// 高级筛选页。改动先放在草稿里，点「应用筛选」才写回全局状态。
class FilterPage extends ConsumerStatefulWidget {
  const FilterPage({super.key});

  @override
  ConsumerState<FilterPage> createState() => _FilterPageState();
}

class _FilterPageState extends ConsumerState<FilterPage> {
  late RecordFilter _draft;
  final TextEditingController _minCtrl = TextEditingController();
  final TextEditingController _maxCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _draft = ref.read(filterProvider);
    _minCtrl.text = _draft.minQty?.toString() ?? '';
    _maxCtrl.text = _draft.maxQty?.toString() ?? '';
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final options = ref.watch(optionsProvider).valueOrNull ??
        <OptionKind, List<String>>{};
    final records =
        ref.watch(recordsProvider).valueOrNull ?? const <PieceRecord>[];
    final used = QueryEngine.distinctValues(records);

    final styleOptions = _merge(options[OptionKind.styleModel], used['styleModels']);
    final colorOptions = _merge(options[OptionKind.color], used['colors']);
    final sizeOptions = _merge(options[OptionKind.size], used['sizes']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('筛选'),
        actions: <Widget>[
          IconButton(
            tooltip: '加载预设',
            icon: const Icon(Icons.bookmark_border),
            onPressed: () => _showPresets(context),
          ),
          IconButton(
            tooltip: '保存为预设',
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: () => _savePreset(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: <Widget>[
          _Section(
            title: '时间范围',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: QuickRange.values.map((q) {
                    final on = _draft.quick == q;
                    return ChoiceChip(
                      label: Text(q.label, style: const TextStyle(fontSize: 12.5)),
                      selected: on,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: BorderSide(
                        color: on ? scheme.primary : scheme.outlineVariant,
                      ),
                      backgroundColor: Colors.transparent,
                      selectedColor: scheme.primary.withAlpha(28),
                      labelStyle: TextStyle(
                        color: on ? scheme.primary : scheme.onSurface,
                        fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                      ),
                      onSelected: (_) {
                        if (q == QuickRange.custom) {
                          _pickRange();
                        } else {
                          setState(() => _draft = _draft.copyWith(quick: q));
                        }
                      },
                    );
                  }).toList(),
                ),
                if (_draft.quick == QuickRange.custom) ...<Widget>[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _pickRange,
                    icon: const Icon(Icons.date_range, size: 17),
                    label: Text(
                      _draft.customStart == null || _draft.customEnd == null
                          ? '选择起止日期'
                          : '${Fmt.date(_draft.customStart!)} → ${Fmt.date(_draft.customEnd!)}',
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            title: '型号',
            child: MultiSelectChips(
              title: '款式型号（可多选）',
              options: styleOptions,
              selected: _draft.styleModels,
              onToggle: (v) => setState(
                () => _draft = _draft.copyWith(
                  styleModels: _toggle(_draft.styleModels, v),
                ),
              ),
              onClear: () =>
                  setState(() => _draft = _draft.copyWith(styleModels: <String>{})),
              emptyHint: '还没有型号。录入记录后会自动出现在这里。',
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            title: '颜色',
            child: MultiSelectChips(
              title: '颜色（可多选）',
              options: colorOptions,
              selected: _draft.colors,
              onToggle: (v) => setState(
                () => _draft = _draft.copyWith(colors: _toggle(_draft.colors, v)),
              ),
              onClear: () =>
                  setState(() => _draft = _draft.copyWith(colors: <String>{})),
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            title: '码数',
            child: MultiSelectChips(
              title: '码数（可多选）',
              options: sizeOptions,
              selected: _draft.sizes,
              onToggle: (v) => setState(
                () => _draft = _draft.copyWith(sizes: _toggle(_draft.sizes, v)),
              ),
              onClear: () =>
                  setState(() => _draft = _draft.copyWith(sizes: <String>{})),
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            title: '数量区间',
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _minCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '最少件数',
                      hintText: '不限',
                    ),
                    onChanged: (v) {
                      final n = int.tryParse(v.trim());
                      setState(() => _draft = _draft.copyWith(
                            minQty: n,
                            clearMinQty: n == null,
                          ));
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('—'),
                ),
                Expanded(
                  child: TextField(
                    controller: _maxCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '最多件数',
                      hintText: '不限',
                    ),
                    onChanged: (v) {
                      final n = int.tryParse(v.trim());
                      setState(() => _draft = _draft.copyWith(
                            maxQty: n,
                            clearMaxQty: n == null,
                          ));
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            title: '上报状态',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '默认只看未上报的 —— 已经上报给公司的不会再冒出来。',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  children: StatusFilter.values.map((s) {
                    final on = _draft.statusFilter == s;
                    return ChoiceChip(
                      label: Text(s.label,
                          style: const TextStyle(fontSize: 12.5)),
                      selected: on,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: BorderSide(
                        color: on ? scheme.primary : scheme.outlineVariant,
                      ),
                      backgroundColor: Colors.transparent,
                      selectedColor: scheme.primary.withAlpha(28),
                      labelStyle: TextStyle(
                        color: on ? scheme.primary : scheme.onSurface,
                        fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                      ),
                      onSelected: (_) => setState(
                        () => _draft = _draft.copyWith(statusFilter: s),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            title: '照片',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '忘记拍照也能保存记录。这里可以单独把缺照片的捞出来补拍。',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  children: PhotoFilter.values.map((p) {
                    final on = _draft.photoFilter == p;
                    return ChoiceChip(
                      label: Text(p.label, style: const TextStyle(fontSize: 12.5)),
                      selected: on,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: BorderSide(
                        color: on ? scheme.primary : scheme.outlineVariant,
                      ),
                      backgroundColor: Colors.transparent,
                      selectedColor: scheme.primary.withAlpha(28),
                      labelStyle: TextStyle(
                        color: on ? scheme.primary : scheme.onSurface,
                        fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                      ),
                      onSelected: (_) =>
                          setState(() => _draft = _draft.copyWith(photoFilter: p)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            title: '缺信息',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '只记了件数也没关系：型号 / 颜色 / 码数 / 单价可以留空，'
                  '这里能把缺这些字段的记录一键捞出来补录。',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  children: MissingField.values.map((m) {
                    final on = _draft.missing.contains(m);
                    return FilterChip(
                      label: Text(m.label,
                          style: const TextStyle(fontSize: 12.5)),
                      selected: on,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: BorderSide(
                        color: on ? scheme.primary : scheme.outlineVariant,
                      ),
                      backgroundColor: Colors.transparent,
                      selectedColor: scheme.primary.withAlpha(28),
                      labelStyle: TextStyle(
                        color: on ? scheme.primary : scheme.onSurface,
                        fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                      ),
                      onSelected: (v) {
                        final next = <MissingField>{..._draft.missing};
                        if (v) {
                          next.add(m);
                        } else {
                          next.remove(m);
                        }
                        setState(
                          () => _draft = _draft.copyWith(missing: next),
                        );
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            title: '排序',
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Wrap(
                    spacing: 7,
                    children: SortField.values.map((f) {
                      final on = _draft.sortField == f;
                      return ChoiceChip(
                        label: Text('按${f.label}',
                            style: const TextStyle(fontSize: 12.5)),
                        selected: on,
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(
                          color: on ? scheme.primary : scheme.outlineVariant,
                        ),
                        backgroundColor: Colors.transparent,
                        selectedColor: scheme.primary.withAlpha(28),
                        onSelected: (_) =>
                            setState(() => _draft = _draft.copyWith(sortField: f)),
                      );
                    }).toList(),
                  ),
                ),
                IconButton(
                  tooltip: _draft.ascending ? '升序' : '降序',
                  icon: Icon(
                    _draft.ascending ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 20,
                  ),
                  onPressed: () => setState(
                    () => _draft = _draft.copyWith(ascending: !_draft.ascending),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _draft = RecordFilter.empty;
                      _minCtrl.clear();
                      _maxCtrl.clear();
                    });
                  },
                  child: const Text('重置'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () {
                    ref.read(filterProvider.notifier).apply(_draft);
                    Navigator.of(context).pop();
                  },
                  child: const Text('应用筛选'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── 交互 ─────────────────────────

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange:
          (_draft.customStart != null && _draft.customEnd != null)
              ? DateTimeRange(
                  start: _draft.customStart!,
                  end: _draft.customEnd!,
                )
              : null,
      helpText: '选择起止日期',
      saveText: '确定',
    );
    if (picked == null) return;
    setState(() {
      _draft = _draft.copyWith(
        quick: QuickRange.custom,
        customStart: picked.start,
        customEnd: picked.end,
      );
    });
  }

  Future<void> _savePreset(BuildContext context) async {
    final ctrl = TextEditingController(
      text: _draft.isActive ? _draft.summary : '',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('保存为筛选预设'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '预设名称',
            hintText: '例如：本周黑色 M 码',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty) return;

    await ref.read(presetsProvider.notifier).save(name, _draft);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已保存预设「$name」')),
    );
  }

  void _showPresets(BuildContext context) {
    final presets = ref.read(presetsProvider).valueOrNull ?? <FilterPreset>[];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: presets.isEmpty
            ? const Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: Text('还没有保存过预设。设好条件后点右上角书签图标保存。'),
              )
            : ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: presets.length,
                  itemBuilder: (_, i) {
                    final p = presets[i];
                    final f = PresetsNotifier.decode(p);
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.bookmark_outline, size: 20),
                      title: Text(p.name),
                      subtitle: Text(
                        f?.summary ?? '（预设已损坏）',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 19),
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await ref.read(presetsProvider.notifier).remove(p.id);
                        },
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        if (f == null) return;
                        setState(() {
                          _draft = f;
                          _minCtrl.text = f.minQty?.toString() ?? '';
                          _maxCtrl.text = f.maxQty?.toString() ?? '';
                        });
                      },
                    );
                  },
                ),
              ),
      ),
    );
  }

  // ───────────────────────── 工具 ─────────────────────────

  static Set<String> _toggle(Set<String> src, String v) {
    final next = Set<String>.from(src);
    if (!next.remove(v)) next.add(v);
    return next;
  }

  static List<String> _merge(List<String>? a, List<String>? b) {
    final set = <String>{...?a, ...?b};
    final list = set.toList()..sort();
    return list;
  }
}

/// 分组卡片
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1B1E24)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withAlpha(140)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
