import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A compact language toggle button for the app bar.
/// Shows current language code (EN/HI/etc.) and opens a quick picker on tap.
class LanguageToggleWidget extends StatelessWidget {
  const LanguageToggleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocalizations.instance,
      builder: (context, _) {
        final currentCode = AppLocalizations.currentLocale.toUpperCase();

        return GestureDetector(
          onTap: () => _showLanguagePicker(context),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.language, color: Colors.white, size: 18),
                const SizedBox(width: 4),
                Text(
                  currentCode,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLanguagePicker(BuildContext context) {
    final current = AppLocalizations.currentLocale;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final maxH = MediaQuery.sizeOf(ctx).height * 0.85;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Select Language / भाषा चुनें',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      shrinkWrap: false,
                      children: [
                        for (final code in AppLocalizations.supportedLocales)
                          _languageTile(
                            ctx,
                            code: code,
                            current: current,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _languageTile(
    BuildContext sheetContext, {
    required String code,
    required String current,
  }) {
    final isSelected = code == current;
    final nativeName = AppLocalizations.nativeNameFor(code);
    final subtitle = AppLocalizations.subtitleFor(code);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : Colors.grey[100],
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            code.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
          ),
        ),
      ),
      title: Text(
        nativeName,
        style: GoogleFonts.inter(
          fontWeight:
              isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? AppColors.primaryGreen : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: Colors.grey[500],
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: AppColors.primaryGreen)
          : null,
      onTap: () {
        Navigator.pop(sheetContext);
        AppLocalizations.setLocale(code);
      },
    );
  }
}
