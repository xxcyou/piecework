import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/profile.dart';
import '../../providers/chat_providers.dart';
import '../../providers/db_providers.dart';
import '../../providers/profile_providers.dart';
import '../../providers/records_providers.dart';
import '../widgets/color_chip.dart';

/// 身份卡管理：新建 / 改名 / 改颜色 / 归档 / 删除
class ProfilesPage extends ConsumerStatefulWidget {
  const ProfilesPage({super.key});

  @override
  ConsumerState<ProfilesPage> createState() => _ProfilesPageState();
}

class _ProfilesPageState extends ConsumerState<ProfilesPage> {
  Map<int, int> _counts = const <int, int>{};

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final c = await ref.read(profileRepoProvider).recordCounts();
    if (!mounted) return;
    setState(() => _counts = c);
  }

  Future<void> _create() async {
    final name = await _askName(title: '新建身份卡');
    if (name == null || name.trim().isEmpty) return;
    final p = await ref.read(profileRepoProvider).create(name.trim());
    await _loadCounts();
    if (!mounted) return;
    await ref.read(chatProvider.notifier).switchProfileTo(p.id);
    ref.invalidate(recordsProvider);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _rename(Profile p) async {
    final name = await _askName(title: '改名', initial: p.name);
    if (name == null || name.trim().isEmpty) return;
    p.name = name.trim();
    await ref.read(profileRepoProvider).update(p);
    _loadCounts();
  }

  Future<void> _editMeta(Profile p) async {
    final color = await _askName(
      title: '颜色名（例如 藏青 / 米白，留空不显示色块）',
      initial: p.colorName,
    );
    if (color == null) return;
    final note = await _askName(title: '备注（工种/工号，可留空）', initial: p.note);
    if (note == null) return;
    p.colorName = color.trim();
    p.note = note.trim();
    await ref.read(profileRepoProvider).update(p);
    _loadCounts();
  }

  Future<void> _archive(Profile p) async {
    p.archived = !p.archived;
    await ref.read(profileRepoProvider).update(p);
    _loadCounts();
  }

  Future<void> _delete(Profile p) async {
    if (p.isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('默认身份不能删除（可以改名）')),
      );
      return;
    }
    final n = _counts[p.id] ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这个身份卡？'),
        content: Text(
          '「${p.name}」下的 $n 条记录会一起进回收站（30 天内可恢复），'
          '不会真正丢失。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(profileRepoProvider).deleteWithRecords(p.id);
    await _loadCounts();
    if (!mounted) return;
    // 删的是当前身份 → 切回默认
    if (ref.read(activeProfileIdProvider) == p.id) {
      final list = ref.read(profilesProvider).valueOrNull ?? const <Profile>[];
      final def = list.where((e) => e.isDefault).firstOrNull ?? list.firstOrNull;
      if (def != null) {
        await ref.read(chatProvider.notifier).switchProfileTo(def.id);
        ref.invalidate(recordsProvider);
      }
    }
  }

  Future<String?> _askName({required String title, String initial = ''}) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(isDense: true),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(profilesProvider);
    final activeId = ref.watch(activeProfileIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('身份卡'),
        actions: <Widget>[
          IconButton(
            tooltip: '新建身份卡',
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: _create,
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('读身份卡失败：$e')),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
          children: <Widget>[
            Text(
              '每个身份卡的记录、报表、AI 对话都是独立的；'
              '切换身份后 AI 只能看到当前身份的账。',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            for (final p in list)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        p.id == activeId ? scheme.primary : scheme.surfaceContainerHighest,
                    child: Text(
                      p.name.isEmpty ? '?' : p.name.characters.first,
                      style: TextStyle(
                        fontSize: 13,
                        color: p.id == activeId ? Colors.white : scheme.onSurface,
                      ),
                    ),
                  ),
                  title: Row(
                    children: <Widget>[
                      Text(p.name, style: const TextStyle(fontSize: 13.5)),
                      if (p.colorName.isNotEmpty) ...<Widget>[
                        const SizedBox(width: 6),
                        ColorChip(name: p.colorName, size: 9, filled: false),
                      ],
                      if (p.isDefault) ...<Widget>[
                        const SizedBox(width: 6),
                        Text('默认',
                            style: TextStyle(
                                fontSize: 9.5, color: scheme.primary)),
                      ],
                      if (p.archived) ...<Widget>[
                        const SizedBox(width: 6),
                        Text('已归档',
                            style: TextStyle(
                                fontSize: 9.5, color: scheme.onSurfaceVariant)),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    '${_counts[p.id] ?? 0} 条记录'
                    '${p.note.isEmpty ? '' : ' · ${p.note}'}',
                    style: const TextStyle(fontSize: 10.5),
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: (v) async {
                      switch (v) {
                        case 'use':
                          await ref
                              .read(chatProvider.notifier)
                              .switchProfileTo(p.id);
                          ref.invalidate(recordsProvider);
                          break;
                        case 'rename':
                          await _rename(p);
                          break;
                        case 'meta':
                          await _editMeta(p);
                          break;
                        case 'archive':
                          await _archive(p);
                          break;
                        case 'delete':
                          await _delete(p);
                          break;
                      }
                    },
                    itemBuilder: (_) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                          value: 'use', child: Text('切换到这个身份')),
                      const PopupMenuItem<String>(
                          value: 'rename', child: Text('改名')),
                      const PopupMenuItem<String>(
                          value: 'meta', child: Text('颜色 / 备注')),
                      PopupMenuItem<String>(
                          value: 'archive',
                          child: Text(p.archived ? '取消归档' : '归档')),
                      if (!p.isDefault)
                        const PopupMenuItem<String>(
                            value: 'delete', child: Text('删除')),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
