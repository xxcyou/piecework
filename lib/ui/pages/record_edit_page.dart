import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/money.dart';
import '../../data/models/operation_log.dart';
import '../../data/models/option_item.dart';
import '../../data/models/piece_record.dart';
import '../../data/services/photo_service.dart';
import '../../data/services/record_codec.dart';
import '../../providers/db_providers.dart';
import '../../providers/options_providers.dart';
import '../../providers/photo_library_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/units_providers.dart';
import '../tour_keys.dart';
import '../widgets/suggest_field.dart';
import 'camera_capture_page.dart';

/// 录入 / 编辑记录页。
///
/// 新增与编辑共用一套表单：
/// * 传 [recordId] 为编辑，否则为新增；
/// * 新增时会用设置里的「默认单价」预填。
class RecordEditPage extends ConsumerStatefulWidget {
  const RecordEditPage({super.key, this.recordId, this.seed});

  final int? recordId;

  /// 复制模式：用这条记录的值预填，但**保存成一条新记录**
  /// （同款懒得重新填：复制 → 改数量/日期 → 保存）
  final PieceRecord? seed;

  @override
  ConsumerState<RecordEditPage> createState() => _RecordEditPageState();
}

class _RecordEditPageState extends ConsumerState<RecordEditPage> {
  final TextEditingController _styleCtrl = TextEditingController();
  final TextEditingController _colorCtrl = TextEditingController();
  final TextEditingController _sizeCtrl = TextEditingController();
  final TextEditingController _qtyCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  PieceRecord? _existing;
  String _unit = '件';
  String _photoName = '';
  Uint8List? _pendingBytes;
  bool _loading = true;
  bool _saving = false;

  /// 用户手动改过的记录时间（null = 用原来的/当前时间）
  DateTime? _atOverride;

  /// 实际会写入的记录时间
  DateTime get _at =>
      _atOverride ?? _existing?.createdAt ?? DateTime.now();

  /// 这张图被多少条记录共用（>1 说明删记录不会删图）
  int _sharedCount = 0;

  bool get _isEdit => widget.recordId != null;
  bool get _isCopy => !_isEdit && widget.seed != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loadExisting();
    } else if (widget.seed != null) {
      _initCopy(widget.seed!);
    } else {
      _initNew();
    }
  }

  @override
  void dispose() {
    _styleCtrl.dispose();
    _colorCtrl.dispose();
    _sizeCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _initNew() async {
    final settings = await ref.read(settingsProvider.future);
    if (!mounted) return;
    setState(() {
      if (settings.defaultUnitPrice > 0) {
        _priceCtrl.text =
            Money.plain(Money.toMilli(settings.defaultUnitPrice));
      }
      _qtyCtrl.text = '1';
      _loading = false;
    });
  }

  /// 复制模式：把原记录的字段搬过来（时间用现在，可在页面上改）
  Future<void> _initCopy(PieceRecord src) async {
    var shared = 0;
    if (src.photoName.isNotEmpty) {
      shared = await ref.read(photoGcProvider).refCount(src.photoName);
    }
    if (!mounted) return;
    setState(() {
      _styleCtrl.text = src.styleModel;
      _colorCtrl.text = src.color;
      _sizeCtrl.text = src.size;
      _qtyCtrl.text = src.quantity.toString();
      _priceCtrl.text = src.unitPrice == 0
          ? ''
          : Money.plain(Money.toMilli(src.unitPrice));
      _noteCtrl.text = src.note;
      _unit = src.unitOrBase;
      // 图片直接引用同一份文件（内容寻址，不重复占空间）
      _photoName = src.photoName;
      _sharedCount = shared;
      _atOverride = DateTime.now();
      _loading = false;
    });
  }

  Future<void> _loadExisting() async {
    final record = await ref.read(recordRepoProvider).byId(widget.recordId!);
    if (!mounted) return;
    if (record == null) {
      Navigator.of(context).pop();
      return;
    }
    // 先查共用张数（异步），再一次性 setState
    var shared = 0;
    if (record.photoName.isNotEmpty) {
      shared = await ref.read(photoGcProvider).refCount(record.photoName);
    }
    if (!mounted) return;
    setState(() {
      _existing = record;
      _styleCtrl.text = record.styleModel;
      _colorCtrl.text = record.color;
      _sizeCtrl.text = record.size;
      _qtyCtrl.text = record.quantity.toString();
      // 单价可能精确到 0.001，用 Money.plain 保留厘位（0.001 不能被显示成 0.00）
      _priceCtrl.text = record.unitPrice == 0
          ? ''
          : Money.plain(Money.toMilli(record.unitPrice));
      _noteCtrl.text = record.note;
      _unit = record.unitOrBase;
      _photoName = record.photoName;
      _sharedCount = shared;
      _loading = false;
    });
  }

  int get _qty => int.tryParse(_qtyCtrl.text.trim()) ?? 0;

  /// 单价留空 = 还不知道多少钱（不是 0 元）
  bool get _priceFilled => _priceCtrl.text.trim().isNotEmpty;
  double get _price => double.tryParse(_priceCtrl.text.trim()) ?? 0;
  int get _subtotalMilli => Money.multiply(_qty, _price);

  // ───────────────────────── 拍照 ─────────────────────────

  Future<void> _takePhoto() async {
    final bytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute<Uint8List>(builder: (_) => const CameraCapturePage()),
    );
    if (bytes == null || !mounted) return;
    setState(() => _pendingBytes = bytes);
  }

  /// 选一张本机已有的图（同型号的排在前面）
  Future<void> _pickExisting() async {
    final picked = await pickExistingPhoto(
      context,
      ref,
      preferStyleModel: _styleCtrl.text.trim(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _pendingBytes = null;
      _photoName = picked;
      _sharedCount = 0;
    });
    // 引用数异步补上（卡片上会显示「和另外 N 条共用」）
    final n = await ref.read(photoGcProvider).refCount(picked);
    if (!mounted) return;
    setState(() => _sharedCount = n);
  }

  void _removePhoto() {
    setState(() {
      _pendingBytes = null;
      _photoName = '';
    });
  }

  // ───────────────────────── 保存 ─────────────────────────

  Future<void> _save() async {
    if (_saving) return;

    final style = _styleCtrl.text.trim();
    final color = _colorCtrl.text.trim();
    final size = _sizeCtrl.text.trim();
    final note = _noteCtrl.text.trim();

    // 只要求数量：很多师傅只知道做了多少件，型号/颜色/码数/单价都可能不知道，
    // 这些一律允许留空，以后能补就补（列表里能看到「缺信息」并筛选出来）。
    if (_qty <= 0) {
      _toast('数量要大于 0');
      return;
    }
    if (_price < 0) {
      _toast('单价不能是负数');
      return;
    }
    // 最多三位小数：多了就是录错了，明确报错，别悄悄抹掉
    if (_priceFilled && Money.parsePrice(_priceCtrl.text.trim()) == null) {
      _toast('单价最多三位小数，例如 0.125');
      return;
    }

    setState(() => _saving = true);

    try {
      // 处理照片文件（内容寻址：同一张图只存一份）
      var finalName = _photoName;
      if (_pendingBytes != null) {
        finalName = await PhotoService.instance.saveBytes(_pendingBytes!);
      }
      // 原来那条记录引用的图：不管是「重拍」「改选已有图」还是「移除」，
      // 只要最终指向变了，就试着回收（没人引用才会真删）
      final oldPhoto = _existing?.photoName ?? '';

      // 改之前先留快照（编辑要能撤回旧值）
      final beforeSnapshot = _existing == null
          ? null
          : RecordCodec.fromJson(RecordCodec.toJson(_existing!));

      final record = _existing ?? PieceRecord();
      record.styleModel = style;
      record.color = color;
      record.size = size;
      record.quantity = _qty;
      record.unitPrice = _price;
      record.note = note;
      record.unit = _unit;
      record.photoName = finalName;
      // 录入时间可以改：用户没改就沿用原值（新建则用当前时间）
      record.createdAt = _at;
      if (_existing != null) record.updatedAt = DateTime.now();

      await ref.read(recordRepoProvider).save(record);

      // 记录已经不再指向旧图了，这时才轮到判断旧图还有没有人用
      if (oldPhoto.isNotEmpty && oldPhoto != finalName) {
        await ref.read(photoGcProvider).deleteIfUnreferenced(oldPhoto);
      }

      // 每次写操作都入日志：手动新增/编辑也能在「操作历史」里撤回
      await ref.read(opLogRepoProvider).record(
            kind: beforeSnapshot == null ? OpKind.create : OpKind.update,
            source: 'manual',
            summary: beforeSnapshot == null
                ? '新建记录：$style'
                : '修改记录：$style',
            before: beforeSnapshot == null
                ? const <PieceRecord>[]
                : <PieceRecord>[beforeSnapshot],
            after: beforeSnapshot == null ? <PieceRecord>[record] : const [],
          );

      // 顺手把新值补进选项库，下次输入就有联想
      final options = ref.read(optionsProvider.notifier);
      if (color.isNotEmpty) {
        await options.ensureValue(OptionKind.color, color);
      }
      if (size.isNotEmpty) {
        await options.ensureValue(OptionKind.size, size);
      }
      await options.ensureValue(OptionKind.styleModel, style);

      if (!mounted) return;
      // 先拿到 messenger 再 pop，否则 pop 之后 context 已失效
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text(_isEdit ? '已更新记录' : '已保存 1 条记录')),
      );
    } catch (e) {
      _toast('保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final styleOptions = ref.watch(optionsForProvider(OptionKind.styleModel));
    final colorOptions = ref.watch(optionsForProvider(OptionKind.color));
    final sizeOptions = ref.watch(optionsForProvider(OptionKind.size));

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '编辑记录' : (_isCopy ? '复制记录' : '录入记录')),
        actions: <Widget>[
          if (_isEdit)
            IconButton(
              tooltip: '复制这条（做同款）',
              icon: const Icon(Icons.copy_all_outlined, size: 20),
              onPressed: _saving
                  ? null
                  : () {
                      final src = _existing;
                      if (src == null) return;
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => RecordEditPage(seed: src),
                        ),
                      );
                    },
            ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中…' : '保存'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: <Widget>[
                KeyedSubtree(
                  key: TourKeys.recordPhoto,
                  child: _buildPhotoCard(scheme),
                ),
                if (_sharedCount > 1) ...<Widget>[
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      Icon(Icons.link, size: 13, color: scheme.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '这张图和另外 ${_sharedCount - 1} 条记录共用同一份文件；'
                          '删掉本条的关联不会把图删掉',
                          style: TextStyle(
                            fontSize: 10.5,
                            height: 1.4,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                _buildTimeRow(scheme),
                const SizedBox(height: 12),
                _buildFormCard(scheme, styleOptions, colorOptions, sizeOptions),
                const SizedBox(height: 12),
              ],
            ),
      // 小计固定在底部：边输边看金额，键盘弹出也不会被挤走
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF15181E)
                : Colors.white,
            border: Border(
              top: BorderSide(color: scheme.outlineVariant.withAlpha(120)),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _buildSummaryCard(scheme),
              const SizedBox(height: 10),
              FilledButton.icon(
                key: TourKeys.recordSave,
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check, size: 19),
                label: Text(_isEdit ? '保存修改' : '保存记录'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 记录时间：点一下改日期和时刻（补录、改错都靠它）
  Widget _buildTimeRow(ColorScheme scheme) {
    final at = _at;
    final changed = _atOverride != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _pickDateTime,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withAlpha(50),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: changed
                  ? scheme.primary.withAlpha(120)
                  : scheme.outlineVariant.withAlpha(110),
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.schedule,
                  size: 16,
                  color: changed ? scheme.primary : scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                '记录时间',
                style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '${Fmt.date(at)} ${Fmt.time(at)}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: changed ? scheme.primary : scheme.onSurface,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.edit_calendar_outlined,
                  size: 15, color: scheme.onSurfaceVariant.withAlpha(160)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final base = _at;
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: '选择记录日期',
      cancelText: '取消',
      confirmText: '下一步',
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
      helpText: '选择记录时刻',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (!mounted) return;

    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? base.hour,
      time?.minute ?? base.minute,
    );
    setState(() => _atOverride = picked);
  }

  Widget _buildPhotoCard(ColorScheme scheme) {
    final hasPhoto = _pendingBytes != null || _photoName.isNotEmpty;

    Widget image() {
      if (_pendingBytes != null) {
        return Image.memory(
          _pendingBytes!,
          fit: BoxFit.cover,
          width: double.infinity,
        );
      }
      final file = PhotoService.instance.syncFile(_photoName);
      if (file != null) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, __, ___) => _photoPlaceholder(scheme),
        );
      }
      return _photoPlaceholder(scheme);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 210,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1B1E24)
              : Colors.white,
          border: Border.all(color: scheme.outlineVariant.withAlpha(140)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: hasPhoto
            ? Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  image(),
                  // 顶部渐变，保证按钮看得清
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 60,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Colors.black.withAlpha(110),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Row(
                      children: <Widget>[
                        _photoAction(
                          icon: Icons.photo_library_outlined,
                          tooltip: '用已有的图',
                          onTap: _pickExisting,
                        ),
                        const SizedBox(width: 6),
                        _photoAction(
                          icon: Icons.photo_camera_outlined,
                          tooltip: '重拍',
                          onTap: _takePhoto,
                        ),
                        const SizedBox(width: 6),
                        _photoAction(
                          icon: Icons.delete_outline,
                          tooltip: '移除照片',
                          onTap: _removePhoto,
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : InkWell(
                onTap: _takePhoto,
                child: _photoPlaceholder(scheme),
              ),
      ),
    );
  }

  Widget _photoPlaceholder(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: scheme.primary.withAlpha(18),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.photo_camera_outlined,
                size: 26, color: scheme.primary),
          ),
          const SizedBox(height: 10),
          Text(
            '拍下货物实拍（可跳过）',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '忘了拍也能直接保存；之后用筛选里的「缺照片」补拍',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickExisting,
            icon: const Icon(Icons.photo_library_outlined, size: 15),
            label: const Text('用已有的图', style: TextStyle(fontSize: 11.5)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(120),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildFormCard(
    ColorScheme scheme,
    List<String> styleOptions,
    List<String> colorOptions,
    List<String> sizeOptions,
  ) {
    // 单位相关状态在方法内取，避免 build 与 helper 的作用域割裂
    final unitNames = ref.watch(unitNamesProvider);
    final baseUnit = ref.watch(baseUnitProvider);
    final converter = ref.watch(unitConverterProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1B1E24)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withAlpha(140)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 只记数量的用户很多：明确告诉他「只有数量必填」
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: scheme.primary.withAlpha(12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.info_outline, size: 14, color: scheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '只有「数量」必填。型号 / 颜色 / 码数 / 单价不知道就留空，'
                    '以后能补就补；缺的字段会标在列表里，也能一键筛出来补。',
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.45,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SuggestField(
            controller: _styleCtrl,
            label: '款式型号（选填）',
            hint: '不知道就留空，例如 A1023',
            options: styleOptions,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: SuggestField(
                  controller: _colorCtrl,
                  label: '颜色（选填）',
                  hint: '不知道可留空',
                  options: colorOptions,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SuggestField(
                  controller: _sizeCtrl,
                  label: '码数（选填）',
                  hint: '不知道可留空',
                  options: sizeOptions,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 计量单位：件 / 片 / 打 …（设置页可增删）
          Row(
            children: <Widget>[
              Text(
                '计量单位',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: unitNames.map((u) {
                    final on = _unit == u;
                    return ChoiceChip(
                      label: Text(u, style: const TextStyle(fontSize: 12)),
                      selected: on,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      side: BorderSide(
                        color: on ? scheme.primary : scheme.outlineVariant,
                      ),
                      backgroundColor: Colors.transparent,
                      selectedColor: scheme.primary.withAlpha(28),
                      labelStyle: TextStyle(
                        color: on ? scheme.primary : scheme.onSurface,
                        fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                      ),
                      onSelected: (_) => setState(() => _unit = u),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          if (_unit != baseUnit) ...<Widget>[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                converter.describe(_unit, styleModel: _styleCtrl.text.trim()),
                style: TextStyle(
                  fontSize: 10.5,
                  color: converter.hasRule(_unit,
                          styleModel: _styleCtrl.text.trim())
                      ? scheme.onSurfaceVariant
                      : scheme.error,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: TourKeys.recordQty,
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    labelText: '数量 *',
                    hintText: _unit,
                    suffixText: _unit,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: '每$_unit单价（选填）',
                    hintText: '不知道可留空',
                    prefixText: '¥ ',
                    helperText: '可精确到 0.001 元（厘）',
                    helperMaxLines: 1,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            minLines: 1,
            decoration: const InputDecoration(
              labelText: '备注',
              hintText: '选填，例如「返工」「急件」',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: scheme.primary.withAlpha(14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.primary.withAlpha(40)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.calculate_outlined, size: 17, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _priceFilled
                  ? '$_qty $_unit × ¥${Money.plain(Money.toMilli(_price))}'
                  : '$_qty $_unit · 未填单价',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _priceFilled ? Money.yuan(_subtotalMilli) : '待结算',
            style: TextStyle(
              fontSize: _priceFilled ? 20 : 14,
              fontWeight: FontWeight.w800,
              color: _priceFilled ? scheme.primary : scheme.onSurfaceVariant,
              fontFeatures: tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}
