import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'api_service.dart';

class MarketplaceService {
  static Future<Map<String, dynamic>> getItems({
    String? category,
    String? search,
    String sort = 'latest',
    int page = 1,
    int perPage = 20,
  }) async {
    final params = <String, String>{
      'sort': sort,
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    final normalizedCategory = (category ?? '').trim();
    if (normalizedCategory.isNotEmpty && normalizedCategory.toLowerCase() != 'semua') {
      params['category'] = normalizedCategory;
    }
    if (search != null && search.isNotEmpty) params['search'] = search;

    final qs = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    final result = await ApiService.get('marketplace?$qs');
    return result;
  }

  static Future<Map<String, dynamic>> getFeatured() async {
    return await ApiService.get('marketplace/featured');
  }

  static Future<Map<String, dynamic>> getCategories() async {
    return await ApiService.get('marketplace/categories');
  }

  static Future<Map<String, dynamic>> getCategory(String? category, String? search, String sort, int page) async {
    return await getItems(category: category, search: search, sort: sort, page: page);
  }

  static Future<Map<String, dynamic>> getItem(String id) async {
    return await ApiService.get('marketplace/$id');
  }

  static Future<Map<String, dynamic>> createItem({
    required String title,
    String? description,
    required String category,
    required String type,
    required double price,
    List<PlatformFile>? media,
  }) async {
    final formData = FormData.fromMap({
      'title': title,
      'description': description ?? '',
      'category': category,
      'type': type,
      'price': price,
    });

    if (media != null && media.isNotEmpty) {
      for (var i = 0; i < media.length; i++) {
        final file = media[i];
        if (file.bytes != null) {
          formData.files.add(MapEntry(
            'media[]',
            MultipartFile.fromBytes(file.bytes!, filename: file.name),
          ));
        } else if (file.path != null) {
          formData.files.add(MapEntry(
            'media[]',
            await MultipartFile.fromFile(file.path!, filename: file.name),
          ));
        }
      }
    }

    return await ApiService.postFormData('marketplace', formData);
  }

  static Future<Map<String, dynamic>> submitReview({
    required String itemId,
    required int rating,
    String? comment,
  }) async {
    return await ApiService.post('marketplace/$itemId/review', {
      'rating': rating,
      'comment': comment,
    });
  }

  static Future<Map<String, dynamic>> purchaseItem(String id, {required String pin}) async {
    return await ApiService.post('marketplace/$id/purchase', {
      'pin': pin,
    });
  }
}
