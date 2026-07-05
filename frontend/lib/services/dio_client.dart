import 'dart:async';
import 'package:dio/dio.dart';
import 'package:kreavana/services/secure_storage_service.dart';
import 'auth_session_state.dart';

class DioClient {
  static final DioClient instance = DioClient._internal();
  late final Dio dio;
  SecureStorageService _secureStorage = SecureStorageService();
  static const String _retriedAfterRefreshKey = 'retried_after_refresh';

  // Allow tests to inject a fake storage without native plugin
  // ignore: use_setters_to_change_properties
  void setStorageForTesting(SecureStorageService storage) {
    _secureStorage = storage;
  }

  bool _isRefreshing = false;
  Completer<bool>? _refreshCompleter;

  // Change baseUrl according to environment
  // static const String baseUrl = 'http://10.112.174.165:8000/api';
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  DioClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        extra: const {'withCredentials': true},
        headers: {'Accept': 'application/json'},
      ),
    );

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
          if (error.response?.statusCode == 401) {
            if (error.requestOptions.extra[_retriedAfterRefreshKey] == true) {
              return handler.next(error);
            }

            // If the refresh token request itself returns 401, force logout
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
              // Refresh failed, force logout
              authSignedOutNotifier.value = true;
              await _secureStorage.clearAll();
              // TODO: Navigate to login screen
              return handler.next(error);
            }
          }
          return handler.next(error);
        },
      ),
    );
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
          baseUrl: baseUrl,
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
