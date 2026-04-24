import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aloo_sbji_mandi/core/constants/api_constant.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_models.dart';
import 'socket_service.dart';
import 'package:logger/logger.dart';

class ChatService {
  // Backend URL - using production server
  static String get baseUrl => '${ApiConstants.baseUrl}/api/v1';

  // Socket service for real-time messaging
  final SocketService _socketService = SocketService();
  final Logger _logger = Logger();
  static const _encoder = JsonEncoder.withIndent('  ');

  void _logApi(String method, String endpoint, {dynamic request, required int status, dynamic response}) {
    _logger.i(
      '[ChatService] $method $endpoint\n'
      '  ── REQUEST:  ${request != null ? _encoder.convert(request) : 'none'}\n'
      '  ── STATUS:   $status\n'
      '  ── RESPONSE: ${response != null ? _encoder.convert(response) : 'none'}',
    );
  }

  // Get socket service instance
  SocketService get socketService => _socketService;

  // Get auth token from shared preferences
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  // Get headers with auth
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Initialize socket connection
  Future<bool> connectSocket() async {
    return await _socketService.connect();
  }

  /// Disconnect socket
  void disconnectSocket() {
    _socketService.disconnect();
  }

  /// Check if socket is connected
  bool get isSocketConnected => _socketService.isConnected;

  /// Get connection status stream
  Stream<bool> get connectionStream => _socketService.connectionStream;

  // Get all conversations for current user
  Future<List<Conversation>> getConversations() async {
    final endpoint = '$baseUrl/chat/conversations';
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(endpoint),
        headers: headers,
      );
      final data = json.decode(response.body);
      _logApi('GET', endpoint, status: response.statusCode, response: data);

      if (response.statusCode == 200) {
        final List<dynamic> conversationsJson = data['data'] ?? [];
        return conversationsJson
            .map((json) => Conversation.fromJson(json))
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('SESSION_EXPIRED');
      } else {
        throw Exception('Failed to load conversations');
      }
    } catch (e) {
      _logger.e('[ChatService] GET $endpoint => Error: $e');
      rethrow;
    }
  }

  // Get users that current user can chat with
  Future<List<ChatUser>> getChatableUsers() async {
    final endpoint = '$baseUrl/chat/users';
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(endpoint),
        headers: headers,
      );
      final data = json.decode(response.body);
      _logApi('GET', endpoint, status: response.statusCode, response: data);

      if (response.statusCode == 200) {
        final List<dynamic> usersJson = data['data'] ?? [];
        return usersJson.map((json) => ChatUser.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load users');
      }
    } catch (e) {
      _logger.e('[ChatService] GET $endpoint => Error: $e');
      rethrow;
    }
  }

  // Search users
  Future<List<ChatUser>> searchUsers({String? query, String? role}) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{};
      if (query != null && query.isNotEmpty) queryParams['query'] = query;
      if (role != null && role.isNotEmpty) queryParams['role'] = role;

      final uri = Uri.parse(
        '$baseUrl/chat/users/search',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(uri, headers: headers);
      final data = json.decode(response.body);
      _logApi('GET', uri.toString(), status: response.statusCode, response: data);

      if (response.statusCode == 200) {
        final List<dynamic> usersJson = data['data'] ?? [];
        return usersJson.map((json) => ChatUser.fromJson(json)).toList();
      } else {
        throw Exception('Failed to search users');
      }
    } catch (e) {
      _logger.e('[ChatService] searchUsers Error: $e');
      rethrow;
    }
  }

  // Get or create conversation with a user
  Future<String> getOrCreateConversation(String otherUserId) async {
    final endpoint = '$baseUrl/chat/conversation/$otherUserId';
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse(endpoint),
        headers: headers,
      );
      final data = json.decode(response.body);
      _logApi('GET', endpoint, status: response.statusCode, response: data);

      if (response.statusCode == 200) {
        final conversationId = data['data']['_id'];

        // Join the conversation room via socket
        _socketService.joinConversation(conversationId);

        return conversationId;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication required. Please login again.');
      } else {
        final errorMessage =
            data['message'] ?? 'Failed to get/create conversation';
        throw Exception(errorMessage);
      }
    } catch (e) {
      _logger.e('[ChatService] GET $endpoint => Error: $e');
      rethrow;
    }
  }

  /// Get or create conversation with context (e.g., linked to a listing or booking)
  Future<Map<String, dynamic>> getOrCreateConversationWithContext({
    required String otherUserId,
    String? contextType,
    String? contextId,
    String? contextModel,
    Map<String, dynamic>? contextDetails,
  }) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{};

      if (contextType != null) queryParams['contextType'] = contextType;
      if (contextId != null) queryParams['contextId'] = contextId;
      if (contextModel != null) queryParams['contextModel'] = contextModel;
      if (contextDetails != null) {
        queryParams['contextDetails'] = json.encode(contextDetails);
      }

      final uri = Uri.parse(
        '$baseUrl/chat/conversation/$otherUserId',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(uri, headers: headers);
      final data = json.decode(response.body);
      _logApi('GET', uri.toString(), request: queryParams, status: response.statusCode, response: data);

      if (response.statusCode == 200) {
        final conversationId = data['data']['_id'];

        // Join the conversation room via socket
        _socketService.joinConversation(conversationId);

        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to start conversation',
        };
      }
    } catch (e) {
      _logger.e('[ChatService] getOrCreateConversationWithContext Error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Start or get conversation - returns full response
  Future<Map<String, dynamic>> startOrGetConversation(
    String otherUserId,
  ) async {
    final endpoint = '$baseUrl/chat/conversation/$otherUserId';
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(endpoint),
        headers: headers,
      );
      final data = json.decode(response.body);
      _logApi('GET', endpoint, status: response.statusCode, response: data);

      if (response.statusCode == 200) {
        final conversationId = data['data']['_id'];

        // Join the conversation room via socket
        _socketService.joinConversation(conversationId);

        return {'success': true, 'data': data['data'] ?? data};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to start conversation',
        };
      }
    } catch (e) {
      _logger.e('[ChatService] GET $endpoint => Error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Get messages for a conversation
  Future<List<Message>> getMessages(
    String conversationId, {
    int page = 1,
    int limit = 50,
  }) async {
    final endpoint = '$baseUrl/chat/messages/$conversationId?page=$page&limit=$limit';
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(endpoint),
        headers: headers,
      );
      final data = json.decode(response.body);
      _logApi('GET', endpoint, status: response.statusCode, response: data);

      if (response.statusCode == 200) {
        final List<dynamic> messagesJson = data['data'] ?? [];
        return messagesJson.map((json) => Message.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load messages');
      }
    } catch (e) {
      _logger.e('[ChatService] GET $endpoint => Error: $e');
      rethrow;
    }
  }

  // Send a message via REST API (fallback if socket fails)
  Future<Message> sendMessage(
    String conversationId,
    String content, {
    String messageType = 'text',
    DealDetails? dealDetails,
    Map<String, dynamic>? dealDetailsMap,
  }) async {
    final endpoint = '$baseUrl/chat/messages/$conversationId';
    try {
      final headers = await _getHeaders();
      final Map<String, dynamic> body = {
        'content': content,
        'messageType': messageType,
      };

      if (dealDetails != null) {
        body['dealDetails'] = dealDetails.toJson();
      } else if (dealDetailsMap != null) {
        body['dealDetails'] = dealDetailsMap;
      }

      final response = await http.post(
        Uri.parse(endpoint),
        headers: headers,
        body: json.encode(body),
      );
      final data = json.decode(response.body);
      _logApi('POST', endpoint, request: body, status: response.statusCode, response: data);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return Message.fromJson(data['data']);
      } else {
        throw Exception('Failed to send message');
      }
    } catch (e) {
      _logger.e('[ChatService] POST $endpoint => Error: $e');
      rethrow;
    }
  }

  /// Send a message via Socket.IO (preferred for real-time)
  void sendMessageRealtime({
    required String conversationId,
    required String content,
    String messageType = 'text',
    Map<String, dynamic>? dealDetails,
  }) {
    _socketService.sendMessage(
      conversationId: conversationId,
      content: content,
      messageType: messageType,
      dealDetails: dealDetails,
    );
  }

  /// Send typing indicator
  void sendTypingStatus(String conversationId, bool isTyping) {
    _socketService.sendTypingStatus(conversationId, isTyping);
  }

  /// Join a conversation room (call when entering chat screen)
  void joinConversation(String conversationId) {
    _socketService.joinConversation(conversationId);
  }

  /// Leave a conversation room (call when leaving chat screen)
  void leaveConversation(String conversationId) {
    _socketService.leaveConversation(conversationId);
  }

  // Mark messages as read
  Future<void> markAsRead(String conversationId) async {
    // Also notify via socket for real-time read receipts
    _socketService.markAsRead(conversationId);

    final endpoint = '$baseUrl/chat/messages/$conversationId/read';
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse(endpoint),
        headers: headers,
      );
      final data = response.body.isNotEmpty ? json.decode(response.body) : null;
      _logApi('PATCH', endpoint, status: response.statusCode, response: data);
    } catch (e) {
      _logger.e('[ChatService] PATCH $endpoint => Error: $e');
    }
  }

  /// Get online status for specific users
  Future<Map<String, bool>> getOnlineStatus(List<String> userIds) async {
    final endpoint = '$baseUrl/chat/users/online?userIds=${userIds.join(',')}';
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(endpoint),
        headers: headers,
      );
      final data = json.decode(response.body);
      _logApi('GET', endpoint, status: response.statusCode, response: data);

      if (response.statusCode == 200) {
        final Map<String, dynamic> statuses = data['data'] ?? {};
        return statuses.map((key, value) => MapEntry(key, value as bool));
      }
      return {};
    } catch (e) {
      _logger.e('[ChatService] GET $endpoint => Error: $e');
      return {};
    }
  }

  // =============================================
  // SOCKET LISTENER HELPERS
  // =============================================

  /// Add listener for incoming messages
  void addMessageListener(MessageCallback callback) {
    _socketService.addMessageListener(callback);
  }

  /// Remove message listener
  void removeMessageListener(MessageCallback callback) {
    _socketService.removeMessageListener(callback);
  }

  /// Add listener for online status changes
  void addOnlineStatusListener(StatusCallback callback) {
    _socketService.addOnlineStatusListener(callback);
  }

  /// Remove online status listener
  void removeOnlineStatusListener(StatusCallback callback) {
    _socketService.removeOnlineStatusListener(callback);
  }

  /// Add listener for typing indicators
  void addTypingListener(TypingCallback callback) {
    _socketService.addTypingListener(callback);
  }

  /// Remove typing listener
  void removeTypingListener(TypingCallback callback) {
    _socketService.removeTypingListener(callback);
  }

  /// Add listener for read receipts
  void addReadListener(ReadCallback callback) {
    _socketService.addReadListener(callback);
  }

  /// Remove read listener
  void removeReadListener(ReadCallback callback) {
    _socketService.removeReadListener(callback);
  }

  // Poll for new messages (fallback mechanism)
  Stream<List<Message>> pollMessages(
    String conversationId, {
    Duration interval = const Duration(seconds: 3),
  }) {
    return Stream.periodic(
      interval,
      (_) => conversationId,
    ).asyncMap((id) => getMessages(id));
  }

  /// Upload and send an image message (QR code, photos, etc.)
  /// The image is sent as base64 encoded data for simplicity
  Future<Message> sendImageMessage(
    String conversationId,
    dynamic imageData, { // Can be File (mobile) or List<int> (web)
    String? caption,
  }) async {
    final endpoint = '$baseUrl/chat/messages/$conversationId';
    _logger.i('[ChatService] POST $endpoint (image) caption=${caption ?? ""}');
    try {
      String base64Image;

      // Handle both mobile (File) and web (bytes) cases
      if (imageData is File) {
        final bytes = await imageData.readAsBytes();
        base64Image = base64Encode(bytes);
      } else if (imageData is List<int>) {
        base64Image = base64Encode(imageData);
      } else {
        throw Exception('Invalid image data type');
      }

      // Create the content as JSON with base64 image data
      final imageContent = json.encode({
        'imageData': base64Image,
        'caption': caption ?? '',
      });

      final headers = await _getHeaders();
      final Map<String, dynamic> body = {
        'content': imageContent,
        'messageType': 'image',
      };

      final response = await http.post(
        Uri.parse(endpoint),
        headers: headers,
        body: json.encode(body),
      );
      _logger.d('[ChatService] POST $endpoint (image) => status=${response.statusCode} body=${response.body}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return Message.fromJson(data['data']);
      } else {
        throw Exception('Failed to send image message');
      }
    } catch (e) {
      _logger.e('[ChatService] POST $endpoint (image) => Error: $e');
      rethrow;
    }
  }
}
