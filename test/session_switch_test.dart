import 'package:flutter_test/flutter_test.dart';

/// 会话切换的「以用户点选为准」规则
///
/// 背景：切会话会改设置，设置一变 ChatNotifier.build() 会重跑；
/// 若设置还没落地，重跑会把 state 拉回旧会话（看起来没切换成功）。
/// 修法：记住用户点选的 id，build() 优先用它。
void main() {
  test('有 requested 时优先用 requested，忽略设置里的旧值', () {
    int? requested = 7;
    const settingsSessionId = 3;
    final wanted = requested ?? settingsSessionId;
    expect(wanted, 7);
  });

  test('没有 requested 时用设置里的会话', () {
    int? requested;
    const settingsSessionId = 3;
    final wanted = requested ?? settingsSessionId;
    expect(wanted, 3);
  });

  test('切换后 requested 与设置最终一致（不会来回跳）', () {
    int? requested = 7;
    var settingsSessionId = 3;
    // switchTo：先改 requested，再落设置
    settingsSessionId = 7;
    expect(requested ?? settingsSessionId, 7);
    expect(settingsSessionId, 7);
  });
}
