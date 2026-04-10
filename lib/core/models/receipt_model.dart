class Receipt {
  final String id;
  final String receiptNumber;
  final String dealId;
  final String dealType;
  final ReceiptUser farmer;
  final ReceiptPayer payer;
  final ReceiptDealDetails dealDetails;
  final ReceiptPaymentDetails paymentDetails;
  final String status;
  final bool viewedByFarmer;
  final bool viewedByPayer;
  final String? notes;
  final String termsAndConditions;
  final DateTime createdAt;
  final DateTime updatedAt;

  Receipt({
    required this.id,
    required this.receiptNumber,
    required this.dealId,
    required this.dealType,
    required this.farmer,
    required this.payer,
    required this.dealDetails,
    required this.paymentDetails,
    required this.status,
    required this.viewedByFarmer,
    required this.viewedByPayer,
    this.notes,
    required this.termsAndConditions,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Receipt.fromJson(Map<String, dynamic> json) {
    return Receipt(
      id: json['_id'] ?? '',
      receiptNumber: json['receiptNumber'] ?? '',
      dealId: json['dealId'] is Map ? json['dealId']['_id'] : json['dealId'] ?? '',
      dealType: json['dealType'] ?? 'cold-storage',
      farmer: ReceiptUser.fromJson(json['farmer'] ?? {}),
      payer: ReceiptPayer.fromJson(json['payer'] ?? {}),
      dealDetails: ReceiptDealDetails.fromJson(json['dealDetails'] ?? {}),
      paymentDetails: ReceiptPaymentDetails.fromJson(json['paymentDetails'] ?? {}),
      status: json['status'] ?? 'generated',
      viewedByFarmer: json['viewedByFarmer'] ?? false,
      viewedByPayer: json['viewedByPayer'] ?? false,
      notes: json['notes'],
      termsAndConditions: json['termsAndConditions'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  bool get isListingDeal => dealType == 'listing';
}

class ReceiptUser {
  final String id;
  final String name;
  final String? phone;

  ReceiptUser({
    required this.id,
    required this.name,
    this.phone,
  });

  factory ReceiptUser.fromJson(Map<String, dynamic> json) {
    return ReceiptUser(
      id: json['userId'] is Map ? json['userId']['_id'] : json['userId'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'],
    );
  }
}

class ReceiptPayer {
  final String id;
  final String name;
  final String? phone;
  final String role;

  ReceiptPayer({
    required this.id,
    required this.name,
    this.phone,
    required this.role,
  });

  factory ReceiptPayer.fromJson(Map<String, dynamic> json) {
    return ReceiptPayer(
      id: json['userId'] is Map ? json['userId']['_id'] : json['userId'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'],
      role: json['role'] ?? 'vendor',
    );
  }

  String get roleDisplayName {
    switch (role) {
      case 'cold-storage-owner':
        return 'Cold Storage Owner';
      case 'vendor':
        return 'Vendor';
      default:
        return role;
    }
  }
}

class ReceiptDealDetails {
  final double quantity;
  final String unit;
  final double pricePerUnit;
  final int? duration;
  final String? listingTitle;

  ReceiptDealDetails({
    required this.quantity,
    required this.unit,
    required this.pricePerUnit,
    this.duration,
    this.listingTitle,
  });

  factory ReceiptDealDetails.fromJson(Map<String, dynamic> json) {
    return ReceiptDealDetails(
      quantity: (json['quantity'] ?? 0).toDouble(),
      unit: json['unit'] ?? 'packets',
      pricePerUnit: (json['pricePerUnit'] ?? 0).toDouble(),
      duration: json['duration'],
      listingTitle: json['listingTitle'],
    );
  }
}

class ReceiptPaymentDetails {
  final double subtotal;
  final double taxes;
  final double totalAmount;
  final String paymentMethod;
  final String? paymentId;
  final String? paymentOrderId;
  final DateTime? paidAt;

  ReceiptPaymentDetails({
    required this.subtotal,
    required this.taxes,
    required this.totalAmount,
    required this.paymentMethod,
    this.paymentId,
    this.paymentOrderId,
    this.paidAt,
  });

  factory ReceiptPaymentDetails.fromJson(Map<String, dynamic> json) {
    return ReceiptPaymentDetails(
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      taxes: (json['taxes'] ?? 0).toDouble(),
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      paymentMethod: json['paymentMethod'] ?? 'razorpay',
      paymentId: json['paymentId'],
      paymentOrderId: json['paymentOrderId'],
      paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt']) : null,
    );
  }

  String get paymentMethodDisplayName {
    switch (paymentMethod) {
      case 'razorpay':
        return 'Razorpay';
      case 'stripe':
        return 'Stripe';
      case 'upi':
        return 'UPI';
      case 'cash':
        return 'Cash';
      case 'bank_transfer':
        return 'Bank Transfer';
      default:
        return paymentMethod;
    }
  }
}
