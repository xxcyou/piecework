library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// AI 助手的离线激活（设备绑定）。
///
/// 方案：**ECDSA P-256 签名**
/// * 设备码 = SHA-256(androidId + 固定盐) 前 8 字节 → `XXXX-XXXX-XXXX-XXXX`
/// * 激活码 = 私钥对设备码的签名（r‖s 各 32 字节）→ Base32 → 每 4 位一个横杠
/// * App 里**只有公钥**，验签通过才算激活
///
/// 为什么不用「设备码算个校验位」那种：那等于把算法放进 App，
/// 任何人反编译就能自己算。这里私钥只在生成器里，App 端无法伪造签名。
// ── 公钥（生成器持有对应私钥；泄露私钥 = 激活码体系失效，注意保管）──
const String _pubX =
    '5f73b34f738a382feb1167bbc866a9852dc19a618838a540b29e789b8e1db37';
const String _pubY =
    '4748ce18e873cd0ca419018c4f0d28c3029dc3cfb0ccb90e4e1d1b5e53bf8354';

/// 设备码固定盐（改这个会让所有已发出的激活码失效）
const String _deviceSalt = 'piecework.ai.license.v1';

/// 激活码里带的前缀版本（换方案时递增，老码自动失效）
const int kLicenseVersion = 1;

/// 把任意长度的字节串转成 32 位大整数（签名的 r/s 用）
Uint8List _fixed32(BigInt v) {
  final out = Uint8List(32);
  final hex = v.toRadixString(16).padLeft(64, '0');
  for (var i = 0; i < 32; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

// ───────────────────────── Base32（RFC4648，无填充）─────────────────────────
const String _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

String base32Encode(List<int> bytes) {
  final out = StringBuffer();
  var buffer = 0;
  var bits = 0;
  for (final b in bytes) {
    buffer = (buffer << 8) | (b & 0xFF);
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      out.write(_alphabet[(buffer >> bits) & 31]);
    }
  }
  if (bits > 0) out.write(_alphabet[(buffer << (5 - bits)) & 31]);
  return out.toString();
}

Uint8List? base32Decode(String input) {
  final s = input.toUpperCase().replaceAll(RegExp(r'[^A-Z2-7]'), '');
  if (s.isEmpty) return null;
  final out = <int>[];
  var buffer = 0;
  var bits = 0;
  for (final ch in s.split('')) {
    final v = _alphabet.indexOf(ch);
    if (v < 0) return null;
    buffer = (buffer << 5) | v;
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      out.add((buffer >> bits) & 0xFF);
    }
  }
  return Uint8List.fromList(out);
}

// ───────────────────────── 设备码 ─────────────────────────

/// 由硬件标识派生设备码：`A1B2-C3D4-E5F6-7890`
String deviceCodeFrom(String rawId) {
  final digest = SHA256Digest()
      .process(Uint8List.fromList(utf8.encode('$rawId|$_deviceSalt')));
  final hex = digest.sublist(0, 8)
      .map((e) => e.toRadixString(16).padLeft(2, '0'))
      .join()
      .toUpperCase();
  return '${hex.substring(0, 4)}-${hex.substring(4, 8)}-'
      '${hex.substring(8, 12)}-${hex.substring(12, 16)}';
}

/// 规范化用户输入（去掉空格/横杠/小写）
String normalizeCode(String code) =>
    code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// 签名覆盖的消息：版本 + 设备码（不含横杠）
String _message(String deviceCode) =>
    'v$kLicenseVersion:${normalizeCode(deviceCode)}';

// ───────────────────────── 验签 ─────────────────────────

/// 校验激活码是否属于这台设备
bool verifyActivationCode(String code, String deviceCode) {
  final payload = normalizeCode(code);
  if (payload.length < 90) return false; // 64 字节 Base32 ≈ 103 位
  final raw = base32Decode(payload);
  if (raw == null || raw.length < 64) return false;
  final r = BigInt.parse(
    raw.sublist(0, 32).map((e) => e.toRadixString(16).padLeft(2, '0')).join(),
    radix: 16,
  );
  final s = BigInt.parse(
    raw.sublist(32, 64).map((e) => e.toRadixString(16).padLeft(2, '0')).join(),
    radix: 16,
  );
  try {
    final domain = ECDomainParameters('prime256v1');
    final q = domain.curve.createPoint(
      BigInt.parse(_pubX, radix: 16),
      BigInt.parse(_pubY, radix: 16),
    );
    final pub = ECPublicKey(q, domain);
    final signer = ECDSASigner(SHA256Digest(), HMac(SHA256Digest(), 64))
      ..init(false, PublicKeyParameter<ECPublicKey>(pub));
    return signer.verifySignature(
      Uint8List.fromList(utf8.encode(_message(deviceCode))),
      ECSignature(r, s),
    );
  } catch (_) {
    return false;
  }
}

/// 生成器用：对设备码签名（私钥只在 keygen 里）
String signDeviceCode(String deviceCode, BigInt privateD) {
  final domain = ECDomainParameters('prime256v1');
  final priv = ECPrivateKey(privateD, domain);
  final signer = ECDSASigner(SHA256Digest(), HMac(SHA256Digest(), 64))
    ..init(true, PrivateKeyParameter<ECPrivateKey>(priv));
  final sig = signer.generateSignature(
    Uint8List.fromList(utf8.encode(_message(deviceCode))),
  ) as ECSignature;
  final bytes = <int>[..._fixed32(sig.r), ..._fixed32(sig.s)];
  final b32 = base32Encode(bytes);
  // 每 4 位一个横杠，肉眼好核对
  final out = StringBuffer();
  for (var i = 0; i < b32.length; i++) {
    if (i > 0 && i % 4 == 0) out.write('-');
    out.write(b32[i]);
  }
  return out.toString();
}
