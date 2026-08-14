import 'package:flutter_test/flutter_test.dart';
import 'package:kreavana/services/encryption_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/key_generators/api.dart';
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'package:pointycastle/random/fortuna_random.dart';
import 'package:rsa_encrypt/rsa_encrypt.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('EncryptionService E2EE Phase 1', () {
    late EncryptionService encryptionService;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      encryptionService = EncryptionService();
    });

    test('generateNewKeyPair creates real RSA keys and exports PEM properly', () async {
      await encryptionService.initializeKeys();
      
      expect(encryptionService.isInitialized, true);
      expect(encryptionService.publicKeyPem, isNotNull);
      expect(encryptionService.publicKeyPem!.contains('PUBLIC KEY'), true);
      expect(encryptionService.publicKeyPem!.contains('MOCK'), false);
    });

    test('encryptMessageForMultipleDevices returns AES-256-GCM ciphertext and RSA-OAEP envelopes', () async {
      await encryptionService.initializeKeys();
      
      // Generate a manual key pair for Device B to bypass the singleton
      final secureRandom = FortunaRandom();
      final random = Random.secure();
      final seeds = List<int>.generate(32, (_) => random.nextInt(256));
      secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
      final keyGen = RSAKeyGenerator()
        ..init(ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
          secureRandom,
        ));
      final pair = keyGen.generateKeyPair();
      final pubB = RsaKeyHelper().encodePublicKeyToPemPKCS1(pair.publicKey as RSAPublicKey);
      final deviceIdB = 'device-B-123';

      final devices = [
        {'device_id': encryptionService.deviceId, 'public_key': encryptionService.publicKeyPem},
        {'device_id': deviceIdB, 'public_key': pubB},
      ];

      final result = encryptionService.encryptMessageForMultipleDevices('Secret Message', devices);
      
      expect(result['encryption_version'], 1);
      expect(result['ciphertext'], isNotEmpty);
      expect(result['iv'], isNotEmpty);
      
      final keys = result['message_keys'] as List<dynamic>;
      expect(keys.length, 2);
      expect(keys[0]['device_id'], encryptionService.deviceId);
      
      // Attempt decryption with Device A's correct private key
      final decryptedA = encryptionService.decryptMessageMultiDevice(
        result['ciphertext'], 
        result['iv'], 
        keys[0]['encrypted_key']
      );
      expect(decryptedA, 'Secret Message');
      
      // Device A trying to decrypt Device B's envelope should fail safely (returns null, NO plaintext fallback)
      final decryptedFailed = encryptionService.decryptMessageMultiDevice(
        result['ciphertext'], 
        result['iv'], 
        keys[1]['encrypted_key']
      );
      expect(decryptedFailed, isNull);
    });

    test('decryptMessageMultiDevice fails safely on corrupted ciphertext', () async {
      await encryptionService.initializeKeys();
      final devices = [
        {'device_id': encryptionService.deviceId, 'public_key': encryptionService.publicKeyPem},
      ];
      final result = encryptionService.encryptMessageForMultipleDevices('Secret Message', devices);
      final keys = result['message_keys'] as List<dynamic>;
      
      // Corrupt the ciphertext
      final corruptedCiphertext = 'X${result['ciphertext']}';
      final decrypted = encryptionService.decryptMessageMultiDevice(
        corruptedCiphertext, 
        result['iv'], 
        keys[0]['encrypted_key']
      );
      expect(decrypted, isNull); // Must return null, NO plaintext fallback
    });

    test('decryptMessageMultiDevice fails safely on corrupted encrypted_key (RSA-OAEP validation)', () async {
      await encryptionService.initializeKeys();
      final devices = [
        {'device_id': encryptionService.deviceId, 'public_key': encryptionService.publicKeyPem},
      ];
      final result = encryptionService.encryptMessageForMultipleDevices('Secret Message', devices);
      final keys = result['message_keys'] as List<dynamic>;
      
      // Corrupt the envelope key
      final corruptedKey = 'X${keys[0]['encrypted_key']}';
      final decrypted = encryptionService.decryptMessageMultiDevice(
        result['ciphertext'], 
        result['iv'], 
        corruptedKey
      );
      expect(decrypted, isNull);
    });
  });
}
