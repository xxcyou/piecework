import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/option_item.dart';
import '../../providers/options_providers.dart';

/// 选项管理：维护型号 / 颜色 / 码数三个可选列表。
///
/// 删掉某项**不会**影响已有记录 —— 记录里存的是值本身，不是引用。
class OptionsPage extends StatelessWidget {
  const OptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('选项管理'),
          bottom: const TabBar(
            labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: <Widget>[
              Tab(text: '型号'),
              Tab(text: '颜色'),
              Tab(text: '码数'),
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[
            _OptionTab(kind: OptionKind.styleModel),
            _OptionTab(kind: OptionKind.color),
            _OptionTab(kind: OptionKind.size),
          ],
        ),
      ),
    );
  }
}

class _OptionTab extends ConsumerStatefulWidget {
  const _OptionTab({required this.kind});

  final OptionKind kind;

  @override
  ConsumerState<_OptionTab> createState() => _OptionTabState();
}

class _OptionTabState extends ConsumerState<_OptionTab>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _ctrl = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final v = _ctrl.text.trim();
    if (v.isEmpty) return;
    final ok = await ref.read(optionsProvider.notifier).add(widget.kind, v);
    if (!mounted) return;
    if (ok) {
      _ctrl.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「$v」已经在列表里了')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final list = ref.watch(optionsForProvider(widget.kind));

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  decoration: InputDecoration(
                    hintText: '新增${widget.kind.label}，例如 ${_hint()}',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _add,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(64, 44),
                ),
                child: const Text('添加'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: <Widget>[
              Text(
                '共 ${list.length} 项',
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '删除不影响已有记录',
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant.withAlpha(170),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Text(
                    '还没有${widget.kind.label}选项',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final v = list[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1B1E24)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: scheme.outlineVariant.withAlpha(140),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              v,
                              style: const TextStyle(fontSize: 13.5),
                            ),
                          ),
                          IconButton(
                            tooltip: '删除',
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.close,
                              size: 17,
                              color: scheme.onSurfaceVariant,
                            ),
                            onPressed: () async {
                              await ref
                                  .read(optionsProvider.notifier)
                                  .remove(widget.kind, v);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _hint() {
    switch (widget.kind) {
      case OptionKind.styleModel:
        return 'A1023';
      case OptionKind.color:
        return '藏青';
      case OptionKind.size:
        return 'XXXL';
    }
  }
}
