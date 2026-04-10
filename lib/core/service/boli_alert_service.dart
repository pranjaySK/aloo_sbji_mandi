import 'dart:convert';

import 'package:aloo_sbji_mandi/core/constants/api_constant.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BoliAlertService {
  static String get baseUrl => '${ApiConstants.baseUrl}/api/v1';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Get all active boli alerts
  Future<Map<String, dynamic>> getAllBoliAlerts({
    String? city,
    String? state,
    bool upcoming = true,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (city != null) queryParams['city'] = city;
      if (state != null) queryParams['state'] = state;
      if (upcoming) queryParams['upcoming'] = 'true';

      final uri = Uri.parse(
        '$baseUrl/boli-alerts',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final headers = await _getHeaders();
      final response = await http.get(uri, headers: headers);
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch boli alerts',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get boli alerts for a specific cold storage
  Future<Map<String, dynamic>> getBoliAlertsByColdStorage(
    String coldStorageId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/boli-alerts/cold-storage/$coldStorageId'),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch boli alerts',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get my boli alerts (for cold storage owner)
  Future<Map<String, dynamic>> getMyBoliAlerts() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/boli-alerts/my'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch your boli alerts',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Create boli alert
  Future<Map<String, dynamic>> createBoliAlert({
    required String coldStorageId,
    String? title,
    String? description,
    int dayOfWeek = 0, // Sunday
    String boliTime = '10:00 AM',
    required String address,
    required String city,
    required String state,
    String? landmark,
    String? googleMapsLink,
    required String contactPerson,
    required String contactPhone,
    double? expectedQuantity,
    double? expectedPriceMin,
    double? expectedPriceMax,
    List<String>? potatoVarieties,
    bool isRecurring = true,
    String? instructions,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = {
        'coldStorageId': coldStorageId,
        'title': title ?? tr('potato_auction'),
        'description': description,
        'dayOfWeek': dayOfWeek,
        'boliTime': boliTime,
        'location': {
          'address': address,
          'city': city,
          'state': state,
          'landmark': landmark,
          'googleMapsLink': googleMapsLink,
        },
        'contactPerson': contactPerson,
        'contactPhone': contactPhone,
        'expectedQuantity': expectedQuantity,
        'expectedPriceMin': expectedPriceMin,
        'expectedPriceMax': expectedPriceMax,
        'potatoVarieties': potatoVarieties,
        'isRecurring': isRecurring,
        'instructions': instructions,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/boli-alerts/create'),
        headers: headers,
        body: json.encode(body),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to create boli alert',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Update boli alert
  Future<Map<String, dynamic>> updateBoliAlert(
    String alertId,
    Map<String, dynamic> updateData,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/boli-alerts/$alertId'),
        headers: headers,
        body: json.encode(updateData),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update boli alert',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Delete boli alert
  Future<Map<String, dynamic>> deleteBoliAlert(String alertId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/boli-alerts/$alertId'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Boli alert deleted successfully'};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to delete boli alert',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Create boli alert from Map (simpler alternative)
  Future<Map<String, dynamic>> createBoliAlertFromMap(
    Map<String, dynamic> data,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/boli-alerts/create'),
        headers: headers,
        body: json.encode(data),
      );
      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'data': responseData['data']};
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to create boli alert',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
}

// Boli Alert Model
class BoliAlert {
  final String id;
  final String? coldStorageId;
  final String? coldStorageName;
  final String title;
  final String? description;
  final int dayOfWeek;
  final String dayName;
  final String dayNameHindi;
  final String boliTime;
  final DateTime nextBoliDate;
  final BoliLocation location;
  final String contactPerson;
  final String contactPhone;
  final double? expectedQuantity;
  final double? expectedPriceMin;
  final double? expectedPriceMax;
  final List<String> potatoVarieties;
  final bool isRecurring;
  final bool isActive;
  final String? instructions;
  final String targetAudience; // 'customers' or 'all'
  final DateTime createdAt;

  BoliAlert({
    required this.id,
    this.coldStorageId,
    this.coldStorageName,
    required this.title,
    this.description,
    required this.dayOfWeek,
    required this.dayName,
    required this.dayNameHindi,
    required this.boliTime,
    required this.nextBoliDate,
    required this.location,
    required this.contactPerson,
    required this.contactPhone,
    this.expectedQuantity,
    this.expectedPriceMin,
    this.expectedPriceMax,
    required this.potatoVarieties,
    required this.isRecurring,
    required this.isActive,
    this.instructions,
    this.targetAudience = 'all',
    required this.createdAt,
  });

  factory BoliAlert.fromJson(Map<String, dynamic> json) {
    final coldStorage = json['coldStorage'];
    return BoliAlert(
      id: json['_id'] ?? '',
      coldStorageId: coldStorage is Map ? coldStorage['_id'] : coldStorage,
      coldStorageName: coldStorage is Map ? coldStorage['name'] : null,
      title: json['title'] ?? tr('potato_boli'),
      description: json['description'],
      dayOfWeek: json['dayOfWeek'] ?? 0,
      dayName: json['dayName'] ?? _getDayName(json['dayOfWeek'] ?? 0),
      dayNameHindi:
          json['dayNameHindi'] ?? _getDayNameHindi(json['dayOfWeek'] ?? 0),
      boliTime: json['boliTime'] ?? '10:00 AM',
      nextBoliDate: DateTime.parse(
        json['nextBoliDate'] ?? DateTime.now().toIso8601String(),
      ),
      location: BoliLocation.fromJson(json['location'] ?? {}),
      contactPerson: json['contactPerson'] ?? '',
      contactPhone: json['contactPhone'] ?? '',
      expectedQuantity: json['expectedQuantity']?.toDouble(),
      expectedPriceMin: json['expectedPriceMin']?.toDouble(),
      expectedPriceMax: json['expectedPriceMax']?.toDouble(),
      potatoVarieties: List<String>.from(json['potatoVarieties'] ?? []),
      isRecurring: json['isRecurring'] ?? true,
      isActive: json['isActive'] ?? true,
      instructions: json['instructions'],
      targetAudience: json['targetAudience'] ?? 'all',
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  static String _getDayName(int day) {
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    return days[day];
  }

  static String _getDayNameHindi(int day) {
    const dayKeys = [
      'day_sunday',
      'day_monday',
      'day_tuesday',
      'day_wednesday',
      'day_thursday',
      'day_friday',
      'day_saturday',
    ];
    return tr(dayKeys[day]);
  }

  /// Returns boliTime with AM/PM (handles both "10:00" and "10:00 AM" formats)
  String get boliTimeFormatted {
    // If already has AM/PM, return as-is
    final upper = boliTime.toUpperCase().trim();
    if (upper.contains('AM') || upper.contains('PM')) return boliTime;
    // Parse HH:mm and convert to 12h format
    final parts = boliTime.split(':');
    if (parts.length < 2) return boliTime;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${h12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $amPm';
  }

  // Check if boli is today
  bool get isToday {
    final now = DateTime.now();
    return nextBoliDate.year == now.year &&
        nextBoliDate.month == now.month &&
        nextBoliDate.day == now.day;
  }

  // Check if boli is tomorrow
  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return nextBoliDate.year == tomorrow.year &&
        nextBoliDate.month == tomorrow.month &&
        nextBoliDate.day == tomorrow.day;
  }

  // Get days until boli
  int get daysUntil {
    final now = DateTime.now();
    return nextBoliDate
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
  }
}

class BoliLocation {
  final String address;
  final String city;
  final String? district;
  final String state;
  final String? landmark;
  final String? googleMapsLink;

  BoliLocation({
    required this.address,
    required this.city,
    this.district,
    required this.state,
    this.landmark,
    this.googleMapsLink,
  });

  factory BoliLocation.fromJson(Map<String, dynamic> json) {
    return BoliLocation(
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      district: json['district'],
      state: json['state'] ?? '',
      landmark: json['landmark'],
      googleMapsLink: json['googleMapsLink'],
    );
  }

  String get fullAddress => '$address, $city, $state';
}
