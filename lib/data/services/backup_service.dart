import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:isar_community/isar.dart';

import '../../core/format.dart';
import '../models/app_setting.dart';
import '../models/chat_message.dart';
import '../models/filter_preset.dart';
import '../models/option_item.dart';
import '../models/piece_record.dart';
import '../models/unit_item.dart';
import '../models/unit_rule.dart';
import 'photo_service.dart';

/// 恢复结果统计
class RestoreReport {
  const RestoreReport({
    required this.records,
    required this.options,
    required this.presets,
    required this.chatMessages,
    required this.photos,
    this.backupCreatedAt,
  });

  final int records;
  final int options;
  final int presets;
  final int chatMessages;
  final int photos;
  final DateTime? backupCreatedAt;

  String get summary =>
      '记录 $records 条 · 选项 $options 项 · 预设 $presets 个 · 对话 $chatMessages 条 · 图片 $photos 张';
}

/// 备份 / 恢复。
///
/// 备份产物是一个 zip：
/// ```
/// data.json          ← 全部结构化数据（记录/选项/预设/设置/对话）
/// photos/xxx.jpg     ← 货物实拍
/// chat_photos/xxx.jpg← AI 对话里用过的图
/// ```
/// 备份文件本身由用户自己选位置保存（下载目录 / 网盘 / 微信传给自己都行），
/// App 不做任何上传。
class BackupService {
  BackupService(this._isar);

  final Isar _isar;

  static const String _magic = 'piecework-backup';
  static const int _version = 1;

  // ───────────────────────────── 备份 ─────────────────────────────

  Future<Uint8List> createBackup() async {
    final records = await _isar.pieceRecords.where().findAll();
    final options = await _isar.optionItems.where().findAll();
    final presets = await _isar.filterPresets.where().findAll();
    final chats = await _isar.chatMessages.where().findAll();
    final setting = await _isar.appSettings.where().findFirst();
    final unitItems = await _isar.unitItems.where().findAll();
    final unitRules = await _isar.unitRules.where().findAll();

    final payload = <String, dynamic>{
      'app': _magic,
      'version': _version,
      'createdAt': DateTime.now().toIso8601String(),
      'records': records.map(_recordToJson).toList(),
      'options': options.map(_optionToJson).toList(),
      'presets': presets.map(_presetToJson).toList(),
      'chatMessages': chats.map(_chatToJson).toList(),
      'settings': setting == null ? null : _settingToJson(setting),
      'unitItems': unitItems.map(_unitItemToJson).toList(),
      'unitRules': unitRules.map(_unitRuleToJson).toList(),
    };

    final jsonBytes =
        Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)));

    final archive = Archive();
    archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));

    // 货物照片：多条记录可能共用同一张图（内容寻址去重），
    // 打包时按文件名去重，避免同一个文件在 zip 里出现多次。
    final packedPhotos = <String>{};
    for (final r in records) {
      if (r.photoName.isEmpty) continue;
      if (!packedPhotos.add(r.photoName)) continue;
      final bytes = await PhotoService.instance.bytesOf(r.photoName);
      if (bytes == null) continue;
      archive.addFile(
        ArchiveFile('photos/${r.photoName}', bytes.length, bytes),
      );
    }

    // 对话照片（同样去重）
    final packedChatPhotos = <String>{};
    for (final c in chats) {
      if (c.imageName.isEmpty) continue;
      if (!packedChatPhotos.add(c.imageName)) continue;
      final bytes = await PhotoService.instance
          .bytesOf(c.imageName, sub: PhotoService.chatDir);
      if (bytes == null) continue;
      archive.addFile(
        ArchiveFile('chat_photos/${c.imageName}', bytes.length, bytes),
      );
    }

    final zipped = ZipEncoder().encode(archive);
    if (zipped == null) {
      throw StateError('备份打包失败（ZipEncoder 返回空）。');
    }

    // 顺手记一下备份时间
    if (setting != null) {
      setting.lastBackupMs = DateTime.now().millisecondsSinceEpoch;
      await _isar.writeTxn(() => _isar.appSettings.put(setting));
    }

    return Uint8List.fromList(zipped);
  }

  static String defaultFileName() => '计件备份_${Fmt.stamp(DateTime.now())}.zip';

  // ───────────────────────────── 恢复 ─────────────────────────────

  Future<RestoreReport> restore(Uint8List zipBytes) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } catch (e) {
      throw FormatException('不是有效的 zip 文件：$e');
    }

    ArchiveFile? dataFile;
    for (final f in archive) {
      if (f.isFile && f.name == 'data.json') {
        dataFile = f;
        break;
      }
    }
    if (dataFile == null) {
      throw const FormatException('备份里找不到 data.json，可能选错了文件。');
    }

    final rawContent = dataFile.content;
    final jsonBytes = rawContent is Uint8List
        ? rawContent
        : Uint8List.fromList(rawContent as List<int>);

    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(jsonBytes));
    } catch (e) {
      throw FormatException('data.json 解析失败：$e');
    }
    if (decoded is! Map) {
      throw const FormatException('data.json 结构异常。');
    }
    final map = decoded.map((k, v) => MapEntry(k.toString(), v));

    if (map['app'] != _magic) {
      throw const FormatException('这不是本应用的备份文件。');
    }

    final records = _asList(map['records']).map(_recordFromJson).toList();
    final options = _asList(map['options']).map(_optionFromJson).toList();
    final presets = _asList(map['presets']).map(_presetFromJson).toList();
    final chats = _asList(map['chatMessages']).map(_chatFromJson).toList();
    final unitItems = _asList(map['unitItems']).map(_unitItemFromJson).toList();
    final unitRules = _asList(map['unitRules']).map(_unitRuleFromJson).toList();
    final settingJson = map['settings'];
    AppSetting? setting;
    if (settingJson is Map) {
      setting =
          _settingFromJson(settingJson.map((k, v) => MapEntry(k.toString(), v)));
      // 复用库里已有那条的 id —— 否则 autoIncrement 会插一条新的，
      // 之后就出现「多条设置、读到旧的」这种灵异现象
      final existing = await _isar.appSettings.where().findAll();
      if (existing.isNotEmpty) {
        existing.sort((a, b) => a.id.compareTo(b.id));
        setting.id = existing.last.id;
      }
    }

    await _isar.writeTxn(() async {
      await _isar.pieceRecords.clear();
      await _isar.optionItems.clear();
      await _isar.filterPresets.clear();
      await _isar.chatMessages.clear();
      await _isar.appSettings.clear();

      await _isar.unitItems.clear();
      await _isar.unitRules.clear();
      await _isar.pieceRecords.putAll(records);
      await _isar.unitItems.putAll(unitItems);
      await _isar.unitRules.putAll(unitRules);
      await _isar.optionItems.putAll(options);
      await _isar.filterPresets.putAll(presets);
      await _isar.chatMessages.putAll(chats);

      if (setting != null) {
        final existing = await _isar.appSettings.where().findFirst();
        if (existing != null) {
          setting.id = existing.id;
        } else {
          setting.id = Isar.autoIncrement;
        }
        await _isar.appSettings.put(setting);
      }
    });

    // 图片：写回私有目录
    var photos = 0;
    for (final f in archive) {
      if (!f.isFile) continue;
      if (f.name.startsWith('photos/')) {
        final name = f.name.substring('photos/'.length);
        if (name.isEmpty || name.contains('/')) continue;
        final c = f.content;
        final bytes = c is Uint8List ? c : Uint8List.fromList(c as List<int>);
        await PhotoService.instance.writeRaw(name, bytes);
        photos++;
      } else if (f.name.startsWith('chat_photos/')) {
        final name = f.name.substring('chat_photos/'.length);
        if (name.isEmpty || name.contains('/')) continue;
        final c = f.content;
        final bytes = c is Uint8List ? c : Uint8List.fromList(c as List<int>);
        await PhotoService.instance
            .writeRaw(name, bytes, sub: PhotoService.chatDir);
        photos++;
      }
    }

    final createdAt = map['createdAt'] is String
        ? DateTime.tryParse(map['createdAt'] as String)
        : null;

    return RestoreReport(
      records: records.length,
      options: options.length,
      presets: presets.length,
      chatMessages: chats.length,
      photos: photos,
      backupCreatedAt: createdAt,
    );
  }

  // ─────────────────────────── 序列化 ───────────────────────────

  static List<Map<String, dynamic>> _asList(Object? v) {
    if (v is List) {
      return v
          .whereType<Map>()
          .map((e) => e.map((k, val) => MapEntry(k.toString(), val)))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  static int _int(Object? v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static double _double(Object? v, [double fallback = 0]) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  static String _str(Object? v) => v is String ? v : '';

  static DateTime _date(Object? v, [DateTime? fallback]) {
    if (v is String) {
      final d = DateTime.tryParse(v);
      if (d != null) return d;
    }
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return fallback ?? DateTime.now();
  }

  static DateTime? _dateOrNull(Object? v) {
    if (v is String) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  static Map<String, dynamic> _unitItemToJson(UnitItem u) => <String, dynamic>{
        'id': u.id,
        'name': u.name,
        'isBase': u.isBase,
        'sortOrder': u.sortOrder,
        'createdAt': u.createdAt.toIso8601String(),
      };

  static UnitItem _unitItemFromJson(Map<String, dynamic> m) {
    final u = UnitItem();
    final id = _int(m['id']);
    u.id = id == 0 ? Isar.autoIncrement : id;
    u.name = _str(m['name']);
    u.isBase = m['isBase'] == true;
    u.sortOrder = _int(m['sortOrder']);
    u.createdAt = _date(m['createdAt']);
    return u;
  }

  static Map<String, dynamic> _unitRuleToJson(UnitRule r) => <String, dynamic>{
        'id': r.id,
        'fromUnit': r.fromUnit,
        'toUnit': r.toUnit,
        'numerator': r.numerator,
        'denominator': r.denominator,
        'styleModel': r.styleModel,
        'createdAt': r.createdAt.toIso8601String(),
      };

  static UnitRule _unitRuleFromJson(Map<String, dynamic> m) {
    final r = UnitRule();
    final id = _int(m['id']);
    r.id = id == 0 ? Isar.autoIncrement : id;
    r.fromUnit = _str(m['fromUnit']);
    r.toUnit = _str(m['toUnit']);
    r.numerator = _int(m['numerator']);
    r.denominator = _int(m['denominator']);
    r.styleModel = _str(m['styleModel']);
    r.createdAt = _date(m['createdAt']);
    return r;
  }

  static Map<String, dynamic> _recordToJson(PieceRecord r) => <String, dynamic>{
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

  static PieceRecord _recordFromJson(Map<String, dynamic> m) {
    final r = PieceRecord();
    final id = _int(m['id']);
    r.id = id == 0 ? Isar.autoIncrement : id;
    r.styleModel = _str(m['styleModel']);
    r.color = _str(m['color']);
    r.size = _str(m['size']);
    r.unit = _str(m['unit']).isEmpty ? '件' : _str(m['unit']);
    r.quantity = _int(m['quantity']);
    r.unitPrice = _double(m['unitPrice']);
    r.note = _str(m['note']);
    r.photoName = _str(m['photoName']);
    r.status = recordStatusFromWire(m['status']);
    r.deletedAt = _dateOrNull(m['deletedAt']);
    r.reportedAt = _dateOrNull(m['reportedAt']);
    r.createdAt = _date(m['createdAt']);
    r.updatedAt = _dateOrNull(m['updatedAt']);
    return r;
  }

  static Map<String, dynamic> _optionToJson(OptionItem o) => <String, dynamic>{
        'id': o.id,
        'kind': o.kind.name,
        'value': o.value,
        'sortOrder': o.sortOrder,
        'createdAt': o.createdAt.toIso8601String(),
      };

  static OptionItem _optionFromJson(Map<String, dynamic> m) {
    final o = OptionItem();
    final id = _int(m['id']);
    o.id = id == 0 ? Isar.autoIncrement : id;
    o.kind = OptionKind.values.firstWhere(
      (k) => k.name == m['kind'],
      orElse: () => OptionKind.styleModel,
    );
    o.value = _str(m['value']);
    o.sortOrder = _int(m['sortOrder']);
    o.createdAt = _date(m['createdAt']);
    return o;
  }

  static Map<String, dynamic> _presetToJson(FilterPreset p) => <String, dynamic>{
        'id': p.id,
        'name': p.name,
        'payload': p.payload,
        'createdAt': p.createdAt.toIso8601String(),
      };

  static FilterPreset _presetFromJson(Map<String, dynamic> m) {
    final p = FilterPreset();
    final id = _int(m['id']);
    p.id = id == 0 ? Isar.autoIncrement : id;
    p.name = _str(m['name']);
    p.payload = _str(m['payload']);
    p.createdAt = _date(m['createdAt']);
    return p;
  }

  static Map<String, dynamic> _chatToJson(ChatMessage c) => <String, dynamic>{
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

  static ChatMessage _chatFromJson(Map<String, dynamic> m) {
    final c = ChatMessage();
    final id = _int(m['id']);
    c.id = id == 0 ? Isar.autoIncrement : id;
    c.sessionId = _int(m['sessionId'], 1);
    c.role = _str(m['role']);
    c.content = _str(m['content']);
    c.imageName = _str(m['imageName']);
    c.filterJson = _str(m['filterJson']);
    c.statsJson = _str(m['statsJson']);
    c.actionJson = _str(m['actionJson']);
    c.toolsJson = _str(m['toolsJson']);
    c.actionLogId = _int(m['actionLogId']);
    c.reasoning = _str(m['reasoning']);
    c.numberWarning = _str(m['numberWarning']);
    c.promptTokens = _int(m['promptTokens']);
    c.completionTokens = _int(m['completionTokens']);
    c.totalTokens = _int(m['totalTokens']);
    c.createdAt = _date(m['createdAt']);
    return c;
  }

  static Map<String, dynamic> _settingToJson(AppSetting s) => <String, dynamic>{
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

  static AppSetting _settingFromJson(Map<String, dynamic> m) {
    final s = AppSetting();
    s.aiBaseUrl = _str(m['aiBaseUrl']).isEmpty ? s.aiBaseUrl : _str(m['aiBaseUrl']);
    s.aiApiKey = _str(m['aiApiKey']);
    s.aiModel = _str(m['aiModel']).isEmpty ? s.aiModel : _str(m['aiModel']);
    s.aiSystemPrompt = _str(m['aiSystemPrompt']);
    s.themeModeIndex = _int(m['themeModeIndex']);
    s.reportFontScale = _double(m['reportFontScale'], 1.0);
    s.reportTitle = _str(m['reportTitle']).isEmpty ? s.reportTitle : _str(m['reportTitle']);
    s.reportSubtitle = _str(m['reportSubtitle']);
    s.reportTemplate = _int(m['reportTemplate']);
    s.reportShowPhoto = m['reportShowPhoto'] != false;
    s.reportGroupBy = _int(m['reportGroupBy']);
    s.defaultUnitPrice = _double(m['defaultUnitPrice']);
    s.lastBackupMs = _int(m['lastBackupMs']);
    s.chatSessionId = _int(m['chatSessionId'], 1);
    s.contextWindowTokens = _int(m['contextWindowTokens'], 8192);
    s.aiVisionEnabled = m['aiVisionEnabled'] == true;
    s.aiThinkingLevel = _int(m['aiThinkingLevel']);
    s.aiProviderId = _str(m['aiProviderId']).isEmpty
        ? 'kilo'
        : _str(m['aiProviderId']);
    s.aiModelCacheJson = _str(m['aiModelCacheJson']);
    s.aiBuiltinModelId = _str(m['aiBuiltinModelId']).isEmpty
        ? 'nvidia/nemotron-3-ultra-550b-a55b:free'
        : _str(m['aiBuiltinModelId']);
    return s;
  }
}
