import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/money.dart';
import '../../data/models/piece_record.dart';
import '../../data/models/record_filter.dart';
import '../../data/services/photo_service.dart';
import '../../data/services/unit_converter.dart';
import '../../data/services/salary_summary.dart';
import '../../providers/units_providers.dart';

/// 报表画布 —— 按「给别人看、能对账」的标准做。
///
/// 三条硬规则：
/// 1. **金额一律整数分计算**，累加不漂；显示统一千分位 + 两位小数 + 等宽数字；
/// 2. **分组带小计**：按日期（默认）或型号分组，每组末尾给 `条数 · 件数 · 金额`，
///    最后再给总计 —— 对方拿到图能一眼核对，不用自己加；
/// 3. **强制白底深字**，不跟随暗色主题：这张图是拿去打印/发人的。
///
/// 宽度自适应父容器，字号按容器宽度轻微缩放；导出时靠
/// `RepaintBoundary.toImage(pixelRatio)` 放大，所以预览即所得。
class ReportDocument extends ConsumerWidget {
  const ReportDocument({
    super.key,
    required this.title,
    required this.subtitle,
    required this.records,
    required this.fontScale,
    required this.compact,
    required this.showPhoto,
    required this.generatedAt,
    required this.rangeText,
    this.groupBy = GroupField.day,
    this.profileName = '',
    this.salaryMode = false,
  });

  final String title;
  final String subtitle;
  final List<PieceRecord> records;
  final double fontScale;

  /// true = 自用紧凑版（纯表格）；false = 对外版（带缩略图）
  final bool compact;
  final bool showPhoto;
  final DateTime generatedAt;
  final String rangeText;

  /// 分组方式：按日期 / 按型号 / 不分组
  final GroupField groupBy;

  /// 身份卡名字（报表标题下方显示，方便对账看单）
  final String profileName;

  /// 财务模式：同款汇总成「工资卡」，不带日期明细
  final bool salaryMode;

  int get _totalMilli => records.fold(0, (a, r) => a + r.subtotalMilli);

  /// 没填单价的条数（金额只是已知部分）
  int get _unpricedCount => records.where((r) => !r.hasPrice).length;

  /// 折算成基准单位的「百分之一」——跨单位汇总看这个，而不是原始数量相加
  int _totalCenti(UnitConverter c) =>
      records.fold(0, (a, r) => a + c.centiBaseOf(r));

  // 配色（固定，不随主题）
  static const Color _ink = Color(0xFF111418);
  static const Color _ink2 = Color(0xFF4A5260);
  static const Color _ink3 = Color(0xFF8B93A1);
  static const Color _line = Color(0xFFE3E7EF);
  static const Color _band = Color(0xFFF5F7FB);
  static const Color _accent = Color(0xFF1F5AE0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final converter = ref.watch(unitConverterProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        // 以 400 逻辑像素为基准缩放字号，窄屏不挤、宽屏不空
        final k = (constraints.maxWidth / 400).clamp(0.82, 1.7) * fontScale;
        if (salaryMode) return _salarySheet(k, converter);
        return Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(16 * k, 18 * k, 16 * k, 16 * k),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _header(k, converter),
              SizedBox(height: 12 * k),
              ..._buildGroups(k, converter),
              SizedBox(height: 12 * k),
              _grandTotal(k, converter),
              SizedBox(height: 8 * k),
              _footnote(k),
            ],
          ),
        );
      },
    );
  }

  /// 工资卡：同款汇总（型号/颜色/码数 · 数量 · 单价 · 金额），不带日期
  Widget _salarySheet(double k, UnitConverter converter) {
    final groups = groupSalary(records, converter);
    var totalCenti = 0;
    for (final r in records) {
      totalCenti += converter.centiBaseOf(r).toInt();
    }
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16 * k, 18 * k, 16 * k, 16 * k),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title.isEmpty ? '工资表' : title,
            style: TextStyle(
              fontSize: 20 * k,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          SizedBox(height: 4 * k),
          Row(
            children: <Widget>[
              if (profileName.isNotEmpty) ...<Widget>[
                Text('身份：$profileName',
                    style: TextStyle(
                        fontSize: 11.5 * k,
                        fontWeight: FontWeight.w600,
                        color: _ink2)),
                SizedBox(width: 10 * k),
              ],
              Text('共 ${groups.length} 款 / ${records.length} 条',
                  style: TextStyle(fontSize: 11 * k, color: _ink3)),
            ],
          ),
          SizedBox(height: 10 * k),
          // 表头
          Container(
            padding: EdgeInsets.symmetric(vertical: 6 * k),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: _line),
                bottom: BorderSide(color: _line),
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: 5,
                  child: Text('型号',
                      style: TextStyle(
                          fontSize: 10.5 * k,
                          fontWeight: FontWeight.w700,
                          color: _ink2)),
                ),
                SizedBox(
                  width: 62 * k,
                  child: Text('数量',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 10.5 * k,
                          fontWeight: FontWeight.w700,
                          color: _ink2)),
                ),
                SizedBox(
                  width: 56 * k,
                  child: Text('单价',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 10.5 * k,
                          fontWeight: FontWeight.w700,
                          color: _ink2)),
                ),
                SizedBox(
                  width: 74 * k,
                  child: Text('金额',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 10.5 * k,
                          fontWeight: FontWeight.w700,
                          color: _ink2)),
                ),
              ],
            ),
          ),
          for (final g in groups)
            Container(
              padding: EdgeInsets.symmetric(vertical: 7 * k),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _line)),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    flex: 5,
                    child: Text(
                      g.label,
                      style: TextStyle(
                          fontSize: 12 * k, height: 1.3, color: _ink),
                    ),
                  ),
                  SizedBox(
                    width: 62 * k,
                    child: Text(
                      !g.mixedUnits
                          ? '${g.qty}'
                          : '${(g.centiBase / 100).toStringAsFixed(2)}',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 12 * k, color: _ink),
                    ),
                  ),
                  SizedBox(
                    width: 56 * k,
                    child: Text(
                      g.singlePrice == null
                          ? '不一'
                          : (g.singlePrice == 0
                              ? '—'
                              : Money.plain(Money.toMilli(g.singlePrice!))),
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 11.5 * k, color: _ink2),
                    ),
                  ),
                  SizedBox(
                    width: 74 * k,
                    child: Text(
                      Money.format(g.amountMilli),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 12 * k,
                          fontWeight: FontWeight.w700,
                          color: _ink),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: 10 * k),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10 * k, vertical: 10 * k),
            decoration: BoxDecoration(
              color: _band,
              borderRadius: BorderRadius.circular(8 * k),
            ),
            child: Row(
              children: <Widget>[
                Text('合计',
                    style: TextStyle(
                        fontSize: 12 * k,
                        fontWeight: FontWeight.w700,
                        color: _ink2)),
                SizedBox(width: 8 * k),
                Text(
                  '${(totalCenti / 100).toStringAsFixed(totalCenti % 100 == 0 ? 0 : 2)} '
                  '${converter.baseUnit}',
                  style: TextStyle(fontSize: 12 * k, color: _ink2),
                ),
                const Spacer(),
                Text(
                  Money.format(_totalMilli),
                  style: TextStyle(
                    fontSize: 17 * k,
                    fontWeight: FontWeight.w800,
                    color: _accent,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10 * k),
          Text(
            '数量按「${converter.baseUnit}」折算；单价为空的条目不计金额。',
            style: TextStyle(fontSize: 9.5 * k, color: _ink3),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── 页眉 ───────────────────────────

  Widget _header(double k, UnitConverter converter) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Text(
                title.isEmpty ? '计件明细报表' : title,
                style: TextStyle(
                  fontSize: 19 * k,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            Text(
              '制表 ${Fmt.dateTime(generatedAt)}',
              style: TextStyle(fontSize: 8.5 * k, color: _ink3, height: 1.6),
            ),
          ],
        ),
        if (profileName.isNotEmpty) ...<Widget>[
          SizedBox(height: 4 * k),
          Text(
            '身份：$profileName',
            style: TextStyle(
              fontSize: 11.5 * k,
              fontWeight: FontWeight.w600,
              color: _ink2,
            ),
          ),
        ],
        if (subtitle.isNotEmpty) ...<Widget>[
          SizedBox(height: 3 * k),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10.5 * k, color: _ink2, height: 1.5),
          ),
        ],
        SizedBox(height: 8 * k),
        // 关键信息条：时间范围 / 条数 / 件数 / 金额
        Container(
          padding: EdgeInsets.symmetric(horizontal: 9 * k, vertical: 7 * k),
          decoration: BoxDecoration(
            color: _band,
            borderRadius: BorderRadius.circular(6 * k),
            border: Border.all(color: _line, width: 0.8),
          ),
          child: Row(
            children: <Widget>[
              _kv('统计区间', rangeText, k, flex: 3),
              _vline(k),
              _kv('记录', '${records.length} 条', k, flex: 1),
              _vline(k),
              _kv(
                '数量',
                '${UnitConverter.formatCenti(_totalCenti(converter))} ${converter.baseUnit}',
                k,
                flex: 2,
              ),
              _vline(k),
              _kv(
                '金额',
                Money.yuan(_totalMilli),
                k,
                flex: 2,
                highlight: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kv(
    String label,
    String value,
    double k, {
    int flex = 1,
    bool highlight = false,
  }) {
    return Expanded(
      flex: flex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(fontSize: 7.5 * k, color: _ink3, height: 1.2),
          ),
          SizedBox(height: 2 * k),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: (highlight ? 11 : 10) * k,
              fontWeight: FontWeight.w700,
              color: highlight ? _accent : _ink,
              height: 1.2,
              fontFeatures: tabularFigures,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vline(double k) => Container(
        width: 0.8,
        height: 22 * k,
        margin: EdgeInsets.symmetric(horizontal: 6 * k),
        color: _line,
      );

  // ─────────────────────────── 分组 ───────────────────────────

  List<Widget> _buildGroups(double k, UnitConverter converter) {
    if (records.isEmpty) {
      return <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(vertical: 20 * k),
          child: Center(
            child: Text(
              '没有记录',
              style: TextStyle(fontSize: 11 * k, color: _ink3),
            ),
          ),
        ),
      ];
    }

    final groups = _group(converter);
    final widgets = <Widget>[];
    for (var i = 0; i < groups.length; i++) {
      final g = groups[i];
      widgets.add(_groupHeader(g, k, index: i + 1, total: groups.length));
      widgets.add(SizedBox(height: 6 * k));
      widgets.add(compact ? _compactTable(g, k) : _cardList(g, k));
      widgets.add(SizedBox(height: 11 * k));
    }
    return widgets;
  }

  List<_Group> _group(UnitConverter converter) {
    if (groupBy == GroupField.none) {
      return <_Group>[
        _Group(key: '全部记录', records: _sorted(records), converter: converter),
      ];
    }

    final map = <String, List<PieceRecord>>{};
    for (final r in records) {
      final key = switch (groupBy) {
        GroupField.styleModel =>
          r.styleModel.isEmpty ? '（未填型号）' : r.styleModel,
        GroupField.day => Fmt.date(r.createdAt),
        _ => '全部记录',
      };
      (map[key] ??= <PieceRecord>[]).add(r);
    }

    final keys = map.keys.toList();
    if (groupBy == GroupField.styleModel) {
      // 型号按件数从多到少，一眼看到主力款
      keys.sort((a, b) {
        final qa = map[a]!.fold(0, (s, r) => s + r.quantity);
        final qb = map[b]!.fold(0, (s, r) => s + r.quantity);
        return qb.compareTo(qa);
      });
    } else {
      keys.sort(); // 日期正序
    }

    return keys
        .map((key) => _Group(
              key: key,
              records: _sorted(map[key]!),
              converter: converter,
            ))
        .toList();
  }

  /// 组内按时间升序，方便顺着时间核对
  List<PieceRecord> _sorted(List<PieceRecord> list) {
    final copy = List<PieceRecord>.of(list);
    copy.sort((a, b) {
      final c = a.createdAt.compareTo(b.createdAt);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
    return copy;
  }

  Widget _groupHeader(_Group g, double k, {required int index, required int total}) {
    final label = switch (groupBy) {
      GroupField.day => '${g.key}  ${Fmt.weekday(DateTime.parse(g.key))}',
      GroupField.styleModel => g.key,
      _ => '全部记录',
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * k, vertical: 5.5 * k),
      decoration: BoxDecoration(
        color: _band,
        border: Border(
          left: BorderSide(color: _accent, width: 2.5 * k),
          bottom: BorderSide(color: _line, width: 0.8),
        ),
      ),
      // 弹性分配：左边标题可压缩，右边金额固定宽度。
      // 之前用 Spacer + 裸 Text，内容一长就把金额顶出画布右边缘。
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 6,
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5 * k,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                      height: 1.3,
                    ),
                  ),
                ),
                if (total > 1) ...<Widget>[
                  SizedBox(width: 4 * k),
                  Text(
                    '$index/$total',
                    style: TextStyle(fontSize: 7.5 * k, color: _ink3),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              '${g.count} 条 · ${g.qtyText}',
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8.5 * k,
                color: _ink2,
                fontFeatures: tabularFigures,
              ),
            ),
          ),
          SizedBox(width: 6 * k),
          Text(
            Money.yuan(g.cents),
            style: TextStyle(
              fontSize: 10 * k,
              fontWeight: FontWeight.w800,
              color: _accent,
              fontFeatures: tabularFigures,
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────── 对外版：卡片列表 ──────────────────────

  Widget _cardList(_Group g, double k) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < g.records.length; i++) ...<Widget>[
          _cardRow(g.records[i], k, i + 1),
          if (i != g.records.length - 1)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 6 * k),
              child: Container(height: 0.7, color: _line),
            ),
        ],
      ],
    );
  }

  Widget _cardRow(PieceRecord r, double k, int index) {
    final file =
        r.photoName.isEmpty ? null : PhotoService.instance.syncFile(r.photoName);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showPhoto && file != null) ...<Widget>[
          Container(
            width: 42 * k,
            height: 42 * k,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F8),
              borderRadius: BorderRadius.circular(5 * k),
              border: Border.all(color: _line, width: 0.8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.file(
              file,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.image_not_supported_outlined,
                size: 14 * k,
                color: const Color(0xFFB9C0CC),
              ),
            ),
          ),
          SizedBox(width: 8 * k),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  // 时间精确到分钟，且等宽，竖着扫不会跳
                  Text(
                    Fmt.time(r.createdAt),
                    style: TextStyle(
                      fontSize: 9 * k,
                      color: _ink3,
                      fontFeatures: tabularFigures,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(width: 6 * k),
                  Expanded(
                    child: Text(
                      r.styleModel.isEmpty ? '（未填型号）' : r.styleModel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12 * k,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                        height: 1.3,
                      ),
                    ),
                  ),
                  SizedBox(width: 6 * k),
                  Text(
                    r.hasPrice ? Money.yuan(r.subtotalMilli) : '未计价',
                    style: TextStyle(
                      fontSize: (r.hasPrice ? 11.5 : 9.5) * k,
                      fontWeight: FontWeight.w800,
                      color: r.hasPrice ? _accent : _ink2,
                      fontFeatures: tabularFigures,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2.5 * k),
              Row(
                children: <Widget>[
                  _attr(r.color.isEmpty ? '—' : r.color, k),
                  SizedBox(width: 4 * k),
                  _attr(r.size.isEmpty ? '—' : r.size, k),
                  SizedBox(width: 6 * k),
                  Flexible(
                    child: Text(
                      '${r.quantity} ${r.unitOrBase} × ¥${Money.plain(Money.toMilli(r.unitPrice))}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 8.5 * k,
                        color: _ink2,
                        fontFeatures: tabularFigures,
                        height: 1.3,
                      ),
                    ),
                  ),
                  if (r.note.isNotEmpty) ...<Widget>[
                    SizedBox(width: 6 * k),
                    Expanded(
                      child: Text(
                        r.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 8.5 * k, color: _ink3),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _attr(String text, double k) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4 * k, vertical: 1.2 * k),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3F9),
        borderRadius: BorderRadius.circular(3 * k),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 7.5 * k,
          fontWeight: FontWeight.w600,
          color: _ink2,
          height: 1.3,
        ),
      ),
    );
  }

  // ────────────────────── 自用版：紧凑表格 ──────────────────────

  Widget _compactTable(_Group g, double k) {
    final head = TextStyle(
      fontSize: 8 * k,
      fontWeight: FontWeight.w700,
      color: _ink2,
      letterSpacing: 0.2,
      height: 1.3,
    );
    final numStyle = TextStyle(
      fontSize: 9 * k,
      color: _ink,
      fontFeatures: tabularFigures,
      height: 1.35,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // 表头
        Container(
          padding: EdgeInsets.symmetric(vertical: 4.5 * k, horizontal: 4 * k),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: _line, width: 0.8),
              bottom: BorderSide(color: _line, width: 0.8),
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(flex: 12, child: Text('时间', style: head)),
              Expanded(flex: 24, child: Text('型号', style: head)),
              Expanded(flex: 12, child: Text('颜色', style: head)),
              Expanded(flex: 7, child: Text('码', style: head)),
              Expanded(
                flex: 9,
                child: Text('数量', textAlign: TextAlign.right, style: head),
              ),
              Expanded(
                flex: 13,
                child: Text('单价', textAlign: TextAlign.right, style: head),
              ),
              Expanded(
                flex: 15,
                child: Text('金额', textAlign: TextAlign.right, style: head),
              ),
            ],
          ),
        ),
        // 明细
        for (var i = 0; i < g.records.length; i++)
          Container(
            padding: EdgeInsets.symmetric(vertical: 4.2 * k, horizontal: 4 * k),
            decoration: BoxDecoration(
              color: i.isEven ? Colors.white : const Color(0xFFFBFCFE),
              border: const Border(
                bottom: BorderSide(color: Color(0xFFEFF2F7), width: 0.6),
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: 12,
                  child: Text(
                    Fmt.time(g.records[i].createdAt),
                    style: numStyle.copyWith(color: _ink2),
                  ),
                ),
                Expanded(
                  flex: 24,
                  child: Text(
                    g.records[i].styleModel.isEmpty
                        ? '—'
                        : g.records[i].styleModel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: numStyle.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 12,
                  child: Text(
                    g.records[i].color.isEmpty ? '—' : g.records[i].color,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: numStyle.copyWith(color: _ink2),
                  ),
                ),
                Expanded(
                  flex: 7,
                  child: Text(
                    g.records[i].size.isEmpty ? '—' : g.records[i].size,
                    style: numStyle.copyWith(color: _ink2),
                  ),
                ),
                Expanded(
                  flex: 9,
                  child: Text(
                    '${g.records[i].quantity}${g.records[i].unitOrBase == g.baseUnit ? '' : g.records[i].unitOrBase}',
                    textAlign: TextAlign.right,
                    style: numStyle.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 13,
                  child: Text(
                    Money.plain(Money.toMilli(g.records[i].unitPrice)),
                    textAlign: TextAlign.right,
                    style: numStyle.copyWith(color: _ink2),
                  ),
                ),
                Expanded(
                  flex: 15,
                  child: Text(
                    Money.plain(g.records[i].subtotalMilli),
                    textAlign: TextAlign.right,
                    style: numStyle.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ─────────────────────────── 总计 ───────────────────────────

  Widget _grandTotal(double k, UnitConverter converter) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9 * k, vertical: 7 * k),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(6 * k),
        border: Border.all(color: _accent, width: 1),
      ),
      child: Row(
        children: <Widget>[
          Text(
            '总计',
            style: TextStyle(
              fontSize: 11 * k,
              fontWeight: FontWeight.w800,
              color: _ink,
              height: 1.3,
            ),
          ),
          SizedBox(width: 8 * k),
          Expanded(
            child: Text(
              '${records.length} 条 · ${UnitConverter.formatCenti(_totalCenti(converter))} ${converter.baseUnit}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9 * k,
                color: _ink2,
                fontFeatures: tabularFigures,
                height: 1.3,
              ),
            ),
          ),
          SizedBox(width: 6 * k),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                Money.yuan(_totalMilli),
                style: TextStyle(
                  fontSize: 15 * k,
                  fontWeight: FontWeight.w900,
                  color: _accent,
                  fontFeatures: tabularFigures,
                  height: 1.2,
                ),
              ),
              if (_unpricedCount > 0)
                Text(
                  '另 $_unpricedCount 条未计价',
                  style: TextStyle(
                    fontSize: 8 * k,
                    color: _ink2,
                    height: 1.3,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _footnote(double k) {
    return Row(
      children: <Widget>[
        Text(
          '计件助手 · 本表数据来自本机记录，未上传云端',
          style: TextStyle(fontSize: 7.5 * k, color: _ink3, height: 1.4),
        ),
        const Spacer(),
        Text(
          Fmt.dateTime(generatedAt),
          style: TextStyle(
            fontSize: 7.5 * k,
            color: _ink3,
            fontFeatures: tabularFigures,
          ),
        ),
      ],
    );
  }
}

/// 报表内的一个分组
class _Group {
  _Group({
    required this.key,
    required this.records,
    required this.converter,
  });

  final String key;
  final List<PieceRecord> records;
  final UnitConverter converter;

  int get count => records.length;
  int get quantity => records.fold(0, (s, r) => s + r.quantity);
  int get cents => records.fold(0, (s, r) => s + r.subtotalMilli);

  /// 折算后的基准数量（百分之一）
  int get centiBase => records.fold(0, (s, r) => s + converter.centiBaseOf(r));

  String get qtyText =>
      '${UnitConverter.formatCenti(centiBase)} ${converter.baseUnit}';

  String get baseUnit => converter.baseUnit;
}
