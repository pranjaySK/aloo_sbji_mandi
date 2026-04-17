import 'dart:convert';
import 'dart:typed_data';

import 'package:aloo_sbji_mandi/core/service/advertisement_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/toast_helper.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class AdminAdsScreen extends StatefulWidget {
  const AdminAdsScreen({super.key});

  @override
  State<AdminAdsScreen> createState() => _AdminAdsScreenState();
}

class _AdminAdsScreenState extends State<AdminAdsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AdvertisementService _adService = AdvertisementService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _allAds = [];
  List<Map<String, dynamic>> _pendingAds = [];
  List<Map<String, dynamic>> _approvedAds = [];
  List<Map<String, dynamic>> _activeAds = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAds();
  }

  Future<void> _loadAds() async {
    setState(() => _isLoading = true);

    final result = await _adService.getAllAdvertisements();
    if (result['success']) {
      _allAds = List<Map<String, dynamic>>.from(
        result['data']['advertisements'] ?? [],
      );
      _pendingAds = _allAds.where((ad) => ad['status'] == 'pending').toList();
      _approvedAds = _allAds.where((ad) => ad['status'] == 'approved').toList();
      _activeAds = _allAds.where((ad) => ad['status'] == 'active').toList();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _approveAd(String id) async {
    final result = await _adService.approveAdvertisement(id);
    if (result['success']) {
      ToastHelper.showSuccess(context, tr('advertisement_approved'));
      _loadAds();
    } else {
      ToastHelper.showError(
        context,
        result['message'] ?? tr('failed_to_approve'),
      );
    }
  }

  Future<void> _rejectAd(String id) async {
    final reasonController = TextEditingController();
    final outerCtx = context;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(tr('reject_advertisement')),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(
            labelText: tr('rejection_reason'),
            hintText: tr('enter_reason_for_rejection'),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final result = await _adService.rejectAdvertisement(
                id,
                reason: reasonController.text.trim(),
              );
              if (!mounted) return;
              if (result['success']) {
                ToastHelper.showSuccess(outerCtx, tr('advertisement_rejected'));
                _loadAds();
              } else {
                ToastHelper.showError(
                  outerCtx,
                  result['message'] ?? tr('failed_to_reject'),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              tr('reject'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmPayment(String id) async {
    final outerCtx = context;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(tr('confirm_payment')),
        content: Text(tr('confirm_payment_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final result = await _adService.confirmPayment(id);
              if (!mounted) return;
              if (result['success']) {
                ToastHelper.showSuccess(
                  outerCtx,
                  tr('payment_confirmed_active'),
                );
                _loadAds();
              } else {
                ToastHelper.showError(
                  outerCtx,
                  result['message'] ?? tr('failed_to_confirm'),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
            ),
            child: Text(
              tr('confirm'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAd(String id, String title) async {
    final outerCtx = context;
    showDialog(
      context: outerCtx,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text(tr('delete_advertisement'))),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: GoogleFonts.inter(color: Colors.black87),
            children: [
              TextSpan(
                text: trArgs('confirm_delete_permanent_args', {'name': title}),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final result = await _adService.adminDeleteAdvertisement(id);
              if (!mounted) return;
              if (result['success']) {
                ToastHelper.showSuccess(outerCtx, tr('advertisement_deleted'));
                _loadAds();
              } else {
                ToastHelper.showError(
                  outerCtx,
                  result['message'] ?? tr('failed_to_delete'),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              tr('delete'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editAd(Map<String, dynamic> ad) async {
    final titleController = TextEditingController(text: ad['title'] ?? '');
    final descriptionController = TextEditingController(
      text: ad['description'] ?? '',
    );
    final priceController = TextEditingController(text: '${ad['price'] ?? 0}');
    int durationDays = ad['durationDays'] ?? 30;
    String currentStatus = ad['status'] ?? 'pending';
    String? newBase64Image;
    Uint8List? newImageBytes;
    bool isSaving = false;

    // Existing images
    final existingImages = <String>[];
    final imgList = ad['images'] as List? ?? [];
    for (final img in imgList) {
      if (img != null && img.toString().isNotEmpty)
        existingImages.add(img.toString());
    }
    if (existingImages.isEmpty &&
        (ad['imageUrl'] ?? '').toString().isNotEmpty) {
      existingImages.add(ad['imageUrl'].toString());
    }

    Future<void> pickEditImage(StateSetter setDialogState) async {
      try {
        final picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
        );
        if (image == null) return;

        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
          setDialogState(() {
            newBase64Image = base64String;
            newImageBytes = bytes;
          });
        } else {
          final croppedFile = await ImageCropper().cropImage(
            sourcePath: image.path,
            uiSettings: [
              AndroidUiSettings(
                toolbarTitle: tr('edit_ad_image'),
                toolbarColor: AppColors.primaryGreen,
                toolbarWidgetColor: Colors.white,
                activeControlsWidgetColor: AppColors.primaryGreen,
                initAspectRatio: CropAspectRatioPreset.ratio16x9,
                lockAspectRatio: false,
                aspectRatioPresets: [
                  CropAspectRatioPreset.original,
                  CropAspectRatioPreset.ratio3x2,
                  CropAspectRatioPreset.ratio16x9,
                ],
              ),
              IOSUiSettings(title: tr('edit_ad_image')),
            ],
          );
          if (croppedFile != null) {
            final bytes = await croppedFile.readAsBytes();
            final base64String =
                'data:image/jpeg;base64,${base64Encode(bytes)}';
            setDialogState(() {
              newBase64Image = base64String;
              newImageBytes = bytes;
            });
          }
        }
      } catch (e) {
        if (mounted) ToastHelper.showError(context, 'Failed to pick image: $e');
      }
    }

    final outerCtx = context;
    showDialog(
      context: outerCtx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.edit, color: AppColors.primaryGreen),
              const SizedBox(width: 10),
              Expanded(child: Text(tr('edit_advertisement'))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: tr('title_required'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 12),

                // Image area
                GestureDetector(
                  onTap: () => pickEditImage(setDialogState),
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: newImageBytes != null
                        ? Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: Image.memory(
                                  newImageBytes!,
                                  width: double.infinity,
                                  height: 120,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => setDialogState(() {
                                    newBase64Image = null;
                                    newImageBytes = null;
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    tr('new_image_tap_change'),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : existingImages.isNotEmpty
                        ? Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: _buildEditImage(existingImages[0]),
                              ),
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    tr('tap_to_replace'),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 36,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                tr('tap_add_image'),
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),

                // Description
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: tr('description'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.description),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),

                // Price
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tr('price_rupees'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.currency_rupee),
                  ),
                ),
                const SizedBox(height: 12),

                // Duration
                Row(
                  children: [
                    Text(tr('duration_label')),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: [7, 15, 30, 60, 90, 365].contains(durationDays)
                          ? durationDays
                          : 30,
                      items: [7, 15, 30, 60, 90, 365]
                          .map(
                            (d) => DropdownMenuItem(
                              value: d,
                              child: Text('$d ${tr('days')}'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => durationDays = v ?? 30),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Status
                Row(
                  children: [
                    Text(tr('status_label')),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: currentStatus,
                      items:
                          [
                                'pending',
                                'approved',
                                'rejected',
                                'active',
                                'expired',
                                'cancelled',
                              ]
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    s.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _statusColor(s),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (v) => setDialogState(
                        () => currentStatus = v ?? currentStatus,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(tr('cancel')),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (titleController.text.trim().isEmpty) {
                        ToastHelper.showError(
                          dialogCtx,
                          tr('title_required_error'),
                        );
                        return;
                      }
                      setDialogState(() => isSaving = true);
                      final result = await _adService.adminEditAdvertisement(
                        ad['_id'],
                        title: titleController.text.trim(),
                        description: descriptionController.text.trim(),
                        durationDays: durationDays,
                        price: double.tryParse(priceController.text.trim()),
                        status: currentStatus,
                        images: newBase64Image != null
                            ? [newBase64Image!]
                            : null,
                      );
                      setDialogState(() => isSaving = false);
                      if (!dialogCtx.mounted) return;
                      Navigator.pop(dialogCtx);
                      if (!mounted) return;
                      if (result['success']) {
                        ToastHelper.showSuccess(
                          outerCtx,
                          tr('advertisement_updated_success'),
                        );
                        _loadAds();
                      } else {
                        ToastHelper.showError(
                          outerCtx,
                          result['message'] ?? tr('failed_to_update_msg'),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      tr('save_changes'),
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditImage(String imgStr) {
    if (imgStr.startsWith('data:image')) {
      try {
        String raw = imgStr;
        if (raw.contains(',')) raw = raw.split(',').last;
        final bytes = base64Decode(raw);
        return Image.memory(
          Uint8List.fromList(bytes),
          width: double.infinity,
          height: 120,
          fit: BoxFit.cover,
        );
      } catch (e) {
        return Container(
          height: 120,
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image, size: 40),
        );
      }
    }
    return Image.network(
      imgStr,
      width: double.infinity,
      height: 120,
      fit: BoxFit.cover,
      errorBuilder: (c, e, s) => Container(
        height: 120,
        color: Colors.grey[200],
        child: const Icon(Icons.broken_image, size: 40),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      case 'active':
        return Colors.green;
      case 'expired':
        return Colors.grey;
      case 'cancelled':
        return Colors.red.shade300;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          tr('manage_advertisements_title'),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAds),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: '${tr('all')} (${_allAds.length})'),
            Tab(text: '${tr('pending_tab')} (${_pendingAds.length})'),
            Tab(text: '${tr('approved_tab')} (${_approvedAds.length})'),
            Tab(text: '${tr('active_ads')} (${_activeAds.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAdsList(_allAds),
                _buildAdsList(_pendingAds),
                _buildAdsList(_approvedAds),
                _buildAdsList(_activeAds),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateBannerDialog,
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
        label: Text(
          tr('add_banner'),
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  void _showCreateBannerDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    int durationDays = 30;
    String? pickedBase64Image;
    Uint8List? pickedImageBytes;
    bool isUploading = false;

    Future<void> pickBannerImage(StateSetter setDialogState) async {
      try {
        final picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
        );
        if (image == null) return;

        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
          setDialogState(() {
            pickedBase64Image = base64String;
            pickedImageBytes = bytes;
          });
        } else {
          final croppedFile = await ImageCropper().cropImage(
            sourcePath: image.path,
            uiSettings: [
              AndroidUiSettings(
                toolbarTitle: tr('edit_banner_image'),
                toolbarColor: AppColors.primaryGreen,
                toolbarWidgetColor: Colors.white,
                activeControlsWidgetColor: AppColors.primaryGreen,
                initAspectRatio: CropAspectRatioPreset.ratio16x9,
                lockAspectRatio: false,
                aspectRatioPresets: [
                  CropAspectRatioPreset.original,
                  CropAspectRatioPreset.ratio3x2,
                  CropAspectRatioPreset.ratio16x9,
                  CropAspectRatioPreset.ratio4x3,
                ],
              ),
              IOSUiSettings(
                title: tr('edit_banner_image'),
                aspectRatioPresets: [
                  CropAspectRatioPreset.original,
                  CropAspectRatioPreset.ratio3x2,
                  CropAspectRatioPreset.ratio16x9,
                  CropAspectRatioPreset.ratio4x3,
                ],
              ),
            ],
          );

          if (croppedFile != null) {
            final bytes = await croppedFile.readAsBytes();
            final base64String =
                'data:image/jpeg;base64,${base64Encode(bytes)}';
            setDialogState(() {
              pickedBase64Image = base64String;
              pickedImageBytes = bytes;
            });
          }
        }
      } catch (e) {
        if (mounted) {
          ToastHelper.showError(context, 'Failed to pick image: $e');
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.add_photo_alternate, color: AppColors.primaryGreen),
              const SizedBox(width: 10),
              Text(tr('add_new_banner')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: tr('banner_title_required'),
                    hintText: tr('banner_title_hint'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 16),
                // ─── Image Picker Area ───
                GestureDetector(
                  onTap: () => pickBannerImage(setDialogState),
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: pickedImageBytes != null
                            ? AppColors.primaryGreen
                            : Colors.grey.shade300,
                        width: pickedImageBytes != null ? 2 : 1,
                      ),
                    ),
                    child: pickedImageBytes != null
                        ? Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: Image.memory(
                                  pickedImageBytes!,
                                  width: double.infinity,
                                  height: 150,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: GestureDetector(
                                  onTap: () => setDialogState(() {
                                    pickedBase64Image = null;
                                    pickedImageBytes = null;
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    tr('tap_to_change_banner'),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 40,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                tr('tap_upload_banner_image'),
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tr('jpg_png_gallery'),
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: tr('description_optional'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.description),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(tr('duration_label')),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: durationDays,
                      items: [7, 15, 30, 60, 90, 365]
                          .map(
                            (d) => DropdownMenuItem(
                              value: d,
                              child: Text('$d ${tr('days')}'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => durationDays = v ?? 30),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('cancel')),
            ),
            ElevatedButton(
              onPressed: isUploading
                  ? null
                  : () async {
                      if (titleController.text.trim().isEmpty) {
                        ToastHelper.showError(
                          context,
                          tr('banner_title_required_error'),
                        );
                        return;
                      }
                      if (pickedBase64Image == null) {
                        ToastHelper.showError(
                          context,
                          tr('please_upload_banner_image'),
                        );
                        return;
                      }
                      setDialogState(() => isUploading = true);
                      final result = await _adService.adminCreateBanner(
                        title: titleController.text.trim(),
                        images: [pickedBase64Image!],
                        description: descriptionController.text.trim(),
                        durationDays: durationDays,
                      );
                      setDialogState(() => isUploading = false);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      if (result['success']) {
                        ToastHelper.showSuccess(
                          context,
                          tr('banner_created_activated'),
                        );
                        _loadAds();
                      } else {
                        ToastHelper.showError(
                          context,
                          result['message'] ?? tr('failed_to_create_banner'),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
              child: isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      tr('create_activate'),
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdsList(List<Map<String, dynamic>> ads) {
    if (ads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              tr('no_advertisements_found'),
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAds,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: ads.length,
        itemBuilder: (context, index) {
          final ad = ads[index];
          return _AdCard(
            ad: ad,
            onApprove: ad['status'] == 'pending'
                ? () => _approveAd(ad['_id'])
                : null,
            onReject: ad['status'] == 'pending'
                ? () => _rejectAd(ad['_id'])
                : null,
            onConfirmPayment: ad['status'] == 'approved'
                ? () => _confirmPayment(ad['_id'])
                : null,
            onEdit: () => _editAd(ad),
            onDelete: () => _deleteAd(ad['_id'], ad['title'] ?? tr('untitled')),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class _AdCard extends StatelessWidget {
  final Map<String, dynamic> ad;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onConfirmPayment;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _AdCard({
    required this.ad,
    this.onApprove,
    this.onReject,
    this.onConfirmPayment,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final advertiser = ad['advertiser'] ?? {};
    final status = ad['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final images = ad['images'] as List? ?? [];
    final imageUrl = ad['imageUrl'] as String? ?? '';

    // Collect all display images
    final List<String> displayImages = [];
    if (images.isNotEmpty) {
      for (final img in images) {
        if (img != null && img.toString().isNotEmpty) {
          displayImages.add(img.toString());
        }
      }
    } else if (imageUrl.isNotEmpty) {
      displayImages.add(imageUrl);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Preview - show all slides
          if (displayImages.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: SizedBox(
                height: 120,
                child: displayImages.length == 1
                    ? _buildAdImage(displayImages[0])
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: displayImages.length,
                        itemBuilder: (context, index) {
                          return Container(
                            width: 180,
                            margin: EdgeInsets.only(
                              right: index < displayImages.length - 1 ? 4 : 0,
                            ),
                            child: Stack(
                              children: [
                                _buildAdImage(displayImages[index]),
                                Positioned(
                                  top: 4,
                                  left: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${tr('slide_prefix')}${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        ad['title'] ?? tr('untitled'),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status.toUpperCase() == 'PENDING'
                            ? tr('pending_tab')
                            : status.toUpperCase() == 'APPROVED'
                            ? tr('approved_tab')
                            : status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Advertiser Info
                Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      '${advertiser['firstName'] ?? ''} ${advertiser['lastName'] ?? ''}'
                          .trim(),
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.phone, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      advertiser['phone'] ?? tr('not_available'),
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Duration & Price
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${ad['durationDays']} ${tr('days')}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.monetization_on,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '₹${ad['price']}',
                      style: TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                // Active Period
                if (ad['startDate'] != null && ad['endDate'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${tr('active_ads')}: ${_formatDate(ad['startDate'])} - ${_formatDate(ad['endDate'])}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],

                // Edit & Delete buttons (always shown)
                const SizedBox(height: 12),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: Delete
                    Row(
                      children: [
                        // Edit button commented out — not working currently
                        // IconButton(
                        //   onPressed: onEdit,
                        //   icon: const Icon(Icons.edit, color: Colors.blue),
                        //   tooltip: 'Edit',
                        //   style: IconButton.styleFrom(
                        //     backgroundColor: Colors.blue.withOpacity(0.1),
                        //   ),
                        // ),
                        // const SizedBox(width: 8),
                        IconButton(
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: tr('delete'),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.red.withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                    // Right: Status action buttons
                    Row(
                      children: [
                        if (onReject != null)
                          TextButton.icon(
                            onPressed: onReject,
                            icon: const Icon(
                              Icons.close,
                              color: Colors.red,
                              size: 18,
                            ),
                            label: Text(
                              tr('reject'),
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (onApprove != null)
                          ElevatedButton.icon(
                            onPressed: onApprove,
                            icon: const Icon(Icons.check, size: 16),
                            label: Text(
                              tr('approve'),
                              style: const TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                            ),
                          ),
                        if (onConfirmPayment != null)
                          ElevatedButton.icon(
                            onPressed: onConfirmPayment,
                            icon: const Icon(Icons.payment, size: 16),
                            label: Text(
                              tr('confirm_pay_btn'),
                              style: TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      case 'paid':
        return Colors.purple;
      case 'active':
        return Colors.green;
      case 'expired':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return tr('not_available');
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildAdImage(String imgStr) {
    if (imgStr.startsWith('data:image')) {
      try {
        String raw = imgStr;
        if (raw.contains(',')) raw = raw.split(',').last;
        final bytes = base64Decode(raw);
        return Image.memory(
          Uint8List.fromList(bytes),
          height: 120,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      } catch (e) {
        return Container(
          height: 120,
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
        );
      }
    }
    return Image.network(
      imgStr,
      height: 120,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        height: 120,
        color: Colors.grey[200],
        child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
      ),
    );
  }
}
