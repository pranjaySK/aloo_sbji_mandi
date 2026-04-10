import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Map<String, String> _emptyLocation() => {
        'village': '',
        'district': '',
        'state': '',
        'pincode': '',
      };

  bool _hasUsefulData(Map<String, String> m) {
    final pin = (m['pincode'] ?? '').trim();
    final st = (m['state'] ?? '').trim();
    return pin.length == 6 || st.isNotEmpty;
  }

  /// Device GPS + reverse geocoding first; falls back to IP lookup.
  Future<Map<String, String>> getLocationData() async {
    // ── Previous behavior (IP only, no GPS) — kept for reference, not used as primary path
    // Map<String, String> locationData = {
    //   'village': '',
    //   'district': '',
    //   'state': '',
    //   'pincode': '',
    // };
    // try {
    //   final ipLocation = await _getLocationFromIP();
    //   if (ipLocation != null) {
    //     locationData = ipLocation;
    //   }
    // } catch (e) {
    //   print('Location service error: $e');
    // }
    // return locationData;

    try {
      final gps = await _getLocationFromGps();
      if (_hasUsefulData(gps)) return gps;
    } catch (e) {
      // ignore — try IP
    }

    try {
      final ipLocation = await _getLocationFromIP();
      if (ipLocation != null) return ipLocation;
    } catch (e) {
      // ignore
    }

    return _emptyLocation();
  }

  /// Reverse geocode current position (when permission granted).
  Future<Map<String, String>> _getLocationFromGps() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return _emptyLocation();
    }

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      return _emptyLocation();
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    final placemarks = await placemarkFromCoordinates(
      pos.latitude,
      pos.longitude,
    );

    if (placemarks.isEmpty) return _emptyLocation();

    final p = placemarks.first;
    var village = '';
    for (final s in [p.locality, p.subLocality, p.name]) {
      if (s != null && s.trim().isNotEmpty) {
        village = s.trim();
        break;
      }
    }

    final district = (p.subAdministrativeArea ?? p.locality ?? '').trim();
    final state = (p.administrativeArea ?? '').trim();
    final pincode = (p.postalCode ?? '').trim();

    return {
      'village': village,
      'district': district,
      'state': state,
      'pincode': pincode,
    };
  }

  /// Get location from IP address (works on web, no permissions needed)
  Future<Map<String, String>?> _getLocationFromIP() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              'http://ip-api.com/json/?fields=city,regionName,country,zip',
            ),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'village': data['city'] ?? '',
          'district': data['city'] ?? '',
          'state': data['regionName'] ?? '',
          'pincode': data['zip'] ?? '',
        };
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  // ── OLD stubs (always false) — replaced with real checks
  // Future<bool> hasLocationPermission() async {
  //   return false;
  // }
  // Future<bool> requestLocationPermission() async {
  //   return false;
  // }

  Future<bool> hasLocationPermission() async {
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.always ||
        p == LocationPermission.whileInUse;
  }

  Future<bool> requestLocationPermission() async {
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    return p == LocationPermission.always ||
        p == LocationPermission.whileInUse;
  }
}
