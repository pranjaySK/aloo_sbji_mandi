import 'package:aloo_sbji_mandi/core/service/boli_alert_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../core/utils/ist_datetime.dart';
import 'package:url_launcher/url_launcher.dart';

/// Widget to show Boli Alerts banner on home screen
class BoliAlertBanner extends StatefulWidget {
  const BoliAlertBanner({super.key});

  @override
  State<BoliAlertBanner> createState() => _BoliAlertBannerState();
}

class _BoliAlertBannerState extends State<BoliAlertBanner> {
  final BoliAlertService _service = BoliAlertService();
  List<BoliAlert> _alerts = [];
  bool _isLoading = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    final result = await _service.getAllBoliAlerts(upcoming: true);
    if (result['success'] == true && result['data'] != null) {
      setState(() {
        _alerts = (result['data'] as List)
            .map((json) => BoliAlert.fromJson(json))
            .toList();
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (_alerts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text('ðŸ””', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                tr('upcoming_auctions'),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_alerts.length > 1)
                Text(
                  '${_currentIndex + 1}/${_alerts.length}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Alert Cards
          SizedBox(
            height: 180,
            child: PageView.builder(
              itemCount: _alerts.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                return _buildAlertCard(_alerts[index]);
              },
            ),
          ),

          // Page indicators
          if (_alerts.length > 1)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _alerts.length,
                    (index) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == _currentIndex
                            ? AppColors.primaryGreen
                            : Colors.grey[300],
                      ),
                    ),
                  ),
                ),
              ),
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
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isUrgent
                ? [Colors.orange.shade600, Colors.orange.shade800]
                : [AppColors.primaryGreen, const Color(0xFF2E7D32)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (isUrgent ? Colors.orange : AppColors.primaryGreen)
                  .withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned(
              right: -20,
              top: -20,
              child: Icon(
                Icons.notifications_active,
                size: 120,
                color: Colors.white.withOpacity(0.1),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Urgency badge
                  if (isUrgent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        alert.isToday
                            ? 'ðŸ”´ ${tr('today')}!'
                            : 'âš ï¸ ${tr('tomorrow')}!',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),

                  // Title
                  Text(
                    alert.title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Cold Storage Name
                  if (alert.coldStorageName != null)
                    Text(
                      alert.coldStorageName!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),

                  const Spacer(),

                  // Date & Time
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        AppLocalizations.isHindi
                            ? alert.dayNameHindi
                            : alert.dayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd MMM').format(alert.nextBoliDate.toIST()),
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(width: 16),
                      const Icon(
                        Icons.access_time,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        alert.boliTimeFormatted,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Location
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${alert.location.city}, ${alert.location.state}',
                          style: const TextStyle(color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${tr('details')} â†’',
                          style: TextStyle(
                            color: isUrgent
                                ? Colors.orange.shade800
                                : AppColors.primaryGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
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

  void _showAlertDetails(BoliAlert alert) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BoliAlertDetailsSheet(alert: alert),
    );
  }
}

/// Full details bottom sheet with token queue indexing
class BoliAlertDetailsSheet extends StatefulWidget {
  final BoliAlert alert;

  const BoliAlertDetailsSheet({super.key, required this.alert});

  @override
  State<BoliAlertDetailsSheet> createState() => _BoliAlertDetailsSheetState();
}

class _BoliAlertDetailsSheetState extends State<BoliAlertDetailsSheet> {
  BoliAlert get alert => widget.alert;
  bool get isHindi => AppLocalizations.isHindi;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('ðŸ””', style: TextStyle(fontSize: 32)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alert.title,
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (alert.coldStorageName != null) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.warehouse,
                                      size: 16,
                                      color: Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      alert.coldStorageName!,
                                      style: GoogleFonts.inter(
                                        color: Colors.blue.shade800,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
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
                  const SizedBox(height: 24),

                  // Urgency indicator
                  if (alert.isToday || alert.isTomorrow)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text('âš ï¸', style: TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              alert.isToday
                                  ? tr('auction_is_today')
                                  : tr('auction_is_tomorrow'),
                              style: TextStyle(
                                color: Colors.orange[800],
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Date & Time
                  _infoCard(
                    icon: Icons.calendar_today,
                    title: tr('date_and_time'),
                    children: [
                      _infoRow(
                        tr('day'),
                        '${AppLocalizations.isHindi ? alert.dayNameHindi : alert.dayName} (${tr('every_week')})',
                      ),
                      _infoRow(
                        tr('date'),
                        DateFormat('dd MMMM yyyy').format(alert.nextBoliDate.toIST()),
                      ),
                      _infoRow(tr('time'), alert.boliTimeFormatted, isBold: true),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Location
                  _infoCard(
                    icon: Icons.location_on,
                    title: tr('location'),
                    children: [
                      Text(
                        alert.location.fullAddress,
                        style: const TextStyle(fontSize: 15),
                      ),
                      if (alert.location.landmark != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${tr('landmark')}: ${alert.location.landmark}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (alert.location.googleMapsLink != null)
                        OutlinedButton.icon(
                          onPressed: () =>
                              _openMaps(alert.location.googleMapsLink!),
                          icon: const Icon(Icons.map),
                          label: Text(tr('open_in_maps')),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Contact
                  _infoCard(
                    icon: Icons.phone,
                    title: tr('contact'),
                    children: [
                      _infoRow(tr('person'), alert.contactPerson),
                      const SizedBox(height: 12),
                      // Phone number with copy
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.phone,
                              color: Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SelectableText(
                                alert.contactPhone,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: alert.contactPhone),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(tr('number_copied')),
                                    duration: const Duration(seconds: 1),
                                    backgroundColor: AppColors.primaryGreen,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy, size: 20),
                              tooltip: tr('copy_number'),
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen
                                    .withOpacity(0.1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Expected Details
                  if (alert.expectedQuantity != null ||
                      alert.expectedPriceMin != null ||
                      alert.potatoVarieties.isNotEmpty)
                    _infoCard(
                      icon: Icons.inventory,
                      title: tr('expected_details'),
                      children: [
                        if (alert.expectedQuantity != null)
                          _infoRow(
                            tr('quantity'),
                            '${alert.expectedQuantity} ${tr('tons')}',
                          ),
                        if (alert.expectedPriceMin != null &&
                            alert.expectedPriceMax != null)
                          _infoRow(
                            tr('expected_price'),
                            'â‚¹${alert.expectedPriceMin!.toStringAsFixed(0)} - â‚¹${alert.expectedPriceMax!.toStringAsFixed(0)} /${tr('quintal_abbr')}',
                          ),
                        if (alert.potatoVarieties.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${tr('potato_varieties')}:',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            children: alert.potatoVarieties
                                .map((v) => Chip(label: Text(v)))
                                .toList(),
                          ),
                        ],
                      ],
                    ),

                  if (alert.instructions != null) ...[
                    const SizedBox(height: 16),
                    _infoCard(
                      icon: Icons.info_outline,
                      title: tr('instructions'),
                      children: [Text(alert.instructions!)],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Share button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _shareAlert(alert),
                      icon: const Icon(Icons.share),
                      label: Text(tr('share_auction')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
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

  Widget _infoCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:', style: TextStyle(color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                fontSize: isBold ? 16 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openMaps(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
ðŸ”” *${alert.title}*

ðŸ“… ${tr('day')}: ${AppLocalizations.isHindi ? alert.dayNameHindi : alert.dayName}
ðŸ“† ${tr('date')}: ${DateFormat('dd MMM yyyy').format(alert.nextBoliDate.toIST())}
â° ${tr('time')}: ${alert.boliTimeFormatted}

ðŸ“ ${tr('location')}:
${alert.location.fullAddress}

ðŸ“ž ${tr('contact')}: ${alert.contactPerson}
â˜Žï¸ ${alert.contactPhone}

${alert.location.googleMapsLink ?? ''}

---
${tr('sent_from_aloo_market')}

Download Aloo Market App:
https://play.google.com/store/apps/details?id=com.aloomarket.app
''';

    Share.share(message);
  }
}