import 'package:aloo_sbji_mandi/core/service/boli_alert_service.dart';
import 'package:aloo_sbji_mandi/core/service/notification_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:aloo_sbji_mandi/screens/boli_alerts_screen.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:aloo_sbji_mandi/widgets/boli_alert_banner.dart';
import 'package:aloo_sbji_mandi/widgets/notification_bell_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../core/utils/ist_datetime.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  final BoliAlertService _boliAlertService = BoliAlertService();
  List<Map<String, dynamic>> _notifications = [];
  List<BoliAlert> _upcomingAlerts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    _fetchUpcomingAlerts();
    // Mark all notifications as read when user opens this screen
    // Uses NotificationState to clear local dot immediately + sync with server
    NotificationState.markAllRead();
  }

  Future<void> _fetchUpcomingAlerts() async {
    final result = await _boliAlertService.getAllBoliAlerts(upcoming: true);
    if (result['success'] == true && result['data'] != null) {
      if (mounted) {
        setState(() {
          _upcomingAlerts = (result['data'] as List)
              .map((json) => BoliAlert.fromJson(json))
              .toList();
        });
      }
    }
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _notificationService.getNotifications();

    if (result['success'] == true) {
      final data = result['data'];
      final list = data['notifications'] ?? [];
      setState(() {
        _notifications = List<Map<String, dynamic>>.from(list);
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result['message'] ?? 'Failed to load notifications';
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmAndDelete(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          tr('delete_notification'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: Text(
          tr('confirm_delete_notification'),
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              tr('cancel'),
              style: GoogleFonts.inter(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              tr('delete'),
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final notification = _notifications[index];
    final id = notification['_id'];

    // Optimistically remove from UI
    setState(() {
      _notifications.removeAt(index);
    });

    if (id != null) {
      final success = await _notificationService.deleteNotification(id);
      if (!success && mounted) {
        // Re-fetch if API call failed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('failed_delete_notification')),
            backgroundColor: Colors.red,
          ),
        );
        _fetchNotifications();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('notification_deleted')),
            backgroundColor: AppColors.primaryGreen,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy, EEEE').format(date.toIST());
    } catch (_) {
      return dateStr;
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('hh:mm a').format(date.toIST());
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: CustomRoundedAppBar(
        title: tr('notifications'),
        actions: const [],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: GoogleFonts.inter(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchNotifications,
                    child: Text(tr('retry')),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await _fetchNotifications();
                await _fetchUpcomingAlerts();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Upcoming Boli Alerts Section
                  if (_upcomingAlerts.isNotEmpty) ...[
                    _buildUpcomingAlertsSection(),
                    const SizedBox(height: 16),
                    Divider(color: Colors.grey[300]),
                    const SizedBox(height: 8),
                  ],

                  // Notifications header
                  if (_notifications.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        tr('notifications'),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  if (_notifications.isEmpty && _upcomingAlerts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Column(
                        children: [
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 80,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            tr('no_notifications'),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (_notifications.isEmpty && _upcomingAlerts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Center(
                        child: Text(
                          tr('no_other_notifications'),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                      ),
                    ),

                  // Notification cards
                  ..._notifications.map((n) {
                    final index = _notifications.indexOf(n);
                    final dataMap = n['data'] as Map<String, dynamic>?;
                    final imageUrl = dataMap?['imageUrl'] as String?;
                    
                    return NotificationCard(
                      date: _formatDate(n['createdAt']),
                      time: _formatTime(n['createdAt']), 
                      message: n['message'] ?? '',
                      title: n['title'] ?? '',
                      imageUrl: imageUrl,
                      onDelete: () => _confirmAndDelete(index),
                    );
                  }),
                ],
              ),
            ),
    );
  }

  Widget _buildUpcomingAlertsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🔔', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              tr('upcoming_auctions'),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BoliAlertsScreen(),
                  ),
                );
              },
              child: Text(
                tr('view_all').substring(0, 8),
                style: TextStyle(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._upcomingAlerts.take(3).map((alert) => _buildBoliAlertCard(alert)),
      ],
    );
  }

  Widget _buildBoliAlertCard(BoliAlert alert) {
    final bool isUrgent = alert.isToday || alert.isTomorrow;

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => BoliAlertDetailsSheet(alert: alert),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isUrgent
                ? [Colors.orange.shade500, Colors.orange.shade700]
                : [AppColors.primaryGreen, const Color(0xFF2E7D32)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: (isUrgent ? Colors.orange : AppColors.primaryGreen)
                  .withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Urgency badge + title
            Row(
              children: [
                if (isUrgent) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      alert.isToday
                          ? '🔴 ${tr('today')}!'
                          : '⚠️ ${tr('tomorrow')}!',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    alert.title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (alert.coldStorageName != null) ...[
              const SizedBox(height: 2),
              Text(
                alert.coldStorageName!,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            // Date, time, location row
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  color: Colors.white70,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  '${AppLocalizations.isHindi ? alert.dayNameHindi : alert.dayName} ${DateFormat('dd MMM').format(alert.nextBoliDate.toIST())}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.access_time, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text(
                  alert.boliTimeFormatted,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.location_on, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text(
                  alert.location.city,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationCard extends StatelessWidget {
  final String date;
  final String time;
  final String message;
  final String title;
  final String? imageUrl;
  final VoidCallback onDelete;

  const NotificationCard({
    super.key,
    required this.date,
    required this.time,
    required this.message,
    this.title = '',
    this.imageUrl,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Material(
        color: AppColors.cardBg(context),
        elevation: 4,
        shadowColor: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      date,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  Text(
                    time,
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onDelete,
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (title.isNotEmpty) ...[
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                message,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textPrimary(context),
                  height: 1.4,
                ),
              ),
              if (imageUrl != null && imageUrl!.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
