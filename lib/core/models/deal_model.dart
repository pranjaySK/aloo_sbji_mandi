import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';

class Deal {
  final String id;
  final String conversationId;
  final String? bookingId;
  final DealUser farmer;
  final DealUser coldStorageOwner;
  final String? coldStorageId;
  final String? listingId;
  final String dealType; // 'cold-storage' or 'listing'
  final double quantity;
  final double pricePerTon;
  final double totalAmount;
  final int duration;
  final String proposedBy;
  final String status;
  final bool farmerConfirmed;
  final bool ownerConfirmed;
  final DateTime? farmerConfirmedAt;
  final DateTime? ownerConfirmedAt;
  final String? notes;
  final String? dealMessageId;
  // Payment fields
  final String
  paymentStatus; // 'pending', 'requested', 'paid', 'failed', 'refunded'
  final DateTime? paymentRequestedAt;
  final String? paymentRequestedBy;
  final String? paymentId;
  final String? paymentOrderId;
  final DateTime? paidAt;
  final String? paymentMethod;
  // Payment confirmation fields
  final bool payerConfirmed;
  final bool receiverConfirmed;
  final DateTime? payerConfirmedAt;
  final DateTime? receiverConfirmedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Deal({
    required this.id,
    required this.conversationId,
    this.bookingId,
    required this.farmer,
    required this.coldStorageOwner,
    this.coldStorageId,
    this.listingId,
    this.dealType = 'cold-storage',
    required this.quantity,
    required this.pricePerTon,
    required this.totalAmount,
    required this.duration,
    required this.proposedBy,
    required this.status,
    required this.farmerConfirmed,
    required this.ownerConfirmed,
    this.farmerConfirmedAt,
    this.ownerConfirmedAt,
    this.notes,
    this.dealMessageId,
    this.paymentStatus = 'pending',
    this.paymentRequestedAt,
    this.paymentRequestedBy,
    this.paymentId,
    this.paymentOrderId,
    this.paidAt,
    this.paymentMethod,
    this.payerConfirmed = false,
    this.receiverConfirmed = false,
    this.payerConfirmedAt,
    this.receiverConfirmedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Deal.fromJson(Map<String, dynamic> json) {
    return Deal(
      id: json['_id'] ?? '',
      conversationId: json['conversationId'] is Map
          ? json['conversationId']['_id']
          : json['conversationId'] ?? '',
      bookingId: json['bookingId'] is Map
          ? json['bookingId']['_id']
          : json['bookingId'],
      farmer: DealUser.fromJson(json['farmer'] ?? {}),
      coldStorageOwner: DealUser.fromJson(
        json['coldStorageOwner'] ?? json['vendor'] ?? {},
      ),
      coldStorageId: json['coldStorage'] is Map
          ? json['coldStorage']['_id']
          : json['coldStorage'],
      listingId: json['listingId'] is Map
          ? json['listingId']['_id']
          : json['listingId'],
      dealType: json['dealType'] ?? 'cold-storage',
      quantity: (json['quantity'] ?? 0).toDouble(),
      pricePerTon: (json['pricePerTon'] ?? 0).toDouble(),
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      duration: json['duration'] ?? 1,
      proposedBy: json['proposedBy'] is Map
          ? json['proposedBy']['_id']
          : json['proposedBy'] ?? '',
      status: json['status'] ?? 'proposed',
      farmerConfirmed: json['farmerConfirmed'] ?? false,
      ownerConfirmed:
          json['ownerConfirmed'] ?? json['vendorConfirmed'] ?? false,
      farmerConfirmedAt: json['farmerConfirmedAt'] != null
          ? DateTime.parse(json['farmerConfirmedAt'])
          : null,
      ownerConfirmedAt: json['ownerConfirmedAt'] != null
          ? DateTime.parse(json['ownerConfirmedAt'])
          : null,
      notes: json['notes'],
      dealMessageId: json['dealMessageId'] is Map
          ? json['dealMessageId']['_id']
          : json['dealMessageId'],
      paymentStatus: json['paymentStatus'] ?? 'pending',
      paymentRequestedAt: json['paymentRequestedAt'] != null
          ? DateTime.parse(json['paymentRequestedAt'])
          : null,
      paymentRequestedBy: json['paymentRequestedBy'] is Map
          ? json['paymentRequestedBy']['_id']
          : json['paymentRequestedBy'],
      paymentId: json['paymentId'],
      paymentOrderId: json['paymentOrderId'],
      paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt']) : null,
      paymentMethod: json['paymentMethod'],
      payerConfirmed: json['payerConfirmed'] ?? false,
      receiverConfirmed: json['receiverConfirmed'] ?? false,
      payerConfirmedAt: json['payerConfirmedAt'] != null
          ? DateTime.parse(json['payerConfirmedAt'])
          : null,
      receiverConfirmedAt: json['receiverConfirmedAt'] != null
          ? DateTime.parse(json['receiverConfirmedAt'])
          : null,
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  bool get isClosed => status == 'closed';
  bool get isCancelled => status == 'cancelled';
  bool get isPending =>
      status == 'proposed' ||
      status == 'farmer_confirmed' ||
      status == 'owner_confirmed';
  bool get isPaid => paymentStatus == 'paid';
  bool get isPaymentRequested => paymentStatus == 'requested';
  bool get isListingDeal => dealType == 'listing';
  bool get isPaymentComplete => payerConfirmed && receiverConfirmed;

  String getStatusText() {
    switch (status) {
      case 'proposed':
        return tr('status_proposed');
      case 'farmer_confirmed':
        return tr('status_farmer_confirmed');
      case 'owner_confirmed':
        return tr('status_owner_confirmed');
      case 'closed':
        return tr('status_deal_closed');
      case 'cancelled':
        return tr('status_cancelled');
      default:
        return status;
    }
  }
}

class DealUser {
  final String id;
  final String firstName;
  final String lastName;
  final String? phone;

  DealUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.phone,
  });

  factory DealUser.fromJson(Map<String, dynamic> json) {
    return DealUser(
      id: json['_id'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      phone: json['phone'],
    );
  }

  String get fullName => '$firstName $lastName';
}
