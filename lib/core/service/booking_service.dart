import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aloo_sbji_mandi/core/constants/api_constant.dart';

class BookingService {
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

  // Create a new booking
  Future<Map<String, dynamic>> createBooking({
    required String coldStorageId,
    required int quantity,
    int duration = 1,
    String? farmerNote,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/create'),
        headers: headers,
        body: json.encode({
          'coldStorageId': coldStorageId,
          'quantity': quantity,
          'duration': duration,
          'farmerNote': farmerNote ?? '',
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'data': data['data'], 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to create booking'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get my bookings (for farmers)
  Future<Map<String, dynamic>> getMyBookings({String? status}) async {
    try {
      final headers = await _getHeaders();
      final queryParams = status != null ? '?status=$status' : '';
      
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/my-bookings$queryParams'),
        headers: headers,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to fetch bookings'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get booking requests (for cold storage owners)
  Future<Map<String, dynamic>> getBookingRequests({String? status}) async {
    try {
      final headers = await _getHeaders();
      final queryParams = status != null ? '?status=$status' : '';
      
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/requests$queryParams'),
        headers: headers,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to fetch requests'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get single booking
  Future<Map<String, dynamic>> getBooking(String bookingId) async {
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
        return {'success': false, 'message': data['message'] ?? 'Booking not found'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Update booking (farmer only, pending bookings)
  Future<Map<String, dynamic>> updateBooking({
    required String bookingId,
    int? quantity,
    int? duration,
    String? farmerNote,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{};
      if (quantity != null) body['quantity'] = quantity;
      if (duration != null) body['duration'] = duration;
      if (farmerNote != null) body['farmerNote'] = farmerNote;

      final response = await http.patch(
        Uri.parse('$baseUrl/bookings/$bookingId'),
        headers: headers,
        body: json.encode(body),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data'], 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to update booking'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Accept or reject booking (owner only)
  Future<Map<String, dynamic>> respondToBooking({
    required String bookingId,
    required String action, // 'accept' or 'reject'
    String? ownerResponse,
    DateTime? startDate,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{
        'action': action,
      };
      if (ownerResponse != null) body['ownerResponse'] = ownerResponse;
      if (startDate != null) body['startDate'] = startDate.toIso8601String();

      final response = await http.patch(
        Uri.parse('$baseUrl/bookings/$bookingId/respond'),
        headers: headers,
        body: json.encode(body),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data'], 'message': data['message']};
      } else {
        final errorDetail = data['error'] != null ? ' (${data['error']})' : '';
        return {'success': false, 'message': (data['message'] ?? 'Failed to respond') + errorDetail};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Cancel booking (farmer only)
  Future<Map<String, dynamic>> cancelBooking(String bookingId) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.patch(
        Uri.parse('$baseUrl/bookings/$bookingId/cancel'),
        headers: headers,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data'], 'message': data['message']};
      } else {
        final errorDetail = data['error'] != null ? ' (${data['error']})' : '';
        return {'success': false, 'message': (data['message'] ?? 'Failed to cancel booking') + errorDetail};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Delete booking (owner only)
  Future<Map<String, dynamic>> deleteBooking(String bookingId) async {
    try {
      final headers = await _getHeaders();

      final response = await http.delete(
        Uri.parse('$baseUrl/bookings/$bookingId'),
        headers: headers,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'Booking deleted'};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to delete booking'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
}
