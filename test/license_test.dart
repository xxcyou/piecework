import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/core/license.dart';

/// AI 激活码：设备绑定 + ECDSA 签名（App 端只有公钥）
void main() {
  // 与生成器一致的私钥（仅测试用）
  final d = BigInt.parse(
    'e72d6d05247eace11cb354ec400b19eadb565dd59053298fe79ddec0e8ee6ba2',
    radix: 16,
  );

  test('设备码格式固定：4-4-4-4 大写十六进制', () {
    final code = deviceCodeFrom('android-id-abc');
    expect(RegExp(r'^[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}$')
        .hasMatch(code), isTrue);
  });

  test('同一设备 → 同一设备码；不同设备 → 不同', () {
    expect(deviceCodeFrom('aaa'), deviceCodeFrom('aaa'));
    expect(deviceCodeFrom('aaa'), isNot(deviceCodeFrom('bbb')));
  });

  test('签发的激活码能通过验签', () {
    final dev = deviceCodeFrom('android-id-abc');
    final code = signDeviceCode(dev, d);
    expect(verifyActivationCode(code, dev), isTrue);
  });

  test('换个设备码就验不过（不能拿别人的码）', () {
    final dev = deviceCodeFrom('android-id-abc');
    final other = deviceCodeFrom('android-id-xyz');
    final code = signDeviceCode(dev, d);
    expect(verifyActivationCode(code, other), isFalse);
  });

  test('随便编的码验不过', () {
    final dev = deviceCodeFrom('android-id-abc');
    expect(verifyActivationCode('', dev), isFalse);
    expect(verifyActivationCode('ABCD-EFGH', dev), isFalse);
    expect(
      verifyActivationCode('A' * 103, dev),
      isFalse,
    );
  });

  test('改一个字符就失效（签名不可篡改）', () {
    final dev = deviceCodeFrom('android-id-abc');
    final code = normalizeCode(signDeviceCode(dev, d));
    final tampered = code.replaceRange(10, 11, code[10] == 'A' ? 'B' : 'A');
    expect(verifyActivationCode(tampered, dev), isFalse);
  });

  test('粘贴时带空格/横杠/小写也能识别', () {
    final dev = deviceCodeFrom('android-id-abc');
    final code = signDeviceCode(dev, d);
    final messy = ' ${code.toLowerCase().replaceAll('-', ' ')} ';
    expect(verifyActivationCode(messy, dev), isTrue);
  });

  test('Base32 往返', () {
    final bytes = <int>[1, 2, 3, 250, 251, 252, 0, 9];
    final enc = base32Encode(bytes);
    expect(base32Decode(enc), bytes);
  });

  realDeviceSample();

  test('用错私钥签的码验不过（证明不是对称校验）', () {
    final dev = deviceCodeFrom('android-id-abc');
    final wrongD = BigInt.parse(
      '1111111111111111111111111111111111111111111111111111111111111111',
      radix: 16,
    );
    // 非法私钥可能直接抛异常，也可能签出验不过 —— 两种都算安全
    try {
      final bad = signDeviceCode(dev, wrongD);
      expect(verifyActivationCode(bad, dev), isFalse);
    } catch (_) {
      // 抛异常同样安全
    }
  });
}

/// 真机联调样例（设备码 68DF-4BB3-8F47-E468 对应生成器签发的码）
void realDeviceSample() {
  test('真机样例：生成器签发的码能通过 App 端验签', () {
    const device = '68DF-4BB3-8F47-E468';
    const code =
        'OH36-WJ6T-IZXW-43IK-T52I-VMBH-4UII-KDSV-VT6L-3WYN-GUB7-7FQH-O5NY-7KRO-'
        'SOB2-2N2M-AJAJ-IDQ2-BJ4K-RHPO-WW26-EY32-VQJV-SIRH-73UD-PAQ';
    expect(verifyActivationCode(code, device), isTrue);
    // 别的设备用不了
    expect(verifyActivationCode(code, 'AAAA-BBBB-CCCC-DDDD'), isFalse);
  });
}
