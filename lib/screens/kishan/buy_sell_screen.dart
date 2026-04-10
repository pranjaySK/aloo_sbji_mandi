import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:aloo_sbji_mandi/screens/kishan/create_sell_request_screen.dart';
import 'package:aloo_sbji_mandi/screens/vyapari/buy_potato_screen.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BuySellScreen extends StatelessWidget {
  const BuySellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardBg(context),
      appBar: CustomRoundedAppBar(
        leadingIcon: Icons.menu,

        title: "",
        actions: const [Icon(Icons.notifications, color: Colors.white)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text(
              tr('what_would_you_like_to_do'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary(context),
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 24),

            /// Buy Potato Seed Card
            _ActionCard(
              backgroundColor: const Color(0xFFDDFFB3),
              borderColor: AppColors.border,
              iconPath: "assets/buy_seed.png",
              title: tr('buy_potato_seed'),
              subtitle: tr('from_farmer_or_producer'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BuySeedOptionsScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            /// Sell Potato Card
            _ActionCard(
              backgroundColor: const Color(0xFFF3E5CF),
              borderColor: const Color(0xFFA67C44),
              iconPath: "assets/sell_potato.png",
              title: tr('sell_potato'),
              subtitle: tr('sell_seed_or_crop'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SellPotatoOptionsScreen(),
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

/// Screen to show Buy Seed options
class BuySeedOptionsScreen extends StatelessWidget {
  const BuySeedOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardBg(context),
      appBar: CustomRoundedAppBar(
        leadingIcon: Icons.arrow_back,
        title: tr('buy_potato_seed'),
        actions: const [],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text(
              tr('where_to_buy_from'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary(context),
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 24),

            // Option 1: From Farmer
            _ActionCard(
              backgroundColor: const Color(0xFFE8F5E9),
              borderColor: AppColors.primaryGreen,
              iconPath: "assets/farmer.png",
              title: tr('from_farmer'),
              subtitle: tr('buy_seeds_from_farmers'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BuyPotatoesScreen(
                      sellerRole: 'farmer',
                      listingType: 'seed',
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Option 2: From Seed Producers (commented out)
            // _ActionCard(
            //   backgroundColor: const Color(0xFFFFF3E0),
            //   borderColor: const Color(0xFFFF9800),
            //   iconPath: "assets/businessman.png",
            //   title: tr('from_seed_producers'),
            //   subtitle: tr('buy_from_certified_producers'),
            //   onTap: () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => const BuyPotatoesScreen(
            //           sellerRole: 'aloo-mitra',
            //           listingType: 'seed',
            //         ),
            //       ),
            //     );
            //   },
            // ),
          ],
        ),
      ),
    );
  }
}

/// Screen to show Sell Potato options
class SellPotatoOptionsScreen extends StatelessWidget {
  const SellPotatoOptionsScreen({super.key});

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
            const SizedBox(height: 12),
            Text(
              tr('what_to_sell'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary(context),
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 24),

            // Option A: Sell Seed - Goes directly to form (cold storage only)
            _ActionCard(
              backgroundColor: const Color(0xFFE3F2FD),
              borderColor: const Color(0xFF2196F3),
              iconPath: "assets/buy_seed.png",
              title: tr('sell_potato_seed'),
              subtitle: tr('from_cold_storage'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const CreateSellRequestScreen(listingType: 'seed'),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Option B: Sell Crop - Goes to location selection screen (field or cold storage)
            _ActionCard(
              backgroundColor: const Color(0xFFFCE4EC),
              borderColor: const Color(0xFFE91E63),
              iconPath: "assets/sell_potato.png",
              title: tr('sell_potato_crop'),
              subtitle: tr('from_field_or_storage'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const SellLocationScreen(listingType: 'crop'),
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

/// Unified Screen to select selling location (Field or Cold Storage) for both Seed and Crop
class SellLocationScreen extends StatelessWidget {
  final String listingType; // 'seed' or 'crop'

  const SellLocationScreen({super.key, required this.listingType});

  @override
  Widget build(BuildContext context) {
    String titleText = listingType == 'seed'
        ? tr('sell_seed')
        : tr('sell_crop');

    return Scaffold(
      backgroundColor: AppColors.cardBg(context),
      appBar: CustomRoundedAppBar(
        leadingIcon: Icons.arrow_back,
        title: titleText,
        actions: const [],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text(
              tr('where_is_potato'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary(context),
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 24),

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
                    builder: (context) => CreateSellRequestScreen(
                      listingType: listingType,
                      sourceType: 'field',
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
              title: tr('from_cold_storage_option'),
              subtitle: tr('with_cold_storage_details'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateSellRequestScreen(
                      listingType: listingType,
                      sourceType: 'cold_storage',
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

/// Legacy Screen - kept for backward compatibility but redirects to new flow
class SellCropLocationScreen extends StatelessWidget {
  const SellCropLocationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SellLocationScreen(listingType: 'crop');
  }
}

class _ActionCard extends StatelessWidget {
  final Color backgroundColor;
  final Color borderColor;
  final String iconPath;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.backgroundColor,
    required this.borderColor,
    required this.iconPath,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Column(
          children: [
            Image.asset(iconPath, height: 50, width: 50),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
