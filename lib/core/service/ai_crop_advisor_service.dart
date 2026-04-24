import 'dart:convert';
import 'package:aloo_sbji_mandi/core/constants/api_constant.dart';
import 'package:aloo_sbji_mandi/core/service/auth_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// AI Crop Advisor Service for Farmers
/// Provides intelligent recommendations from backend APIs
class AICropAdvisorService {
  static String get baseUrl => '${ApiConstants.baseUrl}/api/v1';

  /// Fetch Crop Advisor data with caching (once a day per language after 5 AM)
  static Future<dynamic> fetchCropAdvisorData({
    required String endpoint, // e.g., 'today', 'market-ai', 'seeds', 'disease'
    required String lang,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'ai_crop_${endpoint}_$lang';
    final dateKey = 'ai_crop_date_${endpoint}_$lang';

    final now = DateTime.now();
    // 5 AM today boundary
    final today5AM = DateTime(now.year, now.month, now.day, 5, 0);
    // If it's before 5 AM today, the boundary is yesterday 5 AM
    final validFrom = now.isBefore(today5AM)
        ? today5AM.subtract(const Duration(days: 1))
        : today5AM;

    final cachedDateStr = prefs.getString(dateKey);
    if (cachedDateStr != null) {
      final cachedDate = DateTime.tryParse(cachedDateStr);
      if (cachedDate != null && cachedDate.isAfter(validFrom)) {
        final cachedData = prefs.getString(cacheKey);
        if (cachedData != null) {
          debugPrint(
            '[AICropAdvisorService] Using cache for $endpoint ($lang)',
          );
          return json.decode(cachedData);
        }
      }
    }

    // Fetch from API
    try {
      final token = await AuthService().getAccessToken();
      final url = '$baseUrl/crop-advisor/$endpoint?lang=$lang';
      debugPrint('[AICropAdvisorService] GET $url');
      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          // Save to cache
          await prefs.setString(cacheKey, json.encode(jsonResponse['data']));
          await prefs.setString(dateKey, now.toIso8601String());
          return jsonResponse['data'];
        }
      }
      debugPrint(
        '[AICropAdvisorService] Error fetching $endpoint: ${response.statusCode} - ${response.body}',
      );
      throw Exception('Failed to fetch data');
    } catch (e) {
      debugPrint('[AICropAdvisorService] Exception: $e');
      // fallback to cache if available even if expired, otherwise throw
      final cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        debugPrint(
          '[AICropAdvisorService] Falling back to expired cache for $endpoint ($lang)',
        );
        return json.decode(cachedData);
      }
      rethrow;
    }
  }

  /// Calculate estimated profit
  static Map<String, dynamic> calculateProfit({
    required double landAcres,
    required double seedCostPerKg,
    required double expectedYieldPerAcre,
    required double expectedPricePerKg,
    bool isHindi = false,
  }) {
    // Estimated costs per acre
    final seedCost = landAcres * 800 * seedCostPerKg; // 800 kg seed per acre
    final fertilizerCost = landAcres * 8000;
    final laborCost = landAcres * 15000;
    final irrigationCost = landAcres * 5000;
    final pesticideCost = landAcres * 3000;
    final otherCost = landAcres * 2000;

    final totalCost =
        seedCost +
        fertilizerCost +
        laborCost +
        irrigationCost +
        pesticideCost +
        otherCost;
    final totalYield = landAcres * expectedYieldPerAcre;
    final totalRevenue = totalYield * expectedPricePerKg;
    final profit = totalRevenue - totalCost;
    final profitPerAcre = profit / landAcres;

    return {
      'totalCost': totalCost,
      'totalRevenue': totalRevenue,
      'profit': profit,
      'profitPerAcre': profitPerAcre,
      'totalYield': totalYield,
      'breakdown': {
        tr('cost_seeds'): seedCost,
        tr('cost_fertilizer'): fertilizerCost,
        tr('cost_labor'): laborCost,
        tr('cost_irrigation'): irrigationCost,
        tr('cost_pesticides'): pesticideCost,
        tr('cost_others'): otherCost,
      },
    };
  }
}
