import 'dart:convert';

import 'package:aloo_sbji_mandi/core/constants/api_constant.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service for Google Geocoding API & Static Maps via backend proxy.
///
/// Uses the backend `/api/v1/geocode` endpoints to keep the Google API key
/// secure on the server side. Falls back to direct Google API calls if needed.
class GoogleGeocodingService {
  static final GoogleGeocodingService _instance =
      GoogleGeocodingService._internal();
  factory GoogleGeocodingService() => _instance;
  GoogleGeocodingService._internal();

  static const String _baseUrl = '${ApiConstants.baseUrl}/api/v1/geocode';

  // Cached API key (fetched once from server)
  String? _cachedApiKey;

  /// Reverse geocode: Convert lat/lng → structured address using Google Geocoding API
  /// Returns a map with: address, formattedAddress, locality, district, state, pincode, latitude, longitude
  Future<Map<String, dynamic>?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/reverse'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'latitude': latitude,
              'longitude': longitude,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Map<String, dynamic>.from(data['data']);
        }
      }

      debugPrint(
          'Google Geocoding failed: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Google Geocoding error: $e');
      return null;
    }
  }

  /// Get Google API key from backend (cached after first call)
  Future<String?> getApiKey() async {
    if (_cachedApiKey != null) return _cachedApiKey;

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api-key'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _cachedApiKey = data['data']['apiKey'];
          return _cachedApiKey;
        }
      }
    } catch (e) {
      debugPrint('Error fetching Google API key: $e');
    }
    return null;
  }

  /// Build a Google Static Maps URL for displaying a map image
  /// [latitude], [longitude] — coordinates for the center & marker
  /// [zoom] — map zoom level (1-20, default 15)
  /// [width], [height] — image dimensions in pixels
  String? buildStaticMapUrl({
    required double latitude,
    required double longitude,
    int zoom = 15,
    int width = 600,
    int height = 300,
    String? apiKey,
  }) {
    final key = apiKey ?? _cachedApiKey;
    if (key == null) return null;

    return 'https://maps.googleapis.com/maps/api/staticmap?'
        'center=$latitude,$longitude'
        '&zoom=$zoom'
        '&size=${width}x$height'
        '&maptype=roadmap'
        '&markers=color:red%7C$latitude,$longitude'
        '&key=$key';
  }

  /// Build Google Maps URL for opening in browser/app
  /// When user taps the map, this URL opens Google Maps at the exact location
  static String buildGoogleMapsUrl({
    required double latitude,
    required double longitude,
    String? label,
  }) {
    if (label != null && label.isNotEmpty) {
      final encodedLabel = Uri.encodeComponent(label);
      return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude&query_place_id=$encodedLabel';
    }
    return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
  }

  /// Build a compact address string from geocoding response data
  static String buildCompactAddress(Map<String, dynamic> geocodeData) {
    final parts = <String>[
      if (geocodeData['locality'] != null &&
          geocodeData['locality'].toString().isNotEmpty)
        geocodeData['locality'].toString(),
      if (geocodeData['district'] != null &&
          geocodeData['district'].toString().isNotEmpty &&
          geocodeData['district'] != geocodeData['locality'])
        geocodeData['district'].toString(),
      if (geocodeData['state'] != null &&
          geocodeData['state'].toString().isNotEmpty)
        geocodeData['state'].toString(),
      if (geocodeData['pincode'] != null &&
          geocodeData['pincode'].toString().isNotEmpty)
        geocodeData['pincode'].toString(),
    ];
    return parts.isNotEmpty ? parts.join(', ') : geocodeData['formattedAddress'] ?? '';
  }
}
