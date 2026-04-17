/**
 * Firebase Cloud Messaging (FCM) Service
 * 
 * Handles:
 * - Firebase initialization
 * - FCM token generation & registration with backend
 * - Background message handling (shows local notification)
 * - Foreground message handling
 * - Automatic token refresh
 */

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:aloo_sbji_mandi/core/constants/api_constant.dart';
import 'package:aloo_sbji_mandi/core/service/local_notification_service.dart';

/// Top-level background message handler (must be a top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCMService: Background message received: ${message.messageId}');

  // Show local notification for the background FCM message
  final notification = message.notification;
  final data = message.data;

  final title = notification?.title ?? data['title'] ?? 'Aloo Market';
  final body = notification?.body ?? data['body'] ?? '';
  final channelId = data['channelId'] ?? 'token_queue_channel';

  if (channelId == 'token_queue_channel') {
    // Use the local notification service to display
    final service = LocalNotificationService();
    await service.initialize();
    await service.showTokenNotification(
      title: title,
      message: body,
      tokenId: data['tokenId'],
      event: data['event'],
      coldStorageName: data['coldStorageName'],
    );
  } else {
    final service = LocalNotificationService();
    await service.initialize();
    await service.showNotification(
      id: message.hashCode,
      title: title,
      body: body,
      payload: json.encode(data),
    );
  }
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  /// Lazy — only touch FirebaseMessaging AFTER Firebase.initializeApp() succeeds.
  FirebaseMessaging? _messaging;
  bool _isInitialized = false;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  /// Initialize FCM - call after Firebase.initializeApp()
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb) {
      debugPrint('FCMService: Skipped on web platform');
      return;
    }

    try {
      // Initialize messaging instance lazily (after Firebase is ready)
      _messaging = FirebaseMessaging.instance;

      // Request notification permissions
      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('FCMService: Notification permission denied');
        return;
      }

      debugPrint(
        'FCMService: Permission status: ${settings.authorizationStatus}',
      );

      // Get FCM token
      _fcmToken = await _messaging!.getToken();
      if (kDebugMode) {
        debugPrint('FCMService: Full Token obtained: $_fcmToken');
      } else {
        debugPrint('FCMService: Token obtained: ${_fcmToken?.substring(0, 20)}...');
      }

      // Register token with backend
      if (_fcmToken != null) {
        await _registerTokenWithBackend(_fcmToken!);
      }

      // Listen for token refresh
      _messaging!.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('FCMService: Token refreshed');
        _registerTokenWithBackend(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification tap when app was in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from a notification
      final initialMessage = await _messaging!.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      _isInitialized = true;
      debugPrint('FCMService: Initialized successfully');
    } catch (e) {
      debugPrint('FCMService: Initialization error: $e');
    }
  }

  /// Register FCM token with backend
  Future<void> _registerTokenWithBackend(String fcmToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('accessToken');
      if (accessToken == null) {
        debugPrint('FCMService: No access token, skipping FCM registration');
        return;
      }

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/v1/user/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({'fcmToken': fcmToken}),
      );

      if (response.statusCode == 200) {
        debugPrint('FCMService: Token registered with backend');
      } else {
        debugPrint(
          'FCMService: Failed to register token: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('FCMService: Error registering token: $e');
    }
  }

  /// Handle foreground FCM messages - show local notification
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('FCMService: Foreground message: ${message.messageId}');

    final notification = message.notification;
    final data = message.data;

    final title = notification?.title ?? data['title'] ?? 'Aloo Market';
    final body = notification?.body ?? data['body'] ?? '';
    final channelId = data['channelId'] ?? 'token_queue_channel';

    if (channelId == 'token_queue_channel') {
      LocalNotificationService().showTokenNotification(
        title: title,
        message: body,
        tokenId: data['tokenId'],
        event: data['event'],
        coldStorageName: data['coldStorageName'],
      );
    } else {
      LocalNotificationService().showNotification(
        id: message.hashCode,
        title: title,
        body: body,
        payload: json.encode(data),
      );
    }
  }

  /// Handle notification tap (app opened from notification)
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('FCMService: Notification tapped: ${message.data}');
    // Navigation can be handled here if needed
    // For now, the app opens and the user can see their token status
  }

  /// Re-register FCM token (call after login)
  Future<void> reRegisterToken() async {
    if (_fcmToken != null) {
      await _registerTokenWithBackend(_fcmToken!);
    } else {
      // Try to get a new token
      try {
        _messaging ??= FirebaseMessaging.instance;
        _fcmToken = await _messaging!.getToken();
        if (_fcmToken != null) {
          await _registerTokenWithBackend(_fcmToken!);
        }
      } catch (e) {
        debugPrint('FCMService: Error getting token: $e');
      }
    }
  }

  /// Clear FCM token from backend (call on logout)
  Future<void> clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('accessToken');
      if (accessToken == null) return;

      await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/v1/user/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({'fcmToken': ''}),
      );
      debugPrint('FCMService: Token cleared from backend');
    } catch (e) {
      debugPrint('FCMService: Error clearing token: $e');
    }
  }
}
