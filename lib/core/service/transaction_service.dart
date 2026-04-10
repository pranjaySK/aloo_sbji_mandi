import 'dart:convert';
import 'package:aloo_sbji_mandi/core/constants/api_constant.dart';
import 'package:aloo_sbji_mandi/core/service/token_service.dart';
import 'package:http/http.dart' as http;

class TransactionService {
  static String get baseUrl => '${ApiConstants.baseUrl}/api/v1/transactions';

  // Get user's transaction history
  static Future<Map<String, dynamic>> getTransactionHistory({
    int page = 1,
    int limit = 20,
    String? status,
    String? type,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final token = await TokenService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      String url = '$baseUrl?page=$page&limit=$limit';
      if (status != null) url += '&status=$status';
      if (type != null) url += '&type=$type';
      if (startDate != null) url += '&startDate=$startDate';
      if (endDate != null) url += '&endDate=$endDate';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      print('Get transaction history error: $e');
      return {'success': false, 'message': 'Failed to fetch transactions: $e'};
    }
  }

  // Get transaction by ID
  static Future<Map<String, dynamic>> getTransactionById(String transactionId) async {
    try {
      final token = await TokenService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/$transactionId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      print('Get transaction error: $e');
      return {'success': false, 'message': 'Failed to fetch transaction: $e'};
    }
  }

  // Create a new transaction
  static Future<Map<String, dynamic>> createTransaction({
    required String type,
    required double amount,
    required String paymentMethod,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final token = await TokenService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'type': type,
          'amount': amount,
          'paymentMethod': paymentMethod,
          'description': description,
          'metadata': metadata,
        }),
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      print('Create transaction error: $e');
      return {'success': false, 'message': 'Failed to create transaction: $e'};
    }
  }

  // Get transaction stats
  static Future<Map<String, dynamic>> getTransactionStats() async {
    try {
      final token = await TokenService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/stats'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      print('Get transaction stats error: $e');
      return {'success': false, 'message': 'Failed to fetch stats: $e'};
    }
  }
}

// Transaction model
class TransactionModel {
  final String id;
  final String transactionId;
  final String type;
  final double amount;
  final String currency;
  final String status;
  final String paymentMethod;
  final String? description;
  final DateTime createdAt;
  final String? failureReason;
  final Map<String, dynamic>? metadata;

  TransactionModel({
    required this.id,
    required this.transactionId,
    required this.type,
    required this.amount,
    required this.currency,
    required this.status,
    required this.paymentMethod,
    this.description,
    required this.createdAt,
    this.failureReason,
    this.metadata,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['_id'] ?? '',
      transactionId: json['transactionId'] ?? '',
      type: json['type'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'INR',
      status: json['status'] ?? 'pending',
      paymentMethod: json['paymentMethod'] ?? '',
      description: json['description'],
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      failureReason: json['failureReason'],
      metadata: json['metadata'],
    );
  }

  String get statusDisplay {
    switch (status) {
      case 'success':
        return 'Successful';
      case 'failed':
        return 'Failed';
      case 'pending':
        return 'Pending';
      case 'cancelled':
        return 'Cancelled';
      case 'refunded':
        return 'Refunded';
      default:
        return status;
    }
  }

  String get typeDisplay {
    switch (type) {
      case 'payment':
        return 'Payment';
      case 'refund':
        return 'Refund';
      case 'withdrawal':
        return 'Withdrawal';
      case 'deposit':
        return 'Deposit';
      case 'subscription':
        return 'Subscription';
      case 'purchase':
        return 'Purchase';
      default:
        return type;
    }
  }
}
