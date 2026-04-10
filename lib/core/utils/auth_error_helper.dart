import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Utility class for handling authentication errors across the app.
/// Detects JWT/auth errors from API responses and provides a unified
/// "Session expired" flow that clears tokens and redirects to login.
class AuthErrorHelper {
  /// Check if an error message or HTTP status code indicates an auth error.
  static bool isAuthError(String? message, {int? statusCode}) {
    if (statusCode == 401 || statusCode == 403) return true;
    if (message == null) return false;
    final lower = message.toLowerCase();
    return lower.contains('jwt') ||
        lower.contains('token') &&
            (lower.contains('expired') ||
                lower.contains('invalid') ||
                lower.contains('malformed')) ||
        lower.contains('unauthorized') ||
        lower.contains('not authenticated') ||
        lower.contains('authentication failed');
  }

  /// Get a user-friendly message for auth errors.
  static String getAuthErrorMessage({bool isHindi = false}) {
    return tr('session_expired_message');
  }

  /// Clear auth tokens and navigate to login screen.
  static Future<void> handleSessionExpired(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    // Preserve non-auth preferences
    final lastSeenTimestamp = prefs.getString(
      'lastSeenTraderRequestsTimestamp',
    );
    final appLocale = prefs.getString('app_locale');
    final darkMode = prefs.getBool('darkMode');

    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    await prefs.remove('user');
    await prefs.remove('userRole');
    await prefs.remove('userId');

    // Restore preserved preferences
    if (lastSeenTimestamp != null) {
      await prefs.setString(
        'lastSeenTraderRequestsTimestamp',
        lastSeenTimestamp,
      );
    }
    if (appLocale != null) await prefs.setString('app_locale', appLocale);
    if (darkMode != null) await prefs.setBool('darkMode', darkMode);

    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  /// Build the "Session expired" error widget with a Login Again button.
  static Widget buildSessionExpiredView({
    required BuildContext context,
    bool isHindi = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 80, color: Colors.orange),
            const SizedBox(height: 20),
            Text(
              tr('session_expired'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              tr('session_expired_detail'),
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => handleSessionExpired(context),
              icon: const Icon(Icons.login),
              label: Text(tr('login_again')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
