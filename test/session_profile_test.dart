import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/data/models/chat_session.dart';
import 'package:piecework/data/repositories/chat_repository.dart';

/// 会话按身份隔离：换身份就只看到那个身份的对话
void main() {
  ChatSession s(int id, int profileId, String title) => ChatSession()
    ..id = id
    ..profileId = profileId
    ..title = title
    ..createdAt = DateTime(2026, 11, 25)
    ..updatedAt = DateTime(2026, 11, 25);

  final all = <ChatSession>[
    s(1, 1, '我的对话'),
    s(2, 7, '张三的对话'),
    s(3, 0, '老版本没打标的'),
  ];

  test('身份 1 只看到自己的', () {
    final got = filterSessionsForProfile(all, 1, activeIsDefault: false);
    expect(got.map((e) => e.title), <String>['我的对话']);
  });

  test('身份 7 只看到自己的', () {
    final got = filterSessionsForProfile(all, 7, activeIsDefault: false);
    expect(got.map((e) => e.title), <String>['张三的对话']);
  });

  test('默认身份额外能看到没打标的老会话', () {
    final got = filterSessionsForProfile(all, 1, activeIsDefault: true);
    expect(got.map((e) => e.title), <String>['我的对话', '老版本没打标的']);
  });

  test('没打标的老会话只归「默认身份」这一侧（activeIsDefault 才带出）', () {
    // 当前身份不是默认身份 → activeIsDefault=false → 看不到老会话
    final got = filterSessionsForProfile(all, 7, activeIsDefault: false);
    expect(got.map((e) => e.title), <String>['张三的对话']);
    expect(got.any((e) => e.title == '老版本没打标的'), isFalse);
  });

  test('没有会话时不炸', () {
    expect(
      filterSessionsForProfile(const <ChatSession>[], 7, activeIsDefault: false),
      isEmpty,
    );
  });

  test('还没初始化身份（0）时不过滤', () {
    expect(filterSessionsForProfile(all, 0, activeIsDefault: false).length, 3);
  });
}
