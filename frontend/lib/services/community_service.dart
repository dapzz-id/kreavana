import 'package:dio/dio.dart';
import 'api_service.dart';

class CommunityService {
  // ===== MEMBERS =====
  static Future<Map<String, dynamic>> getMembers({
    String? communityId,
    String? status,
    int perPage = 50,
  }) async {
    try {
      final params = <String, dynamic>{
        if (communityId != null) 'community_id': communityId,
        if (status != null) 'status': status,
        'per_page': perPage,
      };
      final response = await ApiService.get('community/members', queryParams: params);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> addMember({
    required String userId,
    String? role,
  }) async {
    try {
      final response = await ApiService.post('community/members', {
        'user_id': userId,
        if (role != null) 'role': role,
      });
      return response;
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updateMember({
    required String id,
    String? role,
    String? status,
  }) async {
    try {
      final response = await ApiService.put('community/members/$id', {
        if (role != null) 'role': role,
        if (status != null) 'status': status,
      });
      return response;
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> removeMember(String id) async {
    try {
      final response = await ApiService.delete('community/members/$id');
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // ===== ACTIVITIES =====
  static Future<Map<String, dynamic>> getActivities({
    String? communityId,
    String? status,
    int perPage = 50,
  }) async {
    try {
      final params = <String, dynamic>{
        if (communityId != null) 'community_id': communityId,
        if (status != null) 'status': status,
        'per_page': perPage,
      };
      final response = await ApiService.get('community/activities', queryParams: params);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> createActivity({
    required String title,
    String? description,
    String? activityDate,
    String? location,
    int? maxParticipants,
  }) async {
    try {
      final response = await ApiService.post('community/activities', {
        'title': title,
        if (description != null) 'description': description,
        if (activityDate != null) 'activity_date': activityDate,
        if (location != null) 'location': location,
        if (maxParticipants != null) 'max_participants': maxParticipants,
      });
      return response;
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updateActivity({
    required String id,
    String? title,
    String? description,
    String? activityDate,
    String? location,
    String? status,
    int? maxParticipants,
  }) async {
    try {
      final response = await ApiService.put('community/activities/$id', {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (activityDate != null) 'activity_date': activityDate,
        if (location != null) 'location': location,
        if (status != null) 'status': status,
        if (maxParticipants != null) 'max_participants': maxParticipants,
      });
      return response;
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> deleteActivity(String id) async {
    try {
      final response = await ApiService.delete('community/activities/$id');
      return response;
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> joinActivity(String id) async {
    try {
      final response = await ApiService.post('community/activities/$id/join', {});
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // ===== ANNOUNCEMENTS =====
  static Future<Map<String, dynamic>> getAnnouncements({
    String? communityId,
    String? status,
    int perPage = 50,
  }) async {
    try {
      final params = <String, dynamic>{
        if (communityId != null) 'community_id': communityId,
        if (status != null) 'status': status,
        'per_page': perPage,
      };
      final response = await ApiService.get('community/announcements', queryParams: params);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> createAnnouncement({
    required String title,
    required String content,
    String? type,
    String? priority,
    String? publishedAt,
    String? expiresAt,
  }) async {
    try {
      final response = await ApiService.post('community/announcements', {
        'title': title,
        'content': content,
        if (type != null) 'type': type,
        if (priority != null) 'priority': priority,
        if (publishedAt != null) 'published_at': publishedAt,
        if (expiresAt != null) 'expires_at': expiresAt,
      });
      return response;
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updateAnnouncement({
    required String id,
    String? title,
    String? content,
    String? type,
    String? priority,
    String? publishedAt,
    String? expiresAt,
    String? status,
  }) async {
    try {
      final response = await ApiService.put('community/announcements/$id', {
        if (title != null) 'title': title,
        if (content != null) 'content': content,
        if (type != null) 'type': type,
        if (priority != null) 'priority': priority,
        if (publishedAt != null) 'published_at': publishedAt,
        if (expiresAt != null) 'expires_at': expiresAt,
        if (status != null) 'status': status,
      });
      return response;
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> deleteAnnouncement(String id) async {
    try {
      final response = await ApiService.delete('community/announcements/$id');
      return response;
    } catch (e) {
      rethrow;
    }
  }
}
