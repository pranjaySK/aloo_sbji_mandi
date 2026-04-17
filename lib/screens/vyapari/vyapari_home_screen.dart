import 'package:aloo_sbji_mandi/core/service/buy_request_notification_state.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/role_shell_scroll_padding.dart';
import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:aloo_sbji_mandi/screens/aloo_calculator_screen.dart';
import 'package:aloo_sbji_mandi/screens/kishan/create_sell_request_screen.dart';
import 'package:aloo_sbji_mandi/screens/kishan/seller_listing_screen.dart';
import 'package:aloo_sbji_mandi/screens/vyapari/buy_potato_options_screen.dart';
import 'package:aloo_sbji_mandi/screens/vyapari/my_buy_requests_screen.dart';
import 'package:aloo_sbji_mandi/screens/vyapari/vyapari_analytics_screen.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:aloo_sbji_mandi/widgets/common_widget.dart/auto_slider_widget.dart';
import 'package:aloo_sbji_mandi/widgets/common_widget.dart/custom_drawer_widget.dart';
import 'package:aloo_sbji_mandi/widgets/common_widget.dart/direcory_section.dart';
import 'package:aloo_sbji_mandi/widgets/common_widget.dart/news_section_widget.dart';
import 'package:aloo_sbji_mandi/widgets/common_widget.dart/service_card_widget.dart';
import 'package:aloo_sbji_mandi/widgets/common_widget.dart/weather_card.dart';
import 'package:aloo_sbji_mandi/widgets/language_toggle_widget.dart';
import 'package:aloo_sbji_mandi/widgets/notification_bell_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VyapariHomeScreen extends StatelessWidget {
  const VyapariHomeScreen({super.key});

  /// Shows Coming Soon dialog for features under development
  static void _showComingSoonDialog(
    BuildContext context, {
    String? featureName,
    String? featureNameHindi,
  }) {
    final displayName = featureName ?? tr('feature_default');
    final displayNameHindi = featureNameHindi ?? tr('feature_default');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.rocket_launch,
                  size: 40,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                tr('coming_soon'),
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "$displayName ${tr('under_development')}",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    tr('ok'),
                    style: GoogleFonts.inter(
                      fontSize: 16,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: SizedBox(
        width: MediaQuery.of(context).size.width * 0.75,
        child: const CustomAppDrawer(),
      ),
      appBar: CustomRoundedAppBar(
        title: '',
        leadingIcon: Icons.menu,
        isDrawerIcon: true,
        actions: [const LanguageToggleWidget(), const NotificationBellWidget()],
      ),

      backgroundColor: AppColors.scaffoldBg(context),
      body: ListenableBuilder(
        listenable: AppLocalizations.instance,
        builder: (context, _) => SafeArea(
          bottom: false,
        child: SingleChildScrollView(
          padding: RoleShellScrollPadding.home,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// TRADER BANNER SLIDER
              const AutoSliderBanner(
                height: 160,
                autoSlideDuration: Duration(seconds: 4),
                fetchFromServer: true,
              ),
              const SizedBox(height: 16),

              /// BUY / SELL
              Row(
                children: [
                  _mainCard(
                    title: tr('buy_potato'),
                    image: "assets/buy_potato.png",
                    context: context,
                  ),
                  const SizedBox(width: 16),
                  _mainCard(
                    title: tr('sell_potato'),
                    image: "assets/sell_potato.png",
                    context: context,
                  ),
                ],
              ),

              const SizedBox(height: 28),

              /// OTHER SERVICES
              Text(
                tr('other_services'),
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 16),

              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 16,
                childAspectRatio: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MySellerListingScreen(),
                        ),
                      );
                    },
                    child: ServiceCard(
                      title: tr('my_listings'),
                      image: "assets/sell_potato.png",
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/cold_storage_listing');
                    },
                    child: ServiceCard(
                      title: tr('cold_storage_service'),
                      image: "assets/cloud_storage.png",
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/mandi_price');
                    },
                    child: ServiceCard(
                      title: tr('mandi_prices'),
                      image: "assets/alu.png",
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VyapariAnalyticsScreen(),
                        ),
                      );
                    },
                    child: ServiceCard(
                      title: tr('ai_analytics'),
                      image: "assets/al.png",
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const AlooCalculatorScreen(role: 'vyapari'),
                        ),
                      );
                    },
                    child: ServiceCard(
                      title: tr('aloo_calculator'),
                      image: "assets/aloo_calculator.png",
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyBuyRequestsScreen(),
                        ),
                      );
                    },
                    child: ValueListenableBuilder<int>(
                      valueListenable:
                          BuyRequestNotificationState.newResponseCount,
                      builder: (context, count, _) => ServiceCard(
                        title: tr('buy_request'),
                        image: "assets/potato_needed.png",
                        badgeCount: count > 0 ? count : null,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              /// DIRECTORY
              DirectorySection(directoryItems: vyapariDirectoryItems),

              const SizedBox(height: 24),

              /// NEWS SECTION
              NewsSectionWidget(),
              const SizedBox(height: 24),
              // /// DIRECTORY
              // Text(
              //   "Directory",
              //    style: GoogleFonts.inter(
              //     fontSize: 20,
              //     fontWeight: FontWeight.w600,
              //   ),
              // ),
              WeatherCard(),
            ],
          ),
        ),
      ),
      ),
    );
  }

  static Widget _mainCard({
    required BuildContext context,
    required String title,
    required String image,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (title == tr('sell_potato')) {
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
          } else {
            // Navigate to buy options screen with Farmer/Vendor options
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BuyPotatoOptionsScreen(),
              ),
            );
          }
        },
        child: Container(
          height: 130,
          decoration: BoxDecoration(
            color: AppColors.cardGreen,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primaryGreen, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(image, height: 50, width: 50),
              const SizedBox(height: 8),
              Text(
                title,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NewsHowToSection extends StatelessWidget {
  const NewsHowToSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// NEWS SECTION
        _sectionHeader(tr('news')),
        const SizedBox(height: 12),

        Row(
          children: const [
            Expanded(
              child: _ImageCard(image: "assets/1.png", title: ""),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _ImageCard(image: "assets/2.png", title: ""),
            ),
          ],
        ),

        const SizedBox(height: 24),

        /// HOW TO SECTION
        _sectionHeader(tr('how_tos')),
        const SizedBox(height: 12),

        Row(
          children: const [
            Expanded(
              child: _ImageCard(image: "assets/11.png", title: ""),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _ImageCard(image: "assets/21.png", title: ""),
            ),
          ],
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  /// SECTION HEADER
  Widget _sectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            minimumSize: Size(50, 30),

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            side: BorderSide(color: AppColors.primaryGreen),
          ),
          child: Text(
            tr('view_all'),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryGreen,
            ),
          ),
        ),
      ],
    );
  }
}

/// IMAGE CARD WITH TEXT OVERLAY
class _ImageCard extends StatelessWidget {
  final String image;
  final String title;

  const _ImageCard({required this.image, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      width: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        image: DecorationImage(image: AssetImage(image), fit: BoxFit.cover),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [Colors.black.withOpacity(0.6), Colors.transparent],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        alignment: Alignment.bottomLeft,
        child: Text(
          title,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// SERVICE CARD
List<Map<String, String>> get vyapariDirectoryItems => [
  {
    'image': 'assets/transport_service.png',
    'title': tr('transport_services_title'),
    'titleEn': tr('transportation'),
    'route': 'transportation',
  },
];
