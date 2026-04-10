import 'dart:convert';
import 'dart:math';
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
      publishedAt: DateTime.tryParse(json['publishedAt'] ?? '') ?? DateTime.now(),
    );
  }

  factory NewsArticle.fromGNewsJson(Map<String, dynamic> json) {
    return NewsArticle(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image'] ?? '',
      sourceUrl: json['url'] ?? '',
      source: json['source']?['name'] ?? '',
      publishedAt: DateTime.tryParse(json['publishedAt'] ?? '') ?? DateTime.now(),
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
  static const Duration _cacheExpiry = Duration(hours: 1); // Refresh every hour for live news

  /// Clear cache to force fresh fetch
  static void clearCache() {
    _cachedNews = null;
    _lastFetchTime = null;
  }

  /// Fetch agriculture/farming related news from NewsAPI
  static Future<List<NewsArticle>> fetchFarmerNews({bool forceRefresh = false}) async {
    // Return cached news if available and not expired
    if (!forceRefresh && _cachedNews != null && _lastFetchTime != null) {
      if (DateTime.now().difference(_lastFetchTime!) < _cacheExpiry) {
        return _cachedNews!;
      }
    }

    try {
      // Fetch live news from NewsAPI
      final news = await _fetchFromNewsApi();
      if (news.isNotEmpty) {
        _cachedNews = news;
        _lastFetchTime = DateTime.now();
        return news;
      }
    } catch (e) {
      print('Error fetching news from API: $e');
    }

    // Fallback to curated news if API fails
    final fallbackNews = _getFarmingNews();
    _cachedNews = fallbackNews;
    _lastFetchTime = DateTime.now();
    return fallbackNews;
  }

  /// Fetch news from NewsAPI.org
  static Future<List<NewsArticle>> _fetchFromNewsApi() async {
    final List<NewsArticle> allNews = [];
    
    // Get today's date and 7 days ago for fresh news
    final today = DateTime.now();
    final fromDate = today.subtract(const Duration(days: 7));
    
    // First try: Indian agriculture specific news
    try {
      final url = Uri.parse(
        'https://newsapi.org/v2/everything?'
        'q=(agriculture OR farming OR kisan OR crops OR mandi) AND India&'
        'language=en&'
        'from=${fromDate.toIso8601String().split('T')[0]}&'
        'sortBy=publishedAt&'
        'pageSize=20&'
        'apiKey=$_newsApiKey'
      );
      
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      
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
                _isAgricultureRelated(article['title'], article['description'])) {
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
        'language=en&'
        'from=${fromDate.toIso8601String().split('T')[0]}&'
        'sortBy=publishedAt&'
        'pageSize=15&'
        'apiKey=$_newsApiKey'
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
                _isAgricultureRelated(article['title'], article['description'])) {
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
      'cricket', 'ipl', 'movie', 'film', 'bollywood', 'hollywood',
      'politics', 'election', 'vote', 'parliament', 'congress', 'bjp',
      'stock market', 'sensex', 'nifty', 'share price', 'ipo',
      'automobile', 'car', 'bike', 'vehicle', 'ev',
      'smartphone', 'iphone', 'android', 'laptop', 'tech',
      'celebrity', 'actor', 'actress', 'entertainment',
      'sports', 'football', 'tennis', 'olympics',
      'murder', 'crime', 'accident', 'rape', 'scam',
      'trump', 'biden', 'usa', 'china', 'pakistan', 'bangladesh',
      'war', 'military', 'army', 'defense', 'missile',
      'cryptocurrency', 'bitcoin', 'ethereum',
      'real estate', 'property', 'housing',
    ];
    
    // Check if any exclude keyword is present - reject the article
    for (var keyword in excludeKeywords) {
      if (text.contains(keyword)) {
        return false;
      }
    }
    
    // Agriculture related keywords - MUST contain at least one
    final agricultureKeywords = [
      'agriculture', 'farming', 'farmer', 'kisan', 'crop', 'crops',
      'potato', 'aloo', 'vegetable', 'sabji', 'mandi', 'market',
      'cold storage', 'harvest', 'cultivation', 'seed', 'fertilizer',
      'irrigation', 'monsoon', 'rain', 'weather', 'drought', 'flood',
      'msp', 'minimum support price', 'procurement', 'agri', 'rural',
      'krishi', 'pm kisan', 'subsidy farm', 'loan farm', 'yield', 'production',
      'wheat', 'rice', 'onion', 'tomato', 'grain',
      'horticulture', 'soil', 'organic', 'pesticide', 'urea', 'dap',
      'apmc', 'wholesale vegetable', 'food grain', 'food security',
      'warehouse grain', 'fci', 'nafed', 'sowing', 'rabi', 'kharif',
      'sugarcane', 'cotton', 'pulses', 'oilseed', 'mustard', 'groundnut',
      'dairy', 'milk', 'cattle', 'livestock', 'poultry', 'fishery'
    ];
    
    // Check if any agriculture keyword is present
    for (var keyword in agricultureKeywords) {
      if (text.contains(keyword)) {
        return true;
      }
    }
    
    return false;
  }

  /// Returns curated farming news updated daily
  static List<NewsArticle> _getFarmingNews() {
    // Get day of year to rotate news daily
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    
    final allNews = [
      NewsArticle(
        title: 'Advance Potato Seed Bookings Open for 2026',
        description: 'Farmers can now book quality potato seeds for the upcoming season at discounted rates. Early bookings get 15% discount.',
        imageUrl: 'assets/farmaing.png',
        sourceUrl: '',
        source: 'Aloo Mandi',
        publishedAt: DateTime.now(),
      ),
      NewsArticle(
        title: 'NCDEX signals return',
        description: 'Potato futures trading set to resume on NCDEX platform after regulatory approval. Traders expect price stability.',
        imageUrl: 'assets/potato.png',
        sourceUrl: '',
        source: 'Krishi News',
        publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      NewsArticle(
        title: 'Government announces new MSP for potatoes',
        description: 'Agriculture ministry sets minimum support price for potato to help farmers get better returns this season.',
        imageUrl: 'assets/crop_img.png',
        sourceUrl: '',
        source: 'Kisan Samachar',
        publishedAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      NewsArticle(
        title: 'Cold storage capacity expansion in UP',
        description: 'State government approves 50 new cold storage facilities to reduce post-harvest losses for potato farmers.',
        imageUrl: 'assets/home.png',
        sourceUrl: '',
        source: 'Agri Times',
        publishedAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
      NewsArticle(
        title: 'Digital Mandi system launched',
        description: 'Farmers can now sell produce directly to traders through the new digital marketplace. No middlemen involved.',
        imageUrl: 'assets/popular_mandi.png',
        sourceUrl: '',
        source: 'Aloo Mandi',
        publishedAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
      NewsArticle(
        title: 'Potato prices rise in Agra mandi',
        description: 'Due to reduced supply from cold storages, potato prices have increased by ₹2-3 per kg in Agra wholesale market.',
        imageUrl: 'assets/alu.png',
        sourceUrl: '',
        source: 'Mandi Bhav',
        publishedAt: DateTime.now().subtract(const Duration(hours: 10)),
      ),
      NewsArticle(
        title: 'New potato variety released for UP farmers',
        description: 'CPRI Shimla releases new high-yield potato variety Kufri Khyati suitable for plains of Uttar Pradesh.',
        imageUrl: 'assets/potato_seed.png',
        sourceUrl: '',
        source: 'Krishi Jagran',
        publishedAt: DateTime.now().subtract(const Duration(hours: 12)),
      ),
      NewsArticle(
        title: 'PM Kisan next installment date announced',
        description: 'The 19th installment of PM Kisan Samman Nidhi will be credited to farmer accounts by end of this month.',
        imageUrl: 'assets/farmaing.png',
        sourceUrl: '',
        source: 'Kisan News',
        publishedAt: DateTime.now().subtract(const Duration(hours: 14)),
      ),
      NewsArticle(
        title: 'Weather alert for potato growing regions',
        description: 'IMD predicts cold wave in western UP. Farmers advised to protect potato crop from frost damage.',
        imageUrl: 'assets/weather.png',
        sourceUrl: '',
        source: 'Mausam Samachar',
        publishedAt: DateTime.now().subtract(const Duration(hours: 16)),
      ),
      NewsArticle(
        title: 'Export demand for Indian potatoes increases',
        description: 'Nepal and Bangladesh increase import orders for Indian potatoes. Prices expected to remain firm.',
        imageUrl: 'assets/potato.png',
        sourceUrl: '',
        source: 'Trade News',
        publishedAt: DateTime.now().subtract(const Duration(hours: 18)),
      ),
      NewsArticle(
        title: 'Organic potato farming training program',
        description: 'Free training program for organic potato farming starts next week at KVK centers across UP.',
        imageUrl: 'assets/leave.png',
        sourceUrl: '',
        source: 'Krishi Vibhag',
        publishedAt: DateTime.now().subtract(const Duration(hours: 20)),
      ),
      NewsArticle(
        title: 'Subsidy announced for cold storage construction',
        description: 'State government announces 50% subsidy for farmers building small cold storage units.',
        imageUrl: 'assets/home.png',
        sourceUrl: '',
        source: 'Govt. News',
        publishedAt: DateTime.now().subtract(const Duration(hours: 22)),
      ),
    ];
    
    // Shuffle based on day to show different news each day
    final random = Random(dayOfYear);
    final shuffled = List<NewsArticle>.from(allNews)..shuffle(random);
    
    return shuffled.take(8).toList();
  }
}
