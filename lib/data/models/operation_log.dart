import 'package:isar_community/isar.dart';

part 'operation_log.g.dart';

/// 操作类型
enum OpKind { delete, update, create, restore }

extension OpKindX on OpKind {
  String get label => switch (this) {
        OpKind.delete => '删除',
        OpKind.update => '修改',
        OpKind.create => '新建',
        OpKind.restore => '恢复',
      };

  String get wireName => name;
}

/// 蛇形/字符串 → 枚举（extension 里不能放 static，所以放顶层）
OpKind opKindFromWire(Object? v) => switch (v) {
      'update' => OpKind.update,
      'create' => OpKind.create,
      'restore' => OpKind.restore,
      _ => OpKind.delete,
    };

/// 操作日志：一次写操作的完整快照，用于「撤销」。
///
/// payload 存 `{"before":[...], "after":[...]}` —— 受影响记录的完整 JSON。
/// 撤销时按类型回放：
/// * delete  → 把 before 里的记录恢复（deletedAt 清空）
/// * create  → 把 after 里的记录软删除
/// * update  → 把 before 的旧值写回
@collection
class OperationLog {
  Id id = Isar.autoIncrement;

  /// delete / update / create / restore
  @Index()
  late String kind;

  /// manual（手动） / ai（AI 执行）
  @Index()
  late String source;

  /// 给人看的一句话，例如「删除 3 条记录（共 45 件）」
  late String summary;

  /// 受影响记录数
  int recordCount = 0;

  /// 完整快照 JSON
  late String payload;

  @Index()
  late DateTime createdAt;

  /// 是否已撤销
  bool undone = false;

  DateTime? undoneAt;
}

/// 计算属性放 extension：Isar 生成器会把类内 getter 当成字段
extension OperationLogX on OperationLog {
  OpKind get kindEnum => opKindFromWire(kind);

  bool get isAi => source == 'ai';
}
