import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NewsArticle {
  final String title;
  final String description;
  final String imageUrl;
  final String sourceUrl;
  final String source;
  final DateTime publishedAt;

  NewsArticle({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.sourceUrl,
    required this.source,
    required this.publishedAt,
  });

  factory NewsArticle.fromNewsApiJson(Map<String, dynamic> json) {
    return NewsArticle(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['urlToImage'] ?? '',
      sourceUrl: json['url'] ?? '',
      source: json['source']?['name'] ?? '',
      publishedAt:
          DateTime.tryParse(json['publishedAt'] ?? '') ?? DateTime.now(),
    );
  }

  factory NewsArticle.fromGNewsJson(Map<String, dynamic> json) {
    return NewsArticle(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image'] ?? '',
      sourceUrl: json['url'] ?? '',
      source: json['source']?['name'] ?? '',
      publishedAt:
          DateTime.tryParse(json['publishedAt'] ?? '') ?? DateTime.now(),
    );
  }

  factory NewsArticle.fromNewsDataJson(Map<String, dynamic> json) {
    return NewsArticle(
      title: json['title'] ?? '',
      description: json['description'] ?? json['content'] ?? '',
      imageUrl: json['image_url'] ?? '',
      sourceUrl: json['link'] ?? '',
      source: json['source_id'] ?? '',
      publishedAt: DateTime.tryParse(json['pubDate'] ?? '') ?? DateTime.now(),
    );
  }
}

class NewsService {
  // NewsAPI Key from environment
  static String get _newsApiKey => dotenv.get('NEWS_API_KEY', fallback: '');

  // Cache news to avoid too many API calls
  static List<NewsArticle>? _cachedNews;
  static DateTime? _lastFetchTime;
  static const Duration _cacheExpiry = Duration(
    hours: 1,
  ); // Refresh every hour for live news

  /// Clear cache to force fresh fetch
  static void clearCache() {
    _cachedNews = null;
    _lastFetchTime = null;
  }

  /// Fetch agriculture/farming related news from NewsAPI
  static Future<List<NewsArticle>> fetchFarmerNews({
    bool forceRefresh = false,
    String locale = 'en',
  }) async {
    // Return cached news if available and not expired
    if (!forceRefresh && _cachedNews != null && _lastFetchTime != null) {
      if (DateTime.now().difference(_lastFetchTime!) < _cacheExpiry) {
        return _cachedNews!;
      }
    }

    try {
      // Fetch live news from NewsAPI
      final news = await _fetchFromNewsApi(locale: locale);
      debugPrint('News: ${news.length}');
      if (news.isNotEmpty) {
        _cachedNews = news;
        _lastFetchTime = DateTime.now();
        return news;
      }
    } catch (e) {
      print('Error fetching news from API: $e');
    }

    // Fallback to curated news if API fails
    final fallbackNews = _getFarmingNews(locale: locale);
    _cachedNews = fallbackNews;
    _lastFetchTime = DateTime.now();
    return fallbackNews;
  }

  /// Maps app locale to NewsAPI supported languages
  /// Official supported: ar, de, en, es, fr, he, it, nl, no, pt, ru, sv, ud, zh
  static String _getNewsapiLanguage(String locale) {
    const supported = {
      'ar',
      'de',
      'en',
      'es',
      'fr',
      'he',
      'it',
      'nl',
      'no',
      'pt',
      'ru',
      'sv',
      'ud',
      'zh',
    };
    if (supported.contains(locale)) return locale;

    // Default to 'en' for all Indian languages (hi, pa, gu, mr, bn, ta, te, kn, or)
    // as NewsAPI doesn't support them natively but returns high quality news about India in English.
    return 'en';
  }

  /// Fetch news from NewsAPI.org
  static Future<List<NewsArticle>> _fetchFromNewsApi({
    String locale = 'en',
  }) async {
    final List<NewsArticle> allNews = [];
    final String apiLang = _getNewsapiLanguage(locale);

    // Get today's date and 7 days ago for fresh news
    final today = DateTime.now();
    final fromDate = today.subtract(const Duration(days: 7));

    // First try: Indian agriculture specific news
    try {
      final url = Uri.parse(
        'https://newsapi.org/v2/everything?'
        'q=(agriculture OR farming OR kisan OR crops OR mandi) AND India&'
        'language=$apiLang&'
        'from=${fromDate.toIso8601String().split('T')[0]}&'
        'sortBy=publishedAt&'
        'pageSize=20&'
        'apiKey=$_newsApiKey',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      debugPrint('News: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'ok' && data['articles'] != null) {
          final articles = data['articles'] as List;
          for (var article in articles) {
            // Only include articles with images and valid titles
            if (article['urlToImage'] != null &&
                article['urlToImage'].toString().isNotEmpty &&
                article['title'] != null &&
                article['title'] != '[Removed]' &&
                _isAgricultureRelated(
                  article['title'],
                  article['description'],
                )) {
              allNews.add(NewsArticle.fromNewsApiJson(article));
            }
          }
        }
      }
    } catch (e) {
      print('NewsAPI agriculture search error: $e');
    }

    // If we got enough news, return them
    if (allNews.length >= 5) {
      return allNews.take(10).toList();
    }

    // Second try: Potato/vegetable specific news
    try {
      final url = Uri.parse(
        'https://newsapi.org/v2/everything?'
        'q=(potato OR vegetable OR cold storage OR MSP OR farmer) AND India&'
        'language=$apiLang&'
        'from=${fromDate.toIso8601String().split('T')[0]}&'
        'sortBy=publishedAt&'
        'pageSize=15&'
        'apiKey=$_newsApiKey',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'ok' && data['articles'] != null) {
          final articles = data['articles'] as List;
          for (var article in articles) {
            if (article['urlToImage'] != null &&
                article['urlToImage'].toString().isNotEmpty &&
                article['title'] != null &&
                article['title'] != '[Removed]' &&
                _isAgricultureRelated(
                  article['title'],
                  article['description'],
                )) {
              // Avoid duplicates
              final exists = allNews.any((a) => a.title == article['title']);
              if (!exists) {
                allNews.add(NewsArticle.fromNewsApiJson(article));
              }
            }
          }
        }
      }
    } catch (e) {
      print('NewsAPI potato search error: $e');
    }

    // If we got news, return them
    if (allNews.isNotEmpty) {
      return allNews.take(10).toList();
    }

    // If no agriculture news found, return empty (will trigger fallback)
    return allNews;
  }

  /// Check if the article is related to agriculture - STRICT filtering
  static bool _isAgricultureRelated(String? title, String? description) {
    final text = '${title ?? ''} ${description ?? ''}'.toLowerCase();

    // Exclude non-agriculture topics explicitly
    final excludeKeywords = [
      'cricket',
      'ipl',
      'movie',
      'film',
      'bollywood',
      'hollywood',
      'politics',
      'election',
      'vote',
      'parliament',
      'congress',
      'bjp',
      'stock market',
      'sensex',
      'nifty',
      'share price',
      'ipo',
      'automobile',
      'car',
      'bike',
      'vehicle',
      'ev',
      'smartphone',
      'iphone',
      'android',
      'laptop',
      'tech',
      'celebrity',
      'actor',
      'actress',
      'entertainment',
      'sports',
      'football',
      'tennis',
      'olympics',
      'murder',
      'crime',
      'accident',
      'rape',
      'scam',
      'trump',
      'biden',
      'usa',
      'china',
      'pakistan',
      'bangladesh',
      'war',
      'military',
      'army',
      'defense',
      'missile',
      'cryptocurrency',
      'bitcoin',
      'ethereum',
      'real estate',
      'property',
      'housing',
    ];

    // Check if any exclude keyword is present - reject the article
    for (var keyword in excludeKeywords) {
      if (text.contains(keyword)) {
        return false;
      }
    }

    // Agriculture related keywords - MUST contain at least one
    final agricultureKeywords = [
      'agriculture',
      'farming',
      'farmer',
      'kisan',
      'crop',
      'crops',
      'potato',
      'aloo',
      'vegetable',
      'sabji',
      'mandi',
      'market',
      'cold storage',
      'harvest',
      'cultivation',
      'seed',
      'fertilizer',
      'irrigation',
      'monsoon',
      'rain',
      'weather',
      'drought',
      'flood',
      'msp',
      'minimum support price',
      'procurement',
      'agri',
      'rural',
      'krishi',
      'pm kisan',
      'subsidy farm',
      'loan farm',
      'yield',
      'production',
      'wheat',
      'rice',
      'onion',
      'tomato',
      'grain',
      'horticulture',
      'soil',
      'organic',
      'pesticide',
      'urea',
      'dap',
      'apmc',
      'wholesale vegetable',
      'food grain',
      'food security',
      'warehouse grain',
      'fci',
      'nafed',
      'sowing',
      'rabi',
      'kharif',
      'sugarcane',
      'cotton',
      'pulses',
      'oilseed',
      'mustard',
      'groundnut',
      'dairy',
      'milk',
      'cattle',
      'livestock',
      'poultry',
      'fishery',
    ];

    // Check if any agriculture keyword is present
    for (var keyword in agricultureKeywords) {
      if (text.contains(keyword)) {
        return true;
      }
    }

    return false;
  }

  /// Full localized fallback data for 10 languages
  static const Map<String, Map<String, dynamic>> _localizedNewsMap = {
    'en': {
      'news': [
        {'title': 'Advance Potato Seed Bookings Open for 2026', 'description': 'Farmers can now book quality potato seeds for the upcoming season at discounted rates. Early bookings get 15% discount.'},
        {'title': 'NCDEX signals return', 'description': 'Potato futures trading set to resume on NCDEX platform after regulatory approval. Traders expect price stability.'},
        {'title': 'Government announces new MSP for potatoes', 'description': 'Agriculture ministry sets minimum support price for potato to help farmers get better returns this season.'},
        {'title': 'Cold storage capacity expansion in UP', 'description': 'State government approves 50 new cold storage facilities to reduce post-harvest losses for potato farmers.'},
        {'title': 'Digital Mandi system launched', 'description': 'Farmers can now sell produce directly to traders through the new digital marketplace. No middlemen involved.'},
        {'title': 'Potato prices rise in Agra mandi', 'description': 'Due to reduced supply from cold storages, potato prices have increased by ₹2-3 per kg in Agra wholesale market.'},
        {'title': 'New potato variety released for UP farmers', 'description': 'CPRI Shimla releases new high-yield potato variety Kufri Khyati suitable for plains of Uttar Pradesh.'},
        {'title': 'PM Kisan next installment date announced', 'description': 'The 19th installment of PM Kisan Samman Nidhi will be credited to farmer accounts by end of this month.'},
        {'title': 'Weather alert for potato growing regions', 'description': 'IMD predicts cold wave in western UP. Farmers advised to protect potato crop from frost damage.'},
        {'title': 'Export demand for Indian potatoes increases', 'description': 'Nepal and Bangladesh increase import orders for Indian potatoes. Prices expected to remain firm.'},
        {'title': 'Organic potato farming training program', 'description': 'Free training program for organic potato farming starts next week at KVK centers across UP.'},
        {'title': 'Subsidy announced for cold storage construction', 'description': 'State government announces 50% subsidy for farmers building small cold storage units.'}
      ],
      'sources': ['Aloo Mandi', 'Krishi News', 'Kisan Samachar', 'Agri Times', 'Mandi Bhav', 'Krishi Jagran', 'Kisan News', 'Mausam Samachar', 'Trade News', 'Krishi Vibhag', 'Govt. News']
    },
    'hi': {
      'news': [
        {'title': '2026 के लिए आलू के बीज की एडवांस बुकिंग शुरू', 'description': 'किसान अब आगामी सीजन के लिए रियायती दरों पर गुणवत्तापूर्ण आलू के बीज बुक कर सकते हैं। जल्दी बुकिंग करने पर 15% की छूट मिलेगी।'},
        {'title': 'NCDEX की वापसी के संकेत', 'description': 'नियामक मंजूरी के बाद NCDEX प्लेटफॉर्म पर आलू वायदा व्यापार फिर से शुरू होने जा रहा है। व्यापारियों को कीमतों में स्थिरता की उम्मीद है।'},
        {'title': 'सरकार ने आलू के लिए नए MSP की घोषणा की', 'description': 'कृषि मंत्रालय ने इस सीजन में किसानों को बेहतर रिटर्न दिलाने में मदद करने के लिए आलू के लिए न्यूनतम समर्थन मूल्य निर्धारित किया है।'},
        {'title': 'यूपी में कोल्ड स्टोरेज क्षमता का विस्तार', 'description': 'राज्य सरकार ने आलू किसानों के लिए फसल कटाई के बाद के नुकसान को कम करने के लिए 50 नई कोल्ड स्टोरेज सुविधाओं को मंजूरी दी है।'},
        {'title': 'डिजिटल मंडी सिस्टम लॉन्च', 'description': 'किसान अब नए डिजिटल मार्केटप्लेस के जरिए व्यापारियों को सीधे उपज बेच सकते हैं। कोई बिचौलिया शामिल नहीं है।'},
        {'title': 'आगरा मंडी में आलू के दाम बढ़े', 'description': 'कोल्ड स्टोरेज से आपूर्ति कम होने के कारण आगरा थोक बाजार में आलू के दाम ₹2-3 प्रति किलो बढ़ गए हैं।'},
        {'title': 'यूपी के किसानों के लिए आलू की नई किस्म जारी', 'description': 'CPRI शिमला ने उत्तर प्रदेश के मैदानी इलाकों के लिए उपयुक्त नई उच्च उपज वाली आलू की किस्म "कुफरी ख्याति" जारी की है।'},
        {'title': 'पीएम किसान की अगली किस्त की तारीख घोषित', 'description': 'पीएम किसान सम्मान निधि की 19वीं किस्त इस महीने के अंत तक किसानों के खातों में जमा कर दी जाएगी।'},
        {'title': 'आलू उत्पादक क्षेत्रों के लिए मौसम का अलर्ट', 'description': 'IMD ने पश्चिमी यूपी में शीत लहर की भविष्यवाणी की है। किसानों को आलू की फसल को पाले से बचाने की सलाह दी गई है।'},
        {'title': 'भारतीय आलू की निर्यात मांग बढ़ी', 'description': 'नेपाल और बांग्लादेश ने भारतीय आलू के आयात ऑर्डर बढ़ा दिए हैं। कीमतें मजबूत रहने की उम्मीद है।'},
        {'title': 'जैविक आलू की खेती का प्रशिक्षण कार्यक्रम', 'description': 'जैविक आलू की खेती के लिए मुफ्त प्रशिक्षण कार्यक्रम अगले सप्ताह यूपी के केवीके केंद्रों में शुरू होगा।'},
        {'title': 'कोल्ड स्टोरेज निर्माण के लिए सब्सिडी की घोषणा', 'description': 'राज्य सरकार ने छोटे कोल्ड स्टोरेज यूनिट बनाने वाले किसानों के लिए 50% सब्सिडी की घोषणा की है।'}
      ],
      'sources': ['आलू मंडी', 'कृषि समाचार', 'किसान समाचार', 'कृषि टाइम्स', 'मंडी भाव', 'कृषि जागरण', 'किसान न्यूज़', 'मौसम समाचार', 'ट्रेड न्यूज़', 'कृषि विभाग', 'सरकारी समाचार']
    },
    'pa': {
      'news': [
        {'title': '2026 ਲਈ ਆਲੂ ਬੀਜਾਂ ਦੀ ਐਡਵਾਂਸ ਬੁਕਿੰਗ ਸ਼ੁਰੂ', 'description': 'ਕਿਸਾਨ ਹੁਣ ਆਉਣ ਵਾਲੇ ਸੀਜ਼ਨ ਲਈ ਛੋਟ ਵਾਲੀਆਂ ਦਰਾਂ \'ਤੇ ਗੁਣਵੱਤਾ ਵਾਲੇ ਆਲੂ ਬੀਜ ਬੁੱਕ ਕਰ ਸਕਦੇ ਹਨ। ਜਲਦੀ ਬੁਕਿੰਗ ਕਰਨ \'ਤੇ 15% ਛੋਟ ਮਿਲਦੀ ਹੈ।'},
        {'title': 'NCDEX ਵਾਪਸੀ ਦੇ ਸੰਕੇਤ', 'description': 'ਰੈਗੂਲੇਟਰੀ ਪ੍ਰਵਾਨਗੀ ਤੋਂ ਬਾਅਦ NCDEX ਪਲੇਟਫਾਰਮ \'ਤੇ ਆਲੂ ਫਿਊਚਰਜ਼ ਵਪਾਰ ਮੁੜ ਸ਼ੁਰੂ ਹੋਣ ਜਾ ਰਿਹਾ ਹੈ। ਵਪਾਰੀਆਂ ਨੂੰ ਕੀਮਤ ਸਥਿਰਤਾ ਦੀ ਉਮੀਦ ਹੈ।'},
        {'title': 'ਸਰਕਾਰ ਨੇ ਆਲੂਆਂ ਲਈ ਨਵੇਂ MSP ਦਾ ਐਲਾਨ ਕੀਤਾ', 'description': 'ਖੇਤੀਬਾੜੀ ਮੰਤਰਾਲੇ ਨੇ ਇਸ ਸੀਜ਼ਨ ਵਿੱਚ ਕਿਸਾਨਾਂ ਨੂੰ ਬਿਹਟਰ ਰਿਟਰਨ ਪ੍ਰਾਪਤ ਕਰਨ ਵਿੱਚ ਮਦਦ ਕਰਨ ਲਈ ਆਲੂ ਲਈ ਘੱਟੋ-ਘੱਟ ਸਮਰਥਨ ਮੁੱਲ ਨਿਰਧਾਰਤ ਕੀਤਾ ਹੈ।'},
        {'title': 'ਯੂਪੀ ਵਿੱਚ ਕੋਲਡ ਸਟੋਰੇਜ ਸਮਰੱਥਾ ਦਾ ਵਿਸਥਾਰ', 'description': 'ਰਾਜ ਸਰਕਾਰ ਨੇ ਆਲੂ ਕਿਸਾਨਾਂ ਲਈ ਕਟਾਈ ਤੋਂ ਬਾਅਦ ਦੇ ਨੁਕਸਾਨ ਨੂੰ ਘਟਾਉਣ ਲਈ 50 ਨਵੀਆਂ ਕੋਲਡ ਸਟੋਰੇਜ ਸਹੂਲਤਾਂ ਨੂੰ ਮਨਜ਼ੂਰੀ ਦਿੱਤੀ ਹੈ।'},
        {'title': 'ਡਿਜੀਟਲ ਮੰਡੀ ਪ੍ਰਣਾਲੀ ਸ਼ੁਰੂ ਕੀਤੀ ਗਈ', 'description': 'ਕਿਸਾਨ ਹੁਣ ਨਵੇਂ ਡਿਜੀਟਲ ਬਾਜ਼ਾਰ ਰਾਹੀਂ ਵਪਾਰੀਆਂ ਨੂੰ ਸਿੱਧੇ ਤੌਰ \'ਤੇ ਉਤਪਾਦ ਵੇਚ ਸਕਦੇ ਹਨ। ਕੋਈ ਵਿਚੋਲਾ ਸ਼ਾਮਲ ਨਹੀਂ ਹੈ।'},
        {'title': 'ਆਗਰਾ ਮੰਡੀ ਵਿੱਚ ਆਲੂ ਦੀਆਂ ਕੀਮਤਾਂ ਵਧੀਆਂ', 'description': 'ਕੋਲਡ ਸਟੋਰਾਂ ਤੋਂ ਸਪਲਾਈ ਘਟਣ ਕਾਰਨ, ਆਗਰਾ ਥੋਕ ਬਾਜ਼ਾਰ ਵਿੱਚ ਆਲੂ ਦੀਆਂ ਕੀਮਤਾਂ ਵਿੱਚ ₹2-3 ਪ੍ਰਤੀ ਕਿਲੋਗ੍ਰਾਮ ਦਾ ਵਾਧਾ ਹੋਇਆ ਹੈ।'},
        {'title': 'ਯੂਪੀ ਦੇ ਕਿਸਾਨਾਂ ਲਈ ਆਲੂ ਦੀ ਨਵੀਂ ਕਿਸਮ ਜਾਰੀ ਕੀਤੀ ਗਈ', 'description': 'ਸੀਪੀਆਰਆਈ ਸ਼ਿਮਲਾ ਨੇ ਉੱਤਰ ਪ੍ਰਦੇਸ਼ ਦੇ ਮੈਦਾਨੀ ਇਲਾਕਿਆਂ ਲਈ ਢੁਕਵੀਂ ਨਵੀਂ ਉੱਚ-ਉਪਜ ਵਾਲੀ ਆਲੂ ਦੀ ਕਿਸਮ ਕੁਫਰੀ ਖਿਆਤੀ ਜਾਰੀ ਕੀਤੀ।'},
        {'title': 'ਪੀਐਮ ਕਿਸਾਨ ਦੀ ਅਗਲੀ ਕਿਸ਼ਤ ਦੀ ਮਿਤੀ ਦਾ ਐਲਾਨ', 'description': 'ਪੀਐਮ ਕਿਸਾਨ ਸਨਮਾਨ ਨਿਧੀ ਦੀ 19ਵੀਂ ਕਿਸ਼ਤ ਇਸ ਮਹੀਨੇ ਦੇ ਅੰਤ ਤੱਕ ਕਿਸਾਨਾਂ ਦੇ ਖਾਤਿਆਂ ਵਿੱਚ ਜਮ੍ਹਾਂ ਕਰ ਦਿੱਤੀ ਜਾਵੇਗੀ।'},
        {'title': 'ਆਲੂ ਉਗਾਉਣ ਵਾਲੇ ਖੇਤਰਾਂ ਲਈ ਮੌਸਮ ਦੀ ਚੇਤਾਵਨੀ', 'description': 'ਆਈਐਮਡੀ ਨੇ ਪੱਛਮੀ ਯੂਪੀ ਵਿੱਚ ਠੰਢ ਦੀ ਲਹਿਰ ਦੀ ਭਵਿੱਖਬਾਣੀ ਕੀਤੀ ਹੈ। ਕਿਸਾਨਾਂ ਨੂੰ ਆਲੂ ਦੀ ਫਸਲ ਨੂੰ ਠੰਡ ਦੇ ਨੁਕਸਾਨ ਤੋਂ ਬਚਾਉਣ ਦੀ ਸਲਾਹ ਦਿੱਤੀ ਹੈ।'},
        {'title': 'ਭਾਰਤੀ ਆਲੂਆਂ ਦੀ ਨਿਰਯਾਤ ਮੰਗ ਵਧਦੀ ਹੈ', 'description': 'ਨੇਪਾਲ ਅਤੇ ਬੰਗਲਾਦੇਸ਼ ਨੇ ਭਾਰਤੀ ਆਲੂਆਂ ਲਈ ਆਯਾਤ ਆਰਡਰ ਵਧਾਏ ਹਨ। ਕੀਮਤਾਂ ਸਥਿਰ ਰਹਿਣ ਦੀ ਉਮੀਦ ਹੈ।'},
        {'title': 'ਜੈਵਿਕ ਆਲੂ ਖੇਤੀ ਸਿਖਲਾਈ ਪ੍ਰੋਗਰਾਮ', 'description': 'ਜੈਵਿਕ ਆਲੂ ਦੀ ਖੇਤੀ ਲਈ ਮੁਫ਼ਤ ਸਿਖਲਾਈ ਪ੍ਰੋਗਰਾਮ ਅਗਲੇ ਹਫ਼ਤੇ ਯੂਪੀ ਭਰ ਦੇ ਕੇਵੀਕੇ ਕੇਂਦਰਾਂ \'ਤੇ ਸ਼ੁਰੂ ਹੋਵੇਗਾ।'},
        {'title': 'ਕੋਲਡ ਸਟੋਰੇਜ ਨਿਰਮਾਣ ਲਈ ਸਬਸਿਡੀ ਦਾ ਐਲਾਨ', 'description': 'ਰਾਜ ਸਰਕਾਰ ਨੇ ਛੋਟੇ ਕੋਲਡ ਸਟੋਰੇਜ ਯੂਨਿਟ ਬਣਾਉਣ ਵਾਲੇ ਕਿਸਾਨਾਂ ਲਈ 50% ਸਬਸਿਡੀ ਦਾ ਐਲਾਨ ਕੀਤਾ।'}
      ],
      'sources': ['ਆਲੂ ਮੰਡੀ', 'ਕ੍ਰਿਸ਼ੀ ਨਿਊਜ਼', 'ਕਿਸਾਨ ਸਮਾਚਾਰ', 'ਐਗਰੀ ਟਾਈਮਜ਼', 'ਮੰਡੀ ਭਾਵ', 'ਕ੍ਰਿਸ਼ੀ ਜਾਗਰਣ', 'ਕਿਸਾਨ ਨਿਊਜ਼', 'ਮੌਸਮ ਸਮਾਚਾਰ', 'ਵਪਾਰ ਸਮਾਚਾਰ', 'ਕ੍ਰਿਸ਼ੀ ਵਿਭਾਗ', 'ਸਰਕਾਰੀ ਸਮਾਚਾਰ']
    },
    'gu': {
      'news': [
        {'title': '2026 માટે બટેટાના બિયારણનું એડવાન્સ બુકિંગ શરૂ', 'description': 'ખેડૂતો હવે આગામી સિઝન માટે ગુણવત્તાયુક્ત બટાકાના બિયારણ સસ્તા દરે બુક કરી શકે છે. વહેલા બુકિંગ પર 15% ડિસ્કાઉન્ટ મળશે.'},
        {'title': 'NCDEX પરત આવવાના સંકેત', 'description': 'નિયમનકારી મંજૂરી પછી NCDEX પ્લેટફોર્મ પર બટાકાના વાયદાના વેપાર ફરી શરૂ થવા જઈ રહ્યા છે. વેપારીઓ ભાવમાં સ્થિરતાની અપેક્ષા રાખે છે.'},
        {'title': 'સરકારે બટાકા માટે નવા MSPની જાહેરાત કરી', 'description': 'કૃષિ મંત્રાલયે આ સિઝનમાં ખેડૂતોને વધુ વળતર મળે તે માટે બટાકા માટે લઘુત્તમ ટેકાના ભાવ નક્કી કર્યા છે.'},
        {'title': 'યુપીમાં કોલ્ડ સ્ટોરેજ ક્ષમતાનું વિસ્તરણ', 'description': 'રાજ્ય સરકારે બટાકાના ખેડૂતોને લણણી પછીના નુકસાનને ઘટાડવા માટે 50 નવી કોલ્ડ સ્ટોરેજ સુવિધાઓને મંજૂરી આપી છે.'},
        {'title': 'ડિજિટલ મંડી સિસ્ટમ શરૂ કરવામાં આવી', 'description': 'ખેડૂતો હવે નવા ડિજિટલ માર્કેટપ્લેસ દ્વારા સીધા વેપારીઓને ઉત્પાદન વેચી શકે છે. કોઈ વચેટિયા સામેલ નથી.'},
        {'title': 'આગ્રા મંડીમાં બટાકાના ભાવમાં વધારો', 'description': 'કોલ્ડ સ્ટોરેજમાંથી ઓછી સપ્લાયને કારણે આગ્રાના જથ્થાબંધ બજારમાં બટાકાના ભાવમાં કિલો દીઠ ₹2-3નો વધારો થયો છે.'},
        {'title': 'યુપીના ખેડૂતો માટે બટાકાની નવી જાત બહાર પાડવામાં આવી', 'description': 'CPRI શિમલાએ ઉત્તર પ્રદેશના મેદાની વિસ્તારો માટે યોગ્ય નવી ઉચ્ચ ઉપજ આપતી બટાકાની જાત \'કુફરી ખ્યાતિ\' બહાર પાડી છે.'},
        {'title': 'પીએમ કિસાન આગામી હપ્તાની તારીખ જાહેર', 'description': 'પીએમ કિસાન સન્માન નિધિનો 19મો હપ્તો આ મહિનાના અંત સુધીમાં ખેડૂતોના ખાતામાં જમા કરવામાં આવશે.'},
        {'title': 'બટાકા ઉગાડતા પ્રદેશો માટે હવામાનની ચેતરણી', 'description': 'IMD એ પશ્ચિમ યુપીમાં શીતલહેરની આગાહી કરી છે. ખેડૂતોને બટાકાના પાકને ઝાકળના નુકસાનથી બચાવવા સલાહ આપવામાં આવી છે.'},
        {'title': 'ભારતીય બટાકાની નિકાસ માંગ વધી', 'description': 'નેપાળ અને બાંગ્લાદેશે ભારતીય બટાકા માટે આયાત ઓર્ડર વધાર્યા છે. ભાવો મજબૂત રહેવાની ધારણા છે.'},
        {'title': 'ઓર્ગેનિક બટેટા ખેતી તાલીમ કાર્યક્રમ', 'description': 'ઓર્ગેનિક બટાકાની ખેતી માટે મફત તાલીમ કાર્યક્રમ આવતા અઠવાડિયે સમગ્ર યુપીના KVK કેન્દ્રો પર શરૂ થશે.'},
        {'title': 'કોલ્ડ સ્ટોરેજ બનાવવા માટે સબસિડી જાહેર', 'description': 'રાજ્ય સરકારે નાના કોલ્ડ સ્ટોરેજ યુનિટ બનાવતા ખેડૂતો માટે 50% સબસિડીની જાહેરાત કરી છે.'}
      ],
      'sources': ['બટાટા મંડી', 'કૃષિ સમાચાર', 'કિસાન સમાચાર', 'એગ્રી ટાઈમ્સ', 'મંડી ભાવ', 'કૃષિ જાગરણ', 'કિસાન ન્યૂઝ', 'હવામાન સમાચાર', 'ટ્રેડ ન્યૂઝ', 'કૃષિ વિભાગ', 'સરકારી સમાચાર']
    },
    'mr': {
      'news': [
        {'title': '2026 साठी बटाटा बियाणे आगाऊ बुकिंग सुरू', 'description': 'शेतकरी आता आगामी हंगामासाठी दर्जेदार बटाटा बियाणे सवलतीच्या दरात बुक करू शकतात. लवकर बुकिंग केल्यास 15% सवलत मिळेल.'},
        {'title': 'NCDEX परतण्याचे संकेत', 'description': 'नियामक मान्यतेनंतर NCDEX प्लॅटफॉर्मवर बटाटा वायदा व्यापार पुन्हा सुरू होणार आहे. व्यापाऱ्यांना किंमत स्थिरतेची अपेक्षा आहे.'},
        {'title': 'सरकारने बटाट्यासाठी नवीन MSP जाहीर केला', 'description': 'कृषी मंत्रालयाने या हंगामात शेतकऱ्यांना चांगला परतावा मिळावा यासाठी बटाट्यासाठी किमान आधारभूत किंमत निश्चित केली आहे.'},
        {'title': 'यूपीमध्ये कोल्ड स्टोरेज क्षमतेचा विस्तार', 'description': 'बटाटा शेतकऱ्यांचे काढणीनंतरचे नुकसान कमी करण्यासाठी राज्य सरकारने 50 नवीन कोल्ड स्टोरेज सुविधांना मंजुरी दिली आहे.'},
        {'title': 'डिजिटल मंडी प्रणाली सुरू', 'description': 'शेतकरी आता नवीन डिजिटल मार्केटप्लेसद्वारे थेट व्यापाऱ्यांना शेतीमाल विकू शकतात. यामध्ये मध्यस्थांचा सहभाग नाही.'},
        {'title': 'आग्रा मंडीमध्ये बटाट्याच्या दरात वाढ', 'description': 'कोल्ड स्टोरेजमधून पुरवठा कमी झाल्यामुळे आग्रा घाऊक बाजारात बटाट्याचे दर ₹2-3 प्रति किलोने वाढले आहेत.'},
        {'title': 'यूपीच्या शेतकऱ्यांसाठी बटाट्याची नवीन जात विकसित', 'description': 'CPRI सिमला ने उत्तर प्रदेशातील मैदानी प्रदेशांसाठी योग्य अशी नवीन उच्च उत्पन्न देणारी बटाट्याची जात \'कुफरी ख्याती\' प्रसिद्ध केली आहे.'},
        {'title': 'पीएम किसान पुढील हप्त्याची तारीख जाहीर', 'description': 'पीएम किसान सन्मान निधीचा 19 वा हप्ता या महिन्याच्या अखेरीस शेतकऱ्यांच्या खात्यात जमा केला जाईल.'},
        {'title': 'बटाटा उत्पादक क्षेत्रांसाठी हवामानाचा इशारा', 'description': 'आयएमडीने पश्चिम यूपीमध्ये थंडीच्या लाटेचा अंदाज वर्तवला आहे. शेतकऱ्यांना बटाटा पिकाचे दव आणि थंडीपासून संरक्षण करण्याचा सल्ला दिला आहे.'},
        {'title': 'भारतीय बटाट्यांच्या निर्यातीची मागणी वाढली', 'description': 'नेपाळ आणि बांगलादेशने भारतीय बटाट्यांसाठी आयात ऑर्डर वाढवल्या आहेत. किमती स्थिर राहण्याची शक्यता आहे.'},
        {'title': 'सेंद्रिय बटाटा शेती प्रशिक्षण कार्यक्रम', 'description': 'सेंद्रिय बटाटा शेतीसाठी मोफत प्रशिक्षण कार्यक्रम पुढील आठवड्यात यूपीमधील केव्हीके केंद्रांवर सुरू होत आहे.'},
        {'title': 'कोल्ड स्टोरेज बांधकामासाठी अनुदानाची घोषणा', 'description': 'लहान कोल्ड स्टोरेज युनिट्स बांधणाऱ्या शेतकऱ्यांसाठी राज्य सरकारने 50% अनुदानाची घोषणा केली आहे.'}
      ],
      'sources': ['बटाटा मंडी', 'कृषी बातम्या', 'शेतकरी बातम्या', 'অ‍ॅग्री टाइम्स', 'मंडी भाव', 'कृषी जागरण', 'किसान न्यूज', 'हवामान बातम्या', 'व्यापार बातम्या', 'कृषी विभाग', 'शासकीय बातम्या']
    },
    'bn': {
      'news': [
        {'title': '২০২৬ সালের জন্য অগ্রিম আলু বীজ বুকিং শুরু', 'description': 'কৃষকরা এখন আসন্ন মৌসুমের জন্য গুণমানের আলু বীজ সুলভ মূল্যে বুক করতে পারেন। আগাম বুকিংয়ে ১৫% ছাড় পাওয়া যাবে।'},
        {'title': 'NCDEX প্রত্যাবর্তনের ইঙ্গিত', 'description': 'নিয়ন্ত্রক অনুমোদনের পর NCDEX প্ল্যাটফর্মে আলু ফিউচার ট্রেডিং পুনরায় শুরু হতে চলেছে। ব্যবসায়ীরা মূল্য স্থিতিশীলতার আশা করছেন।'},
        {'title': 'সরকার আলুর জন্য নতুন MSP ঘোষণা করেছে', 'description': 'কৃষি মন্ত্রক এই মৌসুমে কৃষকদের ভালো মুনাফা পেতে সাহায্য করার জন্য আলুর ন্যূনতম সহায়ক মূল্য নির্ধারণ করেছে।'},
        {'title': 'উত্তরপ্রদেশে কোল্ড স্টোরেজ ক্ষমতা সম্প্রসারণ', 'description': 'আলু চাষীদের ফসল কাটার পরবর্তী ক্ষতি কমাতে রাজ্য সরকার ৫০টি নতুন কোল্ড স্টোরেজ সেন্টারের অনুমোদন দিয়েছে।'},
        {'title': 'ডিজিটাল মান্ডি ব্যবস্থার সূচনা', 'description': 'কৃষকরা এখন নতুন ডিজিটাল বাজারের মাধ্যমে সরাসরি ব্যবসায়ীদের কাছে পণ্য বিক্রি করতে পারবেন। কোনো মধ্যস্বত্বভোগী জড়িত নেই।'},
        {'title': 'আগ্রা মান্ডিতে আলুর দাম বৃদ্ধি', 'description': 'কোল্ড স্টোরেজ থেকে সরবরাহ কমে যাওয়ায় আগ্রার পাইকারি বাজারে আলুর দাম প্রতি কেজি ২-৩ টাকা বেড়েছে।'},
        {'title': 'ইউপি কৃষকদের জন্য আলুর নতুন জাত উদ্ভাবন', 'description': 'সিপিআরআই শিমলা উত্তর প্রদেশের সমতল ভূমির জন্য উপযোগী নতুন উচ্চ ফলনশীল আলুর জাত \'কুফরি খ্যাতি\' প্রকাশ করেছে।'},
        {'title': 'পিএম কিষাণ পরবর্তী কিস্তির তারিখ ঘোষণা', 'description': 'পিএম কিষাণ সম্মান নিধির ১৯তম কিস্তি এই মাসের শেষের দিকে কৃষকদের অ্যাকাউন্টে জমা হবে।'},
        {'title': 'আলু চাষি অঞ্চলের জন্য আবহাওয়ার সতর্কতা', 'description': 'আইএমডি পশ্চিম ইউপিতে শৈত্যপ্রবাহের পূর্বাভাস দিয়েছে। কৃষকদের আলুর চারা কুয়াশা থেকে রক্ষা করার পরামর্শ দেওয়া হয়েছে।'},
        {'title': 'ভারতীয় আলুর রপ্তানি চাহিদা বাড়ছে', 'description': 'নেপাল ও বাংলাদেশ ভারতীয় আলুর আমদানি অর্ডার বাড়িয়েছে। দাম চড়া থাকার সম্ভাবনা রয়েছে।'},
        {'title': 'জৈব আলু চাষ প্রশিক্ষণ কর্মসূচি', 'description': 'জৈব আলু চাষের জন্য বিনামূল্যে প্রশিক্ষণ কর্মসূচি আগামী সপ্তাহে ইউপি জুড়ে কেভিকে কেন্দ্রগুলিতে শুরু হবে।'},
        {'title': 'কোল্ড স্টোরেজ নির্মাণের জন্য ভরতুকি ঘোষণা', 'description': 'ক্ষুদ্র কোল্ড স্টোরেজ ইউনিট নির্মাণকারী কৃষকদের জন্য রাজ্য সরকার ৫০% ভরতুকি ঘোষণা করেছে।'}
      ],
      'sources': ['আলু মান্ডি', 'কৃষি সংবাদ', 'কিষাণ সমাচার', 'এগ্রি টাইমস', 'মান্ডি ভাব', 'কৃষি জাগরণ', 'কিষাণ নিউজ', 'আবহাওয়া সংবাদ', 'ট্রেড নিউজ', 'কৃষি বিভাগ', 'সরকারি সংবাদ']
    },
    'ta': {
      'news': [
        {'title': '2026-க்கான உருளைக்கிழங்கு விதைகள் முன்பதிவு ஆரம்பம்', 'description': 'விவசாயிகள் வரும் பருவத்திற்கு தரமான உருளைக்கிழங்கு விதைகளை தள்ளுபடி விலையில் இப்போது முன்பதிவு செய்யலாம். முன்பதிவு செய்பவர்களுக்கு 15% தள்ளுபடி உண்டு.'},
        {'title': 'NCDEX வர்த்தகம் மீண்டும் தொடங்குவதற்கான அறிகுறி', 'description': 'அங்கீகாரம் பெற்ற பிறகு NCDEX தளத்தில் உருளைக்கிழங்கு முன்பேர வர்த்தகம் மீண்டும் தொடங்க உள்ளது. விலையில் ஒரு நிலைத்தன்மையை வர்த்தகர்கள் எதிர்பார்க்கின்றனர்.'},
        {'title': 'உருளைக்கிழங்கிற்கு புதிய குறைந்தபட்ச ஆதரவு விலையை அரசு அறிவித்துள்ளது', 'description': 'விவசாயிகள் இந்த பருவத்தில் நல்ல லாபம் பெறுவதற்காக வேளாண் அமைச்சகம் உருளைக்கிழங்கிற்கு புதிய குறைந்தபட்ச ஆதரவு விலையை நிர்ணயித்துள்ளது.'},
        {'title': 'உத்தரபிரதேசத்தில் குளிர்பதன கிடங்கு வசதிகள் விரிவாக்கம்', 'description': 'உருளைக்கிழங்கு விவசாயிகளின் அறுவடைக்கு பிந்தைய இழப்புகளைக் குறைக்க மாநில அரசு 50 புதிய குளிர்பதன கிடங்குகளுக்கு ஒப்புதல் அளித்துள்ளது.'},
        {'title': 'டிஜிட்டல் மண்டி முறை அறிமுகம்', 'description': 'விவசாயிகள் இப்போது புதிய டிஜிட்டல் சந்தை மூலம் நேரடியாக வர்த்தகர்களிடம் விளைபொருட்களை விற்கலாம். இடைத்தரகர்கள் யாரும் இல்லை.'},
        {'title': 'ஆக்ரா மண்டியில் உருளைக்கிழங்கு விலை உயர்வு', 'description': 'குளிர்பதன கிடங்குகளில் இருந்து வரத்து குறைந்ததால், ஆக்ரா மொத்த விற்பனை சந்தையில் உருளைக்கிழங்கு விலை கிலோவுக்கு ₹2-3 உயர்ந்துள்ளது.'},
        {'title': 'உத்தரபிரதேச விவசாயிகளுக்காக புதிய உருளைக்கிழங்கு ரகம் அறிமுகம்', 'description': 'குஃப்ரி கியாதி என்ற அதிக மகசூல் தரும் புதிய உருளைக்கிழங்கு ரகத்தை சிபிஆர்ஐ சிம்லா உத்தரபிரதேச சமவெளி பகுதிகளுக்காக அறிமுகப்படுத்தியுள்ளது.'},
        {'title': 'பிஎம் கிசான் அடுத்த தவணை தேதி அறிவிப்பு', 'description': 'பிஎம் கிசான் சம்மான் நிதியின் 19-வது தவணைத் தொகை இந்த மாத இறுதிக்குள் விவசாயிகளின் வங்கிக் கணக்கில் வரவு வைக்கப்படும்.'},
        {'title': 'உருளைக்கிழங்கு விளைச்சல் பகுதிகளுக்கான வானிலை எச்சரிக்கை', 'description': 'மேற்கு உத்தரபிரதேசத்தில் குளிர் அலை வீசக்கூடும் என வானிலை ஆய்வு மையம் கணித்துள்ளது. விவசாயிகள் பயிர்களைப் பனியிலிருந்து பாதுகாக்க அறிவுறுத்தப்படுகிறார்கள்.'},
        {'title': 'இந்திய உருளைக்கிழங்கிற்கான ஏற்றுமதி தேவை அதிகரிப்பு', 'description': 'நேபாளம் மற்றும் வங்கதேசம் இந்திய உருளைக்கிழங்கிற்கான இறக்குமதி ஆர்டர்களை அதிகரித்துள்ளன. விலைகள் வலுவாக இருக்கும் என எதிர்பார்க்கப்படுகிறது.'},
        {'title': 'இயற்கை உருளைக்கிழங்கு விவசாய பயிற்சி திட்டம்', 'description': 'இயற்கை உருளைக்கிழங்கு விவசாயத்திற்கான இலவச பயிற்சி திட்டம் அடுத்த வாரம் உத்தரபிரதேசம் முழுவதும் உள்ள கேவிகே மையங்களில் தொடங்குகிறது.'},
        {'title': 'குளிர்பதன கிடங்கு அமைக்க மானியம் அறிவிப்பு', 'description': 'சிறிய குளிர்பதன கிடங்குகளை அமைக்கும் விவசாயிகளுக்கு 50% மானியம் வழங்க மாநில அரசு அறிவித்துள்ளது.'}
      ],
      'sources': ['உருளைக்கிழங்கு மண்டி', 'வேளாண் செய்திகள்', 'கிசான் சமாச்சார்', 'அக்ரி டைம்ஸ்', 'மண்டி விபரம்', 'கிருஷி ஜாக்ரன்', 'கிசான் செய்திகள்', 'வானிலை செய்திகள்', 'வர்த்தக செய்திகள்', 'வேளாண் துறை', 'அரசு செய்திகள்']
    },
    'te': {
      'news': [
        {'title': '2026 కోసం బంగాళాదుంప విత్తనాల ముందస్తు బుకింగ్ ప్రారంభం', 'description': 'రైతులు ఇప్పుడు రాబోయే సీజన్ కోసం నాణ్యమైన బంగాళాదుంప విత్తనాలను రాయితీ ధరలకు బుక్ చేసుకోవచ్చు. ముందస్తు బుకింగ్‌పై 15% తగ్గింపు.'},
        {'title': 'NCDEX తిరిగి వచ్చే సంకేతాలు', 'description': 'నియంత్రణ ఆమోదం పొందిన తర్వాత NCDEX ప్లాట్‌ఫారమ్‌లో బంగాళాదుంప ఫ్యూచర్స్ ట్రేడింగ్ తిరిగి ప్రారంభం కానుంది. ధరల స్థిరత్వాన్ని వ్యాపారులు ఆశిస్తున్నారు.'},
        {'title': 'బంగాళాదుంపలకు ప్రభుత్వం కొత్త మద్దతు ధరను ప్రకటించింది', 'description': 'రైతులు ఈ సీజన్‌లో మెరుగైన రాబడిని పొందేందుకు వ్యవసాయ మంత్రిత్వ శాఖ బంగాళాదుంపలకు కనీస మద్దతు ధరను నిర్ణయించింది.'},
        {'title': 'యూపీలో కోల్డ్ స్టోరేజీ సామర్థ్యం పెంపు', 'description': 'బంగాళాదుంప రైతుల పంట తర్వాత నష్టాలను తగ్గించడానికి రాష్ట్ర ప్రభుత్వం 50 కొత్త కోల్డ్ స్టోరేజీ సౌకర్యాలను ఆమోదించింది.'},
        {'title': 'డిజిటల్ మండి వ్యవస్థ ప్రారంభం', 'description': 'రైతులు ఇప్పుడు కొత్త డిజిటల్ మార్కెట్ ప్లేస్ ద్వారా నేరుగా వ్యాపారులకు తమ పంటను అమ్ముకోవచ్చు. దళారుల అవసరం లేదు.'},
        {'title': 'ఆగ్రా మండిలో పెరిగిన బంగాళాదుంపల ధరలు', 'description': 'కోల్డ్ స్టోరేజీల నుండి సరఫరా తగ్గడం వల్ల ఆగ్రా హోల్ సేల్ మార్కెట్‌లో బంగాళాదుంప ధరలు కిలోకు ₹2-3 పెరిగాయి.'},
        {'title': 'యూపీ రైతుల కోసం కొత్త బంగాళాదుంప రకం విడుదల', 'description': 'CPRI సిమ్లా ఉత్తరప్రదేశ్ మైదాన ప్రాంతాలకు అనువైన కొత్త అధిక దిగుబడినిచ్చే బంగాళాదుంప రకం \'కుఫ్రి ఖ్యాతి\'ని విడుదల చేసింది.'},
        {'title': 'పీఎం కిసాన్ తదుపరి విడత తేదీ వెల్లడి', 'description': 'పీఎం కిసాన్ సమ్మాన్ నిధి 19వ విడత ఈ నెలాఖరులోగా రైతుల ఖాతాల్లో జమ చేయబడుతుంది.'},
        {'title': 'బంగాళాదుంపలు పండించే ప్రాంతాలకు వాతావరణ హెచ్చరిక', 'description': 'పశ్చిమ యూపీలో శీతల గాలులు వీస్తాయని IMD అంచనా వేసింది. రైతులు తమ పంటను తుషార నష్టం నుండి కాపాడుకోవాలని సూచించారు.'},
        {'title': 'భారతీయ బంగాళాదుంపలకు పెరిగిన ఎగుమతి డిమాండ్', 'description': 'నేపాల్ మరియు బంగ్లాదేశ్ భారతీయ బంగాళాదుంపల కొనుగోలు ఆర్డర్లను పెంచాయి. ధరలు నిలకడగా ఉండే అవకాశం ఉంది.'},
        {'title': 'సేంద్రీయ బంగాళాదుంప సాగు శిక్షణా కార్యక్రమం', 'description': 'సేంద్రీయ బంగాళాదుంప సాగుపై ఉచిత శిక్షణా కార్యక్రమం వచ్చే వారం యూపీవ్యాప్తంగా KVK కేంద్రాల్లో ప్రారంభమవుతుంది.'},
        {'title': 'కోల్డ్ స్టోరేజీ నిర్మాణానికి రాయితీ ప్రకటన', 'description': 'చిన్న కోల్డ్ స్టోరేజీ యూనిట్లను నిర్మించే రైతులకు రాష్ట్ర ప్రభుత్వం 50% సబ్సిడీని ప్రకటించింది.'}
      ],
      'sources': ['బంగాళాదుంపల మండి', 'కృషి న్యూస్', 'కిసాన్ సమాచార్', 'అగ్రి టైమ్స్', 'మండి రేట్లు', 'కృషి జాగరణ్', 'కిసాన్ న్యూస్', 'వాతావరణ సమాచారం', 'ట్రేడ్ న్యూస్', 'వ్యవసాయ శాఖ', 'ప్రభుత్వ వార్తలు']
    },
    'kn': {
      'news': [
        {'title': '2026ರ ಸಾಲಿಗೆ ಆಲೂಗಡ್ಡೆ ಬಿತ್ತನೆ ಬೀಜಗಳ ಮುಂಗಡ ಬುಕಿಂಗ್ ಆರಂಭ', 'description': 'ರೈತರು ಈಗ ಮುಂಬರುವ ಹಂಗಾಮಿಗೆ ಗುಣಮಟ್ಟದ ಆಲೂಗಡ್ಡೆ ಬೀಜಗಳನ್ನು ರಿಯಾಯಿತಿ ದರದಲ್ಲಿ ಬುಕ್ ಮಾಡಬಹುದು. ಮುಂಗಡ ಬುಕಿಂಗ್‌ಗೆ 15% ರಿಯಾಯಿತಿ ಸಿಗಲಿದೆ.'},
        {'title': 'NCDEX ಮರಳಿ ಬರುವ ಸೂಚನೆ', 'description': 'ನಿಯಂತ್ರಕ ಅನುಮೋದನೆಯ ನಂತರ NCDEX ಪ್ಲಾಟ್‌ಫಾರ್ಮ್‌ನಲ್ಲಿ ಆಲೂಗಡ್ಡೆ ಫ್ಯೂಚರ್ಸ್ ವ್ಯಾಪಾರ ಪುನರಾರಂಭಗೊಳ್ಳಲಿದೆ. ವ್ಯಾಪಾರಸ್ಥರು ಬೆಲೆ ಸ್ಥಿರತೆಯನ್ನು ನಿರೀಕ್ಷಿಸುತ್ತಿದ್ದಾರೆ.'},
        {'title': 'ಸರ್ಕಾರದಿಂದ ಆಲೂಗಡ್ಡೆಗೆ ಹೊಸ ಕನಿಷ್ಠ ಬೆಂಬಲ ಬೆಲೆ ಘೋಷಣೆ', 'description': 'ರೈತರು ಈ ಹಂಗಾಮಿನಲ್ಲಿ ಉತ್ತಮ ಆದಾಯ ಪಡೆಯಲು ಅನುಕೂಲವಾಗುವಂತೆ ಕೃಷಿ ಸಚಿವಾಲಯವು ಆಲೂಗಡ್ಡೆಗೆ ಕನಿಷ್ಠ ಬೆಂಬಲ ಬೆಲೆ ನಿಗದಿಪಡಿಸಿದೆ.'},
        {'title': 'ಉತ್ತರ ಪ್ರದೇಶದಲ್ಲಿ ಕೋಲ್ಡ್ ಸ್ಟೋರೇಜ್ ಸಾಮರ್ಥ್ಯ ವಿಸ್ತರಣೆ', 'description': 'ಆಲೂಗಡ್ಡೆ ರೈತರ ಕೊಯ್ಲಿನ ನಂತರದ ನಷ್ಟವನ್ನು ಕಡಿಮೆ ಮಾಡಲು ರಾಜ್ಯ ಸರ್ಕಾರವು 50 ಹೊಸ ಕೋಲ್ಡ್ ಸ್ಟೋರೇಜ್ ಸೌಲಭ್ಯಗಳನ್ನು ಅನುಮೋದಿಸಿದೆ.'},
        {'title': 'ಡಿಜಿಟಲ್ ಮಂಡಿ ವ್ಯವಸ್ಥೆ ಜಾರಿಗೆ', 'description': 'ರೈತರು ಈಗ ಹೊಸ ಡಿಜಿಟಲ್ ಮಾರುಕಟ್ಟೆಯ ಮೂಲಕ ನೇರವಾಗಿ ವ್ಯಾಪಾರಿಗಳಿಗೆ ಉತ್ಪನ್ನಗಳನ್ನು ಮಾರಾಟ ಮಾಡಬಹುದು. ಯಾವುದೇ ಮಧ್ಯವರ್ತಿಗಳ ಅಗತ್ಯವಿಲ್ಲ.'},
        {'title': 'ಆಗ್ರಾ ಮಂಡಿಯಲ್ಲಿ ಆಲೂಗಡ್ಡೆ ಬೆಲೆ ಏರಿಕೆ', 'description': 'ಕೋಲ್ಡ್ ಸ್ಟೋರೇಜ್‌ಗಳಿಂದ ಪೂರೈಕೆ ಕಡಿಮೆಯಾಗಿರುವುದರಿಂದ ಆಗ್ರಾ ಸಗಟು ಮಾರುಕಟ್ಟೆಯಲ್ಲಿ ಆಲೂಗಡ್ಡೆ ಬೆಲೆ ಕೆಜಿಗೆ ₹2-3 ರಷ್ಟು ಹೆಚ್ಚಾಗಿದೆ.'},
        {'title': 'ಯುಪಿ ರೈತರಿಗಾಗಿ ಹೊಸ ತಳಿಯ ಆಲೂಗಡ್ಡೆ ಬಿಡುಗಡೆ', 'description': 'ಸಿಪಿಆರ್ಐ ಶಿಮ್ಲಾ ಉತ್ತರ ಪ್ರದೇಶದ ಬಯಲು ಪ್ರದೇಶಗಳಿಗೆ ಸೂಕ್ತವಾದ ಹೊಸ ಅಧಿಕ ಇಳುವರಿ ನೀಡುವ ಆಲೂಗಡ್ಡೆ ತಳಿ \'ಕುಫ್ರಿ ಖ್ಯಾತಿ\'ಯನ್ನು ಬಿಡುಗಡೆ ಮಾಡಿದೆ.'},
        {'title': 'ಪಿಎಂ ಕಿಸಾನ್ ಮುಂದಿನ ಕಂತಿನ ದಿನಾಂಕ ಪ್ರಕಟ', 'description': 'ಪಿಎಂ ಕಿಸಾನ್ ಸಮ್ಮಾನ್ ನಿಧಿಯ 19ನೇ ಕಂತಿನ ಹಣ ಈ ತಿಂಗಳಾಂತ್ಯದೊಳಗೆ ರೈತರ ಖಾತೆಗಳಿಗೆ ಜಮೆಯಾಗಲಿದೆ.'},
        {'title': 'ಆಲೂಗಡ್ಡೆ ಬೆಳೆಯುವ ಪ್ರದೇಶಗಳಿಗೆ ಹವಾಮಾನ ಮುನ್ಸೂಚನೆ', 'description': 'ಪಶ್ಚಿಮ ಯುಪಿಯಲ್ಲಿ ಶೈತ್ಯ ಲಹರಿಯ ಮುನ್ಸೂಚನೆಯನ್ನು ಐಎಂಡಿ ನೀಡಿದೆ. ರೈತರು ಆಲೂಗಡ್ಡೆ ಬೆಳೆಯನ್ನು ಹಿಮದ ಹಾನಿಯಿಂದ ರಕ್ಷಿಸಲು ಸೂಚಿಸಲಾಗಿದೆ.'},
        {'title': 'ಭಾರತೀಯ ಆಲೂಗಡ್ಡೆಗೆ ಹೆಚ್ಚಿದ ರಫ್ತು ಬೇಡಿಕೆ', 'description': 'ನೇಪಾಳ ಮತ್ತು ಬಾಂಗ್ಲಾದೇಶ ಭಾರತೀಯ ಆಲೂಗಡ್ಡೆಗೆ ಆಮದು ಆದೇಶಗಳನ್ನು ಹೆಚ್ಚಿಸಿವೆ. ಬೆಲೆಗಳು ಸ್ಥಿರವಾಗಿರುವ ನಿರೀಕ್ಷೆಯಿದೆ.'},
        {'title': 'ಸಾವಯವ ಆಲೂಗಡ್ಡೆ ಕೃಷಿ ತರಬೇತಿ ಕಾರ್ಯಕ್ರಮ', 'description': 'ಸಾವಯವ ಆಲೂಗಡ್ಡೆ ಕೃಷಿಯ ಉಚಿತ ತರಬೇತಿ ಕಾರ್ಯಕ್ರಮವು ಮುಂದಿನ ವಾರ ಯುಪಿಯಾದ್ಯಂತ ಕೆವಿಕೆ ಕೇಂದ್ರಗಳಲ್ಲಿ ಪ್ರಾರಂಭವಾಗಲಿದೆ.'},
        {'title': 'ಕೋಲ್ಡ್ ಸ್ಟೋರೇಜ್ ನಿರ್ಮಾಣಕ್ಕೆ ಸಬ್ಸಿಡಿ ಘೋಷಣೆ', 'description': 'ಸಣ್ಣ ಕೋಲ್ಡ್ ಸ್ಟೋರೇಜ್ ಘಟಕಗಳನ್ನು ನಿರ್ಮಿಸುವ ರೈತರಿಗೆ ರಾಜ್ಯ ಸರ್ಕಾರವು 50% ಸಬ್ಸಿಡಿಯನ್ನು ಘೋಷಿಸಿದೆ.'}
      ],
      'sources': ['ಆಲೂಗಡ್ಡೆ ಮಂಡಿ', 'ಕೃಷಿ ಸುದ್ದಿ', 'ಕಿಸಾನ್ ಸಮಾಚಾರ', 'ಅಗ್ರಿ ಟೈಮ್ಸ್', 'ಮಂಡಿ ದರ', 'ಕೃಷಿ ಜಾಗರಣ', 'ಕಿಸಾನ್ ನ್ಯೂಸ್', 'ಹವಾಮಾನ ವರದಿ', 'ವ್ಯಾಪಾರ ಸುದ್ದಿ', 'ಕೃಷಿ ಇಲಾಖೆ', 'ಸರ್ಕಾರಿ ಸುದ್ದಿ']
    },
    'or': {
      'news': [
        {'title': '2026 ପାଇଁ ଆଗୁଆ ଆଳୁ ବିହନ ବୁକିଂ ଆରମ୍ଭ', 'description': 'ଚାଷୀମାନେ ବର୍ତ୍ତମାନ ଆଗାମୀ ସିଜନ ପାଇଁ ରିହାତି ଦରରେ ଉନ୍ନତ ମାନର ଆଳୁ ବିହନ ବୁକ୍ କରିପାରିବେ। ଆଗୁଆ ବୁକିଂ ଉପରେ ୧୫% ରିହାତି ମିଳିବ।'},
        {'title': 'NCDEX ପ୍ରତ୍ୟାବର୍ତ୍ତନର ସଙ୍କେତ', 'description': 'ନିୟାମକ ଅନୁମୋଦନ ପରେ NCDEX ପ୍ଲାଟଫର୍ମରେ ଆଳୁ ଫ୍ୟୁଚର୍ସ ଟ୍ରେଡିଂ ପୁନର୍ବାର ଆରମ୍ଭ ହେବାକୁ ଯାଉଛି। ବ୍ୟବସାୟୀମାନେ ମୂଲ୍ୟରେ ସ୍ଥିରତା ଆଶା କରୁଛନ୍ତି।'},
        {'title': 'ସରକାର ଆଳୁ ପାଇଁ ନୂତନ MSP ଘୋଷଣା କଲେ', 'description': 'ଏହି ସିଜନରେ ଚାଷୀମାନଙ୍କୁ ଭଲ ଲାଭ ମିଳିବା ପାଇଁ କୃଷି ମନ୍ତ୍ରଣାଳୟ ଆଳୁ ପାଇଁ ସର୍ବନିମ୍ନ ସହାୟକ ମୂଲ୍ୟ ନିର୍ଦ୍ଧାରଣ କରିଛନ୍ତି।'},
        {'title': 'ୟୁପିରେ କୋଲ୍ଡ ଷ୍ଟୋରେଜ୍ କ୍ଷମତା ସମ୍ପ୍ରସାରଣ', 'description': 'ଆଳୁ ଚାଷୀଙ୍କ ପୋଷ୍ଟ-ହାରଭେଷ୍ଟ କ୍ଷତି ହ୍ରାସ କରିବା ପାଇଁ ରାಜ୍ୟ ସରକାର ୫୦ଟି ନୂତନ କୋଲ୍ଡ ଷ୍ଟୋରେଜ୍ ସୁବିଧାକୁ ଅନୁମୋଦନ ଦେଇଛନ୍ତି।'},
        {'title': 'ଡିଜିଟାଲ୍ ମଣ୍ଡି ବ୍ୟବସ୍ଥାର ଶୁଭାରମ୍ଭ', 'description': 'ଚାଷୀମାନେ ବର୍ତ୍ତମାନ ନୂତନ ଡିଜિଟାଲ୍ ମାର୍କେଟପ୍ଲେସ୍ ମାଧ୍ୟମରେ ସିଧାସଳଖ ବ୍ୟବସାୟୀଙ୍କୁ ଉତ୍ପାଦ ବିକ୍ରି କରିପାରିବେ। କୌଣସି ମଧ୍ୟସ୍ଥିଙ୍କ ଆବଶ୍ୟକତା ନାହିଁ।'},
        {'title': 'ଆଗ୍ରା ମଣ୍ଡିରେ ଆଳୁ ଦର ବୃଦ୍ଧି', 'description': 'କୋଲ୍ଡ ଷ୍ଟୋਰੇଜରୁ ଯୋଗାଣ କମିବା ହେତੁ ଆଗ୍ରା ପାଇକାରୀ ବଜାରରେ ଆଳୁ ଦର କିଲୋ ପ୍ରତି ₹୨-୩ ବୃଦ୍ଧି ପାଇଛି।'},
        {'title': 'ୟୁପି ଚାଷୀଙ୍କ ପାଇଁ ନୂତନ ବିହନ କିସମ ଉନ୍ମୋଚିତ', 'description': 'CPRI ଶିମଲା ଉତ୍ତରପ୍ରଦେଶର ସମତଳ ଅଞ୍ଚଳ ପାଇଁ ଉପଯୁକ୍ତ ନୂତନ ଅଧିକ ଅମଳକ୍ଷମ ଆଳୁ କିସମ \'କୁଫ୍ରି ଖ୍ୟାତି\' ଉନ୍ମୋଚନ କରିଛି।'},
        {'title': 'ପିଏମ୍ କିଷାନ ପରବର୍ତ୍ତୀ କିସ୍ତି ତାରିଖ ଘୋଷଣା', 'description': 'ପିଏମ୍ କିଷାନ ସମ୍ମାନ ନିଧିର ୧୯ତମ କିସ୍ତି ଏହି ମାସ ଶେଷ ସୁଦ୍ଧา ଚାଷୀଙ୍କ ଆକାଉଣ୍ଟରେ ଜମା ହେବ।'},
        {'title': 'ଆଳୁ ଚାଷ ଅଞ୍ଚଳ ପାଇଁ ପାଣିପାଗ ସତର୍କତା', 'description': 'ପଶ୍ଚିମ ୟୁପିରେ ଶୀତଳ ଲହରି ବୋହିବା ନେଇ IMD ପୂର୍ବାନୁମାନ କରିଛି। ଆଳୁ ଚାଷକୁ କୁହୁଡିରୁ ରକ୍ଷା କରିବାକୁ ଚାଷୀଙ୍କୁ ପରାਮର୍ଶ ଦିଆଯାଇଛି।'},
        {'title': 'ଭାରତୀୟ ଆଳୁ ପାଇଁ ରପ୍ତାନି ଚାହିଦା ବୃଦ୍ଧି', 'description': 'ନେପାଳ ଏବଂ ବାଂଲାଦେଶ ଭାରତୀୟ ଆଳୁ ପାଇଁ ଆମଦାନୀ ଅର୍ଡର ବୃଦ୍ଧି କରିଛନ୍ତି। ଦର ଚଢା ରହିବା ଆଶା କରାଯାଉଛି।'},
        {'title': 'ଜୈବିକ ଆଳୁ ଚାଷ ପ୍ରଶିକ୍ଷଣ କାର୍ଯ୍ୟକ୍ରਮ', 'description': 'ଜୈବିକ ଆଳୁ ଚାଷ ପାଇଁ ମାଗଣା ପ୍ରଶିକ୍ଷଣ କାର୍ଯ୍ୟକ୍ରମ ଆସନ୍ତା ସପ୍ତାହରୁ ୟୁପିର ବିଭିନ୍ନ KVK କେନ୍ଦ୍ରରେ ଆରମ୍ଭ ହେବ।'},
        {'title': 'କୋଲ୍ଡ ଷ୍ଟୋରେଜ୍ ନିର୍ମାଣ ପାଇଁ ସବସିଡି ଘୋଷଣା', 'description': 'ଛୋଟ କୋଲ୍ଡ ଷ୍ޓୋରେଜ୍ ୟୁନିଟ୍ ନିର୍ମାଣ କରୁଥିବା ଚାଷୀଙ୍କ ପାଇଁ ରାಜ୍ୟ ସରକାର ୫୦% ସବସିଡି ଘୋଷଣା କରିଛନ୍ତି।'}
      ],
      'sources': ['ଆଳୁ ମଣ୍ଡି', 'କୃଷି ନ୍ୟୁଜ୍', 'କିଷାନ ସମାଚାର', 'ଏଗ୍ରି ଟାଇମ୍ସ', 'ମଣ୍ଡି ଭାବ', 'କୃଷି ଜାଗରଣ', 'କିଷାନ ନ୍ୟୁଜ୍', 'ପାଣିପାଗ ସମାଚାର', 'ଟ୍ରେଡ୍ ନ୍ୟୁଜ୍', 'କୃଷି ବିଭାଗ', 'ସରକାରୀ ନ୍ୟୁଜ୍']
    }
  };

  /// Returns curated farming news updated daily
  static List<NewsArticle> _getFarmingNews({String locale = 'en'}) {
    // Get day of year to rotate news daily
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;

    // Use mapped data if available, fallback to 'en'
    final langData = _localizedNewsMap[locale] ?? _localizedNewsMap['en']!;
    final List<dynamic> newsList = langData['news'];
    final List<String> sources = List<String>.from(langData['sources']);

    final List<NewsArticle> allNewsItems = [];
    final List<String> images = [
      'assets/farmaing.png',
      'assets/potato.png',
      'assets/crop_img.png',
      'assets/home.png',
      'assets/popular_mandi.png',
      'assets/alu.png',
      'assets/potato_seed.png',
      'assets/farmaing.png',
      'assets/weather.png',
      'assets/potato.png',
      'assets/leave.png',
      'assets/home.png'
    ];

    for (int i = 0; i < newsList.length; i++) {
      allNewsItems.add(
        NewsArticle(
          title: newsList[i]['title'],
          description: newsList[i]['description'],
          imageUrl: images[i % images.length],
          sourceUrl: '',
          source: sources[i % sources.length],
          publishedAt: DateTime.now().subtract(Duration(hours: i * 2)),
        ),
      );
    }

    // Shuffle based on day to show different news each day
    final random = Random(dayOfYear);
    final shuffled = List<NewsArticle>.from(allNewsItems)..shuffle(random);

    return shuffled.take(8).toList();
  }
}
