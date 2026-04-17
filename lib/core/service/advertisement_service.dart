import 'dart:convert';

import 'package:aloo_sbji_mandi/core/constants/api_constant.dart';
import 'package:aloo_sbji_mandi/core/utils/app_logger.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AdvertisementService {
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

  Map<String, dynamic> _safeJsonDecode(String body) {
    return json.decode(body) as Map<String, dynamic>;
  }

  void _logRequest(
    String method,
    String url, {
    Map<String, dynamic>? headers,
    Object? body,
  }) {
    AppLogger.request(
      method,
      url,
      headers: headers,
      body: body,
      tag: 'AD_API_REQUEST',
    );
  }

  void _logResponse(
    String method,
    String url,
    http.Response response, {
    Stopwatch? stopwatch,
    Object? data,
  }) {
    AppLogger.response(
      method,
      url,
      statusCode: response.statusCode,
      duration: stopwatch?.elapsed,
      data: data ?? response.body,
      tag: 'AD_API_RESPONSE',
    );
  }

  void _logError(
    String method,
    String url, {
    Object? error,
    StackTrace? stackTrace,
    Object? data,
  }) {
    AppLogger.networkError(
      method,
      url,
      error: error,
      stackTrace: stackTrace,
      data: data,
      tag: 'AD_API_ERROR',
    );
  }

  // Get ad slide pricing (public)
  Future<Map<String, dynamic>> getAdPricing() async {
    final url = '$baseUrl/advertisements/pricing';
    final stopwatch = Stopwatch()..start();
    try {
      _logRequest('GET', url);
      final response = await http.get(Uri.parse(url));
      final data = _safeJsonDecode(response.body);
      _logResponse('GET', url, response, stopwatch: stopwatch, data: data);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch pricing',
        };
      }
    } catch (e, stackTrace) {
      _logError('GET', url, error: e, stackTrace: stackTrace);
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Admin: Update ad slide pricing
  Future<Map<String, dynamic>> updateAdPricing({
    List<Map<String, dynamic>>? slidePricing,
    List<Map<String, dynamic>>? durationOptions,
  }) async {
    final url = '$baseUrl/advertisements/admin/pricing';
    final stopwatch = Stopwatch()..start();
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{};
      if (slidePricing != null) body['slidePricing'] = slidePricing;
      if (durationOptions != null) body['durationOptions'] = durationOptions;
      _logRequest('PUT', url, headers: headers, body: body);

      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: json.encode(body),
      );
      final data = _safeJsonDecode(response.body);
      _logResponse('PUT', url, response, stopwatch: stopwatch, data: data);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update pricing',
        };
      }
    } catch (e, stackTrace) {
      _logError(
        'PUT',
        url,
        error: e,
        stackTrace: stackTrace,
        data: {
          'slidePricing': slidePricing,
          'durationOptions': durationOptions,
        },
      );
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Get active advertisements for slider (public)
  Future<Map<String, dynamic>> getActiveAdvertisements() async {
    final url = '$baseUrl/advertisements/active';
    final stopwatch = Stopwatch()..start();
    try {
      _logRequest('GET', url);
      final response = await http.get(Uri.parse(url));
      final data = _safeJsonDecode(response.body);
      _logResponse('GET', url, response, stopwatch: stopwatch, data: data);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch ads',
        };
      }
    } catch (e, stackTrace) {
      _logError('GET', url, error: e, stackTrace: stackTrace);
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Create advertisement request
  Future<Map<String, dynamic>> createAdvertisementRequest({
    required String title,
    String? description,
    String? imageUrl,
    List<String>? images,
    List<String>? redirectUrls,
    String? redirectUrl,
    String? advertiserType,
    String? coldStorageId,
    int durationDays = 30,
    int? slideNumber,
    String? contactPhone,
    String? contactEmail,
    DateTime? startDate,
  }) async {
    final url = '$baseUrl/advertisements/request';
    final stopwatch = Stopwatch()..start();
    try {
      final headers = await _getHeaders();
      final body = {
        'title': title,
        'description': description,
        'redirectUrl': redirectUrl,
        'redirectUrls': redirectUrls ?? [],
        'advertiserType': advertiserType ?? 'cold-storage',
        'coldStorageId': coldStorageId,
        'durationDays': durationDays,
        if (slideNumber != null) 'slideNumber': slideNumber,
        'contactPhone': contactPhone,
        'contactEmail': contactEmail,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
      };

      // Send images array if available, otherwise fallback to imageUrl
      if (images != null && images.isNotEmpty) {
        body['images'] = images;
      } else if (imageUrl != null && imageUrl.isNotEmpty) {
        body['imageUrl'] = imageUrl;
      }
      _logRequest('POST', url, headers: headers, body: body);

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(body),
      );
      final data = _safeJsonDecode(response.body);
      _logResponse('POST', url, response, stopwatch: stopwatch, data: data);

      if (response.statusCode == 201) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to submit request',
        };
      }
    } catch (e, stackTrace) {
      _logError('POST', url, error: e, stackTrace: stackTrace);
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get my advertisements
  Future<Map<String, dynamic>> getMyAdvertisements() async {
    final url = '$baseUrl/advertisements/my';
    final stopwatch = Stopwatch()..start();
    try {
      final headers = await _getHeaders();
      _logRequest('GET', url, headers: headers);
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      final data = _safeJsonDecode(response.body);
      _logResponse('GET', url, response, stopwatch: stopwatch, data: data);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch ads',
        };
      }
    } catch (e, stackTrace) {
      _logError('GET', url, error: e, stackTrace: stackTrace);
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Track ad view
  Future<void> trackAdView(String adId) async {
    final url = '$baseUrl/advertisements/$adId/view';
    try {
      _logRequest('POST', url, body: {'adId': adId});
      final response = await http.post(Uri.parse(url));
      _logResponse('POST', url, response);
    } catch (e, stackTrace) {
      _logError('POST', url, error: e, stackTrace: stackTrace);
      // Silently fail
    }
  }

  // Track ad click
  Future<void> trackAdClick(String adId) async {
    final url = '$baseUrl/advertisements/$adId/click';
    try {
      _logRequest('POST', url, body: {'adId': adId});
      final response = await http.post(Uri.parse(url));
      _logResponse('POST', url, response);
    } catch (e, stackTrace) {
      _logError('POST', url, error: e, stackTrace: stackTrace);
      // Silently fail
    }
  }

  // ============ USER PAYMENT FUNCTIONS ============

  // Create Razorpay order for an approved advertisement
  Future<Map<String, dynamic>> createAdPaymentOrder(
      String advertisementId) async {
    final url = '$baseUrl/advertisements/pay/create-order';
    final stopwatch = Stopwatch()..start();
    try {
      final headers = await _getHeaders();
      final body = {'advertisementId': advertisementId};
      _logRequest('POST', url, headers: headers, body: body);
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(body),
      );

      // Guard against non-JSON responses (HTML error pages, etc.)
      final respBody = response.body.trim();
      if (respBody.isEmpty ||
          respBody.startsWith('<') ||
          respBody.startsWith('<!')) {
        _logResponse('POST', url, response, stopwatch: stopwatch, data: respBody);
        return {
          'success': false,
          'message':
              'Server returned an unexpected response (HTTP ${response.statusCode}). '
              'The payment API may not be deployed yet.',
        };
      }

      final data = _safeJsonDecode(respBody);
      _logResponse('POST', url, response, stopwatch: stopwatch, data: data);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to create payment order',
        };
      }
    } catch (e, stackTrace) {
      _logError(
        'POST',
        url,
        error: e,
        stackTrace: stackTrace,
        data: {'advertisementId': advertisementId},
      );
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Verify Razorpay payment for advertisement
  Future<Map<String, dynamic>> verifyAdPayment({
    required String orderId,
    required String paymentId,
    required String signature,
    required String advertisementId,
  }) async {
    final url = '$baseUrl/advertisements/pay/verify';
    final stopwatch = Stopwatch()..start();
    try {
      final headers = await _getHeaders();
      final body = {
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
        'advertisementId': advertisementId,
      };
      _logRequest('POST', url, headers: headers, body: body);
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(body),
      );

      // Guard against non-JSON responses
      final respBody = response.body.trim();
      if (respBody.isEmpty ||
          respBody.startsWith('<') ||
          respBody.startsWith('<!')) {
        _logResponse('POST', url, response, stopwatch: stopwatch, data: respBody);
        return {
          'success': false,
          'message':
              'Server returned an unexpected response (HTTP ${response.statusCode}). '
              'Payment verification API may not be deployed yet.',
        };
      }

      final data = _safeJsonDecode(respBody);
      _logResponse('POST', url, response, stopwatch: stopwatch, data: data);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Payment verification failed',
        };
      }
    } catch (e, stackTrace) {
      _logError(
        'POST',
        url,
        error: e,
        stackTrace: stackTrace,
        data: {'advertisementId': advertisementId},
      );
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ============ ADMIN FUNCTIONS ============

  // Get all advertisements (Admin)
  Future<Map<String, dynamic>> getAllAdvertisements({String? status}) async {
    try {
      final headers = await _getHeaders();
      String url = '$baseUrl/advertisements/admin/all';
      if (status != null) url += '?status=$status';

      final response = await http.get(Uri.parse(url), headers: headers);
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch ads',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get pending advertisements (Admin)
  Future<Map<String, dynamic>> getPendingAdvertisements() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/advertisements/admin/pending'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch ads',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Approve advertisement (Admin)
  Future<Map<String, dynamic>> approveAdvertisement(
    String id, {
    String? adminNotes,
    double? price,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/advertisements/admin/$id/approve'),
        headers: headers,
        body: json.encode({'adminNotes': ?adminNotes, 'price': ?price}),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to approve',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Reject advertisement (Admin)
  Future<Map<String, dynamic>> rejectAdvertisement(
    String id, {
    String? reason,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/advertisements/admin/$id/reject'),
        headers: headers,
        body: json.encode({'rejectionReason': reason ?? 'Rejected by admin'}),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to reject',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Confirm payment (Admin)
  Future<Map<String, dynamic>> confirmPayment(
    String id, {
    String? paymentId,
    String? paymentMethod,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/advertisements/admin/$id/confirm-payment'),
        headers: headers,
        body: json.encode({
          'paymentId': ?paymentId,
          'paymentMethod': ?paymentMethod,
        }),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to confirm payment',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get dashboard stats (Admin)
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/advertisements/admin/dashboard'),
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

  // Get all users (Admin)
  Future<Map<String, dynamic>> getAllUsers({String? role}) async {
    try {
      final headers = await _getHeaders();
      String url = '$baseUrl/advertisements/admin/users';
      if (role != null) url += '?role=$role';

      final response = await http.get(Uri.parse(url), headers: headers);
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch users',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Admin: Create and activate banner directly
  Future<Map<String, dynamic>> adminCreateBanner({
    required String title,
    List<String>? images,
    String? imageUrl,
    String? description,
    int durationDays = 30,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{
        'title': title,
        'description': description,
        'durationDays': durationDays,
      };

      // Send images array (base64) if available, otherwise fallback to imageUrl
      if (images != null && images.isNotEmpty) {
        body['images'] = images;
      } else if (imageUrl != null && imageUrl.isNotEmpty) {
        body['imageUrl'] = imageUrl;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/advertisements/admin/create'),
        headers: headers,
        body: json.encode(body),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to create banner',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Admin: Edit advertisement
  Future<Map<String, dynamic>> adminEditAdvertisement(
    String id, {
    String? title,
    String? description,
    List<String>? images,
    String? imageUrl,
    int? durationDays,
    double? price,
    String? status,
    String? redirectUrl,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      if (images != null) body['images'] = images;
      if (imageUrl != null) body['imageUrl'] = imageUrl;
      if (durationDays != null) body['durationDays'] = durationDays;
      if (price != null) body['price'] = price;
      if (status != null) body['status'] = status;
      if (redirectUrl != null) body['redirectUrl'] = redirectUrl;

      final response = await http.put(
        Uri.parse('$baseUrl/advertisements/admin/$id/edit'),
        headers: headers,
        body: json.encode(body),
      );

      // Guard against non-JSON responses (e.g. HTML 404 page)
      final respBody = response.body.trim();
      if (respBody.startsWith('<') || respBody.startsWith('<!')) {
        return {
          'success': false,
          'message':
              'Server returned an unexpected response (HTTP ${response.statusCode}). '
              'The edit API may not be deployed yet.',
        };
      }

      final data = json.decode(respBody);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update ad',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Admin: Delete advertisement
  Future<Map<String, dynamic>> adminDeleteAdvertisement(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/advertisements/admin/$id'),
        headers: headers,
      );

      // Guard against non-JSON responses (e.g. HTML 404 page)
      final body = response.body.trim();
      if (body.startsWith('<') || body.startsWith('<!')) {
        return {
          'success': false,
          'message':
              'Server returned an unexpected response (HTTP ${response.statusCode}). '
              'The delete API may not be deployed yet.',
        };
      }

      final data = json.decode(body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'Deleted'};
      } else {
        return {
          'success': false,
          'message':
              data['message'] ?? 'Failed to delete (${response.statusCode})',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
}
