import 'package:dio/dio.dart';

import 'dio_client.dart';
import '../models/job_contract.dart';
import '../utils/app_errors.dart';

class JobContractService {
  static final Dio _dio = DioClient.instance.dio; // Reusing DioClient instance

  /// Fetch user's job contracts (acting as client or creator)
  static Future<List<JobContract>> getUserContracts({int limit = 50}) async {
    try {
      final response = await _dio.get(
        '/contracts',
        queryParameters: {'limit': limit},
      );

      if (response.data['status'] == 'success' &&
          response.data['data'] != null) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => JobContract.fromJson(json)).toList();
      }

      return [];
    } on DioException catch (e) {
      throw Exception(AppErrors.friendly(e));
    } catch (e) {
      throw Exception('Gagal memuat kontrak kerja: ${e.toString()}');
    }
  }

  /// Create a new job contract (booking a service)
  static Future<JobContract> createContract(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dio.post('/contracts', data: payload);

      if (response.data['status'] == 'success' &&
          response.data['data'] != null) {
        return JobContract.fromJson(response.data['data']);
      }

      throw Exception('Gagal membuat kontrak kerja');
    } on DioException catch (e) {
      throw Exception(AppErrors.friendly(e));
    } catch (e) {
      throw Exception(
        'Terjadi kesalahan saat membuat kontrak: ${e.toString()}',
      );
    }
  }
}
