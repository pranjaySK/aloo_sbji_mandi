import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aloo_sbji_mandi/core/constants/api_constant.dart';

class UserService {
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

  // Update user profile
  Future<Map<String, dynamic>> updateProfile({
    String? firstName,
    String? lastName,
    String? village,
    String? district,
    String? state,
  }) async {
    try {
      final headers = await _getHeaders();
      
      final body = <String, dynamic>{};
      if (firstName != null) body['firstName'] = firstName;
      if (lastName != null) body['lastName'] = lastName;
      
      body['address'] = {
        if (village != null) 'village': village,
        if (district != null) 'district': district,
        if (state != null) 'state': state,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/user/profile/update'),
        headers: headers,
        body: json.encode(body),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        // Update stored user data
        final prefs = await SharedPreferences.getInstance();
        if (data['data']?['user'] != null) {
          await prefs.setString('user', json.encode(data['data']['user']));
        }
        return {'success': true, 'data': data['data'], 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to update profile'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get current user profile
  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/user/me'),
        headers: headers,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['user']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to fetch user'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
}
