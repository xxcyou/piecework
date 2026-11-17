import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'secure_backup_card.dart';
import 'tutorials.dart';

/// 「数据」区的主卡片：**唯一**的自动备份通道（加密 + 公共目录）。
///
/// 以前这里还有一套「应用私有目录 auto_*.zip」的自动备份，
/// 卸载即丢、还让人以为有两份备份，已经删掉。
/// 手动导出/导入 .zip 仍然保留在设置页下面的独立入口里（换机迁移用）。
class BackupPanel extends ConsumerWidget {
  const BackupPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1B1E24)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withAlpha(140)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SecureBackupSection(),
          const Divider(height: 22),
          Row(
            children: <Widget>[
              Icon(Icons.school_outlined,
                  size: 15, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '第一次用？跟着引导点一遍就会了',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => runTutorialById(context, ref, 'backup'),
                icon: const Icon(Icons.play_circle_outline, size: 15),
                label: const Text('看引导', style: TextStyle(fontSize: 11.5)),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
