import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aloo_sbji_mandi/core/constants/api_constant.dart';

class TraderRequestService {
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

  // Get all open trader requests (for farmers to see)
  Future<Map<String, dynamic>> getAllRequests({int limit = 20, int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trader-requests?limit=$limit&page=$page'),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get single request
  Future<Map<String, dynamic>> getRequestById(String requestId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trader-requests/$requestId'),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get my requests (for traders)
  Future<Map<String, dynamic>> getMyRequests() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/trader-requests/user/my'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Create a new trader request
  Future<Map<String, dynamic>> createRequest({
    required String potatoVariety,
    required int quantity,
    required int maxPricePerQuintal,
    String? potatoType,
    String? size,
    String? qualityGrade,
    String? description,
    Map<String, String>? deliveryLocation,
    Map<String, dynamic>? captureLocation,
    DateTime? requiredByDate,
    String? targetFarmerId,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = {
        'potatoVariety': potatoVariety,
        'quantity': quantity,
        'maxPricePerQuintal': maxPricePerQuintal,
        if (potatoType != null) 'potatoType': potatoType,
        if (size != null) 'size': size,
        if (qualityGrade != null) 'qualityGrade': qualityGrade,
        if (description != null) 'description': description,
        if (deliveryLocation != null) 'deliveryLocation': deliveryLocation,
        if (captureLocation != null) 'captureLocation': captureLocation,
        if (requiredByDate != null) 'requiredByDate': requiredByDate.toIso8601String(),
        if (targetFarmerId != null) 'targetFarmerId': targetFarmerId,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/trader-requests/create'),
        headers: headers,
        body: json.encode(body),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'data': data['data'], 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to create request'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Farmer responds to a request
  Future<Map<String, dynamic>> respondToRequest({
    required String requestId,
    required String message,
    required int offeredPrice,
    int? offeredQuantity,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = {
        'message': message,
        'offeredPrice': offeredPrice,
        if (offeredQuantity != null) 'offeredQuantity': offeredQuantity,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/trader-requests/$requestId/respond'),
        headers: headers,
        body: json.encode(body),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data'], 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to respond'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Trader accepts/rejects a farmer's response
  Future<Map<String, dynamic>> updateResponseStatus({
    required String requestId,
    required String responseId,
    required String status, // 'accepted' or 'rejected'
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/trader-requests/$requestId/response/$responseId'),
        headers: headers,
        body: json.encode({'status': status}),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data'], 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Update request
  Future<Map<String, dynamic>> updateRequest({
    required String requestId,
    String? potatoVariety,
    String? potatoType,
    int? quantity,
    int? maxPricePerQuintal,
    String? size,
    String? qualityGrade,
    String? description,
    Map<String, String>? deliveryLocation,
    Map<String, dynamic>? captureLocation,
    String? status,
    bool? isActive,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{};
      if (potatoVariety != null) body['potatoVariety'] = potatoVariety;
      if (potatoType != null) body['potatoType'] = potatoType;
      if (quantity != null) body['quantity'] = quantity;
      if (maxPricePerQuintal != null) body['maxPricePerQuintal'] = maxPricePerQuintal;
      if (size != null) body['size'] = size;
      if (qualityGrade != null) body['qualityGrade'] = qualityGrade;
      if (description != null) body['description'] = description;
      if (deliveryLocation != null) body['deliveryLocation'] = deliveryLocation;
      if (captureLocation != null) body['captureLocation'] = captureLocation;
      if (status != null) body['status'] = status;
      if (isActive != null) body['isActive'] = isActive;

      final response = await http.patch(
        Uri.parse('$baseUrl/trader-requests/$requestId'),
        headers: headers,
        body: json.encode(body),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Cancel/Delete request
  Future<Map<String, dynamic>> cancelRequest(String requestId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/trader-requests/$requestId'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get requests where farmer has responded (My Offers for farmers)
  Future<Map<String, dynamic>> getMyResponses() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/trader-requests/farmer/my-responses'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Farmer withdraws their response from a request
  Future<Map<String, dynamic>> withdrawMyResponse(String requestId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/trader-requests/$requestId/my-response'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
}
