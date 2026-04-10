import 'dart:convert';
import 'package:aloo_sbji_mandi/core/constants/api_constant.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class KycService {
  final String baseUrl = ApiConstants.baseUrl;
  static const Duration _timeout = Duration(seconds: 30);

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Map<String, dynamic> _safeParseResponse(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'data': data['data'],
        'message': data['message'] ?? 'Something went wrong',
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Server error (${response.statusCode})',
        'statusCode': response.statusCode,
      };
    }
  }

  // GET /api/v1/kyc/status
  Future<Map<String, dynamic>> getKycStatus() async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Not logged in'};

      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/kyc/status'),
        headers: _headers(token),
      ).timeout(_timeout);

      return _safeParseResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString().contains('TimeoutException') ? 'Request timed out. Please try again.' : 'Network error. Please check your connection.'};
    }
  }

  // POST /api/v1/kyc/send-otp
  Future<Map<String, dynamic>> sendAadhaarOtp(String aadhaarNumber) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Not logged in'};

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/kyc/send-otp'),
        headers: _headers(token),
        body: jsonEncode({'aadhaarNumber': aadhaarNumber}),
      ).timeout(_timeout);

      return _safeParseResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString().contains('TimeoutException') ? 'Request timed out. Please try again.' : 'Network error. Please check your connection.'};
    }
  }

  // POST /api/v1/kyc/verify-otp
  Future<Map<String, dynamic>> verifyAadhaarOtp(String otp, String transactionId) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Not logged in'};

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/kyc/verify-otp'),
        headers: _headers(token),
        body: jsonEncode({'otp': otp, 'transactionId': transactionId}),
      ).timeout(_timeout);

      return _safeParseResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString().contains('TimeoutException') ? 'Request timed out. Please try again.' : 'Network error. Please check your connection.'};
    }
  }

  // POST /api/v1/kyc/resend-otp
  Future<Map<String, dynamic>> resendAadhaarOtp() async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Not logged in'};

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/kyc/resend-otp'),
        headers: _headers(token),
        body: jsonEncode({}),
      ).timeout(_timeout);

      return _safeParseResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString().contains('TimeoutException') ? 'Request timed out. Please try again.' : 'Network error. Please check your connection.'};
    }
  }

  // POST /api/v1/kyc/upload-photo
  Future<Map<String, dynamic>> uploadAadhaarPhoto(String base64Photo) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Not logged in'};

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/kyc/upload-photo'),
        headers: _headers(token),
        body: jsonEncode({'photo': base64Photo}),
      ).timeout(const Duration(seconds: 60)); // longer timeout for photo upload

      return _safeParseResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString().contains('TimeoutException') ? 'Upload timed out. Please try again.' : 'Network error. Please check your connection.'};
    }
  }
}
