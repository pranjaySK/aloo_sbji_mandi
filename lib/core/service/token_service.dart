import 'dart:convert';

import 'package:aloo_sbji_mandi/core/constants/api_constant.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TokenService {
  static const String baseUrl = '${ApiConstants.baseUrl}/api/v1/tokens';
  static const String counterBaseUrl = '${ApiConstants.baseUrl}/api/v1/counters';

  /// Static method to get access token for use in other services
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

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

  // ==================== FARMER METHODS ====================

  /// Request a token for a cold storage
  /// If [counterId] is provided, the token is auto-issued directly into queue (no approval needed)
  /// Otherwise, creates a pending request that needs owner approval
  Future<Map<String, dynamic>> requestToken({
    required String coldStorageId,
    String purpose = 'storage',
    double? expectedQuantity,
    String? potatoVariety,
    String unit = 'Packet',
    String? counterId,
    String? remark,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = {
        'coldStorageId': coldStorageId,
        'purpose': purpose,
        'expectedQuantity': ?expectedQuantity,
        'potatoVariety': ?potatoVariety,
        'unit': unit,
        'counterId': ?counterId,
        'remark': ?remark,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/request'),
        headers: headers,
        body: json.encode(body),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to request token',
          'data': data['data'],
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Get my tokens for today
  Future<Map<String, dynamic>> getMyTokens() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/my-tokens'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch tokens',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Get specific token status
  Future<Map<String, dynamic>> getTokenStatus(String tokenId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/status/$tokenId'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch token status',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Cancel my token
  Future<Map<String, dynamic>> cancelMyToken(String tokenId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/cancel/$tokenId'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to cancel token',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Update my pending token request
  Future<Map<String, dynamic>> updateMyToken({
    required String tokenId,
    String? purpose,
    double? expectedQuantity,
    String? unit,
    String? remark,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{};
      if (purpose != null) body['purpose'] = purpose;
      if (expectedQuantity != null) body['expectedQuantity'] = expectedQuantity;
      if (unit != null) body['unit'] = unit;
      if (remark != null) body['remark'] = remark;

      final response = await http.patch(
        Uri.parse('$baseUrl/update/$tokenId'),
        headers: headers,
        body: json.encode(body),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data'], 'message': data['message']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update token',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Delete my pending token request
  Future<Map<String, dynamic>> deleteMyToken(String tokenId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/delete/$tokenId'),
        headers: headers,
      );

      // Guard against non-JSON responses (e.g. HTML error pages from proxy)
      Map<String, dynamic> data;
      try {
        data = json.decode(response.body);
      } catch (_) {
        return {
          'success': false,
          'message': 'Server error (${response.statusCode}). Please try again.',
        };
      }

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to delete token',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Get public queue info (no auth needed)
  Future<Map<String, dynamic>> getQueueInfo(String coldStorageId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/queue-info/$coldStorageId'),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch queue info',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ==================== COLD STORAGE OWNER METHODS ====================

  /// Issue token to a farmer (with optional counter assignment)
  Future<Map<String, dynamic>> issueToken({
    required String coldStorageId,
    String? farmerId,
    required String farmerName,
    required String farmerPhone,
    String purpose = 'storage',
    double? expectedQuantity,
    String? potatoVariety,
    String? notes,
    String? counterId,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = {
        'farmerId': ?farmerId,
        'farmerName': farmerName,
        'farmerPhone': farmerPhone,
        'purpose': purpose,
        'expectedQuantity': ?expectedQuantity,
        'potatoVariety': ?potatoVariety,
        'notes': ?notes,
        'counterId': ?counterId,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/issue/$coldStorageId'),
        headers: headers,
        body: json.encode(body),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to issue token',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Get token queue for a cold storage
  Future<Map<String, dynamic>> getTokenQueue(
    String coldStorageId, {
    String? status,
    DateTime? date,
  }) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{};
      if (status != null) queryParams['status'] = status;
      if (date != null)
        queryParams['date'] = date.toIso8601String().split('T')[0];

      final uri = Uri.parse(
        '$baseUrl/queue/$coldStorageId',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(uri, headers: headers);
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch queue',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Call next token (per-counter)
  Future<Map<String, dynamic>> callNextToken(
    String coldStorageId, {
    String? counterId,
    int counterNumber = 1,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{
        'counterNumber': counterNumber,
      };
      if (counterId != null) body['counterId'] = counterId;
      final response = await http.post(
        Uri.parse('$baseUrl/call-next/$coldStorageId'),
        headers: headers,
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
          'message': data['message'] ?? 'Failed to call next token',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Start serving a token
  Future<Map<String, dynamic>> startServing(String tokenId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/start-service/$tokenId'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to start service',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Complete a token
  Future<Map<String, dynamic>> completeToken(
    String tokenId, {
    String? notes,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/complete/$tokenId'),
        headers: headers,
        body: json.encode({'notes': notes}),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to complete token',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Skip a token
  Future<Map<String, dynamic>> skipToken(
    String tokenId, {
    String? reason,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/skip/$tokenId'),
        headers: headers,
        body: json.encode({'reason': reason}),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to skip token',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Re-queue a skipped token
  Future<Map<String, dynamic>> requeueToken(String tokenId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/requeue/$tokenId'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to re-queue token',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Approve a pending token request (owner) with optional counter assignment
  Future<Map<String, dynamic>> approveTokenRequest(
    String tokenId, {
    String? counterId,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{};
      if (counterId != null) body['counterId'] = counterId;
      final response = await http.patch(
        Uri.parse('$baseUrl/approve/$tokenId'),
        headers: headers,
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
          'message': data['message'] ?? 'Failed to approve token',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Reject a pending token request (owner)
  Future<Map<String, dynamic>> rejectTokenRequest(
    String tokenId, {
    String? reason,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/reject/$tokenId'),
        headers: headers,
        body: json.encode({'reason': reason}),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to reject token',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
  // ==================== TRANSFER METHODS ====================

  /// Transfer a token to a different counter
  Future<Map<String, dynamic>> transferToken(
    String tokenId, {
    required String targetCounterId,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/transfer/$tokenId'),
        headers: headers,
        body: json.encode({'targetCounterId': targetCounterId}),
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
          'message': data['message'] ?? 'Failed to transfer token',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ==================== COUNTER MANAGEMENT METHODS ====================

  /// Get all counters for a cold storage
  Future<Map<String, dynamic>> getCounters(String coldStorageId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$counterBaseUrl/$coldStorageId'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch counters',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Create a new counter
  Future<Map<String, dynamic>> createCounter(
    String coldStorageId, {
    String? name,
    int? averageServiceTime,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (averageServiceTime != null) body['averageServiceTime'] = averageServiceTime;

      final response = await http.post(
        Uri.parse('$counterBaseUrl/$coldStorageId'),
        headers: headers,
        body: json.encode(body),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to create counter',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Update a counter
  Future<Map<String, dynamic>> updateCounter(
    String counterId, {
    String? name,
    int? averageServiceTime,
    bool? isActive,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (averageServiceTime != null) body['averageServiceTime'] = averageServiceTime;
      if (isActive != null) body['isActive'] = isActive;

      final response = await http.put(
        Uri.parse('$counterBaseUrl/update/$counterId'),
        headers: headers,
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
          'message': data['message'] ?? 'Failed to update counter',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Delete a counter
  Future<Map<String, dynamic>> deleteCounter(String counterId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$counterBaseUrl/delete/$counterId'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to delete counter',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Setup default counters (create N counters)
  Future<Map<String, dynamic>> setupDefaultCounters(
    String coldStorageId, {
    int count = 1,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$counterBaseUrl/$coldStorageId/setup-default'),
        headers: headers,
        body: json.encode({'count': count}),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to setup counters',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
}

// Counter Model
class CounterInfo {
  final String id;
  final int number;
  final String name;
  final int averageServiceTime;
  final bool isActive;
  final int currentQueueLength;
  final String? activeTokenId;

  CounterInfo({
    required this.id,
    required this.number,
    required this.name,
    required this.averageServiceTime,
    required this.isActive,
    required this.currentQueueLength,
    this.activeTokenId,
  });

  factory CounterInfo.fromJson(Map<String, dynamic> json) {
    return CounterInfo(
      id: json['_id'] ?? '',
      number: json['number'] ?? 1,
      name: json['name'] ?? 'Counter 1',
      averageServiceTime: json['averageServiceTime'] ?? 10,
      isActive: json['isActive'] ?? true,
      currentQueueLength: json['currentQueueLength'] ?? 0,
      activeTokenId: json['activeTokenId'],
    );
  }
}

// Token Model
class QueueToken {
  final String id;
  final String tokenNumber;
  final int sequenceNumber;
  final String coldStorageId;
  final String? coldStorageName;
  final String? coldStorageAddress;
  final String farmerId;
  final String farmerName;
  final String farmerPhone;
  final String purpose;
  final double? expectedQuantity;
  final String unit;
  final String? potatoVariety;
  final String status;
  final DateTime tokenDate;
  final DateTime issuedAt;
  final DateTime? calledAt;
  final DateTime? serviceStartedAt;
  final DateTime? completedAt;
  final int estimatedWaitMinutes;
  final int counterNumber;
  final String? counterId;
  final String? counterName;
  final int? positionInQueue;
  final DateTime? estimatedStartTime;
  final String? notes;
  final String? remark;
  final int? position;
  final String? currentlyServing;

  QueueToken({
    required this.id,
    required this.tokenNumber,
    required this.sequenceNumber,
    required this.coldStorageId,
    this.coldStorageName,
    this.coldStorageAddress,
    required this.farmerId,
    required this.farmerName,
    required this.farmerPhone,
    required this.purpose,
    this.expectedQuantity,
    this.unit = 'Packet',
    this.potatoVariety,
    required this.status,
    required this.tokenDate,
    required this.issuedAt,
    this.calledAt,
    this.serviceStartedAt,
    this.completedAt,
    required this.estimatedWaitMinutes,
    required this.counterNumber,
    this.counterId,
    this.counterName,
    this.positionInQueue,
    this.estimatedStartTime,
    this.notes,
    this.remark,
    this.position,
    this.currentlyServing,
  });

  factory QueueToken.fromJson(Map<String, dynamic> json) {
    final coldStorage = json['coldStorage'];
    return QueueToken(
      id: json['_id'] ?? '',
      tokenNumber: json['tokenNumber'] ?? '',
      sequenceNumber: json['sequenceNumber'] ?? 0,
      coldStorageId: coldStorage is Map
          ? coldStorage['_id']
          : (coldStorage ?? ''),
      coldStorageName: coldStorage is Map ? coldStorage['name'] : null,
      coldStorageAddress: coldStorage is Map ? coldStorage['address'] : null,
      farmerId: json['farmer'] is Map
          ? json['farmer']['_id']
          : (json['farmer'] ?? ''),
      farmerName: json['farmerName'] ?? '',
      farmerPhone: json['farmerPhone'] ?? '',
      purpose: json['purpose'] ?? 'storage',
      expectedQuantity: json['expectedQuantity']?.toDouble(),
      unit: json['unit'] ?? 'Packet',
      potatoVariety: json['potatoVariety'],
      status: json['status'] ?? 'waiting',
      tokenDate: DateTime.parse(
        json['tokenDate'] ?? DateTime.now().toIso8601String(),
      ),
      issuedAt: DateTime.parse(
        json['issuedAt'] ?? DateTime.now().toIso8601String(),
      ),
      calledAt: json['calledAt'] != null
          ? DateTime.parse(json['calledAt'])
          : null,
      serviceStartedAt: json['serviceStartedAt'] != null
          ? DateTime.parse(json['serviceStartedAt'])
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      estimatedWaitMinutes: json['estimatedWaitMinutes'] ?? 0,
      counterNumber: json['counterNumber'] ?? 1,
      counterId: json['counter'] is Map
          ? json['counter']['_id']
          : json['counter'],
      counterName: json['counterName'] ??
          (json['counter'] is Map ? json['counter']['name'] : null),
      positionInQueue: json['positionInQueue'],
      estimatedStartTime: json['estimatedStartTime'] != null
          ? DateTime.parse(json['estimatedStartTime'])
          : null,
      notes: json['notes'],
      remark: json['remark'],
      position: json['position'] ?? json['positionInQueue'],
      currentlyServing: json['currentlyServing'],
    );
  }

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return tr('status_pending');
      case 'waiting':
        return tr('status_waiting');
      case 'called':
        return tr('status_called');
      case 'in-service':
        return tr('status_in_service');
      case 'completed':
        return tr('status_completed');
      case 'skipped':
        return tr('status_skipped');
      case 'cancelled':
        return tr('status_cancelled');
      case 'rejected':
        return tr('status_rejected');
      default:
        return status;
    }
  }

  /// @deprecated Use [statusDisplay] instead — it now returns the localized string.
  String get statusDisplayHindi => statusDisplay;

  String get purposeDisplay {
    switch (purpose) {
      case 'storage':
        return tr('purpose_storage');
      case 'withdrawal':
        return tr('purpose_withdrawal');
      case 'inspection':
        return tr('purpose_inspection');
      default:
        return purpose;
    }
  }

  /// @deprecated Use [purposeDisplay] instead — it now returns the localized string.
  String get purposeDisplayHindi => purposeDisplay;

  bool get isActive =>
      ['pending', 'waiting', 'called', 'in-service'].contains(status);
  bool get isPending => status == 'pending';
  bool get isWaiting => status == 'waiting';
  bool get isCalled => status == 'called';
  bool get isInService => status == 'in-service';
  bool get isCompleted => status == 'completed';
  bool get isRejected => status == 'rejected';
}

class QueueStats {
  final int total;
  final int pending;
  final int waiting;
  final int called;
  final int inService;
  final int completed;
  final int skipped;
  final int cancelled;
  final int rejected;

  QueueStats({
    required this.total,
    required this.pending,
    required this.waiting,
    required this.called,
    required this.inService,
    required this.completed,
    required this.skipped,
    required this.cancelled,
    required this.rejected,
  });

  factory QueueStats.fromJson(Map<String, dynamic> json) {
    return QueueStats(
      total: json['total'] ?? 0,
      pending: json['pending'] ?? 0,
      waiting: json['waiting'] ?? 0,
      called: json['called'] ?? 0,
      inService: json['inService'] ?? 0,
      completed: json['completed'] ?? 0,
      skipped: json['skipped'] ?? 0,
      cancelled: json['cancelled'] ?? 0,
      rejected: json['rejected'] ?? 0,
    );
  }
}
