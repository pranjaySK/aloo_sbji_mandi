import 'package:aloo_sbji_mandi/core/service/aloo_mitra_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/role_shell_scroll_padding.dart';
import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:aloo_sbji_mandi/screens/aloo_mitra/aloo_mitra_seed_listings_screen.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:aloo_sbji_mandi/widgets/common_widget.dart/auto_slider_widget.dart';
import 'package:aloo_sbji_mandi/widgets/common_widget.dart/custom_drawer_widget.dart';
import 'package:aloo_sbji_mandi/widgets/common_widget.dart/news_section_widget.dart'
    show NewsSectionWidget;
import 'package:aloo_sbji_mandi/widgets/common_widget.dart/weather_card.dart';
import 'package:aloo_sbji_mandi/widgets/language_toggle_widget.dart';
import 'package:aloo_sbji_mandi/widgets/notification_bell_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AlooMitraHomeScreen extends StatefulWidget {
  const AlooMitraHomeScreen({super.key});

  @override
  State<AlooMitraHomeScreen> createState() => _AlooMitraHomeScreenState();
}

class _AlooMitraHomeScreenState extends State<AlooMitraHomeScreen> {
  final AlooMitraService _alooMitraService = AlooMitraService();

  Map<String, dynamic>? _profileData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final profileResult = await _alooMitraService.getAlooMitraProfile();

      if (mounted) {
        setState(() {
          _profileData = profileResult['success']
              ? profileResult['data']
              : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getServiceTypeLabel(String? serviceType) {
    switch (serviceType) {
      case 'potato-seeds':
        return tr('potato_seeds');
      case 'fertilizers':
        return tr('fertilizers_medicines');
      case 'machinery-rent':
        return tr('machinery_rent');
      case 'transportation':
        return tr('transportation');
      case 'gunny-bag':
        return tr('gunny_bag');
      case 'majdoor':
        return tr('majdoor');
      default:
        return tr('service_provider');
    }
  }

  IconData _getServiceIcon(String? serviceType) {
    switch (serviceType) {
      case 'potato-seeds':
        return Icons.eco;
      case 'fertilizers':
        return Icons.science;
      case 'machinery-rent':
        return Icons.agriculture;
      case 'transportation':
        return Icons.local_shipping;
      case 'gunny-bag':
        return Icons.inventory_2;
      case 'majdoor':
        return Icons.engineering;
      default:
        return Icons.handshake;
    }
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
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: RoleShellScrollPadding.home,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// BANNER SLIDER
                      const AutoSliderBanner(
                        height: 160,
                        autoSlideDuration: Duration(seconds: 4),
                        fetchFromServer: true,
                      ),
                      const SizedBox(height: 16),

                      /// WELCOME CARD
                      _buildWelcomeCard(),
                      const SizedBox(height: 16),

                      /// QUICK ACTIONS
                      _buildQuickActionsSection(),
                      const SizedBox(height: 16),

                      /// RECENT ENQUIRIES
                      _buildRecentEnquiriesSection(),
                      const SizedBox(height: 16),

                      /// NEWS SECTION
                      NewsSectionWidget(),
                      const SizedBox(height: 16),

                      /// WEATHER CARD
                      const WeatherCard(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final businessName = _profileData?['businessName'] ?? 'Aloo Mitra';
    final serviceType = _profileData?['serviceType'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryGreen, Color(0xFF2E7D32)],
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
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getServiceIcon(serviceType),
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('welcome'),
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  businessName,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getServiceTypeLabel(serviceType),
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
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    final serviceType = _profileData?['serviceType'];
    final isPotatoSeedProvider = serviceType == 'potato-seeds';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('quick_actions'),
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),

        // Show Seed Listings option for Potato Seeds service type
        if (isPotatoSeedProvider) ...[
          _buildSeedListingCard(),
          const SizedBox(height: 12),
        ],

        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.edit,
                label: tr('edit_profile'),
                onTap: () => Navigator.pushNamed(context, '/edit_profile'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.add_circle,
                label: tr('add_service'),
                onTap: () => _showComingSoonDialog('Add Service'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.message,
                label: tr('view_messages'),
                onTap: () => Navigator.pushNamed(context, '/conversations'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.history,
                label: tr('transactions'),
                onTap: () =>
                    Navigator.pushNamed(context, '/transaction_history'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Build the seed listing management card for Potato Seed providers
  Widget _buildSeedListingCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AlooMitraSeedListingsScreen(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGreen.withOpacity(0.3),
              blurRadius: 8,
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
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.eco, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('seed_listings'),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr('seed_listings_sub'),
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white70,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primaryGreen.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primaryGreen, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentEnquiriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              tr('recent_enquiries'),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            TextButton(
              onPressed: () => _showComingSoonDialog('All Enquiries'),
              child: Text(
                tr('view_all'),
                style: GoogleFonts.inter(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardBg(context),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
            ],
          ),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.inbox_outlined, size: 50, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  tr('no_enquiries'),
                  style: GoogleFonts.inter(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showComingSoonDialog(String featureName) {
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
                child: const Icon(
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
                "$featureName ${tr('under_development')}.\nStay tuned!",
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
}
