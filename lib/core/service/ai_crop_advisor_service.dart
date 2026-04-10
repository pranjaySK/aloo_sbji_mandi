import 'dart:math';

import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';

/// AI Crop Advisor Service for Farmers
/// Provides intelligent recommendations for potato farming
class AICropAdvisorService {
  static final Random _random = Random();

  /// Get current season based on month
  static String getCurrentSeason() {
    final month = DateTime.now().month;
    if (month >= 3 && month <= 5) return 'summer';
    if (month >= 6 && month <= 9) return 'monsoon';
    if (month >= 10 && month <= 11) return 'autumn';
    return 'winter'; // Dec, Jan, Feb
  }

  /// Get season name in Hindi/English
  static String getSeasonName({bool isHindi = false}) {
    final season = getCurrentSeason();
    final seasonNames = {
      'summer': tr('season_summer'),
      'monsoon': tr('season_monsoon'),
      'autumn': tr('season_autumn'),
      'winter': tr('season_winter'),
    };
    return seasonNames[season] ?? season;
  }

  /// Get AI-powered crop recommendations based on current conditions
  static Map<String, dynamic> getCropRecommendations({bool isHindi = false}) {
    final season = getCurrentSeason();
    final month = DateTime.now().month;

    // Season-specific recommendations
    Map<String, dynamic> recommendations = {};

    if (season == 'winter') {
      recommendations = {
        'season': tr('crop_winter_season'),
        'status': tr('crop_ideal_sowing_time'),
        'statusColor': 'green',
        'mainAdvice': tr('crop_winter_main_advice'),
        'activities': [
          {
            'title': tr('crop_activity_sowing'),
            'description': tr('crop_sowing_desc'),
            'icon': 'agriculture',
            'priority': 'high',
          },
          {
            'title': tr('crop_activity_irrigation'),
            'description': tr('crop_winter_irrigation_desc'),
            'icon': 'water_drop',
            'priority': 'medium',
          },
          {
            'title': tr('crop_activity_fertilization'),
            'description': tr('crop_fertilization_desc'),
            'icon': 'science',
            'priority': 'medium',
          },
        ],
      };
    } else if (season == 'spring' || month == 2 || month == 3) {
      recommendations = {
        'season': tr('crop_spring_season'),
        'status': tr('crop_dev_time'),
        'statusColor': 'blue',
        'mainAdvice': tr('crop_spring_main_advice'),
        'activities': [
          {
            'title': tr('crop_activity_earthing'),
            'description': tr('crop_earthing_desc'),
            'icon': 'landscape',
            'priority': 'high',
          },
          {
            'title': tr('crop_activity_pest_control'),
            'description': tr('crop_pest_control_desc'),
            'icon': 'bug_report',
            'priority': 'high',
          },
          {
            'title': tr('crop_activity_irrigation'),
            'description': tr('crop_spring_irrigation_desc'),
            'icon': 'water_drop',
            'priority': 'medium',
          },
        ],
      };
    } else if (season == 'summer') {
      recommendations = {
        'season': tr('crop_summer_season'),
        'status': tr('crop_harvest_storage_time'),
        'statusColor': 'orange',
        'mainAdvice': tr('crop_summer_main_advice'),
        'activities': [
          {
            'title': tr('crop_activity_harvesting'),
            'description': tr('crop_harvesting_desc'),
            'icon': 'agriculture',
            'priority': 'high',
          },
          {
            'title': tr('crop_activity_grading'),
            'description': tr('crop_grading_desc'),
            'icon': 'sort',
            'priority': 'medium',
          },
          {
            'title': tr('crop_activity_storage'),
            'description': tr('crop_storage_desc'),
            'icon': 'ac_unit',
            'priority': 'high',
          },
        ],
      };
    } else {
      recommendations = {
        'season': tr('crop_monsoon_autumn'),
        'status': tr('crop_field_prep_time'),
        'statusColor': 'teal',
        'mainAdvice': tr('crop_monsoon_main_advice'),
        'activities': [
          {
            'title': tr('crop_activity_field_prep'),
            'description': tr('crop_field_prep_desc'),
            'icon': 'terrain',
            'priority': 'high',
          },
          {
            'title': tr('crop_activity_soil_test'),
            'description': tr('crop_soil_test_desc'),
            'icon': 'science',
            'priority': 'medium',
          },
          {
            'title': tr('crop_activity_seed_selection'),
            'description': tr('crop_seed_selection_desc'),
            'icon': 'eco',
            'priority': 'high',
          },
        ],
      };
    }

    return recommendations;
  }

  /// Get best seed varieties with recommendations
  static List<Map<String, dynamic>> getSeedRecommendations({
    bool isHindi = false,
  }) {
    return [
      {
        'name': 'Kufri Pukhraj',
        'nameHindi': 'कुफरी पुखराज',
        'type': tr('seed_early_maturing'),
        'days': '70-80',
        'yield': '250-300',
        'features': tr('seed_pukhraj_features'),
        'bestFor': tr('seed_pukhraj_region'),
        'rating': 4.8,
        'recommended': true,
      },
      {
        'name': 'Kufri Jyoti',
        'nameHindi': 'कुफरी ज्योति',
        'type': tr('seed_medium_maturing'),
        'days': '90-100',
        'yield': '200-250',
        'features': tr('seed_jyoti_features'),
        'bestFor': tr('seed_jyoti_region'),
        'rating': 4.5,
        'recommended': true,
      },
      {
        'name': 'Kufri Bahar',
        'nameHindi': 'कुफरी बहार',
        'type': tr('seed_early_maturing'),
        'days': '75-85',
        'yield': '220-280',
        'features': tr('seed_bahar_features'),
        'bestFor': tr('seed_bahar_region'),
        'rating': 4.3,
        'recommended': false,
      },
      {
        'name': 'Kufri Chipsona',
        'nameHindi': 'कुफरी चिप्सोना',
        'type': tr('seed_processing_variety'),
        'days': '100-110',
        'yield': '200-230',
        'features': tr('seed_chipsona_features'),
        'bestFor': tr('seed_chipsona_region'),
        'rating': 4.6,
        'recommended': true,
      },
      {
        'name': 'Kufri Khyati',
        'nameHindi': 'कुफरी ख्याति',
        'type': tr('seed_high_yield'),
        'days': '85-95',
        'yield': '300-350',
        'features': tr('seed_khyati_features'),
        'bestFor': tr('seed_khyati_region'),
        'rating': 4.7,
        'recommended': true,
      },
    ];
  }

  /// Get disease identification and solutions
  static List<Map<String, dynamic>> getDiseaseGuide({bool isHindi = false}) {
    return [
      {
        'name': tr('disease_late_blight'),
        'symptoms': tr('disease_late_blight_symptoms'),
        'solution': tr('disease_late_blight_solution'),
        'prevention': tr('disease_late_blight_prevention'),
        'severity': 'high',
        'icon': 'warning',
      },
      {
        'name': tr('disease_early_blight'),
        'symptoms': tr('disease_early_blight_symptoms'),
        'solution': tr('disease_early_blight_solution'),
        'prevention': tr('disease_early_blight_prevention'),
        'severity': 'medium',
        'icon': 'report_problem',
      },
      {
        'name': tr('disease_aphids'),
        'symptoms': tr('disease_aphids_symptoms'),
        'solution': tr('disease_aphids_solution'),
        'prevention': tr('disease_aphids_prevention'),
        'severity': 'medium',
        'icon': 'bug_report',
      },
      {
        'name': tr('disease_black_scurf'),
        'symptoms': tr('disease_black_scurf_symptoms'),
        'solution': tr('disease_black_scurf_solution'),
        'prevention': tr('disease_black_scurf_prevention'),
        'severity': 'low',
        'icon': 'lens',
      },
    ];
  }

  /// Get market timing advice
  static Map<String, dynamic> getMarketAdvice({bool isHindi = false}) {
    final month = DateTime.now().month;
    String advice;
    String timing;
    String priceOutlook;

    if (month >= 2 && month <= 4) {
      advice = tr('advisor_market_feb_apr');
      timing = tr('advisor_timing_sell_or_store');
      priceOutlook = 'neutral';
    } else if (month >= 5 && month <= 8) {
      advice = tr('advisor_market_may_aug');
      timing = tr('advisor_timing_good_to_sell');
      priceOutlook = 'bullish';
    } else {
      advice = tr('advisor_market_default');
      timing = tr('advisor_timing_sell_seeds');
      priceOutlook = 'stable';
    }

    return {
      'advice': advice,
      'timing': timing,
      'priceOutlook': priceOutlook,
      'currentMonth': month,
    };
  }

  /// Get quick tips for the day
  static List<String> getDailyTips({bool isHindi = false}) {
    final allTips = isHindi
        ? [
            tr('tip_morning_irrigation'),
            tr('tip_certified_seeds'),
            tr('tip_soil_testing'),
            tr('tip_frost_irrigation'),
            tr('tip_weekly_disease_check'),
            tr('tip_cure_before_storage'),
            tr('tip_track_market_prices'),
            tr('tip_organic_manure'),
          ]
        : [
            tr('tip_morning_irrigation'),
            tr('tip_certified_seeds'),
            tr('tip_soil_testing'),
            tr('tip_frost_irrigation'),
            tr('tip_weekly_disease_check'),
            tr('tip_cure_before_storage'),
            tr('tip_track_market_prices'),
            tr('tip_organic_manure'),
          ];

    // Return 3 random tips
    allTips.shuffle(_random);
    return allTips.take(3).toList();
  }

  /// Get storage recommendations
  static Map<String, dynamic> getStorageAdvice({bool isHindi = false}) {
    return {
      'temperature': '2-4°C',
      'humidity': '85-90%',
      'tips': isHindi
          ? [
              tr('storage_tip_remove_damaged'),
              tr('storage_tip_keep_dark'),
              tr('storage_tip_ventilation'),
              tr('storage_tip_duration'),
            ]
          : [
              tr('storage_tip_remove_damaged'),
              tr('storage_tip_keep_dark'),
              tr('storage_tip_ventilation'),
              tr('storage_tip_duration'),
            ],
    };
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
