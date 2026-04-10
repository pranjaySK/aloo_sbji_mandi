import 'dart:io';

import 'package:aloo_sbji_mandi/core/service/admin_management_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:aloo_sbji_mandi/core/utils/toast_helper.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:aloo_sbji_mandi/core/constants/api_constant.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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
  String? _uploadedImageUrl;
  bool _isSending = false;
  bool _isUploading = false;

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
          _uploadedImageUrl = null; // Reset uploaded URL when new image selected
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
      _uploadedImageUrl = null;
    });
  }

  Future<String?> _uploadImageToCloudinary(File imageFile) async {
    try {
      setState(() => _isUploading = true);

      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/dphxleab3/image/upload'),
      );

      // Add image file
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      // Add upload preset (you may need to create an unsigned preset in Cloudinary)
      request.fields['upload_preset'] = 'ml_default'; // Change this to your preset
      request.fields['folder'] = 'notifications';

      // Send request
      final response = await request.send();
      final responseData = await response.stream.toBytes();
      final responseString = String.fromCharCodes(responseData);
      final jsonResponse = json.decode(responseString);

      if (response.statusCode == 200) {
        return jsonResponse['secure_url'];
      } else {
        throw Exception('Upload failed: ${jsonResponse['error']['message']}');
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Image upload failed: $e');
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _sendNotification() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    if (title.isEmpty) {
      ToastHelper.showError(context, 'Please enter a title');
      return;
    }

    if (message.isEmpty) {
      ToastHelper.showError(context, 'Please enter a message');
      return;
    }

    if (title.length > 200) {
      ToastHelper.showError(context, 'Title must be less than 200 characters');
      return;
    }

    if (message.length > 1000) {
      ToastHelper.showError(context, 'Message must be less than 1000 characters');
      return;
    }

    // Upload image if selected and not already uploaded
    String? imageUrl = _uploadedImageUrl;
    if (_selectedImage != null && imageUrl == null) {
      imageUrl = await _uploadImageToCloudinary(_selectedImage!);
      if (imageUrl == null) {
        ToastHelper.showError(context, 'Failed to upload image. Try again.');
        return;
      }
      setState(() => _uploadedImageUrl = imageUrl);
    }

    // Confirm before sending
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Confirm Broadcast',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will send a notification to ALL users in the app.',
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
            if (imageUrl != null) ...[
              const SizedBox(height: 8),
              Text(
                'With Image: Yes',
                style: GoogleFonts.inter(color: Colors.green),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text('Send to All', style: GoogleFonts.inter()),
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
        imageUrl: imageUrl,
      );

      print('✅ Broadcast result received: $result');

      if (!mounted) return;

      setState(() => _isSending = false);

      if (result['success']) {
        ToastHelper.showSuccess(
          context,
          result['message'] ?? 'Notification sent successfully!',
        );
        Navigator.pop(context); // Go back to admin home
      } else {
        // Check if it's an auth error
        if (result['needsAuth'] == true) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                'Authentication Required',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              content: Text(
                'Your session may have expired. Please login again as admin.',
                style: GoogleFonts.inter(),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Go back
                  },
                  child: Text('OK', style: GoogleFonts.inter()),
                ),
              ],
            ),
          );
        } else {
          ToastHelper.showError(
            context,
            result['message'] ?? 'Failed to send notification',
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
      appBar: const CustomRoundedAppBar(
        title: 'Send Broadcast Notification',
      ),
      body: _isSending
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Sending notification to all users...',
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
                            'This notification will be sent to all users (Farmers, Traders, Cold Storage, Aloo Mitra)',
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
                    'Notification Title *',
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
                      hintText: 'e.g., Important Update',
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
                    'Notification Message *',
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
                          'e.g., Dear users, we have an important announcement...',
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
                    'Notification Image (Optional)',
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
                            onPressed: _isUploading ? null : _pickImage,
                            icon: const Icon(Icons.edit),
                            label: Text(
                              'Change Image',
                              style: GoogleFonts.inter(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isUploading ? null : _removeImage,
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: Text(
                              'Remove',
                              style: GoogleFonts.inter(color: Colors.red),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_isUploading) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 4),
                      Text(
                        'Uploading image...',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ] else ...[
                    // Pick image button
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: Text(
                        'Add Image',
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
                    onPressed: _isSending || _isUploading ? null : _sendNotification,
                    icon: const Icon(Icons.send, color: Colors.white),
                    label: Text(
                      'Send to All Users',
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
                    onPressed: _isSending || _isUploading
                        ? null
                        : () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
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
