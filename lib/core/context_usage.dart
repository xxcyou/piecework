/// 上下文用量估算与展示。
///
/// 不引第三方 tokenizer（几百 KB 且要跟模型对齐），用字符规则粗估：
/// 中文 1 字 ≈ 1 token，英文/数字 4 字符 ≈ 1 token。
/// 误差在 ±15% 以内，用来判断「该不该压缩」足够。
class ContextUsage {
  const ContextUsage({
    required this.usedTokens,
    required this.windowTokens,
    required this.messageCount,
    this.compactedCount = 0,
  });

  /// 已用 token（估算）
  final int usedTokens;

  /// 上下文窗口大小（设置里可改）
  final int windowTokens;

  final int messageCount;

  /// 已压缩掉的早期消息条数
  final int compactedCount;

  double get ratio =>
      windowTokens <= 0 ? 0 : (usedTokens / windowTokens).clamp(0.0, 1.0);

  /// 超过 70% 就该压缩了
  bool get shouldCompact => ratio >= 0.7;

  /// 超过 90% 属于危险区
  bool get isCritical => ratio >= 0.9;

  String get label =>
      '${formatTokens(usedTokens)} / ${formatTokens(windowTokens)}';

  String get percentLabel => '${(ratio * 100).round()}%';

  /// 自动换算单位：<1000 原样，<1M 用 k，≥1M 用 M
  static String formatTokens(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(2)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  /// 粗略估算一段文本的 token 数
  static int estimateTokens(String text) {
    if (text.isEmpty) return 0;
    var cjk = 0;
    var other = 0;
    for (final r in text.runes) {
      // CJK 统一表意文字 + 扩展 A + 常用标点
      if ((r >= 0x4E00 && r <= 0x9FFF) ||
          (r >= 0x3400 && r <= 0x4DBF) ||
          (r >= 0x3000 && r <= 0x303F) ||
          (r >= 0xFF00 && r <= 0xFFEF)) {
        cjk++;
      } else {
        other++;
      }
    }
    return cjk + (other / 4).ceil();
  }
}
