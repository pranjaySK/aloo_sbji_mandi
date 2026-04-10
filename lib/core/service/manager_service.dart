import 'dart:convert';

import 'package:aloo_sbji_mandi/core/constants/api_constant.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ManagerService {
  static String get baseUrl => '${ApiConstants.baseUrl}/api/v1/manager';

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

  // ============================================
  // DASHBOARD
  // ============================================

  /// Get manager dashboard with cold storage info + stats
  Future<Map<String, dynamic>> getDashboard() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/dashboard'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch dashboard',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ============================================
  // COLD STORAGE
  // ============================================

  /// Get manager's assigned cold storage
  Future<Map<String, dynamic>> getMyStorage() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/my-storage'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'No cold storage assigned',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Update storage details (limited: phone, availableCapacity, pricePerTon)
  Future<Map<String, dynamic>> updateStorageDetails({
    String? phone,
    int? availableCapacity,
    int? pricePerTon,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{};
      if (phone != null) body['phone'] = phone;
      if (availableCapacity != null)
        body['availableCapacity'] = availableCapacity;
      if (pricePerTon != null) body['pricePerTon'] = pricePerTon;

      final response = await http.put(
        Uri.parse('$baseUrl/my-storage'),
        headers: headers,
        body: json.encode(body),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Toggle storage availability
  Future<Map<String, dynamic>> toggleAvailability() async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/my-storage/toggle'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to toggle',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ============================================
  // BOOKINGS
  // ============================================

  /// Get all booking requests for manager's cold storage
  Future<Map<String, dynamic>> getBookingRequests({String? status}) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{};
      if (status != null) queryParams['status'] = status;

      final uri = Uri.parse(
        '$baseUrl/bookings',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(uri, headers: headers);
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch bookings',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Get booking stats
  Future<Map<String, dynamic>> getBookingStats() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/stats'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch stats',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Get single booking by ID
  Future<Map<String, dynamic>> getBookingById(String bookingId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/$bookingId'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch booking',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Respond to booking (accept/reject)
  Future<Map<String, dynamic>> respondToBooking({
    required String bookingId,
    required String action, // 'accept' or 'reject'
    String? ownerResponse,
    String? startDate,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{'action': action};
      if (ownerResponse != null) body['ownerResponse'] = ownerResponse;
      if (startDate != null) body['startDate'] = startDate;

      final response = await http.patch(
        Uri.parse('$baseUrl/bookings/$bookingId/respond'),
        headers: headers,
        body: json.encode(body),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to respond',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ============================================
  // MANAGER PROFILE
  // ============================================

  /// Get manager profile
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/profile'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch profile',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Update manager profile (name only)
  Future<Map<String, dynamic>> updateProfile({
    String? firstName,
    String? lastName,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{};
      if (firstName != null) body['firstName'] = firstName;
      if (lastName != null) body['lastName'] = lastName;

      final response = await http.put(
        Uri.parse('$baseUrl/profile'),
        headers: headers,
        body: json.encode(body),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update profile',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
}
