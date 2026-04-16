import 'dart:convert';

import 'package:aloo_sbji_mandi/core/service/admin_management_service.dart';
import 'package:aloo_sbji_mandi/core/service/advertisement_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/screens/admin/admin_ads_screen.dart';
import 'package:aloo_sbji_mandi/screens/admin/admin_broadcast_notification_screen.dart';
import 'package:aloo_sbji_mandi/screens/admin/manage_admins_screen.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:aloo_sbji_mandi/widgets/language_toggle_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final AdvertisementService _adService = AdvertisementService();
  final AdminManagementService _adminManagementService =
      AdminManagementService();
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  bool _isMaster = false;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _checkMasterRole();
  }

  Future<void> _checkMasterRole() async {
    // Check locally first from stored user data
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      final user = json.decode(userStr);
      final role = user['role'] ?? '';
      final phone = user['phone'] ?? '';
      if (role == 'master' || phone == '8112363785') {
        setState(() => _isMaster = true);
        return;
      }
    }

    // Also verify from server
    final result = await _adminManagementService.checkRole();
    if (result['success'] && result['data'] != null) {
      setState(() {
        _isMaster = result['data']['isMaster'] == true;
      });
    }
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);

    final result = await _adService.getDashboardStats();
    if (result['success']) {
      _stats = result['data'];
    }

    setState(() => _isLoading = false);
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    // Preserve non-auth preferences across logout
    final lastSeenTimestamp = prefs.getString(
      'lastSeenTraderRequestsTimestamp',
    );
    final appLocale = prefs.getString('app_locale');
    final darkMode = prefs.getBool('darkMode');
    await prefs.clear();
    // Restore preserved preferences
    if (lastSeenTimestamp != null)
      await prefs.setString(
        'lastSeenTraderRequestsTimestamp',
        lastSeenTimestamp,
      );
    if (appLocale != null) await prefs.setString('app_locale', appLocale);
    if (darkMode != null) await prefs.setBool('darkMode', darkMode);
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        title: Text(
          tr('admin_dashboard'),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          const LanguageToggleWidget(),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDashboard,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isMaster
                              ? [
                                  const Color(0xFF8B6914),
                                  const Color(0xFFB8860B),
                                ]
                              : [
                                  const Color(0xFF1E3A5F),
                                  const Color(0xFF2E5A8F),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white24,
                            child: Icon(
                              _isMaster
                                  ? Icons.shield
                                  : Icons.admin_panel_settings,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isMaster
                                      ? tr('welcome_master')
                                      : tr('welcome_admin'),
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _isMaster
                                      ? tr('full_control_platform_admins')
                                      : tr('manage_your_platform'),
                                  style: GoogleFonts.inter(
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Stats Grid
                    Text(
                      tr('advertisement_overview'),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.5,
                      children: [
                        _StatCard(
                          title: tr('pending_ads'),
                          value: '${_stats['pendingAds'] ?? 0}',
                          icon: Icons.pending_actions,
                          color: Colors.orange,
                        ),
                        _StatCard(
                          title: tr('active_ads'),
                          value: '${_stats['activeAds'] ?? 0}',
                          icon: Icons.campaign,
                          color: Colors.green,
                        ),
                        _StatCard(
                          title: tr('total_ads'),
                          value: '${_stats['totalAds'] ?? 0}',
                          icon: Icons.analytics,
                          color: Colors.blue,
                        ),
                        _StatCard(
                          title: tr('revenue'),
                          value: '₹${_stats['totalRevenue'] ?? 0}',
                          icon: Icons.monetization_on,
                          color: Colors.purple,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Quick Actions
                    Text(
                      tr('quick_actions'),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _ActionCard(
                      title: tr('manage_advertisements_title'),
                      subtitle:
                          '${_stats['pendingAds'] ?? 0} ${tr('pending_requests')}',
                      icon: Icons.campaign,
                      color: Colors.orange,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminAdsScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // Send Broadcast Notification
                    _ActionCard(
                      title: tr('send_notification'),
                      subtitle: tr('broadcast_message_users'),
                      icon: Icons.notifications_active,
                      color: Colors.blue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const AdminBroadcastNotificationScreen(),
                          ),
                        );
                      },
                    ),

                    // Manage Admins - Only visible to MASTER
                    if (_isMaster) ...[
                      const SizedBox(height: 12),
                      _ActionCard(
                        title: tr('manage_admins_title'),
                        subtitle: tr('create_edit_remove_admins'),
                        icon: Icons.group,
                        color: const Color(0xFF8B6914),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ManageAdminsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
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
      case 'admin':
        return Icons.admin_panel_settings;
      case 'master':
        return Icons.shield;
      default:
        return Icons.person;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 28),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 18),
          ],
        ),
      ),
    );
  }
}
