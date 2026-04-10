import 'package:flutter/material.dart';

class ToastHelper {
  static void showSuccess(BuildContext context, String message) {
    _showToast(context, message, Colors.green, Icons.check_circle);
  }

  static void showError(BuildContext context, String message) {
    _showToast(context, message, Colors.red, Icons.error);
  }

  static void showInfo(BuildContext context, String message) {
    _showToast(context, message, Colors.blue, Icons.info);
  }

  static void showWarning(BuildContext context, String message) {
    _showToast(context, message, Colors.orange, Icons.warning);
  }

  static void showCreated(BuildContext context, String itemName) {
    _showToast(context, '$itemName created successfully!', Colors.green.shade700, Icons.check_circle);
  }

  static void showUpdated(BuildContext context, String itemName) {
    _showToast(context, '$itemName updated successfully!', Colors.green.shade700, Icons.check_circle);
  }

  static void showDeleted(BuildContext context, String itemName) {
    _showToast(context, '$itemName deleted successfully!', Colors.red, Icons.delete);
  }

  static void showBookingCreated(BuildContext context) {
    _showToast(context, 'Booking request sent successfully! The owner will review it.', Colors.green.shade700, Icons.check_circle);
  }

  static void showListingCreated(BuildContext context) {
    _showToast(context, 'Listing created successfully! It is now visible to others.', Colors.green.shade700, Icons.check_circle);
  }

  static void showPostCreated(BuildContext context) {
    _showToast(context, 'Post shared successfully!', Colors.green.shade700, Icons.check_circle);
  }

  static void _showToast(BuildContext context, String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // OK button to dismiss early
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
