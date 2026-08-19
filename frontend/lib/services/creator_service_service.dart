import 'package:dio/dio.dart';
import 'dio_client.dart';
import '../models/creator_service.dart';
import '../utils/app_errors.dart';

class CreatorServiceService {
  static final Dio _dio =
      DioClient.instance.dio; // Reusing DioClient instance

  /// Fetch all creator services, optionally filtered by creator_id
  static Future<List<CreatorService>> getServices({String? creatorId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (creatorId != null && creatorId.isNotEmpty) {
        queryParams['creator_id'] = creatorId;
      }

      final response = await _dio.get(
        '/creator-services',
        queryParameters: queryParams,
      );

      if (response.data['status'] == 'success' &&
          response.data['data'] != null) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => CreatorService.fromJson(json)).toList();
      }

      return [];
    } on DioException catch (e) {
      throw Exception(AppErrors.friendly(e));
    } catch (e) {
      throw Exception('Gagal memuat layanan: ${e.toString()}');
    }
  }

  /// Fetch a single creator service detail by ID
  static Future<CreatorService> getServiceById(String id) async {
    try {
      final response = await _dio.get('/creator-services/$id');

      if (response.data['status'] == 'success' &&
          response.data['data'] != null) {
        return CreatorService.fromJson(response.data['data']);
      }

      throw Exception('Data layanan tidak ditemukan');
    } on DioException catch (e) {
      throw Exception(AppErrors.friendly(e));
    } catch (e) {
      throw Exception('Gagal memuat detail layanan: ${e.toString()}');
    }
  }
}
