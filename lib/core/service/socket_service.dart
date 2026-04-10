/**
 * Socket Service
 *
 * Manages WebSocket connection for real-time messaging.
 * Handles connection, authentication, reconnection, and event handling.
 */

import 'dart:async';

import 'package:aloo_sbji_mandi/core/constants/api_constant.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Callback types for socket events
typedef MessageCallback = void Function(Map<String, dynamic> message);
typedef StatusCallback = void Function(String oderId, bool isOnline);
typedef TypingCallback =
    void Function(String oderId, String userName, bool isTyping);
typedef ReadCallback = void Function(String conversationId, String readBy);
typedef TokenEventCallback = void Function(Map<String, dynamic> data);
typedef BoliAlertCallback = void Function(Map<String, dynamic> data);
typedef BuyRequestResponseCallback = void Function(Map<String, dynamic> data);

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  static String get baseUrl => ApiConstants.baseUrl;

  io.Socket? _socket;
  bool _isConnected = false;
  String? _currentUserId;

  // Track active conversations for re-joining on reconnect
  final Set<String> _activeConversations = {};

  // Event listeners
  final List<MessageCallback> _messageListeners = [];
  final List<StatusCallback> _onlineStatusListeners = [];
  final List<TypingCallback> _typingListeners = [];
  final List<ReadCallback> _readListeners = [];
  final List<TokenEventCallback> _tokenEventListeners = [];
  final List<BoliAlertCallback> _boliAlertListeners = [];
  final List<BuyRequestResponseCallback> _buyRequestResponseListeners = [];

  // Connection state stream
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  bool get isConnected => _isConnected;
  io.Socket? get socket => _socket;

  /// Initialize and connect to Socket.IO server
  Future<bool> connect() async {
    if (_isConnected && _socket != null) {
      return true;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      if (token == null) {
        print('SocketService: No auth token available');
        return false;
      }

      // Get user ID for tracking
      final userJson = prefs.getString('user');
      if (userJson != null) {
        // Parse user ID from stored user data
        // This is used to identify the current user
      }

      _socket = io.io(
        baseUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(10)
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .setAuth({'token': token})
            .build(),
      );

      _setupEventListeners();

      return true;
    } catch (e) {
      print('SocketService: Connection error - $e');
      return false;
    }
  }

  /// Setup all socket event listeners
  void _setupEventListeners() {
    if (_socket == null) return;

    // Connection events
    _socket!.onConnect((_) {
      print('SocketService: Connected to server');
      _isConnected = true;
      _connectionController.add(true);
      // Re-join all active conversations on connect
      _rejoinActiveConversations();
    });

    _socket!.onDisconnect((_) {
      print('SocketService: Disconnected from server');
      _isConnected = false;
      _connectionController.add(false);
    });

    _socket!.onConnectError((error) {
      print('SocketService: Connection error - $error');
      _isConnected = false;
      _connectionController.add(false);
    });

    _socket!.onReconnect((_) {
      print('SocketService: Reconnected to server');
      _isConnected = true;
      _connectionController.add(true);
      // Re-join all active conversations on reconnect
      _rejoinActiveConversations();
    });

    // Message events
    _socket!.on('receiveMessage', (data) {
      try {
        print('SocketService: Received message');
        final message = Map<String, dynamic>.from(data);
        for (final listener in _messageListeners) {
          listener(message);
        }
      } catch (e) {
        print('SocketService: Error processing receiveMessage - $e');
      }
    });

    _socket!.on('newMessageNotification', (data) {
      try {
        print('SocketService: New message notification');
        final notification = Map<String, dynamic>.from(data);
        // This can be used for push notifications or badges
        if (notification['message'] != null) {
          for (final listener in _messageListeners) {
            listener(Map<String, dynamic>.from(notification['message']));
          }
        }
      } catch (e) {
        print('SocketService: Error processing newMessageNotification - $e');
      }
    });

    _socket!.on('messageSent', (data) {
      print('SocketService: Message sent confirmation');
    });

    _socket!.on('messageDelivered', (data) {
      print('SocketService: Message delivered');
    });

    _socket!.on('messagesRead', (data) {
      print('SocketService: Messages read');
      final readData = Map<String, dynamic>.from(data);
      for (final listener in _readListeners) {
        listener(readData['conversationId'], readData['readBy']);
      }
    });

    // Online status events
    _socket!.on('userOnline', (data) {
      final userData = Map<String, dynamic>.from(data);
      for (final listener in _onlineStatusListeners) {
        listener(userData['userId'], true);
      }
    });

    _socket!.on('userOffline', (data) {
      final userData = Map<String, dynamic>.from(data);
      for (final listener in _onlineStatusListeners) {
        listener(userData['userId'], false);
      }
    });

    _socket!.on('onlineStatuses', (data) {
      final statuses = Map<String, dynamic>.from(data);
      statuses.forEach((userId, isOnline) {
        for (final listener in _onlineStatusListeners) {
          listener(userId, isOnline as bool);
        }
      });
    });

    // Typing events
    _socket!.on('userTyping', (data) {
      final typingData = Map<String, dynamic>.from(data);
      for (final listener in _typingListeners) {
        listener(
          typingData['userId'],
          typingData['userName'],
          typingData['isTyping'],
        );
      }
    });

    // Error handling
    _socket!.on('error', (data) {
      print('SocketService: Error - $data');
    });

    // Conversation events
    _socket!.on('joinedConversation', (data) {
      print('SocketService: Joined conversation - ${data['conversationId']}');
    });

    // =============================================
    // TOKEN QUEUE EVENTS
    // =============================================

    // Token called - farmer's turn now
    _socket!.on('token_called', (data) {
      print('SocketService: Token called - ${data['tokenNumber']}');
      final tokenData = Map<String, dynamic>.from(data);
      tokenData['event'] = 'token_called';
      for (final listener in _tokenEventListeners) {
        listener(tokenData);
      }
    });

    // Token nearby - turn is coming
    _socket!.on('token_nearby', (data) {
      print('SocketService: Token nearby - ${data['tokenNumber']}');
      final tokenData = Map<String, dynamic>.from(data);
      tokenData['event'] = 'token_nearby';
      for (final listener in _tokenEventListeners) {
        listener(tokenData);
      }
    });

    // Token skipped
    _socket!.on('token_skipped', (data) {
      print('SocketService: Token skipped - ${data['tokenNumber']}');
      final tokenData = Map<String, dynamic>.from(data);
      tokenData['event'] = 'token_skipped';
      for (final listener in _tokenEventListeners) {
        listener(tokenData);
      }
    });

    // Token issued (confirmation)
    _socket!.on('token_issued', (data) {
      print('SocketService: Token issued - ${data['tokenNumber']}');
      final tokenData = Map<String, dynamic>.from(data);
      tokenData['event'] = 'token_issued';
      for (final listener in _tokenEventListeners) {
        listener(tokenData);
      }
    });

    // Token in service
    _socket!.on('token_in_service', (data) {
      print('SocketService: Token in service - ${data['tokenNumber']}');
      final tokenData = Map<String, dynamic>.from(data);
      tokenData['event'] = 'token_in_service';
      for (final listener in _tokenEventListeners) {
        listener(tokenData);
      }
    });

    // Token completed
    _socket!.on('token_completed', (data) {
      print('SocketService: Token completed - ${data['tokenNumber']}');
      final tokenData = Map<String, dynamic>.from(data);
      tokenData['event'] = 'token_completed';
      for (final listener in _tokenEventListeners) {
        listener(tokenData);
      }
    });

    // Queue position update (real-time position tracking)
    _socket!.on('token_queue_update', (data) {
      final tokenData = Map<String, dynamic>.from(data);
      tokenData['event'] = 'token_queue_update';
      for (final listener in _tokenEventListeners) {
        listener(tokenData);
      }
    });

    // Queue updated (for cold storage owner)
    _socket!.on('token_queue_updated', (data) {
      final tokenData = Map<String, dynamic>.from(data);
      tokenData['event'] = 'token_queue_updated';
      for (final listener in _tokenEventListeners) {
        listener(tokenData);
      }
    });

    // =============================================
    // BOLI ALERT REMINDER EVENTS
    // =============================================

    // Boli alert reminder (3 days / 2 days / 1 day before)
    _socket!.on('boli_alert_reminder', (data) {
      print('SocketService: Boli alert reminder received');
      final alertData = Map<String, dynamic>.from(data);
      for (final listener in _boliAlertListeners) {
        listener(alertData);
      }
    });

    // =============================================
    // BUY REQUEST RESPONSE EVENTS
    // =============================================

    // Farmer responded to a trader's buy request
    _socket!.on('buy_request_response', (data) {
      print('SocketService: Buy request response received');
      final responseData = Map<String, dynamic>.from(data);
      for (final listener in _buyRequestResponseListeners) {
        listener(responseData);
      }
    });
  }

  /// Re-join all active conversations (called on connect/reconnect)
  void _rejoinActiveConversations() {
    if (_socket == null || !_isConnected) return;
    for (final convId in _activeConversations) {
      print('SocketService: Re-joining conversation $convId');
      _socket!.emit('joinConversation', convId);
    }
  }

  /// Join a conversation room to receive messages
  void joinConversation(String conversationId) {
    // Track the conversation so we can re-join on reconnect
    _activeConversations.add(conversationId);
    if (_socket != null && _isConnected) {
      _socket!.emit('joinConversation', conversationId);
    } else {
      print('SocketService: Socket not connected, will join conversation $conversationId on connect');
    }
  }

  /// Leave a conversation room
  void leaveConversation(String conversationId) {
    _activeConversations.remove(conversationId);
    if (_socket != null && _isConnected) {
      _socket!.emit('leaveConversation', conversationId);
    }
  }

  /// Send a message via socket
  void sendMessage({
    required String conversationId,
    required String content,
    String messageType = 'text',
    Map<String, dynamic>? dealDetails,
  }) {
    if (_socket != null && _isConnected) {
      _socket!.emit('sendMessage', {
        'conversationId': conversationId,
        'content': content,
        'messageType': messageType,
        if (dealDetails != null) 'dealDetails': dealDetails,
      });
    }
  }

  /// Mark messages as read
  void markAsRead(String conversationId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('markAsRead', {'conversationId': conversationId});
    }
  }

  /// Send typing indicator
  void sendTypingStatus(String conversationId, bool isTyping) {
    if (_socket != null && _isConnected) {
      _socket!.emit('typing', {
        'conversationId': conversationId,
        'isTyping': isTyping,
      });
    }
  }

  /// Request online status for specific users
  void getOnlineStatus(List<String> userIds) {
    if (_socket != null && _isConnected) {
      _socket!.emit('getOnlineStatus', userIds);
    }
  }

  // =============================================
  // LISTENER MANAGEMENT
  // =============================================

  /// Add message listener
  void addMessageListener(MessageCallback callback) {
    _messageListeners.add(callback);
  }

  /// Remove message listener
  void removeMessageListener(MessageCallback callback) {
    _messageListeners.remove(callback);
  }

  /// Add online status listener
  void addOnlineStatusListener(StatusCallback callback) {
    _onlineStatusListeners.add(callback);
  }

  /// Remove online status listener
  void removeOnlineStatusListener(StatusCallback callback) {
    _onlineStatusListeners.remove(callback);
  }

  /// Add typing listener
  void addTypingListener(TypingCallback callback) {
    _typingListeners.add(callback);
  }

  /// Remove typing listener
  void removeTypingListener(TypingCallback callback) {
    _typingListeners.remove(callback);
  }

  /// Add read listener
  void addReadListener(ReadCallback callback) {
    _readListeners.add(callback);
  }

  /// Remove read listener
  void removeReadListener(ReadCallback callback) {
    _readListeners.remove(callback);
  }

  /// Add token event listener
  void addTokenEventListener(TokenEventCallback callback) {
    _tokenEventListeners.add(callback);
  }

  /// Remove token event listener
  void removeTokenEventListener(TokenEventCallback callback) {
    _tokenEventListeners.remove(callback);
  }

  /// Add boli alert listener
  void addBoliAlertListener(BoliAlertCallback callback) {
    _boliAlertListeners.add(callback);
  }

  /// Remove boli alert listener
  void removeBoliAlertListener(BoliAlertCallback callback) {
    _boliAlertListeners.remove(callback);
  }

  /// Add buy request response listener
  void addBuyRequestResponseListener(BuyRequestResponseCallback callback) {
    _buyRequestResponseListeners.add(callback);
  }

  /// Remove buy request response listener
  void removeBuyRequestResponseListener(BuyRequestResponseCallback callback) {
    _buyRequestResponseListeners.remove(callback);
  }

  /// Disconnect from server
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _connectionController.add(false);
  }

  /// Dispose the service
  void dispose() {
    disconnect();
    _messageListeners.clear();
    _onlineStatusListeners.clear();
    _typingListeners.clear();
    _readListeners.clear();
    _tokenEventListeners.clear();
    _boliAlertListeners.clear();
    _buyRequestResponseListeners.clear();
    _connectionController.close();
  }
}
