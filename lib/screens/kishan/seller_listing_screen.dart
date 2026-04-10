import 'dart:convert';

import 'package:aloo_sbji_mandi/core/service/listing_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:aloo_sbji_mandi/core/utils/toast_helper.dart';
import 'package:aloo_sbji_mandi/screens/kishan/edit_listing_screen.dart';
import 'package:aloo_sbji_mandi/screens/kishan/my_listing_detail_screen.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MySellerListingScreen extends StatefulWidget {
  const MySellerListingScreen({super.key});

  @override
  State<MySellerListingScreen> createState() => _MySellerListingScreenState();
}

class _MySellerListingScreenState extends State<MySellerListingScreen> {
  final ListingService _listingService = ListingService();
  List<Map<String, dynamic>> _myListings = [];
  bool _isLoading = true;

  // Filter state
  String _statusFilter = 'all'; // all, active, inactive, expired
  String _sourceFilter = 'all'; // all, field, cold_storage
  String _typeFilter = 'all'; // all, crop, seed

  List<Map<String, dynamic>> get _filteredListings {
    return _myListings.where((listing) {
      // Status filter
      if (_statusFilter != 'all') {
        final isActive = listing['isActive'] ?? true;
        final isExpired = _isExpired(listing);
        if (_statusFilter == 'active' && (!isActive || isExpired)) return false;
        if (_statusFilter == 'inactive' && (isActive && !isExpired))
          return false;
        if (_statusFilter == 'expired' && !isExpired) return false;
      }
      // Source filter
      if (_sourceFilter != 'all') {
        final sourceType = listing['sourceType'] ?? 'field';
        if (sourceType != _sourceFilter) return false;
      }
      // Type filter
      if (_typeFilter != 'all') {
        final listingType = listing['listingType'] ?? 'crop';
        if (listingType != _typeFilter) return false;
      }
      return true;
    }).toList();
  }

  bool _isExpired(Map<String, dynamic> listing) {
    if (listing['expiresAt'] == null) return false;
    final expiresAt = DateTime.tryParse(listing['expiresAt'].toString());
    if (expiresAt == null) return false;
    return expiresAt.difference(DateTime.now()).isNegative;
  }

  bool get _hasActiveFilters =>
      _statusFilter != 'all' || _sourceFilter != 'all' || _typeFilter != 'all';

  int get _activeFilterCount {
    int count = 0;
    if (_statusFilter != 'all') count++;
    if (_sourceFilter != 'all') count++;
    if (_typeFilter != 'all') count++;
    return count;
  }

  @override
  void initState() {
    super.initState();
    _loadMyListings();
  }

  Future<void> _loadMyListings() async {
    setState(() => _isLoading = true);
    final result = await _listingService.getMyListings();
    if (result['success'] && mounted) {
      setState(() {
        _myListings = List<Map<String, dynamic>>.from(
          result['data']['listings'] ?? [],
        );
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteListing(String listingId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          tr('delete_listing'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(tr('confirm_delete_listing')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              tr('cancel'),
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              tr('delete'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await _listingService.deleteListing(listingId);
      if (result['success']) {
        ToastHelper.showSuccess(context, tr('listing_deleted'));
        _loadMyListings();
      } else {
        ToastHelper.showError(context, result['message'] ?? 'Failed to delete');
      }
    }
  }

  void _viewListing(Map<String, dynamic> listing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyListingDetailScreen(listing: listing),
      ),
    );
  }

  Future<void> _editListing(Map<String, dynamic> listing) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditListingScreen(listing: listing),
      ),
    );

    // Refresh if listing was updated
    if (result == true) {
      _loadMyListings();
    }
  }

  void _showFilterSheet() {
    // Temporary filter values for the sheet
    String tempStatus = _statusFilter;
    String tempSource = _sourceFilter;
    String tempType = _typeFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tr('filters'),
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            tempStatus = 'all';
                            tempSource = 'all';
                            tempType = 'all';
                          });
                        },
                        child: Text(
                          tr('clear_all'),
                          style: TextStyle(
                            color: Colors.red[400],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Status filter
                  _FilterSection(
                    title: tr('status_label'),
                    options: [
                      _FilterOption('all', tr('all')),
                      _FilterOption('active', tr('active')),
                      _FilterOption('inactive', tr('inactive')),
                      _FilterOption('expired', tr('expired')),
                    ],
                    selected: tempStatus,
                    onSelect: (val) => setSheetState(() => tempStatus = val),
                  ),
                  const SizedBox(height: 16),
                  // Source filter
                  _FilterSection(
                    title: tr('source'),
                    options: [
                      _FilterOption('all', tr('all')),
                      _FilterOption('field', tr('field')),
                      _FilterOption('cold_storage', tr('cold_storage')),
                    ],
                    selected: tempSource,
                    onSelect: (val) => setSheetState(() => tempSource = val),
                  ),
                  const SizedBox(height: 16),
                  // Type filter
                  _FilterSection(
                    title: tr('type'),
                    options: [
                      _FilterOption('all', tr('all')),
                      _FilterOption('crop', tr('crop')),
                      _FilterOption('seed', tr('seed')),
                    ],
                    selected: tempType,
                    onSelect: (val) => setSheetState(() => tempType = val),
                  ),
                  const SizedBox(height: 24),
                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _statusFilter = tempStatus;
                          _sourceFilter = tempSource;
                          _typeFilter = tempType;
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        tr('apply_filters'),
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActiveFilterChips() {
    final chips = <Widget>[];
    if (_statusFilter != 'all') {
      chips.add(
        _buildChip(
          _statusFilter == 'active'
              ? tr('active')
              : _statusFilter == 'inactive'
              ? tr('inactive')
              : tr('expired'),
          () => setState(() => _statusFilter = 'all'),
        ),
      );
    }
    if (_sourceFilter != 'all') {
      chips.add(
        _buildChip(
          _sourceFilter == 'field' ? tr('field') : tr('cold_storage'),
          () => setState(() => _sourceFilter = 'all'),
        ),
      );
    }
    if (_typeFilter != 'all') {
      chips.add(
        _buildChip(
          _typeFilter == 'crop' ? tr('crop') : tr('seed'),
          () => setState(() => _typeFilter = 'all'),
        ),
      );
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(spacing: 8, runSpacing: 6, children: chips),
    );
  }

  Widget _buildChip(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 14, color: AppColors.primaryGreen),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredListings;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CustomRoundedAppBar(
        title: tr('my_listings'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list, color: Colors.white),
                onPressed: _showFilterSheet,
              ),
              if (_hasActiveFilters)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_activeFilterCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : _myListings.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr('no_listings'),
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('create_first_listing'),
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadMyListings,
              child: Column(
                children: [
                  _buildActiveFilterChips(),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.filter_list_off,
                                  size: 56,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  tr('no_listings'),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () => setState(() {
                                    _statusFilter = 'all';
                                    _sourceFilter = 'all';
                                    _typeFilter = 'all';
                                  }),
                                  child: Text(
                                    tr('clear_all'),
                                    style: TextStyle(
                                      color: AppColors.primaryGreen,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: GridView.builder(
                              itemCount: filtered.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount:
                                        MediaQuery.of(context).size.width > 600
                                        ? 3
                                        : 2,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 0.50,
                                  ),
                              itemBuilder: (context, index) {
                                final listing = filtered[index];
                                return _ListingCard(
                                  listing: listing,
                                  onView: () => _viewListing(listing),
                                  onEdit: () => _editListing(listing),
                                  onDelete: () =>
                                      _deleteListing(listing['_id']),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _FilterOption {
  final String value;
  final String label;
  _FilterOption(this.value, this.label);
}

class _FilterSection extends StatelessWidget {
  final String title;
  final List<_FilterOption> options;
  final String selected;
  final ValueChanged<String> onSelect;

  const _FilterSection({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = opt.value == selected;
            return GestureDetector(
              onTap: () => onSelect(opt.value),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryGreen : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryGreen
                        : Colors.grey[300]!,
                  ),
                ),
                child: Text(
                  opt.label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ListingCard extends StatelessWidget {
  final Map<String, dynamic> listing;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ListingCard({
    required this.listing,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final variety = listing['potatoVariety'] ?? 'Potato';
    final price = listing['pricePerQuintal'] ?? 0;
    final quantity = listing['quantity'] ?? 0;
    final isActive = listing['isActive'] ?? true;
    final type = listing['type'] ?? 'sell';
    final sourceType = listing['sourceType'] ?? 'field';
    final unit = listing['unit'] ?? tr('quintal');
    final packetWeight = listing['packetWeight'];
    final listingType = listing['listingType'] ?? 'crop';
    final isSeed = listingType == 'seed';
    final referenceId = listing['referenceId'] as String?;

    // Location
    final captureLocation = listing['captureLocation'];
    final locationAddress = captureLocation != null
        ? (captureLocation['address'] ?? '').toString()
        : '';

    // Expiry calculation
    String expiryText = '';
    Color expiryColor = Colors.green;
    if (listing['expiresAt'] != null) {
      final expiresAt = DateTime.tryParse(listing['expiresAt'].toString());
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
    }

    return GestureDetector(
      onTap: onView,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: _buildFirstImage(),
                  ),
                  // Status badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.green : Colors.orange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isActive ? tr('active') : tr('inactive'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Source type badge
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
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            sourceType == 'cold_storage'
                                ? Icons.ac_unit
                                : Icons.grass,
                            size: 12,
                            color: sourceType == 'cold_storage'
                                ? Colors.blue
                                : Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            sourceType == 'cold_storage'
                                ? tr('cold')
                                : tr('field'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: sourceType == 'cold_storage'
                                  ? Colors.blue
                                  : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Expiry badge
                  if (expiryText.isNotEmpty)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: expiryColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.timer,
                              color: Colors.white,
                              size: 10,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              expiryText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Seed / Crop badge
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSeed
                            ? Colors.orange.shade700
                            : Colors.green.shade700,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isSeed ? tr('seed') : tr('crop'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      variety,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
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
                      "₹ $price / ${unitAbbr(unit.toString())}",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (unit == 'Packet' && packetWeight != null) ...[
                      Text(
                        '${tr('packet')}: ${packetWeight is num ? packetWeight.round() : packetWeight} ${tr('kg')}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 2), 
                    ],
                    Text(
                      "$quantity ${unitPlural(unit.toString())}",
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    if (locationAddress.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 12,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              locationAddress,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Spacer(),
                    // Action Buttons Row
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: onEdit,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.edit,
                                    color: AppColors.primaryGreen,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    tr('edit'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: onDelete,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    tr('delete'),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFirstImage() {
    final images = listing['images'];
    if (images is List && images.isNotEmpty) {
      final url = images[0].toString();
      debugPrint('ImageUrl: $url');
      if (url.startsWith('data:image')) {
        final base64Str = url.split(',').last;
        return Image.memory(
          base64Decode(base64Str),
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _defaultImage(),
        );
      }
      return Image.network(
        url,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _defaultImage(),
      );
    }
    return _defaultImage();
  }

  Widget _defaultImage() {
    return Image.asset(
      'assets/potato.png',
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
    );
  }
}
