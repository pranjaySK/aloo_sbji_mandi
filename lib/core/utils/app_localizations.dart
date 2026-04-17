import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Full multi-language localization for the Aloo Market app.
/// Now using .arb files located in assets/l10n/ for better scalability.
class AppLocalizations extends ChangeNotifier {
  static final AppLocalizations _instance = AppLocalizations._internal();
  factory AppLocalizations() => _instance;
  static AppLocalizations get instance => _instance;
  AppLocalizations._internal();

  static String _currentLocale = 'hi';
  static Map<String, String> _localizedStrings = {};
  static Map<String, String> _fallbackStrings = {};

  static String get currentLocale => _currentLocale;
  static bool get isHindi => _currentLocale == 'hi';

  /// Initialize from saved preference — call once in main()
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_locale');
    if (saved != null) {
      _currentLocale = saved;
    } else {
      // First launch: detect device language, default to 'hi' if not supported
      final deviceLocale =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      _currentLocale = supportedLocales.contains(deviceLocale)
          ? deviceLocale
          : 'hi';
    }
    
    // Load current and fallback (English) translations
    await _load(_currentLocale);
    if (_currentLocale != 'en') {
      await _loadFallback();
    }
  }

  /// Load translations for a specific locale from assets
  static Future<void> _load(String locale) async {
    try {
      String jsonContent = await rootBundle.loadString('assets/l10n/app_$locale.arb');
      Map<String, dynamic> jsonMap = json.decode(jsonContent);
      _localizedStrings = jsonMap.map((key, value) {
        // Filter out keys starting with '@' (ARB metadata)
        return MapEntry(key, value.toString());
      })..removeWhere((key, value) => key.startsWith('@'));
    } catch (e) {
      debugPrint('Error loading locale $locale: $e');
      _localizedStrings = {};
    }
  }

  /// Load English as fallback for missing keys
  static Future<void> _loadFallback() async {
    try {
      String jsonContent = await rootBundle.loadString('assets/l10n/app_en.arb');
      Map<String, dynamic> jsonMap = json.decode(jsonContent);
      _fallbackStrings = jsonMap.map((key, value) {
        return MapEntry(key, value.toString());
      })..removeWhere((key, value) => key.startsWith('@'));
    } catch (e) {
      debugPrint('Error loading fallback locale: $e');
      _fallbackStrings = {};
    }
  }

  /// Change locale, persist, and notify so the entire app rebuilds
  static Future<void> setLocale(String locale) async {
    if (_currentLocale == locale) return;
    
    // Load the new language before switching
    await _load(locale);
    _currentLocale = locale;
    
    // Notify listeners IMMEDIATELY so the UI rebuilds synchronously
    _instance.notifyListeners();
    
    // Persist in the background
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_locale', locale);
  }

  /// Get translated text for current locale
  static String tr(String key) {
    // 1. Try current locale
    final localized = _localizedStrings[key];
    if (localized != null && localized.trim().isNotEmpty) {
      return localized;
    }

    // 2. Try English fallback
    final english = _fallbackStrings[key];
    if (english != null && english.trim().isNotEmpty) {
      return english;
    }

    // 3. Return key as final fallback
    return key;
  }

  /// Get translated text with argument substitution.
  static String trArgs(String key, Map<String, String> args) {
    var result = tr(key);
    args.forEach((k, v) {
      result = result.replaceAll('{$k}', v);
    });
    return result;
  }

  static String get currentLanguageName =>
      _languageNames[_currentLocale] ?? 'English';

  static const Map<String, String> _languageNames = {
    'en': 'English',
    'hi': 'हिंदी',
    'pa': 'ਪੰਜਾਬੀ',
    'gu': 'ગુજરાતી',
    'mr': 'मराठी',
    'bn': 'বাংলা',
    'ta': 'தமிழ்',
    'te': 'తెలుగు',
    'kn': 'ಕನ್ನಡ',
    'or': 'ଓଡ଼ିଆ',
  };

  static const Map<String, String> _localeSubtitles = {
    'en': 'English',
    'hi': 'Hindi',
    'pa': 'Punjabi',
    'gu': 'Gujarati',
    'mr': 'Marathi',
    'bn': 'Bengali',
    'ta': 'Tamil',
    'te': 'Telugu',
    'kn': 'Kannada',
    'or': 'Odia',
  };

  static String subtitleFor(String code) => _localeSubtitles[code] ?? code;
  static String nativeNameFor(String code) => _languageNames[code] ?? code;

  static const List<String> supportedLocales = [
    'hi',
    'en',
    'pa',
    'gu',
    'mr',
    'bn',
    'ta',
    'te',
    'kn',
    'or',
  ];
}

/// Shorthand function for easy access throughout the app
String tr(String key) => AppLocalizations.tr(key);
String trArgs(String key, Map<String, String> args) =>
    AppLocalizations.trArgs(key, args);
bool get isHindi => AppLocalizations.isHindi;

/// Returns the localized abbreviation for a unit value.
String unitAbbr(String? unit) {
  switch (unit) {
    case 'Quintal':
      return tr('quintal_abbr');
    case 'Kg':
      return tr('kg_abbr');
    case 'Packet':
    default:
      return tr('packet_abbr');
  }
}

/// Returns the localized plural form for a unit value.
String unitPlural(String? unit) {
  switch (unit) {
    case 'Quintal':
      return tr('quintals_plural');
    case 'Kg':
      return tr('kgs_plural');
    case 'Packet':
    default:
      return tr('packets_plural');
  }
}

/// Returns the localized label for a unit value.
String unitLabel(String? unit) {
  switch (unit) {
    case 'Quintal':
      return tr('quintal_label');
    case 'Kg':
      return tr('kg_label');
    case 'Packet':
    default:
      return tr('packet_label');
  }
}
