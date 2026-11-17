// 工具：把一份 Isar 数据库（.isar）导出成 App 能直接恢复的备份 zip。
//
// 为什么放在 test/ 下：`dart run` 没有 dart:ui，导入 App 的模型会编译失败；
// `flutter test` 的 VM 有完整的 Flutter 环境，所以用测试壳来跑。
//
// 用法：
//   flutter test test/tools/isar_dump_test.dart \
//     --dart-define=ISAR_SRC=/path/to/db.isar \
//     --dart-define=ZIP_OUT=/path/to/out.zip
//
// 场景：设备上 App 数据目录被清掉（卸载/覆盖安装失败），但手里还有一份
// .isar 时，用它把记录/选项/单位/预设/设置/对话还原成 data.json，
// 走 App 的「从备份恢复」重新灌回去。
//
// 注意：照片是独立文件（photos/*.jpg），.isar 里只存文件名，
// 所以这个包里没有图 —— 记录能回来，图要另外找。

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:piecework/data/models/app_setting.dart';
import 'package:piecework/data/models/chat_message.dart';
import 'package:piecework/data/models/filter_preset.dart';
import 'package:piecework/data/models/option_item.dart';
import 'package:piecework/data/models/piece_record.dart';
import 'package:piecework/data/models/unit_item.dart';
import 'package:piecework/data/models/unit_rule.dart';

const String _src = String.fromEnvironment('ISAR_SRC', defaultValue: '');
const String _out = String.fromEnvironment('ZIP_OUT', defaultValue: 'restore.zip');

void main() {
  test('把 isar 导出成可恢复的备份 zip', () async {
    final src = File(_src);
    expect(src.existsSync(), isTrue, reason: '找不到 $_src');

    final dir = src.parent.path;
    final name = src.uri.pathSegments.last.replaceAll('.isar', '');

    await Isar.initializeIsarCore(download: true);

    final isar = await Isar.open(
      <CollectionSchema<dynamic>>[
        PieceRecordSchema,
        OptionItemSchema,
        FilterPresetSchema,
        ChatMessageSchema,
        AppSettingSchema,
        UnitItemSchema,
        UnitRuleSchema,
      ],
      directory: dir,
      name: name,
      inspector: false,
    );

    final records = await isar.pieceRecords.where().findAll();
    final options = await isar.optionItems.where().findAll();
    final presets = await isar.filterPresets.where().findAll();
    final chats = await isar.chatMessages.where().findAll();
    final setting = await isar.appSettings.where().findFirst();
    final unitItems = await isar.unitItems.where().findAll();
    final unitRules = await isar.unitRules.where().findAll();

    final payload = <String, dynamic>{
      'app': 'piecework-backup',
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'records': records.map(_recordToJson).toList(),
      'options': options.map(_optionToJson).toList(),
      'presets': presets.map(_presetToJson).toList(),
      'chatMessages': chats.map(_chatToJson).toList(),
      'settings': setting == null ? null : _settingToJson(setting),
      'unitItems': unitItems.map(_unitItemToJson).toList(),
      'unitRules': unitRules.map(_unitRuleToJson).toList(),
    };

    final jsonBytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)),
    );
    final archive = Archive()
      ..addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));
    final zipped = ZipEncoder().encode(archive);
    expect(zipped, isNotNull, reason: '打包失败');
    File(_out).writeAsBytesSync(zipped!);

    await isar.close();

    final live = records.where((r) => r.deletedAt == null).toList();
    final amount = live.fold<double>(0, (s, r) => s + r.quantity * r.unitPrice);
    final withPhoto = live.where((r) => r.photoName.isNotEmpty).length;

    // ignore: avoid_print
    print('''
== 导出完成 ==
源库      : $_src
输出      : $_out (${File(_out).lengthSync()} bytes)
记录      : ${records.length} 条（未删除 ${live.length}，回收站 ${records.length - live.length}）
金额合计  : ¥${amount.toStringAsFixed(2)}
选项      : ${options.length} 项
单位      : ${unitItems.length} 个 / 换算规则 ${unitRules.length} 条
筛选预设  : ${presets.length} 个
对话消息  : ${chats.length} 条
设置      : ${setting == null ? "无" : "providerId=${setting.aiProviderId} · model=${setting.aiBuiltinModelId}"}
带图记录  : $withPhoto 条（图片文件不在包内）
''');

    expect(records, isNotNull);
  },
      skip: _src.isEmpty
          ? '工具脚本：用 --dart-define=ISAR_SRC=/path/db.isar 指定快照再跑'
          : false,
      timeout: const Timeout(Duration(minutes: 3)));
}

// ── 与 BackupService 的序列化保持一致 ──

Map<String, dynamic> _recordToJson(PieceRecord r) => <String, dynamic>{
      'id': r.id,
      'styleModel': r.styleModel,
      'color': r.color,
      'size': r.size,
      'unit': r.unit,
      'quantity': r.quantity,
      'unitPrice': r.unitPrice,
      'note': r.note,
      'photoName': r.photoName,
      'status': r.status.name,
      'deletedAt': r.deletedAt?.toIso8601String(),
      'reportedAt': r.reportedAt?.toIso8601String(),
      'createdAt': r.createdAt.toIso8601String(),
      'updatedAt': r.updatedAt?.toIso8601String(),
    };

Map<String, dynamic> _optionToJson(OptionItem o) => <String, dynamic>{
      'id': o.id,
      'kind': o.kind.name,
      'value': o.value,
      'sortOrder': o.sortOrder,
      'createdAt': o.createdAt.toIso8601String(),
    };

Map<String, dynamic> _presetToJson(FilterPreset p) => <String, dynamic>{
      'id': p.id,
      'name': p.name,
      'payload': p.payload,
      'createdAt': p.createdAt.toIso8601String(),
    };

Map<String, dynamic> _chatToJson(ChatMessage c) => <String, dynamic>{
      'id': c.id,
      'sessionId': c.sessionId,
      'role': c.role,
      'content': c.content,
      'imageName': c.imageName,
      'filterJson': c.filterJson,
      'statsJson': c.statsJson,
      'actionJson': c.actionJson,
      'toolsJson': c.toolsJson,
      'actionLogId': c.actionLogId,
      'reasoning': c.reasoning,
      'numberWarning': c.numberWarning,
      'promptTokens': c.promptTokens,
      'completionTokens': c.completionTokens,
      'totalTokens': c.totalTokens,
      'createdAt': c.createdAt.toIso8601String(),
    };

Map<String, dynamic> _settingToJson(AppSetting s) => <String, dynamic>{
      'aiBaseUrl': s.aiBaseUrl,
      'aiApiKey': s.aiApiKey,
      'aiModel': s.aiModel,
      'aiSystemPrompt': s.aiSystemPrompt,
      'themeModeIndex': s.themeModeIndex,
      'reportFontScale': s.reportFontScale,
      'reportTitle': s.reportTitle,
      'reportSubtitle': s.reportSubtitle,
      'reportTemplate': s.reportTemplate,
      'reportShowPhoto': s.reportShowPhoto,
      'reportGroupBy': s.reportGroupBy,
      'defaultUnitPrice': s.defaultUnitPrice,
      'lastBackupMs': s.lastBackupMs,
      'chatSessionId': s.chatSessionId,
      'contextWindowTokens': s.contextWindowTokens,
      'aiVisionEnabled': s.aiVisionEnabled,
      'aiThinkingLevel': s.aiThinkingLevel,
      'aiProviderId': s.aiProviderId,
      'aiBuiltinModelId': s.aiBuiltinModelId,
      'aiModelCacheJson': s.aiModelCacheJson,
    };

Map<String, dynamic> _unitItemToJson(UnitItem u) => <String, dynamic>{
      'id': u.id,
      'name': u.name,
      'isBase': u.isBase,
      'sortOrder': u.sortOrder,
      'createdAt': u.createdAt.toIso8601String(),
    };

Map<String, dynamic> _unitRuleToJson(UnitRule r) => <String, dynamic>{
      'id': r.id,
      'fromUnit': r.fromUnit,
      'toUnit': r.toUnit,
      'numerator': r.numerator,
      'denominator': r.denominator,
      'styleModel': r.styleModel,
      'createdAt': r.createdAt.toIso8601String(),
    };
