import 'dart:async';
import 'package:dio/dio.dart';
import 'package:kreavana/services/secure_storage_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'auth_session_state.dart';
import 'encryption_service.dart';

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
  
  HttpClientAdapter? refreshAdapterForTesting;

  bool _isRefreshing = false;
  Completer<bool>? _refreshCompleter;

  // Change baseUrl according to environment
  static String get baseUrl {
    try {
      if (dotenv.isInitialized) {
        return dotenv.env['API_BASE_URL'] ?? 'http://127.0.0.1:8000/api';
      }
    } catch (_) {}
    return 'http://127.0.0.1:8000/api';
  }

  DioClient._internal() {
    final headers = <String, dynamic>{'Accept': 'application/json'};
    if (!kIsWeb) {
      headers['X-Client-Type'] = 'mobile';
    }

    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        extra: const {'withCredentials': true},
        headers: headers,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          final deviceId = EncryptionService().deviceId;
          if (deviceId != null) {
            options.headers['X-Device-ID'] = deviceId;
          }
          return handler.next(options);
        },
        onResponse: (response, handler) async {
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
      dynamic requestData;
      if (!kIsWeb) {
        final rToken = await _secureStorage.getRefreshToken();
        if (rToken == null || rToken.isEmpty) {
          throw Exception("No refresh token available on mobile");
        }
        requestData = {'refresh_token': rToken};
      }

      final refreshDio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          extra: const {'withCredentials': true},
          headers: {
            'Accept': 'application/json',
            if (!kIsWeb) 'X-Client-Type': 'mobile',
          },
        ),
      );
      
      if (refreshAdapterForTesting != null) {
        refreshDio.httpClientAdapter = refreshAdapterForTesting!;
      }

      final response = await refreshDio.post('/auth/refresh', data: requestData);

      if (response.statusCode == 200 && response.data['status'] == true) {
        final resData = response.data['data'];
        final accessToken = resData['access_token'];
        
        await _secureStorage.saveToken(accessToken);
        
        if (!kIsWeb) {
          final newRefreshToken = resData['refresh_token'];
          if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
            await _secureStorage.saveRefreshToken(newRefreshToken);
          }
        }
        
        _refreshCompleter!.complete(true);
        return true;
      }
    } catch (e) {
      // Failed to refresh due to network or 401
    } finally {
      if (!_refreshCompleter!.isCompleted) {
        _refreshCompleter!.complete(false);
      }
      _isRefreshing = false;
    }

    return false;
  }
}
