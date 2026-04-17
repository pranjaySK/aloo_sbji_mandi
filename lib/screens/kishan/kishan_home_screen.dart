import 'package:aloo_sbji_mandi/core/service/trader_request_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/role_shell_scroll_padding.dart';
import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:aloo_sbji_mandi/screens/ai_crop_advisor_screen.dart';
import 'package:aloo_sbji_mandi/screens/aloo_calculator_screen.dart';
import 'package:aloo_sbji_mandi/screens/kishan/buy_sell_screen.dart';
import 'package:aloo_sbji_mandi/screens/kishan/my_token_screen.dart';
import 'package:aloo_sbji_mandi/screens/kishan/trader_requests_screen.dart';
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
import 'package:shared_preferences/shared_preferences.dart';

class KishanHomeScreen extends StatefulWidget {
  const KishanHomeScreen({super.key});

  @override
  State<KishanHomeScreen> createState() => _KishanHomeScreenState();
}

class _KishanHomeScreenState extends State<KishanHomeScreen> {
  final TraderRequestService _traderRequestService = TraderRequestService();
  int _traderRequestsCount = 0;
  String? _lastSeenTimestamp;

  @override
  void initState() {
    super.initState();
    _loadTraderRequestsCount();
  }

  Future<void> _loadTraderRequestsCount() async {
    // Load last seen timestamp from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    _lastSeenTimestamp = prefs.getString('lastSeenTraderRequestsTimestamp');

    final result = await _traderRequestService.getAllRequests(limit: 100);
    if (result['success'] && mounted) {
      final requests = result['data']['requests'] ?? [];

      // Count only NEW requests (created after last seen timestamp)
      int newCount = 0;
      if (_lastSeenTimestamp == null) {
        // Never viewed - show all open requests as new
        newCount = (requests as List)
            .where((r) => r['status'] == 'open')
            .length;
      } else {
        final lastSeenDate = DateTime.tryParse(_lastSeenTimestamp!);
        if (lastSeenDate != null) {
          newCount = (requests as List).where((r) {
            if (r['status'] != 'open') return false;
            final createdAt = DateTime.tryParse(r['createdAt'] ?? '');
            return createdAt != null && createdAt.isAfter(lastSeenDate);
          }).length;
        }
      }

      setState(() {
        _traderRequestsCount = newCount;
      });
    }
  }

  Future<void> _markTraderRequestsAsSeen() async {
    // Save current timestamp as last seen
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String();
    await prefs.setString('lastSeenTraderRequestsTimestamp', now);

    // Clear the badge immediately
    if (mounted) {
      setState(() {
        _traderRequestsCount = 0;
        _lastSeenTimestamp = now;
      });
    }
  }

  /// Shows Coming Soon dialog for features under development
  static void _showComingSoonDialog(
    BuildContext context, {
    String? featureName,
  }) {
    final displayName = featureName ?? tr('aloo_calculator');

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
        width: MediaQuery.of(context).size.width * 0.75, // 75% of screen
        child: const CustomAppDrawer(),
      ),
      appBar: CustomRoundedAppBar(
        title: '',
        leadingIcon: Icons.menu,
        isDrawerIcon: true,
        actions: [const LanguageToggleWidget(), const NotificationBellWidget()],
      ),

      //   appBar: AppBar(
      //     backgroundColor: AppColors.primaryGreen,
      // leading:         IconButton(
      //             icon: const Icon(Icons.menu, color: Colors.white),
      //             onPressed: () => Scaffold.of(context).openDrawer(),
      //           ),
      //     // leadingWidth: 96, // space for two icons
      //     // leading: Builder(
      //     //   builder: (context) => Row(
      //     //     children: [
      //           // IconButton(
      //           //   icon: const Icon(Icons.menu, color: Colors.white),
      //           //   onPressed: () => Scaffold.of(context).openDrawer(),
      //           // ),
      //           // IconButton(
      //           //   icon: const Icon(Icons.search, color: Colors.white),
      //           //   onPressed: () {
      //           //     // search action
      //           //   },
      //           // ),
      //     //     ],
      //     //   ),
      //     // ),

      //   ),
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
              /// FARMER BANNER SLIDER
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
                    context: context,
                    title: tr('buy_seed'),
                    image: "assets/buy_seed.png",
                    cardType: "buy",
                  ),
                  const SizedBox(width: 16),
                  _mainCard(
                    context: context,
                    title: tr('sell_potato'),
                    image: "assets/sell_potato.png",
                    cardType: "sell",
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
                mainAxisSpacing: 12,
                childAspectRatio: 2.5,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/seller_listing');
                    },
                    child: ServiceCard(
                      title: tr('my_listings'),
                      image: "assets/alu.png",
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      // Mark as seen before navigating
                      await _markTraderRequestsAsSeen();
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TraderRequestsScreen(),
                        ),
                      );
                      // Refresh count when returning (to check for new requests)
                      _loadTraderRequestsCount();
                    },
                    child: ServiceCard(
                      title: tr('trader_requests'),
                      image: "assets/businessman.png",
                      badgeCount: _traderRequestsCount,
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
                      Navigator.pushNamed(context, '/cold_storage_listing');
                    },
                    child: ServiceCard(
                      title: tr('cold_storage_service'),
                      image: "assets/cloud_storage.png",
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const AlooCalculatorScreen(role: 'farmer'),
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
                          builder: (_) =>
                              const AICropAdvisorScreen(userRole: 'farmer'),
                        ),
                      );
                    },
                    child: ServiceCard(
                      title: tr('ai_crop_advisor'),
                      image: "assets/al.png",
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyTokenScreen(),
                        ),
                      );
                    },
                    child: ServiceCard(
                      title: tr('my_token'),
                      image: "assets/alu.png",
                    ),
                  ),
                  GestureDetector(
                    onTap: () =>
                        _showComingSoonDialog(context, featureName: tr('loan')),
                    child: ServiceCard(
                      title: tr('loan'),
                      image: "assets/loan.png",
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              /// DIRECTORY SECTION
              DirectorySection(directoryItems: kishanDirectoryItems),

              const SizedBox(height: 24),

              /// NEWS SECTION
              NewsSectionWidget(),
              const SizedBox(height: 24),
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
    required String cardType,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (cardType == "sell") {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SellPotatoOptionsScreen(),
              ),
            );
          } else if (cardType == "buy") {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BuySeedOptionsScreen(),
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

/// SERVICE CARD
List<Map<String, String>> get kishanDirectoryItems => [
  {
    'image': 'assets/potato_seed.png',
    'title': tr('potato_seeds'),
    'titleEn': tr('potato_seeds'),
    'route': 'potato-seeds',
  },
  {
    'image':
        'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=200&h=200&fit=crop',
    'title': tr('fertilizers_medicines'),
    'titleEn': tr('fertilizers_medicines'),
    'route': 'fertilizers',
  },
  {
    // 'image': 'assets/farming_labour.png',
    'image': 'assets/machine.png',
    'title': tr('machinery_new_rent'),
    'titleEn': tr('machinery_new_rent'),
    'route': 'machinery',
  },
  {
    'image': 'assets/transport_service.png',
    'title': tr('transportation'),
    'titleEn': tr('transportation'),
    'route': 'transportation',
  },
  {
    'image': 'assets/gunny_bag.png',
    'title': tr('gunny_bag'),
    'titleEn': tr('gunny_bag'),
    'route': 'gunny-bag',
  },
  {
    'image': 'assets/farming_labour.png',
    'title': tr('majdoor'),
    'titleEn': tr('majdoor'),
    'route': 'majdoor',
  },
];
