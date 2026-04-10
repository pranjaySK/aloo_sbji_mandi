import 'package:aloo_sbji_mandi/core/service/listing_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:aloo_sbji_mandi/core/utils/toast_helper.dart';
import 'package:aloo_sbji_mandi/screens/aloo_mitra/create_seed_listing_screen.dart';
import 'package:aloo_sbji_mandi/screens/kishan/edit_listing_screen.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Screen for Aloo Mitra (Potato Seeds) users to view and manage their seed listings
class AlooMitraSeedListingsScreen extends StatefulWidget {
  const AlooMitraSeedListingsScreen({super.key});

  @override
  State<AlooMitraSeedListingsScreen> createState() =>
      _AlooMitraSeedListingsScreenState();
}

class _AlooMitraSeedListingsScreenState
    extends State<AlooMitraSeedListingsScreen> {
  final ListingService _listingService = ListingService();
  List<Map<String, dynamic>> _myListings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMyListings();
  }

  Future<void> _loadMyListings() async {
    setState(() => _isLoading = true);
    final result = await _listingService.getMyListings();
    if (result['success'] && mounted) {
      // Filter to only show seed listings
      final allListings = List<Map<String, dynamic>>.from(
        result['data']['listings'] ?? [],
      );
      final seedListings = allListings
          .where(
            (listing) =>
                listing['listingType'] == 'seed' || listing['type'] == 'sell',
          )
          .toList();

      setState(() {
        _myListings = seedListings;
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
          tr('delete_listing_title'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(tr('confirm_delete_listing')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              tr('cancel_action'),
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              tr('delete_action'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await _listingService.deleteListing(listingId);
      if (result['success']) {
        ToastHelper.showSuccess(
          context,
          AppLocalizations.isHindi
              ? tr('listing_deleted')
              : "Listing deleted successfully",
        );
        _loadMyListings();
      } else {
        ToastHelper.showError(context, result['message'] ?? 'Failed to delete');
      }
    }
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

  Future<void> _toggleListingStatus(
    String listingId,
    bool currentStatus,
  ) async {
    final result = await _listingService.updateListing(
      listingId: listingId,
      isActive: !currentStatus,
    );

    if (result['success']) {
      ToastHelper.showSuccess(
        context,
        !currentStatus
            ? (AppLocalizations.isHindi
                  ? tr('listing_activated')
                  : "Listing activated")
            : (AppLocalizations.isHindi
                  ? tr('listing_deactivated')
                  : "Listing deactivated"),
      );
      _loadMyListings();
    } else {
      ToastHelper.showError(context, result['message'] ?? 'Failed to update');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = AppLocalizations.isHindi;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: CustomRoundedAppBar(
        title: isHindi ? tr('my_seed_listings') : "My Seed Listings",
        leadingIcon: Icons.arrow_back,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadMyListings,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateSeedListingScreen(),
            ),
          );
          if (result == true) {
            _loadMyListings();
          }
        },
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          isHindi ? tr('new_listing') : "New Listing",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _myListings.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadMyListings,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _myListings.length,
                itemBuilder: (context, index) {
                  final listing = _myListings[index];
                  return _buildListingCard(listing);
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    final isHindi = AppLocalizations.isHindi;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.eco_outlined,
                size: 64,
                color: AppColors.primaryGreen.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isHindi ? tr('no_seed_listings') : "No Seed Listings Yet",
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isHindi
                  ? tr('create_first_listing_desc')
                  : "Create your first seed listing and\nconnect with farmers!",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateSeedListingScreen(),
                  ),
                );
                if (result == true) {
                  _loadMyListings();
                }
              },
              icon: const Icon(Icons.add),
              label: Text(
                isHindi ? tr('create_first_listing') : "Create First Listing",
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListingCard(Map<String, dynamic> listing) {
    final isHindi = AppLocalizations.isHindi;
    final variety = listing['potatoVariety'] ?? 'Unknown';
    final quantity = listing['quantity'] ?? 0;
    final price = listing['pricePerQuintal'] ?? 0;
    final unit = listing['unit'] ?? 'Quintal';
    final isActive = listing['isActive'] ?? true;
    final listingId = listing['_id']?.toString() ?? '';
    final createdAt = listing['createdAt'] != null
        ? DateTime.tryParse(listing['createdAt'].toString())
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primaryGreen.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.eco,
                      size: 20,
                      color: isActive ? AppColors.primaryGreen : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      variety,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isActive ? AppColors.primaryGreen : Colors.grey,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive
                        ? (isHindi ? tr('active_status') : "Active")
                        : (isHindi ? tr('inactive_status') : "Inactive"),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        icon: Icons.inventory_2,
                        label: isHindi ? tr('quantity_label') : "Quantity",
                        value: "$quantity ${unitAbbr(unit)}",
                      ),
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        icon: Icons.attach_money,
                        label: isHindi ? tr('price_label') : "Price",
                        value: "₹$price/${unitAbbr(unit)}",
                      ),
                    ),
                  ],
                ),
                if (createdAt != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: Colors.grey[500]),
                      const SizedBox(width: 8),
                      Text(
                        trArgs('created_date', {
                          'date': _formatDate(createdAt),
                        }),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
                // Location
                if (listing['captureLocation'] != null &&
                    (listing['captureLocation']['address'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey[500]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          listing['captureLocation']['address'].toString(),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: isActive ? Icons.visibility_off : Icons.visibility,
                  label: isActive
                      ? (isHindi ? tr('deactivate_action') : "Deactivate")
                      : (isHindi ? tr('activate_action') : "Activate"),
                  color: isActive ? Colors.orange : Colors.green,
                  onTap: () => _toggleListingStatus(listingId, isActive),
                ),
                _buildActionButton(
                  icon: Icons.edit,
                  label: isHindi ? tr('edit_action') : "Edit",
                  color: Colors.blue,
                  onTap: () => _editListing(listing),
                ),
                _buildActionButton(
                  icon: Icons.delete,
                  label: isHindi ? tr('delete_action') : "Delete",
                  color: Colors.red,
                  onTap: () => _deleteListing(listingId),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.primaryGreen),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }
}
