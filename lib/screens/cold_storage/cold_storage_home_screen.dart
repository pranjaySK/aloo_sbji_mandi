import 'package:aloo_sbji_mandi/core/service/cold_storage_service.dart';
import 'package:aloo_sbji_mandi/core/service/token_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/role_shell_scroll_padding.dart';
import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:aloo_sbji_mandi/screens/ai_crop_advisor_screen.dart';
import 'package:aloo_sbji_mandi/screens/aloo_calculator_screen.dart';
import 'package:aloo_sbji_mandi/screens/cold_storage/booking_requests_screen.dart';
import 'package:aloo_sbji_mandi/screens/cold_storage/manage_boli_alerts_screen.dart';
import 'package:aloo_sbji_mandi/screens/cold_storage/manage_storage_screen.dart';
import 'package:aloo_sbji_mandi/screens/cold_storage/token_system_screen.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:aloo_sbji_mandi/widgets/boli_alert_banner.dart';
import 'package:aloo_sbji_mandi/widgets/common_widget.dart/auto_slider_widget.dart';
import 'package:aloo_sbji_mandi/widgets/common_widget.dart/custom_drawer_widget.dart';
import 'package:aloo_sbji_mandi/widgets/common_widget.dart/direcory_section.dart';
import 'package:aloo_sbji_mandi/widgets/common_widget.dart/news_section_widget.dart';
import 'package:aloo_sbji_mandi/widgets/common_widget.dart/service_card_widget.dart';
import 'package:aloo_sbji_mandi/widgets/common_widget.dart/weather_card.dart';
import 'package:aloo_sbji_mandi/widgets/language_toggle_widget.dart';
import 'package:aloo_sbji_mandi/widgets/cold_storage_notification_bell.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ColdStorageHomeScreen extends StatefulWidget {
  const ColdStorageHomeScreen({super.key});

  @override
  State<ColdStorageHomeScreen> createState() => _ColdStorageHomeScreenState();
}

class _ColdStorageHomeScreenState extends State<ColdStorageHomeScreen> {
  final _tokenService = TokenService();
  final _coldStorageService = ColdStorageService();
  int _pendingTokenCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchPendingTokenCount();
  }

  Future<void> _fetchPendingTokenCount() async {
    try {
      final csResult = await _coldStorageService.getMyColdStorages();
      if (csResult['success'] != true || csResult['data'] == null) return;
      final data = csResult['data'];
      dynamic storages;
      if (data is Map) {
        storages = data['coldStorages'] ?? data['data'] ?? data['cold_storages'];
      } else if (data is List) {
        storages = data;
      }
      if (storages == null || storages is! List || storages.isEmpty) return;
      final csId = storages.first['_id']?.toString();
      if (csId == null) return;

      final result = await _tokenService.getTokenQueue(csId);
      if (result['success'] == true && result['data'] != null) {
        final queueData = result['data'];
        final stats = queueData['stats'];
        if (stats != null && mounted) {
          setState(() {
            _pendingTokenCount = stats['pending'] ?? 0;
          });
        }
      }
    } catch (_) {}
  }

  /// Shows Coming Soon dialog for features under development
  static void _showComingSoonDialog(
    BuildContext context, {
    String? featureName,
  }) {
    final displayName = featureName ?? tr('feature_default');

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
        actions: [
          const LanguageToggleWidget(),
          const ColdStorageNotificationBellWidget(),
        ],
      ),

      backgroundColor: AppColors.scaffoldBg(context),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: RoleShellScrollPadding.home,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// COLD STORAGE BANNER SLIDER
              const AutoSliderBanner(
                height: 160,
                autoSlideDuration: Duration(seconds: 4),
                fetchFromServer: true,
              ),
              const SizedBox(height: 16),

              /// BOLI ALERT BANNER - Show upcoming auctions
              const BoliAlertBanner(),

              const SizedBox(height: 28),

              /// MANAGE MY STORAGE - Primary Action for Cold Storage Owners
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ManageStorageScreen(),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D7230), AppColors.primaryGreen],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGreen.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.ac_unit,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('manage_storage'),
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tr('manage_storage_sub'),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              /// BOOKING REQUESTS - View booking requests from farmers
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BookingRequestsScreen(),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade700, Colors.orange.shade500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.inbox,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('booking_requests'),
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tr('booking_requests_sub'),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              /// OTHER SERVICES
              Text(
                tr('services'),
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
                          builder: (context) => const ManageBoliAlertsScreen(),
                        ),
                      );
                    },
                    child: ServiceCard(
                      title: tr('boli_alert'),
                      image: "assets/alu.png",
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const TokenSystemScreen(),
                        ),
                      );
                    },
                    child: ServiceCard(
                      title: tr('token_system'),
                      image: "assets/alu.png",
                      badgeCount: _pendingTokenCount,
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
                          builder: (_) => const AICropAdvisorScreen(userRole: 'cold_storage'),
                        ),
                      );
                    },
                    child: ServiceCard(
                      title: tr('ai_analysis'),
                      image: "assets/al.png",
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const AlooCalculatorScreen(role: 'cold_storage'),
                        ),
                      );
                    },
                    child: ServiceCard(
                      title: tr('aloo_calculator'),
                      image: "assets/aloo_calculator.png",
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showComingSoonDialog(
                      context,
                      featureName: tr('bulk_desk'),
                    ),
                    child: ServiceCard(
                      title: tr('bulk_desk'),
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

              /// DIRECTORY
              DirectorySection(directoryItems: coldstoragedirectoryItems),

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
    );
  }
}

List<Map<String, String>> get coldstoragedirectoryItems => [
  {
    'image': 'assets/farming_labour.png',
    'title': tr('majdoor'),
    'titleEn': tr('majdoor'),
    'route': 'majdoor',
  },
  {
    'image': 'assets/transport_service.png',
    'title': tr('transportation'),
    'titleEn': tr('transportation'),
    'route': 'transportation',
  },
  {
    'image':
        'https://images.unsplash.com/photo-1590682680695-43b964a3ae17?w=200&h=200&fit=crop',
    'title': tr('gunny_bag'),
    'titleEn': tr('gunny_bag'),
    'route': 'gunny-bag',
  },
];
