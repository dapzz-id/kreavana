import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
