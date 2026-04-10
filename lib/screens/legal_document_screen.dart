import 'package:aloo_sbji_mandi/core/constants/legal_copy.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';

enum LegalDocumentKind { termsOfService, privacyPolicy }

/// Scrollable Terms of Service or Privacy Policy from [LegalCopy].
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.kind});

  final LegalDocumentKind kind;

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.currentLocale;
    final title = kind == LegalDocumentKind.termsOfService
        ? tr('terms_of_service')
        : tr('privacy_policy');
    final body = kind == LegalDocumentKind.termsOfService
        ? LegalCopy.termsOfService(locale)
        : LegalCopy.privacyPolicy(locale);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: CustomRoundedAppBar(title: title),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: SelectableText(
          body.trim(),
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: AppColors.textPrimary(context),
          ),
        ),
      ),
    );
  }
}
