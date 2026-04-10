import 'dart:convert';

import 'package:aloo_sbji_mandi/core/constants/api_constant.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FeedbackService {
  static const String baseUrl = '${ApiConstants.baseUrl}/api';

  /// Submit feedback to backend and store locally
  Future<Map<String, dynamic>> submitFeedback({
    required String message,
    String? userId,
    String? userName,
    String? userRole,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      // Get user info if not provided
      userId ??= prefs.getString('userId') ?? 'anonymous';
      userName ??= prefs.getString('userName') ?? 'Anonymous User';
      userRole ??= prefs.getString('userRole') ?? 'user';

      final feedbackData = {
        'userId': userId,
        'userName': userName,
        'userRole': userRole,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'pending', // pending, reviewed, resolved
      };

      // Try to send to backend
      try {
        final response = await http
            .post(
              Uri.parse('$baseUrl/feedback'),
              headers: {
                'Content-Type': 'application/json',
                if (token != null) 'Authorization': 'Bearer $token',
              },
              body: jsonEncode(feedbackData),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200 || response.statusCode == 201) {
          return {
            'success': true,
            'message': 'Feedback submitted successfully',
          };
        }
      } catch (e) {
        // If backend fails, store locally
        print('Backend unavailable, storing locally: $e');
      }

      // Store locally as fallback
      await _storeLocalFeedback(feedbackData);
      return {'success': true, 'message': 'Feedback saved locally'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to submit feedback: $e'};
    }
  }

  /// Store feedback locally when backend is unavailable
  Future<void> _storeLocalFeedback(Map<String, dynamic> feedback) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> feedbackList = prefs.getStringList('local_feedbacks') ?? [];
    feedbackList.add(jsonEncode(feedback));
    await prefs.setStringList('local_feedbacks', feedbackList);
  }

  /// Get all feedbacks (for admin panel)
  Future<Map<String, dynamic>> getAllFeedbacks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      // Try to get from backend first
      try {
        final response = await http
            .get(
              Uri.parse('$baseUrl/feedback'),
              headers: {
                'Content-Type': 'application/json',
                if (token != null) 'Authorization': 'Bearer $token',
              },
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return {
            'success': true,
            'feedbacks': data['feedbacks'] ?? data['data'] ?? [],
          };
        }
      } catch (e) {
        print('Backend unavailable for fetching feedbacks: $e');
      }

      // Return local feedbacks as fallback
      final localFeedbacks = await _getLocalFeedbacks();
      return {'success': true, 'feedbacks': localFeedbacks, 'isLocal': true};
    } catch (e) {
      return {'success': false, 'feedbacks': [], 'message': 'Error: $e'};
    }
  }

  /// Get locally stored feedbacks
  Future<List<Map<String, dynamic>>> _getLocalFeedbacks() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> feedbackList = prefs.getStringList('local_feedbacks') ?? [];
    return feedbackList
        .map((f) => jsonDecode(f) as Map<String, dynamic>)
        .toList();
  }

  /// Update feedback status (for admin)
  Future<Map<String, dynamic>> updateFeedbackStatus(
    String feedbackId,
    String status,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http
          .put(
            Uri.parse('$baseUrl/feedback/$feedbackId'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'status': status}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Status updated'};
      }
      return {'success': false, 'message': 'Failed to update status'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Delete feedback (for admin)
  Future<Map<String, dynamic>> deleteFeedback(String feedbackId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http
          .delete(
            Uri.parse('$baseUrl/feedback/$feedbackId'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Feedback deleted'};
      }
      return {'success': false, 'message': 'Failed to delete'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Get feedback count (for admin dashboard)
  Future<int> getFeedbackCount() async {
    final result = await getAllFeedbacks();
    if (result['success']) {
      return (result['feedbacks'] as List).length;
    }
    return 0;
  }

  /// Add sample feedbacks for testing
  Future<void> addSampleFeedbacks() async {
    final samples = [
      {
        'userId': 'user1',
        'userName': tr('sample_farmer_name'),
        'userRole': 'farmer',
        'message': tr('sample_farmer_feedback'),
        'timestamp': DateTime.now()
            .subtract(const Duration(hours: 2))
            .toIso8601String(),
        'status': 'pending',
      },
      {
        'userId': 'user2',
        'userName': 'Trader Singh',
        'userRole': 'trader',
        'message':
            'Please add more mandis in the list. App is helpful for business.',
        'timestamp': DateTime.now()
            .subtract(const Duration(hours: 5))
            .toIso8601String(),
        'status': 'pending',
      },
      {
        'userId': 'user3',
        'userName': tr('sample_cold_storage_user'),
        'userRole': 'cold-storage',
        'message': tr('sample_cold_storage_feedback'),
        'timestamp': DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String(),
        'status': 'reviewed',
      },
    ];

    for (var sample in samples) {
      await _storeLocalFeedback(sample);
    }
  }
}
