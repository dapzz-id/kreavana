import 'dart:async';
import 'package:dio/dio.dart';
import 'package:kreavana/services/secure_storage_service.dart';
import 'auth_session_state.dart';
import 'dio_client.dart'; // To reuse the baseUrl or we can define it again

class KycDioClient {
  static final KycDioClient instance = KycDioClient._internal();
  late final Dio dio;
  SecureStorageService _secureStorage = SecureStorageService();
  static const String _retriedAfterRefreshKey = 'retried_after_refresh';
  static const String _retryCountKey = 'retry_count';
  static const int _maxRetries = 3;

  void setStorageForTesting(SecureStorageService storage) {
    _secureStorage = storage;
  }

  bool _isRefreshing = false;
  Completer<bool>? _refreshCompleter;

  KycDioClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: DioClient.baseUrl,
        connectTimeout: const Duration(milliseconds: 3000), // Strict 3000ms timeout
        receiveTimeout: const Duration(milliseconds: 3000), // Strict 3000ms timeout
        extra: const {'withCredentials': true},
        headers: {
            'Accept': 'application/json',
            'Connection': 'keep-alive', // Connection pooling
        },
      ),
    );

    // Logging interceptor (Task 11.5)
    dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: true,
      requestBody: true,
      responseHeader: true,
      responseBody: true,
      error: true,
    ));

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (options.path.contains('/auth/refresh')) {
            final refreshCookie = await _secureStorage.getRefreshCookie();
            if (refreshCookie != null && refreshCookie.isNotEmpty) {
              options.headers['Cookie'] = refreshCookie;
            }
          }
          return handler.next(options);
        },
        onResponse: (response, handler) async {
          await _captureRefreshCookie(response);
          return handler.next(response);
        },
        onError: (DioException error, handler) async {
          // Retry logic for timeouts or 5xx errors (Task 11.6)
          if (_shouldRetry(error)) {
            int retryCount = error.requestOptions.extra[_retryCountKey] ?? 0;
            if (retryCount < _maxRetries) {
              retryCount++;
              
              // Exponential backoff
              await Future.delayed(Duration(milliseconds: 500 * retryCount));
              
              try {
                final opts = Options(
                  method: error.requestOptions.method,
                  headers: error.requestOptions.headers,
                  extra: {
                    ...error.requestOptions.extra,
                    _retryCountKey: retryCount,
                  },
                );
                
                final response = await dio.request(
                  error.requestOptions.path,
                  options: opts,
                  data: error.requestOptions.data,
                  queryParameters: error.requestOptions.queryParameters,
                );
                return handler.resolve(response);
              } on DioException catch (e) {
                return handler.next(e);
              }
            }
          }

          // Handle 401 Unauthorized token refresh
          if (error.response?.statusCode == 401) {
            if (error.requestOptions.extra[_retriedAfterRefreshKey] == true) {
              return handler.next(error);
            }

            if (error.requestOptions.path.contains('/auth/refresh') ||
                error.requestOptions.path.contains('/auth/login') ||
                error.requestOptions.path.contains('/auth/register')) {
              return handler.next(error);
            }

            final isRefreshed = await _refreshToken();
            if (isRefreshed) {
              try {
                final token = await _secureStorage.getToken();
                final opts = Options(
                  method: error.requestOptions.method,
                  headers: {
                    ...error.requestOptions.headers,
                    'Authorization': 'Bearer $token',
                  },
                  extra: {
                    ...error.requestOptions.extra,
                    _retriedAfterRefreshKey: true,
                  },
                );
                final response = await dio.request(
                  error.requestOptions.path,
                  options: opts,
                  data: error.requestOptions.data,
                  queryParameters: error.requestOptions.queryParameters,
                );
                return handler.resolve(response);
              } on DioException catch (e) {
                return handler.next(e);
              }
            } else {
              authSignedOutNotifier.value = true;
              await _secureStorage.clearAll();
              return handler.next(error);
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  bool _shouldRetry(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
           error.type == DioExceptionType.sendTimeout ||
           error.type == DioExceptionType.receiveTimeout ||
           (error.response != null && error.response!.statusCode != null && error.response!.statusCode! >= 500);
  }

  Future<bool> _refreshToken() async {
    if (_isRefreshing) {
      return await _refreshCompleter!.future;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();

    try {
      final refreshCookie = await _secureStorage.getRefreshCookie();
      if (refreshCookie == null || refreshCookie.isEmpty) {
        throw Exception("No refresh cookie");
      }

      final refreshDio = Dio(
        BaseOptions(
          baseUrl: DioClient.baseUrl,
          extra: const {'withCredentials': true},
          headers: {'Accept': 'application/json', 'Cookie': refreshCookie},
        ),
      );

      final response = await refreshDio.post('/auth/refresh');

      if (response.statusCode == 200) {
        await _captureRefreshCookie(response);
        final data = response.data['data'];
        await _secureStorage.saveToken(data['access_token']);
        _isRefreshing = false;
        _refreshCompleter!.complete(true);
        return true;
      }
    } catch (e) {
      // Failed to refresh
    }

    _isRefreshing = false;
    _refreshCompleter!.complete(false);
    return false;
  }

  Future<void> _captureRefreshCookie(Response response) async {
    final setCookieHeaders = response.headers.map['set-cookie'];
    if (setCookieHeaders == null || setCookieHeaders.isEmpty) {
      return;
    }

    for (final header in setCookieHeaders) {
      final cookiePart = header.split(';').first.trim();
      if (!cookiePart.startsWith('refresh_token=')) {
        continue;
      }

      final value = cookiePart.substring('refresh_token='.length);
      if (value.isEmpty) {
        await _secureStorage.clearRefreshCookie();
      } else {
        await _secureStorage.saveRefreshCookie(cookiePart);
      }
    }
  }
}
