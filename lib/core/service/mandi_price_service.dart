import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service to fetch live mandi (market) prices from data.gov.in API
/// API: Variety-wise Daily Market Prices Data of Commodity
class MandiPriceService {
  static const String _apiKey =
      '579b464db66ec23bdd000001cdd3946e44ce4aad7209ff7b23ac571b';
  static const String _baseUrl =
      'https://api.data.gov.in/resource/35985678-0d79-46b4-9ed6-6f13308a1d24';

  /// Fetch potato mandi prices for a given state, district, and optional date.
  ///
  /// [state]    – Indian state name (e.g. "Rajasthan")
  /// [district] – District name     (e.g. "Jaipur") — optional
  /// [date]     – Optional DateTime; when null the API returns all dates
  ///              (sorted most‑recent first by default).
  /// [limit]    – Max records to fetch (default 50).
  ///
  /// Returns a map:
  /// ```
  /// {
  ///   'total': int,
  ///   'records': [ { Market, Variety, Grade, Arrival_Date,
  ///                   Min_Price, Max_Price, Modal_Price, … }, … ]
  /// }
  /// ```
  Future<Map<String, dynamic>> fetchMandiPrices({
    required String state,
    String? district,
    DateTime? date,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, String>{
        'api-key': _apiKey,
        'format': 'json',
        'offset': offset.toString(),
        'limit': limit.toString(),
        'filters[State]': state,
        'filters[Commodity]': 'Potato',
      };

      if (district != null && district.isNotEmpty) {
        queryParams['filters[District]'] = district;
      }

      if (date != null) {
        // API expects dd/MM/yyyy
        final dateStr =
            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
        queryParams['filters[Arrival_Date]'] = dateStr;
      }

      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> rawRecords = data['records'] ?? [];
        final int total = data['total'] ?? 0;

        // Normalise prices to per‑kg (API returns per quintal = 100 kg)
        final records = rawRecords.map<Map<String, dynamic>>((r) {
          final minPrice = _toDouble(r['Min_Price']);
          final maxPrice = _toDouble(r['Max_Price']);
          final modalPrice = _toDouble(r['Modal_Price']);

          return {
            'market': r['Market'] ?? '',
            'district': r['District'] ?? '',
            'state': r['State'] ?? '',
            'variety': r['Variety'] ?? '',
            'grade': r['Grade'] ?? '',
            'arrivalDate': r['Arrival_Date'] ?? '',
            'minPriceQuintal': minPrice,
            'maxPriceQuintal': maxPrice,
            'modalPriceQuintal': modalPrice,
            'minPriceKg': (minPrice / 100),
            'maxPriceKg': (maxPrice / 100),
            'modalPriceKg': (modalPrice / 100),
          };
        }).toList();

        return {
          'total': total,
          'records': records,
        };
      } else {
        print('Mandi Price API error: ${response.statusCode}');
        return {'total': 0, 'records': <Map<String, dynamic>>[]};
      }
    } catch (e) {
      print('Error fetching mandi prices: $e');
      return {'total': 0, 'records': <Map<String, dynamic>>[]};
    }
  }

  /// Fetch prices trying today, then yesterday, then day‑before to find the
  /// most recent available data.  Falls back to no‑date query (all dates).
  Future<Map<String, dynamic>> fetchLatestPrices({
    required String state,
    String? district,
    int limit = 50,
  }) async {
    // Try the last 7 days, one by one
    for (int i = 0; i < 7; i++) {
      final day = DateTime.now().subtract(Duration(days: i));
      final result = await fetchMandiPrices(
        state: state,
        district: district,
        date: day,
        limit: limit,
      );
      if ((result['records'] as List).isNotEmpty) {
        result['fetchedDate'] = day;
        return result;
      }
    }

    // If no data in last 7 days, fetch without date filter (latest available)
    final result = await fetchMandiPrices(
      state: state,
      district: district,
      limit: limit,
    );
    return result;
  }

  /// Fetch all unique mandis (markets) for a state.
  /// Returns list of maps: { 'market': name, 'district': district, 'modalPriceQuintal': price, 'arrivalDate': date }
  Future<List<Map<String, dynamic>>> fetchMandisForState({
    required String state,
  }) async {
    final result = await fetchLatestPrices(
      state: state,
      limit: 500,
    );
    final records = result['records'] as List<Map<String, dynamic>>;

    // Deduplicate by market name, keeping the record with highest modal price
    final marketMap = <String, Map<String, dynamic>>{};
    for (final r in records) {
      final market = r['market'] as String;
      if (!marketMap.containsKey(market) ||
          (r['modalPriceQuintal'] as double) >
              (marketMap[market]!['modalPriceQuintal'] as double)) {
        marketMap[market] = r;
      }
    }
    return marketMap.values.toList()
      ..sort((a, b) =>
          (a['market'] as String).compareTo(b['market'] as String));
  }

  /// Fetch price history for a specific market over the past N days.
  /// Iterates day-by-day to collect data from multiple dates.
  /// Returns a list of { 'date': DateTime, 'modalPriceQuintal': double, ... }
  /// sorted by date ascending.
  Future<List<Map<String, dynamic>>> fetchPriceHistory({
    required String state,
    required String market,
    String? district,
    int days = 6,
  }) async {
    final history = <Map<String, dynamic>>[];
    final seenDates = <String>{};

    // Iterate day-by-day over past N days to collect multi-date data
    for (int i = 0; i < days; i++) {
      final day = DateTime.now().subtract(Duration(days: i));
      final result = await fetchMandiPrices(
        state: state,
        district: district,
        date: day,
        limit: 200,
      );
      final records = result['records'] as List<Map<String, dynamic>>;

      // Filter records for the specific market
      final marketRecords =
          records.where((r) => r['market'] == market).toList();
      if (marketRecords.isEmpty) continue;

      final dateStr = marketRecords.first['arrivalDate'] as String;
      if (seenDates.contains(dateStr)) continue;
      seenDates.add(dateStr);

      // Compute average modal price for this date
      double avgModal = 0;
      double minPrice = double.infinity;
      double maxPrice = 0;
      for (final r in marketRecords) {
        avgModal += r['modalPriceQuintal'] as double;
        final mn = r['minPriceQuintal'] as double;
        final mx = r['maxPriceQuintal'] as double;
        if (mn < minPrice) minPrice = mn;
        if (mx > maxPrice) maxPrice = mx;
      }
      avgModal /= marketRecords.length;
      if (minPrice == double.infinity) minPrice = 0;

      history.add({
        'dateStr': dateStr,
        'date': day,
        'modalPriceQuintal': avgModal,
        'minPriceQuintal': minPrice,
        'maxPriceQuintal': maxPrice,
      });
    }

    // Sort by date ascending
    history.sort((a, b) {
      final da = a['date'] as DateTime?;
      final db = b['date'] as DateTime?;
      if (da == null || db == null) return 0;
      return da.compareTo(db);
    });

    return history;
  }

  /// Parse a dynamic value to double safely.
  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  /// Group records by market name.
  /// Returns map: { "Market Name" : [ record1, record2, ... ] }
  static Map<String, List<Map<String, dynamic>>> groupByMarket(
      List<Map<String, dynamic>> records) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final r in records) {
      final market = r['market'] as String;
      grouped.putIfAbsent(market, () => []);
      grouped[market]!.add(r);
    }
    return grouped;
  }
}
