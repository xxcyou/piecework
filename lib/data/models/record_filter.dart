import 'package:flutter/material.dart';

import '../../core/date_utils.dart';

/// 快捷时间范围
enum QuickRange { all, today, yesterday, thisWeek, thisMonth, custom }

extension QuickRangeX on QuickRange {
  String get label => switch (this) {
        QuickRange.all => '全部',
        QuickRange.today => '今天',
        QuickRange.yesterday => '昨天',
        QuickRange.thisWeek => '本周',
        QuickRange.thisMonth => '本月',
        QuickRange.custom => '自定义',
      };
}

/// 排序字段
enum SortField { createdAt, quantity, amount }

extension SortFieldX on SortField {
  String get label => switch (this) {
        SortField.createdAt => '时间',
        SortField.quantity => '数量',
        SortField.amount => '金额',
      };
}

/// 分组维度（AI 汇总用）
enum GroupField { none, styleModel, color, size, day, month }

extension GroupFieldX on GroupField {
  String get label => switch (this) {
        GroupField.none => '合计',
        GroupField.styleModel => '型号',
        GroupField.color => '颜色',
        GroupField.size => '码数',
        GroupField.day => '日期',
        GroupField.month => '月份',
      };
}

/// 上报状态条件。默认只看未上报 —— 上报过的不用再出现在待办里。
enum StatusFilter { pendingOnly, reportedOnly, all }

extension StatusFilterX on StatusFilter {
  String get label => switch (this) {
        StatusFilter.pendingOnly => '未上报',
        StatusFilter.reportedOnly => '已上报',
        StatusFilter.all => '全部',
      };

  String get wireName => switch (this) {
        StatusFilter.pendingOnly => 'pending',
        StatusFilter.reportedOnly => 'reported',
        StatusFilter.all => 'all',
      };

}

/// 蛇形参数解析（AI 工具用）
/// 上报状态筛选。
///
/// **不传 = 不限（all）**：以前默认 pendingOnly，模型只要漏填 status，
/// 已上报的记录就被静默过滤掉 —— 用户看到的就是「汇总全空」。
StatusFilter statusFilterFromWire(Object? v) => switch (v) {
      'reported' => StatusFilter.reportedOnly,
      'pending' => StatusFilter.pendingOnly,
      _ => StatusFilter.all,
    };

/// 照片条件：忘记拍照是常态，所以「缺照片」要能单独筛出来补拍。
enum PhotoFilter { any, hasPhoto, noPhoto }

extension PhotoFilterX on PhotoFilter {
  String get label => switch (this) {
        PhotoFilter.any => '全部',
        PhotoFilter.hasPhoto => '有照片',
        PhotoFilter.noPhoto => '缺照片',
      };

  /// AI 工具参数用的蛇形值
  String get wireName => switch (this) {
        PhotoFilter.any => 'any',
        PhotoFilter.hasPhoto => 'has_photo',
        PhotoFilter.noPhoto => 'no_photo',
      };

}

/// AI 工具参数（蛇形）→ 枚举。extension 里不能放 static，所以放顶层。
PhotoFilter photoFilterFromWire(Object? v) => switch (v) {
      'has_photo' => PhotoFilter.hasPhoto,
      'no_photo' => PhotoFilter.noPhoto,
      _ => PhotoFilter.any,
    };

/// 缺信息筛选：只记了件数、型号/颜色/码数/单价都没填的记录，
/// 要能一键捞出来补录。
enum MissingField { styleModel, color, size, price }

extension MissingFieldX on MissingField {
  String get label => switch (this) {
        MissingField.styleModel => '缺型号',
        MissingField.color => '缺颜色',
        MissingField.size => '缺码数',
        MissingField.price => '缺单价',
      };

  /// AI 工具参数用的蛇形值
  String get wireName => switch (this) {
        MissingField.styleModel => 'style_model',
        MissingField.color => 'color',
        MissingField.size => 'size',
        MissingField.price => 'price',
      };
}

/// AI 工具参数（蛇形）→ 枚举；认不出的忽略
MissingField? missingFieldFromWire(Object? v) {
  final s = v is String ? v.trim().toLowerCase() : '';
  return switch (s) {
    'style_model' || 'stylemodel' || 'style' => MissingField.styleModel,
    'color' || 'colour' => MissingField.color,
    'size' => MissingField.size,
    'price' || 'unit_price' || 'unitprice' => MissingField.price,
    _ => null,
  };
}

/// 记录筛选条件。不可变对象，所有修改都返回新实例。
///
/// 同时承担两个职责：
/// 1. UI 筛选页 ↔ 记录列表 的状态载体；
/// 2. AI 工具调用（query/aggregate/delete/update）解析出来的查询参数载体，
///    所以它必须能无损 JSON 往返 —— 见 [toJson] / [fromJson]。
@immutable
class RecordFilter {
  const RecordFilter({
    this.quick = QuickRange.all,
    this.customStart,
    this.customEnd,
    this.styleModels = const <String>{},
    this.colors = const <String>{},
    this.sizes = const <String>{},
    this.minQty,
    this.maxQty,
    this.photoFilter = PhotoFilter.any,
    this.missing = const <MissingField>{},
    this.statusFilter = StatusFilter.pendingOnly,
    this.sortField = SortField.createdAt,
    this.ascending = false,
    this.pinnedIds = const <int>[],
  });

  final QuickRange quick;
  final DateTime? customStart;
  final DateTime? customEnd;

  /// 多选条件：空集合 = 不限
  final Set<String> styleModels;
  final Set<String> colors;
  final Set<String> sizes;

  /// 数量区间（含端点）
  final int? minQty;
  final int? maxQty;

  /// 精确锁定的记录 id（AI 查询那一刻命中的那批）。
  ///
  /// 非空时**优先按 id 筛**，忽略型号/颜色/日期等条件 ——
  /// 这样即使你后来改了型号、颜色，点「查看这批记录」看到的还是同一批。
  final List<int> pinnedIds;

  bool get isPinned => pinnedIds.isNotEmpty;

  /// 照片条件
  final PhotoFilter photoFilter;

  /// 缺信息条件：选中的字段必须**都是空的**（AND）。
  /// 空集合 = 不限。
  final Set<MissingField> missing;

  /// 上报状态条件（默认只看未上报）
  final StatusFilter statusFilter;

  final SortField sortField;
  final bool ascending;

  static const RecordFilter empty = RecordFilter();

  // ────────────────────────── 派生 ──────────────────────────

  /// 解析成绝对时间区间；null 表示不限时间。
  DateTimeRange? resolveRange([DateTime? now]) {
    final n = now ?? DateTime.now();
    switch (quick) {
      case QuickRange.all:
        return null;
      case QuickRange.today:
        return DateTimeRange(start: DateUtil.startOfDay(n), end: DateUtil.endOfDay(n));
      case QuickRange.yesterday:
        final y = DateUtil.yesterday(n);
        return DateTimeRange(start: DateUtil.startOfDay(y), end: DateUtil.endOfDay(y));
      case QuickRange.thisWeek:
        return DateTimeRange(start: DateUtil.startOfWeek(n), end: DateUtil.endOfDay(n));
      case QuickRange.thisMonth:
        return DateTimeRange(start: DateUtil.startOfMonth(n), end: DateUtil.endOfDay(n));
      case QuickRange.custom:
        if (customStart == null && customEnd == null) return null;
        final s = customStart ?? customEnd!;
        final e = customEnd ?? customStart!;
        return DateTimeRange(
          start: DateUtil.startOfDay(s),
          end: DateUtil.endOfDay(e),
        );
    }
  }

  /// 生效中的条件数量（用于筛选按钮上的角标）
  int get activeCount {
    var n = 0;
    if (quick != QuickRange.all) n++;
    if (styleModels.isNotEmpty) n++;
    if (colors.isNotEmpty) n++;
    if (sizes.isNotEmpty) n++;
    if (minQty != null || maxQty != null) n++;
    if (photoFilter != PhotoFilter.any) n++;
    if (missing.isNotEmpty) n++;
    if (statusFilter != StatusFilter.pendingOnly) n++;
    return n;
  }

  bool get isActive => activeCount > 0;

  /// 一行文字摘要，用于列表页顶部的筛选条
  String get summary {
    final parts = <String>[];
    if (quick != QuickRange.all) {
      if (quick == QuickRange.custom && customStart != null && customEnd != null) {
        parts.add('${_md(customStart!)}~${_md(customEnd!)}');
      } else {
        parts.add(quick.label);
      }
    }
    if (styleModels.isNotEmpty) parts.add('型号:${styleModels.join("/")}');
    if (colors.isNotEmpty) parts.add('颜色:${colors.join("/")}');
    if (sizes.isNotEmpty) parts.add('码数:${sizes.join("/")}');
    if (minQty != null || maxQty != null) {
      parts.add('数量:${minQty ?? 0}-${maxQty ?? "∞"}');
    }
    if (photoFilter != PhotoFilter.any) parts.add(photoFilter.label);
    if (missing.isNotEmpty) {
      parts.add(missing.map((m) => m.label).join('/'));
    }
    if (statusFilter != StatusFilter.pendingOnly) parts.add(statusFilter.label);
    if (isPinned) {
      final tail = parts.isEmpty ? '' : ' · ${parts.join(' · ')}';
      return '这批记录（${pinnedIds.length} 条）$tail';
    }
    if (parts.isEmpty) return '未上报记录';
    return parts.join(' · ');
  }

  static String _md(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ────────────────────────── 修改 ──────────────────────────

  RecordFilter copyWith({
    QuickRange? quick,
    DateTime? customStart,
    DateTime? customEnd,
    bool clearCustomRange = false,
    Set<String>? styleModels,
    Set<String>? colors,
    Set<String>? sizes,
    int? minQty,
    int? maxQty,
    bool clearMinQty = false,
    bool clearMaxQty = false,
    PhotoFilter? photoFilter,
    Set<MissingField>? missing,
    StatusFilter? statusFilter,
    SortField? sortField,
    bool? ascending,
    List<int>? pinnedIds,
  }) {
    return RecordFilter(
      pinnedIds: pinnedIds ?? this.pinnedIds,
      quick: quick ?? this.quick,
      customStart: clearCustomRange ? null : (customStart ?? this.customStart),
      customEnd: clearCustomRange ? null : (customEnd ?? this.customEnd),
      styleModels: styleModels ?? this.styleModels,
      colors: colors ?? this.colors,
      sizes: sizes ?? this.sizes,
      minQty: clearMinQty ? null : (minQty ?? this.minQty),
      maxQty: clearMaxQty ? null : (maxQty ?? this.maxQty),
      photoFilter: photoFilter ?? this.photoFilter,
      missing: missing ?? this.missing,
      statusFilter: statusFilter ?? this.statusFilter,
      sortField: sortField ?? this.sortField,
      ascending: ascending ?? this.ascending,
    );
  }

  // ────────────────────────── JSON ──────────────────────────

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (pinnedIds.isNotEmpty) 'pinnedIds': pinnedIds,
        'quick': quick.name,
        'customStart': customStart?.millisecondsSinceEpoch,
        'customEnd': customEnd?.millisecondsSinceEpoch,
        'styleModels': styleModels.toList(),
        'colors': colors.toList(),
        'sizes': sizes.toList(),
        'minQty': minQty,
        'maxQty': maxQty,
        'photoFilter': photoFilter.name,
        'missing': missing.map((m) => m.name).toList(),
        'statusFilter': statusFilter.name,
        'sortField': sortField.name,
        'ascending': ascending,
      };

  static RecordFilter fromJson(Map<String, dynamic> json) {
    T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
      if (name is! String) return fallback;
      for (final v in values) {
        if (v.name == name) return v;
      }
      return fallback;
    }

    List<String> strList(Object? v) {
      if (v is List) return v.whereType<String>().toList();
      return const <String>[];
    }

    int? asInt(Object? v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    final cs = asInt(json['customStart']);
    final ce = asInt(json['customEnd']);

    final rawPinned = json['pinnedIds'];
    final pinned = rawPinned is List
        ? rawPinned
            .whereType<num>()
            .map((e) => e.toInt())
            .toList()
        : const <int>[];

    return RecordFilter(
      pinnedIds: pinned,
      quick: enumByName(QuickRange.values, json['quick'], QuickRange.all),
      customStart: cs == null ? null : DateTime.fromMillisecondsSinceEpoch(cs),
      customEnd: ce == null ? null : DateTime.fromMillisecondsSinceEpoch(ce),
      styleModels: strList(json['styleModels']).toSet(),
      colors: strList(json['colors']).toSet(),
      sizes: strList(json['sizes']).toSet(),
      minQty: asInt(json['minQty']),
      maxQty: asInt(json['maxQty']),
      photoFilter:
          enumByName(PhotoFilter.values, json['photoFilter'], PhotoFilter.any),
      missing: <MissingField>{
        for (final n in strList(json['missing']))
          // 兼容两种写法：自己的 JSON 用 name（styleModel），
          // AI 参数用蛇形（style_model）
          ...MissingField.values
              .where((m) => m.name == n || m.wireName == n),
      },
      statusFilter: enumByName(
          StatusFilter.values, json['statusFilter'], StatusFilter.pendingOnly),
      sortField: enumByName(SortField.values, json['sortField'], SortField.createdAt),
      ascending: json['ascending'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RecordFilter &&
      other.quick == quick &&
      other.customStart == customStart &&
      other.customEnd == customEnd &&
      _setEq(other.styleModels, styleModels) &&
      _setEq(other.colors, colors) &&
      _setEq(other.sizes, sizes) &&
      other.minQty == minQty &&
      other.maxQty == maxQty &&
      other.photoFilter == photoFilter &&
      _setEq(other.missing, missing) &&
      other.statusFilter == statusFilter &&
      other.sortField == sortField &&
      other.ascending == ascending;

  @override
  int get hashCode => Object.hash(
        quick,
        customStart,
        customEnd,
        Object.hashAllUnordered(styleModels),
        Object.hashAllUnordered(colors),
        Object.hashAllUnordered(sizes),
        minQty,
        maxQty,
        photoFilter,
        statusFilter,
        sortField,
        ascending,
      );

  static bool _setEq<T>(Set<T> a, Set<T> b) =>
      a.length == b.length && a.containsAll(b);
}
