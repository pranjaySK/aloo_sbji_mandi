import 'dart:convert';

import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/service/ai_crop_advisor_service.dart';
import '../core/service/market_intelligence_service.dart';

class AICropAdvisorScreen extends StatefulWidget {
  final int initialTab;
  final String? userRole;
  const AICropAdvisorScreen({super.key, this.initialTab = 0, this.userRole});

  @override
  State<AICropAdvisorScreen> createState() => _AICropAdvisorScreenState();
}

class _AICropAdvisorScreenState extends State<AICropAdvisorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _role = 'farmer';

  bool get isHindi => AppLocalizations.isHindi;

  @override
  void initState() {
    super.initState();
    _role = widget.userRole ?? 'farmer';
    if (widget.userRole == null) {
      _loadRole();
    }
    _initTabController();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    if (userJson != null) {
      try {
        final userData = json.decode(userJson);
        final role = userData['role'] ?? 'farmer';
        if (role != _role && mounted) {
          setState(() {
            _role = role;
            _tabController.dispose();
            _initTabController();
          });
        }
      } catch (_) {}
    }
  }

  void _initTabController() {
    final tabCount = _getTabsForRole().length;
    _tabController = TabController(
      length: tabCount,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, tabCount - 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Returns tabs and their builders based on user role
  List<_TabConfig> _getTabsForRole() {
    switch (_role) {
      case 'vyapari':
        return [
          _TabConfig(
            tab: Tab(icon: const Icon(Icons.analytics, size: 20), text: tr('market_ai_tab')),
            builder: () => _buildMarketAITab(),
          ),
          _TabConfig(
            tab: Tab(icon: const Icon(Icons.today, size: 20), text: tr('today_tab')),
            builder: () => _buildTodayAdviceTab(),
          ),
        ];
      case 'cold_storage':
        return [
          _TabConfig(
            tab: Tab(icon: const Icon(Icons.analytics, size: 20), text: tr('market_ai_tab')),
            builder: () => _buildMarketAITab(),
          ),
          _TabConfig(
            tab: Tab(icon: const Icon(Icons.today, size: 20), text: tr('today_tab')),
            builder: () => _buildTodayAdviceTab(),
          ),
        ];
      case 'farmer':
      default:
        return [
          _TabConfig(
            tab: Tab(icon: const Icon(Icons.today, size: 20), text: tr('today_tab')),
            builder: () => _buildTodayAdviceTab(),
          ),
          _TabConfig(
            tab: Tab(icon: const Icon(Icons.analytics, size: 20), text: tr('market_ai_tab')),
            builder: () => _buildMarketAITab(),
          ),
          _TabConfig(
            tab: Tab(icon: const Icon(Icons.eco, size: 20), text: tr('seeds_tab')),
            builder: () => _buildSeedGuideTab(),
          ),
          _TabConfig(
            tab: Tab(icon: const Icon(Icons.bug_report, size: 20), text: tr('disease_tab')),
            builder: () => _buildDiseaseGuideTab(),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _getTabsForRole();

    return ListenableBuilder(
      listenable: AppLocalizations.instance,
      builder: (context, _) => Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildLanguageToggle(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                key: ValueKey(isHindi),
                controller: _tabController,
                children: tabs.map((t) => t.builder()).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: const Color(0xFF2E7D32),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.psychology, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('ai_crop_advisor_title'),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                tr('your_farming_assistant'),
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageToggle() {
    return Container(
      color: const Color(0xFF2E7D32),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'English',
            style: GoogleFonts.poppins(
              color: !isHindi ? Colors.white : Colors.white54,
              fontWeight: !isHindi ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: isHindi,
            onChanged: (value) =>
                AppLocalizations.setLocale(value ? 'hi' : 'en'),
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.white38,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white38,
          ),
          const SizedBox(width: 8),
          Text(
            tr('hindi_lang'),
            style: GoogleFonts.poppins(
              color: isHindi ? Colors.white : Colors.white54,
              fontWeight: isHindi ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF2E7D32),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
        tabs: _getTabsForRole().map((t) => t.tab).toList(),
      ),
    );
  }

  // ==================== MARKET AI TAB ====================
  Widget _buildMarketAITab() {
    return _MarketAIWidget(isHindi: isHindi);
  }

  // ==================== TODAY'S ADVICE TAB ====================
  Widget _buildTodayAdviceTab() {
    final recommendations = AICropAdvisorService.getCropRecommendations(
      isHindi: isHindi,
    );
    final tips = AICropAdvisorService.getDailyTips(isHindi: isHindi);
    final marketAdvice = AICropAdvisorService.getMarketAdvice(isHindi: isHindi);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Season Status Card
          _buildSeasonCard(recommendations),
          const SizedBox(height: 16),

          // Main Advice
          _buildMainAdviceCard(recommendations),
          const SizedBox(height: 16),

          // Activities
          Text(
            tr('activities_to_do'),
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(
            (recommendations['activities'] as List).length,
            (index) => _buildActivityCard(recommendations['activities'][index]),
          ),
          const SizedBox(height: 20),

          // Market Advice
          _buildMarketAdviceCard(marketAdvice),
          const SizedBox(height: 20),

          // Daily Tips
          Text(
            tr('tips_for_today'),
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...tips.map((tip) => _buildTipCard(tip)),
        ],
      ),
    );
  }

  Widget _buildSeasonCard(Map<String, dynamic> recommendations) {
    final statusColors = {
      'green': Colors.green,
      'blue': Colors.blue,
      'orange': Colors.orange,
      'teal': Colors.teal,
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColors[recommendations['statusColor']] ?? Colors.green,
            (statusColors[recommendations['statusColor']] ?? Colors.green)
                .withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:
                (statusColors[recommendations['statusColor']] ?? Colors.green)
                    .withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.wb_sunny, color: Colors.white, size: 40),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recommendations['season'] ?? '',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    recommendations['status'] ?? '',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
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

  Widget _buildMainAdviceCard(Map<String, dynamic> recommendations) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lightbulb, color: Colors.blue, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              recommendations['mainAdvice'] ?? '',
              style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final priorityColors = {
      'high': Colors.red,
      'medium': Colors.orange,
      'low': Colors.green,
    };

    final iconMap = {
      'agriculture': Icons.agriculture,
      'water_drop': Icons.water_drop,
      'science': Icons.science,
      'landscape': Icons.landscape,
      'bug_report': Icons.bug_report,
      'terrain': Icons.terrain,
      'eco': Icons.eco,
      'ac_unit': Icons.ac_unit,
      'sort': Icons.sort,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (priorityColors[activity['priority']] ?? Colors.grey)
              .withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (priorityColors[activity['priority']] ?? Colors.grey)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              iconMap[activity['icon']] ?? Icons.check_circle,
              color: priorityColors[activity['priority']] ?? Colors.grey,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        activity['title'] ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: priorityColors[activity['priority']]
                            ?.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        activity['priority'] == 'high'
                            ? tr('priority')
                            : tr('normal'),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: priorityColors[activity['priority']],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  activity['description'] ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketAdviceCard(Map<String, dynamic> marketAdvice) {
    final outlookColors = {
      'bullish': Colors.green,
      'neutral': Colors.orange,
      'stable': Colors.blue,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, color: Colors.amber, size: 24),
              const SizedBox(width: 8),
              Text(
                tr('market_advice'),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: outlookColors[marketAdvice['priceOutlook']]
                      ?.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  marketAdvice['timing'] ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: outlookColors[marketAdvice['priceOutlook']],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            marketAdvice['advice'] ?? '',
            style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(String tip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(tip, style: GoogleFonts.poppins(fontSize: 14)),
    );
  }

  // ==================== SEED GUIDE TAB ====================
  Widget _buildSeedGuideTab() {
    final seeds = AICropAdvisorService.getSeedRecommendations(isHindi: isHindi);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.eco, color: Colors.white, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('best_potato_varieties'),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        tr('choose_certified_seeds'),
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Seed Cards
          ...seeds.map((seed) => _buildSeedCard(seed)),
        ],
      ),
    );
  }

  Widget _buildSeedCard(Map<String, dynamic> seed) {
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
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: seed['recommended'] == true
                  ? Colors.green.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.eco, color: Colors.green, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isHindi ? seed['nameHindi'] : seed['name'],
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (seed['recommended'] == true)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tr('recommended'),
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        seed['type'] ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildSeedStat(
                      icon: Icons.timer,
                      label: tr('days_label'),
                      value: seed['days'] ?? '',
                    ),
                    _buildSeedStat(
                      icon: Icons.inventory,
                      label: tr('yield_per_acre'),
                      value: seed['yield'] ?? '',
                    ),
                    _buildSeedStat(
                      icon: Icons.star,
                      label: tr('rating_label'),
                      value: '${seed['rating']}',
                      isRating: true,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        seed['features'] ?? '',
                        style: GoogleFonts.poppins(fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${tr('best_for')}${seed['bestFor']}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeedStat({
    required IconData icon,
    required String label,
    required String value,
    bool isRating = false,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: isRating ? Colors.amber : Colors.green, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isRating ? Colors.amber[700] : Colors.black87,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ==================== DISEASE GUIDE TAB ====================
  Widget _buildDiseaseGuideTab() {
    final diseases = AICropAdvisorService.getDiseaseGuide(isHindi: isHindi);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEF5350), Color(0xFFE53935)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.healing, color: Colors.white, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('disease_identification'),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        tr('early_detection'),
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Disease Cards
          ...diseases.map((disease) => _buildDiseaseCard(disease)),
        ],
      ),
    );
  }

  Widget _buildDiseaseCard(Map<String, dynamic> disease) {
    final severityColors = {
      'high': Colors.red,
      'medium': Colors.orange,
      'low': Colors.green,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (severityColors[disease['severity']] ?? Colors.grey)
              .withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (severityColors[disease['severity']] ?? Colors.grey)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.bug_report,
              color: severityColors[disease['severity']] ?? Colors.grey,
              size: 24,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  disease['name'] ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: severityColors[disease['severity']]?.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  disease['severity'] == 'high'
                      ? tr('severe')
                      : disease['severity'] == 'medium'
                      ? tr('moderate')
                      : tr('mild'),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: severityColors[disease['severity']],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Text(
            disease['symptoms'] ?? '',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
          ),
          children: [
            _buildDiseaseInfo(
              icon: Icons.healing,
              title: tr('treatment_label'),
              content: disease['solution'] ?? '',
              color: Colors.green,
            ),
            const SizedBox(height: 10),
            _buildDiseaseInfo(
              icon: Icons.shield,
              title: tr('prevention'),
              content: disease['prevention'] ?? '',
              color: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiseaseInfo({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(content, style: GoogleFonts.poppins(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== PROFIT CALCULATOR TAB ====================
  Widget _buildProfitCalculatorTab() {
    return _ProfitCalculator(isHindi: isHindi);
  }
}

/// Helper class for role-specific tab configuration
class _TabConfig {
  final Tab tab;
  final Widget Function() builder;
  const _TabConfig({required this.tab, required this.builder});
}

class _ProfitCalculator extends StatefulWidget {
  final bool isHindi;

  const _ProfitCalculator({required this.isHindi});

  @override
  State<_ProfitCalculator> createState() => _ProfitCalculatorState();
}

class _ProfitCalculatorState extends State<_ProfitCalculator> {
  final _landController = TextEditingController(text: '1');
  final _seedCostController = TextEditingController(text: '25');
  final _yieldController = TextEditingController(text: '250');
  final _priceController = TextEditingController(text: '15');

  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _landController.dispose();
    _seedCostController.dispose();
    _yieldController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _calculate() {
    final land = double.tryParse(_landController.text) ?? 1;
    final seedCost = double.tryParse(_seedCostController.text) ?? 25;
    final yield_ = double.tryParse(_yieldController.text) ?? 250;
    final price = double.tryParse(_priceController.text) ?? 15;

    setState(() {
      _result = AICropAdvisorService.calculateProfit(
        landAcres: land,
        seedCostPerKg: seedCost,
        expectedYieldPerAcre: yield_,
        expectedPricePerKg: price,
        isHindi: widget.isHindi,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7B1FA2), Color(0xFF9C27B0)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.calculate, color: Colors.white, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('profit_calculator'),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        tr('know_estimated_profit'),
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Input Fields
          Container(
            padding: const EdgeInsets.all(16),
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
                _buildInputField(
                  controller: _landController,
                  label: tr('land_acres'),
                  icon: Icons.landscape,
                  suffix: tr('acres'),
                ),
                const SizedBox(height: 12),
                _buildInputField(
                  controller: _seedCostController,
                  label: tr('seed_cost_per_kg'),
                  icon: Icons.eco,
                  suffix: '₹/kg',
                ),
                const SizedBox(height: 12),
                _buildInputField(
                  controller: _yieldController,
                  label: tr('expected_yield_per_acre'),
                  icon: Icons.inventory,
                  suffix: 'Q/Acre',
                ),
                const SizedBox(height: 12),
                _buildInputField(
                  controller: _priceController,
                  label: tr('selling_price_per_kg'),
                  icon: Icons.currency_rupee,
                  suffix: '₹/kg',
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _calculate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      tr('calculate_btn'),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_result != null) ...[
            const SizedBox(height: 20),
            _buildResultCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: GoogleFonts.poppins(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFF2E7D32)),
        suffixText: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildResultCard() {
    final profit = _result!['profit'] as double;
    final isProfit = profit > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isProfit
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isProfit
              ? Colors.green.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Main Result
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isProfit ? Icons.trending_up : Icons.trending_down,
                color: isProfit ? Colors.green : Colors.red,
                size: 40,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isProfit ? tr('estimated_profit') : tr('estimated_loss'),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    '₹ ${profit.abs().toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isProfit ? Colors.green[700] : Colors.red[700],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Summary Grid
          Row(
            children: [
              _buildSummaryItem(
                label: tr('total_cost'),
                value:
                    '₹ ${(_result!['totalCost'] as double).toStringAsFixed(0)}',
                icon: Icons.shopping_cart,
                color: Colors.orange,
              ),
              _buildSummaryItem(
                label: tr('total_revenue'),
                value:
                    '₹ ${(_result!['totalRevenue'] as double).toStringAsFixed(0)}',
                icon: Icons.account_balance_wallet,
                color: Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSummaryItem(
                label: tr('total_yield'),
                value:
                    '${(_result!['totalYield'] as double).toStringAsFixed(0)} Q',
                icon: Icons.inventory_2,
                color: Colors.teal,
              ),
              _buildSummaryItem(
                label: tr('profit_per_acre'),
                value:
                    '₹ ${(_result!['profitPerAcre'] as double).toStringAsFixed(0)}',
                icon: Icons.landscape,
                color: Colors.purple,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Cost Breakdown
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('cost_breakdown'),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...(_result!['breakdown'] as Map<String, dynamic>).entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key, style: GoogleFonts.poppins(fontSize: 13)),
                        Text(
                          '₹ ${(e.value as double).toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== MARKET AI WIDGET ====================
class _MarketAIWidget extends StatefulWidget {
  final bool isHindi;

  const _MarketAIWidget({required this.isHindi});

  @override
  State<_MarketAIWidget> createState() => _MarketAIWidgetState();
}

class _MarketAIWidgetState extends State<_MarketAIWidget> {
  bool _isLoading = true;
  MarketTrend? _trend;
  AIMarketDecision? _decision;
  List<Map<String, dynamic>> _mandiPrices = [];
  Map<String, dynamic>? _forecast;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMarketData();
  }

  Future<void> _loadMarketData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        MarketIntelligenceService.analyzeMarketTrend(isHindi: widget.isHindi),
        MarketIntelligenceService.getAIDecision(isHindi: widget.isHindi),
        MarketIntelligenceService.getMandiBuyer(isHindi: widget.isHindi),
      ]);

      setState(() {
        _trend = results[0] as MarketTrend;
        _decision = results[1] as AIMarketDecision;
        _mandiPrices = (results[2] as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        _forecast = MarketIntelligenceService.getPriceForecast(
          isHindi: widget.isHindi,
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF2E7D32)),
            const SizedBox(height: 16),
            Text(
              tr('analyzing_market'),
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              tr('failed_load_data'),
              style: GoogleFonts.poppins(fontSize: 16),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadMarketData,
              child: Text(tr('retry_btn')),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMarketData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI Decision Card
            _buildAIDecisionCard(),
            const SizedBox(height: 16),

            // Market Trend Card
            _buildMarketTrendCard(),
            const SizedBox(height: 16),

            // Price Forecast
            _buildPriceForecastCard(),
            const SizedBox(height: 16),

            // Mandi Comparison
            Text(
              tr('mandi_price_comparison'),
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ..._mandiPrices.map((mandi) => _buildMandiCard(mandi)),

            const SizedBox(height: 16),

            // Analysis Factors
            if (_decision != null) _buildFactorsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildAIDecisionCard() {
    if (_decision == null) return const SizedBox();

    final decisionColors = {
      'sell_now': Colors.green,
      'hold': Colors.orange,
      'wait': Colors.blue,
    };

    final decisionIcons = {
      'sell_now': Icons.sell,
      'hold': Icons.inventory_2,
      'wait': Icons.hourglass_empty,
    };

    final decisionTitles = {
      'sell_now': tr('sell_now'),
      'hold': tr('hold'),
      'wait': tr('wait_label'),
    };

    final color = decisionColors[_decision!.decision] ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  decisionIcons[_decision!.decision] ?? Icons.analytics,
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
                      tr('ai_decision'),
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      decisionTitles[_decision!.decision] ?? '',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.psychology, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${_decision!.confidenceLevel}%',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.isHindi ? _decision!.reasonHindi : _decision!.reason,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.isHindi
                    ? '${tr('expected_change_label')}: ${_decision!.expectedPriceChange >= 0 ? '+' : ''}${_decision!.expectedPriceChange.toStringAsFixed(1)}%'
                    : 'Expected Change: ${_decision!.expectedPriceChange >= 0 ? '+' : ''}${_decision!.expectedPriceChange.toStringAsFixed(1)}%',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
              ),
              Text(
                widget.isHindi
                    ? '${tr('valid_until_label')}: ${_decision!.validUntil.day}/${_decision!.validUntil.month}'
                    : 'Valid until: ${_decision!.validUntil.day}/${_decision!.validUntil.month}',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMarketTrendCard() {
    if (_trend == null) return const SizedBox();

    final trendColors = {
      'bullish': Colors.green,
      'bearish': Colors.red,
      'stable': Colors.blue,
    };

    final trendIcons = {
      'bullish': Icons.trending_up,
      'bearish': Icons.trending_down,
      'stable': Icons.trending_flat,
    };

    final color = trendColors[_trend!.trend] ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(trendIcons[_trend!.trend], color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('market_trend'),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      _trend!.trend == 'bullish'
                          ? tr('bullish')
                          : _trend!.trend == 'bearish'
                          ? tr('bearish')
                          : tr('stable'),
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${_trend!.currentAvgPrice.toStringAsFixed(1)}/kg',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_trend!.changePercent >= 0 ? '+' : ''}${_trend!.changePercent.toStringAsFixed(1)}%',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: _trend!.changePercent >= 0
                          ? Colors.green
                          : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.isHindi
                        ? _trend!.recommendationHindi
                        : _trend!.recommendation,
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceForecastCard() {
    if (_forecast == null) return const SizedBox();

    final forecasts = (_forecast!['forecast'] as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph, color: Colors.purple, size: 24),
              const SizedBox(width: 8),
              Text(
                tr('four_week_forecast'),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_forecast!['confidence']}% ${tr('confidence')}',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.purple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: forecasts.map((f) {
              final isPositive = (f['change'] as double) >= 0;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isPositive ? Colors.green : Colors.red).withOpacity(
                      0.1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        f['week'],
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${(f['price'] as double).toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        f['changeText'],
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: isPositive ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _forecast!['trend'],
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.purple,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMandiCard(Map<String, dynamic> mandi) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.brown.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.store, color: Colors.brown, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mandi['market'],
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  mandi['state'],
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                mandi['priceDisplay'],
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2E7D32),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (mandi['price'] as double) > 18
                      ? Colors.green.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  mandi['recommendation'],
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: (mandi['price'] as double) > 18
                        ? Colors.green
                        : Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFactorsCard() {
    final factors = widget.isHindi
        ? _decision!.factorsHindi
        : _decision!.factors;
    if (factors.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, color: Colors.indigo, size: 24),
              const SizedBox(width: 8),
              Text(
                tr('analysis_factors'),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...factors.map(
            (factor) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.indigo,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      factor,
                      style: GoogleFonts.poppins(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
