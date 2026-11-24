import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/db_providers.dart';
import '../widgets/secure_backup_card.dart';

/// 首次启动的引导（4 步，不能一路跳过）。
///
/// 顺序是刻意的：**先保住数据，再谈功能**。
/// 1. 欢迎
/// 2. 数据安全（加密自动备份，真实卡片，能直接授权文件夹/设密码）
/// 3. 身份卡（我叫什么，可选再加一个人）
/// 4. 开始
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _ctrl = PageController();
  final TextEditingController _nameCtrl = TextEditingController(text: '我');
  final TextEditingController _mateCtrl = TextEditingController();
  int _page = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    _nameCtrl.dispose();
    _mateCtrl.dispose();
    super.dispose();
  }

  void _go(int page) {
    setState(() => _page = page);
    _ctrl.animateToPage(
      page,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    // 1) 身份卡名字（默认身份直接改名）
    final repo = ref.read(profileRepoProvider);
    final list = await repo.all(includeArchived: true);
    final def = list.where((p) => p.isDefault).firstOrNull ?? list.firstOrNull;
    final name = _nameCtrl.text.trim();
    if (def != null && name.isNotEmpty && name != def.name) {
      def.name = name;
      await repo.update(def);
    }
    // 2) 可选：再加一个人
    final mate = _mateCtrl.text.trim();
    if (mate.isNotEmpty) {
      await repo.create(mate);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // 步骤指示
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: <Widget>[
                  for (var i = 0; i < 4; i++)
                    Expanded(
                      child: Container(
                        height: 3,
                        margin: EdgeInsets.only(right: i == 3 ? 0 : 5),
                        decoration: BoxDecoration(
                          color: i <= _page
                              ? scheme.primary
                              : scheme.outlineVariant.withAlpha(120),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _ctrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: <Widget>[
                  _welcome(scheme),
                  _backupStep(scheme),
                  _profileStep(scheme),
                  _doneStep(scheme),
                ],
              ),
            ),
            // 底部按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
              child: Row(
                children: <Widget>[
                  if (_page > 0)
                    TextButton(
                      onPressed: () => _go(_page - 1),
                      child: const Text('上一步'),
                    )
                  else
                    const SizedBox(width: 8),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      if (_page == 3) {
                        _finish();
                      } else {
                        _go(_page + 1);
                      }
                    },
                    child: Text(
                      switch (_page) {
                        0 => '开始',
                        1 => '好了，下一步',
                        2 => '下一步',
                        _ => '开始计件',
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 1. 欢迎 ──
  Widget _welcome(ColorScheme scheme) => ListView(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 12),
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primary.withAlpha(22),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.inventory_2_outlined,
                size: 32, color: scheme.primary),
          ),
          const SizedBox(height: 18),
          const Text('计件助手',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('记件数、算工钱、出报表，数据只存本机。',
              style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: scheme.onSurfaceVariant)),
          const SizedBox(height: 26),
          for (final e in <(IconData, String, String)>[
            (Icons.shield_outlined, '数据先保住', '先花 1 分钟设好加密备份，换机重装都能恢复'),
            (Icons.add_a_photo_outlined, '一条记录一张图', '拍下货物，型号颜色码数数量单价记清楚'),
            (Icons.auto_awesome_outlined, '想问就问', '「本周多少件」直接问，AI 查本机数据回答'),
          ]) ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(e.$1, size: 18, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(e.$2,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(e.$3,
                          style: TextStyle(
                              fontSize: 11.5,
                              height: 1.5,
                              color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ],
      );

  // ── 2. 数据安全 ──
  Widget _backupStep(ColorScheme scheme) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        children: <Widget>[
          const Text('先把数据保住',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('设置加密备份后，每改一次数据就自动存一份到手机里，'
              '重装 App 也能恢复。密码自己记住，忘了打不开。',
              style: TextStyle(
                  fontSize: 12, height: 1.6, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          const SecureBackupSection(),
          const SizedBox(height: 10),
          Text('不想现在设也可以，之后在「设置 → 备份」里随时能开。',
              style: TextStyle(
                  fontSize: 10.5, color: scheme.onSurfaceVariant)),
        ],
      );

  // ── 3. 身份卡 ──
  Widget _profileStep(ColorScheme scheme) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        children: <Widget>[
          const Text('你叫什么',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('记录会记在这个名字下。手底下还有人的话，可以再加一个。',
              style: TextStyle(
                  fontSize: 12, height: 1.6, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: '我的名字',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _mateCtrl,
            decoration: const InputDecoration(
              labelText: '再加一个人（可留空）',
              hintText: '例如 张三',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Text('以后在设置 → 身份卡里可以随时增删改。',
              style: TextStyle(
                  fontSize: 10.5, color: scheme.onSurfaceVariant)),
        ],
      );

  // ── 4. 完成 ──
  Widget _doneStep(ColorScheme scheme) => ListView(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 12),
        children: <Widget>[
          Icon(Icons.check_circle_outline, size: 48, color: scheme.primary),
          const SizedBox(height: 14),
          const Text('可以开始记了',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('首页右下角「+」记第一条。\n'
              '想不起来怎么用，就去「设置 → 教程」，点哪条教哪条。',
              style: TextStyle(
                  fontSize: 12.5,
                  height: 1.7,
                  color: scheme.onSurfaceVariant)),
        ],
      );
}
