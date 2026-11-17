import 'package:flutter/material.dart';

/// 带历史联想的输入框。
///
/// 用 [RawAutocomplete] 而不是 DropdownButton：
/// * 用户可以自由输入新值（新码数 / 新型号），不受列表限制；
/// * 聚焦或输入时自动弹出历史值，减少重复打字。
class SuggestField extends StatefulWidget {
  const SuggestField({
    super.key,
    required this.controller,
    required this.label,
    required this.options,
    this.hint,
    this.keyboardType,
    this.maxSuggestions = 12,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final List<String> options;
  final String? hint;
  final TextInputType? keyboardType;
  final int maxSuggestions;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final TextCapitalization textCapitalization;

  @override
  State<SuggestField> createState() => _SuggestFieldState();
}

class _SuggestFieldState extends State<SuggestField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (TextEditingValue value) {
        final opts = widget.options;
        if (opts.isEmpty) return const Iterable<String>.empty();
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return opts.take(widget.maxSuggestions);
        return opts
            .where((o) => o.toLowerCase().contains(q))
            .take(widget.maxSuggestions);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: widget.keyboardType,
          textCapitalization: widget.textCapitalization,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            suffixIcon: widget.suffix,
          ),
          onChanged: widget.onChanged,
          onSubmitted: (v) {
            widget.onSubmitted?.call(v);
            onFieldSubmitted();
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF23262E)
                : Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 216, maxWidth: 300),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final option = options.elementAt(i);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      child: Text(
                        option,
                        style: TextStyle(fontSize: 13.5, color: scheme.onSurface),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
