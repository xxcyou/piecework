import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/data/services/ai_tool_types.dart';

/// 计划没做完 → 确认卡片后要能自动续跑
void main() {
  AgentTask task({bool done = false, int steps = 3}) => AgentTask(
        goal: '把今天的货记进去',
        steps: <AgentStep>[
          for (var i = 0; i < steps; i++)
            AgentStep(id: 's$i', title: '第 $i 步')
              ..status = i == 0 ? AgentStepStatus.done : AgentStepStatus.pending,
        ],
        done: done,
      );

  Map<String, dynamic> toolsJson(AgentTask? t) => <String, dynamic>{
        if (t != null) 'task': t.toJson(),
      };

  test('task 序列化后能读回，done=false 说明还没做完', () {
    final raw = jsonDecode(jsonEncode(toolsJson(task()))) as Map<String, dynamic>;
    final back = AgentTask.fromJson(raw['task']);
    expect(back, isNotNull);
    expect(back!.done, isFalse);
    expect(back.goal, '把今天的货记进去');
    expect(back.steps.length, 3);
  });

  test('done=true 的任务不该再续跑', () {
    final raw = jsonDecode(jsonEncode(toolsJson(task(done: true))))
        as Map<String, dynamic>;
    final back = AgentTask.fromJson(raw['task'])!;
    expect(back.done, isTrue);
  });

  test('没有 task 的消息不触发续跑', () {
    final raw = jsonDecode(jsonEncode(toolsJson(null))) as Map<String, dynamic>;
    expect(AgentTask.fromJson(raw['task']), isNull);
  });

  test('进度能反映到「做完了没」', () {
    final t = task();
    expect(t.doneCount, 1);
    expect(t.progress, closeTo(1 / 3, 0.01));
  });
}
