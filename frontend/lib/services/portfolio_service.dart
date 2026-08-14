import 'dart:io';
import 'package:dio/dio.dart';
import '../services/dio_client.dart';

class PortfolioItemModel {
  final dynamic id;
  final String title;
  final String? category;
  final String? description;
  final String? imageUrl;
  final int sortOrder;

  PortfolioItemModel({
    this.id,
    required this.title,
    this.category,
    this.description,
    this.imageUrl,
    this.sortOrder = 0,
  });

  factory PortfolioItemModel.fromJson(Map<String, dynamic> json) {
    return PortfolioItemModel(
      id: json['id'],
      title: json['title'] ?? '',
      category: json['category'],
      description: json['description'],
      imageUrl: json['image_url'],
      sortOrder: json['sort_order'] ?? 0,
    );
  }
}

class PortfolioService {
  static Dio get _dio => DioClient.instance.dio;

  static Future<List<PortfolioItemModel>> getPortfolio() async {
    try {
      final response = await _dio.get('/portfolio');
      final data = response.data;
      if (data['status'] == true) {
        final List items = data['data'] ?? [];
        return items.map((e) => PortfolioItemModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<PortfolioItemModel?> addPortfolio({
    required String title,
    String? category,
    String? description,
    required File imageFile,
  }) async {
    try {
      final formData = FormData.fromMap({
        'title': title,
        'category': ?category,
        'description': ?description,
        'image': await MultipartFile.fromFile(imageFile.path),
      });

      final response = await _dio.post('/portfolio', data: formData);
      if (response.statusCode == 201 && response.data['status'] == true) {
        return PortfolioItemModel.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> deletePortfolio(dynamic id) async {
    try {
      final response = await _dio.delete('/portfolio/$id');
      return response.data['status'] == true;
    } catch (e) {
      return false;
    }
  }
}
