import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/profile.dart';
import '../../providers/chat_providers.dart';
import '../../providers/db_providers.dart';
import '../../providers/license_providers.dart';
import '../../providers/profile_providers.dart';
import '../../providers/records_providers.dart';
import '../pages/profiles_page.dart';
import 'ai_lock.dart';
import '../../core/avatars.dart';

/// 身份卡胶囊（列表页标题旁、AI 页顶部都用它）
class ProfileChip extends ConsumerWidget {
  const ProfileChip({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final p = ref.watch(activeProfileProvider);
    final name = (p?.name ?? '').trim();
    if (name.isEmpty) return const SizedBox.shrink();
    final avatar = p?.avatar ?? '';
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap ?? () => showProfileSwitcher(context, ref),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 3, 6, 3),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withAlpha(80),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant.withAlpha(140)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              avatar.isNotEmpty ? avatar : avatarFallback(name),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(width: 4),
            Text(
              name,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.expand_more,
                size: 14, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// 身份卡切换面板：列出现有身份 + 新建 + 管理
Future<void> showProfileSwitcher(BuildContext context, WidgetRef ref) async {
  // 多身份是付费功能：未激活直接拦
  if (!ref.read(aiActivatedProvider)) {
    await showNeedActivation(context, ref, feature: '多身份管理');
    return;
  }
  final scheme = Theme.of(context).colorScheme;
  final profiles = ref.read(profilesProvider).valueOrNull ?? const <Profile>[];
  final counts =
      await ref.read(profileRepoProvider).recordCounts();
  final activeId = ref.read(activeProfileIdProvider);

  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
            child: Row(
              children: <Widget>[
                const Text('切换身份卡',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const Spacer(),

              ],
            ),
          ),
          for (final p in profiles)
            ListTile(
              leading: CircleAvatar(
                radius: 15,
                backgroundColor: p.id == activeId
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
                child: Text(
                  p.avatar.isNotEmpty ? p.avatar : avatarFallback(p.name),
                  style: TextStyle(
                    fontSize: 14,
                    color: p.id == activeId ? Colors.white : scheme.onSurface,
                  ),
                ),
              ),
              title: Row(
                children: <Widget>[
                  Text(p.name, style: const TextStyle(fontSize: 13.5)),
                  if (p.avatar.isNotEmpty) ...<Widget>[
                    const SizedBox(width: 5),
                    Text(p.avatar, style: const TextStyle(fontSize: 13)),
                  ],
                  if (p.isDefault) ...<Widget>[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: scheme.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('默认',
                          style: TextStyle(
                              fontSize: 9, color: scheme.primary)),
                    ),
                  ],
                ],
              ),
              subtitle: Text('${counts[p.id] ?? 0} 条记录',
                  style: const TextStyle(fontSize: 10.5)),
              onTap: () async {
                Navigator.of(ctx).pop();
                if (p.id == activeId) return;
                await ref
                    .read(chatProvider.notifier)
                    .switchProfileTo(p.id);
                ref.invalidate(recordsProvider);
                ref.read(filterProvider.notifier).reset();
              },
            ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.person_add_alt_1_outlined),
            title: const Text('新建身份卡'),
            onTap: () async {
              Navigator.of(ctx).pop();
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const ProfilesPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.manage_accounts_outlined),
            title: const Text('管理身份卡'),
            onTap: () async {
              Navigator.of(ctx).pop();
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const ProfilesPage()),
              );
            },
          ),
        ],
      ),
    ),
  );
}
