import 'package:aloo_sbji_mandi/core/service/notification_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:aloo_sbji_mandi/widgets/cold_storage_notification_bell.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/utils/ist_datetime.dart';

class ColdStorageNotificationScreen extends StatefulWidget {
  const ColdStorageNotificationScreen({super.key});

  @override
  State<ColdStorageNotificationScreen> createState() =>
      _ColdStorageNotificationScreenState();
}

class _ColdStorageNotificationScreenState
    extends State<ColdStorageNotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    // Mark all CS notifications as read when user opens this screen
    ColdStorageNotificationState.markAllRead();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _notificationService.getNotifications(
      types: coldStorageNotificationTypes,
    );

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

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'booking_request':
        return Icons.book_online;
      case 'booking_updated':
        return Icons.edit_note;
      case 'booking_cancelled':
        return Icons.cancel_outlined;
      case 'token_called':
      case 'token_nearby':
      case 'token_issued':
        return Icons.confirmation_number;
      case 'token_skipped':
        return Icons.skip_next;
      case 'token_completed':
        return Icons.check_circle_outline;
      case 'boli_alert':
        return Icons.gavel;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'booking_request':
        return Colors.blue;
      case 'booking_updated':
        return Colors.orange;
      case 'booking_cancelled':
        return Colors.red;
      case 'token_called':
      case 'token_nearby':
      case 'token_issued':
        return AppColors.primaryGreen;
      case 'token_skipped':
        return Colors.amber.shade700;
      case 'token_completed':
        return Colors.green;
      case 'boli_alert':
        return Colors.deepPurple;
      default:
        return Colors.grey;
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
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.grey[400]),
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
                  onRefresh: _fetchNotifications,
                  child: _notifications.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.6,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
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
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            final n = _notifications[index];
                            final type = n['type'] as String?;
                            final data = n['data'] as Map<String, dynamic>?;
                            final imageUrl = data?['imageUrl'] as String?;
                            return _ColdStorageNotificationCard(
                              imageUrl: imageUrl,
                              date: _formatDate(n['createdAt']),
                              time: _formatTime(n['createdAt']),
                              title: n['title'] ?? '',
                              message: n['message'] ?? '',
                              icon: _getNotificationIcon(type),
                              iconColor: _getNotificationColor(type),
                              onDelete: () => _confirmAndDelete(index),
                            );
                          },
                        ),
                ),
    );
  }
}

class _ColdStorageNotificationCard extends StatelessWidget {
  final String date;
  final String time;
  final String title;
  final String message;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onDelete;
  final String? imageUrl;

  const _ColdStorageNotificationCard({
    required this.date,
    required this.time,
    required this.title,
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.onDelete,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.cardBg(context),
        elevation: 3,
        shadowColor: AppColors.primaryGreen.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            date,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        Text(
                          time,
                          style: GoogleFonts.inter(
                              fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: onDelete,
                          child: const Icon(Icons.close,
                              size: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (title.isNotEmpty) ...[
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    Text(
                      message,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textPrimary(context).withOpacity(0.8),
                        height: 1.4,
                      ),
                    ),
                    if (imageUrl != null && imageUrl!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl!,
                          width: double.infinity,
                          height: 150,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
