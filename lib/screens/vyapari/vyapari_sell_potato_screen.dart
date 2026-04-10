import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:aloo_sbji_mandi/screens/kishan/create_sell_request_screen.dart';
import 'package:aloo_sbji_mandi/screens/kishan/seller_listing_screen.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Screen to show Sell Potato options for Vyapari (Trader)
class VyapariSellPotatoOptionsScreen extends StatelessWidget {
  const VyapariSellPotatoOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardBg(context),
      appBar: CustomRoundedAppBar(
        leadingIcon: Icons.arrow_back,
        title: tr('sell_potato'),
        actions: const [],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // View My Listings button at top
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MySellerListingScreen(),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryGreen),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.list_alt, color: AppColors.primaryGreen),
                    const SizedBox(width: 10),
                    Text(
                      tr('my_listings'),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            Text(
              tr('create_new_listing'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('where_is_potato'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w400,
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),

            // Option 1: From Field
            _ActionCard(
              backgroundColor: const Color(0xFFE8F5E9),
              borderColor: AppColors.primaryGreen,
              iconPath: "assets/leave.png",
              title: tr('from_field'),
              subtitle: tr('with_live_location'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateSellRequestScreen(
                      listingType: 'crop',
                      sourceType: 'field',
                      showQuality: true,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Option 2: From Cold Storage
            _ActionCard(
              backgroundColor: const Color(0xFFE3F2FD),
              borderColor: const Color(0xFF2196F3),
              iconPath: "assets/home.png",
              title: tr('from_cold_storage'),
              subtitle: tr('with_cold_storage_details'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateSellRequestScreen(
                      listingType: 'crop',
                      sourceType: 'cold_storage',
                      showQuality: true,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final Color backgroundColor;
  final Color borderColor;
  final String iconPath;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.backgroundColor,
    required this.borderColor,
    required this.iconPath,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Row(
          children: [
            Image.asset(iconPath, height: 50, width: 50),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: borderColor, size: 20),
          ],
        ),
      ),
    );
  }
}
