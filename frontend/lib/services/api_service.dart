import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../screens/login_screen.dart';

class ApiService {
  static final http.Client _client = http.Client();

  /// Timeout agar UI tidak menunggu terlalu lama saat server offline.
  static const Duration requestTimeout = Duration(seconds: 10);

  /// Override saat build: --dart-define=API_HOST=192.168.x.x
  static const String _hostOverride = String.fromEnvironment(
    'API_HOST',
    defaultValue: '',
  );

  static const int apiPort = 8000;
  static const String keyPusher = 'cuzkfya73cpnszss3vc2';

  /// Host backend otomatis per platform (Laragon/Windows = localhost).
  static String get hostIp {
    if (_hostOverride.isNotEmpty) return _hostOverride;

    if (kIsWeb) return '127.0.0.1';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Emulator Android → host PC. Perangkat fisik: set API_HOST via dart-define.
        return '10.0.2.2';
      case TargetPlatform.iOS:
        return '127.0.0.1';
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return '127.0.0.1';
      default:
        return '127.0.0.1';
    }
  }

  static String get baseUrl => 'http://$hostIp:$apiPort/api';

  static bool _isRefreshing = false;

  static String _connectionErrorMessage(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('timeout') ||
        text.contains('semaphore') ||
        text.contains('connection refused') ||
        text.contains('failed host lookup') ||
        text.contains('network is unreachable') ||
        text.contains('socketexception')) {
      return 'Tidak dapat terhubung ke server Kreavana.\n'
          'Pastikan backend sudah jalan:\n'
          'php artisan serve --host=0.0.0.0 --port=$apiPort\n'
          '(Host: $hostIp:$apiPort)';
    }
    return 'Koneksi gagal. Periksa internet dan pastikan server backend aktif.';
  }

  static Future<bool> _refreshToken() async {
    if (_isRefreshing) return false;
    _isRefreshing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final oldToken = prefs.getString('auth_token') ?? '';

      final uri = Uri.parse('$baseUrl/auth/refresh');
      final response = await _client
          .post(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $oldToken',
            },
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final newTokens = data['data'];
          await prefs.setString(
            'auth_token',
            newTokens['access_token'] ?? newTokens['token'] ?? '',
          );
          await prefs.setString(
            'refresh_token',
            newTokens['refresh_token'] ?? '',
          );
          if (newTokens['session_token'] != null) {
            await prefs.setString('session_token', newTokens['session_token']);
          }
          _isRefreshing = false;
          return true;
        }
      }
    } catch (_) {}
    _isRefreshing = false;
    await _forceLogout();
    return false;
  }

  static Future<void> _forceLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    await prefs.remove('session_token');
    await prefs.remove('user_data');

    if (navigatorKey.currentContext != null) {
      Navigator.of(navigatorKey.currentContext!).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<dynamic> _request(
    String method,
    String endpoint, {
    Map<String, String>? queryParams,
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/$endpoint').replace(
        queryParameters: queryParams,
      );

      Future<http.Response> makeCall(Map<String, String> headers) {
        switch (method) {
          case 'POST':
            return _client
                .post(uri, headers: headers, body: jsonEncode(body))
                .timeout(requestTimeout);
          case 'PUT':
            return _client
                .put(uri, headers: headers, body: jsonEncode(body))
                .timeout(requestTimeout);
          case 'PATCH':
            return _client
                .patch(uri, headers: headers, body: jsonEncode(body))
                .timeout(requestTimeout);
          case 'DELETE':
            return _client.delete(uri, headers: headers).timeout(requestTimeout);
          case 'GET':
          default:
            return _client.get(uri, headers: headers).timeout(requestTimeout);
        }
      }

      final headers = await _getHeaders();
      final response = await makeCall(headers);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.body.isNotEmpty
            ? jsonDecode(response.body)
            : {'success': true};
      } else if (response.statusCode == 401) {
        if (endpoint != 'auth/refresh') {
          final refreshed = await _refreshToken();
          if (refreshed) {
            final newHeaders = await _getHeaders();
            final retryResponse = await makeCall(newHeaders);
            if (retryResponse.statusCode >= 200 &&
                retryResponse.statusCode < 300) {
              return retryResponse.body.isNotEmpty
                  ? jsonDecode(retryResponse.body)
                  : {'success': true};
            }
          }
        }
        return {
          'success': false,
          'message': 'Sesi telah habis, silakan login kembali.',
        };
      } else {
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map) {
            if (decoded['message'] != null) {
              return {
                'success': false,
                'message': decoded['message'].toString(),
              };
            }
            if (decoded['errors'] is Map) {
              final errors = decoded['errors'] as Map;
              final first = errors.values.first;
              final msg = first is List ? first.first.toString() : first.toString();
              return {'success': false, 'message': msg};
            }
          }
        } catch (_) {}
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': _connectionErrorMessage(e),
      };
    }
  }

  static Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) {
    return _request('GET', endpoint, queryParams: queryParams);
  }

  static Future<dynamic> post(String endpoint, Map<String, dynamic> body) {
    return _request('POST', endpoint, body: body);
  }

  static Future<dynamic> put(String endpoint, Map<String, dynamic> body) {
    return _request('PUT', endpoint, body: body);
  }

  static Future<dynamic> patch(String endpoint, Map<String, dynamic> body) {
    return _request('PATCH', endpoint, body: body);
  }

  static Future<dynamic> delete(String endpoint) {
    return _request('DELETE', endpoint);
  }
}
