import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:aloo_sbji_mandi/core/constants/api_constant.dart';
import 'package:aloo_sbji_mandi/core/service/auth_service.dart';

class AlooMitraService {
  static String get baseUrl => '${ApiConstants.baseUrl}/api/v1';
  final AuthService _authService = AuthService();

  /// Get Aloo Mitra profile details
  Future<Map<String, dynamic>> getAlooMitraProfile() async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not logged in'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/aloo-mitra/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to get profile'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Update Aloo Mitra profile
  Future<Map<String, dynamic>> updateAlooMitraProfile({
    required String serviceType,
    required String businessName,
    required String state,
    required String district,
    String? city,
    required String pricing,
    String? description,
  }) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not logged in'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/aloo-mitra/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'serviceType': serviceType,
          'businessName': businessName,
          'state': state,
          'district': district,
          'city': city ?? '',
          'pricing': pricing,
          'description': description ?? '',
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to update profile'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Get Aloo Mitra statistics (enquiries, deals, etc.)
  Future<Map<String, dynamic>> getAlooMitraStats() async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not logged in'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/aloo-mitra/stats'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        // Return default stats if API fails
        return {
          'success': true,
          'data': {
            'totalEnquiries': 0,
            'activeListings': 0,
            'completedDeals': 0,
            'rating': 0.0,
          }
        };
      }
    } catch (e) {
      // Return default stats on error
      return {
        'success': true,
        'data': {
          'totalEnquiries': 0,
          'activeListings': 0,
          'completedDeals': 0,
          'rating': 0.0,
        }
      };
    }
  }

  /// Get list of service providers by type
  Future<Map<String, dynamic>> getServiceProviders({
    String? serviceType,
    String? state,
    String? district,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not logged in'};
      }

      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      
      if (serviceType != null) queryParams['serviceType'] = serviceType;
      if (state != null) queryParams['state'] = state;
      if (district != null) queryParams['district'] = district;

      final uri = Uri.parse('$baseUrl/aloo-mitra/providers')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to get providers'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Send enquiry to a service provider
  Future<Map<String, dynamic>> sendEnquiry({
    required String providerId,
    required String message,
    String? quantity,
  }) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not logged in'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/aloo-mitra/enquiry'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'providerId': providerId,
          'message': message,
          'quantity': quantity,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to send enquiry'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Get enquiries received by the service provider
  Future<Map<String, dynamic>> getReceivedEnquiries({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not logged in'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/aloo-mitra/enquiries?page=$page&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to get enquiries'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
}
