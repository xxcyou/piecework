import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/tutorials.dart';
import 'onboarding_page.dart';

/// 教程关卡列表：点哪条就跳到对应页面，用聚光灯一步步指路。
///
/// 只列「必须会」+「最常用」，其他设置项让用户自己摸。
class TutorialsPage extends ConsumerWidget {
  const TutorialsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('新手教程')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          Text(
            '跟着点亮的地方点一遍就行，随时可以跳过。'
            '带「必做」标记的是防丢数据的关键步骤。',
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          for (final t in tutorials) ...<Widget>[
            _card(context, ref, t, scheme),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          Center(
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const OnboardingPage()),
              ),
              icon: const Icon(Icons.slideshow_outlined, size: 16),
              label: const Text('重看欢迎引导', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(
    BuildContext context,
    WidgetRef ref,
    Tutorial t,
    ColorScheme scheme,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1B1E24)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: t.required
              ? scheme.primary.withAlpha(110)
              : scheme.outlineVariant.withAlpha(140),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(t.icon, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.title,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
              ),
              if (t.required)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: scheme.primary.withAlpha(26),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '必做',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            t.desc,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.55,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              // 把选中的教程带回上一页执行：
              // 这里 pop 之后本页 context 就失效了，不能在本页起引导
              onPressed: () => Navigator.of(context).pop<Tutorial>(t),
              icon: const Icon(Icons.play_arrow_rounded, size: 17),
              label: Text('${t.steps.length} 步 · 开始'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
