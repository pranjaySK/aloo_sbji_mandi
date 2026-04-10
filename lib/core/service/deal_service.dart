import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aloo_sbji_mandi/core/constants/api_constant.dart';
import '../models/deal_model.dart';

class DealService {
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

  // Propose a new deal
  Future<Deal> proposeDeal({
    required String conversationId,
    String? bookingId,
    required double quantity,
    required double pricePerTon,
    int duration = 1,
    String? notes,
  }) async {
    final headers = await _getHeaders();
    
    try {
      final requestBody = {
        'conversationId': conversationId,
        if (bookingId != null) 'bookingId': bookingId,
        'quantity': quantity,
        'pricePerTon': pricePerTon,
        'duration': duration,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };
      
      print('Proposing deal with data: $requestBody');
      
      final response = await http.post(
        Uri.parse('$baseUrl/deals/propose'),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      print('Deal response status: ${response.statusCode}');
      print('Deal response body: ${response.body}');
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 201 && data['success'] == true) {
        return Deal.fromJson(data['data']['deal']);
      } else {
        final errorMessage = data['message'] ?? 'Failed to create deal proposal';
        print('Deal error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Deal exception: $e');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: $e');
    }
  }

  // Confirm a deal
  Future<Deal> confirmDeal(String dealId) async {
    final headers = await _getHeaders();
    
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/deals/$dealId/confirm'),
        headers: headers,
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['success'] == true) {
        return Deal.fromJson(data['data']['deal']);
      } else {
        throw Exception(data['message'] ?? 'Failed to confirm deal (${response.statusCode})');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: $e');
    }
  }

  // Cancel a deal
  Future<void> cancelDeal(String dealId, {String? reason}) async {
    final headers = await _getHeaders();
    
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/deals/$dealId/cancel'),
        headers: headers,
        body: jsonEncode({
          if (reason != null) 'reason': reason,
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode != 200 || data['success'] != true) {
        throw Exception(data['message'] ?? 'Failed to cancel deal (${response.statusCode})');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: $e');
    }
  }

  // Get deals for a conversation
  Future<List<Deal>> getDealsForConversation(String conversationId) async {
    final headers = await _getHeaders();
    
    final response = await http.get(
      Uri.parse('$baseUrl/deals/conversation/$conversationId'),
      headers: headers,
    );

    final data = jsonDecode(response.body);
    
    if (response.statusCode == 200 && data['success'] == true) {
      final dealsList = data['data']['deals'] as List;
      return dealsList.map((d) => Deal.fromJson(d)).toList();
    } else {
      throw Exception(data['message'] ?? 'Failed to fetch deals');
    }
  }

  // Get my deals
  Future<List<Deal>> getMyDeals({String? status}) async {
    final headers = await _getHeaders();
    
    String url = '$baseUrl/deals/my-deals';
    if (status != null) {
      url += '?status=$status';
    }
    
    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    final data = jsonDecode(response.body);
    
    if (response.statusCode == 200 && data['success'] == true) {
      final dealsList = data['data']['deals'] as List;
      return dealsList.map((d) => Deal.fromJson(d)).toList();
    } else {
      throw Exception(data['message'] ?? 'Failed to fetch deals');
    }
  }

  // Get single deal
  Future<Deal> getDeal(String dealId) async {
    final headers = await _getHeaders();
    
    final response = await http.get(
      Uri.parse('$baseUrl/deals/$dealId'),
      headers: headers,
    );

    final data = jsonDecode(response.body);
    
    if (response.statusCode == 200 && data['success'] == true) {
      return Deal.fromJson(data['data']['deal']);
    } else {
      throw Exception(data['message'] ?? 'Failed to fetch deal');
    }
  }

  // Confirm payment sent (payer's side)
  Future<Deal> confirmPaymentSent(String dealId) async {
    final headers = await _getHeaders();
    
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/deals/$dealId/confirm-payment-sent'),
        headers: headers,
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['success'] == true) {
        return Deal.fromJson(data['data']['deal']);
      } else {
        throw Exception(data['message'] ?? 'Failed to confirm payment sent');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: $e');
    }
  }

  // Confirm payment received (receiver's side)
  Future<Deal> confirmPaymentReceived(String dealId) async {
    final headers = await _getHeaders();
    
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/deals/$dealId/confirm-payment-received'),
        headers: headers,
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['success'] == true) {
        return Deal.fromJson(data['data']['deal']);
      } else {
        throw Exception(data['message'] ?? 'Failed to confirm payment received');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: $e');
    }
  }
}
