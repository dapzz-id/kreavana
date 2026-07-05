import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keySessionToken = 'session_token';
  static const String _keyRefreshCookie = 'refresh_cookie';

  Future<void> saveToken(String token) async {
    await _storage.write(key: _keyAccessToken, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _keyAccessToken);
  }

  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _keyRefreshToken, value: token);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  Future<void> saveSessionToken(String token) async {
    await _storage.write(key: _keySessionToken, value: token);
  }

  Future<String?> getSessionToken() async {
    return await _storage.read(key: _keySessionToken);
  }

  Future<void> saveRefreshCookie(String cookie) async {
    await _storage.write(key: _keyRefreshCookie, value: cookie);
  }

  Future<String?> getRefreshCookie() async {
    return await _storage.read(key: _keyRefreshCookie);
  }

  Future<void> clearRefreshCookie() async {
    await _storage.delete(key: _keyRefreshCookie);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
