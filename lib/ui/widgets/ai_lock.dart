import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/license_providers.dart';

/// AI 未激活时的遮罩：磨砂 + 玻璃卡片
class AiLockOverlay extends ConsumerWidget {
  const AiLockOverlay({super.key, required this.onActivate});

  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            color: scheme.surface.withAlpha(120),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 340),
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
              decoration: BoxDecoration(
                color: scheme.surface.withAlpha(235),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: scheme.outlineVariant.withAlpha(120)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withAlpha(26),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          scheme.primary,
                          scheme.primary.withAlpha(170),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'AI 助手',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '未激活',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final t in const <String>[
                    '用大白话查件数、算工钱',
                    '说一句就帮你记一条',
                    '按型号/颜色/日期出汇总',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.check_circle,
                              size: 15, color: scheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(t,
                                style: const TextStyle(fontSize: 12.5)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onActivate,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('输入激活码'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => showHowToGetDialog(context),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      textStyle: const TextStyle(fontSize: 11.5),
                      foregroundColor: scheme.onSurfaceVariant,
                    ),
                    child: const Text('怎么获取？'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 激活对话框
Future<void> showActivationDialog(BuildContext context, WidgetRef ref) {
  final codeCtrl = TextEditingController();
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      title: const Text('激活 AI 助手', style: TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Consumer(
              builder: (c, r, _) {
                final dev = r.watch(deviceCodeProvider);
                final code = dev.valueOrNull ?? '';
                return Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                  decoration: BoxDecoration(
                    color: Theme.of(c).colorScheme.surfaceContainerHighest
                        .withAlpha(70),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('设备码',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Theme.of(c).colorScheme.onSurfaceVariant,
                                )),
                            const SizedBox(height: 2),
                            SelectableText(
                              code.isEmpty ? '读取中…' : code,
                              style: const TextStyle(
                                fontSize: 15,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '复制设备码',
                        icon: const Icon(Icons.copy_rounded, size: 17),
                        onPressed: code.isEmpty
                            ? null
                            : () async {
                                await Clipboard.setData(
                                    ClipboardData(text: code));
                                if (!c.mounted) return;
                                ScaffoldMessenger.of(c).showSnackBar(
                                  const SnackBar(content: Text('已复制')),
                                );
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
              style: const TextStyle(fontSize: 12, height: 1.45),
              decoration: InputDecoration(
                labelText: '激活码',
                hintText: '粘贴生成器算出的激活码',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: IconButton(
                  tooltip: '粘贴',
                  icon: const Icon(Icons.paste_rounded, size: 17),
                  onPressed: () async {
                    final d = await Clipboard.getData(Clipboard.kTextPlain);
                    if (d?.text != null) codeCtrl.text = d!.text!;
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '激活码只对这台设备有效。',
              style: TextStyle(
                fontSize: 10.5,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
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

/// 「怎么获取」：加微信
Future<void> showHowToGetDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('获取激活码', style: TextStyle(fontSize: 15)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text('扫码加微信，把设备码发过来',
              style: TextStyle(fontSize: 12.5)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset('assets/wechat_qr.png', width: 200),
          ),
        ],
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}
