import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:aloo_sbji_mandi/main.dart';
import 'package:aloo_sbji_mandi/screens/legal_document_screen.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _darkMode = prefs.getBool('dark_mode') ?? false;
    });
  }

  Future<void> _saveNotificationsSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    setState(() {
      _notificationsEnabled = value;
    });
  }

  // Future<void> _saveDarkModeSetting(bool value) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setBool('dark_mode', value);
  //   setState(() {
  //     _darkMode = value;
  //   });
  //   // Update the app theme
  //   MyApp.of(context)?.updateTheme(value);
  // }

  void _showLanguageDialog() {
    final outerContext = context;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('select_language')),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: AppLocalizations.supportedLocales.length,
            itemBuilder: (_, index) {
              final code = AppLocalizations.supportedLocales[index];
              final isSelected = AppLocalizations.currentLocale == code;
              return ListTile(
                title: Text(AppLocalizations.nativeNameFor(code)),
                subtitle: Text(AppLocalizations.subtitleFor(code)),
                trailing: isSelected
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  final langName = AppLocalizations.nativeNameFor(code);
                  Navigator.pop(dialogContext);
                  AppLocalizations.setLocale(code);
                  ScaffoldMessenger.of(outerContext).showSnackBar(
                    SnackBar(
                      content: Text('${tr('language_changed')} $langName'),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr('cancel')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: CustomRoundedAppBar(title: tr('settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('preferences'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 16),

            _settingsCard(
              children: [
                _switchTile(
                  icon: Icons.notifications_outlined,
                  title: tr('push_notifications'),
                  subtitle: tr('push_notifications_sub'),
                  value: _notificationsEnabled,
                  onChanged: _saveNotificationsSetting,
                ),
                // const Divider(height: 1),
                // _switchTile(
                //   icon: Icons.dark_mode_outlined,
                //   title: tr('dark_mode'),
                //   subtitle: tr('dark_mode_sub'),
                //   value: _darkMode,
                //   onChanged: _saveDarkModeSetting,
                // ),
              ],
            ),

            const SizedBox(height: 24),

            Text(
              tr('general'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 16),

            _settingsCard(
              children: [
                _actionTile(
                  icon: Icons.language_outlined,
                  title: tr('language'),
                  subtitle: AppLocalizations.nativeNameFor(
                    AppLocalizations.currentLocale,
                  ),
                  onTap: _showLanguageDialog,
                ),
                const Divider(height: 1),
                _actionTile(
                  icon: Icons.storage_outlined,
                  title: tr('clear_cache'),
                  subtitle: tr('clear_cache_sub'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(tr('cache_cleared')),
                        backgroundColor: AppColors.primaryGreen,
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            Text(
              tr('about'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 16),

            _settingsCard(
              children: [
                _actionTile(
                  icon: Icons.info_outline,
                  title: tr('app_version'),
                  subtitle: '1.0.0',
                  showArrow: false,
                ),
                const Divider(height: 1),
                _actionTile(
                  icon: Icons.description_outlined,
                  title: tr('terms_of_service'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) => const LegalDocumentScreen(
                          kind: LegalDocumentKind.termsOfService,
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                _actionTile(
                  icon: Icons.privacy_tip_outlined,
                  title: tr('privacy_policy'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) => const LegalDocumentScreen(
                          kind: LegalDocumentKind.privacyPolicy,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _settingsCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primaryGreen, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 12,
              ),
            )
          : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primaryGreen,
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    bool showArrow = true,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primaryGreen, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 12,
              ),
            )
          : null,
      trailing: showArrow
          ? Icon(Icons.chevron_right, color: Colors.grey[400])
          : null,
      onTap: onTap,
    );
  }
}
