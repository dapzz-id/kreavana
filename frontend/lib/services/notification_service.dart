import 'api_service.dart';

class NotificationService {
  static Future<List<dynamic>> fetchNotifications() async {
    final response = await ApiService.get('notifications');
    if (response is Map && response['success'] == true && response['data'] != null) {
      return response['data'] as List<dynamic>;
    }
    return [];
  }

  static Future<bool> markAsRead() async {
    final response = await ApiService.put('notifications/read', {});
    return response is Map && response['success'] == true;
  }
}
