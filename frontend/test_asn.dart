import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/api.dart' as crypto;
import 'package:pointycastle/key_generators/api.dart';
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'package:pointycastle/random/fortuna_random.dart';
import 'dart:math';
import 'package:asn1lib/asn1lib.dart';

void main() {
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seeds = List<int>.generate(32, (_) => random.nextInt(256));
    secureRandom.seed(crypto.KeyParameter(Uint8List.fromList(seeds)));

    final keyGen = RSAKeyGenerator()
      ..init(crypto.ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
        secureRandom,
      ));

    final pair = keyGen.generateKeyPair();
    final pubKey = pair.publicKey as RSAPublicKey;
    final privKey = pair.privateKey as RSAPrivateKey;
    
    var topLevelSeq = ASN1Sequence();
    var algorithmSeq = ASN1Sequence();
    var paramsAsn1Obj = ASN1Object.fromBytes(Uint8List.fromList([0x5, 0x0]));
    algorithmSeq.add(ASN1ObjectIdentifier.fromBytes(Uint8List.fromList([0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01])));
    algorithmSeq.add(paramsAsn1Obj);
    
    var publicKeySeq = ASN1Sequence();
    publicKeySeq.add(ASN1Integer(pubKey.modulus!));
    publicKeySeq.add(ASN1Integer(pubKey.exponent!));
    var publicKeyBitString = ASN1BitString(publicKeySeq.encodedBytes);
    
    topLevelSeq.add(algorithmSeq);
    topLevelSeq.add(publicKeyBitString);
    
    var pubPemBase64 = base64.encode(topLevelSeq.encodedBytes);
    var chunks = pubPemBase64.replaceAllMapped(RegExp(r".{1,64}"), (match) => "${match.group(0)}\n");
    print('-----BEGIN PUBLIC KEY-----\n$chunks-----END PUBLIC KEY-----');
}
