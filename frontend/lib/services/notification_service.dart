import 'api_service.dart';
import '../models/notification_model.dart';

class NotificationResult {
  final bool? success;
  final List<NotificationModel>? notifications;
  final String? message;

  NotificationResult({this.success, this.notifications, this.message});
}

class NotificationService {
  static Future<NotificationResult> getNotifications(String userId) async {
    try {
      final response = await ApiService.get('notifications');
      if (response['status'] == true && response['data'] != null) {
        final data = response['data'] as List<dynamic>;
        final notifications = data.map((e) => NotificationModel.fromJson(e as Map<String, dynamic>)).toList();
        return NotificationResult(success: true, notifications: notifications);
      }
      return NotificationResult(success: false, message: 'Gagal memuat notifikasi');
    } catch (e) {
      return NotificationResult(success: false, message: e.toString());
    }
  }

  static Future<bool> markAsRead(String userId) async {
    try {
      final response = await ApiService.put('notifications/read', {});
      return response['status'] == true;
    } catch (e) {
      return false;
    }
  }
}
