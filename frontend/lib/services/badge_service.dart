import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class BadgeService extends ChangeNotifier {
  static final BadgeService _instance = BadgeService._();
  factory BadgeService() => _instance;
  BadgeService._();

  int _unreadNotifications = 0;
  int _unreadMessages = 0;
  Timer? _timer;
  bool _polling = false;

  int get unreadNotifications => _unreadNotifications;
  int get unreadMessages => _unreadMessages;

  String get unreadNotificationsText =>
      _unreadNotifications > 0 ? '$_unreadNotifications' : '';
  String get unreadMessagesText =>
      _unreadMessages > 0 ? '$_unreadMessages' : '';

  void startPolling({Duration interval = const Duration(seconds: 20)}) {
    if (_polling) return;
    _polling = true;
    fetchCounts();
    _timer = Timer.periodic(interval, (_) => fetchCounts());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
    _polling = false;
  }

  Future<void> fetchCounts() async {
    try {
      final res = await ApiService.get('unread-count');
      if ((res['success'] == true || res['status'] == true) &&
          res['data'] != null) {
        final data = res['data'];
        final newNotif = data['unread_notifications'] ?? 0;
        final newChat = data['unread_messages'] ?? 0;
        if (newNotif != _unreadNotifications || newChat != _unreadMessages) {
          _unreadNotifications = newNotif;
          _unreadMessages = newChat;
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  void markNotificationsRead() {
    _unreadNotifications = 0;
    notifyListeners();
    _markNotificationsReadBackend();
  }

  Future<void> _markNotificationsReadBackend() async {
    try {
      await ApiService.put('notifications/read', {});
    } catch (_) {}
    fetchCounts();
  }

  void markMessagesRead() {
    _unreadMessages = 0;
    notifyListeners();
    _markMessagesReadBackend();
  }

  Future<void> _markMessagesReadBackend() async {
    try {
      await ApiService.post('chats/read-all', {});
    } catch (_) {}
    fetchCounts();
  }

  void incrementUnreadNotifications() {
    _unreadNotifications++;
    notifyListeners();
  }

  void incrementUnreadMessages() {
    _unreadMessages++;
    notifyListeners();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
