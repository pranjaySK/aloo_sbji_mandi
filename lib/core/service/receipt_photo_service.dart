import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Model for a captured receipt photo
class ReceiptPhoto {
  final String id;
  final String imagePath; // Local path or base64 for web
  final String? title;
  final String? description;
  final double? amount;
  final String? vendor; // Who you sold to or bought from
  final String? transactionType; // 'sale' or 'purchase'
  final DateTime capturedAt;
  final String? notes;

  ReceiptPhoto({
    required this.id,
    required this.imagePath,
    this.title,
    this.description,
    this.amount,
    this.vendor,
    this.transactionType,
    required this.capturedAt,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'imagePath': imagePath,
    'title': title,
    'description': description,
    'amount': amount,
    'vendor': vendor,
    'transactionType': transactionType,
    'capturedAt': capturedAt.toIso8601String(),
    'notes': notes,
  };

  factory ReceiptPhoto.fromJson(Map<String, dynamic> json) => ReceiptPhoto(
    id: json['id'],
    imagePath: json['imagePath'],
    title: json['title'],
    description: json['description'],
    amount: json['amount']?.toDouble(),
    vendor: json['vendor'],
    transactionType: json['transactionType'],
    capturedAt: DateTime.parse(json['capturedAt']),
    notes: json['notes'],
  );
}

/// Service for managing receipt photos
class ReceiptPhotoService {
  static const String _storageKey = 'receipt_photos';
  final Uuid _uuid = const Uuid();

  /// Save a new receipt photo
  Future<ReceiptPhoto> saveReceiptPhoto({
    required String imagePath,
    String? title,
    String? description,
    double? amount,
    String? vendor,
    String? transactionType,
    String? notes,
  }) async {
    final photo = ReceiptPhoto(
      id: _uuid.v4(),
      imagePath: imagePath,
      title: title ?? 'Receipt ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
      description: description,
      amount: amount,
      vendor: vendor,
      transactionType: transactionType ?? 'sale',
      capturedAt: DateTime.now(),
      notes: notes,
    );

    final photos = await getAllReceiptPhotos();
    photos.insert(0, photo); // Add to beginning (newest first)
    await _saveAllPhotos(photos);

    return photo;
  }

  /// Get all saved receipt photos
  Future<List<ReceiptPhoto>> getAllReceiptPhotos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      
      if (jsonString == null) return [];

      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => ReceiptPhoto.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error loading receipt photos: $e');
      return [];
    }
  }

  /// Update an existing receipt photo
  Future<bool> updateReceiptPhoto(ReceiptPhoto updatedPhoto) async {
    try {
      final photos = await getAllReceiptPhotos();
      final index = photos.indexWhere((p) => p.id == updatedPhoto.id);
      
      if (index == -1) return false;

      photos[index] = updatedPhoto;
      await _saveAllPhotos(photos);
      return true;
    } catch (e) {
      debugPrint('Error updating receipt photo: $e');
      return false;
    }
  }

  /// Delete a receipt photo
  Future<bool> deleteReceiptPhoto(String id) async {
    try {
      final photos = await getAllReceiptPhotos();
      photos.removeWhere((p) => p.id == id);
      await _saveAllPhotos(photos);
      return true;
    } catch (e) {
      debugPrint('Error deleting receipt photo: $e');
      return false;
    }
  }

  /// Get receipt photo by ID
  Future<ReceiptPhoto?> getReceiptPhotoById(String id) async {
    final photos = await getAllReceiptPhotos();
    try {
      return photos.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get count of all receipt photos
  Future<int> getReceiptPhotoCount() async {
    final photos = await getAllReceiptPhotos();
    return photos.length;
  }

  /// Get total amount from all receipts
  Future<double> getTotalAmount({String? transactionType}) async {
    final photos = await getAllReceiptPhotos();
    double total = 0;
    for (var photo in photos) {
      if (transactionType == null || photo.transactionType == transactionType) {
        total += photo.amount ?? 0;
      }
    }
    return total;
  }

  /// Save all photos to storage
  Future<void> _saveAllPhotos(List<ReceiptPhoto> photos) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(photos.map((p) => p.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  /// Clear all receipt photos
  Future<void> clearAllReceiptPhotos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
