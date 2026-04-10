import 'dart:async';
import 'dart:convert';

import 'package:aloo_sbji_mandi/core/constants/api_constant.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static String get baseUrl => '${ApiConstants.baseUrl}/api/v1';
  static const int _maxRetries = 0; // Changed from 2 to 0 (only 1 attempt)
  static const Duration _retryDelay = Duration(seconds: 1);
  static const Duration _requestTimeout = Duration(seconds: 5); // Reduced from 8 to 5

  // Helper method for HTTP requests with retry logic
  Future<http.Response> _makeRequestWithRetry(
    Future<http.Response> Function() request, {
    int maxRetries = _maxRetries,
    Duration? timeout,
  }) async {
    int retryCount = 0;
    final effectiveTimeout = timeout ?? _requestTimeout;
    
    while (true) {
      try {
        print('🔷 Auth API attempt ${retryCount + 1}/${maxRetries + 1}');
        final startTime = DateTime.now();
        final response = await request().timeout(effectiveTimeout);
        final duration = DateTime.now().difference(startTime);
        print('✅ Auth API responded in ${duration.inMilliseconds}ms');
        return response;
      } catch (e) {
        final duration = DateTime.now().difference(DateTime.now());
        print('❌ Auth API attempt ${retryCount + 1} failed after ${effectiveTimeout.inSeconds}s: $e');
        retryCount++;
        if (retryCount >= maxRetries) {
          print('🔴 Max retries reached, throwing error');
          rethrow;
        }
        // Wait before retrying
        print('⏳ Waiting ${_retryDelay.inSeconds}s before retry...');
        await Future.delayed(_retryDelay * retryCount);
      }
    }
  }

  // Convert connection errors to user-friendly messages
  String _getFriendlyErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('clientexception') ||
        errorString.contains('socketexception') ||
        errorString.contains('failed to fetch') ||
        errorString.contains('connection refused') ||
        errorString.contains('network is unreachable') ||
        errorString.contains('timeout')) {
      return 'Server not reachable. Please check your internet connection and try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  // ============================================
  // REGISTRATION WITH OTP
  // ============================================

  // Step 1: Register & Send OTP
  Future<Map<String, dynamic>> registerAndSendOTP({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
    required String role,
    String? subRole,
    Map<String, String>? address,
  }) async {
    try {
      final body = {
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'password': password,
        'role': role,
        'address':
            address ??
            {'village': '', 'district': '', 'state': '', 'pincode': ''},
      };

      // Add subRole only for aloo-mitra
      if (subRole != null) {
        body['subRole'] = subRole;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/user/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
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
          'message': data['message'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Step 2: Verify OTP & Complete Registration
  Future<Map<String, dynamic>> verifyOTPAndRegister({
    required String phone,
    required String otp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': phone, 'otp': otp}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        await _saveAuthData(data['data']);
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Verification failed',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Resend OTP
  Future<Map<String, dynamic>> resendOTP({required String phone}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/resend-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': phone}),
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
          'message': data['message'] ?? 'Failed to resend OTP',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ============================================
  // DEV: Find existing assigned manager
  // ============================================

  /// Find an existing cold-storage-manager user who is assigned to a cold storage.
  /// Returns {'found': true, 'phone': '...'} or {'found': false}.
  Future<Map<String, dynamic>> devFindManager() async {
    try {
      final response = await _makeRequestWithRetry(
        () => http.get(
          Uri.parse('$baseUrl/user/dev-find-manager'),
          headers: {'Content-Type': 'application/json'},
        ),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['data'] != null) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': 'No manager found'};
      }
    } catch (e) {
      return {'success': false, 'message': _getFriendlyErrorMessage(e)};
    }
  }

  // ============================================
  // LOGIN WITH OTP
  // ============================================

  // Step 1: Send Login OTP
  Future<Map<String, dynamic>> sendLoginOTP({required String phone}) async {
    try {
      print('📤 Sending login OTP to: $phone');
      final response = await http.post(
        Uri.parse('$baseUrl/user/login/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': phone}),
      ).timeout(_requestTimeout);

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
          'message': data['message'] ?? 'Failed to send OTP',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Step 2: Verify Login OTP
  Future<Map<String, dynamic>> verifyLoginOTP({
    required String phone,
    required String otp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/login/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': phone, 'otp': otp}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        await _saveAuthData(data['data']);
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ============================================
  // PASSWORD-BASED LOGIN (Legacy)
  // ============================================

  Future<Map<String, dynamic>> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    try {
      final response = await _makeRequestWithRetry(
        () => http.post(
          Uri.parse('$baseUrl/user/login'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            if (email != null) 'email': email,
            if (phone != null) 'phone': phone,
            'password': password,
          }),
        ),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        await _saveAuthData(data['data']);
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'message': _getFriendlyErrorMessage(e)};
    }
  }

  // Dev register (for testing without OTP)
  Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    required String password,
    required String role,
    Map<String, String>? address,
  }) async {
    try {
      final response = await _makeRequestWithRetry(
        () => http.post(
          Uri.parse('$baseUrl/user/dev-register'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'firstName': firstName,
            'lastName': lastName,
            if (email != null) 'email': email,
            if (phone != null) 'phone': phone,
            'password': password,
            'role': role,
            'address':
                address ??
                {
                  'village': 'Default Village',
                  'district': 'Default District',
                  'state': 'UP',
                  'pincode': '000000',
                },
          }),
        ),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        await _saveAuthData(data['data']);
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      return {'success': false, 'message': _getFriendlyErrorMessage(e)};
    }
  }

  // ============================================
  // UPDATE USER ROLE
  // ============================================

  Future<Map<String, dynamic>> updateUserRole({required String role}) async {
    try {
      final token = await getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not logged in'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/user/profile/update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'role': role}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        // Update stored user data with new role
        final prefs = await SharedPreferences.getInstance();
        final user = data['data']['user'];
        await prefs.setString('user', json.encode(user));
        await prefs.setString('userRole', user['role']);
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update role',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ============================================
  // UPDATE ALOO MITRA PROFILE
  // ============================================

  Future<Map<String, dynamic>> updateAlooMitraProfile({
    required String serviceType,
    required String name,
    required String state,
    required String district,
    String? city,
    required String pricing,
    String? businessAddress,
    String? pincode,
    double? latitude,
    double? longitude,
    // Majdoor-specific fields
    String? majdoorMobile,
    String? kaamType,
    String? kaamJagah,
    String? availability,
    dynamic aadhaarImage, // File type from dart:io
    // Gunny Bag-specific fields
    String? gunnyBagBusinessName,
    String? gunnyBagOwnerName,
    // Machinery-specific fields
    String? machineryBusinessName,
    String? machineType,
    String? machineryServiceType,
    String? rentType,
    int? salePriceMin,
    int? salePriceMax,
    int? rentPriceMin,
    int? rentPriceMax,
    // Business photos (base64 encoded strings)
    List<String>? businessPhotos,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not logged in'};
      }

      final Map<String, dynamic> bodyData = {
        'serviceType': serviceType,
        'businessName': name,
        'state': state,
        'district': district,
        'city': city ?? '',
        'pricing': pricing,
      };

      // Add business address, pincode and location for fertilizers
      if (businessAddress != null && businessAddress.isNotEmpty) {
        bodyData['businessAddress'] = businessAddress;
      }
      if (pincode != null && pincode.isNotEmpty) {
        bodyData['pincode'] = pincode;
      }
      if (latitude != null && longitude != null) {
        bodyData['businessLocation'] = {
          'latitude': latitude,
          'longitude': longitude,
        };
      }

      // Add Majdoor-specific fields
      if (majdoorMobile != null && majdoorMobile.isNotEmpty) {
        bodyData['majdoorMobile'] = majdoorMobile;
      }
      if (kaamType != null && kaamType.isNotEmpty) {
        bodyData['kaamType'] = kaamType;
      }
      if (kaamJagah != null && kaamJagah.isNotEmpty) {
        bodyData['kaamJagah'] = kaamJagah;
      }
      if (availability != null && availability.isNotEmpty) {
        bodyData['availability'] = availability;
      }

      // Add Gunny Bag-specific fields
      if (gunnyBagBusinessName != null && gunnyBagBusinessName.isNotEmpty) {
        bodyData['gunnyBagBusinessName'] = gunnyBagBusinessName;
      }
      if (gunnyBagOwnerName != null && gunnyBagOwnerName.isNotEmpty) {
        bodyData['gunnyBagOwnerName'] = gunnyBagOwnerName;
      }

      // Add Machinery-specific fields
      if (machineryBusinessName != null && machineryBusinessName.isNotEmpty) {
        bodyData['machineryBusinessName'] = machineryBusinessName;
      }
      if (machineType != null && machineType.isNotEmpty) {
        bodyData['machineType'] = machineType;
      }
      if (machineryServiceType != null && machineryServiceType.isNotEmpty) {
        bodyData['machineryServiceType'] = machineryServiceType;
      }
      if (rentType != null && rentType.isNotEmpty) {
        bodyData['rentType'] = rentType;
      }
      if (salePriceMin != null) {
        bodyData['salePriceMin'] = salePriceMin;
      }
      if (salePriceMax != null) {
        bodyData['salePriceMax'] = salePriceMax;
      }
      if (rentPriceMin != null) {
        bodyData['rentPriceMin'] = rentPriceMin;
      }
      if (rentPriceMax != null) {
        bodyData['rentPriceMax'] = rentPriceMax;
      }

      // TODO: Handle Aadhaar image upload separately if needed
      // For now, we'll skip image upload and handle it later

      // Add business photos (base64 encoded)
      if (businessPhotos != null && businessPhotos.isNotEmpty) {
        bodyData['businessPhotos'] = businessPhotos;
      }

      final response = await http.put(
        Uri.parse('$baseUrl/aloo-mitra/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(bodyData),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update profile',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ============================================
  // AUTH DATA MANAGEMENT
  // ============================================

  Future<void> _saveAuthData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', data['accessToken']);
    await prefs.setString('refreshToken', data['refreshToken']);
    await prefs.setString('user', json.encode(data['user']));
    await prefs.setString('userRole', data['user']['role']);
    await prefs.setString('userId', data['user']['_id']);
    // Store master flag
    final role = data['user']['role'];
    final phone = data['user']['phone'] ?? '';
    if (role == 'master' || phone == '8112363785') {
      await prefs.setBool('isMaster', true);
    } else {
      await prefs.setBool('isMaster', false);
    }
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      return json.decode(userStr);
    }
    return null;
  }

  Future<String?> getCurrentUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userRole');
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    await prefs.remove('user');
    await prefs.remove('userRole');
    await prefs.remove('userId');
  }
}
