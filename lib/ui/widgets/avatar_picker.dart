import 'package:flutter/material.dart';

import '../../core/avatars.dart';

/// 头像选择：24 个 emoji + 「不用头像（用名字首字）」
Future<String?> pickAvatar(BuildContext context, {String current = ''}) {
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('选个头像',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final a in kProfileAvatars)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(ctx).pop(a),
                    child: Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: a == current
                            ? scheme.primary.withAlpha(26)
                            : scheme.surfaceContainerHighest.withAlpha(70),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: a == current
                              ? scheme.primary
                              : scheme.outlineVariant.withAlpha(120),
                        ),
                      ),
                      child: Text(a, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(''),
                    child: const Text('不用头像（显示名字首字）'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('取消'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
