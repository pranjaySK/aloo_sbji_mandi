import 'package:aloo_sbji_mandi/core/service/notification_service.dart';
import 'package:flutter/material.dart';

/// Cold-storage-only notification types.
/// These are the notification types that involve cold storage operations.
const List<String> coldStorageNotificationTypes = [
  'booking_request',
  'booking_updated',
  'booking_cancelled',
  'token_called',
  'token_nearby',
  'token_skipped',
  'token_issued',
  'token_completed',
  'boli_alert',
];

/// Separate unread state for cold storage notifications.
/// Completely independent from the farmer/trader NotificationState.
class ColdStorageNotificationState {
  ColdStorageNotificationState._();
  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  static final NotificationService _service = NotificationService();
  static bool _hasFetched = false;
  static bool _markingAsRead = false;

  /// Fetch unread count from server filtered by CS notification types.
  static Future<void> refresh({bool force = false}) async {
    if (_markingAsRead) return;
    if (!force && _hasFetched) return;
    final count = await _service.getUnreadCount(types: coldStorageNotificationTypes);
    if (!_markingAsRead) {
      unreadCount.value = count;
    }
    _hasFetched = true;
  }

  /// Mark only CS notifications as read and clear badge immediately.
  static Future<void> markAllRead() async {
    _markingAsRead = true;
    unreadCount.value = 0;
    _hasFetched = true;
    try {
      await _service.markAllAsRead(types: coldStorageNotificationTypes);
    } catch (_) {}
    _markingAsRead = false;
  }

  /// Reset state (e.g., on logout).
  static void reset() {
    unreadCount.value = 0;
    _hasFetched = false;
  }
}

/// Notification bell icon with red dot badge for cold storage notifications only.
class ColdStorageNotificationBellWidget extends StatefulWidget {
  const ColdStorageNotificationBellWidget({super.key});

  @override
  State<ColdStorageNotificationBellWidget> createState() =>
      _ColdStorageNotificationBellWidgetState();
}

class _ColdStorageNotificationBellWidgetState
    extends State<ColdStorageNotificationBellWidget> {
  @override
  void initState() {
    super.initState();
    ColdStorageNotificationState.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ColdStorageNotificationState.unreadCount,
      builder: (context, count, _) {
        return IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications, color: Colors.white),
              if (count > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () async {
            await Navigator.pushNamed(context, '/cold-storage-notifications');
            // After returning, force-refresh to confirm server-side state
            ColdStorageNotificationState.unreadCount.value = 0;
            ColdStorageNotificationState.refresh(force: true);
          },
        );
      },
    );
  }
}
