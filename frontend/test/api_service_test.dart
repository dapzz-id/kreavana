import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:kreavana/services/auth_session_state.dart';
import 'package:kreavana/services/secure_storage_service.dart';
import 'fake_secure_storage.dart';

// ─── Minimal mock adapter ─────────────────────────────────────────────────────

class _MockAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) handler;
  _MockAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions o, _, _) => handler(o);

  @override
  void close({bool force = false}) {}
}

// ─── Isolated DioClient replica (avoids singleton state across tests) ──────────
//
// Because [DioClient] is a singleton (its _internal Dio is built once), the
// tests below reconstruct the *same logic* in a plain [Dio] + [InterceptorsWrapper]
// so each test gets a fresh, fully-isolatable instance.

Dio _buildDio(
  SecureStorageService storage,
  _MockAdapter adapter, {
  required _MockAdapter refreshAdapter,
}) {
  const retriedKey = 'retried_after_refresh';
  bool isRefreshing = false;

  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://fake.host',
      headers: {'Accept': 'application/json'},
    ),
  )..httpClientAdapter = adapter;

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException error, handler) async {
        if (error.response?.statusCode != 401) return handler.next(error);

        // Already retried once — stop.
        if (error.requestOptions.extra[retriedKey] == true) {
          return handler.next(error);
        }

        // Don't retry auth/refresh itself.
        if (error.requestOptions.path.contains('/auth/refresh') ||
            error.requestOptions.path.contains('/auth/login')) {
          return handler.next(error);
        }

        // Attempt refresh using a *separate* Dio whose adapter can be mocked.
        if (isRefreshing) return handler.next(error);
        isRefreshing = true;

        try {
          final cookie = await storage.getRefreshCookie();
          if (cookie == null || cookie.isEmpty) throw Exception('no cookie');

          final refreshDio = Dio(
            BaseOptions(
              baseUrl: 'http://fake.host',
              headers: {'Accept': 'application/json', 'Cookie': cookie},
            ),
          )..httpClientAdapter = refreshAdapter;

          final resp = await refreshDio.post('/auth/refresh');
          if (resp.statusCode == 200) {
            final newToken = resp.data['data']['access_token'] as String;
            await storage.saveToken(newToken);
            isRefreshing = false;

            final opts = Options(
              method: error.requestOptions.method,
              headers: {
                ...error.requestOptions.headers,
                'Authorization': 'Bearer $newToken',
              },
              extra: {...error.requestOptions.extra, retriedKey: true},
            );
            final retried = await dio.request(
              error.requestOptions.path,
              options: opts,
              data: error.requestOptions.data,
              queryParameters: error.requestOptions.queryParameters,
            );
            return handler.resolve(retried);
          }
        } catch (_) {
          // refresh failed
        }

        // Refresh failed → sign out.
        isRefreshing = false;
        authSignedOutNotifier.value = true;
        await storage.clearAll();
        return handler.next(error);
      },
    ),
  );

  return dio;
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    authSignedOutNotifier.value = false;
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Test 1 – happy path: 401 → refresh → retry succeeds
  // ──────────────────────────────────────────────────────────────────────────
  test(
    '401 retry logic: succeeds when refresh returns a new access token',
    () async {
      int protectedCalls = 0;
      int refreshCalls = 0;

      final storage = FakeSecureStorage();
      await storage.saveToken('old_access_token');
      await storage.saveRefreshCookie('refresh_token=valid_refresh');

      final mainAdapter = _MockAdapter((options) async {
        if (options.path.contains('/protected')) {
          protectedCalls++;
          final auth = options.headers['Authorization'] as String? ?? '';
          if (auth == 'Bearer old_access_token') {
            return ResponseBody.fromString(
              '{"status":false,"message":"unauthorized"}',
              401,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          }
          if (auth == 'Bearer new_access_token') {
            return ResponseBody.fromString(
              '{"status":true,"data":"success"}',
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          }
        }
        return ResponseBody.fromString('{}', 404);
      });

      final refreshAdapter = _MockAdapter((options) async {
        if (options.path.contains('/auth/refresh')) {
          refreshCalls++;
          return ResponseBody.fromString(
            '{"status":true,"data":{"access_token":"new_access_token"}}',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        }
        return ResponseBody.fromString('{}', 404);
      });

      final dio = _buildDio(
        storage,
        mainAdapter,
        refreshAdapter: refreshAdapter,
      );
      final response = await dio.get('/protected');

      expect(response.statusCode, 200);
      expect(refreshCalls, 1, reason: 'refresh called exactly once');
      expect(
        protectedCalls,
        2,
        reason: 'initial 401 + successful retry = 2 calls',
      );
      expect(
        await storage.getToken(),
        'new_access_token',
        reason: 'new token stored after refresh',
      );
    },
  );

  // ──────────────────────────────────────────────────────────────────────────
  // Test 2 – single retry limit: even after refresh the 401 is not retried again
  // ──────────────────────────────────────────────────────────────────────────
  test('401 retry limit: request is not retried more than once', () async {
    int protectedCalls = 0;
    int refreshCalls = 0;

    final storage = FakeSecureStorage();
    await storage.saveToken('access_token');
    await storage.saveRefreshCookie('refresh_token=valid_refresh');

    final mainAdapter = _MockAdapter((options) async {
      if (options.path.contains('/protected')) {
        protectedCalls++;
        // Always 401 regardless of token
        return ResponseBody.fromString(
          '{"status":false}',
          401,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      return ResponseBody.fromString('{}', 404);
    });

    final refreshAdapter = _MockAdapter((options) async {
      if (options.path.contains('/auth/refresh')) {
        refreshCalls++;
        return ResponseBody.fromString(
          '{"status":true,"data":{"access_token":"refreshed_token"}}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      return ResponseBody.fromString('{}', 404);
    });

    final dio = _buildDio(storage, mainAdapter, refreshAdapter: refreshAdapter);

    try {
      await dio.get('/protected');
      fail('Expected DioException');
    } on DioException catch (e) {
      expect(e.response?.statusCode, 401);
    }

    expect(refreshCalls, 1, reason: 'refresh called once');
    expect(protectedCalls, 2, reason: 'initial + single retry — no more');
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Test 3 – refresh failure: storage is cleared and signedOut notifier fires
  // ──────────────────────────────────────────────────────────────────────────
  test('refresh failure triggers storage cleanup and signs user out', () async {
    int refreshCalls = 0;

    final storage = FakeSecureStorage();
    await storage.saveToken('old_access_token');
    await storage.saveRefreshCookie('refresh_token=invalid_refresh');

    final mainAdapter = _MockAdapter((options) async {
      if (options.path.contains('/protected')) {
        return ResponseBody.fromString(
          '{"status":false}',
          401,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      return ResponseBody.fromString('{}', 404);
    });

    final refreshAdapter = _MockAdapter((options) async {
      if (options.path.contains('/auth/refresh')) {
        refreshCalls++;
        return ResponseBody.fromString(
          '{"status":false}',
          401,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      return ResponseBody.fromString('{}', 404);
    });

    final dio = _buildDio(storage, mainAdapter, refreshAdapter: refreshAdapter);

    try {
      await dio.get('/protected');
    } on DioException {
      // expected
    }

    // Allow async cleanup
    await Future.delayed(const Duration(milliseconds: 20));

    expect(refreshCalls, 1, reason: 'refresh attempted once');
    expect(
      authSignedOutNotifier.value,
      true,
      reason: 'signedOut notifier set after failed refresh',
    );
    expect(
      await storage.getToken(),
      isNull,
      reason: 'access token cleared from storage',
    );
  });
}
