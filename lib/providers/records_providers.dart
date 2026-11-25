import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../data/models/operation_view.dart';
import '../data/models/piece_record.dart';
import '../data/models/record_filter.dart';
import '../data/services/auto_backup_service.dart';
import '../data/services/query_engine.dart';
import 'db_providers.dart';
import 'profile_providers.dart';
import 'units_providers.dart';

/// 当前身份卡的记录（响应式：任何写入都会自动推送新列表）
///
/// 多身份必须隔离：这里按 activeProfileId 过滤，
/// 列表/报表/AI 都吃这一份数据，天然不会串账。
final recordsProvider = StreamProvider<List<PieceRecord>>((ref) {
  final profileId = ref.watch(activeProfileIdProvider);
  final activeIsDefault = ref.watch(activeProfileProvider)?.isDefault ?? false;
  return ref.watch(recordRepoProvider).watchAll().map((all) {
    // 按身份过滤；profileId==0 的历史记录归到「默认身份」，
    // 否则用户新建/复制保存后看不到那条记录（以为没保存）
    final list = profileId == 0
        ? all
        : all
            .where((r) =>
                r.profileId == profileId ||
                (r.profileId == 0 && activeIsDefault))
            .toList();
    // 数据一变就排一次自动备份（内部防抖 25 秒）
    AutoBackupService.instance.schedule();
    return list;
  });
});

/// 当前筛选条件
class FilterNotifier extends Notifier<RecordFilter> {
  @override
  RecordFilter build() {
    // 身份一变就清空筛选：条件（型号/颜色…）属于上一个身份的环境，
    // 带过去只会筛出空列表
    ref.watch(activeProfileIdProvider);
    return RecordFilter.empty;
  }

  void apply(RecordFilter filter) => state = filter;

  void reset() => state = RecordFilter.empty;

  void setQuick(QuickRange quick, {DateTime? start, DateTime? end}) {
    state = state.copyWith(
      quick: quick,
      customStart: start,
      customEnd: end,
    );
  }

  void setSort(SortField field) {
    // 点同一列则切换升降序
    if (state.sortField == field) {
      state = state.copyWith(ascending: !state.ascending);
    } else {
      state = state.copyWith(sortField: field, ascending: false);
    }
  }

  void toggleStyle(String v) => state = state.copyWith(
        styleModels: _toggle(state.styleModels, v),
      );

  void toggleColor(String v) => state = state.copyWith(
        colors: _toggle(state.colors, v),
      );

  void toggleSize(String v) => state = state.copyWith(
        sizes: _toggle(state.sizes, v),
      );

  void setStyleModels(Set<String> v) => state = state.copyWith(styleModels: v);
  void setColors(Set<String> v) => state = state.copyWith(colors: v);
  void setSizes(Set<String> v) => state = state.copyWith(sizes: v);

  void setQuantityRange({int? min, int? max}) => state = state.copyWith(
        minQty: min,
        maxQty: max,
        clearMinQty: min == null,
        clearMaxQty: max == null,
      );

  static Set<String> _toggle(Set<String> src, String v) {
    final next = Set<String>.from(src);
    if (!next.remove(v)) next.add(v);
    return next;
  }
}

final filterProvider = NotifierProvider<FilterNotifier, RecordFilter>(
  FilterNotifier.new,
);

/// 操作快照视图（「查看这批记录」点进来的那个伪造列表）
/// null = 正常列表
final operationViewProvider = StateProvider<OperationView?>((ref) => null);

/// 回收站（已软删除，30 天内可恢复）
final deletedRecordsProvider = StreamProvider<List<PieceRecord>>((ref) {
  return ref.watch(recordRepoProvider).watchDeleted();
});

/// 筛选结果（同步派生：记录变化或筛选变化都会立即重算）
final filteredResultProvider = Provider<QueryResult>((ref) {
  final async = ref.watch(recordsProvider);
  final filter = ref.watch(filterProvider);
  final list = async.valueOrNull ?? const <PieceRecord>[];
  final converter = ref.watch(unitConverterProvider);
  return QueryEngine.apply(list, filter, converter: converter);
});

/// 当前选中批量操作的记录 id
class SelectionNotifier extends Notifier<Set<Id>> {
  @override
  Set<Id> build() => <Id>{};

  void toggle(Id id) {
    final next = Set<Id>.from(state);
    if (!next.remove(id)) next.add(id);
    state = next;
  }

  void selectAll(Iterable<Id> ids) => state = ids.toSet();

  void clear() => state = <Id>{};

  bool get isActive => state.isNotEmpty;
}

final selectionProvider = NotifierProvider<SelectionNotifier, Set<Id>>(
  SelectionNotifier.new,
);

/// 列表分块加载：一次渲染 50 条，滚到底再追加 50。
/// 数据几千条时，避免一次性构建几千个卡片 widget。
class VisibleCountNotifier extends Notifier<int> {
  static const int step = 50;

  @override
  int build() => step;

  void more() => state = state + step;

  void reset() => state = step;
}

final visibleCountProvider =
    NotifierProvider<VisibleCountNotifier, int>(VisibleCountNotifier.new);

/// 是否处于批量选择模式
class SelectionModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void enter() => state = true;

  void exit() => state = false;
}

final selectionModeProvider = NotifierProvider<SelectionModeNotifier, bool>(
  SelectionModeNotifier.new,
);
