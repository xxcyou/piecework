import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/record_filter.dart';
import 'records_providers.dart';

/// 底部导航当前页
class TabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void go(int index) => state = index;
}

final tabIndexProvider = NotifierProvider<TabNotifier, int>(TabNotifier.new);

/// 从 AI 回答一键跳到「筛选后的记录列表」
void jumpToRecords(WidgetRef ref, RecordFilter filter) {
  ref.read(filterProvider.notifier).apply(filter);
  ref.read(selectionProvider.notifier).clear();
  ref.read(tabIndexProvider.notifier).go(0);
}
