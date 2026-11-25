import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/data/models/piece_record.dart';

/// 新建记录必须打上当前身份，否则会被身份过滤掉（看起来像「保存没生效」）
void main() {
  test('PieceRecord 默认 profileId 是 0（未打标）', () {
    expect(PieceRecord().profileId, 0);
  });

  test('复制一条记录会带上目标身份', () {
    final src = PieceRecord()
      ..profileId = 1
      ..styleModel = 'A1'
      ..quantity = 100;
    // 模拟「复制」：新建对象，改成目标身份
    final copy = PieceRecord()
      ..profileId = 7
      ..styleModel = src.styleModel
      ..quantity = src.quantity;
    expect(copy.profileId, 7);
    expect(copy.styleModel, 'A1');
    expect(src.profileId, 1); // 原记录不动
  });
}
