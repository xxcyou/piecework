import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/date_utils.dart';
import '../../core/format.dart';
import '../../core/money.dart';
import '../models/option_item.dart';
import '../models/operation_log.dart';
import '../models/pending_action.dart';
import '../models/piece_record.dart';
import '../models/record_filter.dart';
import 'ai_tool_types.dart';
import 'linux_env_service.dart';
import 'photo_index_service.dart';
import 'tool_bridge.dart';
import 'query_engine.dart';
import 'terminal_service.dart';
import 'unit_converter.dart';

/// 一次工具调用的产物。
///
/// 除了回给模型的 JSON，还带回 [filter] / [groups]，
/// UI 据此渲染「查看这批记录 →」按钮和统计卡片。
class ToolOutcome {
  const ToolOutcome({
    required this.json,
    this.filter,
    this.groups,
    this.stats,
    this.pendingAction,
    this.trace,
    this.uiActions = const <UiAction>[],
    this.agentTask,
    this.ask,
    this.svg,
    this.calc,
    this.code,
    this.photos = const <Map<String, dynamic>>[],
  });

  final Map<String, dynamic> json;
  final RecordFilter? filter;
  final List<GroupStat>? groups;
  final Map<String, dynamic>? stats;

  /// 写操作的待确认提议（delete / update / create）
  final PendingAction? pendingAction;

  /// 聊天里那张工具卡片的轨迹
  final ToolTrace? trace;

  /// 希望界面执行的动作（跳页 / 应用筛选）
  final List<UiAction> uiActions;

  /// agent 任务状态（计划 / 进度 / 总结）
  final AgentTask? agentTask;

  /// 向用户反问（信息不足时）
  final AskPrompt? ask;

  /// 展示类卡片：SVG 图 / 计算过程 / 代码
  final SvgBlock? svg;
  final CalcTable? calc;
  final CodeBlock? code;

  /// 要展示的图片卡片（show_photos 工具用）
  final List<Map<String, dynamic>> photos;

  ToolOutcome copyWith({
    ToolTrace? trace,
    List<UiAction>? uiActions,
    AgentTask? agentTask,
    AskPrompt? ask,
    SvgBlock? svg,
    CalcTable? calc,
    CodeBlock? code,
    List<Map<String, dynamic>>? photos,
  }) =>
      ToolOutcome(
        json: json,
        filter: filter,
        groups: groups,
        stats: stats,
        pendingAction: pendingAction,
        trace: trace ?? this.trace,
        uiActions: uiActions ?? this.uiActions,
        agentTask: agentTask ?? this.agentTask,
        ask: ask ?? this.ask,
        svg: svg ?? this.svg,
        calc: calc ?? this.calc,
        code: code ?? this.code,
        photos: photos ?? this.photos,
      );
}

/// 修改前 / 修改后的对比数据（确认卡画成对比条）。
///
/// 输入是「会被改到的那几条记录」和「要写的新值」，
/// 输出每行 `{label, before, after, unit, money, perItem}`：
/// * `before/after` 是 num → 卡片画双条形图 + 差值；
/// * 是 String（例如型号）→ 只显示「旧 → 新」。
List<Map<String, dynamic>> buildUpdateDiff(
  List<PieceRecord> recs,
  Map<String, dynamic> changes,
) {
  if (recs.isEmpty) return const <Map<String, dynamic>>[];
  final rows = <Map<String, dynamic>>[];

  num? asNum(Object? v) => v is num ? v : (v is String ? num.tryParse(v) : null);

  /// 所有记录该字段的值都一样吗？一样才直接显示，否则显示「多个值」
  String uniformText(String Function(PieceRecord) pick) {
    final values = recs.map(pick).toSet();
    return values.length == 1 ? values.first : '多个值';
  }

  final qty = asNum(changes['quantity']);
  final price = asNum(changes['unitPrice']);

  // ① 数量：合计 + 每条
  if (qty != null) {
    final oldSum = recs.fold<num>(0, (a, r) => a + r.quantity);
    final newSum = qty * recs.length;
    final units = recs.map((r) => r.unitOrBase).toSet();
    rows.add(<String, dynamic>{
      'label': '数量合计',
      'before': oldSum,
      'after': newSum,
      'unit': units.length == 1 ? units.first : '',
    });
    rows.add(<String, dynamic>{
      'label': '每条数量',
      'before': uniformText((r) => '${r.quantity}'),
      'after': '$qty',
      'perItem': true,
      // 逐条：这条记录原来是多少 → 改成多少（旧值各不相同也能看清）
      'items': <Map<String, dynamic>>[
        for (final r in recs)
          <String, dynamic>{
            'id': r.id,
            'label': _photoRecordLabel(r),
            'before': '${r.quantity}${r.unitOrBase}',
            'after': '$qty${r.unitOrBase}',
          },
      ],
    });
  }

  // ② 单价 + 金额（金额随数量/单价一起变）
  final oldAmount = recs.fold<double>(
    0,
    (a, r) => a + Money.toYuan(r.subtotalMilli),
  );
  if (price != null) {
    final oldPrices = recs.map((r) => r.unitPrice).toSet();
    rows.add(<String, dynamic>{
      'label': '单价',
      'before': oldPrices.length == 1 ? oldPrices.first : '多个值',
      'after': price,
      'money': true,
      'perItem': true,
    });
  }
  if (price != null || qty != null) {
    var newAmount = 0.0;
    for (final r in recs) {
      final q = qty ?? r.quantity;
      final p = price ?? r.unitPrice;
      newAmount += q * p;
    }
    if ((newAmount - oldAmount).abs() > 0.0001) {
      rows.add(<String, dynamic>{
        'label': '金额合计',
        'before': oldAmount,
        'after': double.parse(newAmount.toStringAsFixed(2)),
        'money': true,
        'total': true,
      });
    }
  }

  // ③ 记录时间（只给日期时每条保留原时刻）
  final newDate = changes['date'] as String?;
  final newTime = changes['time'] as String?;
  if (newDate != null || newTime != null) {
    String compose(PieceRecord r) {
      final d = newDate ?? Fmt.date(r.createdAt);
      final t = newTime ?? Fmt.time(r.createdAt);
      return '$d $t';
    }

    rows.add(<String, dynamic>{
      'label': '记录时间',
      'before':
          uniformText((r) => '${Fmt.date(r.createdAt)} ${Fmt.time(r.createdAt)}'),
      'after': newDate != null && newTime != null
          ? '$newDate $newTime'
          : (newDate != null ? '$newDate（保留原时刻）' : '原日期 $newTime'),
      'items': <Map<String, dynamic>>[
        for (final r in recs)
          <String, dynamic>{
            'id': r.id,
            'label': _photoRecordLabel(r),
            'before': '${Fmt.date(r.createdAt)} ${Fmt.time(r.createdAt)}',
            'after': compose(r),
          },
      ],
    });
  }

  // ④ 文字字段
  const textFields = <String, String>{
    'styleModel': '型号',
    'color': '颜色',
    'size': '码数',
    'note': '备注',
    'status': '状态',
  };
  for (final e in textFields.entries) {
    if (!changes.containsKey(e.key)) continue;
    final after = (changes[e.key] ?? '').toString();
    String pickText(PieceRecord r) {
      switch (e.key) {
        case 'styleModel':
          return r.styleModel;
        case 'color':
          return r.color;
        case 'size':
          return r.size;
        case 'note':
          return r.note;
        case 'status':
          return r.status.name;
      }
      return '';
    }

    final before = uniformText(pickText);
    if (before == after) continue;
    rows.add(<String, dynamic>{
      'label': e.value,
      'before': before.isEmpty ? '（空）' : before,
      'after': after.isEmpty ? '（空）' : after,
    });
  }

  return rows;
}

/// 图片变动的前后对比（关联 / 解除关联）。
///
/// 除了「无图 → #1」这种汇总，还会**逐条**列出受影响的记录：
/// 每条记录原来的图、改成哪张图，这样用户能看清「这条记录现在配的是哪张」。
List<Map<String, dynamic>> buildPhotoDiff({
  required List<PieceRecord> records,
  required String afterName,
  required bool detach,
}) {
  final uniq = records
      .map((r) => r.photoName)
      .where((n) => n.isNotEmpty)
      .toSet();

  String beforeLabel;
  String beforeName;
  if (uniq.isEmpty) {
    beforeLabel = '无图';
    beforeName = '';
  } else if (uniq.length == 1) {
    beforeName = uniq.first;
    final id = PhotoIndexService.instance.numberOf(beforeName);
    beforeLabel = id == null ? '有图' : '#$id';
  } else {
    beforeName = '';
    beforeLabel = '多张不同（${uniq.length} 张）';
  }

  String afterLabel;
  if (afterName.isEmpty) {
    afterLabel = '无图';
  } else {
    final id = PhotoIndexService.instance.numberOf(afterName);
    afterLabel = id == null ? '有图' : '#$id';
  }

  // 逐条：这条记录原来是哪张、会变成哪张
  final items = <Map<String, dynamic>>[
    for (final r in records)
      <String, dynamic>{
        'id': r.id,
        'label': _photoRecordLabel(r),
        'photoBefore': r.photoName,
        'photoAfter': afterName,
        'before': PhotoIndexService.instance.numberOf(r.photoName) == null
            ? (r.photoName.isEmpty ? '无图' : '有图')
            : '#${PhotoIndexService.instance.numberOf(r.photoName)}',
        'after': afterLabel,
      },
  ];

  return <Map<String, dynamic>>[
    <String, dynamic>{
      'label': detach ? '解除图片' : '关联图片',
      'before': beforeLabel,
      'after': afterLabel,
      'photoBefore': beforeName,
      'photoAfter': afterName,
      'items': items,
    },
  ];
}

/// 对比列表里每条记录的说明：型号 颜色 码数 · 数量 · 日期
String _photoRecordLabel(PieceRecord r) {
  final parts = <String>[
    if (r.styleModel.isNotEmpty) r.styleModel,
    if (r.color.isNotEmpty) r.color,
    if (r.size.isNotEmpty) r.size,
  ];
  return '${parts.isEmpty ? "（未填型号）" : parts.join(" ")}'
      ' · ${r.quantity}${r.unitOrBase}'
      ' · ${Fmt.date(r.createdAt)}';
}

/// AI 可用的本地工具定义（OpenAI function calling 的 tools 数组）
class AiTools {
  AiTools._();

  /// 所有工具共享的筛选参数
  static const Map<String, dynamic> _filterProps = <String, dynamic>{
    'date_preset': <String, dynamic>{
      'type': 'string',
      'enum': <String>['all', 'today', 'yesterday', 'this_week', 'this_month', 'custom'],
      'description': '快捷时间范围。默认 all。用户说“本周/这个月/今天”时对应填值。',
    },
    'start_date': <String, dynamic>{
      'type': 'string',
      'description': '自定义开始日期 YYYY-MM-DD，仅在 date_preset=custom 时使用',
    },
    'end_date': <String, dynamic>{
      'type': 'string',
      'description': '自定义结束日期 YYYY-MM-DD（含当天）',
    },
    'style_models': <String, dynamic>{
      'type': 'array',
      'items': <String, dynamic>{'type': 'string'},
      'description': '款式型号，多选。留空表示不限。',
    },
    'colors': <String, dynamic>{
      'type': 'array',
      'items': <String, dynamic>{'type': 'string'},
      'description': '颜色，多选。留空表示不限。',
    },
    'sizes': <String, dynamic>{
      'type': 'array',
      'items': <String, dynamic>{'type': 'string'},
      'description': '码数，多选。留空表示不限。',
    },
    'min_quantity': <String, dynamic>{
      'type': 'integer',
      'description': '单条记录数量下限（含）',
    },
    'max_quantity': <String, dynamic>{
      'type': 'integer',
      'description': '单条记录数量上限（含）',
    },
    'status': <String, dynamic>{
      'type': 'string',
      'enum': <String>['pending', 'reported', 'all'],
      'description':
          '上报状态。默认 pending=只查未上报的（用户日常口径）。'
          '用户问「都上报了吗」「已上报的有多少」时用 all 或 reported。',
    },
    'missing': <String, dynamic>{
      'type': 'array',
      'items': <String, dynamic>{
        'type': 'string',
        'enum': <String>['style_model', 'color', 'size', 'price'],
      },
      'description':
          '只查「缺这些字段」的记录（多个条件是「同时都缺」）。'
          '用户说「没填型号的那些」「不知道单价的那批」「只记了件数的」时用。'
          'price=没填单价（unitPrice<=0）。',
    },
    'photo': <String, dynamic>{
      'type': 'string',
      'enum': <String>['any', 'has_photo', 'no_photo'],
      'description':
          '照片条件。any=全部（默认），has_photo=只查有实拍照片的，'
          'no_photo=只查忘记拍照的记录（用户说「没拍照片的那些」时用这个）。',
    },
  };

  /// 所有工具名（终端里生成 @工具名 脚本用）
  static List<String> get toolNames => <String>[
        for (final t in schema)
          if ((t['function'] as Map?)?['name'] is String)
            (t['function'] as Map)['name'] as String,
      ];

  static final List<Map<String, dynamic>> schema = <Map<String, dynamic>>[
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'query_records',
        'description':
            '查询本机计件记录明细。可按时间范围、型号、颜色、码数、数量区间筛选并排序。'
            '返回匹配记录的明细列表，以及记录条数、总件数、总金额。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            ..._filterProps,
            'sort_by': <String, dynamic>{
              'type': 'string',
              'enum': <String>['createdAt', 'quantity', 'amount'],
              'description': '排序字段，默认 createdAt',
            },
            'sort_order': <String, dynamic>{
              'type': 'string',
              'enum': <String>['asc', 'desc'],
              'description': '默认 desc',
            },
            'limit': <String, dynamic>{
              'type': 'integer',
              'description': '返回明细条数上限，默认 30，最大 200',
            },
          },
          'required': <String>[],
        },
      },
    },
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'aggregate_records',
        'description':
            '对本机计件记录做分组汇总。可按型号/颜色/码数/日期/月份分组，'
            '返回每组件数、金额、记录数以及总体合计。不返回逐条明细。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            ..._filterProps,
            'group_by': <String, dynamic>{
              'type': 'string',
              'enum': <String>['none', 'styleModel', 'color', 'size', 'day', 'month'],
              'description': '分组维度。只问总数时填 none。',
            },
          },
          'required': <String>[],
        },
      },
    },
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'list_available_options',
        'description':
            '列出数据库里实际出现过的型号、颜色、码数取值，以及用户维护的可选列表。'
            '当用户提到的型号/颜色写法不确定时先调用它确认。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{},
          'required': <String>[],
        },
      },
    },
    // ───────── 写操作（全部走「先预览、后确认」）─────────
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'delete_records',
        'description':
            '删除匹配条件的计件记录。危险操作：调用后**不会立即删除**，只会返回预览并在界面上生成确认卡片，'
            '必须由用户点「确认删除」才生效。调用前请先用 query_records 确认影响范围，并在 reason 里说明理由。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            ..._filterProps,
            'reason': <String, dynamic>{
              'type': 'string',
              'description': '向用户说明为什么要删这批记录，会显示在确认卡片上',
            },
          },
          'required': <String>['reason'],
        },
      },
    },
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'update_records',
        'description':
            '批量修改匹配记录的字段（统一改单价、补备注、改颜色等）。'
            '同样只返回预览，用户确认后才写库。只传需要修改的字段，没传的保持原值。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            ..._filterProps,
            'set_unit_price': <String, dynamic>{
              'type': 'number',
              'description': '把单件单价统一改成这个值',
            },
            'set_note': <String, dynamic>{
              'type': 'string',
              'description': '把备注统一改成这个内容（传空串表示清空备注）',
            },
            'set_color': <String, dynamic>{'type': 'string'},
            'set_size': <String, dynamic>{'type': 'string'},
            'set_style_model': <String, dynamic>{'type': 'string'},
            'set_quantity': <String, dynamic>{
              'type': 'integer',
              'description': '把数量统一改成这个值（慎用）',
            },
            'set_date': <String, dynamic>{
              'type': 'string',
              'description':
                  '把记录日期改成这一天 YYYY-MM-DD（例如 2026-11-10）。'
                  '只改日期时每条记录原来的时刻保留',
            },
            'set_time': <String, dynamic>{
              'type': 'string',
              'description': '把记录时刻改成 HH:mm（例如 09:30）；配合 set_date 用',
            },
            'set_status': <String, dynamic>{
              'type': 'string',
              'enum': <String>['pending', 'reported'],
              'description': '批量改上报状态。reported=已上报给公司，pending=撤销上报',
            },
            'reason': <String, dynamic>{
              'type': 'string',
              'description': '向用户说明为什么要改',
            },
          },
          'required': <String>['reason'],
        },
      },
    },
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'create_records',
        'description':
            '批量新建计件记录。用户口述「今天 A1023 黑色 M 码 30 件单价 12」时用。'
            '同样返回预览，用户确认后才写入。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'items': <String, dynamic>{
              'type': 'array',
              'description': '要新建的记录列表',
              'items': <String, dynamic>{
                'type': 'object',
                'properties': <String, dynamic>{
                  'style_model': <String, dynamic>{
                    'type': 'string',
                    'description': '款式型号。不知道就留空（用户常常不知道）',
                  },
                  'color': <String, dynamic>{
                    'type': 'string',
                    'description': '颜色。不知道就留空',
                  },
                  'size': <String, dynamic>{
                    'type': 'string',
                    'description': '码数。不知道就留空',
                  },
                  'unit': <String, dynamic>{
                    'type': 'string',
                    'description': '计量单位，例如 件 / 片 / 打。默认「件」。',
                  },
                  'date': <String, dynamic>{
              'type': 'string',
              'description':
                  '记录日期 YYYY-MM-DD（用户说「昨天的」「上周三的」时填；不填=今天）',
            },
            'quantity': <String, dynamic>{'type': 'integer'},
                  'unit_price': <String, dynamic>{
                    'type': 'number',
                    'description':
                        '该单位下的单价，可精确到 0.001（厘）。'
                        '不知道就留空/传 0（表示未计价，等结算后补）。',
                  },
                  'attach_photo': <String, dynamic>{
                    'type': 'boolean',
                    'description':
                        '是否把本次对话里发的照片关联到这条记录。默认 true（有图就自动关联），'
                        '用户明确说「不要图」时才填 false。',
                  },
                  'note': <String, dynamic>{'type': 'string'},
                },
                // 只要求数量：很多师傅只知道自己做了多少件，
                // 型号/颜色/码数/单价都可能不知道，留空即可
                'required': <String>['quantity'],
              },
            },
            'reason': <String, dynamic>{'type': 'string'},
          },
          'required': <String>['items'],
        },
      },
    },
    // ───────── 设置 / 单位 / 导航（AI 对 App 的掌控面）─────────
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'get_settings',
        'description': '读取当前 App 设置：主题、报表标题/字号/模板/分组、默认单价、单位列表与换算规则。'
            '用户问「现在是什么主题」「换算配了吗」时用。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{},
          'required': <String>[],
        },
      },
    },
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'update_settings',
        'description': '修改 App 设置（立即生效，不需要确认）。只传要改的项。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'theme': <String, dynamic>{
              'type': 'string',
              'enum': <String>['system', 'light', 'dark'],
              'description': '主题模式',
            },
            'report_title': <String, dynamic>{
              'type': 'string',
              'description': '报表标题',
            },
            'report_font_scale': <String, dynamic>{
              'type': 'number',
              'description': '报表字号缩放 0.7~1.8',
            },
            'report_template': <String, dynamic>{
              'type': 'string',
              'enum': <String>['external', 'compact'],
              'description': 'external=对外版（带缩略图），compact=自用紧凑版',
            },
            'report_group': <String, dynamic>{
              'type': 'string',
              'enum': <String>['day', 'styleModel', 'none'],
              'description': '报表分组方式',
            },
            'default_unit_price': <String, dynamic>{
              'type': 'number',
              'description': '新增记录时预填的单价',
            },
          },
          'required': <String>[],
        },
      },
    },
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'manage_options',
        'description': '增删「型号 / 颜色 / 码数」的可选列表项。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'action': <String, dynamic>{
              'type': 'string',
              'enum': <String>['add', 'remove'],
            },
            'kind': <String, dynamic>{
              'type': 'string',
              'enum': <String>['styleModel', 'color', 'size'],
            },
            'value': <String, dynamic>{'type': 'string'},
          },
          'required': <String>['action', 'kind', 'value'],
        },
      },
    },
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'manage_units',
        'description': '增删计量单位，或切换基准单位（件/片/打…）。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'action': <String, dynamic>{
              'type': 'string',
              'enum': <String>['add', 'remove', 'set_base'],
            },
            'name': <String, dynamic>{'type': 'string'},
          },
          'required': <String>['action', 'name'],
        },
      },
    },
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'set_unit_rule',
        'description': '配置单位换算规则，例如「100 片 = 30 件」。配好后录入「片」会自动折算成基准单位。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'from_unit': <String, dynamic>{'type': 'string', 'description': '源单位，例如 片'},
            'to_unit': <String, dynamic>{'type': 'string', 'description': '目标单位，通常填基准单位'},
            'numerator': <String, dynamic>{'type': 'integer', 'description': '折算后数量 Y'},
            'denominator': <String, dynamic>{'type': 'integer', 'description': '折算前数量 X'},
            'style_model': <String, dynamic>{
              'type': 'string',
              'description': '限定型号，留空=全局',
            },
          },
          'required': <String>['from_unit', 'to_unit', 'numerator', 'denominator'],
        },
      },
    },
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'apply_filter',
        'description': '把一组筛选条件应用到记录页并跳过去。用户说「帮我把这批调出来」时用。'
            '返回后界面上会出现「查看这批记录」按钮。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{..._filterProps},
          'required': <String>[],
        },
      },
    },
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'compare_periods',
        'description': '对比两个时间段的件数与金额（例如本周 vs 上周），给出增减。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'period_a': <String, dynamic>{
              'type': 'string',
              'enum': <String>['today', 'yesterday', 'this_week', 'last_week', 'this_month', 'last_month'],
              'description': '对比基准期',
            },
            'period_b': <String, dynamic>{
              'type': 'string',
              'enum': <String>['today', 'yesterday', 'this_week', 'last_week', 'this_month', 'last_month'],
              'description': '对比对象期',
            },
          },
          'required': <String>['period_a', 'period_b'],
        },
      },
    },
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'top_n',
        'description': '排行榜：按型号/颜色/码数，按件数或金额排序取前 N。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'dimension': <String, dynamic>{
              'type': 'string',
              'enum': <String>['styleModel', 'color', 'size'],
            },
            'metric': <String, dynamic>{
              'type': 'string',
              'enum': <String>['quantity', 'amount'],
            },
            'limit': <String, dynamic>{'type': 'integer', 'description': '默认 5'},
            ..._filterProps,
          },
          'required': <String>['dimension'],
        },
      },
    },
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'open_page',
        'description': '打开 App 的某个页面：records=记录、chat=AI、report=报表、settings=设置、'
            'units=单位与换算、options=选项管理。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'page': <String, dynamic>{
              'type': 'string',
              'enum': <String>['records', 'chat', 'report', 'settings', 'units', 'options'],
            },
          },
          'required': <String>['page'],
        },
      },
    },
    // ───────── Agent 执行协议 ─────────
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'plan_task',
        'description':
            '任务需要多步时，先声明执行计划（2~6 步），用户会在界面上看到进度。'
            '简单问题（一句 query_records 能答完的）不要用这个。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'goal': <String, dynamic>{
              'type': 'string',
              'description': '用一句话说清要达成的目标',
            },
            'steps': <String, dynamic>{
              'type': 'array',
              'description': '2~6 个步骤，按执行顺序',
              'items': <String, dynamic>{
                'type': 'object',
                'properties': <String, dynamic>{
                  'id': <String, dynamic>{
                    'type': 'string',
                    'description': '短 id，例如 s1',
                  },
                  'title': <String, dynamic>{
                    'type': 'string',
                    'description': '这一步做什么，10 字以内',
                  },
                },
                'required': <String>['id', 'title'],
              },
            },
          },
          'required': <String>['goal', 'steps'],
        },
      },
    },
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'step_done',
        'description': '标记计划里的某一步完成，并记录结果摘要。每完成一步都要调一次。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'step_id': <String, dynamic>{'type': 'string'},
            'result': <String, dynamic>{
              'type': 'string',
              'description': '结果摘要，例如「42 条 · 1,280 件 · ¥15,360.00」',
            },
          },
          'required': <String>['step_id', 'result'],
        },
      },
    },
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'finish_task',
        'description': '任务全部完成时调用：给一句话总结 + 2~3 个后续可问的问题。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'summary': <String, dynamic>{
              'type': 'string',
              'description': '一句话总结这次做了什么、结论是什么',
            },
            'followups': <String, dynamic>{
              'type': 'array',
              'items': <String, dynamic>{'type': 'string'},
              'description': '2~3 个用户可能想接着问的问题',
            },
          },
          'required': <String>['summary'],
        },
      },
    },
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'manage_photos',
        'description':
            '给记录关联照片，或解除照片关联。'
            '**关联的图不必重新上传**：可以指定图库编号（photo_id，#1 就传 1）、'
            '图片文件名（photo_name），或者干脆用本次对话里刚发的那张（都不传时）。'
            '不确定有哪些图时，先用 action=list 或 show_photos 查编号。'
            'detach 只解除关联；照片文件只有在没有任何记录再引用时才会被删除，都需要用户确认。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'action': <String, dynamic>{
              'type': 'string',
              'enum': <String>['attach', 'detach', 'list'],
              'description':
                  'attach=关联图片（photo_id/photo_name 指定，或本次对话的图）；'
                  'detach=解除关联；list=列出图库里的图片和编号',
            },
            'photo_id': <String, dynamic>{
              'type': 'integer',
              'description': '图库编号（#1 传 1）。用它把「已存在的图」关联到别的记录，不用重新上传',
            },
            'photo_name': <String, dynamic>{
              'type': 'string',
              'description': '图片文件名（例如 c3f9a....jpg），photo_id 的替代写法',
            },
            ..._filterProps,
          },
          'required': <String>['action'],
        },
      },
    },
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'ask_user',
        'description':
            '信息不足、描述模糊、有多种理解时，**主动向用户提问**，而不是瞎猜或直接拒绝。'
            '一次只问最关键的一个问题。能列出候选答案就列（用户点一下就行）。'
            '例如用户说「记一下今天的」但没说型号/数量/单价 → 先问型号。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'question': <String, dynamic>{
              'type': 'string',
              'description': '要问的问题，一句话，具体。例如「这条记录是什么型号？」',
            },
            'options': <String, dynamic>{
              'type': 'array',
              'items': <String, dynamic>{'type': 'string'},
              'description': '可点选的候选答案（2~6 个）。能从数据库里取到的值优先用真实值。',
            },
            'why': <String, dynamic>{
              'type': 'string',
              'description': '可选：为什么需要这个信息，一句话',
            },
          },
          'required': <String>['question'],
        },
      },
    },
    // ───────── 业务质检 / 历史 / 导出 ─────────
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'explain_conversion',
        'description':
            '逐条列出记录的原始数量、单位、折算值、用的换算规则，用于核对单位换算是否正确。'
            '用户问「这几条到底怎么算的」「件数怎么对不上」时**必须**用这个，'
            '不要自己解释。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{..._filterProps},
          'required': <String>[],
        },
      },
    },
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'find_duplicates',
        'description': '找疑似重复录入的记录（同一天 + 同型号 + 同颜色 + 同码数 + 同数量）。'
            '用户说「是不是录重了」「有没有重复的」时用。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{..._filterProps},
          'required': <String>[],
        },
      },
    },
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'show_photos',
        'description':
            '把本机的货物实拍以**图片卡片**展示给用户。'
            '每张图有编号（#12），可以按编号精确挑，也可以按型号/颜色/码数筛。'
            '用户说「给我看看那张图」「A1023 的图在哪」「哪个是黑色的」时用。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'photo_ids': <String, dynamic>{
              'type': 'array',
              'items': <String, dynamic>{'type': 'integer'},
              'description': '按图片编号挑（#12 就传 12）',
            },
            'style_model': <String, dynamic>{'type': 'string'},
            'color': <String, dynamic>{'type': 'string'},
            'size': <String, dynamic>{'type': 'string'},
            'limit': <String, dynamic>{
              'type': 'integer',
              'description': '最多展示几张，默认 6，最大 20',
            },
          },
          'required': <String>[],
        },
      },
    },
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'run_terminal',
        'description':
            '执行一条 shell 命令，返回 exitCode / stdout / stderr。'
            '默认跑在**内置的 Alpine Linux**（proot）里：有 cat/grep/sed/awk/find/tar/wget，'
            '可以用 apk add 装包；也可以切到 android 跑手机自带的 /system/bin/sh。'
            '用来算数、处理文本、查文件、看环境。'
            '注意：每条命令都是独立进程，工作目录固定 /root，'
            '要换目录就写成 `cd /etc && ls`。'
            '命令以 `@` 开头时直接调用本 App 的 AI 工具：'
            '`@query_records {"date_preset":"this_week"}` 返回工具 JSON；'
            '加管道还能接着用 shell 处理：`@aggregate_records {"group_by":"styleModel"} | head -20`。'
            '输出截断到 8000 字符；'
            '破坏性命令（rm -rf /、pm uninstall、reboot 等）会被拦下。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'command': <String, dynamic>{
              'type': 'string',
              'description': '要执行的命令，例如 ls -l /sdcard/Download | head',
            },
            'timeout_ms': <String, dynamic>{
              'type': 'integer',
              'description': '超时毫秒，默认 15000（linux 环境默认 30000），最大 60000',
            },
            'env': <String, dynamic>{
              'type': 'string',
              'enum': <String>['android', 'linux'],
              'description':
                  '在哪个环境执行。android=手机自带 /system/bin/sh（只能看，工具少）；'
                  'linux=内置的 Alpine Linux（proot，有 busybox 全套、能用 apk 装包），'
                  '默认 linux。首次调用会自动解压环境（1~3 秒）。',
            },
          },
          'required': <String>['command'],
        },
      },
    },
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'check_anomalies',
        'description': '数据体检：缺照片、长期未上报、单价离群、数量异常。'
            '用户问「数据有没有问题」「帮我把关一下」时用。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'stale_days': <String, dynamic>{
              'type': 'integer',
              'description': '未上报超过多少天算异常，默认 7',
            },
          },
          'required': <String>[],
        },
      },
    },
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'list_operations',
        'description': '查最近的操作历史（新增/修改/删除/上报），含是否已撤销。'
            '用户说「我今天改了什么」「刚才那个操作」时用。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'limit': <String, dynamic>{'type': 'integer', 'description': '默认 10'},
          },
          'required': <String>[],
        },
      },
    },
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'undo_operation',
        'description': '撤销某次操作（把数据还原回去）。不传 log_id 时撤销最近一条未撤销的操作。'
            '用户说「撤回刚才那个」「把上一步还原」时用。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'log_id': <String, dynamic>{
              'type': 'integer',
              'description': '要撤销的操作 id（来自 list_operations）',
            },
          },
          'required': <String>[],
        },
      },
    },
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'restore_records',
        'description': '从回收站恢复记录（30 天内删掉的）。可传筛选条件精确挑。'
            '用户说「把删掉的那几条找回来」时用。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            ..._filterProps,
            'all': <String, dynamic>{
              'type': 'boolean',
              'description': 'true = 恢复回收站全部记录',
            },
          },
          'required': <String>[],
        },
      },
    },
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'export_report',
        'description': '打开报表页准备导出（PNG 或 CSV）。AI 不能直接写文件，'
            '会跳转过去让用户点导出。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'format': <String, dynamic>{
              'type': 'string',
              'enum': <String>['png', 'csv'],
            },
            ..._filterProps,
          },
          'required': <String>[],
        },
      },
    },
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'predict_income',
        'description': '按最近的日均收入预估本月总收入。用户问「这个月大概能拿多少」时用。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'lookback_days': <String, dynamic>{
              'type': 'integer',
              'description': '用最近多少天算日均，默认 7',
            },
          },
          'required': <String>[],
        },
      },
    },
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'unit_convert',
        'description': '单位换算计算，例如「100 片等于多少件」。纯计算，不改数据。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'quantity': <String, dynamic>{'type': 'number'},
            'from_unit': <String, dynamic>{'type': 'string'},
            'to_unit': <String, dynamic>{'type': 'string'},
            'style_model': <String, dynamic>{
              'type': 'string',
              'description': '可选：按某个型号的专属换算规则',
            },
          },
          'required': <String>['quantity', 'from_unit', 'to_unit'],
        },
      },
    },
    // ───────── 展示类卡片 ─────────
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'render_svg',
        'description':
            '画一张 SVG 图直接显示在对话里（柱状图/折线图/饼图/对比图都行）。'
            '用于展示趋势、占比、型号对比。'
            'SVG 必须是完整的 `<svg ...>...</svg>`，viewBox 建议 0 0 320 200，'
            '不要用外部图片或脚本。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'title': <String, dynamic>{'type': 'string'},
            'svg': <String, dynamic>{
              'type': 'string',
              'description': '完整 SVG 源码，纯形状/文字/颜色，不要外链',
            },
          },
          'required': <String>['title', 'svg'],
        },
      },
    },
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'show_calculation',
        'description':
            '展示计算过程表：每一步的表达式和结果。'
            '用户质疑数字怎么来的、或者涉及单位折算/求和时，**用它把推导摊开**，'
            '而不是在正文里写一串算式。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'title': <String, dynamic>{'type': 'string'},
            'steps': <String, dynamic>{
              'type': 'array',
              'items': <String, dynamic>{
                'type': 'object',
                'properties': <String, dynamic>{
                  'label': <String, dynamic>{
                    'type': 'string',
                    'description': '这一步在做什么，例如「粉色 4 条折算」',
                  },
                  'expression': <String, dynamic>{
                    'type': 'string',
                    'description': '算式，例如「276 × 4 × 0.5」',
                  },
                  'result': <String, dynamic>{
                    'type': 'string',
                    'description': '结果，例如「552 件」',
                  },
                },
                'required': <String>['label', 'expression', 'result'],
              },
            },
            'conclusion': <String, dynamic>{
              'type': 'string',
              'description': '最后一行结论，例如「合计 826 件」',
            },
          },
          'required': <String>['title', 'steps'],
        },
      },
    },
    <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': 'show_code',
        'description': '展示代码或命令（带语法高亮 + 一键复制），'
            '用于给用户看 SQL、shell 命令、JSON、配置片段。',
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'title': <String, dynamic>{'type': 'string'},
            'language': <String, dynamic>{
              'type': 'string',
              'description': 'sql / bash / json / dart / yaml / text',
            },
            'code': <String, dynamic>{'type': 'string'},
          },
          'required': <String>['title', 'language', 'code'],
        },
      },
    },
  ];
}

/// 工具执行器：把模型给的参数翻译成对本地数据的只读查询。
///
/// 只读 —— 不提供任何写入/删除工具，AI 无法改动你的账。
class AiToolExecutor {
  AiToolExecutor({
    required this.host,
    required this.records,
    required this.options,
    this.contextPhotoName = '',
  });

  /// 能真正操作 App 的宿主（改设置 / 加单位 / 配换算 / 删记录）
  final AiToolHost host;

  /// 全量记录快照（每次提问时由 Provider 传入最新数据）
  final List<PieceRecord> records;

  /// 用户维护的可选列表
  final Map<OptionKind, List<String>> options;

  /// 当前 agent 任务（一次提问内有效）
  AgentTask? _task;

  /// 本次提问附带的图片文件名（chat_photos 下）。
  /// 用户发图说「记一下…」时，新建的记录会自动关联这张图。
  final String contextPhotoName;

  Map<String, List<String>> optionsSnapshot() => <String, List<String>>{
        'styleModels': options[OptionKind.styleModel] ?? const <String>[],
        'colors': options[OptionKind.color] ?? const <String>[],
        'sizes': options[OptionKind.size] ?? const <String>[],
      };

  Future<ToolOutcome> execute(String name, Map<String, dynamic> args) async {
    final sw = Stopwatch()..start();
    final outcome = await _dispatch(name, args);
    sw.stop();
    return outcome.copyWith(
      trace: _buildTrace(name, args, outcome, sw.elapsedMilliseconds),
    );
  }

  Future<ToolOutcome> _dispatch(String name, Map<String, dynamic> args) async {
    switch (name) {
      case 'query_records':
        return _query(args);
      case 'aggregate_records':
        return _aggregate(args);
      case 'list_available_options':
        return _listOptions();
      case 'delete_records':
        return _deletePreview(args);
      case 'update_records':
        return _updatePreview(args);
      case 'create_records':
        return _createPreview(args);
      case 'get_settings':
        return _getSettings();
      case 'update_settings':
        return _updateSettings(args);
      case 'manage_options':
        return _manageOptions(args);
      case 'manage_units':
        return _manageUnits(args);
      case 'set_unit_rule':
        return _setUnitRule(args);
      case 'apply_filter':
        return _applyFilter(args);
      case 'compare_periods':
        return _comparePeriods(args);
      case 'top_n':
        return _topN(args);
      case 'open_page':
        return _openPage(args);
      case 'plan_task':
        return _planTask(args);
      case 'step_done':
        return _stepDone(args);
      case 'finish_task':
        return _finishTask(args);
      case 'manage_photos':
        return _managePhotos(args);
      case 'ask_user':
        return _askUser(args);
      case 'explain_conversion':
        return _explainConversion(args);
      case 'find_duplicates':
        return _findDuplicates(args);
      case 'check_anomalies':
        return _checkAnomalies(args);
      case 'show_photos':
        return _showPhotos(args);
      case 'run_terminal':
        return _runTerminal(args);
      case 'list_operations':
        return _listOperations(args);
      case 'undo_operation':
        return _undoOperation(args);
      case 'restore_records':
        return _restoreRecords(args);
      case 'export_report':
        return _exportReport(args);
      case 'predict_income':
        return _predictIncome(args);
      case 'unit_convert':
        return _unitConvert(args);
      case 'render_svg':
        return _renderSvg(args);
      case 'show_calculation':
        return _showCalculation(args);
      case 'show_code':
        return _showCode(args);
      default:
        return ToolOutcome(
          json: <String, dynamic>{
            'ok': false,
            'error': '未知工具：$name。可用工具：query_records / aggregate_records / '
                'list_available_options / delete_records / update_records / create_records / '
                'get_settings / update_settings / manage_options / manage_units / '
                'set_unit_rule / apply_filter / compare_periods / top_n / open_page / '
                'run_terminal',
          },
        );
    }
  }

  // ───────────────────────── query_records ─────────────────────────

  Future<ToolOutcome> _query(Map<String, dynamic> args) async {
    final filter = _filterFromArgs(args);
    final limit = _clampInt(args['limit'], 12, 1, 200);
    final converter = await _converter();

    final result = QueryEngine.apply(records, filter, converter: converter);
    final sliced = result.records.take(limit).toList();

    final rows = sliced
        .map((r) => <String, dynamic>{
              'date': _dateTime(r.createdAt),
              'styleModel': r.styleModel,
              'color': r.color,
              'size': r.size,
              // 单位必须带上，否则模型分不清「100 片」和「100 件」
              'unit': r.unitOrBase,
              'quantity': r.quantity,
              // 有换算规则时的折算值（无规则时等于 quantity）
              'convertedQuantity': double.parse(
                converter.baseQuantityOf(r).toStringAsFixed(4),
              ),
              'baseUnit': converter.baseUnit,
              'unitPrice': r.unitPrice,
              'amount': Money.toYuan(r.subtotalMilli),
              if (r.note.isNotEmpty) 'note': r.note,
            })
        .toList();

    return ToolOutcome(
      filter: _pin(filter, result.records),
      stats: result.toSummaryJson(),
      json: <String, dynamic>{
        'ok': true,
        'filterSummary': filter.summary,
        // ── 权威数字：回答里只能逐字引用这一块 ──
        'authoritative': <String, dynamic>{
          'recordCount': result.count,
          // 跨单位时 totalQuantity 是裸和，不可用 → 返回 null
          'totalQuantity': result.mixedUnits ? null : result.totalQuantity,
          'totalBaseQuantity': result.totalBaseQuantity,
          'baseUnit': result.baseUnit,
          'mixedUnits': result.mixedUnits,
          'units': result.units.toList(),
          // 直接可念的数量描述（单位 + 折算都写好了，照抄即可）
          'quantityText': result.quantityText,
          'averagePricePerBaseUnit':
              double.parse(result.averagePerBaseUnit.toStringAsFixed(4)),
          'totalAmount': Money.toYuan(result.totalAmountMilli),
          // 有记录没填单价时，totalAmount 只是「已知部分」，不能当成全部工钱
          if (result.amountIsPartial) 'unpricedCount': result.unpricedCount,
          if (result.amountIsPartial)
            'unpricedQuantity': result.unpricedQuantity,
          'note': result.mixedUnits
              ? '这批记录混用了单位（${result.units.join("、")}），'
                  'totalQuantity 不可用！件数只能用 totalBaseQuantity，'
                  '平均单价只能用 averagePricePerBaseUnit。'
              : (result.amountIsPartial
                  ? '回答里出现的所有数字必须逐字引用这里，禁止自行相加。'
                      '注意：有 ${result.unpricedCount} 条没填单价'
                      '（共 ${result.unpricedQuantity} ${result.units.length == 1 ? result.units.first : result.baseUnit}），'
                      'totalAmount 只是已知单价那部分的合计，'
                      '必须明确告诉用户「还有 N 条未计价，金额没算进去」。'
                  : '回答里出现的所有数字必须逐字引用这里，禁止自行相加'),
        },
        'recordCount': result.count,
        'totalQuantity': result.totalQuantity,
        'totalBaseQuantity': result.totalBaseQuantity,
        'quantityText': result.quantityText,
        'mixedUnits': result.mixedUnits,
        'totalAmount': Money.toYuan(result.totalAmountMilli),
        'returnedCount': rows.length,
        'truncated': result.count > rows.length,
        'truncatedNote': result.count > rows.length
            ? '明细只返回了 ${rows.length} 条，但 recordCount / totalQuantity / '
                'totalAmount 是**全量**统计，报总数时用它们，不要用明细条数'
            : null,
        'records': rows,
        'hint': result.isEmpty
            ? '没有任何记录匹配这组条件，请放宽条件或确认型号/颜色/码数写法。'
            : null,
      },
    );
  }

  // ──────────────────────── aggregate_records ──────────────────────

  Future<ToolOutcome> _aggregate(Map<String, dynamic> args) async {
    final filter = _filterFromArgs(args);
    final field = _groupFromArgs(args['group_by']);
    final converter = await _converter();

    final result =
        QueryEngine.apply(records, filter, converter: converter);
    final groups =
        QueryEngine.group(result.records, field, converter: converter);

    return ToolOutcome(
      filter: _pin(filter, result.records),
      groups: groups,
      stats: result.toSummaryJson(),
      json: <String, dynamic>{
        'ok': true,
        'filterSummary': filter.summary,
        'groupBy': field.label,
        // ── 权威数字：各组之和必须等于这里的总计 ──
        'authoritative': <String, dynamic>{
          'recordCount': result.count,
          // 跨单位时 totalQuantity 是裸和，不可用 → 返回 null
          'totalQuantity': result.mixedUnits ? null : result.totalQuantity,
          'totalBaseQuantity': result.totalBaseQuantity,
          'baseUnit': result.baseUnit,
          'mixedUnits': result.mixedUnits,
          'units': result.units.toList(),
          // 直接可念的数量描述（单位 + 折算都写好了，照抄即可）
          'quantityText': result.quantityText,
          'averagePricePerBaseUnit':
              double.parse(result.averagePerBaseUnit.toStringAsFixed(4)),
          'totalAmount': Money.toYuan(result.totalAmountMilli),
          // 有记录没填单价时，totalAmount 只是「已知部分」，不能当成全部工钱
          if (result.amountIsPartial) 'unpricedCount': result.unpricedCount,
          if (result.amountIsPartial)
            'unpricedQuantity': result.unpricedQuantity,
          'note': result.mixedUnits
              ? '这批记录混用了单位（${result.units.join("、")}），'
                  'totalQuantity 不可用！件数只能用 totalBaseQuantity，'
                  '平均单价只能用 averagePricePerBaseUnit。'
              : (result.amountIsPartial
                  ? '回答里出现的所有数字必须逐字引用这里，禁止自行相加。'
                      '注意：有 ${result.unpricedCount} 条没填单价'
                      '（共 ${result.unpricedQuantity} ${result.units.length == 1 ? result.units.first : result.baseUnit}），'
                      'totalAmount 只是已知单价那部分的合计，'
                      '必须明确告诉用户「还有 N 条未计价，金额没算进去」。'
                  : '回答里出现的所有数字必须逐字引用这里，禁止自行相加'),
        },
        'recordCount': result.count,
        'totalQuantity': result.totalQuantity,
        'totalBaseQuantity': result.totalBaseQuantity,
        'quantityText': result.quantityText,
        'mixedUnits': result.mixedUnits,
        'totalAmount': Money.toYuan(result.totalAmountMilli),
        'units': result.units.toList(),
        'baseUnit': result.baseUnit,
        if (result.amountIsPartial) 'unpricedCount': result.unpricedCount,
        if (result.amountIsPartial) 'unpricedQuantity': result.unpricedQuantity,
        'groupCount': groups.length,
        'groups': groups.map((g) => g.toJson()).toList(),
      },
    );
  }

  // ───────────────────── list_available_options ────────────────────

  ToolOutcome _listOptions() {
    final used = QueryEngine.distinctValues(records);
    return ToolOutcome(
      json: <String, dynamic>{
        'ok': true,
        'usedInRecords': used,
        'configuredLists': optionsSnapshot(),
        'note': 'usedInRecords 是实际录入过的值，configuredLists 是设置页维护的可选列表。',
      },
    );
  }

  // ─────────────────────── 写操作：只生成预览 ───────────────────────

  Future<ToolOutcome> _deletePreview(Map<String, dynamic> args) async {
    final filter = _filterFromArgs(args);
    final converter = await _converter();
    final result =
        QueryEngine.apply(records, filter, converter: converter);

    if (result.isEmpty) {
      return ToolOutcome(
        filter: _pin(filter, result.records),
        json: <String, dynamic>{
          'ok': false,
          'error': '没有记录匹配这组条件，删除操作未生成。',
          'filterSummary': filter.summary,
        },
      );
    }

    final reason = (args['reason'] as String?)?.trim() ?? '';
    final action = PendingAction(
      kind: PendingKind.delete,
      description: '删除 ${result.count} 条记录（共 ${result.totalQuantity} 件）'
          '${reason.isEmpty ? '' : ' —— $reason'}',
      ids: result.records.map((r) => r.id).toList(),
      preview: result.records.take(5).map(_recordLine).toList(),
    );

    return ToolOutcome(
      filter: _pin(filter, result.records),
      pendingAction: action,
      stats: result.toSummaryJson(),
      json: <String, dynamic>{
        'ok': true,
        'status': 'pending_user_confirmation',
        'affectedCount': result.count,
        'totalQuantity': result.totalQuantity,
        'totalAmount': Money.toYuan(result.totalAmountMilli),
        'filterSummary': filter.summary,
        'message': '已在界面上生成确认卡片，用户点「确认删除」后才会真正删除。'
            '现在请告诉用户你准备删哪些记录、共多少条，请他确认。',
        'sample': result.records
            .take(8)
            .map((r) => <String, dynamic>{
                  'date': _dateTime(r.createdAt),
                  'styleModel': r.styleModel,
                  'color': r.color,
                  'size': r.size,
                  'quantity': r.quantity,
                })
            .toList(),
      },
    );
  }

  Future<ToolOutcome> _updatePreview(Map<String, dynamic> args) async {
    final filter = _filterFromArgs(args);
    final converter = await _converter();
    final result =
        QueryEngine.apply(records, filter, converter: converter);

    final changes = <String, dynamic>{};
    final price = _optDouble(args['set_unit_price']);
    if (price != null) changes['unitPrice'] = price;
    final qty = _optInt(args['set_quantity']);
    if (qty != null) changes['quantity'] = qty;
    if (args.containsKey('set_note')) {
      changes['note'] = (args['set_note'] as String?) ?? '';
    }
    final color = (args['set_color'] as String?)?.trim();
    if (color != null && color.isNotEmpty) changes['color'] = color;
    final size = (args['set_size'] as String?)?.trim();
    if (size != null && size.isNotEmpty) changes['size'] = size;
    final style = (args['set_style_model'] as String?)?.trim();
    if (style != null && style.isNotEmpty) changes['styleModel'] = style;
    final st = args['set_status'] as String?;
    if (st == 'pending' || st == 'reported') changes['status'] = st;

    // 录入时间也能改：set_date=YYYY-MM-DD（可只改日期，保留每条原来的时刻）
    // 想连时刻一起改就再给 set_time=HH:mm
    final setDate = (args['set_date'] as String?)?.trim() ?? '';
    if (setDate.isNotEmpty) {
      final d = _parseDate(setDate);
      if (d == null) {
        return ToolOutcome(
          filter: _pin(filter, result.records),
          json: <String, dynamic>{
            'ok': false,
            'error': 'set_date 格式不对，要写成 YYYY-MM-DD（例如 2026-11-10）',
          },
        );
      }
      changes['date'] = '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
    }
    final setTime = (args['set_time'] as String?)?.trim() ?? '';
    if (setTime.isNotEmpty) {
      final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(setTime);
      if (m == null) {
        return ToolOutcome(
          filter: _pin(filter, result.records),
          json: <String, dynamic>{
            'ok': false,
            'error': 'set_time 格式不对，要写成 HH:mm（例如 09:30）',
          },
        );
      }
      changes['time'] = '${m.group(1)!.padLeft(2, '0')}:${m.group(2)}';
    }

    if (changes.isEmpty) {
      return ToolOutcome(
        filter: _pin(filter, result.records),
        json: <String, dynamic>{
          'ok': false,
          'error': '没有指定任何要修改的字段（set_unit_price / set_note / set_color / '
              'set_size / set_style_model / set_quantity 至少给一个）。',
        },
      );
    }
    if (result.isEmpty) {
      return ToolOutcome(
        filter: _pin(filter, result.records),
        json: <String, dynamic>{
          'ok': false,
          'error': '没有记录匹配这组条件，修改操作未生成。',
          'filterSummary': filter.summary,
        },
      );
    }

    final reason = (args['reason'] as String?)?.trim() ?? '';
    final desc = changes.entries
        .map((e) => '${_fieldLabel(e.key)}=${e.value}')
        .join('，');

    final action = PendingAction(
      kind: PendingKind.update,
      description: '修改 ${result.count} 条记录：$desc'
          '${reason.isEmpty ? '' : ' —— $reason'}',
      ids: result.records.map((r) => r.id).toList(),
      changes: changes,
      preview: result.records.take(5).map(_recordLine).toList(),
      diff: buildUpdateDiff(result.records, changes),
    );

    return ToolOutcome(
      filter: _pin(filter, result.records),
      pendingAction: action,
      stats: result.toSummaryJson(),
      json: <String, dynamic>{
        'ok': true,
        'status': 'pending_user_confirmation',
        'affectedCount': result.count,
        'filterSummary': filter.summary,
        'changes': changes,
        'diff': action.diff,
        'message': '已在界面上生成确认卡片，用户点「确认修改」后才生效。'
            '现在请告诉用户你准备改什么、影响多少条。',
      },
    );
  }

  ToolOutcome _createPreview(Map<String, dynamic> args) {
    final raw = args['items'];
    final items = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is! Map) continue;
        final m = e.map((k, v) => MapEntry(k.toString(), v));
        final style = (m['style_model'] as String?)?.trim() ?? '';
        final qty = _optInt(m['quantity']) ?? 0;
        // 只有数量是硬要求：型号/颜色/码数/单价都可以不知道
        if (qty <= 0) continue;
        // 用户带图说话时，新记录直接关联这张图（默认开启，除非显式 false）
        final wantPhoto = m['attach_photo'] != false && contextPhotoName.isNotEmpty;
        items.add(<String, dynamic>{
          'styleModel': style,
          'color': (m['color'] as String?)?.trim() ?? '',
          'size': (m['size'] as String?)?.trim() ?? '',
          'unit': (m['unit'] as String?)?.trim() ?? '件',
          'quantity': qty,
          'unitPrice': _optDouble(m['unit_price']) ?? 0.0,
          'note': (m['note'] as String?)?.trim() ?? '',
          'photoName': wantPhoto ? contextPhotoName : '',
          // 用户说「记一条昨天的」时，模型会带 date
          if (_parseDate(m['date']) != null)
            'createdAt': _parseDate(m['date'])!.toIso8601String(),
        });
      }
    }

    if (items.isEmpty) {
      return ToolOutcome(
        json: <String, dynamic>{
          'ok': false,
          'error': 'items 里没有有效记录（每条至少要有 quantity>0；'
              '型号/颜色/码数/单价都可以留空）。',
        },
      );
    }

    final reason = (args['reason'] as String?)?.trim() ?? '';
    final action = PendingAction(
      kind: PendingKind.create,
      description: '新建 ${items.length} 条记录'
          '${reason.isEmpty ? '' : ' —— $reason'}',
      items: items,
    );

    return ToolOutcome(
      pendingAction: action,
      json: <String, dynamic>{
        'ok': true,
        'status': 'pending_user_confirmation',
        'affectedCount': items.length,
        'message': '已在界面上生成确认卡片，用户点「确认新建」后才写入。'
            '现在请把要新建的内容念一遍给用户听。',
        'items': items,
      },
    );
  }

  // ───────────────────── 设置 / 单位 / 导航 ─────────────────────

  Future<ToolOutcome> _getSettings() async {
    final s = await host.loadSettings();
    if (s == null) {
      return ToolOutcome(
        json: <String, dynamic>{'ok': false, 'error': '设置还没初始化'},
      );
    }
    final units = await host.loadUnits();
    final rules = await host.loadUnitRules();
    String base = '件';
    for (final u in units) {
      if (u.isBase) base = u.name;
    }

    return ToolOutcome(
      json: <String, dynamic>{
        'ok': true,
        'theme': <String>['system', 'light', 'dark'][s.themeModeIndex.clamp(0, 2)],
        'reportTitle': s.reportTitle,
        'reportFontScale': s.reportFontScale,
        'reportTemplate': s.reportTemplate == 1 ? 'compact' : 'external',
        'reportGroupBy':
            <String>['day', 'styleModel', 'none'][s.reportGroupBy.clamp(0, 2)],
        'defaultUnitPrice': s.defaultUnitPrice,
        'baseUnit': base,
        'units': units.map((u) => u.name).toList(),
        'unitRules': rules.map((r) => r.label).toList(),
        'aiModel': s.aiModel,
      },
    );
  }

  Future<ToolOutcome> _updateSettings(Map<String, dynamic> args) async {
    final applied = <String, dynamic>{};

    await host.updateSettings((s) {
      final theme = args['theme'] as String?;
      if (theme != null) {
        final idx = <String>['system', 'light', 'dark'].indexOf(theme);
        if (idx >= 0) {
          s.themeModeIndex = idx;
          applied['theme'] = theme;
        }
      }
      final title = args['report_title'] as String?;
      if (title != null && title.trim().isNotEmpty) {
        s.reportTitle = title.trim();
        applied['reportTitle'] = s.reportTitle;
      }
      final scale = _optDouble(args['report_font_scale']);
      if (scale != null) {
        s.reportFontScale = scale.clamp(0.7, 1.8);
        applied['reportFontScale'] = s.reportFontScale;
      }
      final tpl = args['report_template'] as String?;
      if (tpl != null) {
        s.reportTemplate = tpl == 'compact' ? 1 : 0;
        applied['reportTemplate'] = tpl;
      }
      final group = args['report_group'] as String?;
      if (group != null) {
        final idx = <String>['day', 'styleModel', 'none'].indexOf(group);
        if (idx >= 0) {
          s.reportGroupBy = idx;
          applied['reportGroupBy'] = group;
        }
      }
      final price = _optDouble(args['default_unit_price']);
      if (price != null) {
        s.defaultUnitPrice = price;
        applied['defaultUnitPrice'] = price;
      }
    });

    return ToolOutcome(
      json: <String, dynamic>{
        'ok': applied.isNotEmpty,
        'applied': applied,
        'message': applied.isEmpty ? '没有可应用的设置项' : '设置已更新并立即生效',
      },
    );
  }

  Future<ToolOutcome> _manageOptions(Map<String, dynamic> args) async {
    final action = (args['action'] as String?) ?? 'add';
    final kindName = (args['kind'] as String?) ?? '';
    final value = ((args['value'] as String?) ?? '').trim();

    final kind = switch (kindName) {
      'color' => OptionKind.color,
      'size' => OptionKind.size,
      'styleModel' => OptionKind.styleModel,
      _ => null,
    };
    if (kind == null || value.isEmpty) {
      return ToolOutcome(
        json: <String, dynamic>{
          'ok': false,
          'error': 'kind 必须是 styleModel/color/size，value 不能为空',
        },
      );
    }

    if (action == 'remove') {
      await host.removeOption(kind, value);
      return ToolOutcome(
        json: <String, dynamic>{'ok': true, 'removed': value, 'kind': kindName},
      );
    }

    final ok = await host.addOption(kind, value);
    return ToolOutcome(
      json: <String, dynamic>{
        'ok': ok,
        'added': value,
        'kind': kindName,
        'note': ok ? null : '该值已存在',
      },
    );
  }

  Future<ToolOutcome> _manageUnits(Map<String, dynamic> args) async {
    final action = (args['action'] as String?) ?? 'add';
    final name = ((args['name'] as String?) ?? '').trim();
    if (name.isEmpty) {
      return ToolOutcome(
        json: <String, dynamic>{'ok': false, 'error': 'name 不能为空'},
      );
    }

    switch (action) {
      case 'remove':
        await host.removeUnit(name);
        return ToolOutcome(
          json: <String, dynamic>{'ok': true, 'removed': name},
        );
      case 'set_base':
        await host.setBaseUnit(name);
        return ToolOutcome(
          json: <String, dynamic>{'ok': true, 'baseUnit': name},
        );
      default:
        final ok = await host.addUnit(name);
        return ToolOutcome(
          json: <String, dynamic>{
            'ok': ok,
            'added': name,
            'note': ok ? null : '该单位已存在',
          },
        );
    }
  }

  Future<ToolOutcome> _setUnitRule(Map<String, dynamic> args) async {
    final from = ((args['from_unit'] as String?) ?? '').trim();
    final to = ((args['to_unit'] as String?) ?? '').trim();
    final num = _optInt(args['numerator']) ?? 0;
    final den = _optInt(args['denominator']) ?? 0;
    final style = ((args['style_model'] as String?) ?? '').trim();

    if (from.isEmpty || to.isEmpty || num <= 0 || den <= 0) {
      return ToolOutcome(
        json: <String, dynamic>{
          'ok': false,
          'error': 'from_unit/to_unit 不能为空，numerator/denominator 必须大于 0',
        },
      );
    }

    await host.saveUnitRule(
      fromUnit: from,
      toUnit: to,
      numerator: num,
      denominator: den,
      styleModel: style,
    );

    return ToolOutcome(
      json: <String, dynamic>{
        'ok': true,
        'rule': '$den $from = $num $to${style.isEmpty ? '' : '（$style）'}',
        'message': '换算规则已保存，之后录入「$from」会自动折算',
      },
    );
  }

  Future<ToolOutcome> _applyFilter(Map<String, dynamic> args) async {
    final filter = _filterFromArgs(args);
    final converter = await _converter();
    final result =
        QueryEngine.apply(records, filter, converter: converter);

    return ToolOutcome(
      filter: _pin(filter, result.records),
      stats: result.toSummaryJson(),
      uiActions: <UiAction>[
        UiAction(
          kind: UiActionKind.applyFilter,
          filter: _pin(filter, result.records),
          label: '查看这批记录（${result.count} 条）',
        ),
      ],
      json: <String, dynamic>{
        'ok': true,
        'filterSummary': filter.summary,
        'recordCount': result.count,
        'totalQuantity': result.totalQuantity,
        'totalBaseQuantity': result.totalBaseQuantity,
        'quantityText': result.quantityText,
        'mixedUnits': result.mixedUnits,
        'totalAmount': Money.toYuan(result.totalAmountMilli),
        'message': '筛选已准备好，界面上会出现「查看这批记录」按钮。',
      },
    );
  }

  Future<ToolOutcome> _comparePeriods(Map<String, dynamic> args) async {
    final a = _periodRange((args['period_a'] as String?) ?? 'this_week');
    final b = _periodRange((args['period_b'] as String?) ?? 'last_week');

    final converter = await _converter();
    QueryResult run(_Period p) => QueryEngine.apply(
          records,
          RecordFilter(
            quick: QuickRange.custom,
            customStart: p.start,
            customEnd: p.end,
          ),
          converter: converter,
        );

    final ra = run(a);
    final rb = run(b);

    int deltaQty = ra.totalQuantity - rb.totalQuantity;
    int deltaCents = ra.totalAmountMilli - rb.totalAmountMilli;
    final qtyPct = rb.totalQuantity == 0
        ? null
        : (deltaQty / rb.totalQuantity * 100).toStringAsFixed(1);
    final amtPct = rb.totalAmountMilli == 0
        ? null
        : (deltaCents / rb.totalAmountMilli * 100).toStringAsFixed(1);

    return ToolOutcome(
      json: <String, dynamic>{
        'ok': true,
        'authoritative': <String, dynamic>{
          'aMixedUnits': ra.mixedUnits,
          'bMixedUnits': rb.mixedUnits,
          'aBaseQuantity': ra.totalBaseQuantity,
          'bBaseQuantity': rb.totalBaseQuantity,
          'aQuantity': ra.mixedUnits ? null : ra.totalQuantity,
          'aAmount': Money.toYuan(ra.totalAmountMilli),
          'bQuantity': rb.mixedUnits ? null : rb.totalQuantity,
          'bAmount': Money.toYuan(rb.totalAmountMilli),
          'deltaQuantity': deltaQty,
          'deltaAmount': Money.toYuan(deltaCents),
          'note': '回答里出现的所有数字必须逐字引用这里，禁止自行相减',
        },
        'a': <String, dynamic>{
          'period': a.label,
          'recordCount': ra.count,
          'quantity': ra.totalQuantity,
          'amount': Money.toYuan(ra.totalAmountMilli),
        },
        'b': <String, dynamic>{
          'period': b.label,
          'recordCount': rb.count,
          'quantity': rb.totalQuantity,
          'amount': Money.toYuan(rb.totalAmountMilli),
        },
        'delta': <String, dynamic>{
          'quantity': deltaQty,
          'quantityPercent': qtyPct,
          'amount': Money.toYuan(deltaCents),
          'amountPercent': amtPct,
        },
        'message': '${a.label} 比 ${b.label}：件数 ${deltaQty >= 0 ? '+' : ''}$deltaQty'
            '（${qtyPct ?? "—"}%），金额 ${deltaCents >= 0 ? '+' : ''}'
            '${Money.toYuan(deltaCents)}（${amtPct ?? "—"}%）',
      },
    );
  }

  Future<ToolOutcome> _topN(Map<String, dynamic> args) async {
    final filter = _filterFromArgs(args);
    final converter = await _converter();
    final result =
        QueryEngine.apply(records, filter, converter: converter);

    final dim = switch ((args['dimension'] as String?) ?? 'styleModel') {
      'color' => GroupField.color,
      'size' => GroupField.size,
      _ => GroupField.styleModel,
    };
    final byAmount = (args['metric'] as String?) == 'amount';
    final limit = _clampInt(args['limit'], 5, 1, 50);

    final groups = QueryEngine.group(result.records, dim);
    groups.sort((a, b) => byAmount
        ? b.amountMilli.compareTo(a.amountMilli)
        : b.quantity.compareTo(a.quantity));
    final top = groups.take(limit).toList();

    return ToolOutcome(
      filter: _pin(filter, result.records),
      groups: top,
      stats: result.toSummaryJson(),
      json: <String, dynamic>{
        'ok': true,
        'dimension': dim.label,
        'metric': byAmount ? 'amount' : 'quantity',
        'filterSummary': filter.summary,
        'authoritative': <String, dynamic>{
          'recordCount': result.count,
          // 跨单位时 totalQuantity 是裸和，不可用 → 返回 null
          'totalQuantity': result.mixedUnits ? null : result.totalQuantity,
          'totalBaseQuantity': result.totalBaseQuantity,
          'baseUnit': result.baseUnit,
          'mixedUnits': result.mixedUnits,
          'units': result.units.toList(),
          // 直接可念的数量描述（单位 + 折算都写好了，照抄即可）
          'quantityText': result.quantityText,
          'averagePricePerBaseUnit':
              double.parse(result.averagePerBaseUnit.toStringAsFixed(4)),
          'totalAmount': Money.toYuan(result.totalAmountMilli),
          // 有记录没填单价时，totalAmount 只是「已知部分」，不能当成全部工钱
          if (result.amountIsPartial) 'unpricedCount': result.unpricedCount,
          if (result.amountIsPartial)
            'unpricedQuantity': result.unpricedQuantity,
          'note': result.mixedUnits
              ? '这批记录混用了单位（${result.units.join("、")}），'
                  'totalQuantity 不可用！件数只能用 totalBaseQuantity，'
                  '平均单价只能用 averagePricePerBaseUnit。'
              : (result.amountIsPartial
                  ? '回答里出现的所有数字必须逐字引用这里，禁止自行相加。'
                      '注意：有 ${result.unpricedCount} 条没填单价'
                      '（共 ${result.unpricedQuantity} ${result.units.length == 1 ? result.units.first : result.baseUnit}），'
                      'totalAmount 只是已知单价那部分的合计，'
                      '必须明确告诉用户「还有 N 条未计价，金额没算进去」。'
                  : '回答里出现的所有数字必须逐字引用这里，禁止自行相加'),
        },
        'totalQuantity': result.totalQuantity,
        'totalBaseQuantity': result.totalBaseQuantity,
        'mixedUnits': result.mixedUnits,
        'totalAmount': Money.toYuan(result.totalAmountMilli),
        'ranking': <Map<String, dynamic>>[
          for (var i = 0; i < top.length; i++)
            <String, dynamic>{
              'rank': i + 1,
              'key': top[i].key,
              'quantity': top[i].quantity,
              'amount': Money.toYuan(top[i].amountMilli),
              'recordCount': top[i].count,
            },
        ],
      },
    );
  }

  Future<ToolOutcome> _openPage(Map<String, dynamic> args) async {
    final page = (args['page'] as String?) ?? 'records';
    const labels = <String, String>{
      'records': '记录页',
      'chat': 'AI 助手',
      'report': '报表页',
      'settings': '设置',
      'units': '单位与换算',
      'options': '选项管理',
    };
    return ToolOutcome(
      uiActions: <UiAction>[
        UiAction(
          kind: UiActionKind.openPage,
          target: page,
          label: '打开${labels[page] ?? page}',
        ),
      ],
      json: <String, dynamic>{'ok': true, 'opened': page},
    );
  }

  /// 换算器缓存：一次提问内只读一次库
  Future<UnitConverter>? _convFuture;

  Future<UnitConverter> _converter() => _convFuture ??= _loadConverter();

  /// 从当前单位配置构造换算器
  Future<UnitConverter> _loadConverter() async {
    final units = await host.loadUnits();
    final rules = await host.loadUnitRules();
    var base = '件';
    for (final u in units) {
      if (u.isBase) base = u.name;
    }
    return UnitConverter(baseUnit: base, rules: rules);
  }

  // ───────────────────────── 换算核对 ─────────────────────────

  Future<ToolOutcome> _explainConversion(Map<String, dynamic> args) async {
    final filter = _filterFromArgs(args);
    final converter = await _converter();
    final result = QueryEngine.apply(records, filter, converter: converter);

    final rows = result.records.map((r) {
      final unit = r.unitOrBase;
      final per = converter.centiBasePerUnit(
        unit,
        styleModel: r.styleModel,
      );
      return <String, dynamic>{
        'id': r.id,
        'styleModel': r.styleModel,
        'color': r.color,
        'size': r.size,
        'unit': unit,
        'quantity': r.quantity,
        'unitPrice': r.unitPrice,
        // 1 个该单位等于多少基准单位（百分之一）
        'centiPerUnit': per,
        'conversionRule': converter.describe(unit, styleModel: r.styleModel),
        'convertedQuantity': double.parse(
          (r.quantity * per / 100).toStringAsFixed(4),
        ),
        'baseUnit': converter.baseUnit,
        'amount': Money.toYuan(r.subtotalMilli),
      };
    }).toList();

    final sumConverted = result.records.fold<double>(
      0,
      (s, r) =>
          s +
          r.quantity *
              converter.centiBasePerUnit(r.unitOrBase,
                  styleModel: r.styleModel) /
              100,
    );

    return ToolOutcome(
      filter: _pin(filter, result.records),
      stats: result.toSummaryJson(),
      json: <String, dynamic>{
        'ok': true,
        'recordCount': result.count,
        'rawQuantitySum': result.totalQuantity,
        'totalBaseQuantity': result.totalBaseQuantity,
        'recomputedSum': double.parse(sumConverted.toStringAsFixed(4)),
        'consistent':
            (sumConverted - result.totalBaseQuantity).abs() < 0.01,
        'units': result.units.toList(),
        'mixedUnits': result.mixedUnits,
        'totalAmount': Money.toYuan(result.totalAmountMilli),
        'averagePricePerBaseUnit':
            double.parse(result.averagePerBaseUnit.toStringAsFixed(4)),
        'records': rows,
        'message': '逐条列出每条记录怎么折算的。'
            '核对方式：每条 convertedQuantity 之和应等于 totalBaseQuantity，'
            'consistent=true 表示自洽。',
      },
    );
  }

  // ───────────────────────── 业务质检 / 历史 / 导出 ─────────────────────────

  Future<ToolOutcome> _findDuplicates(Map<String, dynamic> args) async {
    final filter = _filterFromArgs(args);
    final converter = await _converter();
    final result =
        QueryEngine.apply(records, filter, converter: converter);

    final map = <String, List<PieceRecord>>{};
    for (final r in result.records) {
      final key = '${r.styleModel}|${r.color}|${r.size}|'
          '${r.quantity}|${Fmt.date(r.createdAt)}';
      (map[key] ??= <PieceRecord>[]).add(r);
    }

    final groups = map.entries.where((e) => e.value.length > 1).toList();
    final total = groups.fold(0, (s, e) => s + e.value.length);

    return ToolOutcome(
      filter: _pin(filter, result.records),
      json: <String, dynamic>{
        'ok': true,
        'duplicateGroups': groups.length,
        'duplicateRecords': total,
        'groups': groups
            .take(10)
            .map((e) => <String, dynamic>{
                  'key': '${e.value.first.styleModel} '
                      '${e.value.first.color} ${e.value.first.size} '
                      '${e.value.first.quantity}件',
                  'date': Fmt.date(e.value.first.createdAt),
                  'count': e.value.length,
                  'ids': e.value.map((r) => r.id).toList(),
                })
            .toList(),
        'hint': groups.isEmpty
            ? '没有发现重复录入。'
            : '共 ${groups.length} 组疑似重复（$total 条）。确认后可以让我删掉多余的。',
      },
    );
  }

  // ───────────────────────── run_terminal ─────────────────────────

  /// 终端里调 AI 工具：`@query_records {...} | grep 型号`
  ///
  /// 没有管道时直接把工具 JSON 还给模型；有管道时把 JSON 落到临时文件，
  /// 再在 shell 里 `cat 文件 | 管道`，这样「取数 → 文本处理」一步完成。
  Future<ToolOutcome> _runToolInTerminal(
    String expr,
    Map<String, dynamic> args,
  ) async {
    final env = (args['env'] as String?)?.trim().toLowerCase() ?? 'linux';
    final useLinux = env != 'android';
    final call = parseToolCommand(expr);

    if (call.name.isEmpty || call.name == 'help' || call.name == 'tools') {
      return ToolOutcome(
        json: <String, dynamic>{
          'ok': true,
          'tools': <String>[
            'query_records',
            'aggregate_records',
            'top_n',
            'compare_periods',
            'list_available_options',
            'check_anomalies',
            'find_duplicates',
            'predict_income',
            'unit_convert',
            'explain_conversion',
            'get_settings',
            'list_operations',
            'create_records',
            'update_records',
            'delete_records',
            'manage_photos',
            'update_settings',
            'set_unit_rule',
            'manage_units',
            'manage_options',
          ],
          'usage': r'run_terminal({"command":"@query_records {"date_preset":"this_week"} | head -20"})',
          'note': '管道部分在 Linux shell 里执行，工具 JSON 在 /tmp/tool_xxx.json',
        },
      );
    }

    if (call.args == null) {
      return ToolOutcome(
        json: <String, dynamic>{
          'ok': false,
          'error': '@${call.name} 的参数必须是 JSON 对象，例如 '
              '@query_records {"date_preset":"this_week"}',
        },
      );
    }
    if (call.name == 'run_terminal') {
      return ToolOutcome(
        json: <String, dynamic>{
          'ok': false,
          'error': '不要用 @run_terminal 套娃：直接调 run_terminal 就行',
        },
      );
    }

    // 真正执行工具（不经过 execute，避免重复记一条 trace）
    final outcome = await _dispatch(call.name, call.args!);
    final toolJson = outcome.json;

    // 没有管道：直接把 JSON 交给模型
    if (call.pipeline.isEmpty) {
      return ToolOutcome(
        pendingAction: outcome.pendingAction,
        filter: outcome.filter,
        groups: outcome.groups,
        stats: outcome.stats,
        json: <String, dynamic>{
          'ok': toolJson['ok'] != false,
          'tool': call.name,
          'result': toolJson,
        },
      );
    }

    // 有管道：写临时文件，让 shell 接着处理
    try {
      // 取不到应用目录时（例如纯 Dart 环境）退回系统临时目录
      Directory docs;
      try {
        docs = await getApplicationDocumentsDirectory();
      } catch (_) {
        docs = Directory.systemTemp;
      }
      final tmpDir = Directory(p.join(docs.path, 'linux', 'tmp'));
      if (!await tmpDir.exists()) await tmpDir.create(recursive: true);
      final name = 'tool_${DateTime.now().microsecondsSinceEpoch}.json';
      final file = File(p.join(tmpDir.path, name));
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(toolJson),
        flush: true,
      );

      // Linux 里 /tmp 就是应用这个 tmp 目录（proot 绑定了）；android 环境用绝对路径
      final path = useLinux ? '/tmp/$name' : file.path;
      final cmd = 'cat $path ${call.pipeline}';
      final result = useLinux
          ? await LinuxEnvService.instance.run(cmd)
          : await TerminalService.instance.run(cmd);

      // 用完删掉，别在用户磁盘上堆垃圾
      try {
        await file.delete();
      } catch (_) {}

      if (result.blocked) {
        return ToolOutcome(
          json: <String, dynamic>{'ok': false, 'error': result.blockedReason},
        );
      }
      return ToolOutcome(
        filter: outcome.filter,
        groups: outcome.groups,
        stats: outcome.stats,
        json: <String, dynamic>{
          'ok': result.exitCode == 0,
          'tool': call.name,
          'toolOk': toolJson['ok'] != false,
          'pipeline': call.pipeline,
          'output': result.stdout,
          if (result.stderr.isNotEmpty) 'stderr': result.stderr,
          if (result.truncated) 'truncated': true,
          'note': 'output 是管道处理后的结果；工具原始 JSON 在 result 里（无管道时才直接返回）',
        },
      );
    } catch (e) {
      return ToolOutcome(
        json: <String, dynamic>{
          'ok': false,
          'error': '工具结果接管道失败：$e',
          'tool': call.name,
          'result': toolJson,
        },
      );
    }
  }

  // ───────────────────────── show_photos ─────────────────────────

  /// 把图片以卡片形式展示（用户能直接看到图，AI 也能用编号精确引用）
  Future<ToolOutcome> _showPhotos(Map<String, dynamic> args) async {
    final limit = _clampInt(args['limit'], 6, 1, 20);
    final style = (args['style_model'] as String?)?.trim() ?? '';
    final color = (args['color'] as String?)?.trim() ?? '';
    final size = (args['size'] as String?)?.trim() ?? '';
    final wantedIds = <int>{
      for (final v in (args['photo_ids'] as List?) ?? const <dynamic>[])
        if (v is num) v.toInt(),
    };

    // 按文件名聚合（一张图可能被多条记录引用，取最新那条做展示信息）
    final byName = <String, PieceRecord>{};
    for (final r in records) {
      if (r.deletedAt != null) continue;
      if (r.photoName.isEmpty) continue;
      if (style.isNotEmpty && r.styleModel != style) continue;
      if (color.isNotEmpty && r.color != color) continue;
      if (size.isNotEmpty && r.size != size) continue;
      final old = byName[r.photoName];
      if (old == null || r.createdAt.isAfter(old.createdAt)) {
        byName[r.photoName] = r;
      }
    }

    // 编号按「最早出现」分配，保证稳定
    final namesByAge = byName.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    await PhotoIndexService.instance
        .ensure(namesByAge.map((r) => r.photoName).toList());

    var picked = byName.values.toList();
    if (wantedIds.isNotEmpty) {
      final wantedNames = <String>{
        for (final id in wantedIds)
          if (PhotoIndexService.instance.nameOf(id) != null)
            PhotoIndexService.instance.nameOf(id)!,
      };
      picked = picked.where((r) => wantedNames.contains(r.photoName)).toList();
      // 编号存在但记录已被删：也要能展示（图还在）
      for (final name in wantedNames) {
        if (picked.any((r) => r.photoName == name)) continue;
        picked.add(PieceRecord()
          ..photoName = name
          ..createdAt = DateTime.now()
          ..styleModel = ''
          ..color = ''
          ..size = ''
          ..unit = '件'
          ..quantity = 0
          ..unitPrice = 0);
      }
    }

    picked.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final shown = picked.take(limit).toList();
    if (shown.isEmpty) {
      return ToolOutcome(
        json: <String, dynamic>{
          'ok': true,
          'count': 0,
          'message': '没有匹配的图片（这条记录可能没拍照，或者筛选条件太窄）',
        },
      );
    }

    final photos = <Map<String, dynamic>>[];
    for (final r in shown) {
      final id = PhotoIndexService.instance.numberOf(r.photoName) ?? 0;
      final refs = records
          .where((x) => x.deletedAt == null && x.photoName == r.photoName)
          .length;
      photos.add(<String, dynamic>{
        'id': id,
        'label': '#$id',
        'name': r.photoName,
        'recordId': r.id,
        'styleModel': r.styleModel,
        'color': r.color,
        'size': r.size,
        'quantity': r.quantity,
        'unit': r.unitOrBase,
        'unitPrice': r.unitPrice,
        'createdAt': _dateTime(r.createdAt),
        'refs': refs,
      });
    }

    return ToolOutcome(
      photos: photos,
      json: <String, dynamic>{
        'ok': true,
        'count': photos.length,
        'photos': photos,
        'note': '图片卡片已经显示给用户了；引用某张图时说编号（例如 #12）即可。',
      },
    );
  }

  Future<ToolOutcome> _runTerminal(Map<String, dynamic> args) async {
    final command = (args['command'] as String?)?.trim() ?? '';
    if (command.isEmpty) {
      return ToolOutcome(
        json: <String, dynamic>{'ok': false, 'error': 'command 不能为空'},
      );
    }
    // `@工具名 {...} [| 管道]` → 先跑工具，再把 JSON 交给 shell 接管道
    if (command.startsWith('@')) {
      return _runToolInTerminal(command.substring(1), args);
    }

    final env = (args['env'] as String?)?.trim().toLowerCase() ?? 'linux';
    final useLinux = env != 'android';
    final timeoutMs = _optInt(args['timeout_ms']) ??
        (useLinux ? 30000 : TerminalService.defaultTimeoutMs);

    // Linux 里挂一个工具桥：这样 `for t in a b; do @update_settings {...}; done`
    // 这种复合语句里的 @工具名 也能执行（不只是命令行开头）
    ToolBridge? bridge;
    if (useLinux) {
      try {
        final docs = await getApplicationDocumentsDirectory();
        bridge = ToolBridge(
          tmpDir: Directory(p.join(docs.path, 'linux', 'tmp')),
          handler: (name, args) async => (await _dispatch(name, args)).json,
        );
        await bridge.ensureScripts(AiTools.toolNames);
      } catch (_) {
        bridge = null;
      }
    }

    final result = useLinux
        ? await LinuxEnvService.instance
            .run(command, timeoutMs: timeoutMs, bridge: bridge)
        : await TerminalService.instance.run(command, timeoutMs: timeoutMs);
    await bridge?.dispose();

    if (result.blocked) {
      return ToolOutcome(
        json: <String, dynamic>{
          'ok': false,
          'error': result.blockedReason,
          'hint': '换一条命令；破坏系统/其他 App 数据的命令不会被执行。',
        },
      );
    }

    return ToolOutcome(
      json: <String, dynamic>{
        'ok': result.exitCode == 0,
        'command': command,
        'exitCode': result.exitCode,
        'stdout': result.stdout,
        'stderr': result.stderr,
        if (result.truncated) 'truncated': true,
        'durationMs': result.durationMs,
        'env': useLinux ? 'linux' : 'android',
        'cwd': useLinux ? '/root（Alpine rootfs）' : 'App 文档目录',
        'note': 'stdout/stderr 超过 8000 字符会被截断；'
            '回答时只引用实际看到的输出，不要编造。',
      },
    );
  }

  ToolOutcome _checkAnomalies(Map<String, dynamic> args) {
    final staleDays = _clampInt(args['stale_days'], 7, 1, 90);
    final now = DateTime.now();
    final live = records.where((r) => r.deletedAt == null).toList();

    final noPhoto = live.where((r) => r.photoName.isEmpty).toList();
    final stale = live
        .where((r) =>
            r.status == RecordStatus.pending &&
            now.difference(r.createdAt).inDays >= staleDays)
        .toList();
    final badQty = live.where((r) => r.quantity <= 0 || r.quantity > 1000).toList();

    // 单价离群：超过中位数 5 倍或低于 1/5
    final prices = live.map((r) => r.unitPrice).where((p) => p > 0).toList()
      ..sort();
    final median = prices.isEmpty
        ? 0.0
        : prices[prices.length ~/ 2];
    // 只在「填过单价」的记录里找离群值：
    // 未计价（单价 0）是常态，不能当成异常，否则只记数量的用户会被刷一堆误报
    final outliers = median <= 0
        ? <PieceRecord>[]
        : live
            .where((r) =>
                r.hasPrice &&
                (r.unitPrice > median * 5 || r.unitPrice < median / 5))
            .toList();

    // 缺信息统计（只记数量的用户很常见，用来提示补录，不算错误）
    final noStyle = live.where((r) => r.styleModel.trim().isEmpty).toList();
    final noColor = live.where((r) => r.color.trim().isEmpty).toList();
    final noSize = live.where((r) => r.size.trim().isEmpty).toList();
    final unpriced = live.where((r) => !r.hasPrice).toList();

    final issues = <String>[];
    if (noPhoto.isNotEmpty) issues.add('${noPhoto.length} 条缺照片');
    if (stale.isNotEmpty) issues.add('${stale.length} 条超过 $staleDays 天未上报');
    if (badQty.isNotEmpty) issues.add('${badQty.length} 条数量异常');
    if (outliers.isNotEmpty) issues.add('${outliers.length} 条单价离群');
    if (noStyle.isNotEmpty) issues.add('${noStyle.length} 条缺型号');
    if (unpriced.isNotEmpty) issues.add('${unpriced.length} 条未计价');

    return ToolOutcome(
      json: <String, dynamic>{
        'ok': true,
        'totalRecords': live.length,
        'medianPrice': Money.toYuan(Money.toMilli(median)),
        'issues': <String, dynamic>{
          'noPhoto': noPhoto.length,
          'stalePending': stale.length,
          'badQuantity': badQty.length,
          'priceOutliers': outliers.length,
          // 下面这些不是「错误」，是「可以补录」的信息缺口
          'missingStyleModel': noStyle.length,
          'missingColor': noColor.length,
          'missingSize': noSize.length,
          'unpriced': unpriced.length,
        },
        'note': '缺型号/缺颜色/缺码数/未计价不算错误 —— 只记数量的用户很常见，'
            '可以提示「这些能补就补」，不要当成数据异常反复追问。',
        'samples': <Map<String, dynamic>>[
          for (final r in <PieceRecord>[...noPhoto, ...stale, ...outliers]
              .take(8))
            <String, dynamic>{
              'id': r.id,
              'styleModel': r.styleModel,
              'color': r.color,
              'size': r.size,
              'quantity': r.quantity,
              'unitPrice': r.unitPrice,
              'date': Fmt.date(r.createdAt),
              'why': r.photoName.isEmpty
                  ? '缺照片'
                  : (r.status == RecordStatus.pending ? '未上报' : '单价离群'),
            },
        ],
        'summary': issues.isEmpty ? '数据很干净，没发现问题。' : issues.join('；'),
      },
    );
  }

  Future<ToolOutcome> _listOperations(Map<String, dynamic> args) async {
    final limit = _clampInt(args['limit'], 10, 1, 50);
    final logs = await host.loadOperations(limit: limit);

    return ToolOutcome(
      json: <String, dynamic>{
        'ok': true,
        'count': logs.length,
        'operations': logs
            .map((l) => <String, dynamic>{
                  'logId': l.id,
                  'kind': l.kindEnum.label,
                  'summary': l.summary,
                  'source': l.isAi ? 'AI' : '手动',
                  'time': Fmt.dateTime(l.createdAt),
                  'undone': l.undone,
                })
            .toList(),
        'hint': logs.isEmpty ? '还没有操作记录。' : '要撤回哪一条，把 logId 给我。',
      },
    );
  }

  Future<ToolOutcome> _undoOperation(Map<String, dynamic> args) async {
    var logId = _optInt(args['log_id']) ?? 0;

    if (logId == 0) {
      // 没给 id：撤销最近一条未撤销的
      final logs = await host.loadOperations(limit: 20);
      for (final l in logs) {
        if (!l.undone) {
          logId = l.id.toInt();
          break;
        }
      }
    }

    if (logId == 0) {
      return ToolOutcome(
        json: <String, dynamic>{'ok': false, 'error': '没有可撤销的操作'},
      );
    }

    final ok = await host.undoOperation(logId);
    return ToolOutcome(
      json: <String, dynamic>{
        'ok': ok,
        'logId': logId,
        'message': ok ? '已撤销，数据还原到操作之前。' : '这条操作已经撤销过或数据异常。',
      },
    );
  }

  Future<ToolOutcome> _restoreRecords(Map<String, dynamic> args) async {
    final deleted = await host.loadDeleted();
    if (deleted.isEmpty) {
      return ToolOutcome(
        json: <String, dynamic>{'ok': false, 'error': '回收站是空的'},
      );
    }

    List<PieceRecord> targets;
    if (args['all'] == true) {
      targets = deleted;
    } else {
      final filter = _filterFromArgs(args);
      final converter = await _converter();
      targets =
          QueryEngine.apply(deleted, filter, converter: converter).records;
    }

    if (targets.isEmpty) {
      return ToolOutcome(
        json: <String, dynamic>{
          'ok': false,
          'error': '回收站里没有匹配的记录（共 ${deleted.length} 条）',
        },
      );
    }

    final n = await host.restoreDeleted(targets.map((r) => r.id.toInt()).toList());
    return ToolOutcome(
      json: <String, dynamic>{
        'ok': true,
        'restored': n,
        'message': '已从回收站恢复 $n 条记录。',
        'samples': targets.take(5).map((r) => <String, dynamic>{
              'styleModel': r.styleModel,
              'color': r.color,
              'size': r.size,
              'quantity': r.quantity,
              'deletedAt': r.deletedAt == null
                  ? null
                  : Fmt.dateTime(r.deletedAt!),
            }).toList(),
      },
    );
  }

  Future<ToolOutcome> _exportReport(Map<String, dynamic> args) async {
    final filter = _filterFromArgs(args);
    final format = (args['format'] as String?) ?? 'png';
    final converter = await _converter();
    final result =
        QueryEngine.apply(records, filter, converter: converter);

    return ToolOutcome(
      filter: _pin(filter, result.records),
      stats: result.toSummaryJson(),
      uiActions: <UiAction>[
        const UiAction(
          kind: UiActionKind.openPage,
          target: 'report',
          label: '打开报表页导出',
        ),
      ],
      json: <String, dynamic>{
        'ok': true,
        'format': format,
        'recordCount': result.count,
        'totalQuantity': result.totalQuantity,
        'totalAmount': Money.toYuan(result.totalAmountMilli),
        'message': '已跳到报表页。提醒用户：筛选条件已带过去，点右下角「导出高清 PNG」或「导出 CSV」。',
      },
    );
  }

  ToolOutcome _predictIncome(Map<String, dynamic> args) {
    final days = _clampInt(args['lookback_days'], 7, 1, 90);
    final now = DateTime.now();
    final since = DateUtil.startOfDay(now).subtract(Duration(days: days));
    final monthStart = DateUtil.startOfMonth(now);

    final live = records.where((r) => r.deletedAt == null).toList();
    final recent = live.where((r) => r.createdAt.isAfter(since)).toList();
    final monthList =
        live.where((r) => !r.createdAt.isBefore(monthStart)).toList();

    final recentMilli =
        recent.fold(0, (s, r) => s + r.subtotalMilli);
    final monthMilli = monthList.fold(0, (s, r) => s + r.subtotalMilli);

    final perDay = recentMilli / days;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final remaining = (daysInMonth - now.day).clamp(0, 31);
    final predicted = monthMilli + perDay * remaining;

    return ToolOutcome(
      json: <String, dynamic>{
        'ok': true,
        'lookbackDays': days,
        'averagePerDay': Money.toYuan(perDay.round()),
        'monthSoFar': Money.toYuan(monthMilli),
        'remainingDays': remaining,
        'predictedMonthTotal': Money.toYuan(predicted.round()),
        'recordCountThisMonth': monthList.length,
        'message': '按最近 $days 天日均 ¥${Money.format(perDay.round())} 推算，'
            '本月预计 ¥${Money.format(predicted.round())}（已入账 ¥${Money.format(monthMilli)}，'
            '还剩 $remaining 天）。',
      },
    );
  }

  Future<ToolOutcome> _unitConvert(Map<String, dynamic> args) async {
    final qty = _optDouble(args['quantity']) ?? 0;
    final from = ((args['from_unit'] as String?) ?? '').trim();
    final to = ((args['to_unit'] as String?) ?? '').trim();
    final style = ((args['style_model'] as String?) ?? '').trim();

    if (from.isEmpty || to.isEmpty) {
      return ToolOutcome(
        json: <String, dynamic>{'ok': false, 'error': 'from_unit / to_unit 不能为空'},
      );
    }

    final units = await host.loadUnits();
    final rules = await host.loadUnitRules();
    var base = '件';
    for (final u in units) {
      if (u.isBase) base = u.name;
    }
    final conv = UnitConverter(baseUnit: base, rules: rules);

    final perFrom = conv.centiBasePerUnit(from, styleModel: style) / 100.0;
    final perTo = conv.centiBasePerUnit(to, styleModel: style) / 100.0;
    if (perTo <= 0) {
      return ToolOutcome(
        json: <String, dynamic>{'ok': false, 'error': '目标单位换算比例为 0'},
      );
    }
    final result = qty * perFrom / perTo;

    return ToolOutcome(
      json: <String, dynamic>{
        'ok': true,
        'quantity': qty,
        'fromUnit': from,
        'toUnit': to,
        'result': double.parse(result.toStringAsFixed(4)),
        'baseUnit': base,
        'ruleConfigured': conv.hasRule(from, styleModel: style),
        'message': '$qty $from = ${result.toStringAsFixed(2)} $to'
            '${conv.hasRule(from, styleModel: style) ? '' : '（该单位未配换算，按 1:1 算）'}',
      },
    );
  }

  // ───────────────────────── 展示类卡片 ─────────────────────────

  ToolOutcome _renderSvg(Map<String, dynamic> args) {
    final title = ((args['title'] as String?) ?? '图表').trim();
    final svg = ((args['svg'] as String?) ?? '').trim();

    if (!svg.startsWith('<svg')) {
      return ToolOutcome(
        json: <String, dynamic>{
          'ok': false,
          'error': 'svg 必须以 <svg 开头',
        },
      );
    }
    if (svg.length > 20000) {
      return ToolOutcome(
        json: <String, dynamic>{
          'ok': false,
          'error': 'SVG 太大（${svg.length} 字符），控制在 20000 以内',
        },
      );
    }

    return ToolOutcome(
      svg: SvgBlock(title: title.isEmpty ? '图表' : title, svg: svg),
      json: <String, dynamic>{
        'ok': true,
        'rendered': true,
        'message': '图已显示在对话里。用一句话说明这张图表达什么就行，不要复述数据。',
      },
    );
  }

  ToolOutcome _showCalculation(Map<String, dynamic> args) {
    final title = ((args['title'] as String?) ?? '计算过程').trim();
    final raw = args['steps'];
    final steps = <CalcStep>[];

    if (raw is List) {
      for (final e in raw) {
        if (e is! Map) continue;
        final m = e.map((k, v) => MapEntry(k.toString(), v));
        final label = (m['label'] as String?)?.trim() ?? '';
        final expr = (m['expression'] as String?)?.trim() ?? '';
        final result = (m['result'] as String?)?.trim() ?? '';
        if (label.isEmpty && expr.isEmpty) continue;
        steps.add(CalcStep(label: label, expression: expr, result: result));
        if (steps.length >= 12) break;
      }
    }

    if (steps.isEmpty) {
      return ToolOutcome(
        json: <String, dynamic>{
          'ok': false,
          'error': 'steps 不能为空',
        },
      );
    }

    return ToolOutcome(
      calc: CalcTable(
        title: title.isEmpty ? '计算过程' : title,
        steps: steps,
        conclusion: ((args['conclusion'] as String?) ?? '').trim(),
      ),
      json: <String, dynamic>{
        'ok': true,
        'stepCount': steps.length,
        'message': '计算过程已展示。正文里不要再重复算式，只说结论。',
      },
    );
  }

  ToolOutcome _showCode(Map<String, dynamic> args) {
    final title = ((args['title'] as String?) ?? '代码').trim();
    final lang = ((args['language'] as String?) ?? 'text').trim().toLowerCase();
    final code = ((args['code'] as String?) ?? '').trim();

    if (code.isEmpty) {
      return ToolOutcome(
        json: <String, dynamic>{'ok': false, 'error': 'code 不能为空'},
      );
    }
    if (code.length > 8000) {
      return ToolOutcome(
        json: <String, dynamic>{
          'ok': false,
          'error': '代码太长（${code.length} 字符），控制在 8000 以内',
        },
      );
    }

    return ToolOutcome(
      code: CodeBlock(
        title: title.isEmpty ? '代码' : title,
        language: lang.isEmpty ? 'text' : lang,
        code: code,
      ),
      json: <String, dynamic>{
        'ok': true,
        'language': lang,
        'lines': code.split('\n').length,
        'message': '代码卡片已展示，用户可以直接复制。',
      },
    );
  }

  // ───────────────────────── 反问用户 ─────────────────────────

  ToolOutcome _askUser(Map<String, dynamic> args) {
    final q = (args['question'] as String?)?.trim() ?? '';
    if (q.isEmpty) {
      return ToolOutcome(
        json: <String, dynamic>{'ok': false, 'error': 'question 不能为空'},
      );
    }

    final options = <String>[];
    final raw = args['options'];
    if (raw is List) {
      for (final e in raw) {
        if (e is String && e.trim().isNotEmpty) {
          options.add(e.trim());
          if (options.length >= 6) break;
        }
      }
    }

    return ToolOutcome(
      ask: AskPrompt(
        question: q,
        options: options,
        why: (args['why'] as String?)?.trim() ?? '',
      ),
      json: <String, dynamic>{
        'ok': true,
        'asked': q,
        'optionCount': options.length,
        'message': '问题已经显示在界面上（带可点选项）。现在停下等用户回答，'
            '不要自己猜一个答案继续往下做。',
      },
    );
  }

  // ───────────────────────── 图片关联 ─────────────────────────

  Future<ToolOutcome> _managePhotos(Map<String, dynamic> args) async {
    final action = (args['action'] as String?) ?? 'attach';
    final filter = _filterFromArgs(args);
    final converter = await _converter();
    final result =
        QueryEngine.apply(records, filter, converter: converter);

    if (result.isEmpty) {
      return ToolOutcome(
        filter: _pin(filter, result.records),
        json: <String, dynamic>{
          'ok': false,
          'error': '没有记录匹配这组条件，未生成图片操作。',
          'filterSummary': filter.summary,
        },
      );
    }

    if (action == 'list') {
      final names = <String>{
        for (final r in records)
          if (r.deletedAt == null && r.photoName.isNotEmpty) r.photoName,
      };
      final byAge = records
          .where((r) => names.contains(r.photoName))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      await PhotoIndexService.instance
          .ensure(byAge.map((r) => r.photoName).toSet().toList());
      final list = <Map<String, dynamic>>[
        for (final r in byAge)
          <String, dynamic>{
            'id': PhotoIndexService.instance.numberOf(r.photoName) ?? 0,
            'name': r.photoName,
            'styleModel': r.styleModel,
            'size': r.size,
            'createdAt': _dateTime(r.createdAt),
            'refs': records
                .where((x) => x.deletedAt == null && x.photoName == r.photoName)
                .length,
          },
      ];
      return ToolOutcome(
        json: <String, dynamic>{
          'ok': true,
          'count': list.length,
          'photos': list,
          'note': '关联时把 id 传给 manage_photos 的 photo_id 即可（不用重新上传）。',
        },
      );
    }

    if (action == 'detach') {
      final withPhoto =
          result.records.where((r) => r.photoName.isNotEmpty).toList();
      if (withPhoto.isEmpty) {
        return ToolOutcome(
          filter: _pin(filter, result.records),
          json: <String, dynamic>{
            'ok': false,
            'error': '这些记录本来就没有照片。',
          },
        );
      }
      await PhotoIndexService.instance
          .ensure(withPhoto.map((r) => r.photoName).toSet().toList());
      final pending = PendingAction(
        kind: PendingKind.detachPhoto,
        description: '解除 ${withPhoto.length} 条记录的照片关联（没有其他记录引用时才会删掉图片文件）',
        ids: withPhoto.map((r) => r.id).toList(),
        diff: buildPhotoDiff(
          records: withPhoto,
          afterName: '',
          detach: true,
        ),
      );
      return ToolOutcome(
        filter: _pin(filter, result.records),
        pendingAction: pending,
        json: <String, dynamic>{
          'ok': true,
          'status': 'pending_user_confirmation',
          'affectedCount': withPhoto.length,
          'message': '已在界面生成确认卡片，用户点「确认解除」后才删除。'
              '这条需求到此为止；还有别的需求就继续调用工具。',
        },
      );
    }

    // attach：目标图可以是「本次对话发的图」，也可以是图库里已有的图（按编号/文件名）
    var targetPhoto = contextPhotoName;
    String source = '本次对话的图片';

    final wantedId = _optInt(args['photo_id']);
    final wantedName = (args['photo_name'] as String?)?.trim() ?? '';
    if (targetPhoto.isEmpty && (wantedId != null || wantedName.isNotEmpty)) {
      await PhotoIndexService.instance.ensureLoaded();
      if (wantedId != null) {
        targetPhoto = PhotoIndexService.instance.nameOf(wantedId) ?? '';
        if (targetPhoto.isEmpty) {
          return ToolOutcome(
            filter: _pin(filter, result.records),
            json: <String, dynamic>{
              'ok': false,
              'error': '没有编号 #$wantedId 的图片。'
                  '可以用 show_photos 或 list 动作先看看有哪些图。',
            },
          );
        }
        source = '图库 #$wantedId';
      } else {
        targetPhoto = wantedName;
        source = '图库文件 $wantedName';
      }
    }

    if (targetPhoto.isEmpty) {
      return ToolOutcome(
        filter: _pin(filter, result.records),
        json: <String, dynamic>{
          'ok': false,
          'error': '没有指定要关联的图片。三种方式任选：'
              '① 用户在对话里发一张图（自动用这张）；'
              '② 传 photo_id（图库编号，例如 1 表示 #1）；'
              '③ 传 photo_name（图片文件名）。'
              '不知道编号就先调 show_photos 或 manage_photos(action=list)。',
        },
      );
    }

    // 给「原来的图」和「新图」都分配编号，卡片上才能显示 #12 这种
    await PhotoIndexService.instance.ensure(<String>[
      for (final r in result.records)
        if (r.photoName.isNotEmpty) r.photoName,
      if (targetPhoto.isNotEmpty) targetPhoto,
    ]);

    final pending = PendingAction(
      kind: PendingKind.attachPhoto,
      description: '给 ${result.count} 条记录关联$source',
      ids: result.records.map((r) => r.id).toList(),
      photoName: targetPhoto,
      preview: result.records.take(5).map(_recordLine).toList(),
      diff: buildPhotoDiff(
        records: result.records,
        afterName: targetPhoto,
        detach: false,
      ),
    );

    return ToolOutcome(
      filter: _pin(filter, result.records),
      pendingAction: pending,
      json: <String, dynamic>{
        'ok': true,
        'status': 'pending_user_confirmation',
        'affectedCount': result.count,
        'message': '已在界面生成确认卡片，用户点「确认关联」后生效。'
            '这条需求到此为止；用户如果还提了别的需求，继续调用工具处理，不要停。',
      },
    );
  }

  // ───────────────────────── Agent 协议 ─────────────────────────

  ToolOutcome _planTask(Map<String, dynamic> args) {
    final goal = (args['goal'] as String?)?.trim() ?? '';
    final raw = args['steps'];
    final steps = <AgentStep>[];

    if (raw is List) {
      for (var i = 0; i < raw.length && i < 8; i++) {
        final e = raw[i];
        if (e is Map) {
          final m = e.map((k, v) => MapEntry(k.toString(), v));
          final title = (m['title'] as String?)?.trim() ?? '';
          if (title.isEmpty) continue;
          final rawId = (m['id'] as String?)?.trim() ?? '';
          steps.add(AgentStep(
            id: rawId.isEmpty ? 's${steps.length + 1}' : rawId,
            title: title,
            status: steps.isEmpty
                ? AgentStepStatus.running
                : AgentStepStatus.pending,
          ));
        } else if (e is String && e.trim().isNotEmpty) {
          steps.add(AgentStep(
            id: 's${steps.length + 1}',
            title: e.trim(),
            status: steps.isEmpty
                ? AgentStepStatus.running
                : AgentStepStatus.pending,
          ));
        }
      }
    }

    if (steps.isEmpty) {
      return ToolOutcome(
        json: <String, dynamic>{
          'ok': false,
          'error': 'steps 不能为空，至少给 2 个步骤',
        },
      );
    }

    _task = AgentTask(
      goal: goal.isEmpty ? '执行任务' : goal,
      steps: steps,
    );

    return ToolOutcome(
      agentTask: _task,
      json: <String, dynamic>{
        'ok': true,
        'goal': _task!.goal,
        'stepCount': steps.length,
        'message': '计划已展示给用户。现在按顺序执行，每完成一步调用 step_done，'
            '全部做完调用 finish_task。',
      },
    );
  }

  ToolOutcome _stepDone(Map<String, dynamic> args) {
    final t = _task;
    if (t == null) {
      return ToolOutcome(
        json: <String, dynamic>{
          'ok': false,
          'error': '还没有计划。多步任务请先调 plan_task；单步任务直接做即可。',
        },
      );
    }

    final id = (args['step_id'] as String?)?.trim() ?? '';
    final result = (args['result'] as String?)?.trim() ?? '';

    var idx = id.isEmpty ? -1 : t.steps.indexWhere((s) => s.id == id);
    if (idx < 0) {
      idx = t.steps.indexWhere((s) => s.status == AgentStepStatus.running);
    }
    if (idx < 0) {
      idx = t.steps.indexWhere((s) => s.status == AgentStepStatus.pending);
    }
    if (idx < 0) {
      return ToolOutcome(
        agentTask: t,
        json: <String, dynamic>{'ok': false, 'error': '没有可完成的步骤'},
      );
    }

    t.steps[idx].status = AgentStepStatus.done;
    t.steps[idx].detail = result;

    // 自动把下一步标为进行中
    for (var i = 0; i < t.steps.length; i++) {
      if (t.steps[i].status == AgentStepStatus.pending) {
        t.steps[i].status = AgentStepStatus.running;
        break;
      }
    }

    return ToolOutcome(
      agentTask: t,
      json: <String, dynamic>{
        'ok': true,
        'completed': t.steps[idx].id,
        'progress': '${t.doneCount}/${t.steps.length}',
      },
    );
  }

  ToolOutcome _finishTask(Map<String, dynamic> args) {
    final t = _task ?? AgentTask(goal: '任务', steps: <AgentStep>[]);
    t.summary = (args['summary'] as String?)?.trim() ?? '';

    final raw = args['followups'];
    final followups = <String>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is String && e.trim().isNotEmpty) followups.add(e.trim());
      }
    }
    t.followups = followups.take(3).toList();
    t.done = true;
    for (final s in t.steps) {
      if (s.status != AgentStepStatus.failed) {
        s.status = AgentStepStatus.done;
      }
    }
    _task = t;

    return ToolOutcome(
      agentTask: t,
      json: <String, dynamic>{
        'ok': true,
        'summary': t.summary,
        'followups': t.followups,
        'message': '任务已标记完成。请用一两句话向用户交代结论，不要重复步骤列表。',
      },
    );
  }

  // ───────────────────────── 工具轨迹 ─────────────────────────

  /// 给测试/诊断用：显式构造一条工具轨迹（不执行工具）
  ToolTrace buildTraceFor(
    String name,
    Map<String, dynamic> args,
    ToolOutcome outcome,
    int durationMs,
  ) =>
      _buildTrace(name, args, outcome, durationMs);

  ToolTrace _buildTrace(
    String name,
    Map<String, dynamic> args,
    ToolOutcome outcome,
    int durationMs,
  ) {
    final ok = outcome.json['ok'] != false;
    return ToolTrace(
      name: name,
      label: _toolLabel(name),
      input: _inputSummary(name, args, outcome),
      output: _outputSummary(name, args, outcome),
      detail: _detailFor(name, args, outcome),
      ok: ok,
      durationMs: durationMs,
    );
  }

  static String _toolLabel(String name) => switch (name) {
        'show_photos' => '展示图片',
        'run_terminal' => '执行命令',
        'query_records' => '查询记录',
        'aggregate_records' => '分组汇总',
        'list_available_options' => '读取选项',
        'delete_records' => '删除记录',
        'update_records' => '修改记录',
        'create_records' => '新建记录',
        'get_settings' => '读取设置',
        'update_settings' => '修改设置',
        'manage_options' => '维护选项',
        'manage_units' => '维护单位',
        'set_unit_rule' => '配置换算',
        'apply_filter' => '应用筛选',
        'compare_periods' => '周期对比',
        'top_n' => '排行榜',
        'open_page' => '打开页面',
        'manage_photos' => '图片关联',
        'ask_user' => '向用户提问',
        'explain_conversion' => '换算核对',
        'find_duplicates' => '查重',
        'check_anomalies' => '数据体检',
        'list_operations' => '操作历史',
        'undo_operation' => '撤销操作',
        'restore_records' => '回收站恢复',
        'export_report' => '导出报表',
        'predict_income' => '收入预估',
        'unit_convert' => '单位换算',
        'render_svg' => '绘制图表',
        'show_calculation' => '计算过程',
        'show_code' => '代码展示',
        _ => name,
      };

  String _inputSummary(
    String name,
    Map<String, dynamic> args,
    ToolOutcome outcome,
  ) {
    String clip(Object? v, [int max = 60]) {
      final t = (v is String ? v : '').trim();
      return t.length > max ? '${t.substring(0, max)}…' : t;
    }

    switch (name) {
      case 'query_records':
      case 'aggregate_records':
      case 'delete_records':
      case 'update_records':
      case 'apply_filter':
      case 'top_n':
      case 'explain_conversion':
        return outcome.filter?.summary ?? '';
      case 'compare_periods':
        return '${args['period_a'] ?? ''} vs ${args['period_b'] ?? ''}';
      case 'open_page':
        return '${args['page'] ?? ''}';
      case 'update_settings':
        final applied = outcome.json['applied'];
        if (applied is Map && applied.isNotEmpty) {
          return applied.keys.join(' / ');
        }
        return '';
      case 'run_terminal':
        final env = (args['env'] as String?) ?? 'linux';
        final cmd = clip(args['command'], 64);
        return '[$env] $cmd';
      case 'manage_options':
      case 'manage_units':
        return '${args['action'] ?? ''} ${args['name'] ?? args['value'] ?? ''}'
            .trim();
      case 'set_unit_rule':
        return '${args['denominator']} ${args['from_unit']} = '
            '${args['numerator']} ${args['to_unit']}';
      case 'manage_photos':
        return '${args['action'] ?? ''}'.trim();
      case 'check_anomalies':
        return '未上报超 ${args['stale_days'] ?? 7} 天算异常';
      case 'predict_income':
        return '按最近 ${args['lookback_days'] ?? 7} 天推算';
      case 'unit_convert':
        return '${args['quantity'] ?? ''} ${args['from_unit'] ?? ''} → '
            '${args['to_unit'] ?? ''}';
      case 'export_report':
        return '${args['template'] ?? '报表'}';
      case 'restore_records':
        final ids = args['ids'];
        return ids is List ? '${ids.length} 条' : '';
      case 'undo_operation':
        return args['log_id'] == null ? '最近一次' : '日志 #${args['log_id']}';
      case 'ask_user':
        return clip(args['question'], 40);
      case 'plan_task':
        final steps = args['steps'];
        return steps is List ? '${steps.length} 步' : '';
      case 'step_done':
        return clip(args['title'], 30);
      case 'finish_task':
        return clip(args['summary'], 40);
      case 'show_calculation':
      case 'render_svg':
        return clip(args['title'], 30);
      case 'show_code':
        return '${args['language'] ?? ''}'.trim();
      default:
        return '';
    }
  }

  /// 展开卡片时看的明细：目前只有终端命令需要（完整输出）
  String _detailFor(
    String name,
    Map<String, dynamic> args,
    ToolOutcome outcome,
  ) {
    if (name != 'run_terminal') return '';
    final json = outcome.json;
    final buf = StringBuffer();
    buf.writeln('\$ ${args['command'] ?? ''}');
    if (json['ok'] == false && json['error'] != null) {
      buf.writeln('⛔ ${json['error']}');
      return buf.toString().trimRight();
    }
    final out = (json['stdout'] as String?) ?? '';
    final err = (json['stderr'] as String?) ?? '';
    if (out.isNotEmpty) buf.writeln(out);
    if (err.isNotEmpty) buf.writeln('[stderr]\n$err');
    if (out.isEmpty && err.isEmpty) buf.writeln('（无输出）');
    final tail = buf.toString();
    return tail.length > 2000 ? '${tail.substring(0, 2000)}\n…（已截断）' : tail;
  }

  /// 结果摘要：每个工具都要说清楚「具体发生了什么」，不要只写「完成」
  String _outputSummary(
    String name,
    Map<String, dynamic> args,
    ToolOutcome outcome,
  ) {
    final json = outcome.json;
    if (json['ok'] == false) {
      final err = json['error'] as String?;
      return err == null || err.isEmpty ? '失败' : err;
    }
    if (outcome.pendingAction != null) {
      final a = outcome.pendingAction!;
      final kind = switch (a.kind) {
        PendingKind.delete => '删除',
        PendingKind.update => '修改',
        PendingKind.create => '新建',
        PendingKind.attachPhoto => '关联图片',
        PendingKind.detachPhoto => '解除图片',
      };
      return '待确认 · $kind ${a.affectedCount} 条';
    }

    switch (name) {
      case 'run_terminal':
        final exit = json['exitCode'];
        final out = (json['stdout'] as String?) ?? '';
        final err = (json['stderr'] as String?) ?? '';
        final body = out.isNotEmpty ? out : err;
        final first = body.isEmpty ? '' : body.split('\n').first.trim();
        final lines = body.isEmpty ? 0 : body.split('\n').length;
        final parts = <String>[
          if (exit != null) 'exit $exit',
          if (body.isEmpty) '无输出' else '$lines 行输出',
          if (first.isNotEmpty)
            first.length > 48 ? '${first.substring(0, 48)}…' : first,
        ];
        return parts.join(' · ');
      case 'list_available_options':
        final used = json['usedInRecords'];
        if (used is Map) {
          int n(Object? v) => v is List ? v.length : 0;
          return '型号 ${n(used['styleModels'])} · 颜色 ${n(used['colors'])} · '
              '码数 ${n(used['sizes'])}';
        }
        return '已读取选项';
      case 'get_settings':
        return '主题 ${json['theme'] ?? '-'} · 单位 ${json['baseUnit'] ?? '-'} · '
            '报表「${json['reportTitle'] ?? '-'}」';
      case 'update_settings':
        final applied = json['applied'];
        if (applied is Map) {
          return applied.isEmpty
              ? '无变化'
              : '已更新 ${applied.length} 项（${applied.keys.join('/')}）';
        }
        return '已更新';
      case 'manage_options':
        final v = json['value'] ?? args['value'];
        final kind = json['kind'] ?? args['kind'];
        return '${json['action'] ?? args['action'] ?? ''} $kind $v'.trim();
      case 'manage_units':
        return '${json['action'] ?? args['action'] ?? ''} '
                '${json['name'] ?? args['name'] ?? ''}'
            .trim();
      case 'set_unit_rule':
        return json['label'] as String? ??
            '${args['denominator']} ${args['from_unit']} = '
                '${args['numerator']} ${args['to_unit']}';
      case 'check_anomalies':
        final issues = json['issues'];
        if (issues is Map) {
          final parts = <String>[
            if ((issues['noPhoto'] ?? 0) != 0) '缺照片 ${issues['noPhoto']}',
            if ((issues['stalePending'] ?? 0) != 0)
              '久未上报 ${issues['stalePending']}',
            if ((issues['badQuantity'] ?? 0) != 0)
              '数量异常 ${issues['badQuantity']}',
            if ((issues['priceOutliers'] ?? 0) != 0)
              '单价离群 ${issues['priceOutliers']}',
            if ((issues['missingStyleModel'] ?? 0) != 0)
              '缺型号 ${issues['missingStyleModel']}',
            if ((issues['unpriced'] ?? 0) != 0) '未计价 ${issues['unpriced']}',
          ];
          return parts.isEmpty
              ? '共 ${json['totalRecords'] ?? 0} 条，没发现问题'
              : parts.join(' · ');
        }
        return '体检完成';
      case 'find_duplicates':
        final g = json['duplicateGroups'];
        final r = json['duplicateRecords'];
        if (g is int) return '$g 组重复（共 $r 条）';
        return '没发现重复';
      case 'predict_income':
        final avg = json['averagePerDay'];
        final pred = json['predictedMonthTotal'];
        return '日均 ${avg is num ? Money.yuan(Money.toMilli(avg)) : '-'} · '
            '本月预计 ${pred is num ? Money.yuan(Money.toMilli(pred)) : '-'}';
      case 'unit_convert':
        final v = json['result'] ?? json['value'] ?? json['converted'];
        return '${args['quantity'] ?? ''} ${args['from_unit'] ?? ''} = '
            '${v is num ? v : (v ?? '-')} ${args['to_unit'] ?? ''}'
                .trim();
      case 'compare_periods':
        final a = json['a'];
        final b = json['b'];
        if (a is Map && b is Map) {
          return '${a['label'] ?? 'A'} ${a['totalQuantity'] ?? '-'} vs '
              '${b['label'] ?? 'B'} ${b['totalQuantity'] ?? '-'}';
        }
        return '对比完成';
      case 'explain_conversion':
        final ok = json['consistent'];
        return ok == true ? '换算自洽' : '换算不一致（已列出明细）';
      case 'list_operations':
        final n = json['count'];
        return n is int ? '$n 条操作记录' : '操作记录';
      case 'undo_operation':
        return (json['message'] as String?) ?? '已撤销';
      case 'restore_records':
        final n = json['restoredCount'] ?? json['affectedCount'];
        return n is int ? '恢复 $n 条' : (json['message'] as String? ?? '已恢复');
      case 'export_report':
        return '已生成报表，点下方按钮打开';
      case 'plan_task':
        final n = json['stepCount'];
        return n is int ? '$n 步计划' : '计划已建立';
      case 'step_done':
        final p = json['progress'];
        return p is String ? '进度 $p' : '步骤完成';
      case 'finish_task':
        return (json['summary'] as String?) ?? '任务完成';
      case 'ask_user':
        return '等用户回答';
      case 'render_svg':
        return '已生成图表卡片';
      case 'show_calculation':
        return '已生成计算过程卡片';
      case 'show_code':
        return '已生成代码卡片';
      case 'open_page':
        return '已跳转 ${args['page'] ?? ''}'.trim();
      case 'apply_filter':
        return '筛选已应用';
    }

    // 通用兜底：给一句「具体」的摘要，而不是「完成」
    final count = json['recordCount'];
    if (count is int) {
      final qty = json['totalQuantity'];
      final baseQty = json['totalBaseQuantity'];
      final mixed = json['mixedUnits'] == true;
      final amt = json['totalAmount'];

      // 单位必须照抄结果里的，不能一律写「件」：
      // 记录是「片」的时候写「1280 件」会被当成错账
      final auth = json['authoritative'] is Map
          ? json['authoritative'] as Map
          : const <String, dynamic>{};
      final rawUnits = json['units'] ?? auth['units'];
      final units = rawUnits is List
          ? rawUnits.map((e) => e.toString()).toList()
          : const <String>[];
      final baseUnit =
          (json['baseUnit'] ?? auth['baseUnit'] ?? '件').toString();
      final singleUnit = units.length == 1 ? units.first : '';

      final parts = <String>['$count 条'];
      if (mixed) {
        if (baseQty is num) {
          parts.add('${baseQty.toStringAsFixed(2)} $baseUnit(折算)');
        }
      } else if (qty is num) {
        final unit = singleUnit.isEmpty ? baseUnit : singleUnit;
        // 单位和基准不同时，顺手把折算值写出来，卡片和回答才对得上
        if (unit != baseUnit && baseQty is num && baseQty != qty) {
          final baseText = baseQty == baseQty.roundToDouble()
              ? baseQty.toStringAsFixed(0)
              : baseQty.toStringAsFixed(2);
          parts.add('$qty $unit（≈ $baseText $baseUnit）');
        } else {
          parts.add('$qty $unit');
        }
      } else if (baseQty is num) {
        parts.add('${baseQty.toStringAsFixed(2)} $baseUnit(折算)');
      }
      if (amt is num) parts.add(Money.yuan(Money.toMilli(amt)));
      if ((json['unpricedCount'] ?? 0) != 0) {
        parts.add('${json['unpricedCount']} 条未计价');
      }
      return parts.join(' · ');
    }
    if (json['ranking'] is List) return '${(json['ranking'] as List).length} 名';
    if (json['affectedCount'] is int) return '影响 ${json['affectedCount']} 条';

    // 最后兜底：把结果里的前几个字段摊开（比「完成」有用）
    final preview = <String>[];
    for (final e in json.entries) {
      if (e.key == 'ok' || e.key == 'note') continue;
      final v = e.value;
      if (v == null) continue;
      if (v is String && v.isEmpty) continue;
      if (v is List && v.isEmpty) continue;
      if (v is Map && v.isEmpty) continue;
      final text = v is String
          ? (v.length > 30 ? '${v.substring(0, 30)}…' : v)
          : (v is List ? '${v.length} 项' : '$v');
      preview.add('${e.key}=$text');
      if (preview.length >= 3) break;
    }
    return preview.isEmpty ? '完成（无返回内容）' : preview.join(' · ');
  }

  // ───────────────────────── 周期工具 ─────────────────────────

  _Period _periodRange(String key) {
    final now = DateTime.now();
    final today = DateUtil.startOfDay(now);
    switch (key) {
      case 'today':
        return _Period('今天', today, DateUtil.endOfDay(now));
      case 'yesterday':
        final y = today.subtract(const Duration(days: 1));
        return _Period('昨天', y, DateUtil.endOfDay(y));
      case 'this_week':
        return _Period('本周', DateUtil.startOfWeek(now), DateUtil.endOfDay(now));
      case 'last_week':
        final start = DateUtil.startOfWeek(now).subtract(const Duration(days: 7));
        final end = start.add(const Duration(days: 6));
        return _Period('上周', start, DateUtil.endOfDay(end));
      case 'this_month':
        return _Period('本月', DateUtil.startOfMonth(now), DateUtil.endOfDay(now));
      case 'last_month':
        final start = DateTime(now.year, now.month - 1, 1);
        return _Period('上月', start, DateUtil.endOfMonth(start));
      default:
        return _Period('本周', DateUtil.startOfWeek(now), DateUtil.endOfDay(now));
    }
  }

  /// 一行记录摘要，给确认卡预览用
  static String _recordLine(PieceRecord r) {
    final parts = <String>[
      if (r.styleModel.isNotEmpty) r.styleModel,
      if (r.color.isNotEmpty) r.color,
      if (r.size.isNotEmpty) r.size,
    ];
    return '${parts.isEmpty ? "（未填）" : parts.join(" ")}'
        ' · ${r.quantity}${r.unitOrBase}'
        ' · ${Fmt.date(r.createdAt)}';
  }

  static String _fieldLabel(String key) => switch (key) {
        'unitPrice' => '单价',
        'quantity' => '数量',
        'note' => '备注',
        'color' => '颜色',
        'size' => '码数',
        'styleModel' => '型号',
        'status' => '上报状态',
        _ => key,
      };

  // ─────────────────────────── 参数解析 ───────────────────────────

  /// 把「这一刻命中的记录」钉进筛选条件，
  /// 之后即使数据被改，点「查看这批记录」也能看到同一批。
  static RecordFilter _pin(RecordFilter filter, List<PieceRecord> hit) {
    if (hit.isEmpty) return filter;
    return filter.copyWith(
      pinnedIds: hit.take(500).map((r) => r.id).toList(),
    );
  }

  RecordFilter _filterFromArgs(Map<String, dynamic> args) {
    final preset = (args['date_preset'] as String?) ?? 'all';
    var quick = switch (preset) {
      'today' => QuickRange.today,
      'yesterday' => QuickRange.yesterday,
      'this_week' => QuickRange.thisWeek,
      'this_month' => QuickRange.thisMonth,
      'custom' => QuickRange.custom,
      _ => QuickRange.all,
    };

    DateTime? start;
    DateTime? end;
    if (quick == QuickRange.custom) {
      start = _parseDate(args['start_date']);
      end = _parseDate(args['end_date']);
      if (start == null && end == null) {
        quick = QuickRange.all; // 模型给了 custom 却没给日期 → 退化为全部
      }
    }

    return RecordFilter(
      quick: quick,
      customStart: start,
      customEnd: end,
      styleModels: _strList(args['style_models']),
      colors: _strList(args['colors']),
      sizes: _strList(args['sizes']),
      minQty: _optInt(args['min_quantity']),
      maxQty: _optInt(args['max_quantity']),
      photoFilter: photoFilterFromWire(args['photo']),
      missing: <MissingField>{
        for (final v in _strList(args['missing']))
          if (missingFieldFromWire(v) != null) missingFieldFromWire(v)!,
      },
      statusFilter: statusFilterFromWire(args['status']),
      sortField: switch (args['sort_by']) {
        'quantity' => SortField.quantity,
        'amount' => SortField.amount,
        _ => SortField.createdAt,
      },
      ascending: args['sort_order'] == 'asc',
    );
  }

  static GroupField _groupFromArgs(Object? v) => switch (v) {
        'styleModel' => GroupField.styleModel,
        'color' => GroupField.color,
        'size' => GroupField.size,
        'day' => GroupField.day,
        'month' => GroupField.month,
        _ => GroupField.none,
      };

  static Set<String> _strList(Object? v) {
    if (v is List) {
      return v
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
    }
    if (v is String && v.trim().isNotEmpty) return <String>{v.trim()};
    return <String>{};
  }

  static int? _optInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  static double? _optDouble(Object? v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }

  static int _clampInt(Object? v, int fallback, int min, int max) {
    final n = _optInt(v) ?? fallback;
    if (n < min) return min;
    if (n > max) return max;
    return n;
  }

  static DateTime? _parseDate(Object? v) {
    if (v is! String || v.trim().isEmpty) return null;
    return DateTime.tryParse(v.trim());
  }

  static String _dateTime(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';

  static String _two(int v) => v.toString().padLeft(2, '0');
}


/// 周期工具用的时间区间
class _Period {
  const _Period(this.label, this.start, this.end);

  final String label;
  final DateTime start;
  final DateTime end;
}
