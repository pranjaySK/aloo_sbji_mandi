import 'dart:convert';

import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:aloo_sbji_mandi/core/utils/role_shell_scroll_padding.dart';
import 'package:aloo_sbji_mandi/screens/edit_profile_screen.dart';
import 'package:aloo_sbji_mandi/screens/help_support_screen.dart';
import 'package:aloo_sbji_mandi/screens/receipt/my_receipt_photos_screen.dart';
import 'package:aloo_sbji_mandi/screens/settings_screen.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:aloo_sbji_mandi/widgets/notification_bell_widget.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    AppLocalizations.instance.addListener(_onLocaleChanged);
    _loadUserData();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppLocalizations.instance.removeListener(_onLocaleChanged);
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      if (userJson != null) {
        setState(() {
          userData = json.decode(userJson);
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  String _getRoleLabel(String? role) {
    switch (role) {
      case 'farmer':
        return tr('role_farmer');
      case 'trader':
        return tr('role_trader');
      case 'cold-storage':
        return 'Cold Storage Owner';
      case 'admin':
        return 'Admin';
      case 'master':
        return 'Master Admin';
      default:
        return role ?? 'User';
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
      case 'admin':
        return Icons.admin_panel_settings;
      case 'master':
        return Icons.shield;
      default:
        return Icons.person;
    }
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'farmer':
        return Colors.green;
      case 'trader':
        return Colors.orange;
      case 'cold-storage':
        return Colors.blue;
      case 'admin':
        return Colors.red;
      case 'master':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('logout')),
        content: Text(tr('logout_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              NotificationState.reset();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                );
              }
            },
            child: Text(tr('yes'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: CustomRoundedAppBar(title: tr('profile'), showBackButton: false),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : SingleChildScrollView(
              padding: RoleShellScrollPadding.profile,
              child: Column(
                children: [
                  // Profile Avatar
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: _getRoleColor(userData?['role']).withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _getRoleColor(userData?['role']),
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      _getRoleIcon(userData?['role']),
                      size: 60,
                      color: _getRoleColor(userData?['role']),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Name
                  Text(
                    '${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Role badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getRoleColor(userData?['role']),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getRoleLabel(userData?['role']),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Profile Info Card
                  Container(
                    padding: const EdgeInsets.all(20),
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
                        _infoRow(
                          icon: Icons.phone,
                          label: tr('phone_number'),
                          value: '+91 ${userData?['phone'] ?? 'N/A'}',
                        ),
                        const Divider(height: 24),
                        _infoRow(
                          icon: Icons.location_on,
                          label: tr('village'),
                          value: userData?['address']?['village'] ?? 'N/A',
                        ),
                        const Divider(height: 24),
                        _infoRow(
                          icon: Icons.location_city,
                          label: tr('district'),
                          value: userData?['address']?['district'] ?? 'N/A',
                        ),
                        const Divider(height: 24),
                        _infoRow(
                          icon: Icons.map,
                          label: tr('state_label'),
                          value: userData?['address']?['state'] ?? 'N/A',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Share App - right below profile
                  _menuItem(
                    icon: Icons.share,
                    label: tr('share_app'),
                    subtitle: tr('share_app_sub'),
                    onTap: () {
                      Share.share(
                        'Ek share \u{1F64F} Aloo Parivar ki Unnati ke liye !\n\nDownload Aloo Market App now!\nhttps://play.google.com/store/apps/details?id=com.mandi.aloo_market&hl=en_IN',
                      );
                    },
                  ),

                  // Menu Items
                  _menuItem(
                    icon: Icons.edit,
                    label: tr('edit_profile'),
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditProfileScreen(),
                        ),
                      );
                      if (result == true) {
                        _loadUserData(); // Refresh profile data
                      }
                    },
                  ),
                  if (userData?['role'] != 'aloo-mitra')
                    _menuItem(
                      icon: Icons.receipt_long,
                      label: tr('my_receipts'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MyReceiptPhotosScreen(),
                          ),
                        );
                      },
                    ),
                  _menuItem(
                    icon: Icons.language,
                    label: tr('change_language'),
                    onTap: () => _showLanguageDialog(),
                  ),
                  if (userData?['role'] == 'aloo-mitra')
                    _menuItem(
                      icon: Icons.campaign,
                      label: 'Advertise with Us',
                      subtitle: tr('promote_business'),
                      onTap: () {
                        Navigator.pushNamed(context, '/advertise_with_us');
                      },
                    ),
                  _menuItem(
                    icon: Icons.settings,
                    label: tr('settings'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  _menuItem(
                    icon: Icons.help_outline,
                    label: tr('help_support'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HelpSupportScreen(),
                        ),
                      );
                    },
                  ),
                  _menuItem(
                    icon: Icons.logout,
                    label: tr('logout'),
                    color: Colors.red,
                    onTap: _logout,
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryGreen, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
    String? subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: color ?? AppColors.primaryGreen),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: color ?? Colors.black,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              )
            : null,
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
        onTap: onTap,
      ),
    );
  }

  void _showLanguageDialog() {
    String selectedCode = AppLocalizations.currentLocale;
    final outerContext = context;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.language, color: AppColors.primaryGreen),
              const SizedBox(width: 10),
              Text(tr('select_language')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final code in AppLocalizations.supportedLocales) ...[
                  _languageOption(
                    AppLocalizations.nativeNameFor(code),
                    AppLocalizations.subtitleFor(code),
                    selectedCode == code,
                    () => setDialogState(() => selectedCode = code),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                tr('cancel'),
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await Future<void>.delayed(Duration.zero);
                await AppLocalizations.setLocale(selectedCode);
                if (!outerContext.mounted) return;
                final langLabel = AppLocalizations.nativeNameFor(selectedCode);
                ScaffoldMessenger.of(outerContext).showSnackBar(
                  SnackBar(
                    content: Text('✅ ${tr('language_changed')} $langLabel'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: Text(tr('save')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _languageOption(
    String lang,
    String subtitle,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGreen.withOpacity(0.1)
              : AppColors.surfaceVariant(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primaryGreen
                          : AppColors.textPrimary(context),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.primaryGreen),
          ],
        ),
      ),
    );
  }
}
