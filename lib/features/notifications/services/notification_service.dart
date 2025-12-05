import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:splitbillapp/core/config/supabase_config.dart';
import 'package:splitbillapp/features/notifications/models/notification.dart';

class NotificationService {
  final _supabase = SupabaseConfig.client;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Initialize local notifications
  Future<void> initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        print('📱 Notification tapped: ${response.payload}');
      },
    );
  }

  /// Setup realtime listener for new notifications
  void setupRealtimeListener() {
    if (currentUserId == null) {
      print('⚠️ Cannot setup realtime: no user ID');
      return;
    }

    print('🔔 Setting up realtime listener for user: $currentUserId');

    // Subscribe to realtime changes
    _supabase
        .channel('public:notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            print('🔔 Realtime payload received: ${payload.newRecord}');
            
            // Check if notification is for current user
            if (payload.newRecord['user_id'] == currentUserId) {
              print('✅ Notification for current user!');
              _showLocalNotification(payload.newRecord);
            } else {
              print('⏭️ Notification for different user, skipping');
            }
          },
        )
        .subscribe((status, [error]) {
          print('📡 Realtime subscription status: $status');
          if (error != null) {
            print('❌ Realtime error: $error');
          }
        });
  }

  /// Show local notification
  Future<void> _showLocalNotification(Map<String, dynamic> notification) async {
    print('📱 Showing local notification: ${notification['title']}');
    
    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    try {
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
        notification['title'] ?? 'New Notification',
        notification['message'] ?? '',
        notificationDetails,
        payload: jsonEncode(notification),
      );
      print('✅ Local notification shown');
    } catch (e) {
      print('❌ Error showing notification: $e');
    }
  }

  /// Get all notifications for current user
  Future<List<Notification>> getNotifications({int limit = 50}) async {
    try {
      print('DEBUG: Fetching notifications for user: $currentUserId');
      
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', currentUserId!)
          .order('created_at', ascending: false)
          .limit(limit);

      print('DEBUG: Notifications response: ${response.length} items');
      
      return (response as List)
          .map((json) => Notification.fromJson(json))
          .toList();
    } catch (e) {
      print('DEBUG: Error fetching notifications: $e');
      throw Exception('Failed to get notifications: $e');
    }
  }

  /// Get unread notifications count
  Future<int> getUnreadCount() async {
    try {
      print('DEBUG: Fetching unread count for user: $currentUserId');
      
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', currentUserId!)
          .eq('is_read', false);

      final count = (response as List).length;
      print('DEBUG: Unread count: $count');
      
      return count;
    } catch (e) {
      print('DEBUG: Error fetching unread count: $e');
      throw Exception('Failed to get unread count: $e');
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', notificationId);
    } catch (e) {
      throw Exception('Failed to mark as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true, 'updated_at': DateTime.now().toIso8601String()})
          .eq('user_id', currentUserId!);
    } catch (e) {
      throw Exception('Failed to mark all as read: $e');
    }
  }

  /// Send notification to users when bill is finalized
  Future<void> sendBillFinalizedNotification({
    required String billId,
    required String billTitle,
    required List<String> userIds,
  }) async {
    try {
      // 1. Create notifications in database
      final notifications = userIds.map((userId) => {
        'user_id': userId,
        'title': 'Bill Finalized',
        'message': 'The bill "$billTitle" has been finalized. Please proceed with payment.',
        'type': 'bill_finalized',
        'related_id': billId,
        'is_read': false,
      }).toList();

      await _supabase.from('notifications').insert(notifications);
      print('✅ Notifications inserted to DB for ${userIds.length} users');
      print('📡 Push notifications will be delivered via Supabase Realtime');
    } catch (e) {
      print('❌ Error sending notifications: $e');
      throw Exception('Failed to send notifications: $e');
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);
    } catch (e) {
      throw Exception('Failed to delete notification: $e');
    }
  }
}
