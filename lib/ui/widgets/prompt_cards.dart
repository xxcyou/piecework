import 'package:flutter/material.dart';

/// 一个提问场景
class PromptScene {
  const PromptScene({
    required this.icon,
    required this.title,
    required this.color,
    required this.questions,
  });

  final IconData icon;
  final String title;
  final Color color;
  final List<String> questions;
}

/// 场景化提问卡片。
///
/// 空对话时摆出来，点一下就直接把问题发出去 —— 比让用户自己想怎么问有效得多。
class PromptCards extends StatelessWidget {
  const PromptCards({
    super.key,
    required this.onPick,
    this.enabled = true,
  });

  final ValueChanged<String> onPick;
  final bool enabled;

  static const List<PromptScene> scenes = <PromptScene>[
    PromptScene(
      icon: Icons.insights_outlined,
      title: '查数据',
      color: Color(0xFF2E6BFF),
      questions: <String>[
        '本周一共做了多少件？',
        '这个月的总工钱是多少？',
        '哪个型号做得最多？',
      ],
    ),
    PromptScene(
      icon: Icons.search,
      title: '找记录',
      color: Color(0xFF0E9F6E),
      questions: <String>[
        '找出没拍照片的记录',
        '上周 A1023 的所有记录',
        '数量超过 50 件的记录',
      ],
    ),
    PromptScene(
      icon: Icons.edit_note,
      title: '改数据',
      color: Color(0xFFE02424),
      questions: <String>[
        '把这批记录的单价统一改成 12.5',
        '删掉重复录入的那些',
        '帮我补录今天的：A1023 黑色 M 码 30 件，单价 12',
      ],
    ),
    PromptScene(
      icon: Icons.tune,
      title: '改设置',
      color: Color(0xFF7E3AF2),
      questions: <String>[
        '把主题换成暗色',
        '设置 100 片 = 30 件',
        '报表改成按型号分组、紧凑版',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCol = constraints.maxWidth > 340;
        final cardWidth = twoCol
            ? (constraints.maxWidth - 10) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            for (final s in scenes)
              SizedBox(
                width: cardWidth,
                child: _SceneCard(scene: s, onPick: onPick, enabled: enabled),
              ),
          ],
        );
      },
    );
  }
}

class _SceneCard extends StatelessWidget {
  const _SceneCard({
    required this.scene,
    required this.onPick,
    required this.enabled,
  });

  final PromptScene scene;
  final ValueChanged<String> onPick;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 9),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1E24) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scene.color.withAlpha(60)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: scene.color.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: scene.color.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(scene.icon, size: 15, color: scene.color),
              ),
              const SizedBox(width: 7),
              Text(
                scene.title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final q in scene.questions)
            InkWell(
              onTap: enabled ? () => onPick(q) : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Container(
                        width: 3.5,
                        height: 3.5,
                        decoration: BoxDecoration(
                          color: scene.color.withAlpha(150),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        q,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.45,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
