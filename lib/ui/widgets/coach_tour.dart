import 'package:flutter/material.dart';

/// 一步引导：把屏幕压暗，只在 [target] 那个控件上开个洞，旁边浮一张说明卡。
class CoachStep {
  const CoachStep({
    required this.target,
    required this.title,
    required this.body,
  });

  /// 要指的那个控件
  final GlobalKey target;

  final String title;
  final String body;
}

/// 新手引导（聚光灯 + 指路卡片）。
///
/// 交互：点「下一步」自动滚到下一个目标 → 重新测量 → 高亮。
/// 用户随时可以「跳过」。
Future<void> runCoachTour(BuildContext context, List<CoachStep> steps) async {
  if (steps.isEmpty) return;
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    barrierLabel: '新手引导',
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, __, ___) => _CoachOverlay(steps: steps),
  );
}

class _CoachOverlay extends StatefulWidget {
  const _CoachOverlay({required this.steps});

  final List<CoachStep> steps;

  @override
  State<_CoachOverlay> createState() => _CoachOverlayState();
}

class _CoachOverlayState extends State<_CoachOverlay> {
  int _index = 0;
  Rect? _hole;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus(0));
  }

  Future<void> _focus(int i) async {
    if (!mounted) return;
    setState(() {
      _index = i;
      _hole = null;
    });
    final ctx = widget.steps[i].target.currentContext;
    if (ctx != null) {
      // 目标可能在长列表下方，先滚到可见
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 260),
        alignment: 0.35,
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    if (!mounted) return;
    _measure();
  }

  void _measure() {
    final ctx = widget.steps[_index].target.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final topLeft = box.localToGlobal(Offset.zero);
    setState(() => _hole = (topLeft & box.size).inflate(6));
  }

  void _next() {
    if (_index >= widget.steps.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    _focus(_index + 1);
  }

  void _prev() {
    if (_index == 0) return;
    _focus(_index - 1);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final hole = _hole;
    final step = widget.steps[_index];
    final last = _index == widget.steps.length - 1;

    // 说明卡：优先放在洞下方，空间不够就放上方
    const cardWidth = 320.0;
    final maxW = size.width - 32;
    final w = maxW < cardWidth ? maxW : cardWidth;
    double cardTop;
    if (hole == null) {
      cardTop = size.height * 0.35;
    } else {
      final below = hole.bottom + 16;
      cardTop = below + 200 < size.height ? below : hole.top - 200;
      if (cardTop < 80) cardTop = 80;
    }
    final cardLeft = ((size.width - w) / 2).clamp(16.0, size.width);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: <Widget>[
          // 压暗 + 聚光灯
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _SpotlightPainter(hole: hole, color: scheme.primary),
              ),
            ),
          ),
          // 点空白处不做任何事（防误触），只有按钮能推进
          Positioned.fill(child: GestureDetector(onTap: () {})),
          Positioned(
            left: cardLeft,
            top: cardTop,
            width: w,
            child: _Card(
              index: _index,
              total: widget.steps.length,
              step: step,
              last: last,
              onNext: _next,
              onPrev: _prev,
              onSkip: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.index,
    required this.total,
    required this.step,
    required this.last,
    required this.onNext,
    required this.onPrev,
    required this.onSkip,
  });

  final int index;
  final int total;
  final CoachStep step;
  final bool last;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(16),
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.primary.withAlpha(26),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${index + 1}/$total',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    step.title,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              step.body,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.65,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('跳过', style: TextStyle(fontSize: 12)),
                ),
                const Spacer(),
                if (index > 0)
                  TextButton(
                    onPressed: onPrev,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('上一步', style: TextStyle(fontSize: 12)),
                  ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    last ? '开始用' : '下一步',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 整屏压暗，只在目标位置留一个圆角洞，并画一圈描边。
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.hole, required this.color});

  final Rect? hole;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final dim = Paint()..color = Colors.black.withAlpha(178);

    if (hole == null) {
      canvas.drawRect(full, dim);
      return;
    }

    final rrect = RRect.fromRectAndRadius(hole!, const Radius.circular(12));
    canvas.saveLayer(full, Paint());
    canvas.drawRect(full, dim);
    canvas.drawRRect(rrect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    // 洞的描边，让边界更清楚
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.hole != hole || old.color != color;
}
