import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'unit_diagnosis_page.dart';

import '../../data/models/unit_item.dart';
import '../../providers/units_providers.dart';

/// 单位与换算管理。
///
/// 典型场景：裁片按「片」计价，成衣按「件」结算，比例因款而异
/// （100 片 = 50 件，或 100 片 = 30 件）。这里把比例配好，
/// 录入时选「片」，列表和报表会自动折算成基准单位的件数。
class UnitsPage extends ConsumerWidget {
  const UnitsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final cfg = ref.watch(unitsProvider).valueOrNull;

    if (cfg == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('单位与换算')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('单位与换算')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: <Widget>[
          _sectionTitle('计量单位', scheme),
          _card(
            scheme,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '基准单位用于跨单位汇总（报表里的「数量」列）。'
                  '例如按「片」录入，会折算成「件」显示。',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.55,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                for (final u in cfg.units) _unitRow(context, ref, u, cfg, scheme),
                const SizedBox(height: 6),
                _AddUnitField(
                  onAdd: (name) async {
                    final ok =
                        await ref.read(unitsProvider.notifier).addUnit(name);
                    if (!context.mounted) return;
                    if (!ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('「$name」已存在或为空')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          _sectionTitle('换算规则', scheme),
          _card(
            scheme,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '格式：X 个源单位 = Y 个基准单位。'
                  '例如「100 片 = 30 件」。可以只对某个型号生效。',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.55,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                if (cfg.rules.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '还没有换算规则。没配规则的「片」会按 1:1 折算。',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  for (final r in cfg.rules)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.swap_horiz,
                          size: 18, color: scheme.primary),
                      title: Text(
                        r.label,
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        '1 ${r.fromUnit} = ${r.factor.toStringAsFixed(4)} ${r.toUnit}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 17),
                        onPressed: () => ref
                            .read(unitsProvider.notifier)
                            .removeRule(r.id),
                      ),
                    ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _showAddRule(context, ref, cfg),
                  icon: const Icon(Icons.add, size: 17),
                  label: const Text('添加换算规则'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const UnitDiagnosisPage(),
              ),
            ),
            icon: const Icon(Icons.bug_report_outlined, size: 17),
            label: const Text('换算自检（数字对不上时看这里）'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '提示：金额始终按「记录自己的单位 × 该单位单价」计算，'
            '折算只影响数量汇总，不会改变工钱。',
            style: TextStyle(
              fontSize: 11,
              height: 1.6,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _unitRow(
    BuildContext context,
    WidgetRef ref,
    UnitItem u,
    UnitConfig cfg,
    ColorScheme scheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Icon(
            u.isBase ? Icons.star_rounded : Icons.circle_outlined,
            size: 16,
            color: u.isBase ? scheme.primary : scheme.outline,
          ),
          const SizedBox(width: 8),
          Text(u.name, style: const TextStyle(fontSize: 13.5)),
          if (u.isBase) ...<Widget>[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: scheme.primary.withAlpha(28),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '基准',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (!u.isBase) ...<Widget>[
            TextButton(
              onPressed: () =>
                  ref.read(unitsProvider.notifier).setBase(u.name),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 30),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('设为基准', style: TextStyle(fontSize: 11)),
            ),
            IconButton(
              tooltip: '删除',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close, size: 16, color: scheme.onSurfaceVariant),
              onPressed: () =>
                  ref.read(unitsProvider.notifier).removeUnit(u.name),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showAddRule(
    BuildContext context,
    WidgetRef ref,
    UnitConfig cfg,
  ) async {
    final sources = cfg.names.where((n) => n != cfg.baseUnit).toList();
    if (sources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先添加一个非基准单位，例如「片」')),
      );
      return;
    }

    String from = sources.first;
    String to = cfg.baseUnit;
    final denCtrl = TextEditingController(text: '100');
    final numCtrl = TextEditingController(text: '50');
    final styleCtrl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('添加换算规则'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: from,
                        decoration: const InputDecoration(labelText: '源单位'),
                        items: sources
                            .map((s) => DropdownMenuItem<String>(
                                  value: s,
                                  child: Text(s),
                                ))
                            .toList(),
                        onChanged: (v) => setLocal(() => from = v ?? from),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward, size: 16),
                    ),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: to,
                        decoration: const InputDecoration(labelText: '目标单位'),
                        items: cfg.names
                            .map((s) => DropdownMenuItem<String>(
                                  value: s,
                                  child: Text(s),
                                ))
                            .toList(),
                        onChanged: (v) => setLocal(() => to = v ?? to),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: denCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(labelText: '数量（$from）'),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('='),
                    ),
                    Expanded(
                      child: TextField(
                        controller: numCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(labelText: '折算（$to）'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: styleCtrl,
                  decoration: const InputDecoration(
                    labelText: '限定型号（可选）',
                    hintText: '留空 = 全局生效',
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '例：100 $from = 30 $to，表示 1 $from 折算 0.3 $to。'
                  '目标单位不一定是基准单位 —— 也可以配「片 → 打」，系统会自动串成链。',
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.5,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final den = int.tryParse(denCtrl.text.trim()) ?? 0;
      final num = int.tryParse(numCtrl.text.trim()) ?? 0;
      if (den > 0 && num > 0) {
        await ref.read(unitsProvider.notifier).saveRule(
              fromUnit: from,
              toUnit: to,
              numerator: num,
              denominator: den,
              styleModel: styleCtrl.text.trim(),
            );
      }
    }

    denCtrl.dispose();
    numCtrl.dispose();
    styleCtrl.dispose();
  }

  Widget _sectionTitle(String text, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _card(ColorScheme scheme, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: scheme.brightness == Brightness.dark
            ? const Color(0xFF1B1E24)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withAlpha(140)),
      ),
      child: child,
    );
  }
}

class _AddUnitField extends StatefulWidget {
  const _AddUnitField({required this.onAdd});

  final Future<void> Function(String name) onAdd;

  @override
  State<_AddUnitField> createState() => _AddUnitFieldState();
}

class _AddUnitFieldState extends State<_AddUnitField> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: _ctrl,
            decoration: const InputDecoration(
              hintText: '新增单位，例如「套」「条」',
              isDense: true,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(minimumSize: const Size(60, 42)),
          child: const Text('添加'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final v = _ctrl.text.trim();
    if (v.isEmpty) return;
    await widget.onAdd(v);
    if (mounted) _ctrl.clear();
  }
}
