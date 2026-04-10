import 'dart:convert';

import 'package:aloo_sbji_mandi/core/models/chat_models.dart';
import 'package:aloo_sbji_mandi/core/service/chat_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/toast_helper.dart';
import 'package:aloo_sbji_mandi/screens/chat/chat_detail_screen.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:aloo_sbji_mandi/widgets/location_map_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/ist_datetime.dart';

class PotatoDetailsScreen extends StatefulWidget {
  final Map<String, dynamic>? listing;

  const PotatoDetailsScreen({super.key, this.listing});

  @override
  State<PotatoDetailsScreen> createState() => _PotatoDetailsScreenState();
}

class _PotatoDetailsScreenState extends State<PotatoDetailsScreen> {
  final ChatService _chatService = ChatService();
  final PageController _pageController = PageController();
  bool _isLoadingChat = false;
  int _currentImageIndex = 0;

  Map<String, dynamic> get listing => widget.listing ?? {};
  
  /// Get images from listing
  List<String> get _images {
    final imgs = listing['images'];
    if (imgs is List && imgs.isNotEmpty) {
      return imgs.cast<String>();
    }
    return [];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Build image widget handling base64 and network URLs
  Widget _buildListingImage(String url, {double? height}) {
    final imgHeight = height ?? 200.0;
    if (url.startsWith('data:image')) {
      final base64Str = url.split(',').last;
      return Image.memory(
        base64Decode(base64Str),
        height: imgHeight,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackImage(height: imgHeight),
      );
    }
    return Image.network(
      url,
      height: imgHeight,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _fallbackImage(height: imgHeight),
    );
  }

  /// Fallback image when listing image is not available
  Widget _fallbackImage({double? height}) {
    return Image.asset(
      'assets/potato.png',
      height: height ?? 200,
      width: double.infinity,
      fit: BoxFit.cover,
    );
  }

  /// Open full-screen zoomable image viewer
  void _openImageViewer(int initialIndex) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _FullScreenImageViewer(
            images: _images,
            initialIndex: initialIndex,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Map<String, dynamic> get seller {
    final s = listing['seller'];
    if (s is Map) return Map<String, dynamic>.from(s);
    return {};
  }

  Future<void> _startChat() async {
    String? sellerId;
    String sellerName = 'Seller';
    String sellerRole = 'farmer';

    if (seller.isNotEmpty && seller['_id'] != null) {
      sellerId = seller['_id'].toString();
      sellerName = '${seller['firstName'] ?? ''} ${seller['lastName'] ?? ''}'
          .trim();
      if (sellerName.isEmpty) sellerName = 'Seller';
      sellerRole = seller['role']?.toString() ?? 'farmer';
    } else if (listing['seller'] != null && listing['seller'] is String) {
      sellerId = listing['seller'];
    }

    if (sellerId == null || sellerId.isEmpty) {
      ToastHelper.showError(context, 'Seller information not available');
      return;
    }

    setState(() => _isLoadingChat = true);

    final listingId = listing['_id']?.toString();
    final listingRefId = listing['referenceId']?.toString();

    final result = await _chatService.getOrCreateConversationWithContext(
      otherUserId: sellerId,
      contextType: 'listing',
      contextId: listingId,
      contextModel: 'Listing',
      contextDetails: {
        'title': listing['potatoVariety'] ?? 'Potato',
        'price': listing['pricePerQuintal'],
        'quantity': listing['quantity'],
        'unit': listing['unit'] ?? 'Packet',
        'referenceId': listingRefId,
      },
    );

    setState(() => _isLoadingChat = false);

    if (result['success']) {
      final data = result['data'];
      final conversation = data is Map ? (data['conversation'] ?? data) : null;
      if (conversation != null && conversation['_id'] != null && mounted) {
        // Create ChatUser object for the seller
        final chatUser = ChatUser(
          id: sellerId,
          firstName: seller['firstName']?.toString() ?? sellerName,
          lastName: seller['lastName']?.toString() ?? '',
          role: sellerRole,
          isOnline: seller['isOnline'] ?? false,
          phone: seller['phone']?.toString(),
        );

        // Get listing quantity and price for deal auto-fill
        final listingQuantity = listing['quantity'] is num
            ? (listing['quantity'] as num).toDouble()
            : double.tryParse(listing['quantity']?.toString() ?? '');
        final listingPrice = listing['pricePerQuintal'] is num
            ? (listing['pricePerQuintal'] as num).toDouble()
            : double.tryParse(listing['pricePerQuintal']?.toString() ?? '');

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              conversationId: conversation['_id']?.toString() ?? '',
              otherUser: chatUser,
              contextType: 'listing',
              initialQuantity: listingQuantity,
              initialPrice: listingPrice,
              listingRefId: listingRefId,
            ),
          ),
        );
      } else if (mounted) {
        ToastHelper.showError(context, 'Could not start conversation');
      }
    } else {
      if (mounted) {
        ToastHelper.showError(
          context,
          result['message'] ?? 'Could not start chat',
        );
      }
    }
  }

  Future<void> _callSeller() async {
    final phone = seller['phone'];
    if (phone != null && phone.toString().isNotEmpty) {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        ToastHelper.showError(context, 'Could not launch phone');
      }
    } else {
      ToastHelper.showError(context, 'Phone number not available');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extract listing data with fallbacks
    final variety = listing['potatoVariety'] ?? listing['variety'] ?? 'Potato';
    final price = listing['pricePerQuintal'] ?? listing['price'] ?? 0;
    final quantity = listing['quantity'] ?? 0;
    final unit = listing['unit'] ?? 'Packet';
    final type = listing['type'] ?? 'sell';
    final description = listing['description'] ?? '';
    final size = listing['size'] ?? 'Medium';
    final location = listing['location'] ?? {};
    final state = location['state'] ?? listing['state'] ?? '';
    final district = location['district'] ?? listing['city'] ?? '';
    final sellerName =
        '${seller['firstName'] ?? ''} ${seller['lastName'] ?? ''}'.trim();
    final sellerPhone = seller['phone'] ?? '';
    final createdAt = DateTime.tryParse(listing['createdAt'] ?? '');
    final sourceType = listing['sourceType'] ?? '';
    final coldStorageName = listing['coldStorageName'] ?? '';
    final captureLocation = listing['captureLocation'];

    return Scaffold(
      backgroundColor: AppColors.cardBg(context),
      body: Stack(
        children: [
          // Background
          Image.asset(
            "assets/backgroun2.png",
            width: double.infinity,
            height: 300,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 300,
              color: AppColors.primaryGreen.withOpacity(0.1),
            ),
          ),

          // Content
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 120),

                // Main Image
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.grey[300],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          // Image slider or single image
                          if (_images.isNotEmpty)
                            _images.length > 1
                                ? PageView.builder(
                                    controller: _pageController,
                                    itemCount: _images.length,
                                    onPageChanged: (index) {
                                      setState(() => _currentImageIndex = index);
                                    },
                                    itemBuilder: (context, index) {
                                      return GestureDetector(
                                        onTap: () => _openImageViewer(index),
                                        child: _buildListingImage(_images[index]),
                                      );
                                    },
                                  )
                                : GestureDetector(
                                    onTap: () => _openImageViewer(0),
                                    child: _buildListingImage(_images[0]),
                                  )
                          else
                            _fallbackImage(),
                          // Page indicator dots
                          if (_images.length > 1)
                            Positioned(
                              bottom: 10,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  _images.length,
                                  (index) => Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    width: _currentImageIndex == index ? 10 : 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: _currentImageIndex == index
                                          ? Colors.white
                                          : Colors.white54,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // Type badge
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: type == 'sell'
                                    ? Colors.green
                                    : Colors.blue,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                type == 'sell' ? AppLocalizations.tr('for_sale') : AppLocalizations.tr('wanted'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Content Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg(context),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and price
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  variety,
                                  style: GoogleFonts.inter(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (district.isNotEmpty || state.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$district${district.isNotEmpty && state.isNotEmpty ? ', ' : ''}$state',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '₹$price',
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                                Text(
                                  '/${unitAbbr(unit)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Quick Info Row
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primaryGreen.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _infoColumn(
                              AppLocalizations.tr('quantity'),
                              '$quantity ${unitPlural(unit)}',
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: AppColors.primaryGreen.withOpacity(0.3),
                            ),
                            _infoColumn(AppLocalizations.tr('size'), size),
                            Container(
                              width: 1,
                              height: 40,
                              color: AppColors.primaryGreen.withOpacity(0.3),
                            ),
                            _infoColumn(AppLocalizations.tr('status'), AppLocalizations.tr('status_open')),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Description
                      if (description.isNotEmpty) ...[
                          Text(
                            AppLocalizations.tr('description'),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 20),
                      ],

                      const Divider(),
                      const SizedBox(height: 16),

                      // Cold Storage Info
                      if (sourceType == 'cold_storage' &&
                          coldStorageName.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.warehouse_rounded,
                                  color: Colors.blue.shade700,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                      Text(
                                        AppLocalizations.tr('role_cold_storage'),
                                        style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      coldStorageName,
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Captured Photo Location — Interactive Map
                      if (captureLocation != null &&
                          captureLocation is Map &&
                          captureLocation['latitude'] != null &&
                          captureLocation['longitude'] != null) ...[
                        LocationMapWidget(
                          latitude: (captureLocation['latitude'] is num)
                              ? (captureLocation['latitude'] as num).toDouble()
                              : double.tryParse(captureLocation['latitude'].toString()) ?? 0.0,
                          longitude: (captureLocation['longitude'] is num)
                              ? (captureLocation['longitude'] as num).toDouble()
                              : double.tryParse(captureLocation['longitude'].toString()) ?? 0.0,
                          address: captureLocation['address']?.toString(),
                          height: 180,
                          showAddress: true,
                          showCoordinates: true,
                        ),
                        const SizedBox(height: 16),
                      ] else if (captureLocation != null &&
                          captureLocation is Map &&
                          captureLocation['address'] != null) ...[
                        // Fallback: show text-only location if no lat/lng
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.gps_fixed,
                                  color: Colors.green.shade700,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                      Text(
                                        AppLocalizations.tr('photo_captured_location'),
                                        style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      captureLocation['address'] ?? '',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Seller Info
                      Row(
                        children: [
                          Text(
                            AppLocalizations.tr('farmer_information'),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.agriculture,
                                  size: 14,
                                  color: Colors.orange.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  AppLocalizations.tr('listed_by_farmer'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant(context),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: AppColors.primaryGreen
                                  .withOpacity(0.2),
                              child: const Icon(
                                Icons.person,
                                color: AppColors.primaryGreen,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sellerName.isEmpty ? AppLocalizations.tr('role_farmer') : sellerName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Phone number hidden - use chat instead
                                  Text(
                                    AppLocalizations.tr('chat_to_connect'),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (createdAt != null)
                                    Text(
                                      '${AppLocalizations.tr('member_since')} ${DateFormat('MMM yyyy').format(createdAt.toIST())}',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Action Buttons - Chat only (no call for privacy)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isLoadingChat ? null : _startChat,
                          icon: _isLoadingChat
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.chat, color: Colors.white),
                          label: Text(
                            AppLocalizations.tr('chat_with_farmer'),
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Disclaimer
                      Text(
                        AppLocalizations.tr('aloo_market_disclaimer'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Back Button - positioned last so it's on top
          Positioned(
            top: 40,
            left: 16,
            child: Material(
              color: AppColors.cardBg(context),
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.arrow_back, color: AppColors.primaryGreen),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoColumn(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppColors.primaryGreen,
          ),
        ),
      ],
    );
  }
}

/// Full-screen zoomable image viewer with swipe between images
class _FullScreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenImageViewer({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildZoomableImage(String url) {
    Widget imageWidget;
    if (url.startsWith('data:image')) {
      final base64Str = url.split(',').last;
      imageWidget = Image.memory(
        base64Decode(base64Str),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/potato.png',
          fit: BoxFit.contain,
        ),
      );
    } else {
      imageWidget = Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/potato.png',
          fit: BoxFit.contain,
        ),
      );
    }

    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 5.0,
      child: Center(child: imageWidget),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Swipeable + zoomable images
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              return _buildZoomableImage(widget.images[index]);
            },
          ),

          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),

          // Image counter
          if (widget.images.length > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
