import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../services/dio_client.dart';

class PortfolioItemModel {
  final dynamic id;
  final String title;
  final String? category;
  final String? description;
  final String? imageUrl;
  final int sortOrder;
  final String? eventDate;
  final String? location;
  final String source; // 'kreavana' | 'external'
  final String verificationStatus; // 'self_reported' | 'verified' | 'disputed'
  final String? clientName;

  PortfolioItemModel({
    this.id,
    required this.title,
    this.category,
    this.description,
    this.imageUrl,
    this.sortOrder = 0,
    this.eventDate,
    this.location,
    this.source = 'external',
    this.verificationStatus = 'self_reported',
    this.clientName,
  });

  bool get isExternal => source == 'external';

  factory PortfolioItemModel.fromJson(Map<String, dynamic> json) {
    return PortfolioItemModel(
      id: json['id'],
      title: json['title'] ?? '',
      category: json['category'],
      description: json['description'],
      imageUrl: json['image_url'],
      sortOrder: json['sort_order'] ?? 0,
      eventDate: json['event_date']?.toString(),
      location: json['location']?.toString(),
      source: json['source']?.toString() ?? 'external',
      verificationStatus: json['verification_status']?.toString() ?? 'self_reported',
      clientName: json['client_name']?.toString(),
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
    File? imageFile,
    Uint8List? imageBytes,
    String? fileName,
    String? eventDate,
    String? location,
    String source = 'external',
    String? clientName,
  }) async {
    try {
      final formDataMap = <String, dynamic>{
        'title': title,
        if (category != null) 'category': category,
        if (description != null) 'description': description,
        if (eventDate != null) 'event_date': eventDate,
        if (location != null) 'location': location,
        'source': source,
        if (clientName != null) 'client_name': clientName,
      };

      if (imageBytes != null) {
        formDataMap['image'] = MultipartFile.fromBytes(
          imageBytes,
          filename: fileName ?? 'portfolio_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      } else if (imageFile != null && !kIsWeb) {
        formDataMap['image'] = await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        );
      }

      final formData = FormData.fromMap(formDataMap);

      final response = await _dio.post('/portfolio', data: formData);
      if (response.statusCode == 201 && response.data['status'] == true) {
        return PortfolioItemModel.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('Error adding portfolio: $e');
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
