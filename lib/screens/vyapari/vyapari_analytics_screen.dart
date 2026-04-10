import 'package:aloo_sbji_mandi/core/service/vyapari_analytics_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VyapariAnalyticsScreen extends StatefulWidget {
  const VyapariAnalyticsScreen({super.key});

  @override
  State<VyapariAnalyticsScreen> createState() => _VyapariAnalyticsScreenState();
}

class _VyapariAnalyticsScreenState extends State<VyapariAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _data;
  late AnimationController _pulseController;

  bool get isHindi => AppLocalizations.isHindi;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _loadInsights();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadInsights() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await VyapariAnalyticsService.getVyapariInsights();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _data = result['data'];
      } else {
        _error = result['message'] ?? 'Unknown error';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.insights, size: 24),
            const SizedBox(width: 8),
            Text(
              tr('ai_trade_advisor'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadInsights,
            icon: const Icon(Icons.refresh),
            tooltip: tr('refresh'),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
          ? _buildErrorState()
          : _buildInsightsBody(),
    );
  }

  // ─── Loading ──────────────────────────────────
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 0.9 + _pulseController.value * 0.2,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primaryGreen.withOpacity(0.3),
                        AppColors.primaryGreen.withOpacity(0.1),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.psychology,
                    size: 40,
                    color: AppColors.primaryGreen,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            tr('ai_analyzing_market'),
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            tr('preparing_insights'),
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ─── Error ──────────────────────────────────
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              tr('could_not_load'),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadInsights,
              icon: const Icon(Icons.refresh),
              label: Text(tr('retry_btn')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Main Insights Body ──────────────────────
  Widget _buildInsightsBody() {
    final d = _data!;
    final rate = d['ratePrediction'] as Map<String, dynamic>? ?? {};
    final demand = d['demandAlert'] as Map<String, dynamic>? ?? {};
    final riskyDeals =
        (d['riskyDeals'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final buyTime = d['bestBuyingTime'] as Map<String, dynamic>? ?? {};
    final negotiation = d['negotiation'] as Map<String, dynamic>? ?? {};
    final perf = d['performance'] as Map<String, dynamic>? ?? {};
    final meta = d['meta'] as Map<String, dynamic>? ?? {};

    return RefreshIndicator(
      onRefresh: _loadInsights,
      color: AppColors.primaryGreen,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Quick summary bar
          _buildSummaryBar(rate, buyTime),
          const SizedBox(height: 14),

          // 1. Rate Prediction
          _buildRatePredictionCard(rate),
          const SizedBox(height: 12),

          // 2. Best Buying Time
          _buildBuyTimeCard(buyTime),
          const SizedBox(height: 12),

          // 3. Price Negotiation
          _buildNegotiationCard(negotiation),
          const SizedBox(height: 12),

          // 4. Demand Alert
          _buildDemandAlertCard(demand),
          const SizedBox(height: 12),

          // 5. Risky Deals
          _buildRiskyDealsCard(riskyDeals),
          const SizedBox(height: 12),

          // 6. Performance
          _buildPerformanceCard(perf),
          const SizedBox(height: 12),

          // Footer
          _buildFooter(meta),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ─── Summary Bar ──────────────────────────────
  Widget _buildSummaryBar(
    Map<String, dynamic> rate,
    Map<String, dynamic> buyTime,
  ) {
    final direction = rate['predictedDirection'] ?? 'Stable';
    final rec = buyTime['recommendation'] ?? 'Wait';
    final price = rate['currentAvgPrice'] ?? 0;

    Color dirColor = Colors.amber;
    IconData dirIcon = Icons.trending_flat;
    if (direction == 'Rising') {
      dirColor = Colors.green;
      dirIcon = Icons.trending_up;
    } else if (direction == 'Falling') {
      dirColor = Colors.red;
      dirIcon = Icons.trending_down;
    }

    Color recColor = Colors.orange;
    if (rec == 'Buy Now') recColor = Colors.green;
    if (rec == 'Wait') recColor = Colors.red.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen,
            AppColors.primaryGreen.withOpacity(0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('market_rate'),
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                ),
                Text(
                  '₹$price/${tr('quintal_abbr')}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          // Trend
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: dirColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(dirIcon, size: 18, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  direction,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Buy recommendation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: recColor.withOpacity(0.25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white38),
            ),
            child: Text(
              rec == 'Buy Now'
                  ? tr('buy_now_label')
                  : rec == 'Wait'
                  ? tr('wait_advice')
                  : tr('buy_small'),
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 1. Rate Prediction ──────────────────────
  Widget _buildRatePredictionCard(Map<String, dynamic> rate) {
    final direction = rate['predictedDirection'] ?? 'Stable';
    final confidence = rate['confidence'] ?? 'Medium';
    final changePercent = (rate['predictedChangePercent'] ?? 0).toDouble();
    final priceRange =
        rate['predictedPriceRange'] as Map<String, dynamic>? ?? {};
    final low = priceRange['low'] ?? 0;
    final high = priceRange['high'] ?? 0;
    final reason = isHindi
        ? (rate['reasonHi'] ?? rate['reason'] ?? '')
        : (rate['reason'] ?? '');
    final horizon = rate['horizon'] ?? '3-7 days';

    Color trendColor = Colors.amber.shade700;
    IconData trendIcon = Icons.trending_flat;
    String trendLabel = tr('stable_trend');
    if (direction == 'Rising') {
      trendColor = Colors.green.shade700;
      trendIcon = Icons.trending_up;
      trendLabel = tr('rising_trend');
    } else if (direction == 'Falling') {
      trendColor = Colors.red.shade700;
      trendIcon = Icons.trending_down;
      trendLabel = tr('falling_trend');
    }

    Color confColor = Colors.orange;
    if (confidence == 'High') confColor = Colors.green;
    if (confidence == 'Low') confColor = Colors.red;

    return _insightCard(
      icon: Icons.show_chart,
      iconColor: Colors.blue.shade700,
      iconBg: Colors.blue.shade50,
      title: tr('ai_rate_prediction'),
      badge: '$horizon',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trend row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: trendColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: trendColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(trendIcon, color: trendColor, size: 22),
                    const SizedBox(width: 6),
                    Text(
                      trendLabel,
                      style: GoogleFonts.inter(
                        color: trendColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${changePercent >= 0 ? "+" : ""}${changePercent.toStringAsFixed(1)}%',
                style: GoogleFonts.inter(
                  color: trendColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              // Confidence badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: confColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${tr('confidence_label')}: $confidence',
                  style: GoogleFonts.inter(
                    color: confColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Predicted range
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _miniStat(
                  tr('low_label'),
                  '₹$low/${tr('quintal_abbr')}',
                  Colors.red.shade600,
                ),
                Container(width: 1, height: 30, color: Colors.grey.shade300),
                _miniStat(
                  tr('high_label'),
                  '₹$high/${tr('quintal_abbr')}',
                  Colors.green.shade600,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            reason,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ─── 2. Best Buying Time ─────────────────────
  Widget _buildBuyTimeCard(Map<String, dynamic> buyTime) {
    final rec = buyTime['recommendation'] ?? 'Wait';
    final reason = isHindi
        ? (buyTime['reasonHi'] ?? buyTime['reason'] ?? '')
        : (buyTime['reason'] ?? '');
    final season = buyTime['season'] ?? '';

    Color recColor = Colors.orange;
    IconData recIcon = Icons.access_time;
    String recLabel = rec;
    if (rec == 'Buy Now') {
      recColor = Colors.green.shade700;
      recIcon = Icons.check_circle;
      recLabel = tr('buy_now_action');
    } else if (rec == 'Wait') {
      recColor = Colors.red.shade700;
      recIcon = Icons.pause_circle;
      recLabel = tr('wait_action');
    } else {
      recColor = Colors.orange.shade700;
      recIcon = Icons.shopping_bag;
      recLabel = tr('buy_small_action');
    }

    return _insightCard(
      icon: Icons.timer,
      iconColor: Colors.teal.shade700,
      iconBg: Colors.teal.shade50,
      title: tr('best_buying_time'),
      badge: season,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: recColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: recColor.withOpacity(0.3), width: 1.5),
            ),
            child: Row(
              children: [
                Icon(recIcon, color: recColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    recLabel,
                    style: GoogleFonts.inter(
                      color: recColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            reason,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ─── 3. Price Negotiation ────────────────────
  Widget _buildNegotiationCard(Map<String, dynamic> neg) {
    final marketAvg = neg['marketAvgPrice'] ?? 0;
    final idealPrice = neg['idealBuyPrice'] ?? 0;
    final floor = neg['floorPrice'] ?? 0;
    final ceiling = neg['ceilingPrice'] ?? 0;
    final tip = isHindi
        ? (neg['tipHi'] ?? neg['tip'] ?? '')
        : (neg['tip'] ?? '');

    return _insightCard(
      icon: Icons.handshake,
      iconColor: Colors.purple.shade700,
      iconBg: Colors.purple.shade50,
      title: tr('negotiation_tip'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Price bar visual
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _priceLabel(
                      tr('floor_label'),
                      '₹$floor',
                      Colors.green.shade700,
                    ),
                    _priceLabel(
                      tr('ideal_label'),
                      '₹$idealPrice',
                      Colors.blue.shade700,
                    ),
                    _priceLabel(
                      tr('ceiling_label'),
                      '₹$ceiling',
                      Colors.orange.shade700,
                    ),
                    _priceLabel(
                      tr('market_label'),
                      '₹$marketAvg',
                      Colors.red.shade700,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Visual bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 8,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(color: Colors.green.shade400),
                        ),
                        Expanded(
                          flex: 2,
                          child: Container(color: Colors.blue.shade400),
                        ),
                        Expanded(
                          flex: 2,
                          child: Container(color: Colors.orange.shade400),
                        ),
                        Expanded(
                          flex: 1,
                          child: Container(color: Colors.red.shade400),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '₹$floor',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '₹$marketAvg',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tip,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.brown.shade700,
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

  // ─── 4. Demand Alert ─────────────────────────
  Widget _buildDemandAlertCard(Map<String, dynamic> demand) {
    final trend = demand['trend'] ?? 'Normal';
    final alertLevel = demand['alertLevel'] ?? 'None';
    final reason = isHindi
        ? (demand['reasonHi'] ?? demand['reason'] ?? '')
        : (demand['reason'] ?? '');

    Color alertColor = Colors.grey;
    IconData alertIcon = Icons.check_circle_outline;
    if (trend.contains('Increasing')) {
      alertColor = Colors.orange.shade700;
      alertIcon = Icons.arrow_upward;
    } else if (trend.contains('Decreasing')) {
      alertColor = Colors.red.shade700;
      alertIcon = Icons.arrow_downward;
    } else {
      alertColor = Colors.green.shade700;
      alertIcon = Icons.check_circle_outline;
    }

    return _insightCard(
      icon: Icons.notifications_active,
      iconColor: Colors.orange.shade700,
      iconBg: Colors.orange.shade50,
      title: tr('demand_alert'),
      badge: alertLevel != 'None' ? alertLevel : null,
      badgeColor: alertLevel == 'High'
          ? Colors.red
          : alertLevel == 'Medium'
          ? Colors.orange
          : Colors.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(alertIcon, color: alertColor, size: 24),
              const SizedBox(width: 8),
              Text(
                trend,
                style: GoogleFonts.inter(
                  color: alertColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reason,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ─── 5. Risky Deals ──────────────────────────
  Widget _buildRiskyDealsCard(List<Map<String, dynamic>> riskyDeals) {
    return _insightCard(
      icon: Icons.warning_amber,
      iconColor: Colors.red.shade700,
      iconBg: Colors.red.shade50,
      title: tr('risky_deal_alerts'),
      badge: riskyDeals.isNotEmpty ? '${riskyDeals.length}' : null,
      badgeColor: Colors.red,
      child: riskyDeals.isEmpty
          ? Row(
              children: [
                Icon(
                  Icons.verified_user,
                  color: Colors.green.shade600,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('no_risky_deals_msg'),
                    style: GoogleFonts.inter(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            )
          : Column(
              children: riskyDeals.map((deal) {
                final riskLevel = deal['riskLevel'] ?? 'Low';
                final risks = (deal['risks'] as List?)?.cast<String>() ?? [];
                final other = deal['otherParty'] ?? 'Unknown';
                final qty = deal['quantity'] ?? 0;

                Color rColor = Colors.green;
                if (riskLevel == 'High') rColor = Colors.red;
                if (riskLevel == 'Medium') rColor = Colors.orange;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: rColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: rColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: rColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              riskLevel,
                              style: GoogleFonts.inter(
                                color: rColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$other • $qty ${tr('pkts')}',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...risks.map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• ',
                                style: TextStyle(color: rColor, fontSize: 12),
                              ),
                              Expanded(
                                child: Text(
                                  r,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ─── 6. Performance ──────────────────────────
  Widget _buildPerformanceCard(Map<String, dynamic> perf) {
    final totalDeals = perf['totalDeals'] ?? 0;
    final activeDeals = perf['activeDeals'] ?? 0;
    final avgMargin = (perf['avgMarginPercent'] ?? 0).toDouble();
    final bestMonth = perf['bestBuyingMonth'] ?? 'N/A';
    final tips = isHindi
        ? ((perf['tipsHi'] as List?)?.cast<String>() ?? [])
        : ((perf['tips'] as List?)?.cast<String>() ?? []);

    return _insightCard(
      icon: Icons.bar_chart,
      iconColor: Colors.indigo.shade700,
      iconBg: Colors.indigo.shade50,
      title: tr('trade_performance'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats row
          Row(
            children: [
              Expanded(
                child: _statBox(
                  tr('closed_label'),
                  '$totalDeals',
                  Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statBox(
                  tr('active_label'),
                  '$activeDeals',
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statBox(
                  tr('avg_margin'),
                  '${avgMargin.toStringAsFixed(1)}%',
                  avgMargin >= 5 ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statBox(tr('best_month'), bestMonth, Colors.blue),
              ),
            ],
          ),
          if (tips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              tr('tips_label'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            ...tips.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💡 ', style: TextStyle(fontSize: 13)),
                    Expanded(
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Footer ══════════════════════════════════
  Widget _buildFooter(Map<String, dynamic> meta) {
    final generatedAt = meta['generatedAt'] ?? '';
    final dataPoints = meta['dataPoints'] as Map<String, dynamic>? ?? {};

    return Center(
      child: Column(
        children: [
          Text(
            tr('ai_analysis_footer'),
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            '${dataPoints['dealsAnalyzed'] ?? 0} deals • ${dataPoints['listingsScanned'] ?? 0} listings scanned',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // ─── Reusable Insight Card ═══════════════════
  Widget _insightCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    String? badge,
    Color? badgeColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: iconBg.withOpacity(0.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: (badgeColor ?? Colors.grey).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: GoogleFonts.inter(
                        color: badgeColor ?? Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Body
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }

  // ─── Helpers ═════════════════════════════════
  Widget _miniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _priceLabel(String label, String price, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          price,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
