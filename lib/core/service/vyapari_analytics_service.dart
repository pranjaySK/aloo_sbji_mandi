import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aloo_sbji_mandi/core/constants/api_constant.dart';

class VyapariAnalyticsService {
  static String get _baseUrl => '${ApiConstants.baseUrl}/api/v1';

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Fetch all 6 AI insights for the logged-in Vyapari
  static Future<Map<String, dynamic>> getVyapariInsights() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('$_baseUrl/analytics/vyapari-insights'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to load analytics',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
