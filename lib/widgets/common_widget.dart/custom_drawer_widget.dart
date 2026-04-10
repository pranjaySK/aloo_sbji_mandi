import 'dart:convert';

import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:aloo_sbji_mandi/widgets/notification_bell_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomAppDrawer extends StatefulWidget {
  const CustomAppDrawer({super.key});

  @override
  State<CustomAppDrawer> createState() => _CustomAppDrawerState();
}

class _CustomAppDrawerState extends State<CustomAppDrawer> {
  String? userRole;
  String? alooMitraServiceType;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('userRole');
    String? serviceType;

    // For aloo-mitra, check serviceType from stored user data
    if (role == 'aloo-mitra') {
      final userJson = prefs.getString('user');
      if (userJson != null) {
        try {
          final userData = json.decode(userJson);
          final profile = userData['alooMitraProfile'];
          if (profile != null) {
            serviceType = profile['serviceType'];
          }
        } catch (_) {}
      }
    }

    setState(() {
      userRole = role;
      alooMitraServiceType = serviceType;
    });
  }

  Future<void> _logout(BuildContext context) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('logout')),
        content: Text(tr('logout_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () async {
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
              if (appLocale != null)
                await prefs.setString('app_locale', appLocale);
              if (darkMode != null) await prefs.setBool('darkMode', darkMode);
              NotificationState.reset();
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
            child: Text(
              tr('logout'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.cardBg(context),
      child: Column(
        children: [
          _DrawerHeader(),
          Expanded(
            child: Container(
              color: AppColors.scaffoldBg(context),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                children: _buildDrawerItems(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDrawerItems(BuildContext context) {
    // Minimal items for Aloo Mitra
    if (userRole == 'aloo-mitra') {
      return [
        // Show "Advertise with Us" for all aloo-mitra EXCEPT majdoor
        if (alooMitraServiceType != 'majdoor')
          _DrawerTile(
            icon: Icons.campaign_outlined,
            title: tr('advertise_with_us'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/advertise_with_us');
            },
          ),
        _DrawerTile(
          icon: Icons.settings_outlined,
          title: tr('settings'),
          onTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/settings');
          },
        ),
        _DrawerTile(
          icon: Icons.logout,
          title: tr('log_out'),
          isLogout: true,
          onTap: () => _logout(context),
        ),
      ];
    }

    // Full items for other roles (Farmer, Trader, Cold Storage)
    return [
      _DrawerTile(
        icon: Icons.star_border,
        title: tr('my_plan'),
        onTap: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/my_plan');
        },
      ),
      _DrawerTile(
        icon: Icons.verified_user_outlined,
        title: tr('kyc_documents'),
        onTap: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/kyc_documents');
        },
      ),
      _DrawerTile(
        icon: Icons.receipt_long,
        title: tr('transaction_history'),
        onTap: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/transaction_history');
        },
      ),
      _DrawerTile(
        icon: Icons.campaign_outlined,
        title: tr('advertise_with_us'),
        onTap: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/advertise_with_us');
        },
      ),
      _DrawerTile(
        icon: Icons.settings_outlined,
        title: tr('settings'),
        onTap: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/settings');
        },
      ),
      _DrawerTile(
        icon: Icons.logout,
        title: tr('log_out'),
        isLogout: true,
        onTap: () => _logout(context),
      ),
    ];
  }
}

class _DrawerHeader extends StatefulWidget {
  @override
  State<_DrawerHeader> createState() => _DrawerHeaderState();
}

class _DrawerHeaderState extends State<_DrawerHeader> {
  String userName = "Welcome User";
  String userPhone = "";
  String? userRole;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// Get display-friendly role label from role string
  String _getRoleLabel(String? role) {
    switch (role) {
      case 'farmer':
        return 'Kisan / किसान';
      case 'trader':
        return 'Vyapari / व्यापारी';
      case 'cold-storage':
        return 'Cold Storage Owner / शीत भंडार';
      case 'cold-storage-manager':
        return 'Storage Manager / मैनेजर';
      case 'aloo-mitra':
        return 'Aloo Mitra / आलू मित्र';
      case 'admin':
        return 'Admin';
      case 'master':
        return 'Master Admin';
      default:
        return '';
    }
  }

  /// Role-based placeholders that should be stripped from lastName
  static const _rolePlaceholders = {
    'kisan', 'farmer', 'vyapari', 'trader',
    'cold storage', 'cold-storage', 'storage',
    'mitra', 'aloo mitra', 'admin', 'master',
  };

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('userRole');
      final userJson = prefs.getString('user');
      if (userJson != null) {
        final userData = json.decode(userJson);
        final firstName = (userData['firstName'] ?? '').toString().trim();
        final lastName = (userData['lastName'] ?? '').toString().trim();

        // Filter out role-placeholder lastNames (e.g. "Kisan", "Vyapari")
        final cleanLastName = _rolePlaceholders.contains(lastName.toLowerCase())
            ? ''
            : lastName;

        setState(() {
          userName = cleanLastName.isNotEmpty
              ? '$firstName $cleanLastName'
              : firstName;
          if (userName.isEmpty) userName = "Welcome User";
          userPhone = userData['phone'] ?? "";
          userRole = role;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel = _getRoleLabel(userRole);

    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        image: const DecorationImage(
          image: AssetImage("assets/drawer_pattern.png"),
          fit: BoxFit.cover,
          opacity: 0.3,
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned(
              right: 16,
              top: 12,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 45, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    userName,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (roleLabel.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        roleLabel,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    userPhone.isNotEmpty ? userPhone : "User",
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 14,
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

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isLogout;
  final VoidCallback? onTap;

  const _DrawerTile({
    required this.icon,
    required this.title,
    this.isLogout = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shadowColor: AppColors.primaryGreen, // GREEN SHADOW
      surfaceTintColor: Colors.transparent, // Material 3 fix
      color: AppColors.cardBg(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        decoration: BoxDecoration(
          // color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          leading: Icon(
            icon,
            color: isLogout ? Colors.red : Colors.green.shade700,
          ),
          title: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: isLogout ? Colors.red : AppColors.textPrimary(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap:
              onTap ??
              () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$title - Coming soon!')),
                );
              },
        ),
      ),
    );
  }
}
