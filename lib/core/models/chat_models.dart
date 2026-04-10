class ChatUser {
  final String id;
  final String firstName;
  final String lastName;
  final String role;
  final String? phone;
  final String? address;
  bool isOnline;

  ChatUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.phone,
    this.address,
    this.isOnline = false,
  });

  String get fullName {
    // For aloo-mitra users, don't append 'Kisan' as lastName if it's the default
    if (role == 'aloo-mitra' && lastName.toLowerCase() == 'kisan') {
      return firstName;
    }
    return '$firstName $lastName';
  }

  String get roleDisplay {
    switch (role) {
      case 'farmer':
        return 'Farmer';
      case 'trader':
        return 'Vendor/Trader';
      case 'vendor':
        return 'Vendor/Trader';
      case 'cold-storage':
        return 'Cold Storage Owner';
      case 'aloo-mitra':
        return 'Aloo Mitra';
      default:
        return role;
    }
  }

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    return ChatUser(
      id: json['_id'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      role: json['role'] ?? 'farmer',
      phone: json['phone'],
      address: json['address'] is String ? json['address'] : null,
      isOnline: json['isOnline'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'firstName': firstName,
      'lastName': lastName,
      'role': role,
      'phone': phone,
      'address': address,
      'isOnline': isOnline,
    };
  }
}

/// Context details for a conversation linked to a specific entity
class ConversationContext {
  final String contextType;
  final String? contextId;
  final String? title;
  final double? price;
  final double? quantity;
  final String? unit;
  final String? imageUrl;

  ConversationContext({
    required this.contextType,
    this.contextId,
    this.title,
    this.price,
    this.quantity,
    this.unit,
    this.imageUrl,
  });

  factory ConversationContext.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ConversationContext(contextType: 'none');
    }
    return ConversationContext(
      contextType: json['contextType'] ?? 'none',
      contextId: json['contextId'],
      title: json['title'],
      price: json['price']?.toDouble(),
      quantity: json['quantity']?.toDouble(),
      unit: json['unit'],
      imageUrl: json['imageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'contextType': contextType,
      if (contextId != null) 'contextId': contextId,
      if (title != null) 'title': title,
      if (price != null) 'price': price,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (imageUrl != null) 'imageUrl': imageUrl,
    };
  }
}

class Conversation {
  final String id;
  final ChatUser otherUser;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final String type;
  final ConversationContext? context;

  Conversation({
    required this.id,
    required this.otherUser,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.type = 'direct',
    this.context,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    ConversationContext? ctx;
    if (json['contextType'] != null && json['contextType'] != 'none') {
      ctx = ConversationContext(
        contextType: json['contextType'],
        contextId: json['contextId'],
        title: json['contextDetails']?['title'],
        price: json['contextDetails']?['price']?.toDouble(),
        quantity: json['contextDetails']?['quantity']?.toDouble(),
        unit: json['contextDetails']?['unit'],
        imageUrl: json['contextDetails']?['imageUrl'],
      );
    }
    
    return Conversation(
      id: json['_id'] ?? '',
      otherUser: ChatUser.fromJson(json['otherUser'] ?? {}),
      lastMessage: json['lastMessage'],
      lastMessageAt: json['lastMessageAt'] != null 
          ? DateTime.parse(json['lastMessageAt']) 
          : null,
      unreadCount: json['unreadCount'] ?? 0,
      type: json['type'] ?? 'direct',
      context: ctx,
    );
  }
}

class Message {
  final String id;
  final String conversationId;
  final ChatUser sender;
  final String? receiverId;
  final String content;
  final String messageType;
  final bool isRead;
  final String status; // sent, delivered, read
  final DateTime createdAt;
  final DealDetails? dealDetails;

  Message({
    required this.id,
    required this.conversationId,
    required this.sender,
    this.receiverId,
    required this.content,
    this.messageType = 'text',
    this.isRead = false,
    this.status = 'sent',
    required this.createdAt,
    this.dealDetails,
  });

  /// Create from socket event data
  factory Message.fromSocketData(Map<String, dynamic> json) {
    return Message(
      id: json['_id'] ?? '',
      conversationId: json['conversationId'] ?? '',
      sender: json['sender'] is Map 
          ? ChatUser.fromJson(json['sender'])
          : ChatUser(id: json['sender'] ?? '', firstName: '', lastName: '', role: ''),
      receiverId: json['receiver'] is String ? json['receiver'] : json['receiver']?['_id'],
      content: json['content'] ?? '',
      messageType: json['messageType'] ?? 'text',
      isRead: json['isRead'] ?? false,
      status: json['status'] ?? 'sent',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      dealDetails: json['dealDetails'] != null 
          ? DealDetails.fromJson(json['dealDetails']) 
          : null,
    );
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['_id'] ?? '',
      conversationId: json['conversationId'] ?? '',
      sender: ChatUser.fromJson(json['sender'] ?? {}),
      receiverId: json['receiver'] is String ? json['receiver'] : json['receiver']?['_id'],
      content: json['content'] ?? '',
      messageType: json['messageType'] ?? 'text',
      isRead: json['isRead'] ?? false,
      status: json['status'] ?? 'sent',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      dealDetails: json['dealDetails'] != null 
          ? DealDetails.fromJson(json['dealDetails']) 
          : null,
    );
  }

  /// Copy with updated fields
  Message copyWith({
    String? id,
    String? conversationId,
    ChatUser? sender,
    String? receiverId,
    String? content,
    String? messageType,
    bool? isRead,
    String? status,
    DateTime? createdAt,
    DealDetails? dealDetails,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      sender: sender ?? this.sender,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      isRead: isRead ?? this.isRead,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      dealDetails: dealDetails ?? this.dealDetails,
    );
  }
}

class DealDetails {
  final double? quantity;
  final double? pricePerKg;
  final double? totalAmount;
  final int? storageMonths;
  final String? coldStorageId;
  final String? sellerName;
  final String? buyerName;
  final String? listingRefId;

  DealDetails({
    this.quantity,
    this.pricePerKg,
    this.totalAmount,
    this.storageMonths,
    this.coldStorageId,
    this.sellerName,
    this.buyerName,
    this.listingRefId,
  });

  factory DealDetails.fromJson(Map<String, dynamic> json) {
    return DealDetails(
      quantity: json['quantity']?.toDouble(),
      pricePerKg: json['pricePerKg']?.toDouble(),
      totalAmount: json['totalAmount']?.toDouble(),
      storageMonths: json['storageMonths'],
      coldStorageId: json['coldStorageId'],
      sellerName: json['sellerName'],
      buyerName: json['buyerName'],
      listingRefId: json['listingRefId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quantity': quantity,
      'pricePerKg': pricePerKg,
      'totalAmount': totalAmount,
      'storageMonths': storageMonths,
      'coldStorageId': coldStorageId,
      if (sellerName != null) 'sellerName': sellerName,
      if (buyerName != null) 'buyerName': buyerName,
      if (listingRefId != null) 'listingRefId': listingRefId,
    };
  }
}
