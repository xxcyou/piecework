import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/license_providers.dart';

/// AI 未激活时的遮罩：磨砂 + 不可操作
class AiLockOverlay extends ConsumerWidget {
  const AiLockOverlay({super.key, required this.onActivate});

  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            color: scheme.surface.withAlpha(150),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.lock_outline, size: 34, color: scheme.primary),
                const SizedBox(height: 10),
                const Text('AI 助手未激活',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('激活后可用',
                    style: TextStyle(
                        fontSize: 11.5, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: onActivate,
                  child: const Text('输入激活码'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 激活对话框：显示设备码（可复制）+ 粘贴激活码
Future<void> showActivationDialog(BuildContext context, WidgetRef ref) {
  final codeCtrl = TextEditingController();
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('激活 AI 助手'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('设备码', style: TextStyle(fontSize: 11.5)),
            const SizedBox(height: 4),
            Consumer(
              builder: (c, r, _) {
                final dev = r.watch(deviceCodeProvider);
                return dev.when(
                  loading: () => const Text('读取中…'),
                  error: (e, _) => Text('读取失败：$e'),
                  data: (code) => Row(
                    children: <Widget>[
                      Expanded(
                        child: SelectableText(
                          code,
                          style: const TextStyle(
                            fontSize: 15,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '复制',
                        icon: const Icon(Icons.copy, size: 16),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: code));
                          if (c.mounted) {
                            ScaffoldMessenger.of(c).showSnackBar(
                              const SnackBar(content: Text('已复制设备码')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 12, height: 1.4),
              decoration: const InputDecoration(
                labelText: '激活码',
                hintText: '粘贴生成器给的激活码',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () async {
            final r = await activateAi(ref, codeCtrl.text);
            if (!ctx.mounted) return;
            if (r.ok) {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('已激活')),
              );
            } else {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text(r.message)),
              );
            }
          },
          child: const Text('激活'),
        ),
      ],
    ),
  );
}
