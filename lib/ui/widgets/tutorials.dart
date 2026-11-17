import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/ui_providers.dart';
import '../pages/record_edit_page.dart';
import '../tour_keys.dart';
import 'coach_tour.dart';

/// 一条教程：先跳到对应页面，再用聚光灯一步步指路。
class Tutorial {
  const Tutorial({
    required this.id,
    required this.title,
    required this.desc,
    required this.icon,
    required this.required,
    required this.prepare,
    required this.steps,
  });

  final String id;
  final String title;
  final String desc;
  final IconData icon;

  /// 必做项（备份/恢复）标出来，可选项弱化
  final bool required;

  /// 跳到教程所在的页面
  final Future<void> Function(BuildContext context, WidgetRef ref) prepare;

  final List<CoachStep> steps;
}

/// 只列「必须会」和「最常用」的，其余设置让用户自己摸。
final List<Tutorial> tutorials = <Tutorial>[
  Tutorial(
    id: 'backup',
    title: '开启加密自动备份（必做）',
    desc: '选一个公共文件夹 + 设个密码，之后数据一变就自动加密备份，卸载也不丢。',
    icon: Icons.shield_outlined,
    required: true,
    prepare: (context, ref) async {
      ref.read(tabIndexProvider.notifier).go(3);
      await Future<void>.delayed(const Duration(milliseconds: 400));
    },
    steps: <CoachStep>[
      CoachStep(
        target: TourKeys.backupCard,
        title: '这是唯一的备份通道',
        body: '加密后写到公共目录（/storage/emulated/0/ 下你自己选的文件夹），'
            '卸载 App、换手机、清数据都还在。',
      ),
      CoachStep(
        target: TourKeys.backupFolder,
        title: '第一步：选文件夹',
        body: '点这里会弹出系统的文件夹选择器，选一个你找得到的地方'
            '（比如「下载」里新建一个「计件备份」）。选完要点「允许」，'
            'App 才有写入权限。',
      ),
      CoachStep(
        target: TourKeys.backupPassword,
        title: '第二步：设密码',
        body: '至少 6 位。备份文件用这个密码派生的密钥加密，'
            '被拷走也读不出内容。密码本身不保存 —— 别忘了它，'
            '重装后要靠它才能解开旧备份。',
      ),
      CoachStep(
        target: TourKeys.backupNow,
        title: '第三步：立刻备份一份',
        body: '点一下马上写一份到文件夹里。之后你每次改数据，'
            '25 秒后会自动再写一份，公共目录里最多留 10 份。',
      ),
    ],
  ),
  Tutorial(
    id: 'restore',
    title: '重装 / 换机后恢复（必做）',
    desc: '重装 App 后，从这里选回备份文件夹、输入当初的密码，就能把数据拿回来。',
    icon: Icons.restore,
    required: true,
    prepare: (context, ref) async {
      ref.read(tabIndexProvider.notifier).go(3);
      await Future<void>.delayed(const Duration(milliseconds: 400));
    },
    steps: <CoachStep>[
      CoachStep(
        target: TourKeys.backupRestore,
        title: '重装后就点这里',
        body: '选回当初那个备份文件夹 → 挑一份 .pwb → 输入密码。\n'
            '注意：卸载时系统会收回文件夹授权，所以必须重新选一次文件夹，'
            '这是 Android 的规则，绕不过去。',
      ),
    ],
  ),
  Tutorial(
    id: 'record',
    title: '录入一条记录',
    desc: '拍照留档 → 填型号/颜色/码数/数量/单价 → 保存。',
    icon: Icons.add_a_photo_outlined,
    required: false,
    prepare: (context, ref) async {
      ref.read(tabIndexProvider.notifier).go(0);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const RecordEditPage()),
      );
    },
    steps: <CoachStep>[
      CoachStep(
        target: TourKeys.recordPhoto,
        title: '先拍货物（可跳过）',
        body: '点这里拍货物实拍，方便以后认货/回忆这批是什么。照片只存本机。'
            '忘了拍也能直接保存，之后用筛选里的「缺照片」补拍。',
      ),
      CoachStep(
        target: TourKeys.recordQty,
        title: '数量和单价',
        body: '填数量和单件单价，下面的小计会实时算出来。'
            '单位可以在「片 / 打」之间切，换算规则在设置里配。',
      ),
      CoachStep(
        target: TourKeys.recordSave,
        title: '保存',
        body: '点这里落库。保存后可以在列表里筛选、汇总、导报表。',
      ),
    ],
  ),
  Tutorial(
    id: 'ai',
    title: '让 AI 帮你查账',
    desc: '直接用大白话问：本周多少件、哪个款做得最多、这周比上周怎么样。',
    icon: Icons.auto_awesome,
    required: false,
    prepare: (context, ref) async {
      ref.read(tabIndexProvider.notifier).go(1);
      await Future<void>.delayed(const Duration(milliseconds: 400));
    },
    steps: <CoachStep>[
      CoachStep(
        target: TourKeys.aiInput,
        title: '在这里说话就行',
        body: '比如「本周多少件」「A1023 黑色做了多少」「把上周那批单价改成 0.4」。'
            'AI 会自己查本机数据再回答，不会瞎编数字。',
      ),
      CoachStep(
        target: TourKeys.aiSend,
        title: '发出去',
        body: '改数据的操作会先给你一张确认卡，你点了才真正落库。',
      ),
    ],
  ),
];

Tutorial? tutorialById(String id) {
  for (final t in tutorials) {
    if (t.id == id) return t;
  }
  return null;
}

/// 跑某条教程：先跳页面，再进聚光灯引导
Future<void> runTutorial(
  BuildContext context,
  WidgetRef ref,
  Tutorial tutorial,
) async {
  await tutorial.prepare(context, ref);
  if (!context.mounted) return;
  // 等页面布局稳定，否则量不到目标位置
  await Future<void>.delayed(const Duration(milliseconds: 250));
  if (!context.mounted) return;
  await runCoachTour(context, tutorial.steps);
}

Future<void> runTutorialById(
  BuildContext context,
  WidgetRef ref,
  String id,
) async {
  final t = tutorialById(id);
  if (t == null) return;
  await runTutorial(context, ref, t);
}
