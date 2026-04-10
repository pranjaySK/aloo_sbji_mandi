import 'dart:convert';

import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:aloo_sbji_mandi/widgets/location_map_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/utils/ist_datetime.dart';

/// Detail screen for viewing own listing with all captured images and info.
class MyListingDetailScreen extends StatefulWidget {
  final Map<String, dynamic> listing;

  const MyListingDetailScreen({super.key, required this.listing});

  @override
  State<MyListingDetailScreen> createState() => _MyListingDetailScreenState();
}

class _MyListingDetailScreenState extends State<MyListingDetailScreen> {
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  Map<String, dynamic> get listing => widget.listing;

  /// Get images from listing
  List<String> get _images {
    print('Listing: $listing');
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
  Widget _buildListingImage(String url, {BoxFit fit = BoxFit.cover}) {
    print('Image URL: $url');
    if (url.startsWith('data:image')) {
      final base64Str = url.split(',').last;
      return Image.memory(
        base64Decode(base64Str),
        width: double.infinity,
        height: double.infinity,
        fit: fit,
        errorBuilder: (_, __, ___) => _fallbackImage(),
      );
    }
    return Image.network(
      url,
      width: double.infinity,
      height: double.infinity,
      fit: fit,
      errorBuilder: (_, __, ___) => _fallbackImage(),
    );
  }

  /// Fallback image
  Widget _fallbackImage() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey[400]),
      ),
    );
  }

  /// Open a full-screen image viewer with swipe
  void _openFullScreenGallery(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullScreenGallery(
          images: _images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final variety = listing['potatoVariety'] ?? 'Potato';
    final price = listing['pricePerQuintal'] ?? 0;
    final quantity = listing['quantity'] ?? 0;
    final unit = listing['unit'] ?? 'Quintal';
    final packetWeight = listing['packetWeight'];
    final description = listing['description'] ?? '';
    final size = listing['size'] ?? 'Medium';
    final quality = listing['quality'] ?? '';
    final sourceType = listing['sourceType'] ?? 'field';
    final coldStorageName = listing['coldStorageName'] ?? '';
    final isActive = listing['isActive'] ?? true;
    final listingType = listing['listingType'] ?? 'crop';
    final isSeed = listingType == 'seed';
    final referenceId = listing['referenceId'] as String?;
    final captureLocation = listing['captureLocation'];
    final location = listing['location'] ?? {};
    final state = location['state'] ?? listing['state'] ?? '';
    final district = location['district'] ?? listing['city'] ?? '';
    final createdAt = DateTime.tryParse(listing['createdAt'] ?? '');
    final expiresAt = DateTime.tryParse((listing['expiresAt'] ?? '').toString());

    // Expiry calculation
    String expiryText = '';
    Color expiryColor = Colors.green;
    if (expiresAt != null) {
      final remaining = expiresAt.difference(DateTime.now());
      if (remaining.isNegative) {
        expiryText = tr('expired');
        expiryColor = Colors.red;
      } else if (remaining.inDays > 0) {
        expiryText = '${remaining.inDays} ${tr('days_left')}';
        expiryColor = remaining.inDays <= 3 ? Colors.orange : Colors.green;
      } else if (remaining.inHours > 0) {
        expiryText = '${remaining.inHours} ${tr('hours_left')}';
        expiryColor = Colors.orange;
      } else {
        expiryText = '${remaining.inMinutes} ${tr('minutes_left')}';
        expiryColor = Colors.red;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.cardBg(context),
      body: Stack(
        children: [
          // Background gradient
          Container(
            height: 300,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primaryGreen.withOpacity(0.15),
                  AppColors.cardBg(context),
                ],
              ),
            ),
          ),

          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 90),

                // ── Image Slider ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    height: 260,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.grey[200],
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          // Image slider
                          if (_images.isNotEmpty)
                            GestureDetector(
                              onTap: () => _openFullScreenGallery(_currentImageIndex),
                              child: _images.length > 1
                                  ? PageView.builder(
                                      controller: _pageController,
                                      itemCount: _images.length,
                                      onPageChanged: (index) {
                                        setState(() => _currentImageIndex = index);
                                      },
                                      itemBuilder: (context, index) {
                                        return _buildListingImage(_images[index]);
                                      },
                                    )
                                  : _buildListingImage(_images[0]),
                            )
                          else
                            _fallbackImage(),

                          // Image counter
                          if (_images.length > 1)
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_currentImageIndex + 1} / ${_images.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),

                          // Page indicator dots
                          if (_images.length > 1)
                            Positioned(
                              bottom: 12,
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

                          // Status badge
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isActive ? Colors.green : Colors.orange,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isActive ? tr('active') : tr('inactive'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          // Tap hint icon
                          if (_images.isNotEmpty)
                            Positioned(
                              bottom: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.fullscreen,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Image Thumbnails (if multiple images) ──
                if (_images.length > 1) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 60,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _images.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final isSelected = index == _currentImageIndex;
                        return GestureDetector(
                          onTap: () {
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Container(
                            width: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primaryGreen
                                    : Colors.grey[300]!,
                                width: isSelected ? 2.5 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _buildListingImage(_images[index]),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // ── Content Card ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg(context),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title & badges row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              variety,
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Seed / Crop badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isSeed ? Colors.orange.shade700 : Colors.green.shade700,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isSeed ? tr('seed') : tr('crop'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Reference ID
                      if (referenceId != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              referenceId,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),

                      // Location
                      if (district.isNotEmpty || state.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                '$district${district.isNotEmpty && state.isNotEmpty ? ', ' : ''}$state',
                                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Price card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '₹$price',
                              style: GoogleFonts.inter(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                            Text(
                              ' / ${unitAbbr(unit)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            if (expiryText.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: expiryColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: expiryColor.withOpacity(0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.timer, size: 14, color: expiryColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      expiryText,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: expiryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Quick Info Grid ──
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primaryGreen.withOpacity(0.2)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: _infoTile(Icons.inventory_2_outlined, tr('quantity'), '$quantity ${unitPlural(unit)}')),
                                const SizedBox(width: 12),
                                Expanded(child: _infoTile(Icons.straighten, tr('size'), tr(size.toLowerCase()))),
                              ],
                            ),
                            if (quality.isNotEmpty || (unit == 'Packet' && packetWeight != null)) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  if (quality.isNotEmpty)
                                    Expanded(child: _infoTile(Icons.star_outline, tr('quality'), tr(quality.toLowerCase())))
                                  else
                                    const Expanded(child: SizedBox()),
                                  const SizedBox(width: 12),
                                  if (unit == 'Packet' && packetWeight != null)
                                    Expanded(
                                      child: _infoTile(
                                        Icons.monitor_weight_outlined,
                                        tr('packet_weight'),
                                        '${packetWeight is num ? packetWeight.round() : packetWeight} kg',
                                      ),
                                    )
                                  else
                                    const Expanded(child: SizedBox()),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Source type
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: sourceType == 'cold_storage'
                              ? Colors.blue.shade50
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sourceType == 'cold_storage'
                                ? Colors.blue.shade200
                                : Colors.green.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: sourceType == 'cold_storage'
                                    ? Colors.blue.shade100
                                    : Colors.green.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                sourceType == 'cold_storage' ? Icons.ac_unit : Icons.grass,
                                color: sourceType == 'cold_storage'
                                    ? Colors.blue.shade700
                                    : Colors.green.shade700,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr('source'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: sourceType == 'cold_storage'
                                          ? Colors.blue.shade600
                                          : Colors.green.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    sourceType == 'cold_storage'
                                        ? (coldStorageName.isNotEmpty
                                            ? '$coldStorageName (${tr('cold_storage')})'
                                            : tr('cold_storage'))
                                        : tr('field'),
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: sourceType == 'cold_storage'
                                          ? Colors.blue.shade900
                                          : Colors.green.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Description
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          tr('description'),
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Text(
                            description,
                            style: TextStyle(color: Colors.grey[700], fontSize: 14, height: 1.5),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),

                      // ── Capture Location ──
                      if (captureLocation != null &&
                          captureLocation is Map &&
                          captureLocation['latitude'] != null &&
                          captureLocation['longitude'] != null) ...[
                        Text(
                          tr('capture_location'),
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
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
                          showCoordinates: false,
                        ),
                        const SizedBox(height: 16),
                      ] else if (captureLocation != null &&
                          captureLocation is Map &&
                          captureLocation['address'] != null) ...[
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
                                child: Icon(Icons.gps_fixed, color: Colors.green.shade700, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        tr('photo_captured_location'),
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

                      // Created date
                      if (createdAt != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                              const SizedBox(width: 10),
                              Text(
                                '${tr('listed_on')} ${DateFormat('dd MMM yyyy, hh:mm a').format(createdAt.toIST())}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Back button ──
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

          // ── Title in top bar ──
          Positioned(
            top: 48,
            left: 64,
            child: Text(
              tr('listing_details'),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen image gallery with pinch-to-zoom
class _FullScreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenGallery({required this.images, required this.initialIndex});

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
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

  Widget _buildImage(String url) {
    if (url.startsWith('data:image')) {
      final base64Str = url.split(',').last;
      return Image.memory(
        base64Decode(base64Str),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48, color: Colors.white54),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48, color: Colors.white54),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Swipeable images with pinch-to-zoom
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(child: _buildImage(widget.images[index])),
              );
            },
          ),

          // Close button
          Positioned(
            top: 44,
            left: 16,
            child: Material(
              color: Colors.black45,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: () => Navigator.pop(context),
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
          ),

          // Image counter
          Positioned(
            top: 52,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentIndex + 1} / ${widget.images.length}',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          // Bottom dots
          if (widget.images.length > 1)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.images.length,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentIndex == i ? 12 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentIndex == i ? Colors.white : Colors.white38,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
