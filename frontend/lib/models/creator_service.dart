import 'package:flutter/material.dart';

class CreatorService {
  final String id;
  final String creatorId;
  final String title;
  final String? description;
  final String? category;
  final double price;
  final String? durationInfo;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CreatorService({
    required this.id,
    required this.creatorId,
    required this.title,
    this.description,
    this.category,
    required this.price,
    this.durationInfo,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory CreatorService.fromJson(Map<String, dynamic> json) {
    return CreatorService(
      id: json['id']?.toString() ?? '',
      creatorId: json['creator_id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      category: json['category'],
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      durationInfo: json['duration_info'],
      status: json['status'] ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'creator_id': creatorId,
      'title': title,
      'description': description,
      'category': category,
      'price': price,
      'duration_info': durationInfo,
      'status': status,
    };
  }

  // Helper getters to map backend data to existing frontend UI needs
  String get displaySubtitle =>
      description ?? durationInfo ?? 'Layanan Creator';
  String get displayTag => category ?? 'Umum';

  IconData get displayIcon {
    final cat = (category ?? '').toLowerCase();
    if (cat.contains('foto')) return Icons.camera_alt_outlined;
    if (cat.contains('video')) return Icons.videocam_outlined;
    if (cat.contains('mc')) return Icons.mic_external_on_outlined;
    if (cat.contains('design') || cat.contains('desain'))
      return Icons.brush_outlined;
    if (cat.contains('edit')) return Icons.edit_outlined;
    if (cat.contains('music') || cat.contains('singer'))
      return Icons.music_note_outlined;
    return Icons.work_outline;
  }
}
