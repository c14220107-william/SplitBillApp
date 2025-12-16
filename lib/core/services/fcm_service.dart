import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📱 Background message: ${message.messageId}');
  print('📱 Title: ${message.notification?.title}');
  print('📱 Body: ${message.notification?.body}');
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final SupabaseClient _supabase = Supabase.instance.client;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Initialize FCM
  Future<void> initialize() async {
    try {
      print('🔔 Initializing FCM Service...');

      // Request permission for iOS
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ User granted notification permission');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        print('⚠️ User granted provisional notification permission');
      } else {
        print('❌ User declined notification permission');
        return;
      }

      // Initialize local notifications for foreground display
      await _initializeLocalNotifications();

      // Get FCM token
      _fcmToken = await _fcm.getToken();
      if (_fcmToken != null) {
        print('✅ FCM Token: $_fcmToken');
        await _saveFCMToken(_fcmToken!);
      }

      // Listen to token refresh
      _fcm.onTokenRefresh.listen((newToken) {
        print('🔄 FCM Token refreshed: $newToken');
        _fcmToken = newToken;
        _saveFCMToken(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages (app opened from notification)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Check if app was opened from terminated state
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }

      print('✅ FCM Service initialized successfully');
    } catch (e) {
      print('❌ Error initializing FCM: $e');
    }
  }

  /// Initialize local notifications for Android
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channel
    const androidChannel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Save FCM token to Supabase
  Future<void> _saveFCMToken(String token) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('⚠️ Cannot save FCM token: User not logged in');
        return;
      }

      // Upsert FCM token to user_devices table
      await _supabase.from('user_devices').upsert({
        'user_id': userId,
        'fcm_token': token,
        'platform': 'android', // or 'ios' based on Platform
        'updated_at': DateTime.now().toIso8601String(),
      });

      print('✅ FCM token saved to Supabase');
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('📱 Foreground message: ${message.messageId}');
    print('📱 Title: ${message.notification?.title}');
    print('📱 Body: ${message.notification?.body}');
    print('📱 Data: ${message.data}');

    // Show local notification when app is in foreground
    _showLocalNotification(message);
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription:
                'This channel is used for important notifications.',
            importance: Importance.high,
            priority: Priority.high,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data['bill_id'], // Pass bill_id for navigation
      );
    }
  }

  /// Handle message opened app (background/terminated)
  void _handleMessageOpenedApp(RemoteMessage message) {
    print('📱 Message opened app: ${message.messageId}');
    print('📱 Data: ${message.data}');

    // Navigate to bill detail if bill_id exists
    if (message.data.containsKey('bill_id')) {
      final billId = message.data['bill_id'];
      print('🔍 Navigating to bill: $billId');
      // TODO: Implement navigation using go_router
      // context.go('/bills/$billId');
    }
  }

  /// Handle notification tapped (from local notification)
  void _onNotificationTapped(NotificationResponse response) {
    print('📱 Notification tapped: ${response.payload}');
    
    if (response.payload != null) {
      final billId = response.payload!;
      print('🔍 Navigating to bill: $billId');
      // TODO: Implement navigation using go_router
      // context.go('/bills/$billId');
    }
  }

  /// Delete FCM token (call on logout)
  Future<void> deleteFCMToken() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Delete from Supabase
      await _supabase
          .from('user_devices')
          .delete()
          .eq('user_id', userId)
          .eq('fcm_token', _fcmToken ?? '');

      // Delete from FCM
      await _fcm.deleteToken();
      _fcmToken = null;

      print('✅ FCM token deleted');
    } catch (e) {
      print('❌ Error deleting FCM token: $e');
    }
  }
}
