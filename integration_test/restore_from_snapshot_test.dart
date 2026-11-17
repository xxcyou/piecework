// 抢救：把 /data/local/tmp/olddb.isar（一份旧的 Isar 快照）里的数据
// 直接灌回当前 App 的数据库，并把等价备份 zip 写到外部目录方便再取一份。
//
// 背景：`flutter test -d <device>` 会装 debug 包（versionCode 1），
// 遇到已装的 release（versionCode 2001）会先卸载 → App 私有目录被删，
// 记录 / 照片 / 自动备份全没了。这个测试负责从快照里把结构化数据捞回来。
//
// 前置：
//   adb push olddb.isar /data/local/tmp/olddb.isar
// 运行：
//   flutter test integration_test/restore_from_snapshot_test.dart -d <device>

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:piecework/data/models/app_setting.dart';
import 'package:piecework/data/models/chat_message.dart';
import 'package:piecework/data/models/filter_preset.dart';
import 'package:piecework/data/models/option_item.dart';
import 'package:piecework/data/models/piece_record.dart';
import 'package:piecework/data/models/unit_item.dart';
import 'package:piecework/data/models/unit_rule.dart';
import 'package:piecework/data/services/backup_service.dart';
import 'package:piecework/main.dart' as app;
import 'package:piecework/providers/db_providers.dart';

const String _snapshotPath = '/data/local/tmp/olddb.isar';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('从 isar 快照恢复数据', (tester) async {
    app.main();
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp).first),
      listen: false,
    );
    final live = container.read(isarProvider);

    late String report;
    await tester.runAsync(() async {
      final snap = File(_snapshotPath);
      if (!snap.existsSync()) {
        throw StateError('快照不存在：$_snapshotPath（先 adb push）');
      }

      final docs = await getApplicationDocumentsDirectory();
      final copy = File(p.join(docs.path, 'oldcopy.isar'));
      copy.writeAsBytesSync(snap.readAsBytesSync());

      final old = await Isar.open(
        <CollectionSchema<dynamic>>[
          PieceRecordSchema,
          OptionItemSchema,
          FilterPresetSchema,
          ChatMessageSchema,
          AppSettingSchema,
          UnitItemSchema,
          UnitRuleSchema,
        ],
        directory: docs.path,
        name: 'oldcopy',
        inspector: false,
      );

      final records = await old.pieceRecords.where().findAll();
      final options = await old.optionItems.where().findAll();
      final presets = await old.filterPresets.where().findAll();
      final chats = await old.chatMessages.where().findAll();
      final setting = await old.appSettings.where().findFirst();
      final unitItems = await old.unitItems.where().findAll();
      final unitRules = await old.unitRules.where().findAll();

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
      final zipped = Uint8List.fromList(ZipEncoder().encode(archive)!);

      // 留一份可再次导入的备份到外部目录（可 adb pull）
      try {
        final ext = await getExternalStorageDirectory();
        if (ext != null) {
          final out = File(p.join(ext.path, 'rescue_backup.zip'));
          out.parent.createSync(recursive: true);
          out.writeAsBytesSync(zipped);
        }
      } catch (_) {
        // 外部目录拿不到也不影响恢复
      }

      await old.close();

      // 灌回当前库
      final rep = await BackupService(live).restore(zipped);

      final after = await live.pieceRecords.where().findAll();
      final amount = after
          .where((r) => r.deletedAt == null)
          .fold<double>(0, (s, r) => s + r.quantity * r.unitPrice);

      report = '''
== 恢复完成 ==
快照记录 : ${records.length} 条
已恢复   : ${rep.records} 条（库内现在 ${after.length} 条）
金额合计 : ¥${amount.toStringAsFixed(2)}
选项     : ${rep.options} 项
单位     : ${unitItems.length} 个 / 规则 ${unitRules.length} 条
预设     : ${rep.presets} 个
对话     : ${rep.chatMessages} 条
''';
      // ignore: avoid_print
      print(report);
      expect(after.isNotEmpty || records.isEmpty, isTrue);
    });

    expect(report.contains('恢复完成'), isTrue);
  }, timeout: const Timeout(Duration(minutes: 5)));
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
