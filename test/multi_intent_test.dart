import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/data/models/pending_action.dart';
import 'package:piecework/data/services/ai_service.dart';
import 'package:piecework/providers/chat_providers.dart';

/// 一条消息里多个需求（改数量 + 关联图 + 查时间）时，
/// 多个写操作必须各自留下确认卡片，不能被「最后一个」覆盖。
void main() {
  PendingAction act(PendingKind kind, List<int> ids) => PendingAction(
        kind: kind,
        description: 'x',
        ids: ids,
      );

  test('多张确认卡片全部保留', () {
    final reply = AiReply(
      text: '好了',
      pendingAction: act(PendingKind.update, <int>[1]),
      pendingActions: <PendingAction>[
        act(PendingKind.update, <int>[1]),
        act(PendingKind.attachPhoto, <int>[2]),
        act(PendingKind.delete, <int>[3]),
      ],
    );
    final actions = actionsOfReply(reply);
    expect(actions.length, 3);
    expect(actions.map((a) => a.kind).toSet(), <PendingKind>{
      PendingKind.update,
      PendingKind.attachPhoto,
      PendingKind.delete,
    });
  });

  test('只有老的单个 pendingAction 时也返回一张', () {
    final reply = AiReply(
      text: '好了',
      pendingAction: act(PendingKind.create, <int>[9]),
    );
    final actions = actionsOfReply(reply);
    expect(actions.length, 1);
    expect(actions.first.kind, PendingKind.create);
  });

  test('没有任何写操作时返回空', () {
    expect(actionsOfReply(const AiReply(text: '查询完成')).length, 0);
  });

  test('提示词明确要求「多个需求全部做完」', () {
    final p = AiService.defaultSystemPrompt;
    expect(p, contains('多个需求'));
    expect(p, contains('逐个调用工具全部做完'));
    expect(p, contains('几张卡片可以同时存在'));
  });
}
