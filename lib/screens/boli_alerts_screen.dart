import 'package:aloo_sbji_mandi/core/service/boli_alert_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:aloo_sbji_mandi/widgets/boli_alert_banner.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../core/utils/ist_datetime.dart';
import 'package:url_launcher/url_launcher.dart';

class BoliAlertsScreen extends StatefulWidget {
  const BoliAlertsScreen({super.key});

  @override
  State<BoliAlertsScreen> createState() => _BoliAlertsScreenState();
}

class _BoliAlertsScreenState extends State<BoliAlertsScreen>
    with SingleTickerProviderStateMixin {
  final BoliAlertService _service = BoliAlertService();
  late TabController _tabController;

  List<BoliAlert> _upcomingAlerts = [];
  List<BoliAlert> _allAlerts = [];
  bool _isLoading = true;
  String? _error;

  bool get isHindi => AppLocalizations.isHindi;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAlerts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load upcoming alerts
      final upcomingResult = await _service.getAllBoliAlerts(upcoming: true);
      if (upcomingResult['success'] == true && upcomingResult['data'] != null) {
        _upcomingAlerts = (upcomingResult['data'] as List)
            .map((json) => BoliAlert.fromJson(json))
            .toList();
      }

      // Load all alerts
      final allResult = await _service.getAllBoliAlerts();
      if (allResult['success'] == true && allResult['data'] != null) {
        _allAlerts = (allResult['data'] as List)
            .map((json) => BoliAlert.fromJson(json))
            .toList();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          tr('auction_alerts'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: tr('upcoming_tab')),
            Tab(text: tr('all_tab')),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorView()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAlertsList(_upcomingAlerts, isUpcoming: true),
                _buildAlertsList(_allAlerts),
              ],
            ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            tr('something_went_wrong'),
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(_error ?? '', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadAlerts,
            icon: const Icon(Icons.refresh),
            label: Text(tr('retry_btn')),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsList(List<BoliAlert> alerts, {bool isUpcoming = false}) {
    if (alerts.isEmpty) {
      return _buildEmptyView(isUpcoming);
    }

    // Group alerts by day
    final Map<String, List<BoliAlert>> groupedAlerts = {};
    for (final alert in alerts) {
      final dayKey = alert.dayName;
      groupedAlerts.putIfAbsent(dayKey, () => []).add(alert);
    }

    return RefreshIndicator(
      onRefresh: _loadAlerts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: groupedAlerts.length,
        itemBuilder: (context, index) {
          final day = groupedAlerts.keys.elementAt(index);
          final dayAlerts = groupedAlerts[day]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getLocalizedDay(day),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      trArgs('auction_count', {
                        'count': dayAlerts.length.toString(),
                      }),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

              // Alerts for this day
              ...dayAlerts.map((alert) => _buildAlertCard(alert)),

              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyView(bool isUpcoming) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isUpcoming ? Icons.event_available : Icons.notifications_off,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            isUpcoming ? tr('no_upcoming_auctions') : tr('no_auctions_found'),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr('new_auctions_coming_soon'),
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(BoliAlert alert) {
    final bool isUrgent = alert.isToday || alert.isTomorrow;

    return GestureDetector(
      onTap: () => _showAlertDetails(alert),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isUrgent ? Border.all(color: Colors.orange, width: 2) : null,
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
            // Urgency banner
            if (isUrgent)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                ),
                child: Center(
                  child: Text(
                    alert.isToday
                        ? tr('auction_today')
                        : tr('auction_tomorrow'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Cold Storage
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('🏭', style: TextStyle(fontSize: 24)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alert.title,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (alert.coldStorageName != null) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.warehouse,
                                      size: 14,
                                      color: Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      alert.coldStorageName!,
                                      style: TextStyle(
                                        color: Colors.blue.shade800,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Divider(height: 24),

                  // Date, Time, Location row
                  Row(
                    children: [
                      Expanded(
                        child: _iconText(
                          Icons.calendar_today,
                          DateFormat('dd MMM').format(alert.nextBoliDate.toIST()),
                        ),
                      ),
                      Expanded(
                        child: _iconText(Icons.access_time, alert.boliTimeFormatted),
                      ),
                      Expanded(
                        child: _iconText(
                          Icons.location_on,
                          alert.location.city,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Potato varieties chips
                  if (alert.potatoVarieties.isNotEmpty)
                    SizedBox(
                      height: 28,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: alert.potatoVarieties.length.clamp(0, 3),
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              alert.potatoVarieties[index],
                              style: TextStyle(
                                color: Colors.green[800],
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _makeCall(alert.contactPhone),
                          icon: const Icon(Icons.call, size: 18),
                          label: Text(
                            tr('call_action'),
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _shareAlert(alert),
                          icon: const Icon(Icons.share, size: 18),
                          label: Text(
                            tr('share_action'),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _showAlertDetails(alert),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: Text(
                          tr('details_action'),
                          style: const TextStyle(fontSize: 12),
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
    );
  }

  Widget _iconText(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: Colors.grey[800], fontSize: 13)),
      ],
    );
  }

  String _getLocalizedDay(String englishDay) {
    final Map<String, String> dayKeys = {
      'Sunday': 'day_sunday',
      'Monday': 'day_monday',
      'Tuesday': 'day_tuesday',
      'Wednesday': 'day_wednesday',
      'Thursday': 'day_thursday',
      'Friday': 'day_friday',
      'Saturday': 'day_saturday',
    };
    return tr(dayKeys[englishDay] ?? englishDay);
  }

  void _showAlertDetails(BoliAlert alert) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BoliAlertDetailsSheet(alert: alert),
    );
  }

  void _makeCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _shareAlert(BoliAlert alert) {
    final message =
        '''
🔔 *${alert.title}*

📅 ${tr('day_field')}: ${_getLocalizedDay(alert.dayName)}
📆 ${tr('date_field')}: ${DateFormat('dd MMM yyyy').format(alert.nextBoliDate.toIST())}
⏰ ${tr('time_field')}: ${alert.boliTimeFormatted}

📍 ${tr('location_field')}:
${alert.location.fullAddress}

📞 ${tr('contact_field')}: ${alert.contactPerson}
☎️ ${alert.contactPhone}

${alert.location.googleMapsLink ?? ''}

---
${tr('shared_from_aloo_market')}

Download Aloo Market App:
https://play.google.com/store/apps/details?id=com.aloomarket.app
''';

    Share.share(message);
  }
}
