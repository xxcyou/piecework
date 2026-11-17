import 'piece_record.dart';

/// 「查看这批记录」用的操作快照视图。
///
/// 和普通筛选的区别：这是**伪造列表** ——
/// 直接把这次操作涉及的记录摊出来，不管它们现在还在不在列表里：
/// * 删掉的 → 从回收站捞出来，打「已删除」标签
/// * 新建的 → 打「新建」标签
/// * 修改的 → 打「已修改」标签，显示改后的值
///
/// 所以它是"这一刻的账"，不是"当前的库"。
class OperationView {
  const OperationView({
    required this.title,
    required this.tag,
    required this.records,
    this.note = '',
  });

  /// 例如「删除 8 条记录（共 826 件）」
  final String title;

  /// 每条记录右上角的标签：「已删除」「新建」「已修改」
  final String tag;

  /// 涉及的记录（顺序保持操作时的顺序）
  final List<PieceRecord> records;

  /// 补充说明，例如「其中 2 条已彻底删除」
  final String note;

  int get count => records.length;
}
