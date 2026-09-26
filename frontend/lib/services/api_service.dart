import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dio_client.dart';

class ApiService {
  static Dio get _dio => DioClient.instance.dio;

  static String get hostIp => Uri.parse(DioClient.baseUrl).host;

  static String get keyPusher => dotenv.env['PUSHER_KEY'] ?? '';

  /// Selesaikan URL gambar aset backend.
  ///
  /// File lama disimpan sebagai `http://host/avatars/file` yang TIDAK punya
  /// CORS headers (dilayani langsung oleh web server). Tulis ulang ke
  /// `http://host/api/avatars/file` sehingga lewat middleware CORS Laravel
  /// dan bisa dimuat dari Flutter Web.
  static String resolveAssetUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    // Relative path handling
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      final base = DioClient.baseUrl.replaceAll('/api', '');
      final cleanPath = url.startsWith('/') ? url : '/$url';
      if (cleanPath.startsWith('/portfolio/')) {
        return '$base/api/portfolio-assets/${cleanPath.replaceFirst('/portfolio/', '')}';
      }
      if (cleanPath.startsWith('/storage/ktp/')) {
        return '$base/api/verification-assets/ktp/${cleanPath.replaceFirst('/storage/ktp/', '')}';
      }
      if (cleanPath.startsWith('/storage/selfie/')) {
        return '$base/api/verification-assets/selfie/${cleanPath.replaceFirst('/storage/selfie/', '')}';
      }
      if (cleanPath.startsWith('/storage/nib/')) {
        return '$base/api/verification-assets/nib/${cleanPath.replaceFirst('/storage/nib/', '')}';
      }
      return '$base$cleanPath';
    }

    // Rewrite localhost/127.0.0.1 to current DioClient.baseUrl when accessing remotely
    if (url.contains('localhost') || url.contains('127.0.0.1')) {
      final base = DioClient.baseUrl.replaceAll('/api', '');
      url = url.replaceFirst(RegExp(r'https?://(localhost|127\.0\.0\.1)(:\d+)?'), base);
    }

    // Rewrite /storage/avatar/file.jpg → /api/avatars/file.jpg
    if (url.contains('/storage/avatar/') && !url.contains('/api/avatars/')) {
      return url.replaceFirst(RegExp(r'/storage/avatar/'), '/api/avatars/');
    }
    // Rewrite /avatars/file.jpg → /api/avatars/file.jpg
    if (url.contains('/avatars/') && !url.contains('/api/avatars/')) {
      return url.replaceFirst('/avatars/', '/api/avatars/');
    }
    // Rewrite /storage/portfolio/file.jpg → /api/portfolio-assets/file.jpg
    if (url.contains('/storage/portfolio/') && !url.contains('/api/portfolio-assets/')) {
      return url.replaceFirst(RegExp(r'/storage/portfolio/'), '/api/portfolio-assets/');
    }
    // Rewrite /storage/ktp/file.jpg → /api/verification-assets/ktp/file.jpg
    if (url.contains('/storage/ktp/') && !url.contains('/api/verification-assets/')) {
      return url.replaceFirst(RegExp(r'/storage/ktp/'), '/api/verification-assets/ktp/');
    }
    // Rewrite /storage/selfie/file.jpg → /api/verification-assets/selfie/file.jpg
    if (url.contains('/storage/selfie/') && !url.contains('/api/verification-assets/')) {
      return url.replaceFirst(RegExp(r'/storage/selfie/'), '/api/verification-assets/selfie/');
    }
    // Rewrite /storage/nib/file.jpg → /api/verification-assets/nib/file.jpg
    if (url.contains('/storage/nib/') && !url.contains('/api/verification-assets/')) {
      return url.replaceFirst(RegExp(r'/storage/nib/'), '/api/verification-assets/nib/');
    }
    return url;
  }

  static String _normalizePath(String endpoint) {
    return endpoint.startsWith('/') ? endpoint : '/$endpoint';
  }

  static Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final response = await _dio.get(
        _normalizePath(endpoint),
        queryParameters: queryParams,
      );
      return _formatResponse(response);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.post(_normalizePath(endpoint), data: body);
      return _formatResponse(response);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  static Future<Map<String, dynamic>> postFormData(
    String endpoint,
    FormData data,
  ) async {
    try {
      final response = await _dio.post(_normalizePath(endpoint), data: data);
      return _formatResponse(response);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  static Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.put(_normalizePath(endpoint), data: body);
      return _formatResponse(response);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  static Future<Map<String, dynamic>> patch(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.patch(_normalizePath(endpoint), data: body);
      return _formatResponse(response);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  static Future<Map<String, dynamic>> delete(
    String endpoint, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.delete(_normalizePath(endpoint), data: data);
      return _formatResponse(response);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  static Map<String, dynamic> _formatResponse(Response response) {
    if (response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      if (!data.containsKey('status')) {
        data['status'] = true;
      }
      return data;
    }
    return {'status': true, 'data': response.data};
  }

  static Map<String, dynamic> _handleError(DioException e) {
    if (e.response != null) {
      final statusCode = e.response!.statusCode;

      if (e.response!.data is Map<String, dynamic>) {
        final data = e.response!.data as Map<String, dynamic>;
        if (!data.containsKey('status')) {
          data['status'] = false;
        }
        return data;
      }

      if (statusCode == 401) {
        return {'status': false, 'message': 'Email atau kata sandi salah.'};
      }

      if (statusCode == 403) {
        return {'status': false, 'message': 'Akses ditolak.'};
      }

      if (e.response!.data is Map<String, dynamic>) {
        final data = e.response!.data as Map<String, dynamic>;
        if (!data.containsKey('status')) {
          data['status'] = false;
        }
        return data;
      }
      return {
        'status': false,
        'message': 'Error ${e.response!.statusCode}',
        'data': e.response!.data,
      };
    }
    return {
      'status': false,
      'message': 'Gagal terhubung ke server',
      'error': e.message,
    };
  }
}
