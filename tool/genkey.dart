import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

String hex(Uint8List b) =>
    b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();

void main() {
  final domain = ECDomainParameters('prime256v1');
  final rnd = Random.secure();
  final seed = Uint8List.fromList(List<int>.generate(32, (_) => rnd.nextInt(256)));
  final secure = SecureRandom('Fortuna')..seed(KeyParameter(seed));
  final gen = ECKeyGenerator()
    ..init(ParametersWithRandom(ECKeyGeneratorParameters(domain), secure));
  final pair = gen.generateKeyPair();
  final priv = pair.privateKey as ECPrivateKey;
  final pub = pair.publicKey as ECPublicKey;
  print('D=${priv.d!.toRadixString(16)}');
  print('QX=${pub.Q!.x!.toBigInteger()!.toRadixString(16)}');
  print('QY=${pub.Q!.y!.toBigInteger()!.toRadixString(16)}');
}
