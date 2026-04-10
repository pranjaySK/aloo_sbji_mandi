import 'package:flutter/material.dart';

class AppColors {
  static const primaryGreen = Color(0xFF004711);
  static const lightGreen = Color(0xFFCFFF9E);
  static const background = Color(0xFFF4F6F1);
  static const cardGreen = Color(0xFFDDFFB3);
  static const cardBrown = Color(0xFFF3E5D3);
  static const heading = Color(0xFF004711);
  static const border = Color(0xff9B7542);
  static const buttonTextColor = Color(0xffffffff);
  static const bulerTextColor = Color(0xff757575);
  static const blackColor = Color(0xff000000);

  // ── Dark-mode aware helpers ──
  // Use these instead of hardcoded Colors.white / Colors.black87 etc.

  /// Scaffold / page background
  static Color scaffoldBg(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  /// Card / container surface
  static Color cardBg(BuildContext context) =>
      Theme.of(context).cardColor;

  /// Primary text color  
  static Color textPrimary(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

  /// Secondary / subtitle text
  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[400]!
          : Colors.grey[600]!;

  /// Hint / placeholder text
  static Color textHint(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[600]!
          : Colors.grey[400]!;

  /// Divider / border
  static Color dividerColor(BuildContext context) =>
      Theme.of(context).dividerColor;

  /// Surface variant (slightly different from card)
  static Color surfaceVariant(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF2C2C2C)
          : Colors.grey[50]!;

  /// Input field fill
  static Color inputFill(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF2C2C2C)
          : Colors.white;

  /// Icon color (non-primary)
  static Color iconColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white70
          : Colors.grey[700]!;

  /// Check if currently in dark mode
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}
