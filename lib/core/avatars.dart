import 'package:flutter/widgets.dart';

/// 身份卡可选头像（emoji）。空字符串 = 用名字首字。
const List<String> kProfileAvatars = <String>[
  '👷', '🧑‍🏭', '👩‍🏭', '🧑‍🌾', '👨‍🔧', '👩‍🔧',
  '🧵', '🧶', '📦', '📋', '🔧', '🛠️',
  '🐱', '🐶', '🦊', '🐼', '🐯', '🐻',
  '🌟', '🔥', '🍀', '🎯', '⚡', '💼',
];

/// 没有头像时的兜底：取名字第一个字符
String avatarFallback(String name) {
  final n = name.trim();
  if (n.isEmpty) return '?';
  return n.characters.first;
}
