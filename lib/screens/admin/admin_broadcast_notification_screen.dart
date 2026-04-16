import 'dart:convert';
import 'dart:io';

import 'package:aloo_sbji_mandi/core/service/admin_management_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:aloo_sbji_mandi/core/utils/toast_helper.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class AdminBroadcastNotificationScreen extends StatefulWidget {
  const AdminBroadcastNotificationScreen({super.key});

  @override
  State<AdminBroadcastNotificationScreen> createState() =>
      _AdminBroadcastNotificationScreenState();
}

class _AdminBroadcastNotificationScreenState
    extends State<AdminBroadcastNotificationScreen> {
  final AdminManagementService _adminService = AdminManagementService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Failed to pick image: $e');
      }
    }
  }

  Future<void> _removeImage() async {
    setState(() {
      _selectedImage = null;
    });
  }

  Future<void> _sendNotification() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    if (title.isEmpty) {
      ToastHelper.showError(context, tr('please_enter_a_title'));
      return;
    }

    if (message.isEmpty) {
      ToastHelper.showError(context, tr('please_enter_a_message'));
      return;
    }

    if (title.length > 200) {
      ToastHelper.showError(context, tr('title_less_than_200'));
      return;
    }

    if (message.length > 1000) {
      ToastHelper.showError(context, tr('message_less_than_1000'));
      return;
    }

    String? imageBase64;
    if (_selectedImage != null) {
      final bytes = await _selectedImage!.readAsBytes();
      imageBase64 = base64Encode(bytes);
    }

    // Confirm before sending
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          tr('confirm_broadcast'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('send_notification_to_all_msg'),
              style: GoogleFonts.inter(),
            ),
            const SizedBox(height: 16),
            Text(
              'Title: $title',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Message: $message',
              style: GoogleFonts.inter(color: Colors.grey[700]),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
            if (_selectedImage != null) ...[
              const SizedBox(height: 8),
              Text(
                tr('with_image_yes'),
                style: GoogleFonts.inter(color: Colors.green),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel'), style: GoogleFonts.inter()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(tr('send_to_all'), style: GoogleFonts.inter()),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSending = true);

    try {
      print('🚀 Starting broadcast notification send...');
      final result = await _adminService.sendBroadcastNotification(
        title: title,
        message: message,
        imageBase64: imageBase64,
      );

      print('✅ Broadcast result received: $result');

      if (!mounted) return;

      setState(() => _isSending = false);

      if (result['success']) {
        ToastHelper.showSuccess(
          context,
          result['message'] ?? tr('notification_sent_successfully'),
        );
        Navigator.pop(context); // Go back to admin home
      } else {
        // Check if it's an auth error
        if (result['needsAuth'] == true) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                tr('authentication_required'),
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              content: Text(
                tr('session_expired_login_again'),
                style: GoogleFonts.inter(),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Go back
                  },
                  child: Text(tr('ok'), style: GoogleFonts.inter()),
                ),
              ],
            ),
          );
        } else {
          ToastHelper.showError(
            context,
            result['message'] ?? tr('failed_to_send_notification'),
          );
        }
      }
    } catch (e) {
      print('❌ Exception in send: $e');
      if (mounted) {
        setState(() => _isSending = false);
        ToastHelper.showError(context, 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar:  CustomRoundedAppBar(
        title: tr('send_broadcast_notification_title'),
      ),
      body: _isSending
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    tr('sending_notification_to_all'),
                    style: GoogleFonts.inter(fontSize: 16),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.blue.shade700, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tr('broadcast_notification_info'),
                            style: GoogleFonts.inter(
                              color: Colors.blue.shade900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Title Field
                  Text(
                    tr('notification_title_required'),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    maxLength: 200,
                    decoration: InputDecoration(
                      hintText: tr('eg_important_update'),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xFF1E3A5F), width: 2),
                      ),
                    ),
                    style: GoogleFonts.inter(),
                  ),

                  const SizedBox(height: 16),

                  // Message Field
                  Text(
                    tr('notification_message_required'),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _messageController,
                    maxLength: 1000,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText:
                          tr('eg_important_announcement'),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xFF1E3A5F), width: 2),
                      ),
                    ),
                    style: GoogleFonts.inter(),
                  ),

                  const SizedBox(height: 16),

                  // Image Section
                  Text(
                    tr('notification_image_optional'),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (_selectedImage != null) ...[
                    // Show selected image
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        image: DecorationImage(
                          image: FileImage(_selectedImage!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.edit),
                            label: Text(
                              tr('change_image'),
                              style: GoogleFonts.inter(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _removeImage,
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: Text(
                              tr('remove'),
                              style: GoogleFonts.inter(color: Colors.red),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ),
                      ],
                    ),

                  ] else ...[
                    // Pick image button
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: Text(
                        tr('add_image'),
                        style: GoogleFonts.inter(),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Send Button
                  ElevatedButton.icon(
                    onPressed: _isSending ? null : _sendNotification,
                    icon: const Icon(Icons.send, color: Colors.white),
                    label: Text(
                      tr('send_to_all_users'),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Cancel Button
                  OutlinedButton(
                    onPressed: _isSending ? null : () => Navigator.pop(context),
                    child: Text(
                      tr('cancel'),
                      style: GoogleFonts.inter(fontSize: 16),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
