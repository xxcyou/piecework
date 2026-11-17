import 'package:flutter/material.dart';

/// 首次启动的欢迎引导（3 屏）。
///
/// 返回 true 表示用户想「顺便把防丢失备份打开」。
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _ctrl = PageController();
  int _page = 0;

  static const List<_Slide> _slides = <_Slide>[
    _Slide(
      icon: Icons.receipt_long_outlined,
      title: '记一条，算一条',
      body: '拍下货物实拍（方便以后认货），填型号 / 颜色 / 码数 / 数量 / 单价，'
          '工钱自动算好，不用再拿计算器对着单子加。',
    ),
    _Slide(
      icon: Icons.auto_awesome,
      title: '想查什么，直接问',
      body: '「本周多少件」「哪个款做得最多」「这周比上周怎么样」——'
          '用大白话问就行，AI 会查本机数据再回答，不会瞎编数字。',
    ),
    _Slide(
      icon: Icons.shield_outlined,
      title: '数据别丢，开个备份',
      body: '开启加密自动备份后，数据会加密存到你选的公共文件夹。'
          '卸载、换手机、清数据都还在，重装后一键找回。',
    ),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page >= _slides.length - 1) {
      Navigator.of(context).pop(false);
      return;
    }
    _ctrl.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = _page == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('跳过', style: TextStyle(fontSize: 12.5)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: scheme.primary.withAlpha(20),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(s.icon, size: 44, color: scheme.primary),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          s.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          s.body,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.75,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // 小圆点
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? scheme.primary
                          : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(
                children: <Widget>[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(last ? '开始使用' : '下一步'),
                    ),
                  ),
                  if (last) ...<Widget>[
                    const SizedBox(height: 6),
                    TextButton(
                      // 直接带用户去设置备份（返回 true 让上层起引导）
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text(
                        '先帮我把备份打开',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;
}
