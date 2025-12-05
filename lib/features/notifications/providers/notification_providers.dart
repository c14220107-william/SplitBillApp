import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitbillapp/features/notifications/models/notification.dart';
import 'package:splitbillapp/features/notifications/services/notification_service.dart';

// Notification Service Provider
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// Notifications List Provider (with auto-refresh)
final notificationsProvider = FutureProvider.autoDispose<List<Notification>>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  return await service.getNotifications();
});

// Unread Count Provider (with auto-refresh)
final unreadNotificationsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  return await service.getUnreadCount();
});
