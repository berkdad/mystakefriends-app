import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  String? _currentToken;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      print('FCM: Already initialized, skipping');
      return;
    }

    try {
      print('FCM: Starting initialization...');
      await _requestPermission();
      await _setupLocalNotifications();
      await _setupMessageHandlers();
      _isInitialized = true;
      print('FCM: Initialization complete');
    } catch (e) {
      print('FCM: Initialization error: $e');
      // Don't rethrow - FCM is non-critical
    }
  }

  Future<void> _requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('FCM: User granted permission');
      } else {
        print('FCM: User declined permission');
      }
    } catch (e) {
      print('FCM: Permission request error: $e');
    }
  }

  Future<void> _setupLocalNotifications() async {
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // Don't request permissions here - already done in _requestPermission()
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      print('FCM: Local notifications setup complete');
    } catch (e) {
      print('FCM: Local notifications setup error: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('FCM: Notification tapped: ${response.payload}');
    // Handle navigation based on payload
  }

  Future<void> _setupMessageHandlers() async {
    try {
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Check if app was opened from a terminated state
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }
      print('FCM: Message handlers setup complete');
    } catch (e) {
      print('FCM: Message handlers setup error: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('FCM: Foreground message received: ${message.notification?.title}');

    // Don't show notification if user is in the chat screen
    final prefs = await SharedPreferences.getInstance();
    final isInChat = prefs.getBool('isInChatScreen') ?? false;

    if (isInChat && message.data['type'] == 'chat') {
      print('FCM: Suppressing chat notification - user in chat screen');
      return;
    }

    // Show local notification
    if (message.notification != null) {
      await _showLocalNotification(message);
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    print('FCM: App opened from notification: ${message.data}');
    // Navigate based on message data
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'mystakefriends_channel',
      'My Stake Friends',
      channelDescription: 'Notifications for My Stake Friends',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFFf472b6),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      details,
      payload: message.data['payload'],
    );
  }

  Future<String?> getToken() async {
    try {
      _currentToken = await _messaging.getToken();
      print('FCM: Token obtained: $_currentToken');
      return _currentToken;
    } catch (e) {
      print('FCM: Error getting token: $e');
      return null;
    }
  }

  Future<void> saveTokenToFirestore(String userId) async {
    try {
      final token = await getToken();
      if (token == null) {
        print('FCM: No token available to save');
        return;
      }

      final tokenDoc = FirebaseFirestore.instance
          .collection('fcmTokens')
          .doc(userId)
          .collection('tokens')
          .doc(token);

      await tokenDoc.set({
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'createdAt': FieldValue.serverTimestamp(),
        'lastUsed': FieldValue.serverTimestamp(),
      });

      print('FCM: Token saved to Firestore');
    } catch (e) {
      print('FCM: Error saving token: $e');
    }
  }

  Future<void> deleteTokenFromFirestore(String userId) async {
    try {
      final token = _currentToken ?? await getToken();
      if (token == null) return;

      await FirebaseFirestore.instance
          .collection('fcmTokens')
          .doc(userId)
          .collection('tokens')
          .doc(token)
          .delete();

      print('FCM: Token deleted from Firestore');
    } catch (e) {
      print('FCM: Error deleting token: $e');
    }
  }

  Future<void> cleanupOldTokens(String userId) async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      final tokensRef = FirebaseFirestore.instance
          .collection('fcmTokens')
          .doc(userId)
          .collection('tokens');

      final oldTokens = await tokensRef
          .where('lastUsed', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in oldTokens.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      print('FCM: Cleaned up ${oldTokens.docs.length} old tokens');
    } catch (e) {
      print('FCM: Error cleaning up tokens: $e');
    }
  }

  Future<void> refreshToken(String userId) async {
    await deleteTokenFromFirestore(userId);
    await saveTokenToFirestore(userId);
    await cleanupOldTokens(userId);
  }

  Future<void> setChatScreenStatus(bool isInChat) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isInChatScreen', isInChat);
  }

  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    print('FCM: Subscribed to topic: $topic');
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    print('FCM: Unsubscribed from topic: $topic');
  }
}

// Top-level function for background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('FCM: Background message received: ${message.notification?.title}');
}