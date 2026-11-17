import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/data/services/photo_service.dart';
import 'package:piecework/data/services/secure_backup_service.dart';

void main() {
  group('加密备份（AES-256-GCM + PBKDF2）', () {
    final key = SecureBackupService.deriveKey('my-secret-pass');

    test('同一密码派生出同一把密钥（换机/重装能解开旧备份）', () {
      final again = SecureBackupService.deriveKey('my-secret-pass');
      expect(base64Encode(again), base64Encode(key));
      expect(key.length, 32);
    });

    test('不同密码派生不同密钥', () {
      final other = SecureBackupService.deriveKey('my-secret-pass2');
      expect(base64Encode(other), isNot(base64Encode(key)));
    });

    test('加解密往返一致', () {
      final plain = Uint8List.fromList(utf8.encode('计件备份 23 条 ¥1358.77'));
      final blob = SecureBackupService.encryptBytes(plain, key);

      // 文件头是 PWBK + 版本 1
      expect(blob.sublist(0, 5), <int>[0x50, 0x57, 0x42, 0x4B, 0x01]);
      // 密文里不该出现明文
      expect(utf8.decode(blob, allowMalformed: true).contains('计件备份'), isFalse);

      final back = SecureBackupService.decryptBytes(blob, key);
      expect(utf8.decode(back), '计件备份 23 条 ¥1358.77');
    });

    test('密码不对 → 解密失败', () {
      final blob = SecureBackupService.encryptBytes(
        Uint8List.fromList(utf8.encode('hello')),
        key,
      );
      expect(
        () => SecureBackupService.decryptBytes(
          blob,
          SecureBackupService.deriveKey('wrong-pass'),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('文件被改过 → 解密失败（GCM 校验）', () {
      final blob = SecureBackupService.encryptBytes(
        Uint8List.fromList(utf8.encode('hello world')),
        key,
      );
      blob[blob.length - 1] ^= 0xFF;
      expect(
        () => SecureBackupService.decryptBytes(blob, key),
        throwsA(isA<FormatException>()),
      );
    });

    test('不是本 App 的文件 → 明确报错', () {
      final junk = Uint8List.fromList(List<int>.filled(64, 7));
      expect(
        () => SecureBackupService.decryptBytes(junk, key),
        throwsA(isA<FormatException>()),
      );
    });

    test('同一份内容每次加密结果不同（随机 nonce）', () {
      final plain = Uint8List.fromList(utf8.encode('same'));
      final a = SecureBackupService.encryptBytes(plain, key);
      final b = SecureBackupService.encryptBytes(plain, key);
      expect(base64Encode(a), isNot(base64Encode(b)));
      expect(base64Encode(SecureBackupService.decryptBytes(a, key)),
          base64Encode(SecureBackupService.decryptBytes(b, key)));
    });

    test('备份文件名带时间戳且可排序', () {
      final n1 = SecureBackupService.stampName(DateTime(2026, 11, 14, 9, 5, 3));
      final n2 = SecureBackupService.stampName(DateTime(2026, 11, 14, 10, 5, 3));
      expect(n1, 'piecework_backup_20261114_090503.pwb');
      expect(n1.compareTo(n2) < 0, isTrue);
    });
  });

  group('图片内容寻址去重', () {
    test('同一份字节 → 同一个文件名（不重复占空间）', () {
      final a = Uint8List.fromList(List<int>.generate(2048, (i) => i % 251));
      final b = Uint8List.fromList(List<int>.generate(2048, (i) => i % 251));
      expect(PhotoService.contentName(a), PhotoService.contentName(b));
    });

    test('不同字节 → 不同文件名', () {
      final a = Uint8List.fromList(<int>[1, 2, 3, 4]);
      final b = Uint8List.fromList(<int>[1, 2, 3, 5]);
      expect(PhotoService.contentName(a), isNot(PhotoService.contentName(b)));
    });

    test('文件名可作安全路径（无斜杠/空格）', () {
      final n = PhotoService.contentName(Uint8List.fromList(<int>[9, 9, 9]));
      expect(RegExp(r'^c[0-9a-f]{32}\.jpg$').hasMatch(n), isTrue);
    });
  });
}
