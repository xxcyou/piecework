import 'package:isar_community/isar.dart';

import '../models/piece_record.dart';

/// 记录 ↔ JSON。操作日志的快照、备份都靠它。
class RecordCodec {
  RecordCodec._();

  static Map<String, dynamic> toJson(PieceRecord r) => <String, dynamic>{
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
        'reportedAt': r.reportedAt?.toIso8601String(),
        'deletedAt': r.deletedAt?.toIso8601String(),
        'createdAt': r.createdAt.toIso8601String(),
        'updatedAt': r.updatedAt?.toIso8601String(),
      };

  static PieceRecord fromJson(Map<String, dynamic> m) {
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
    r.status = m['status'] == 'reported'
        ? RecordStatus.reported
        : RecordStatus.pending;
    r.reportedAt = _dateOrNull(m['reportedAt']);
    r.deletedAt = _dateOrNull(m['deletedAt']);
    r.createdAt = _date(m['createdAt']);
    r.updatedAt = _dateOrNull(m['updatedAt']);
    return r;
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
}
