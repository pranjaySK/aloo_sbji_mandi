import 'package:aloo_sbji_mandi/core/service/feedback_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/utils/ist_datetime.dart';

class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  final FeedbackService _feedbackService = FeedbackService();
  List<Map<String, dynamic>> _feedbacks = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadFeedbacks();
  }

  Future<void> _loadFeedbacks() async {
    setState(() => _isLoading = true);

    final result = await _feedbackService.getAllFeedbacks();

    if (result['success']) {
      setState(() {
        _feedbacks = List<Map<String, dynamic>>.from(result['feedbacks'] ?? []);
        // Sort by timestamp (newest first)
        _feedbacks.sort((a, b) {
          final timeA =
              DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(2000);
          final timeB =
              DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(2000);
          return timeB.compareTo(timeA);
        });
      });
    }

    setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> get _filteredFeedbacks {
    if (_selectedFilter == 'all') return _feedbacks;
    return _feedbacks.where((f) => f['status'] == _selectedFilter).toList();
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'reviewed':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String? role) {
    switch (role) {
      case 'farmer':
        return Icons.agriculture;
      case 'trader':
        return Icons.store;
      case 'cold-storage':
        return Icons.ac_unit;
      case 'aloo-mitra':
        return Icons.handshake;
      default:
        return Icons.person;
    }
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'farmer':
        return AppColors.primaryGreen;
      case 'trader':
        return Colors.blue;
      case 'cold-storage':
        return Colors.cyan;
      case 'aloo-mitra':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final dateTime = DateTime.parse(timestamp).toIST();
      final now = nowIST();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 60) {
        return trArgs('min_ago_args', {'count': '${difference.inMinutes}'});
      } else if (difference.inHours < 24) {
        return trArgs('hours_ago_args', {'count': '${difference.inHours}'});
      } else if (difference.inDays < 7) {
        return trArgs('days_ago_args', {'count': '${difference.inDays}'});
      } else {
        return DateFormat('dd MMM yyyy').format(dateTime);
      }
    } catch (e) {
      return tr('unknown');
    }
  }

  void _showFeedbackDetails(Map<String, dynamic> feedback) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getRoleColor(
                    feedback['userRole'],
                  ).withOpacity(0.2),
                  child: Icon(
                    _getRoleIcon(feedback['userRole']),
                    color: _getRoleColor(feedback['userRole']),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feedback['userName'] ?? tr('unknown_user'),
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_formatRoleName(feedback['userRole'])} • ${_formatTime(feedback['timestamp'])}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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
                    color: _getStatusColor(feedback['status']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    (feedback['status'] ?? 'pending').toString().toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(feedback['status']),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                feedback['message'] ?? tr('no_message'),
                style: GoogleFonts.inter(fontSize: 15, height: 1.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              tr('update_status'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatusButton(
                    label: tr('pending'),
                    color: Colors.orange,
                    isSelected: feedback['status'] == 'pending',
                    onTap: () => _updateStatus(feedback, 'pending'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatusButton(
                    label: tr('reviewed'),
                    color: Colors.blue,
                    isSelected: feedback['status'] == 'reviewed',
                    onTap: () => _updateStatus(feedback, 'reviewed'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatusButton(
                    label: tr('resolved'),
                    color: Colors.green,
                    isSelected: feedback['status'] == 'resolved',
                    onTap: () => _updateStatus(feedback, 'resolved'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _deleteFeedback(feedback),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: Text(tr('delete_feedback')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRoleName(String? role) {
    switch (role) {
      case 'farmer':
        return tr('role_farmer_emoji');
      case 'trader':
        return tr('role_trader_emoji');
      case 'cold-storage':
        return tr('role_cold_storage_emoji');
      case 'aloo-mitra':
        return tr('role_aloo_mitra_emoji');
      default:
        return tr('user');
    }
  }

  void _updateStatus(Map<String, dynamic> feedback, String newStatus) {
    Navigator.pop(context);
    setState(() {
      final index = _feedbacks.indexWhere(
        (f) => f['timestamp'] == feedback['timestamp'],
      );
      if (index != -1) {
        _feedbacks[index]['status'] = newStatus;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${tr('status_updated_to')} $newStatus'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  void _deleteFeedback(Map<String, dynamic> feedback) {
    Navigator.pop(context);
    setState(() {
      _feedbacks.removeWhere((f) => f['timestamp'] == feedback['timestamp']);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('feedback_deleted')),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        title: Text(
          tr('user_feedbacks'),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadFeedbacks,
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E3A5F), Color(0xFF2E5A8F)],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: tr('total'),
                  count: _feedbacks.length,
                  color: Colors.white,
                ),
                _StatItem(
                  label: tr('pending'),
                  count: _feedbacks
                      .where((f) => f['status'] == 'pending')
                      .length,
                  color: Colors.orange,
                ),
                _StatItem(
                  label: tr('reviewed'),
                  count: _feedbacks
                      .where((f) => f['status'] == 'reviewed')
                      .length,
                  color: Colors.blue,
                ),
                _StatItem(
                  label: tr('resolved'),
                  count: _feedbacks
                      .where((f) => f['status'] == 'resolved')
                      .length,
                  color: Colors.green,
                ),
              ],
            ),
          ),

          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: tr('all'),
                    isSelected: _selectedFilter == 'all',
                    onTap: () => setState(() => _selectedFilter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: tr('pending'),
                    isSelected: _selectedFilter == 'pending',
                    color: Colors.orange,
                    onTap: () => setState(() => _selectedFilter = 'pending'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: tr('reviewed'),
                    isSelected: _selectedFilter == 'reviewed',
                    color: Colors.blue,
                    onTap: () => setState(() => _selectedFilter = 'reviewed'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: tr('resolved'),
                    isSelected: _selectedFilter == 'resolved',
                    color: Colors.green,
                    onTap: () => setState(() => _selectedFilter = 'resolved'),
                  ),
                ],
              ),
            ),
          ),

          // Feedbacks List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredFeedbacks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.feedback_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          tr('no_feedbacks_yet'),
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr('user_feedbacks_will_appear_here'),
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadFeedbacks,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredFeedbacks.length,
                      itemBuilder: (context, index) {
                        final feedback = _filteredFeedbacks[index];
                        return _FeedbackCard(
                          feedback: feedback,
                          onTap: () => _showFeedbackDetails(feedback),
                          roleIcon: _getRoleIcon(feedback['userRole']),
                          roleColor: _getRoleColor(feedback['userRole']),
                          statusColor: _getStatusColor(feedback['status']),
                          timeAgo: _formatTime(feedback['timestamp']),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Add sample feedbacks for testing
          await _feedbackService.addSampleFeedbacks();
          _loadFeedbacks();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('sample_feedbacks_added')),
              backgroundColor: AppColors.primaryGreen,
            ),
          );
        },
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.add),
        label: Text(tr('add_samples')),
      ),
    );
  }
}

// ==================== WIDGETS ====================

class _FeedbackCard extends StatelessWidget {
  final Map<String, dynamic> feedback;
  final VoidCallback onTap;
  final IconData roleIcon;
  final Color roleColor;
  final Color statusColor;
  final String timeAgo;

  const _FeedbackCard({
    required this.feedback,
    required this.onTap,
    required this.roleIcon,
    required this.roleColor,
    required this.statusColor,
    required this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: roleColor.withOpacity(0.2),
                    child: Icon(roleIcon, color: roleColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feedback['userName'] ?? tr('unknown_user'),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      (feedback['status'] ?? 'pending')
                          .toString()
                          .toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                feedback['message'] ?? tr('no_message'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatItem({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? (color ?? const Color(0xFF1E3A5F)) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color ?? const Color(0xFF1E3A5F)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (color ?? const Color(0xFF1E3A5F)),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
