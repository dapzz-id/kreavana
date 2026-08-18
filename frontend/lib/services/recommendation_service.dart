import 'package:dio/dio.dart';
import '../models/recommendation_creator_model.dart';
import 'dio_client.dart';

class RecommendationResponse {
  final List<RecommendationCreatorModel> data;
  final bool hasMore;
  final int currentPage;

  RecommendationResponse({
    required this.data,
    required this.hasMore,
    required this.currentPage,
  });
}

class RecommendationService {
  static Future<RecommendationResponse> getCreatorRecommendations({
    String? subRole,
    String? category,
    String? region,
    String? startDate,
    String? endDate,
    int page = 1,
    int perPage = 20,
    CancelToken? cancelToken,
  }) async {
    try {
      final Map<String, dynamic> queryParameters = {
        'page': page,
        'per_page': perPage,
      };

      if (subRole != null && subRole.isNotEmpty) {
        queryParameters['sub_role'] = subRole;
      }
      if (category != null && category.isNotEmpty) {
        queryParameters['category'] = category;
      }
      if (region != null && region.isNotEmpty) {
        queryParameters['region'] = region;
      }
      if (startDate != null && startDate.isNotEmpty) {
        queryParameters['start_date'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        queryParameters['end_date'] = endDate;
      }

      final response = await DioClient.instance.dio.get(
        '/creators/recommendations',
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 && response.data['status'] == true) {
        final List<dynamic> rawData = response.data['data'] ?? [];
        final List<RecommendationCreatorModel> creators = rawData
            .map((json) => RecommendationCreatorModel.fromJson(json))
            .toList();

        final meta = response.data['meta'];
        bool hasMore = false;
        int currentPage = page;

        if (meta != null) {
          currentPage = meta['current_page'] ?? page;
          if (meta['has_more'] != null) {
            hasMore = meta['has_more'];
          } else {
            final int lastPage = meta['last_page'] ?? page;
            hasMore = currentPage < lastPage;
          }
        }

        return RecommendationResponse(
          data: creators,
          hasMore: hasMore,
          currentPage: currentPage,
        );
      } else {
        throw Exception(
          response.data['message'] ?? 'Failed to fetch recommendations',
        );
      }
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        throw e; // Let the caller handle cancellation
      }
      throw Exception('Failed to connect to recommendation service: $e');
    }
  }

  static Future<List<String>> getServiceCategories() async {
    try {
      final response = await DioClient.instance.dio.get('/creators/recommendations/categories');
      if (response.statusCode == 200 && response.data['status'] == true) {
        final List<dynamic> rawData = response.data['data'] ?? [];
        return rawData.map((e) => e.toString()).toList();
      } else {
        throw Exception(response.data['message'] ?? 'Failed to fetch categories');
      }
    } catch (e) {
      throw Exception('Failed to connect to recommendation service: $e');
    }
  }
}
