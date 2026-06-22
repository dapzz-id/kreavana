import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../screens/login_screen.dart';

class ApiService {
  static final http.Client _client = http.Client();

  // Secara dinamis mendeteksi platform:
  // - Flutter Web / Windows / macOS: menggunakan localhost:8000 (Laravel Default)
  // - Android Emulator: menggunakan 10.0.2.2:8000
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000/api';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://localhost:8000/api';
  }

  static bool _isRefreshing = false;

  static Future<bool> _refreshToken() async {
    if (_isRefreshing) return false;
    _isRefreshing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final oldToken = prefs.getString('auth_token') ?? '';
      
      final uri = Uri.parse('$baseUrl/auth/refresh');
      final response = await _client.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $oldToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final newTokens = data['data'];
          await prefs.setString('auth_token', newTokens['access_token'] ?? newTokens['token'] ?? '');
          await prefs.setString('refresh_token', newTokens['refresh_token'] ?? '');
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

  static Future<dynamic> get(String endpoint,
      {Map<String, String>? queryParams}) async {
    try {
      final uri = Uri.parse('$baseUrl/$endpoint').replace(
        queryParameters: queryParams,
      );
      final headers = await _getHeaders();
      final response = await _client.get(uri, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        if (endpoint != 'auth/refresh') {
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Retry request
            final newHeaders = await _getHeaders();
            final retryResponse = await _client.get(uri, headers: newHeaders);
            if (retryResponse.statusCode == 200) {
              return jsonDecode(retryResponse.body);
            }
          }
        }
        return {
          'success': false,
          'message': 'Sesi telah habis, silakan login kembali.',
        };
      } else {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Koneksi gagal: $e',
      };
    }
  }

  static Future<dynamic> post(
      String endpoint, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$baseUrl/$endpoint');
      final headers = await _getHeaders();
      final response = await _client.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        if (endpoint != 'auth/refresh') {
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Retry request
            final newHeaders = await _getHeaders();
            final retryResponse = await _client.post(uri, headers: newHeaders, body: jsonEncode(body));
            if (retryResponse.statusCode == 200 || retryResponse.statusCode == 201) {
              return jsonDecode(retryResponse.body);
            }
          }
        }
        return {
          'success': false,
          'message': 'Sesi telah habis, silakan login kembali.',
        };
      } else {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Koneksi gagal: $e',
      };
    }
  }

  static Future<dynamic> put(
      String endpoint, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$baseUrl/$endpoint');
      final headers = await _getHeaders();
      final response = await _client.put(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        if (endpoint != 'auth/refresh') {
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Retry request
            final newHeaders = await _getHeaders();
            final retryResponse = await _client.put(uri, headers: newHeaders, body: jsonEncode(body));
            if (retryResponse.statusCode == 200 || retryResponse.statusCode == 201) {
              return jsonDecode(retryResponse.body);
            }
          }
        }
        return {
          'success': false,
          'message': 'Sesi telah habis, silakan login kembali.',
        };
      } else {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Koneksi gagal: $e',
      };
    }
  }

  static Future<dynamic> delete(String endpoint) async {
    try {
      final uri = Uri.parse('$baseUrl/$endpoint');
      final headers = await _getHeaders();
      final response = await _client.delete(uri, headers: headers);

      if (response.statusCode == 200 || response.statusCode == 204) {
        return response.body.isNotEmpty ? jsonDecode(response.body) : {'success': true};
      } else if (response.statusCode == 401) {
        if (endpoint != 'auth/refresh') {
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Retry request
            final newHeaders = await _getHeaders();
            final retryResponse = await _client.delete(uri, headers: newHeaders);
            if (retryResponse.statusCode == 200 || retryResponse.statusCode == 204) {
              return retryResponse.body.isNotEmpty ? jsonDecode(retryResponse.body) : {'success': true};
            }
          }
        }
        return {
          'success': false,
          'message': 'Sesi telah habis, silakan login kembali.',
        };
      } else {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Koneksi gagal: $e',
      };
    }
  }
}
