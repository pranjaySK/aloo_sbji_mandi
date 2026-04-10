import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aloo_sbji_mandi/core/constants/api_constant.dart';

class PaymentService {
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

  // Create payment order (farmer requests payment)
  Future<Map<String, dynamic>> createPaymentOrder(String dealId) async {
    final headers = await _getHeaders();

    final response = await http.post(
      Uri.parse('$baseUrl/payments/create-order'),
      headers: headers,
      body: jsonEncode({'dealId': dealId}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return {
        'success': true,
        'data': data['data'],
      };
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to create payment order',
      };
    }
  }

  // Verify payment after completion
  Future<Map<String, dynamic>> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
    required String dealId,
  }) async {
    final headers = await _getHeaders();

    final response = await http.post(
      Uri.parse('$baseUrl/payments/verify'),
      headers: headers,
      body: jsonEncode({
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
        'dealId': dealId,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return {
        'success': true,
        'message': 'Payment verified successfully',
        'data': data['data'],
      };
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'Payment verification failed',
      };
    }
  }

  // Get payment status for a deal
  Future<Map<String, dynamic>> getPaymentStatus(String dealId) async {
    final headers = await _getHeaders();

    final response = await http.get(
      Uri.parse('$baseUrl/payments/status/$dealId'),
      headers: headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return {
        'success': true,
        'data': data['data'],
      };
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to get payment status',
      };
    }
  }

  // Get Razorpay key
  Future<Map<String, dynamic>> getRazorpayKey() async {
    final headers = await _getHeaders();

    final response = await http.get(
      Uri.parse('$baseUrl/payments/key'),
      headers: headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return {
        'success': true,
        'key': data['data']['key'],
      };
    }
    return {
      'success': false,
      'message': 'Failed to get Razorpay key',
    };
  }
}
