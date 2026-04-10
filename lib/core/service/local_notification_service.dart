/**
 * Local Push Notification Service
 * 
 * Uses flutter_local_notifications to show push-style notifications
 * on the user's device when boli alert reminders arrive via socket.
 * 
 * This shows notifications in the system tray even when the app is 
 * in the foreground or background.
 */

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Callback for when user taps a notification
  static void Function(String? payload)? onNotificationTapped;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // flutter_local_notifications does not support web
    if (kIsWeb) {
      debugPrint('LocalNotificationService: Skipped on web platform');
      return;
    }

    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        if (onNotificationTapped != null) {
          onNotificationTapped!(response.payload);
        }
      },
    );

    // Request Android notification permission (Android 13+)
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    _isInitialized = true;
    debugPrint('LocalNotificationService: Initialized');
  }

  /// Show a boli alert reminder notification
  Future<void> showBoliAlertNotification({
    required String title,
    required String message,
    String? boliAlertId,
    String? coldStorageName,
    String? boliTime,
    String? city,
    String? daysBeforeLabel,
  }) async {
    if (kIsWeb) return; // Notifications not supported on web
    if (!_isInitialized) await initialize();
    final androidDetails = AndroidNotificationDetails(
      'boli_alert_channel',
      'बोली अलर्ट / Boli Alerts',
      channelDescription: 'Notifications for upcoming potato auctions (बोली)',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF1B5E20), // Dark green
      styleInformation: BigTextStyleInformation(
        message,
        contentTitle: title,
        summaryText: coldStorageName ?? 'बोली अलर्ट',
      ),
    );

    // iOS notification details
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Create payload with boli alert info
    final payload = json.encode({
      'type': 'boli_alert',
      'boliAlertId': boliAlertId,
      'coldStorageName': coldStorageName,
      'boliTime': boliTime,
      'city': city,
      'daysBeforeLabel': daysBeforeLabel,
    });

    // Use a unique ID based on boliAlertId and daysBeforeLabel
    final notifId = (boliAlertId ?? '').hashCode + (daysBeforeLabel ?? '').hashCode;

    await _notifications.show(
      notifId.abs() % 100000, // Keep ID within safe range
      title,
      message,
      details,
      payload: payload,
    );

    debugPrint('LocalNotificationService: Showed boli alert notification - $daysBeforeLabel');
  }

  /// Show a token queue notification (called, nearby, completed, etc.)
  Future<void> showTokenNotification({
    required String title,
    required String message,
    String? tokenId,
    String? event,
    String? coldStorageName,
  }) async {
    if (kIsWeb) return;
    if (!_isInitialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      'token_queue_channel',
      'टोकन कतार / Token Queue',
      channelDescription: 'Notifications for token queue updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF1B5E20),
      styleInformation: BigTextStyleInformation(
        message,
        contentTitle: title,
        summaryText: coldStorageName ?? 'टोकन कतार',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = json.encode({
      'type': 'token_queue',
      'tokenId': tokenId,
      'event': event,
      'coldStorageName': coldStorageName,
    });

    final notifId = (tokenId ?? '').hashCode + (event ?? '').hashCode;

    await _notifications.show(
      notifId.abs() % 100000,
      title,
      message,
      details,
      payload: payload,
    );

    debugPrint('LocalNotificationService: Showed token notification - $event');
  }

  /// Show a generic notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return; // Notifications not supported on web
    if (!_isInitialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'general_channel',
      'General Notifications',
      channelDescription: 'General app notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
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

    await _notifications.show(id, title, body, details, payload: payload);
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
