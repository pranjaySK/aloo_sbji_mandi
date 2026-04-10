import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:aloo_sbji_mandi/screens/vyapari/buy_potato_screen.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Screen to show Buy Potato options for Vyapari - From Farmer or From Vendors
class BuyPotatoOptionsScreen extends StatelessWidget {
  const BuyPotatoOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardBg(context),
      appBar: CustomRoundedAppBar(
        leadingIcon: Icons.arrow_back,
        title: tr("buy_potatoes"),
        actions: const [],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text(
              tr("where_to_buy_from"),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary(context),
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 24),

            // Option 1: From Farmer
            _BuyOptionCard(
              backgroundColor: const Color(0xFFE8F5E9),
              borderColor: AppColors.primaryGreen,
              iconPath: "assets/farmer.png",
              title: tr("from_farmers"),
              subtitle: tr("buy_potatoes_directly_from_farmers"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BuyPotatoesScreen(
                      sellerRole: 'farmer',
                      listingType: 'crop',
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Option 2: From Vendors
            _BuyOptionCard(
              backgroundColor: const Color(0xFFFFF3E0),
              borderColor: const Color(0xFFFF9800),
              iconPath: "assets/businessman.png",
              title: tr("from_vendors"),
              subtitle: tr("buy_potatoes_from_other_vendors"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const BuyPotatoesScreen(sellerRole: 'vendor'),
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

class _BuyOptionCard extends StatelessWidget {
  final Color backgroundColor;
  final Color borderColor;
  final String iconPath;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BuyOptionCard({
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
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: borderColor.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.cardBg(context),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  iconPath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.shopping_bag, size: 30, color: borderColor),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // Arrow
            Icon(Icons.arrow_forward_ios, size: 18, color: borderColor),
          ],
        ),
      ),
    );
  }
}
