import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kreavana/services/dio_client.dart';
import 'package:kreavana/services/secure_storage_service.dart';
import 'package:kreavana/services/auth_session_state.dart';

class MockSecureStorage implements SecureStorageService {
  String? _accessToken;
  String? _refreshToken;
  String? _sessionToken;
  String? _refreshCookie;

  @override
  Future<void> saveToken(String token) async => _accessToken = token;

  @override
  Future<String?> getToken() async => _accessToken;

  @override
  Future<void> saveRefreshToken(String token) async => _refreshToken = token;

  @override
  Future<String?> getRefreshToken() async => _refreshToken;

  @override
  Future<void> saveSessionToken(String token) async => _sessionToken = token;

  @override
  Future<String?> getSessionToken() async => _sessionToken;

  @override
  Future<void> saveRefreshCookie(String cookie) async =>
      _refreshCookie = cookie;

  @override
  Future<String?> getRefreshCookie() async => _refreshCookie;

  @override
  Future<void> clearRefreshCookie() async => _refreshCookie = null;

  @override
  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    _sessionToken = null;
    _refreshCookie = null;
  }

  @override
  Future<void> clearAll() async {
    _accessToken = null;
    _refreshToken = null;
    _sessionToken = null;
    _refreshCookie = null;
  }
}

class MockAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) onFetch;
  MockAdapter(this.onFetch);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return await onFetch(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late MockSecureStorage mockStorage;
  late Dio dio;
  int refreshCallCount = 0;
  bool shouldRefreshSucceed = true;
  bool wasLoggedOut = false;

  setUp(() {
    mockStorage = MockSecureStorage();
    mockStorage.saveToken('old_access_token');
    mockStorage.saveRefreshToken('old_refresh_token');

    DioClient.instance.setStorageForTesting(mockStorage);
    dio = DioClient.instance.dio;
    authSignedOutNotifier.value = false;
    refreshCallCount = 0;
    shouldRefreshSucceed = true;
    wasLoggedOut = false;

    authSignedOutNotifier.addListener(() {
      wasLoggedOut = authSignedOutNotifier.value;
    });

    // Mock the main API requests
    dio.httpClientAdapter = MockAdapter((options) async {
      // For any normal request, return 401 if using old token
      if (options.headers['Authorization'] == 'Bearer old_access_token') {
        return ResponseBody.fromString(
          jsonEncode({'message': 'Unauthorized'}),
          401,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }

      // If retried with new token, succeed
      if (options.headers['Authorization'] == 'Bearer new_access_token') {
        return ResponseBody.fromString(
          jsonEncode({'status': true, 'data': 'success_data'}),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }

      // If retried with invalid token, fail
      return ResponseBody.fromString(
        jsonEncode({'message': 'Unauthorized'}),
        401,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });

    // Mock the Refresh request
    DioClient.instance.refreshAdapterForTesting = MockAdapter((options) async {
      refreshCallCount++;
      // Simulate network delay to ensure single-flight blocks work
      await Future.delayed(const Duration(milliseconds: 50));

      if (shouldRefreshSucceed) {
        return ResponseBody.fromString(
          jsonEncode({
            'status': true,
            'data': {
              'access_token': 'new_access_token',
              'refresh_token': 'new_refresh_token',
            },
          }),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      } else {
        return ResponseBody.fromString(
          jsonEncode({'status': false, 'message': 'Refresh Failed'}),
          401,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
    });
  });

  test(
    'Concurrent 401s produce exactly ONE refresh request and retry all',
    () async {
      // Send 3 concurrent requests
      final futures = <Future<Response>>[
        dio.get('/api/test1'),
        dio.get('/api/test2'),
        dio.get('/api/test3'),
      ];

      final responses = await Future.wait(futures);

      // Verify all 3 requests eventually succeeded
      for (final res in responses) {
        expect(res.statusCode, 200);
        expect(res.data['data'], 'success_data');
      }

      // Verify refresh was only called ONCE
      expect(refreshCallCount, 1);

      // Verify secure storage was updated
      expect(await mockStorage.getToken(), 'new_access_token');
      expect(await mockStorage.getRefreshToken(), 'new_refresh_token');
    },
  );

  test('Failed refresh releases waiting requests and forces logout', () async {
    shouldRefreshSucceed = false; // Force refresh to fail

    // Send 2 concurrent requests
    final futures = <Future>[dio.get('/api/test1'), dio.get('/api/test2')];

    try {
      await Future.wait(futures);
    } catch (e) {
      // Should throw DioException 401
      expect(e, isA<DioException>());
    }

    // Verify refresh was only called ONCE
    expect(refreshCallCount, 1);

    // Verify secure storage was cleared
    expect(await mockStorage.getToken(), null);
    expect(await mockStorage.getRefreshToken(), null);

    // Verify authSignedOutNotifier was triggered
    expect(wasLoggedOut, true);
  });
}
