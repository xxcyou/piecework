import 'package:isar_community/isar.dart';

import '../../core/money.dart';

part 'piece_record.g.dart';

/// 记录状态：这批货是否已经上报给公司
enum RecordStatus {
  /// 还没上报（默认，列表默认只显示这个）
  pending,

  /// 已经上报公司
  reported,
}

extension RecordStatusX on RecordStatus {
  String get label => this == RecordStatus.pending ? '未上报' : '已上报';
}

/// 蛇形参数解析（AI 工具用）
RecordStatus recordStatusFromWire(Object? v) =>
    v == 'reported' ? RecordStatus.reported : RecordStatus.pending;

/// 一条计件记录 = 一批货的「本地底账」。
///
/// 设计要点：
/// * 照片只存**文件名**（相对 `<AppDocuments>/photos/`），不存绝对路径。
///   iOS/Android 的应用沙盒绝对路径会在升级、迁移后变化，存绝对路径必然失效。
/// * `createdAt` 是录入时间，索引用于时间范围筛选。
/// * 金额不做存储字段，一律由 `quantity * unitPrice` 实时计算，避免四舍五入漂移。
@collection
class PieceRecord {
  Id id = Isar.autoIncrement;

  /// 款式型号，例如 "A1023"、"XX"
  @Index()
  late String styleModel;

  /// 颜色，例如 "黑色"
  @Index()
  late String color;

  /// 码数，例如 "M"
  @Index()
  late String size;

  /// 件数（整数）
  late int quantity;

  /// 计量单位（件 / 片 / 打 …），默认「件」。
  /// 旧数据读出来可能是空串，业务层统一用 [unitOrBase] 兜底。
  String unit = '件';

  /// 该单位下的单价（元）。单价可精确到 **0.001 元（厘）**，内部按整数厘计算。
  late double unitPrice;

  /// 备注，可空
  String note = '';

  /// 实拍照片文件名（不含目录），空串表示未拍照
  String photoName = '';

  /// 软删除时间。null = 正常；非空 = 在回收站（30 天后自动清理）。
  /// 不做物理删除 —— 误删了还能捞回来。
  @Index()
  DateTime? deletedAt;

  /// 上报状态：默认未上报。列表默认过滤掉已上报的，避免重复上报。
  @enumerated
  @Index()
  RecordStatus status = RecordStatus.pending;

  /// 上报时间（标记为已上报时写入）
  DateTime? reportedAt;

  /// 录入时间
  @Index()
  late DateTime createdAt;

  /// 最后修改时间（编辑过才有值）
  DateTime? updatedAt;
}

/// 计算属性放在 extension 里：
/// Isar 代码生成器只处理实例字段，getter 放类内可能触发告警，
/// 用 extension 可以 100% 规避生成器行为差异。
extension PieceRecordX on PieceRecord {
  /// 单位兜底（兼容加字段之前录入的旧记录）
  String get unitOrBase => unit.trim().isEmpty ? '件' : unit.trim();

  /// 小计金额（**分**）。
  ///
  /// 财务计算一律走整数分：`10 件 × 12.35` 得到 12350 分，
  /// 而不是 123.49999999999999 元。累加汇总时也不会漂。
  int get subtotalMilli => Money.multiply(quantity, unitPrice);

  /// 有没有填单价。
  ///
  /// 很多师傅只记件数、不知道单价（要等公司结算），所以「单价 0」一律当作
  /// **未填**处理：小计按 0 算，但汇总里要单独标出「未计价」的条数和件数，
  /// 不能当成「这批货白干」。
  bool get hasPrice => unitPrice > 0;

  /// 缺了哪些字段（录入时可能只知道件数/码数）
  List<String> get missingFields => <String>[
        if (styleModel.trim().isEmpty) 'styleModel',
        if (color.trim().isEmpty) 'color',
        if (size.trim().isEmpty) 'size',
        if (!hasPrice) 'price',
      ];

  /// 小计金额（元），仅用于显示
  double get subtotal => Money.toYuan(subtotalMilli);

  bool get hasPhoto => photoName.isNotEmpty;

  bool get isReported => status == RecordStatus.reported;

  bool get isDeleted => deletedAt != null;
}
