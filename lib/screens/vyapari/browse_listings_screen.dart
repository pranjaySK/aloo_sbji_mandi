import 'dart:convert';

import 'package:aloo_sbji_mandi/core/models/chat_models.dart';
import 'package:aloo_sbji_mandi/core/service/chat_service.dart';
import 'package:aloo_sbji_mandi/core/service/listing_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/screens/chat/chat_detail_screen.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:aloo_sbji_mandi/widgets/listing_filter_sheet.dart';
import 'package:aloo_sbji_mandi/widgets/location_map_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class BrowseListingsScreen extends StatefulWidget {
  final String? initialType; // 'sell' or 'buy'

  const BrowseListingsScreen({super.key, this.initialType});

  @override
  State<BrowseListingsScreen> createState() => _BrowseListingsScreenState();
}

class _BrowseListingsScreenState extends State<BrowseListingsScreen>
    with SingleTickerProviderStateMixin {
  final ListingService _listingService = ListingService();
  late TabController _tabController;

  List<dynamic> _sellListings = [];
  List<dynamic> _buyListings = [];
  bool _isLoading = true;
  String? _error;
  final ListingFilters _sellFilters = ListingFilters();
  final ListingFilters _buyFilters = ListingFilters();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialType == 'buy' ? 1 : 0,
    );
    _loadListings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadListings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final sellResult = await _listingService.getSellListings(
      limit: 50,
      variety: _sellFilters.variety,
      size: _sellFilters.size,
      quality: _sellFilters.quality,
      sourceType: _sellFilters.sourceType,
      minPrice: _sellFilters.minPrice,
      maxPrice: _sellFilters.maxPrice,
      sortBy: _sellFilters.sortBy,
    );
    final buyResult = await _listingService.getBuyListings(
      limit: 50,
      variety: _buyFilters.variety,
      size: _buyFilters.size,
      quality: _buyFilters.quality,
      sourceType: _buyFilters.sourceType,
      minPrice: _buyFilters.minPrice,
      maxPrice: _buyFilters.maxPrice,
      sortBy: _buyFilters.sortBy,
    );

    setState(() {
      _isLoading = false;
      if (sellResult['success']) {
        _sellListings = sellResult['data']['listings'] ?? [];
      }
      if (buyResult['success']) {
        _buyListings = buyResult['data']['listings'] ?? [];
      }
      if (!sellResult['success'] && !buyResult['success']) {
        _error = 'Failed to load listings';
      }
    });
  }

  Future<void> _loadSellOnly() async {
    setState(() => _isLoading = true);
    final result = await _listingService.getSellListings(
      limit: 50,
      variety: _sellFilters.variety,
      size: _sellFilters.size,
      quality: _sellFilters.quality,
      sourceType: _sellFilters.sourceType,
      minPrice: _sellFilters.minPrice,
      maxPrice: _sellFilters.maxPrice,
      sortBy: _sellFilters.sortBy,
    );
    setState(() {
      _isLoading = false;
      if (result['success']) {
        _sellListings = result['data']['listings'] ?? [];
      }
    });
  }

  Future<void> _loadBuyOnly() async {
    setState(() => _isLoading = true);
    final result = await _listingService.getBuyListings(
      limit: 50,
      variety: _buyFilters.variety,
      size: _buyFilters.size,
      quality: _buyFilters.quality,
      sourceType: _buyFilters.sourceType,
      minPrice: _buyFilters.minPrice,
      maxPrice: _buyFilters.maxPrice,
      sortBy: _buyFilters.sortBy,
    );
    setState(() {
      _isLoading = false;
      if (result['success']) {
        _buyListings = result['data']['listings'] ?? [];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Farmer Listings',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'Selling (${_sellListings.length})'),
            Tab(text: 'Buying (${_buyListings.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadListings,
                    child: Text(tr('retry')),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFilteredTab(_sellListings, 'sell', _sellFilters),
                _buildFilteredTab(_buyListings, 'buy', _buyFilters),
              ],
            ),
    );
  }

  Widget _buildFilteredTab(
    List<dynamic> listings,
    String type,
    ListingFilters filters,
  ) {
    return Column(
      children: [
        ListingFilterBar(
          filters: filters,
          onFilterTap: () => _openFilterSheet(type, filters),
          onClearAll: () {
            setState(() => filters.clear());
            if (type == 'sell') {
              _loadSellOnly();
            } else {
              _loadBuyOnly();
            }
          },
        ),
        Expanded(child: _buildListingGrid(listings, type, filters)),
      ],
    );
  }

  Future<void> _openFilterSheet(String type, ListingFilters filters) async {
    final result = await ListingFilterSheet.show(
      context,
      currentFilters: filters,
    );
    if (result != null) {
      setState(() {
        filters.variety = result.variety;
        filters.size = result.size;
        filters.quality = result.quality;
        filters.sourceType = result.sourceType;
        filters.minPrice = result.minPrice;
        filters.maxPrice = result.maxPrice;
        filters.sortBy = result.sortBy;
      });
      if (type == 'sell') {
        _loadSellOnly();
      } else {
        _loadBuyOnly();
      }
    }
  }

  Widget _buildListingGrid(
    List<dynamic> listings,
    String type,
    ListingFilters filters,
  ) {
    if (listings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              filters.hasActiveFilters
                  ? tr('no_results_for_filters')
                  : 'No ${type == 'sell' ? 'selling' : 'buying'} listings found',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            if (filters.hasActiveFilters) ...[
              const SizedBox(height: 8),
              Text(
                tr('try_changing_filters'),
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  setState(() => filters.clear());
                  if (type == 'sell') {
                    _loadSellOnly();
                  } else {
                    _loadBuyOnly();
                  }
                },
                icon: const Icon(Icons.clear, size: 16),
                label: Text(tr('clear_filters')),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadListings,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.7,
        ),
        itemCount: listings.length,
        itemBuilder: (context, index) {
          return ListingCard(
            listing: listings[index],
            onTap: () => _showListingDetail(listings[index]),
          );
        },
      ),
    );
  }

  void _showListingDetail(Map<String, dynamic> listing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ListingDetailSheet(listing: listing),
    );
  }
}

class ListingCard extends StatefulWidget {
  final Map<String, dynamic> listing;
  final VoidCallback onTap;

  const ListingCard({super.key, required this.listing, required this.onTap});

  @override
  State<ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends State<ListingCard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<String> get _images {
    final imgs = widget.listing['images'];
    if (imgs is List && imgs.isNotEmpty) {
      return imgs.cast<String>();
    }
    return [];
  }

  @override
  void initState() {
    super.initState();
    if (_images.length > 1) {
      Future.delayed(const Duration(seconds: 3), _autoSlide);
    }
  }

  void _autoSlide() {
    if (!mounted || _images.length <= 1) return;
    final next = (_currentPage + 1) % _images.length;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
    Future.delayed(const Duration(seconds: 4), _autoSlide);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildListingImage(String url) {
    if (url.startsWith('data:image')) {
      final base64Str = url.split(',').last;
      return Image.memory(
        base64Decode(base64Str),
        height: 100,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackImg(),
      );
    }
    return Image.network(
      url,
      height: 100,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _fallbackImg(),
    );
  }

  Widget _fallbackImg() {
    return Image.asset(
      'assets/potato.png',
      height: 100,
      width: double.infinity,
      fit: BoxFit.cover,
    );
  }

  String _getRemainingTime() {
    final expiresAtStr = widget.listing['expiresAt'];
    if (expiresAtStr == null) return '';

    try {
      final expiresAt = DateTime.parse(expiresAtStr);
      final now = DateTime.now();
      final diff = expiresAt.difference(now);

      if (diff.isNegative) return 'Expired';

      if (diff.inDays > 0) {
        return '${diff.inDays}d left';
      } else if (diff.inHours > 0) {
        return '${diff.inHours}h ${diff.inMinutes % 60}m left';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes}m left';
      } else {
        return 'Expiring soon';
      }
    } catch (e) {
      return '';
    }
  }

  bool get _isExpiringSoon {
    final expiresAtStr = widget.listing['expiresAt'];
    if (expiresAtStr == null) return false;

    try {
      final expiresAt = DateTime.parse(expiresAtStr);
      final now = DateTime.now();
      final diff = expiresAt.difference(now);
      return diff.inHours < 6 && !diff.isNegative;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final seller = listing['seller'] ?? {};
    final variety = listing['potatoVariety'] ?? listing['variety'] ?? 'Potato';
    final price = listing['pricePerQuintal'] ?? listing['price'] ?? 0;
    final quantity = listing['quantity'] ?? 0;
    final size = listing['size'] ?? 'Medium';
    final sellerRating = (seller['rating'] ?? 0).toDouble();
    final remainingTime = _getRemainingTime();
    final unit = listing['unit'] ?? 'Packet';
    final packetWeight = listing['packetWeight'];
    final referenceId = listing['referenceId'] as String?;
    final images = _images;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with slider
            Stack(
              children: [
                if (images.length > 1)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: SizedBox(
                      height: 100,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: images.length,
                        onPageChanged: (i) => setState(() => _currentPage = i),
                        itemBuilder: (_, i) => _buildListingImage(images[i]),
                      ),
                    ),
                  )
                else
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: images.isNotEmpty
                        ? _buildListingImage(images[0])
                        : Image.asset(
                            'assets/potato.png',
                            height: 100,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 100,
                              color: Colors.grey[300],
                              child: const Icon(Icons.image, size: 40),
                            ),
                          ),
                  ),
                // Dot indicators
                if (images.length > 1)
                  Positioned(
                    bottom: 6,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        images.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _currentPage == i ? 14 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _currentPage == i
                                ? Colors.white
                                : Colors.white54,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Crop / Seed badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (listing['listingType'] == 'seed')
                          ? Colors.orange.shade700
                          : Colors.green.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      (listing['listingType'] == 'seed')
                          ? tr('seed')
                          : tr('crop'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                // Rating badge (only show if seller has ratings)
                if (sellerRating > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            sellerRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Expiry time badge (24-hour listings)
                if (remainingTime.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: remainingTime == 'Expired'
                            ? Colors.red
                            : _isExpiringSoon
                            ? Colors.orange
                            : Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.timer,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            remainingTime,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // Details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    variety,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (referenceId != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      referenceId,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500],
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '₹$price / ${unit.toString().toLowerCase()}',
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (unit == 'Packet' && packetWeight != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Packet: ${packetWeight is num ? packetWeight.round() : packetWeight} kg',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Qty: $quantity ${unit.toString().toLowerCase()}s • Size: $size',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  // Seller info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.blue.withOpacity(0.2),
                        child: const Icon(
                          Icons.person,
                          size: 14,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${seller['firstName'] ?? ''} ${seller['lastName'] ?? ''}'
                              .trim(),
                          style: const TextStyle(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  // Cold Storage name on card
                  if (listing['sourceType'] == 'cold_storage' &&
                      (listing['coldStorageName'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.warehouse_rounded, size: 14, color: Colors.blue.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            listing['coldStorageName'],
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Capture location on card
                  if (listing['captureLocation'] != null &&
                      listing['captureLocation'] is Map &&
                      listing['captureLocation']['address'] != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.gps_fixed, size: 13, color: Colors.green.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            listing['captureLocation']['address'],
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ListingDetailSheet extends StatefulWidget {
  final Map<String, dynamic> listing;

  const ListingDetailSheet({super.key, required this.listing});

  @override
  State<ListingDetailSheet> createState() => _ListingDetailSheetState();
}

class _ListingDetailSheetState extends State<ListingDetailSheet> {
  final ChatService _chatService = ChatService();
  final PageController _imagePageController = PageController();
  bool _isLoadingChat = false;
  int _currentImageIndex = 0;

  Map<String, dynamic> get listing => widget.listing;
  Map<String, dynamic> get seller =>
      listing['seller'] is Map ? listing['seller'] as Map<String, dynamic> : {};

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
    _imagePageController.dispose();
    super.dispose();
  }

  /// Build image widget handling base64 and network URLs
  Widget _buildListingImage(String url, {double? height}) {
    final imgHeight = height ?? 180.0;
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
      height: height ?? 180,
      width: double.infinity,
      fit: BoxFit.cover,
    );
  }

  Future<void> _startChat() async {
    // Get seller ID with better null safety
    String? sellerId;
    String sellerName = 'Seller';
    String sellerRole = 'farmer';

    if (seller.isNotEmpty && seller['_id'] != null) {
      sellerId = seller['_id'].toString();
      sellerName = '${seller['firstName'] ?? ''} ${seller['lastName'] ?? ''}'
          .trim();
      if (sellerName.isEmpty) sellerName = 'Seller';
      sellerRole = seller['role']?.toString() ?? 'farmer';
    } else if (listing['seller'] != null) {
      // Seller might be stored as just an ID string
      if (listing['seller'] is String) {
        sellerId = listing['seller'];
      }
    }

    if (sellerId == null || sellerId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('seller_info_not_available')),
            backgroundColor: Colors.red,
          ),
        );
      }
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
        'title': listing['potatoVariety'] ?? listing['variety'] ?? 'Potato',
        'price': listing['pricePerQuintal'] ?? listing['price'],
        'quantity': listing['quantity'],
        'unit': listing['unit'] ?? 'Packet',
        'referenceId': listingRefId,
      },
    );

    setState(() => _isLoadingChat = false);

    if (result['success']) {
      // Backend returns conversation directly in data, or nested under 'conversation'
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
        final listingPrice = listing['expectedPrice'] is num
            ? (listing['expectedPrice'] as num).toDouble()
            : double.tryParse(listing['expectedPrice']?.toString() ?? '');

        Navigator.pop(context); // Close bottom sheet
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('could_not_start_conversation')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? tr('could_not_start_chat')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _callSeller() async {
    final phone = seller['phone'];
    if (phone != null && phone.isNotEmpty) {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final variety = listing['potatoVariety'] ?? listing['variety'] ?? 'Potato';
    final price = listing['pricePerQuintal'] ?? listing['price'] ?? 0;
    final quantity = listing['quantity'] ?? 0;
    final type = listing['type'] ?? 'sell';
    final description = listing['description'] ?? '';
    final size = listing['size'] ?? 'Medium';
    final unit = listing['unit'] ?? 'Packet';
    final packetWeight = listing['packetWeight'];
    final location = listing['location'] ?? {};
    final state = location['state'] ?? listing['state'] ?? '';
    final district = location['district'] ?? listing['city'] ?? '';
    final sourceType = listing['sourceType'] ?? '';
    final coldStorageName = listing['coldStorageName'] ?? '';
    final captureLocation = listing['captureLocation'];

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image with slider support
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 180,
                      width: double.infinity,
                      child: Stack(
                        children: [
                          if (_images.isNotEmpty)
                            _images.length > 1
                                ? PageView.builder(
                                    controller: _imagePageController,
                                    itemCount: _images.length,
                                    onPageChanged: (index) {
                                      setState(() => _currentImageIndex = index);
                                    },
                                    itemBuilder: (context, index) {
                                      return _buildListingImage(_images[index]);
                                    },
                                  )
                                : _buildListingImage(_images[0])
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
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Type badge and variety
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: type == 'sell' ? Colors.green : Colors.blue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          type == 'sell' ? 'FOR SALE' : 'WANTED',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if ((seller['rating'] ?? 0) > 0) ...[
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          (seller['rating'] as num).toStringAsFixed(1),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 12),

                  Text(
                    variety,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Location
                  if (district.isNotEmpty || state.isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Colors.grey[600],
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$district${district.isNotEmpty && state.isNotEmpty ? ', ' : ''}$state',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),

                  const SizedBox(height: 20),

                  // Price and Quantity
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryGreen),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _infoColumn(
                          'Price',
                          '₹$price/${unit.toString().toLowerCase()}',
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: AppColors.primaryGreen,
                        ),
                        _infoColumn(
                          'Quantity',
                          '$quantity ${unit.toString().toLowerCase()}s',
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: AppColors.primaryGreen,
                        ),
                        _infoColumn('Size', size),
                        if (unit == 'Packet' && packetWeight != null) ...[
                          Container(
                            width: 1,
                            height: 40,
                            color: AppColors.primaryGreen,
                          ),
                          _infoColumn(
                            'Pkt Wt',
                            '${packetWeight is num ? packetWeight.round() : packetWeight} kg',
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Description
                  if (description.isNotEmpty) ...[
                    Text(
                      'Description',
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

                  // Cold Storage Info
                  if (sourceType == 'cold_storage' &&
                      coldStorageName.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.shade200,
                        ),
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
                                  'Cold Storage',
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
                    const SizedBox(height: 20),
                  ],

                  // Captured Photo Location — interactive map
                  if (captureLocation != null &&
                      captureLocation is Map &&
                      captureLocation['address'] != null) ...[
                    if (captureLocation['latitude'] != null &&
                        captureLocation['longitude'] != null)
                      LocationMapWidget(
                        latitude: (captureLocation['latitude'] as num).toDouble(),
                        longitude: (captureLocation['longitude'] as num).toDouble(),
                        address: captureLocation['address'] ?? '',
                        height: 200,
                        zoom: 15,
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on, color: Colors.green.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                captureLocation['address'] ?? '',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],

                  // Seller Info
                  Row(
                    children: [
                      Text(
                        'Farmer Information',
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
                              'Listed by Farmer',
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
                          backgroundColor: Colors.blue.withOpacity(0.2),
                          child: const Icon(
                            Icons.person,
                            color: Colors.blue,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${seller['firstName'] ?? ''} ${seller['lastName'] ?? ''}'
                                    .trim(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Chat to connect with farmer',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom action buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBg(context),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoadingChat ? null : _startChat,
                icon: _isLoadingChat
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.chat),
                label: Text(tr('chat_with_farmer')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
