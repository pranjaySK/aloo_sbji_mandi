import 'dart:convert';
import 'dart:io';

import 'package:aloo_sbji_mandi/core/service/receipt_photo_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
// Conditional import for web camera
import 'package:aloo_sbji_mandi/screens/receipt/camera_screen_stub.dart'
    if (dart.library.html) 'package:aloo_sbji_mandi/screens/receipt/web_camera_screen.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/utils/ist_datetime.dart';

class MyReceiptPhotosScreen extends StatefulWidget {
  const MyReceiptPhotosScreen({super.key});

  @override
  State<MyReceiptPhotosScreen> createState() => _MyReceiptPhotosScreenState();
}

class _MyReceiptPhotosScreenState extends State<MyReceiptPhotosScreen> {
  final ReceiptPhotoService _service = ReceiptPhotoService();
  final ImagePicker _picker = ImagePicker();

  List<ReceiptPhoto> _photos = [];
  bool _isLoading = true;
  double _totalSales = 0;
  double _totalPurchases = 0;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);

    final photos = await _service.getAllReceiptPhotos();
    final sales = await _service.getTotalAmount(transactionType: 'sale');
    final purchases = await _service.getTotalAmount(
      transactionType: 'purchase',
    );

    setState(() {
      _photos = photos;
      _totalSales = sales;
      _totalPurchases = purchases;
      _isLoading = false;
    });
  }

  Future<void> _captureReceipt() async {
    if (kIsWeb) {
      // Use custom web camera screen
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (context) => const WebCameraScreen()),
      );

      if (result != null) {
        // Save the captured image
        await _service.saveReceiptPhoto(
          imagePath: result,
          transactionType: 'sale',
        );

        _loadPhotos();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('receipt_saved')),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    } else {
      // For mobile, use image_picker with camera
      try {
        final XFile? image = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
          preferredCameraDevice: CameraDevice.rear,
        );

        if (image != null) {
          String imagePath = image.path;

          // Show confirmation dialog
          _showConfirmSaveDialog(imagePath);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr('error_opening_camera')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showConfirmSaveDialog(String imagePath) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.photo_camera, color: AppColors.primaryGreen),
            const SizedBox(width: 8),
            Text(tr('save_receipt_question')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview Image
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildImageWidget(imagePath, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr('confirm_save_receipt'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              tr('cancel'),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);

              // Save receipt
              await _service.saveReceiptPhoto(
                imagePath: imagePath,
                transactionType: 'sale',
              );

              _loadPhotos();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(tr('receipt_saved')),
                  backgroundColor: AppColors.primaryGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check, color: Colors.white),
            label: Text(tr('save'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddDetailsDialog(String imagePath) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final vendorController = TextEditingController();
    final notesController = TextEditingController();
    String transactionType = 'sale';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.receipt_long, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              Text(tr('receipt_details')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Preview Image
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildImageWidget(imagePath, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 16),

                // Transaction Type
                Row(
                  children: [
                    Text(
                      '${tr('type')}:',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'sale',
                            label: Text(tr('sale')),
                            icon: const Icon(Icons.sell, size: 16),
                          ),
                          ButtonSegment(
                            value: 'purchase',
                            label: Text(tr('purchase')),
                            icon: const Icon(Icons.shopping_cart, size: 16),
                          ),
                        ],
                        selected: {transactionType},
                        onSelectionChanged: (value) {
                          setDialogState(() => transactionType = value.first);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Title
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: tr('title_optional'),
                    hintText: tr('title_hint'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 12),

                // Amount
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: tr('amount_inr'),
                    hintText: '0',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.currency_rupee),
                  ),
                ),
                const SizedBox(height: 12),

                // Vendor
                TextField(
                  controller: vendorController,
                  decoration: InputDecoration(
                    labelText: transactionType == 'sale'
                        ? tr('sold_to')
                        : tr('bought_from'),
                    hintText: tr('enter_name'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),

                // Notes
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: tr('notes'),
                    hintText: tr('notes_hint'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.note),
                  ),
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
              onPressed: () async {
                Navigator.pop(context);

                await _service.saveReceiptPhoto(
                  imagePath: imagePath,
                  title: titleController.text.isEmpty
                      ? null
                      : titleController.text,
                  amount: double.tryParse(amountController.text),
                  vendor: vendorController.text.isEmpty
                      ? null
                      : vendorController.text,
                  transactionType: transactionType,
                  notes: notesController.text.isEmpty
                      ? null
                      : notesController.text,
                );

                _loadPhotos();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(tr('receipt_saved')),
                    backgroundColor: AppColors.primaryGreen,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: Text(
                tr('save'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(ReceiptPhoto photo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text(tr('delete_question')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('confirm_delete_receipt')),
            if (photo.title != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        photo.title!,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (photo.amount != null)
                      Text(
                        '₹${photo.amount!.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: photo.transactionType == 'sale'
                              ? Colors.green[700]
                              : Colors.red[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('action_cannot_be_undone'),
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('no_keep')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _service.deleteReceiptPhoto(photo.id);
              _loadPhotos();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(tr('receipt_deleted')),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              tr('yes_delete'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _viewReceiptDetails(ReceiptPhoto photo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    photo.title ?? tr('receipt'),
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _showDeleteConfirmation(photo);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildImageWidget(photo.imagePath),
                  ),
                  const SizedBox(height: 16),

                  // Details Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _detailRow(
                          icon: Icons.calendar_today,
                          label: tr('date'),
                          value: DateFormat(
                            'dd MMM yyyy, hh:mm a',
                          ).format(photo.capturedAt.toIST()),
                        ),
                        if (photo.transactionType != null)
                          _detailRow(
                            icon: photo.transactionType == 'sale'
                                ? Icons.sell
                                : Icons.shopping_cart,
                            label: tr('type'),
                            value: photo.transactionType == 'sale'
                                ? tr('sale')
                                : tr('purchase'),
                            valueColor: photo.transactionType == 'sale'
                                ? Colors.green
                                : Colors.orange,
                          ),
                        if (photo.amount != null)
                          _detailRow(
                            icon: Icons.currency_rupee,
                            label: tr('amount'),
                            value: '₹${photo.amount!.toStringAsFixed(0)}',
                            valueColor: photo.transactionType == 'sale'
                                ? Colors.green[700]
                                : Colors.red[700],
                            isBold: true,
                          ),
                        if (photo.vendor != null)
                          _detailRow(
                            icon: Icons.person,
                            label: photo.transactionType == 'sale'
                                ? tr('buyer')
                                : tr('seller'),
                            value: photo.vendor!,
                          ),
                        if (photo.notes != null && photo.notes!.isNotEmpty)
                          _detailRow(
                            icon: Icons.note,
                            label: tr('notes'),
                            value: photo.notes!,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text('$label:', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWidget(String imagePath, {BoxFit fit = BoxFit.contain}) {
    if (imagePath.startsWith('data:image')) {
      // Base64 image (web)
      final base64String = imagePath.split(',').last;
      return Image.memory(
        base64Decode(base64String),
        fit: fit,
        errorBuilder: (context, error, stack) => _errorPlaceholder(),
      );
    } else {
      // File path (mobile)
      return Image.file(
        File(imagePath),
        fit: fit,
        errorBuilder: (context, error, stack) => _errorPlaceholder(),
      );
    }
  }

  Widget _errorPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              tr('image_not_found'),
              style: TextStyle(color: Colors.grey[600]),
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
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        title: Text(
          tr('my_receipt_photos'),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadPhotos,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary Header - Total Receipts Only
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryGreen, Color(0xFF2E7D32)],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.photo_library,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_photos.length}',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tr('receipts_saved'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),

                // Photos Grid
                Expanded(
                  child: _photos.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadPhotos,
                          child: GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 0.85,
                                ),
                            itemCount: _photos.length,
                            itemBuilder: (context, index) {
                              return _buildReceiptGridItem(_photos[index]);
                            },
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _captureReceipt,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 8,
        icon: const Icon(Icons.camera_alt, size: 28),
        label: Text(
          tr('capture'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _summaryItem({
    required String label,
    required String value,
    required IconData icon,
    Color? color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.camera_alt, size: 48, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          Text(
            tr('no_receipts_yet'),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              tr('capture_mandi_receipts'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptGridItem(ReceiptPhoto photo) {
    return GestureDetector(
      onTap: () => _viewReceiptDetails(photo),
      onLongPress: () => _showDeleteConfirmation(photo),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              _buildImageWidget(photo.imagePath, fit: BoxFit.cover),

              // Gradient overlay at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (photo.amount != null)
                        Text(
                          '₹${photo.amount!.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      Text(
                        DateFormat('dd/MM').format(photo.capturedAt.toIST()),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Transaction type badge
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: photo.transactionType == 'sale'
                        ? Colors.green
                        : Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    photo.transactionType == 'sale' ? 'S' : 'P',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptCard(ReceiptPhoto photo) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _viewReceiptDetails(photo),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 70,
                  height: 70,
                  child: _buildImageWidget(photo.imagePath, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            photo.title ?? tr('receipt'),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: photo.transactionType == 'sale'
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            photo.transactionType == 'sale'
                                ? tr('sale')
                                : tr('purchase'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: photo.transactionType == 'sale'
                                  ? Colors.green[700]
                                  : Colors.orange[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (photo.vendor != null)
                      Text(
                        photo.vendor!,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('dd MMM yyyy').format(photo.capturedAt.toIST()),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        if (photo.amount != null)
                          Text(
                            '₹${photo.amount!.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: photo.transactionType == 'sale'
                                  ? Colors.green[700]
                                  : Colors.red[700],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Delete Button
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _showDeleteConfirmation(photo),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
