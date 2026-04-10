import 'dart:math';

import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';

/// Simple Farmer Chatbot Service
/// Provides helpful answers in simple, easy-to-understand language
class FarmerChatbotService {
  static final Random _random = Random();

  /// Get chatbot response for farmer query
  static ChatResponse getResponse(String query, {bool isHindi = false}) {
    final lowerQuery = query.toLowerCase().trim();

    // Check for greetings
    if (_matchesAny(lowerQuery, [
      'hello',
      'hi',
      'hey',
      'namaste',
      'नमस्ते',
      'हेलो',
      'हाय',
    ])) {
      return _getGreetingResponse(isHindi);
    }

    // Check for potato selling questions
    if (_matchesAny(lowerQuery, [
      'sell',
      'bechna',
      'bechein',
      'बेचना',
      'बेचें',
      'how to sell',
      'kaise beche',
    ])) {
      return _getSellPotatoResponse(isHindi);
    }

    // Check for price questions
    if (_matchesAny(lowerQuery, [
      'price',
      'bhav',
      'rate',
      'daam',
      'भाव',
      'दाम',
      'रेट',
      'कीमत',
      'kitna',
      'कितना',
    ])) {
      return _getPriceResponse(isHindi);
    }

    // Check for cold storage questions
    if (_matchesAny(lowerQuery, [
      'cold storage',
      'storage',
      'store',
      'रखना',
      'भंडार',
      'कोल्ड',
      'स्टोरेज',
      'godown',
    ])) {
      return _getColdStorageResponse(isHindi);
    }

    // Check for seed questions
    if (_matchesAny(lowerQuery, [
      'seed',
      'beej',
      'बीज',
      'variety',
      'किस्म',
      'which potato',
      'konsa',
    ])) {
      return _getSeedResponse(isHindi);
    }

    // Check for disease/pest questions
    if (_matchesAny(lowerQuery, [
      'disease',
      'bimari',
      'rog',
      'रोग',
      'बीमारी',
      'kida',
      'कीड़ा',
      'pest',
      'jhulsa',
      'झुलसा',
    ])) {
      return _getDiseaseResponse(isHindi);
    }

    // Check for fertilizer/khad questions
    if (_matchesAny(lowerQuery, [
      'fertilizer',
      'khad',
      'खाद',
      'urea',
      'dap',
      'potash',
      'पोटाश',
      'यूरिया',
    ])) {
      return _getFertilizerResponse(isHindi);
    }

    // Check for irrigation/water questions
    if (_matchesAny(lowerQuery, [
      'water',
      'pani',
      'पानी',
      'irrigation',
      'sinchai',
      'सिंचाई',
      'कितना पानी',
    ])) {
      return _getIrrigationResponse(isHindi);
    }

    // Check for sowing/planting questions
    if (_matchesAny(lowerQuery, [
      'sow',
      'plant',
      'bona',
      'बोना',
      'lagana',
      'लगाना',
      'kab',
      'कब',
      'when',
      'time',
    ])) {
      return _getSowingResponse(isHindi);
    }

    // Check for harvest questions
    if (_matchesAny(lowerQuery, [
      'harvest',
      'katai',
      'कटाई',
      'nikalna',
      'निकालना',
      'khudai',
      'खुदाई',
    ])) {
      return _getHarvestResponse(isHindi);
    }

    // Check for loan/money questions
    if (_matchesAny(lowerQuery, [
      'loan',
      'karz',
      'कर्ज',
      'ऋण',
      'paisa',
      'पैसा',
      'money',
      'bank',
    ])) {
      return _getLoanResponse(isHindi);
    }

    // Check for weather questions
    if (_matchesAny(lowerQuery, [
      'weather',
      'mausam',
      'मौसम',
      'rain',
      'barish',
      'बारिश',
      'frost',
      'pala',
      'पाला',
    ])) {
      return _getWeatherResponse(isHindi);
    }

    // Check for transport questions
    if (_matchesAny(lowerQuery, [
      'transport',
      'truck',
      'ट्रक',
      'गाड़ी',
      'gaadi',
      'le jana',
      'ले जाना',
    ])) {
      return _getTransportResponse(isHindi);
    }

    // Check for trader/buyer questions
    if (_matchesAny(lowerQuery, [
      'trader',
      'vyapari',
      'व्यापारी',
      'buyer',
      'khariddar',
      'खरीददार',
      'aadti',
      'आढ़ती',
    ])) {
      return _getTraderResponse(isHindi);
    }

    // Check for app usage questions
    if (_matchesAny(lowerQuery, [
      'app',
      'use',
      'kaise',
      'कैसे',
      'help',
      'मदद',
      'samajh',
      'समझ',
    ])) {
      return _getAppHelpResponse(isHindi);
    }

    // Check for thank you
    if (_matchesAny(lowerQuery, [
      'thank',
      'dhanyawad',
      'धन्यवाद',
      'shukriya',
      'शुक्रिया',
    ])) {
      return _getThankYouResponse(isHindi);
    }

    // Default response
    return _getDefaultResponse(isHindi);
  }

  static bool _matchesAny(String query, List<String> keywords) {
    return keywords.any((keyword) => query.contains(keyword));
  }

  // ==================== RESPONSE GENERATORS ====================

  static ChatResponse _getGreetingResponse(bool isHindi) {
    return ChatResponse(
      message: tr('chatbot_greeting_response'),
      suggestions: [
        tr('chatbot_qr_how_to_sell'),
        tr('chatbot_qr_tell_price'),
        tr('chatbot_qr_which_seed'),
      ],
    );
  }

  static ChatResponse _getSellPotatoResponse(bool isHindi) {
    return ChatResponse(
      message: tr('chatbot_sell_response'),
      suggestions: [
        tr('chatbot_qr_what_price_get'),
        tr('chatbot_qr_which_variety_good'),
        tr('chatbot_qr_how_find_trader'),
      ],
    );
  }

  static ChatResponse _getPriceResponse(bool isHindi) {
    final prices = [14, 15, 16, 17, 18];
    final todayPrice = prices[_random.nextInt(prices.length)];

    return ChatResponse(
      message: trArgs('chatbot_price_response', {
        'minPrice': todayPrice.toString(),
        'maxPrice': (todayPrice + 2).toString(),
      }),
      suggestions: [
        tr('chatbot_qr_sell_or_wait'),
        tr('chatbot_qr_which_mandi_best'),
        tr('chatbot_qr_when_price_rise'),
      ],
    );
  }

  static ChatResponse _getColdStorageResponse(bool isHindi) {
    return ChatResponse(
      message: tr('chatbot_cold_storage_response'),
      suggestions: [
        tr('chatbot_qr_what_rent'),
        tr('chatbot_qr_how_long_store'),
        tr('chatbot_qr_nearest_storage'),
      ],
    );
  }

  static ChatResponse _getSeedResponse(bool isHindi) {
    return ChatResponse(
      message: tr('chatbot_seed_response'),
      suggestions: [
        tr('chatbot_qr_where_get_seed'),
        tr('chatbot_qr_how_much_seed'),
        tr('chatbot_qr_when_to_sow'),
      ],
    );
  }

  static ChatResponse _getDiseaseResponse(bool isHindi) {
    return ChatResponse(
      message: tr('chatbot_disease_response'),
      suggestions: [
        tr('chatbot_qr_which_medicine'),
        tr('chatbot_qr_how_many_days_effect'),
        tr('chatbot_qr_where_get_medicine'),
      ],
    );
  }

  static ChatResponse _getFertilizerResponse(bool isHindi) {
    return ChatResponse(
      message: tr('chatbot_fertilizer_response'),
      suggestions: [
        tr('chatbot_qr_where_get_fertilizer'),
        tr('chatbot_qr_how_much_cost'),
        tr('chatbot_qr_how_make_organic'),
      ],
    );
  }

  static ChatResponse _getIrrigationResponse(bool isHindi) {
    return ChatResponse(
      message: tr('chatbot_irrigation_response'),
      suggestions: [
        tr('chatbot_qr_save_from_frost'),
        tr('chatbot_qr_install_drip'),
        tr('chatbot_qr_less_water'),
      ],
    );
  }

  static ChatResponse _getSowingResponse(bool isHindi) {
    return ChatResponse(
      message: tr('chatbot_sowing_response'),
      suggestions: [
        tr('chatbot_qr_how_much_seed_needed'),
        tr('chatbot_qr_what_depth'),
        tr('chatbot_qr_sown_late'),
      ],
    );
  }

  static ChatResponse _getHarvestResponse(bool isHindi) {
    return ChatResponse(
      message: tr('chatbot_harvest_response'),
      suggestions: [
        tr('chatbot_qr_how_much_yield'),
        tr('chatbot_qr_how_to_store'),
        tr('chatbot_qr_sell_or_keep'),
      ],
    );
  }

  static ChatResponse _getLoanResponse(bool isHindi) {
    return ChatResponse(
      message: tr('chatbot_loan_response'),
      suggestions: [
        tr('chatbot_qr_how_much_loan'),
        tr('chatbot_qr_what_interest'),
        tr('chatbot_qr_where_apply'),
      ],
    );
  }

  static ChatResponse _getWeatherResponse(bool isHindi) {
    return ChatResponse(
      message: tr('chatbot_weather_response'),
      suggestions: [
        tr('chatbot_qr_when_frost'),
        tr('chatbot_qr_what_do_rain'),
        tr('chatbot_qr_save_in_heat'),
      ],
    );
  }

  static ChatResponse _getTransportResponse(bool isHindi) {
    return ChatResponse(
      message: tr('chatbot_transport_response'),
      suggestions: [
        tr('chatbot_qr_how_much_fare'),
        tr('chatbot_qr_when_get_vehicle'),
        tr('chatbot_qr_goods_damaged'),
      ],
    );
  }

  static ChatResponse _getTraderResponse(bool isHindi) {
    return ChatResponse(
      message: tr('chatbot_trader_response'),
      suggestions: [
        tr('chatbot_qr_find_reliable'),
        tr('chatbot_qr_how_get_payment'),
        tr('chatbot_qr_if_cheated'),
      ],
    );
  }

  static ChatResponse _getAppHelpResponse(bool isHindi) {
    return ChatResponse(
      message: tr('chatbot_app_help_response'),
      suggestions: [
        tr('chatbot_qr_change_profile'),
        tr('chatbot_qr_change_language'),
        tr('chatbot_qr_turn_off_notif'),
      ],
    );
  }

  static ChatResponse _getThankYouResponse(bool isHindi) {
    return ChatResponse(
      message: tr('chatbot_thankyou_response'),
      suggestions: [
        tr('chatbot_qr_ask_more'),
        tr('chatbot_qr_go_home'),
        tr('chatbot_qr_call_us'),
      ],
    );
  }

  static ChatResponse _getDefaultResponse(bool isHindi) {
    return ChatResponse(
      message: tr('chatbot_default_response'),
      suggestions: [
        tr('chatbot_qr_how_to_sell'),
        tr('chatbot_qr_tell_price'),
        tr('chatbot_qr_need_help'),
      ],
    );
  }
}

/// Chat Response Model
class ChatResponse {
  final String message;
  final List<String> suggestions;

  ChatResponse({required this.message, this.suggestions = const []});
}

/// Chat Message Model
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.isUser, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();
}
