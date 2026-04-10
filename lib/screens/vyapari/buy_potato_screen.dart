import 'dart:convert';

import 'package:aloo_sbji_mandi/core/service/listing_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:aloo_sbji_mandi/screens/vyapari/potato_detail_screen.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:aloo_sbji_mandi/widgets/listing_filter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BuyPotatoesScreen extends StatefulWidget {
  final String? sellerRole; // 'farmer', 'vendor', or null for all
  final String? listingType; // 'seed', 'crop', or null for all

  const BuyPotatoesScreen({super.key, this.sellerRole, this.listingType});

  @override
  State<BuyPotatoesScreen> createState() => _BuyPotatoesScreenState();
}

class _BuyPotatoesScreenState extends State<BuyPotatoesScreen> {
  final ListingService _listingService = ListingService();
  List<dynamic> _listings = [];
  bool _isLoading = true;
  String? _error;
  String? _userDistrict;
  String? _currentUserId;
  final ListingFilters _filters = ListingFilters();

  @override
  void initState() {
    super.initState();
    _loadUserDataAndListings();
  }

  String get _screenTitle {
    // If it's a seed listing type
    if (widget.listingType == 'seed') {
      if (widget.sellerRole == 'farmer') {
        return tr('buy_seeds_from_farmers');
      } else if (widget.sellerRole == 'aloo-mitra') {
        return tr('buy_from_seed_producers');
      }
      return tr('buy_potato_seeds');
    }
    if (widget.sellerRole == 'farmer') {
      return tr('buy_from_farmers');
    } else if (widget.sellerRole == 'vendor') {
      return tr('buy_from_vendors');
    }
    return tr('buy_potatoes');
  }

  Future<void> _loadUserDataAndListings() async {
    // First get user's district and ID
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('userId');
    final userJson = prefs.getString('user');
    if (userJson != null) {
      try {
        final userData = json.decode(userJson);
        _userDistrict = userData['address']?['district'];
        _currentUserId ??= userData['_id'];
      } catch (e) {
        print('Error parsing user data: $e');
      }
    }

    // Then load listings
    await _loadListings();
  }

  Future<void> _loadListings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // For Vyapari buying from other vendors, exclude listings from their own city
    // They should only see vendor listings from OTHER cities
    final result = await _listingService.getSellListings(
      limit: 50,
      sellerRole: widget.sellerRole,
      excludeDistrict: widget.sellerRole == 'vendor' ? _userDistrict : null,
      excludeSeller: _currentUserId,
      listingType: widget.listingType,
      variety: _filters.variety,
      size: _filters.size,
      quality: _filters.quality,
      sourceType: _filters.sourceType,
      minPrice: _filters.minPrice,
      maxPrice: _filters.maxPrice,
      sortBy: _filters.sortBy,
    );

    setState(() {
      _isLoading = false;
      if (result['success']) {
        final allListings = result['data']['listings'] ?? [];
        // Filter out current user's own listings
        if (_currentUserId != null && _currentUserId!.isNotEmpty) {
          _listings = allListings.where((listing) {
            final sellerId = listing['seller']?['_id'] ?? listing['sellerId'];
            return sellerId != _currentUserId;
          }).toList();
          print(
            'BuyPotatoesScreen: userId=$_currentUserId, total=${allListings.length}, afterFilter=${_listings.length}',
          );
        } else {
          _listings = allListings;
          print(
            'BuyPotatoesScreen: No userId found, showing all ${allListings.length} listings',
          );
        }
      } else {
        _error = result['message'] ?? tr('failed_to_load_listings');
      }
    });
  }

  String _getEmptyMessage() {
    // Check for seed listings first
    if (widget.listingType == 'seed') {
      if (widget.sellerRole == 'farmer') {
        return tr('no_seed_listings_from_farmers_check_later');
      } else if (widget.sellerRole == 'aloo-mitra') {
        return tr('no_listings_from_seed_producers_check_later');
      }
      return tr('no_seed_listings_available');
    }

    // Regular potato listings
    if (widget.sellerRole == 'farmer') {
      return tr('no_listings_from_farmers');
    } else if (widget.sellerRole == 'vendor') {
      return tr('no_listings_from_vendors');
    }
    return tr('no_listings_available');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomRoundedAppBar(
        title: _screenTitle,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadListings,
          ),
        ],
      ),

      body: Column(
        children: [
          // Filter bar
          ListingFilterBar(
            filters: _filters,
            onFilterTap: _openFilterSheet,
            onClearAll: () {
              setState(() => _filters.clear());
              _loadListings();
            },
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadListings,
                          child: Text(tr('retry')),
                        ),
                      ],
                    ),
                  )
                : _listings.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _filters.hasActiveFilters
                              ? tr('no_results_for_filters')
                              : _getEmptyMessage(),
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        if (_filters.hasActiveFilters) ...[
                          const SizedBox(height: 8),
                          Text(
                            tr('try_changing_filters'),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () {
                              setState(() => _filters.clear());
                              _loadListings();
                            },
                            icon: const Icon(Icons.clear, size: 16),
                            label: Text(tr('clear_filters')),
                          ),
                        ],
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadListings,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: GridView.builder(
                        itemCount: _listings.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: .75,
                            ),
                        itemBuilder: (_, index) => _PotatoCard(
                          listing: _listings[index],
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PotatoDetailsScreen(
                                  listing: Map<String, dynamic>.from(
                                    _listings[index],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    final result = await ListingFilterSheet.show(
      context,
      currentFilters: _filters,
    );
    if (result != null) {
      setState(() {
        _filters.variety = result.variety;
        _filters.size = result.size;
        _filters.quality = result.quality;
        _filters.sourceType = result.sourceType;
        _filters.minPrice = result.minPrice;
        _filters.maxPrice = result.maxPrice;
        _filters.sortBy = result.sortBy;
      });
      _loadListings();
    }
  }
}

class _PotatoCard extends StatefulWidget {
  final Map<String, dynamic> listing;
  final VoidCallback onTap;

  const _PotatoCard({required this.listing, required this.onTap});

  @override
  State<_PotatoCard> createState() => _PotatoCardState();
}

class _PotatoCardState extends State<_PotatoCard> {
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
    // Auto-slide if 2 images
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

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final seller = listing['seller'] ?? {};
    final sellerName =
        '${seller['firstName'] ?? ''} ${seller['lastName'] ?? ''}'.trim();
    final variety = listing['potatoVariety'] ?? 'Potato';
    final price = listing['pricePerQuintal'] ?? 0;
    final unit = listing['unit'] ?? 'Packet';
    final listingType = listing['listingType'] ?? 'crop';
    final isSeed = listingType == 'seed';
    final images = _images;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg(context),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Image with crop/seed badge
            Expanded(
              child: Stack(
                children: [
                  // Image area — slider if multiple, single otherwise
                  if (images.length > 1)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: images.length,
                        onPageChanged: (i) => setState(() => _currentPage = i),
                        itemBuilder: (_, i) => _buildNetworkImage(images[i]),
                      ),
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: images.isNotEmpty
                          ? _buildNetworkImage(images[0])
                          : Image.asset(
                              "assets/potato.png",
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.image, size: 40),
                              ),
                            ),
                    ),
                  // Dot indicators for multiple images
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
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isSeed
                            ? Colors.orange.shade700
                            : Colors.green.shade700,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isSeed ? tr('seed') : tr('crop'),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            /// Variety name
            Text(
              variety,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            /// Seller name
            Text(
              sellerName.isEmpty ? 'Farmer' : sellerName,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 4),

            /// Price + Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "₹$price/${unitAbbr(unit)}",
                    style: GoogleFonts.inter(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),

                /// View Deal
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.primaryGreen,
                      width: 1.4,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "View",
                    style: GoogleFonts.inter(
                      color: AppColors.primaryGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkImage(String url) {
    if (url.startsWith('data:image')) {
      // Base64 image
      final base64Str = url.split(',').last;
      return Image.memory(
        base64Decode(base64Str),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _fallbackImage(),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => _fallbackImage(),
    );
  }

  Widget _fallbackImage() {
    return Image.asset(
      "assets/potato.png",
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }
}
