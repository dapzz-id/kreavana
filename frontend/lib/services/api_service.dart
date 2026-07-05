import 'package:dio/dio.dart';
import 'dio_client.dart';

class ApiService {
  static Dio get _dio => DioClient.instance.dio;

  static String get hostIp => Uri.parse(DioClient.baseUrl).host;

  static String get keyPusher => 'cuzkfya73cpnszss3vc2';

  static Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final response = await _dio.get(
        '/$endpoint',
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
      final response = await _dio.post('/$endpoint', data: body);
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
      final response = await _dio.put('/$endpoint', data: body);
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
      final response = await _dio.patch('/$endpoint', data: body);
      return _formatResponse(response);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  static Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final response = await _dio.delete('/$endpoint');
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

      if (statusCode == 401) {
        return {
          'status': false,
          'message': 'Sesi tidak valid. Silakan masuk kembali.',
        };
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
