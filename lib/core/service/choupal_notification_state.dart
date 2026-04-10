import 'package:aloo_sbji_mandi/core/service/chat_service.dart';
import 'package:aloo_sbji_mandi/core/service/socket_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global notification state for Choupal (chat) section.
///
/// Tracks whether there are new unread chat messages so that:
/// - A red dot appears on the Choupal bottom‑nav tab
/// - A red dot appears on the "Chat" sub‑tab inside Choupal
///
/// Both dots are cleared only when the user visits Choupal → Chats section.
/// New incoming socket messages re‑trigger the dots.
class ChoupalNotificationState {
  ChoupalNotificationState._();

  /// Whether to show a red dot on the Choupal bottom‑nav tab.
  static final ValueNotifier<bool> hasNewMessages = ValueNotifier<bool>(false);

  /// Whether to show a red dot on the Chat sub‑tab inside Choupal.
  static final ValueNotifier<bool> hasChatTabNotification =
      ValueNotifier<bool>(false);

  static final ChatService _chatService = ChatService();
  static final SocketService _socketService = SocketService();

  static bool _initialized = false;
  static bool _listeningSocket = false;

  // SharedPreferences key for last‑visited timestamp
  static const String _lastChatVisitKey = 'choupal_last_chat_visit';

  /// Initialize: fetch unread count from server & start socket listener.
  /// Safe to call multiple times — only runs once.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Check server for existing unread conversations
    await _checkUnread();

    // 2. Start listening for real‑time socket messages
    _startSocketListener();
  }

  /// Check whether any conversation has unread messages.
  static Future<void> _checkUnread() async {
    try {
      final conversations = await _chatService.getConversations();
      final hasUnread = conversations.any((c) => c.unreadCount > 0);
      if (hasUnread) {
        hasNewMessages.value = true;
        hasChatTabNotification.value = true;
      }
    } catch (_) {
      // Silently fail — will retry on next init or socket event
    }
  }

  /// Listen for incoming socket messages.
  static void _startSocketListener() {
    if (_listeningSocket) return;
    _listeningSocket = true;

    _socketService.addMessageListener(_onNewMessage);
  }

  /// Called when a new message arrives via socket.
  static void _onNewMessage(Map<String, dynamic> message) {
    // Always flag notifications — the user hasn't seen the chat yet
    hasNewMessages.value = true;
    hasChatTabNotification.value = true;
  }

  /// Call when the user navigates to Choupal → Chats sub‑tab.
  /// Clears both red dots and records the visit timestamp.
  static Future<void> markChatsVisited() async {
    hasNewMessages.value = false;
    hasChatTabNotification.value = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _lastChatVisitKey, DateTime.now().toIso8601String());
  }

  /// Force‑refresh from server (e.g. after coming back to the app).
  static Future<void> refresh() async {
    await _checkUnread();
  }

  /// Reset on logout.
  static void reset() {
    hasNewMessages.value = false;
    hasChatTabNotification.value = false;
    _initialized = false;
    _listeningSocket = false;
    _socketService.removeMessageListener(_onNewMessage);
  }
}
