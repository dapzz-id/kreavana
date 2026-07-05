import 'package:kreavana/services/secure_storage_service.dart';

/// In-memory fake for [SecureStorageService] that avoids native platform channels.
/// Use in unit tests by calling [DioClient.instance.setStorageForTesting(FakeSecureStorage())].
class FakeSecureStorage extends SecureStorageService {
  final Map<String, String?> _store = {};

  @override
  Future<void> saveToken(String token) async {
    _store['access_token'] = token;
  }

  @override
  Future<String?> getToken() async {
    return _store['access_token'];
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    _store['refresh_token'] = token;
  }

  @override
  Future<String?> getRefreshToken() async {
    return _store['refresh_token'];
  }

  @override
  Future<void> saveSessionToken(String token) async {
    _store['session_token'] = token;
  }

  @override
  Future<String?> getSessionToken() async {
    return _store['session_token'];
  }

  @override
  Future<void> saveRefreshCookie(String cookie) async {
    _store['refresh_cookie'] = cookie;
  }

  @override
  Future<String?> getRefreshCookie() async {
    return _store['refresh_cookie'];
  }

  @override
  Future<void> clearRefreshCookie() async {
    _store.remove('refresh_cookie');
  }

  @override
  Future<void> clearAll() async {
    _store.clear();
  }
}
