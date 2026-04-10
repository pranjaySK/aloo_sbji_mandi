import 'dart:convert';

import 'package:aloo_sbji_mandi/core/constants/api_constant.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ColdStorageService {
  static const String baseUrl = '${ApiConstants.baseUrl}/api/v1';

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

  // Get all cold storages with optional filters
  Future<Map<String, dynamic>> getAllColdStorages({
    String? state,
    String? city,
    String? village,
    String? district,
    String? nearbySearch, // Flexible search in city/village/address
    bool? isAvailable,
    int? minCapacity,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (state != null && state.isNotEmpty) queryParams['state'] = state;
      if (city != null && city.isNotEmpty) queryParams['city'] = city;
      if (village != null && village.isNotEmpty)
        queryParams['village'] = village;
      if (district != null && district.isNotEmpty)
        queryParams['district'] = district;
      if (nearbySearch != null && nearbySearch.isNotEmpty)
        queryParams['nearbySearch'] = nearbySearch;
      if (isAvailable != null)
        queryParams['isAvailable'] = isAvailable.toString();
      if (minCapacity != null)
        queryParams['minCapacity'] = minCapacity.toString();

      final uri = Uri.parse(
        '$baseUrl/cold-storage',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(uri);
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch cold storages',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get cold storage by ID
  Future<Map<String, dynamic>> getColdStorageById(String id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/cold-storage/$id'));
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Cold storage not found',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get my cold storages (for owner)
  Future<Map<String, dynamic>> getMyColdStorages() async {
    try {
      final headers = await _getHeaders();
      print('getMyColdStorages - headers: ${headers.keys.toList()}');
      print(
        'getMyColdStorages - has auth: ${headers.containsKey('Authorization')}',
      );

      final url = '$baseUrl/cold-storage/my';
      print('getMyColdStorages - URL: $url');

      final response = await http.get(Uri.parse(url), headers: headers);

      print('getMyColdStorages - status: ${response.statusCode}');
      print('getMyColdStorages - body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'statusCode': response.statusCode,
          'message':
              data['message'] ??
              'Failed to fetch your cold storages (${response.statusCode})',
        };
      }
    } catch (e) {
      print('getMyColdStorages - error: $e');
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Create cold storage
  Future<Map<String, dynamic>> createColdStorage({
    required String name,
    required String address,
    required String city,
    required String state,
    String? village,
    required String pincode,
    required String phone,
    String? email, // Email is now optional
    required int capacity,
    required double pricePerTon,
    Map<String, dynamic>? captureLocation,
    List<String>? images, // Base64 encoded images
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{
        'name': name,
        'address': address,
        'city': city,
        'state': state,
        'pincode': pincode,
        'phone': phone,
        'capacity': capacity,
        'pricePerTon': pricePerTon,
      };
      if (village != null && village.isNotEmpty) body['village'] = village;
      if (email != null && email.isNotEmpty) body['email'] = email;
      if (captureLocation != null) body['captureLocation'] = captureLocation;
      if (images != null && images.isNotEmpty) body['images'] = images;

      final response = await http.post(
        Uri.parse('$baseUrl/cold-storage/create'),
        headers: headers,
        body: json.encode(body),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to create cold storage',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Update cold storage
  Future<Map<String, dynamic>> updateColdStorage({
    required String id,
    String? name,
    String? address,
    String? city,
    String? state,
    String? village,
    String? pincode,
    String? phone,
    String? email,
    int? capacity,
    int? availableCapacity,
    double? pricePerTon,
    bool? isAvailable,
    Map<String, dynamic>? captureLocation,
    List<String>? images, // Base64 encoded images (new) or existing URLs
  }) async {
    try {
      final headers = await _getHeaders();
      final updates = <String, dynamic>{};

      if (name != null) updates['name'] = name;
      if (address != null) updates['address'] = address;
      if (city != null) updates['city'] = city;
      if (state != null) updates['state'] = state;
      if (village != null) updates['village'] = village;
      if (pincode != null) updates['pincode'] = pincode;
      if (phone != null) updates['phone'] = phone;
      if (email != null) updates['email'] = email;
      if (capacity != null) updates['capacity'] = capacity;
      if (availableCapacity != null)
        updates['availableCapacity'] = availableCapacity;
      if (pricePerTon != null) updates['pricePerTon'] = pricePerTon;
      if (isAvailable != null) updates['isAvailable'] = isAvailable;
      if (captureLocation != null) updates['captureLocation'] = captureLocation;
      if (images != null && images.isNotEmpty) updates['images'] = images;

      final response = await http.put(
        Uri.parse('$baseUrl/cold-storage/$id'),
        headers: headers,
        body: json.encode(updates),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update cold storage',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Toggle availability
  Future<Map<String, dynamic>> toggleAvailability(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/cold-storage/$id/toggle'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to toggle availability',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Delete cold storage
  Future<Map<String, dynamic>> deleteColdStorage(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/cold-storage/$id'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Deleted successfully'};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to delete cold storage',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Add rating to cold storage
  Future<Map<String, dynamic>> addRating({
    required String coldStorageId,
    required int rating,
    String? review,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/cold-storage/$coldStorageId/rating'),
        headers: headers,
        body: json.encode({'rating': rating, 'review': ?review}),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to add rating',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get ratings for cold storage
  Future<Map<String, dynamic>> getRatings(String coldStorageId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/cold-storage/$coldStorageId/ratings'),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch ratings',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ============================================
  // MANAGER MANAGEMENT
  // ============================================

  // Assign manager to cold storage
  Future<Map<String, dynamic>> assignManager({
    required String coldStorageId,
    required String managerPhone,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/cold-storage/$coldStorageId/assign-manager'),
        headers: headers,
        body: json.encode({'managerPhone': managerPhone}),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to assign manager',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Remove manager from cold storage
  Future<Map<String, dynamic>> removeManager(String coldStorageId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/cold-storage/$coldStorageId/remove-manager'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Manager removed successfully'};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to remove manager',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get cold storage assigned to manager
  Future<Map<String, dynamic>> getManagerColdStorage() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/cold-storage/manager/my-storage'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'No cold storage assigned',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
}
