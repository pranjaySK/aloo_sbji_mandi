import 'dart:convert';

import 'package:aloo_sbji_mandi/core/constants/api_constant.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ListingService {
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

  // Get all listings
  Future<Map<String, dynamic>> getAllListings({
    String? type,
    String? variety,
    String? state,
    int limit = 20,
    int page = 1,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'page': page.toString(),
      };
      if (type != null) queryParams['type'] = type;
      if (variety != null) queryParams['variety'] = variety;
      if (state != null) queryParams['state'] = state;

      final uri = Uri.parse(
        '$baseUrl/listings',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri);
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch listings',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get sell listings
  Future<Map<String, dynamic>> getSellListings({
    int limit = 20,
    String? sellerRole,
    String? excludeDistrict,
    String? excludeSeller,
    String? listingType,
    String? variety,
    String? size,
    String? quality,
    String? sourceType,
    int? minPrice,
    int? maxPrice,
    String? state,
    String? district,
    String? sortBy,
  }) async {
    try {
      String url = '$baseUrl/listings/sell?limit=$limit';
      if (sellerRole != null) {
        url += '&sellerRole=$sellerRole';
      }
      if (excludeDistrict != null && excludeDistrict.isNotEmpty) {
        url += '&excludeDistrict=${Uri.encodeComponent(excludeDistrict)}';
      }
      if (excludeSeller != null && excludeSeller.isNotEmpty) {
        url += '&excludeSeller=${Uri.encodeComponent(excludeSeller)}';
      }
      if (listingType != null) {
        url += '&listingType=$listingType';
      }
      if (variety != null && variety.isNotEmpty) {
        url += '&variety=${Uri.encodeComponent(variety)}';
      }
      if (size != null) {
        url += '&size=${Uri.encodeComponent(size)}';
      }
      if (quality != null) {
        url += '&quality=${Uri.encodeComponent(quality)}';
      }
      if (sourceType != null) {
        url += '&sourceType=${Uri.encodeComponent(sourceType)}';
      }
      if (minPrice != null) {
        url += '&minPrice=$minPrice';
      }
      if (maxPrice != null) {
        url += '&maxPrice=$maxPrice';
      }
      if (state != null && state.isNotEmpty) {
        url += '&state=${Uri.encodeComponent(state)}';
      }
      if (district != null && district.isNotEmpty) {
        url += '&district=${Uri.encodeComponent(district)}';
      }
      if (sortBy != null) {
        url += '&sortBy=$sortBy';
      }

      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get buy listings
  Future<Map<String, dynamic>> getBuyListings({
    int limit = 20,
    String? variety,
    String? size,
    String? quality,
    String? sourceType,
    int? minPrice,
    int? maxPrice,
    String? state,
    String? district,
    String? sortBy,
  }) async {
    try {
      String url = '$baseUrl/listings/buy?limit=$limit';
      if (variety != null && variety.isNotEmpty) {
        url += '&variety=${Uri.encodeComponent(variety)}';
      }
      if (size != null) {
        url += '&size=${Uri.encodeComponent(size)}';
      }
      if (quality != null) {
        url += '&quality=${Uri.encodeComponent(quality)}';
      }
      if (sourceType != null) {
        url += '&sourceType=${Uri.encodeComponent(sourceType)}';
      }
      if (minPrice != null) {
        url += '&minPrice=$minPrice';
      }
      if (maxPrice != null) {
        url += '&maxPrice=$maxPrice';
      }
      if (state != null && state.isNotEmpty) {
        url += '&state=${Uri.encodeComponent(state)}';
      }
      if (district != null && district.isNotEmpty) {
        url += '&district=${Uri.encodeComponent(district)}';
      }
      if (sortBy != null) {
        url += '&sortBy=$sortBy';
      }

      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get my listings
  Future<Map<String, dynamic>> getMyListings() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/listings/user/my'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Create listing
  Future<Map<String, dynamic>> createListing({
    required String type,
    required String potatoVariety,
    required int quantity,
    required int pricePerQuintal,
    String? description,
    String? size,
    String? quality,
    Map<String, String>? location,
    String? sourceType,
    String? listingType,
    String? unit,
    int? packetWeight,
    int? expiryHours,
    List<String>? images,
    String? coldStorageId,
    String? coldStorageName,
    Map<String, dynamic>? captureLocation,
    String? contactPhone,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/listings/create'),
        headers: headers,
        body: json.encode({
          'type': type,
          'potatoVariety': potatoVariety,
          'quantity': quantity,
          'pricePerQuintal': pricePerQuintal,
          'description': description,
          'size': size ?? 'Medium',
          'quality': quality ?? 'Good',
          'location': location,
          'sourceType': sourceType ?? 'cold_storage',
          'listingType': listingType ?? 'crop',
          'unit': unit ?? 'Packet',
          if (unit == 'Packet' && packetWeight != null)
            'packetWeight': packetWeight,
          if (expiryHours != null) 'expiryHours': expiryHours,
          if (images != null && images.isNotEmpty) 'images': images,
          if (contactPhone != null && contactPhone.isNotEmpty)
            'contactPhone': contactPhone,
          if (coldStorageId != null && coldStorageId.isNotEmpty)
            'coldStorageId': coldStorageId,
          if (coldStorageName != null && coldStorageName.isNotEmpty)
            'coldStorageName': coldStorageName,
          if (captureLocation != null)
            'captureLocation': captureLocation,
        }),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to create listing',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Update listing
  Future<Map<String, dynamic>> updateListing({
    required String listingId,
    String? potatoVariety,
    int? quantity,
    int? pricePerQuintal,
    String? description,
    String? size,
    bool? isActive,
    String? contactPhone,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{};

      if (potatoVariety != null) body['potatoVariety'] = potatoVariety;
      if (quantity != null) body['quantity'] = quantity;
      if (pricePerQuintal != null) body['pricePerQuintal'] = pricePerQuintal;
      if (description != null) body['description'] = description;
      if (size != null) body['size'] = size;
      if (isActive != null) body['isActive'] = isActive;
      if (contactPhone != null) body['contactPhone'] = contactPhone;

      final response = await http.put(
        Uri.parse('$baseUrl/listings/$listingId'),
        headers: headers,
        body: json.encode(body),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': data['data'],
          'message': 'Listing updated successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update listing',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Delete listing
  Future<Map<String, dynamic>> deleteListing(String listingId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/listings/$listingId'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Listing deleted successfully'};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to delete listing',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Toggle listing active status
  Future<Map<String, dynamic>> toggleListingStatus(String listingId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/listings/$listingId/toggle'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to toggle status',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
}
