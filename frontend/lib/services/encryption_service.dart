import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/api.dart' as crypto;
import 'package:pointycastle/key_generators/api.dart';
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'package:pointycastle/random/fortuna_random.dart';

import 'dart:math';
import 'package:rsa_encrypt/rsa_encrypt.dart';
import 'package:uuid/uuid.dart';
import '../services/api_service.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final _secureStorage = const FlutterSecureStorage();
  
  // Storage Keys
  static const String _privateKeyStorageKey = 'e2ee_private_key';
  static const String _publicKeyStorageKey = 'e2ee_public_key';
  static const String _deviceIdStorageKey = 'e2ee_device_id';

  RSAPrivateKey? _privateKey;
  RSAPublicKey? _publicKey;
  String? _deviceId;

  bool get isInitialized => _privateKey != null && _publicKey != null && _deviceId != null;
  String? get publicKeyPem => _publicKey != null ? _encodePublicKeyToPem(_publicKey!) : null;
  String? get deviceId => _deviceId;

  Future<void> initializeKeys() async {
    final privKeyString = await _secureStorage.read(key: _privateKeyStorageKey);
    final pubKeyString = await _secureStorage.read(key: _publicKeyStorageKey);
    _deviceId = await _secureStorage.read(key: _deviceIdStorageKey);

    if (_deviceId == null) {
      _deviceId = const Uuid().v4();
      await _secureStorage.write(key: _deviceIdStorageKey, value: _deviceId);
    }

    if (privKeyString != null && pubKeyString != null) {
      _privateKey = _parsePrivateKeyFromPem(privKeyString);
      _publicKey = _parsePublicKeyFromPem(pubKeyString);
    } else {
      await generateNewKeyPair();
    }
    
    // Always upload public key to ensure backend has it
    if (_publicKey != null) {
      await uploadPublicKey(publicKeyPem!);
    }
  }

  Future<void> uploadPublicKey(String pem) async {
    try {
      await ApiService.put('user/public-key', {'public_key': pem});
      if (_deviceId != null) {
        await ApiService.post('user/devices', {
          'device_id': _deviceId,
          'public_key': pem,
        });
      }
    } catch (e) {
      // Ignore API failure for now as instructed, state remains local.
      print('Warning: Failed to upload public key: $e');
    }
  }

  Future<void> generateNewKeyPair() async {
    // Generate RSA key pair using pointycastle
    final pair = _generateRSAKeyPair();
    _publicKey = pair.publicKey as RSAPublicKey;
    _privateKey = pair.privateKey as RSAPrivateKey;

    final pubPem = _encodePublicKeyToPem(_publicKey!);
    final privPem = _encodePrivateKeyToPem(_privateKey!);

    await _secureStorage.write(key: _privateKeyStorageKey, value: privPem);
    await _secureStorage.write(key: _publicKeyStorageKey, value: pubPem);
  }

  /// Encrypts a message using a one-time AES key, then encrypts the AES key with the receiver's RSA public keys.
  Map<String, dynamic> encryptMessageForMultipleDevices(String plainText, List<Map<String, dynamic>> devices) {
    if (!isInitialized) throw Exception('EncryptionService not initialized');

    // 1. Generate one-time AES key (32 bytes = 256 bits) and IV (16 bytes)
    final aesKey = Key.fromSecureRandom(32);
    final iv = IV.fromSecureRandom(16);

    // 2. Encrypt the message with AES-GCM
    final encrypter = Encrypter(AES(aesKey, mode: AESMode.gcm));
    final encryptedMessage = encrypter.encrypt(plainText, iv: iv);

    // We concatenate IV + AES Key to encrypt them together (16 + 32 = 48 bytes)
    final keyData = Uint8List.fromList([...iv.bytes, ...aesKey.bytes]);

    // 3. Encrypt the AES key with each receiver's RSA public key
    final messageKeys = <Map<String, String>>[];
    for (final device in devices) {
      try {
        final deviceId = device['device_id'] as String?;
        final pubKeyPem = device['public_key'] as String?;
        if (deviceId == null || pubKeyPem == null) continue;

        final receiverPubKey = _parsePublicKeyFromPem(pubKeyPem);
        final rsaEncrypter = Encrypter(RSA(publicKey: receiverPubKey, encoding: RSAEncoding.OAEP));
        final encryptedKey = rsaEncrypter.encryptBytes(keyData);
        
        messageKeys.add({
          'device_id': deviceId,
          'encrypted_key': encryptedKey.base64,
        });
      } catch (e) {
        print('Error encrypting for device: $e');
      }
    }

    // 4. Return payload
    return {
      'encryption_version': 1,
      'ciphertext': encryptedMessage.base64,
      'iv': iv.base64,
      'message_keys': messageKeys,
    };
  }

  /// Decrypts a message using our RSA private key to get the AES key, then decrypts the message.
  String? decryptMessageMultiDevice(String ciphertextBase64, String ivBase64, String encryptedKeyBase64) {
    if (!isInitialized) return null;

    try {
      // 1. Decrypt the AES key + IV using our Private Key
      final rsaEncrypter = Encrypter(RSA(privateKey: _privateKey, encoding: RSAEncoding.OAEP));
      final keyData = rsaEncrypter.decryptBytes(Encrypted.fromBase64(encryptedKeyBase64));

      // KeyData is 16 bytes IV + 32 bytes Key = 48 bytes
      if (keyData.length != 48) return null; // Invalid key data length

      final iv = IV(Uint8List.fromList(keyData.sublist(0, 16)));
      final aesKey = Key(Uint8List.fromList(keyData.sublist(16, 48)));

      // Validate IV matches the one passed
      if (iv.base64 != ivBase64) return null; // IV mismatch

      // 2. Decrypt the actual message
      final encrypter = Encrypter(AES(aesKey, mode: AESMode.gcm));
      return encrypter.decrypt(Encrypted.fromBase64(ciphertextBase64), iv: iv);
    } catch (e) {
      return null;
    }
  }

  // --- Helper Methods ---
  
  RSAPublicKey _parsePublicKeyFromPem(String pem) {
    return RSAKeyParser().parse(pem) as RSAPublicKey;
  }

  RSAPrivateKey _parsePrivateKeyFromPem(String pem) {
    return RSAKeyParser().parse(pem) as RSAPrivateKey;
  }

  String _encodePublicKeyToPem(RSAPublicKey key) {
    return RsaKeyHelper().encodePublicKeyToPemPKCS1(key);
  }

  String _encodePrivateKeyToPem(RSAPrivateKey key) {
    return RsaKeyHelper().encodePrivateKeyToPemPKCS1(key);
  }

  crypto.AsymmetricKeyPair<crypto.PublicKey, crypto.PrivateKey> _generateRSAKeyPair() {
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seeds = List<int>.generate(32, (_) => random.nextInt(256));
    secureRandom.seed(crypto.KeyParameter(Uint8List.fromList(seeds)));

    final keyGen = RSAKeyGenerator()
      ..init(crypto.ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
        secureRandom,
      ));

    return keyGen.generateKeyPair();
  }
}
