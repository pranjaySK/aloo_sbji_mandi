import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aloo_sbji_mandi/core/constants/api_constant.dart';

class NotificationService {
  static String get baseUrl => '${ApiConstants.baseUrl}/api/v1';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Get all notifications
  Future<Map<String, dynamic>> getNotifications({
    int limit = 50,
    int skip = 0,
    bool unreadOnly = false,
    List<String>? types,
  }) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'skip': skip.toString(),
      };
      if (unreadOnly) queryParams['unreadOnly'] = 'true';
      if (types != null && types.isNotEmpty) {
        queryParams['types'] = types.join(',');
      }

      final uri = Uri.parse('$baseUrl/notifications')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to fetch notifications'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get unread count
  Future<int> getUnreadCount({List<String>? types}) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{};
      if (types != null && types.isNotEmpty) {
        queryParams['types'] = types.join(',');
      }

      final uri = Uri.parse('$baseUrl/notifications/unread-count')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(uri, headers: headers);

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data['data']['unreadCount'] ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // Mark notification as read
  Future<bool> markAsRead(String notificationId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/notifications/$notificationId/read'),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Mark all as read
  Future<bool> markAllAsRead({List<String>? types}) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{};
      if (types != null && types.isNotEmpty) {
        body['types'] = types;
      }

      final response = await http.patch(
        Uri.parse('$baseUrl/notifications/read-all'),
        headers: headers,
        body: json.encode(body),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Mark all as seen
  Future<bool> markAllAsSeen() async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/notifications/seen-all'),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Delete notification
  Future<bool> deleteNotification(String notificationId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/notifications/$notificationId'),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Clear all notifications
  Future<bool> clearAll() async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/notifications'),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
