/// AI 提议的写操作，**必须由用户在界面上确认后才会真正执行**。
///
/// 设计动机：模型再聪明也可能理解偏。让它在删除/批量修改前先把「影响哪几条、
/// 改成什么」摆到用户面前，用户点一下才落库 —— 既满足「AI 能删能改」，
/// 又不会出现「一句话把账删没了」的事故。
enum PendingKind { delete, update, create, attachPhoto, detachPhoto }

extension PendingKindX on PendingKind {
  /// 操作快照视图里每条记录打的标签
  String get snapshotTag => switch (this) {
        PendingKind.delete => '已删除',
        PendingKind.update => '已修改',
        PendingKind.create => '新建',
        PendingKind.attachPhoto => '已关联图片',
        PendingKind.detachPhoto => '已移除图片',
      };

  String get wireName => switch (this) {
        PendingKind.delete => 'delete',
        PendingKind.update => 'update',
        PendingKind.create => 'create',
        PendingKind.attachPhoto => 'attachPhoto',
        PendingKind.detachPhoto => 'detachPhoto',
      };

  /// 按钮文案
  String get confirmLabel => switch (this) {
        PendingKind.delete => '确认删除',
        PendingKind.update => '确认修改',
        PendingKind.create => '确认新建',
        PendingKind.attachPhoto => '确认关联',
        PendingKind.detachPhoto => '确认解除',
      };

  static PendingKind fromWire(Object? v) => switch (v) {
        'delete' => PendingKind.delete,
        'update' => PendingKind.update,
        'attachPhoto' => PendingKind.attachPhoto,
        'detachPhoto' => PendingKind.detachPhoto,
        _ => PendingKind.create,
      };
}

class PendingAction {
  const PendingAction({
    required this.kind,
    required this.description,
    this.ids = const <int>[],
    this.changes = const <String, dynamic>{},
    this.items = const <Map<String, dynamic>>[],
    this.photoName = '',
    this.preview = const <String>[],
    this.diff = const <Map<String, dynamic>>[],
  });

  final PendingKind kind;

  /// 给用户看的一句话，例如「删除 3 条记录（共 45 件）」
  final String description;

  /// delete / update 的目标记录 id
  final List<int> ids;

  /// update 要写入的字段（key 与 PieceRecord 字段同名）
  final Map<String, dynamic> changes;

  /// create 的新记录
  final List<Map<String, dynamic>> items;

  /// attachPhoto 时要关联的对话图片文件名
  final String photoName;

  /// 会受影响的记录摘要（前 5 条），确认卡里列出来让人看清
  final List<String> preview;

  /// 修改前后的对比（确认卡上画成对比条）：
  /// `{label, before, after, unit, money, perItem}`
  /// before/after 是数字时画条形图，是字符串时只显示「旧 → 新」。
  final List<Map<String, dynamic>> diff;

  int get affectedCount =>
      kind == PendingKind.create ? items.length : ids.length;

  bool get isEmpty => affectedCount == 0;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind.wireName,
        'description': description,
        'ids': ids,
        'changes': changes,
        'items': items,
        'photoName': photoName,
        'preview': preview,
        'diff': diff,
      };

  static PendingAction? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    final ids = <int>[];
    final rawIds = m['ids'];
    if (rawIds is List) {
      for (final v in rawIds) {
        if (v is int) {
          ids.add(v);
        } else if (v is num) {
          ids.add(v.toInt());
        }
      }
    }
    final changes = <String, dynamic>{};
    final rawChanges = m['changes'];
    if (rawChanges is Map) {
      rawChanges.forEach((k, v) => changes[k.toString()] = v);
    }
    final items = <Map<String, dynamic>>[];
    final rawItems = m['items'];
    if (rawItems is List) {
      for (final v in rawItems) {
        if (v is Map) {
          items.add(v.map((k, vv) => MapEntry(k.toString(), vv)));
        }
      }
    }

    return PendingAction(
      kind: PendingKindX.fromWire(m['kind']),
      description: (m['description'] as String?) ?? '',
      ids: ids,
      changes: changes,
      items: items,
      photoName: (m['photoName'] as String?) ?? '',
      preview: (m['preview'] as List?)
              ?.whereType<String>()
              .toList() ??
          const <String>[],
      diff: (m['diff'] as List?)
              ?.whereType<Map>()
              .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
              .toList() ??
          const <Map<String, dynamic>>[],
    );
  }
}
