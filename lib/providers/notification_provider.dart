import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class NotificationProvider extends ChangeNotifier {
  final ApiService _api;
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;

  NotificationProvider(this._api);

  List<Map<String, dynamic>> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  Future<void> loadNotifications() async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _api.getNotifications();
      _notifications = List<Map<String, dynamic>>.from(
        result['notifications'] ?? [],
      );
      _unreadCount = result['unread_count'] as int? ?? 0;
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> markAllRead() async {
    try {
      await _api.markAllNotificationsRead();
      _unreadCount = 0;
      for (final n in _notifications) {
        n['is_read'] = true;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markRead(int notificationId) async {
    try {
      await _api.markNotificationRead(notificationId);
      final idx = _notifications.indexWhere((n) => n['id'] == notificationId);
      if (idx != -1 && _notifications[idx]['is_read'] != true) {
        _notifications[idx]['is_read'] = true;
        _unreadCount = (_unreadCount - 1).clamp(0, _unreadCount);
        notifyListeners();
      }
    } catch (_) {}
  }
}
