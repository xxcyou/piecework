import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/data/services/device_backup_service.dart';

/// 免设置自动备份：加密/解密往返 + 文件头校验
void main() {
  final svc = DeviceBackupService.instance;

  test('加密后能解回原文（AES-256-GCM）', () async {
    final plain = Uint8List.fromList(utf8.encode('计件备份内容 abc123'));
    final enc = await svc.encryptBytes(plain);
    // 文件头 PWBK v1
    expect(enc.sublist(0, 5), <int>[0x50, 0x57, 0x42, 0x4B, 0x01]);
    expect(enc.length, greaterThan(plain.length));
    final back = await svc.decryptBytes(enc);
    expect(utf8.decode(back), '计件备份内容 abc123');
  });

  test('两次加密结果不同（随机 IV）', () async {
    final plain = Uint8List.fromList(utf8.encode('same'));
    final a = await svc.encryptBytes(plain);
    final b = await svc.encryptBytes(plain);
    expect(a, isNot(b));
  });

  test('不是本 App 的文件直接拒绝', () async {
    final junk = Uint8List.fromList(List<int>.filled(40, 7));
    expect(() => svc.decryptBytes(junk), throwsA(isA<FormatException>()));
  });

  test('被篡改的密文解不开', () async {
    final enc = await svc.encryptBytes(Uint8List.fromList(utf8.encode('x')));
    enc[enc.length - 1] ^= 0xFF;
    expect(() => svc.decryptBytes(enc), throwsA(anything));
  });

  test('文件名格式固定，便于排序与清理', () {
    expect(DeviceBackupService.prefix, 'piecework_auto_');
    expect(DeviceBackupService.ext, '.pwb');
    expect(DeviceBackupService.keepCount, 5);
  });
}
