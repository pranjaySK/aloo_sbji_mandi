import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// ========================================
/// DUMMY PAYMENT GATEWAY FOR TESTING
/// ========================================
/// 
/// Test Card Numbers:
/// ✅ SUCCESS Cards:
///    - 4111 1111 1111 1111 (Visa)
///    - 5555 5555 5555 4444 (Mastercard)
/// 
/// ❌ FAILURE Cards:
///    - 4000 0000 0000 0002 (Card Declined)
///    - 4000 0000 0000 9995 (Insufficient Funds)
/// 
/// UPI:
///    - success@upi, yourname@paytm, test@okaxis → Success
///    - fail@upi → Failure
/// ========================================

class DummyPaymentService {
  static const String _transactionsKey = 'dummy_payment_transactions';

  // Test card configurations
  static const Map<String, _TestCardResult> testCards = {
    '4111111111111111': _TestCardResult(success: true, message: 'Payment successful', cardType: 'Visa'),
    '5555555555554444': _TestCardResult(success: true, message: 'Payment successful', cardType: 'Mastercard'),
    '4000000000000002': _TestCardResult(success: false, message: 'Card declined by bank', cardType: 'Visa'),
    '4000000000009995': _TestCardResult(success: false, message: 'Insufficient funds', cardType: 'Visa'),
  };

  /// Process a dummy payment
  Future<DummyPaymentResponse> processPayment({
    required double amount,
    required String paymentMethod, // 'card', 'upi', 'cod'
    String? cardNumber,
    String? cardExpiry,
    String? cardCvv,
    String? upiId,
    String? description,
  }) async {
    // Simulate network delay (1-3 seconds)
    await Future.delayed(Duration(milliseconds: 1500 + Random().nextInt(1500)));

    String transactionId = _generateTransactionId();
    bool success = false;
    String message = '';
    String? bankRefNumber;

    if (paymentMethod == 'card' && cardNumber != null) {
      // Clean card number
      String cleanCard = cardNumber.replaceAll(' ', '').replaceAll('-', '');
      
      if (testCards.containsKey(cleanCard)) {
        final result = testCards[cleanCard]!;
        success = result.success;
        message = result.message;
      } else if (cleanCard.length == 16) {
        // Random success for unknown valid cards (85% success rate)
        success = Random().nextDouble() > 0.15;
        message = success ? 'Payment successful' : 'Transaction failed. Please try again.';
      } else {
        success = false;
        message = 'Invalid card number';
      }
      
      if (success) {
        bankRefNumber = 'REF${Random().nextInt(999999999).toString().padLeft(9, '0')}';
      }
    } else if (paymentMethod == 'upi' && upiId != null) {
      String cleanUpi = upiId.toLowerCase().trim();
      
      if (cleanUpi.contains('fail')) {
        success = false;
        message = 'UPI transaction failed';
      } else if (cleanUpi.contains('@')) {
        success = true;
        message = 'Payment successful via UPI';
        bankRefNumber = 'UPI${Random().nextInt(999999999).toString().padLeft(9, '0')}';
      } else {
        success = false;
        message = 'Invalid UPI ID format';
      }
    } else if (paymentMethod == 'cod') {
      success = true;
      message = 'Cash on Delivery order confirmed';
    } else {
      success = false;
      message = 'Invalid payment method';
    }

    final response = DummyPaymentResponse(
      transactionId: transactionId,
      success: success,
      message: message,
      amount: amount,
      paymentMethod: paymentMethod,
      timestamp: DateTime.now(),
      description: description,
      bankRefNumber: bankRefNumber,
    );

    // Save transaction history
    await _saveTransaction(response);

    return response;
  }

  String _generateTransactionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = Random().nextInt(999999).toString().padLeft(6, '0');
    return 'PAY$timestamp$randomPart';
  }

  Future<void> _saveTransaction(DummyPaymentResponse response) async {
    final prefs = await SharedPreferences.getInstance();
    final transactions = await getTransactionHistory();
    
    transactions.insert(0, response);
    
    // Keep only last 50 transactions
    if (transactions.length > 50) {
      transactions.removeRange(50, transactions.length);
    }
    
    final jsonList = transactions.map((t) => t.toJson()).toList();
    await prefs.setString(_transactionsKey, jsonEncode(jsonList));
  }

  Future<List<DummyPaymentResponse>> getTransactionHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_transactionsKey);
    
    if (jsonString == null) return [];
    
    final jsonList = jsonDecode(jsonString) as List;
    return jsonList.map((j) => DummyPaymentResponse.fromJson(j)).toList();
  }

  Future<void> clearTransactionHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_transactionsKey);
  }

  /// Get total successful payments
  Future<double> getTotalPayments() async {
    final transactions = await getTransactionHistory();
    double total = 0.0;
    for (final t in transactions) {
      if (t.success) {
        total += t.amount;
      }
    }
    return total;
  }
}

class _TestCardResult {
  final bool success;
  final String message;
  final String cardType;

  const _TestCardResult({
    required this.success,
    required this.message,
    required this.cardType,
  });
}

class DummyPaymentResponse {
  final String transactionId;
  final bool success;
  final String message;
  final double amount;
  final String paymentMethod;
  final DateTime timestamp;
  final String? description;
  final String? bankRefNumber;

  DummyPaymentResponse({
    required this.transactionId,
    required this.success,
    required this.message,
    required this.amount,
    required this.paymentMethod,
    required this.timestamp,
    this.description,
    this.bankRefNumber,
  });

  Map<String, dynamic> toJson() => {
    'transactionId': transactionId,
    'success': success,
    'message': message,
    'amount': amount,
    'paymentMethod': paymentMethod,
    'timestamp': timestamp.toIso8601String(),
    'description': description,
    'bankRefNumber': bankRefNumber,
  };

  factory DummyPaymentResponse.fromJson(Map<String, dynamic> json) => DummyPaymentResponse(
    transactionId: json['transactionId'],
    success: json['success'],
    message: json['message'],
    amount: (json['amount'] as num).toDouble(),
    paymentMethod: json['paymentMethod'],
    timestamp: DateTime.parse(json['timestamp']),
    description: json['description'],
    bankRefNumber: json['bankRefNumber'],
  );
}
