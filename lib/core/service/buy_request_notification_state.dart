import 'package:aloo_sbji_mandi/core/service/socket_service.dart';
import 'package:aloo_sbji_mandi/core/service/trader_request_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global notification state for Buy Request responses.
///
/// Tracks whether there are new farmer responses to the trader's buy requests
/// so that a red badge appears on the Buy Request ServiceCard on Vyapari home.
///
/// The badge is cleared when the user visits the My Buy Requests screen.
/// New incoming socket events re‑trigger the badge.
class BuyRequestNotificationState {
  BuyRequestNotificationState._();

  /// Count of new/unseen buy request responses.
  static final ValueNotifier<int> newResponseCount = ValueNotifier<int>(0);

  static final SocketService _socketService = SocketService();
  static final TraderRequestService _requestService = TraderRequestService();

  static bool _initialized = false;
  static bool _listeningSocket = false;

  // SharedPreferences key for last-visited timestamp
  static const String _lastVisitKey = 'buy_request_last_visit';

  /// Initialize: check server for unseen responses & start socket listener.
  /// Safe to call multiple times — only runs once.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Check server for existing unseen responses
    await _checkUnseen();

    // 2. Start listening for real-time socket events
    _startSocketListener();
  }

  /// Check how many buy request responses are unseen (arrived after last visit).
  static Future<void> _checkUnseen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastVisit = prefs.getString(_lastVisitKey);
      final lastVisitTime =
          lastVisit != null ? DateTime.tryParse(lastVisit) : null;

      final result = await _requestService.getMyRequests();
      if (result['success'] == true) {
        final requests = result['data']['requests'] as List? ?? [];
        int unseenCount = 0;

        for (final request in requests) {
          final responses = request['responses'] as List? ?? [];
          for (final response in responses) {
            // Count responses that arrived after last visit
            final respondedAt = response['respondedAt'] ?? response['createdAt'];
            if (respondedAt != null && lastVisitTime != null) {
              final responseTime = DateTime.tryParse(respondedAt.toString());
              if (responseTime != null && responseTime.isAfter(lastVisitTime)) {
                unseenCount++;
              }
            } else if (lastVisitTime == null) {
              // First time — count pending responses
              final status = response['status']?.toString() ?? 'pending';
              if (status == 'pending') {
                unseenCount++;
              }
            }
          }
        }

        newResponseCount.value = unseenCount;
      }
    } catch (_) {
      // Silently fail — will retry on next init or socket event
    }
  }

  /// Listen for incoming buy request response socket events.
  static void _startSocketListener() {
    if (_listeningSocket) return;
    _listeningSocket = true;

    _socketService.addBuyRequestResponseListener(_onNewResponse);
  }

  /// Called when a new buy request response arrives via socket.
  static void _onNewResponse(Map<String, dynamic> data) {
    newResponseCount.value = newResponseCount.value + 1;
  }

  /// Call when the user navigates to My Buy Requests screen.
  /// Clears the badge and records the visit timestamp.
  static Future<void> markSeen() async {
    newResponseCount.value = 0;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastVisitKey, DateTime.now().toIso8601String());
  }

  /// Force-refresh from server (e.g. after coming back to the app).
  static Future<void> refresh() async {
    await _checkUnseen();
  }

  /// Reset on logout.
  static void reset() {
    newResponseCount.value = 0;
    _initialized = false;
    _listeningSocket = false;
    _socketService.removeBuyRequestResponseListener(_onNewResponse);
  }
}
