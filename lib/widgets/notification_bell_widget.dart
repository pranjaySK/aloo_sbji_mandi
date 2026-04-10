import 'package:aloo_sbji_mandi/core/service/notification_service.dart';
import 'package:flutter/material.dart';

/// Global unread notification count — shared across all bell instances.
/// Prevents the red dot from flickering when widgets rebuild.
class NotificationState {
  NotificationState._();
  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  static final NotificationService _service = NotificationService();
  static bool _hasFetched = false;

  /// Track if markAllRead is pending — prevents refresh from overriding
  static bool _markingAsRead = false;

  /// Fetch unread count from server (only once per app session, unless forced).
  static Future<void> refresh({bool force = false}) async {
    if (_markingAsRead) return; // Don't refresh while marking as read
    if (!force && _hasFetched) return;
    final count = await _service.getUnreadCount();
    if (!_markingAsRead) {
      unreadCount.value = count;
    }
    _hasFetched = true;
  }

  /// Mark all as read on server AND clear local state immediately.
  static Future<void> markAllRead() async {
    // Prevent any concurrent refresh from overriding our 0
    _markingAsRead = true;
    // Clear locally FIRST so the dot disappears instantly
    unreadCount.value = 0;
    _hasFetched = true;
    // Then sync with server
    try {
      await _service.markAllAsRead();
    } catch (_) {
      // Even if server fails, keep local state at 0 for this session
    }
    _markingAsRead = false;
  }

  /// Reset state (e.g., on logout)
  static void reset() {
    unreadCount.value = 0;
    _hasFetched = false;
  }
}

/// A notification bell icon with a red dot badge when there are unread notifications.
class NotificationBellWidget extends StatefulWidget {
  const NotificationBellWidget({super.key});

  @override
  State<NotificationBellWidget> createState() => _NotificationBellWidgetState();
}

class _NotificationBellWidgetState extends State<NotificationBellWidget> {
  @override
  void initState() {
    super.initState();
    // Only fetches from server on first mount; subsequent rebuilds use cached value
    NotificationState.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationState.unreadCount,
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
            await Navigator.pushNamed(context, '/notification');
            // After returning, ensure red dot reflects actual server state
            NotificationState.unreadCount.value = 0;
            NotificationState.refresh(force: true);
          },
        );
      },
    );
  }
}
