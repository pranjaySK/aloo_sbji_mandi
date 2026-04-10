import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LanguageScreen extends StatefulWidget {
  final String? destinationRoute;

  const LanguageScreen({super.key, this.destinationRoute});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  // Current language selected by default
  String selectedLanguage = AppLocalizations.currentLanguageName;

  String? get _destinationRoute {
    // Check for route argument passed via Navigator
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    return args?['destinationRoute'] ?? widget.destinationRoute;
  }

  String _getChooseLanguageText(String lang) {
    switch (lang) {
      case "हिंदी":
        return tr('choose_language');
      case "ਪੰਜਾਬੀ":
        return "ਆਪਣੀ ਭਾਸ਼ਾ ਚੁਣੋ";
      case "ગુજરાતી":
        return "તમારી ભાષા પસંદ કરો";
      case "मराठी":
        return "तुमची भाषा निवडा";
      case "বাংলা":
        return "আপনার ভাষা নির্বাচন করুন";
      case "தமிழ்":
        return "உங்கள் மொழியை தேர்ந்தெடுக்கவும்";
      case "తెలుగు":
        return "మీ భాషను ఎంచుకోండి";
      case "ಕನ್ನಡ":
        return "ನಿಮ್ಮ ಭಾಷೆಯನ್ನು ಆಯ್ಕೆಮಾಡಿ";
      case "ଓଡ଼ିଆ":
        return "ଆପଣଙ୍କ ଭାଷା ବାଛନ୍ତୁ";
      default:
        return "Choose your language";
    }
  }

  final List<String> languages = [
    "हिंदी",
    "English",
    "ਪੰਜਾਬੀ",
    "ગુજરાતી",
    "मराठी",
    "বাংলা",
    "தமிழ்",
    "తెలుగు",
    "ಕನ್ನಡ",
    "ଓଡ଼ିଆ",
  ];

  Widget languageTile(String text) {
    final bool isSelected = selectedLanguage == text;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedLanguage = text;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : Colors.grey[300]!,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryGreen : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryGreen
                      : Colors.grey[400]!,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      body: Column(
        children: [
          // Green header section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 40, bottom: 24),
            decoration: const BoxDecoration(color: Color(0xFF1B4332)),
            child: Column(
              children: [
                // Logo
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Image.asset('assets/logo.png', height: 60),
                ),

                const SizedBox(height: 16),

                Text(
                  AppLocalizations.tr('choose_language'),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Language options
          Expanded(
            child: Container(
              color: AppColors.surfaceVariant(context),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ...languages.map((lang) => languageTile(lang)),

                    const SizedBox(height: 24),

                    // Done button
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B4332),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          // Set the language preference and wait for rebuild
                          if (selectedLanguage == "हिंदी") {
                            await AppLocalizations.setLocale('hi');
                          } else if (selectedLanguage == "ਪੰਜਾਬੀ") {
                            await AppLocalizations.setLocale('pa');
                          } else if (selectedLanguage == "ગુજરાતી") {
                            await AppLocalizations.setLocale('gu');
                          } else if (selectedLanguage == "मराठी") {
                            await AppLocalizations.setLocale('mr');
                          } else if (selectedLanguage == "বাংলা") {
                            await AppLocalizations.setLocale('bn');
                          } else if (selectedLanguage == "தமிழ்") {
                            await AppLocalizations.setLocale('ta');
                          } else if (selectedLanguage == "తెలుగు") {
                            await AppLocalizations.setLocale('te');
                          } else if (selectedLanguage == "ಕನ್ನಡ") {
                            await AppLocalizations.setLocale('kn');
                          } else if (selectedLanguage == "ଓଡ଼ିଆ") {
                            await AppLocalizations.setLocale('or');
                          } else {
                            await AppLocalizations.setLocale('en');
                          }

                          if (!mounted) return;
                          // Navigate to destination route or role selection
                          final destination = _destinationRoute;
                          if (destination != null) {
                            Navigator.pushReplacementNamed(
                              context,
                              destination,
                            );
                          } else {
                            Navigator.pushReplacementNamed(context, '/role');
                          }
                        },
                        child: Text(
                          AppLocalizations.tr('done'),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
