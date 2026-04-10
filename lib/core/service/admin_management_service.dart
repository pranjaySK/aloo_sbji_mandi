import 'dart:async';
import 'dart:convert';

import 'package:aloo_sbji_mandi/core/constants/api_constant.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AdminManagementService {
  static const String baseUrl = '${ApiConstants.baseUrl}/api/v1';

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

  // Check if current user is master
  Future<Map<String, dynamic>> checkRole() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/admin/check-role'),
        headers: headers,
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to check role',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Get all admins (master only)
  Future<Map<String, dynamic>> getAllAdmins() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/admin/admins'),
        headers: headers,
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch admins',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Create a new admin (master only)
  Future<Map<String, dynamic>> createAdmin({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
    String? email,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = {
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'password': password,
        if (email != null && email.isNotEmpty) 'email': email,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/admin/create-admin'),
        headers: headers,
        body: json.encode(body),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to create admin',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Update an admin (master only)
  Future<Map<String, dynamic>> updateAdmin({
    required String adminId,
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    String? password,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{};
      if (firstName != null) body['firstName'] = firstName;
      if (lastName != null) body['lastName'] = lastName;
      if (phone != null) body['phone'] = phone;
      if (email != null) body['email'] = email;
      if (password != null && password.isNotEmpty) body['password'] = password;

      final response = await http.put(
        Uri.parse('$baseUrl/admin/update-admin/$adminId'),
        headers: headers,
        body: json.encode(body),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update admin',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Delete an admin (master only)
  Future<Map<String, dynamic>> deleteAdmin(String adminId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/delete-admin/$adminId'),
        headers: headers,
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to delete admin',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Demote admin to regular user (master only)
  Future<Map<String, dynamic>> demoteAdmin(
    String adminId, {
    String? newRole,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{};
      if (newRole != null) body['newRole'] = newRole;

      final response = await http.put(
        Uri.parse('$baseUrl/admin/demote-admin/$adminId'),
        headers: headers,
        body: json.encode(body),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to demote admin',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Send broadcast notification to all users (admin only)
  Future<Map<String, dynamic>> sendBroadcastNotification({
    required String title,
    required String message,
    String? imageUrl,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = {
        'title': title,
        'message': message,
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      };

      final url = '$baseUrl/admin/broadcast-notification';
      print('🔵 Sending broadcast notification to: $url');
      print('🔵 Headers: $headers');
      print('🔵 Body: ${json.encode(body)}');

      final response = await http
          .post(
            Uri.parse(url),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('❌ Request timed out after 30 seconds');
              throw Exception('Request timed out. Server did not respond in time.');
            },
          );

      print('🔵 Response status: ${response.statusCode}');
      print('🔵 Response body: ${response.body}');

      // Handle authentication errors
      if (response.statusCode == 401 || response.statusCode == 403) {
        try {
          final data = json.decode(response.body);
          return {
            'success': false,
            'message': data['message'] ?? 'Authentication failed. Please login as admin.',
            'needsAuth': true,
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Authentication required. Please login again.',
            'needsAuth': true,
          };
        }
      }

      // Check if response is JSON before decoding
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          return {
            'success': true,
            'data': data['data'],
            'message': data['message'],
          };
        } catch (e) {
          print('❌ JSON decode error: $e');
          return {
            'success': false,
            'message': 'Invalid server response: $e',
          };
        }
      } else {
        try {
          final data = json.decode(response.body);
          return {
            'success': false,
            'message': data['message'] ?? 'Failed to send notification',
          };
        } catch (e) {
          print('❌ Error response decode error: $e');
          return {
            'success': false,
            'message':
                'Server error (${response.statusCode}): ${response.body.length > 100 ? response.body.substring(0, 100) : response.body}',
          };
        }
      }
    } on TimeoutException catch (e) {
      print('❌ Timeout error: $e');
      return {
        'success': false,
        'message':
            'Request timed out. The server is taking too long to respond. Please try again.',
      };
    } catch (e) {
      print('❌ Network error: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }
}
