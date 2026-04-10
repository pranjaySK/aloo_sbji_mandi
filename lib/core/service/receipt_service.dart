import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aloo_sbji_mandi/core/constants/api_constant.dart';
import '../models/receipt_model.dart';

class ReceiptService {
  static const String baseUrl = '${ApiConstants.baseUrl}/api/v1';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Generate receipt for a deal
  Future<Map<String, dynamic>> generateReceipt(String dealId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/receipts/generate'),
        headers: headers,
        body: jsonEncode({'dealId': dealId}),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'receipt': data['receipt'] != null ? Receipt.fromJson(data['receipt']) : null,
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to generate receipt',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  // Get receipt by deal ID
  Future<Map<String, dynamic>> getReceiptByDealId(String dealId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/receipts/deal/$dealId'),
        headers: headers,
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'receipt': data['receipt'] != null ? Receipt.fromJson(data['receipt']) : null,
          'userRole': data['userRole'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Receipt not found',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  // Get receipt by receipt number
  Future<Map<String, dynamic>> getReceiptByNumber(String receiptNumber) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/receipts/number/$receiptNumber'),
        headers: headers,
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'receipt': data['receipt'] != null ? Receipt.fromJson(data['receipt']) : null,
          'userRole': data['userRole'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Receipt not found',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  // Get all receipts for current user
  Future<Map<String, dynamic>> getMyReceipts({int page = 1, int limit = 20}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/receipts/my-receipts?page=$page&limit=$limit'),
        headers: headers,
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        final List<Receipt> receipts = (data['receipts'] as List)
            .map((r) => Receipt.fromJson(r))
            .toList();
        return {
          'success': true,
          'receipts': receipts,
          'pagination': data['pagination'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch receipts',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  // Mark receipt as downloaded
  Future<Map<String, dynamic>> markAsDownloaded(String receiptId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/receipts/downloaded/$receiptId'),
        headers: headers,
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update receipt',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }
}
