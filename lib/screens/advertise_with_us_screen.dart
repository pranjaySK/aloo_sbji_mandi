import 'dart:convert';

import 'package:aloo_sbji_mandi/core/service/advertisement_service.dart';
import 'package:aloo_sbji_mandi/core/service/cold_storage_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/toast_helper.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdvertiseWithUsScreen extends StatefulWidget {
  const AdvertiseWithUsScreen({super.key});

  @override
  State<AdvertiseWithUsScreen> createState() => _AdvertiseWithUsScreenState();
}

class _AdvertiseWithUsScreenState extends State<AdvertiseWithUsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();

  final AdvertisementService _adService = AdvertisementService();
  final ColdStorageService _coldStorageService = ColdStorageService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = false;
  bool _isLoadingData = true;
  int _selectedDuration = 30;
  String? _selectedColdStorageId;
  List<dynamic> _myColdStorages = [];
  List<Map<String, dynamic>> _myAds = [];
  String _userRole = '';

  // Preferred start date & time
  DateTime? _startDate;
  TimeOfDay? _startTime;

  // 5 slide images (base64 strings)
  final List<String?> _slideImages = List.filled(5, null);

  // Per-slide redirect URLs
  final List<TextEditingController> _slideLinkControllers =
      List.generate(5, (_) => TextEditingController());

  // Per-slide pricing (fetched from backend, defaults below)
  List<Map<String, dynamic>> _slidePricing = [
    {'label': 'Slide 1', 'price': 1000},
    {'label': 'Slide 2', 'price': 800},
    {'label': 'Slide 3', 'price': 600},
    {'label': 'Slide 4', 'price': 400},
    {'label': 'Slide 5', 'price': 200},
  ];

  List<Map<String, dynamic>> _durationOptions = [
    {'days': 7, 'label': '1 Week', 'multiplier': 1},
    {'days': 15, 'label': '15 Days', 'multiplier': 2},
    {'days': 30, 'label': '1 Month', 'multiplier': 3},
    {'days': 90, 'label': '3 Months', 'multiplier': 8},
  ];

  int get _slidesTotal {
    int total = 0;
    for (int i = 0; i < 5; i++) {
      if (_slideImages[i] != null) {
        total += _slidePricing[i]['price'] as int;
      }
    }
    return total;
  }

  int get _selectedMultiplier {
    final opt = _durationOptions.firstWhere(
      (o) => o['days'] == _selectedDuration,
      orElse: () => _durationOptions[2],
    );
    return opt['multiplier'] as int;
  }

  int get _totalPrice => _slidesTotal * _selectedMultiplier;

  // Razorpay
  late Razorpay _razorpay;
  String? _pendingAdId;
  String? _pendingOrderId;
  String? _userName;
  String? _userEmail;
  String? _userPhone;

  @override
  void initState() {
    super.initState();
    _initRazorpay();
    _loadData();
  }

  void _initRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final result = await _adService.verifyAdPayment(
        orderId: response.orderId ?? _pendingOrderId ?? '',
        paymentId: response.paymentId ?? '',
        signature: response.signature ?? '',
        advertisementId: _pendingAdId ?? '',
      );

      if (result['success']) {
        Fluttertoast.showToast(
          msg: 'Payment successful! Your ad is now active.',
          backgroundColor: Colors.green,
          toastLength: Toast.LENGTH_LONG,
        );
        // Refresh the ads list
        await _refreshAds();
      } else {
        Fluttertoast.showToast(
          msg: result['message'] ?? 'Payment verification failed',
          backgroundColor: Colors.red,
          toastLength: Toast.LENGTH_LONG,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Verification error. If amount was deducted, your ad will activate automatically.',
        backgroundColor: Colors.orange,
        toastLength: Toast.LENGTH_LONG,
      );
    }

    _pendingAdId = null;
    _pendingOrderId = null;
    if (mounted) setState(() => _isLoading = false);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    String errorMessage = 'Payment failed';
    try {
      if (response.message != null) {
        final errData = json.decode(response.message!);
        if (errData is Map) {
          errorMessage = errData['error']?['description'] ??
              errData['description'] ??
              response.message!;
        } else {
          errorMessage = response.message!;
        }
      }
    } catch (_) {
      errorMessage = response.message ?? 'Payment failed';
    }

    Fluttertoast.showToast(
      msg: 'Payment failed: $errorMessage',
      backgroundColor: Colors.red,
      toastLength: Toast.LENGTH_LONG,
    );

    _pendingAdId = null;
    _pendingOrderId = null;
    if (mounted) setState(() => _isLoading = false);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    Fluttertoast.showToast(
      msg: 'External wallet selected: ${response.walletName}',
      backgroundColor: Colors.blue,
    );
  }

  Future<void> _refreshAds() async {
    final adsResult = await _adService.getMyAdvertisements();
    if (adsResult['success']) {
      setState(() {
        _myAds = List<Map<String, dynamic>>.from(
          adsResult['data']['advertisements'] ?? [],
        );
      });
    }
  }

  Future<void> _onMakePayment(Map<String, dynamic> ad) async {
    final adId = ad['_id']?.toString() ?? '';
    final price = ad['price'] ?? 0;
    final title = ad['title'] ?? 'Advertisement';
    final duration = ad['durationDays'] ?? 30;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.payment, color: AppColors.primaryGreen),
            const SizedBox(width: 8),
            const Text('Confirm Payment'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            _paymentDetailRow('Duration', '$duration days'),
            const Divider(height: 20),
            _paymentDetailRow(
              'Amount',
              '\u{20B9}$price',
              isBold: true,
              valueColor: AppColors.primaryGreen,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your ad will be activated immediately after payment.',
                      style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.qr_code_2, size: 18),
            label: const Text('Pay Now'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    _pendingAdId = adId;

    // Create Razorpay order
    final orderResult = await _adService.createAdPaymentOrder(adId);

    if (!orderResult['success']) {
      if (mounted) setState(() => _isLoading = false);
      Fluttertoast.showToast(
        msg: orderResult['message'] ?? 'Failed to create order',
        backgroundColor: Colors.red,
      );
      _pendingAdId = null;
      return;
    }

    final orderData = orderResult['data'];
    _pendingOrderId = orderData['orderId'];

    // Open Razorpay checkout
    var options = {
      'key': orderData['keyId'],
      'amount': orderData['amount'],
      'currency': orderData['currency'] ?? 'INR',
      'name': 'Aloo Sabji Mandi',
      'description': 'Advertisement: $title',
      'order_id': orderData['orderId'],
      'prefill': {
        'name': _userName ?? '',
        'email': _userEmail ?? '',
        'contact': _userPhone ?? '',
      },
      'theme': {'color': '#4CAF50'},
      'notes': {'advertisementId': adId, 'title': title},
      'config': {
        'display': {
          'blocks': {
            'utib': {
              'name': 'Pay using UPI QR',
              'instruments': [
                {'method': 'upi', 'flows': ['qr']},
                {'method': 'upi', 'flows': ['collect', 'intent']},
              ],
            },
            'other': {
              'name': 'Other Payment Methods',
              'instruments': [
                {'method': 'card'},
                {'method': 'netbanking'},
                {'method': 'wallet'},
              ],
            },
          },
          'sequence': ['block.utib', 'block.other'],
          'preferences': {'show_default_blocks': false},
        },
      },
    };

    try {
      if (mounted) setState(() => _isLoading = false);
      _razorpay.open(options);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _pendingAdId = null;
      _pendingOrderId = null;
      Fluttertoast.showToast(
        msg: 'Error starting payment',
        backgroundColor: Colors.red,
      );
    }
  }

  Widget _paymentDetailRow(String label, String value,
      {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: isBold ? 18 : 14,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('userRole') ?? '';
    final userJson = prefs.getString('user');
    if (userJson != null) {
      final userData = json.decode(userJson);
      _userName = userData['name'] ?? userData['fullName'] ?? '';
      _userEmail = userData['email'] ?? '';
      _userPhone = userData['phone'] ?? userData['mobileNumber'] ?? '';
    }
    _phoneController.text = prefs.getString('userPhone') ?? '';

    // Fetch dynamic pricing from backend
    try {
      final pricingResult = await _adService.getAdPricing();
      if (pricingResult['success'] && pricingResult['data'] != null) {
        final data = pricingResult['data'];
        if (data['slidePricing'] != null) {
          _slidePricing = List<Map<String, dynamic>>.from(
            (data['slidePricing'] as List).map(
              (e) => Map<String, dynamic>.from(e),
            ),
          );
        }
        if (data['durationOptions'] != null) {
          _durationOptions = List<Map<String, dynamic>>.from(
            (data['durationOptions'] as List).map(
              (e) => Map<String, dynamic>.from(e),
            ),
          );
          // Ensure selected duration is still valid
          final validDays = _durationOptions.map((o) => o['days']).toSet();
          if (!validDays.contains(_selectedDuration)) {
            _selectedDuration = _durationOptions.isNotEmpty
                ? _durationOptions[0]['days'] as int
                : 30;
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to load pricing: $e');
      // Keep defaults
    }

    // Load user's cold storages if they're a cold storage owner
    if (_userRole == 'cold-storage') {
      final result = await _coldStorageService.getMyColdStorages();
      if (result['success']) {
        _myColdStorages = result['data']['coldStorages'] ?? [];
      }
    }

    // Load my advertisement requests
    final adsResult = await _adService.getMyAdvertisements();
    if (adsResult['success']) {
      _myAds = List<Map<String, dynamic>>.from(
        adsResult['data']['advertisements'] ?? [],
      );
    }

    setState(() => _isLoadingData = false);
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryGreen,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryGreen,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickSlideImage(int slideIndex) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (image != null) {
        if (kIsWeb) {
          // Web: skip cropper (known cropperjs init bug), use image directly
          final bytes = await image.readAsBytes();
          final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
          setState(() {
            _slideImages[slideIndex] = base64String;
          });
        } else {
          // Android/iOS: open native cropper with aspect ratio options
          final croppedFile = await ImageCropper().cropImage(
            sourcePath: image.path,
            uiSettings: [
              AndroidUiSettings(
                toolbarTitle: 'Edit Banner Image',
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
                  CropAspectRatioPreset.square,
                ],
              ),
              IOSUiSettings(
                title: 'Edit Banner Image',
                aspectRatioPresets: [
                  CropAspectRatioPreset.original,
                  CropAspectRatioPreset.ratio3x2,
                  CropAspectRatioPreset.ratio16x9,
                  CropAspectRatioPreset.ratio4x3,
                  CropAspectRatioPreset.square,
                ],
              ),
            ],
          );

          if (croppedFile != null) {
            final bytes = await croppedFile.readAsBytes();
            final base64String =
                'data:image/jpeg;base64,${base64Encode(bytes)}';
            setState(() {
              _slideImages[slideIndex] = base64String;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Failed to pick image');
      }
    }
  }

  Future<void> _editSlideImage(int slideIndex) async {
    // Re-crop existing image is not possible from base64, so re-pick and crop
    await _pickSlideImage(slideIndex);
  }

  void _removeSlideImage(int slideIndex) {
    setState(() {
      _slideImages[slideIndex] = null;
    });
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    // Collect non-null images
    final images = _slideImages
        .where((img) => img != null)
        .map((img) => img!)
        .toList();

    // Collect redirect URLs for slides that have images
    final redirectUrls = <String>[];
    for (int i = 0; i < 5; i++) {
      if (_slideImages[i] != null) {
        redirectUrls.add(_slideLinkControllers[i].text.trim());
      }
    }

    if (images.isEmpty) {
      ToastHelper.showError(context, 'Please add at least one slide image');
      return;
    }

    setState(() => _isLoading = true);

    final result = await _adService.createAdvertisementRequest(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      images: images,
      redirectUrls: redirectUrls,
      advertiserType: _userRole.isNotEmpty ? _userRole : 'cold-storage',
      coldStorageId: _selectedColdStorageId,
      durationDays: _selectedDuration,
      contactPhone: _phoneController.text.trim(),
      startDate: _startDate != null
          ? DateTime(
              _startDate!.year,
              _startDate!.month,
              _startDate!.day,
              _startTime?.hour ?? 0,
              _startTime?.minute ?? 0,
            )
          : null,
    );

    setState(() => _isLoading = false);

    if (result['success']) {
      ToastHelper.showSuccess(
        context,
        'Advertisement request submitted successfully!',
      );
      _clearForm();
      _loadData();
    } else {
      ToastHelper.showError(
        context,
        result['message'] ?? 'Failed to submit request',
      );
    }
  }

  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    _selectedColdStorageId = null;
    _selectedDuration = 30;
    _startDate = null;
    _startTime = null;
    for (int i = 0; i < 5; i++) {
      _slideImages[i] = null;
      _slideLinkControllers[i].clear();
    }
  }

  Widget _buildSlideImage(String base64Str) {
    try {
      String raw = base64Str;
      if (raw.contains(',')) {
        raw = raw.split(',').last;
      }
      final bytes = base64Decode(raw);
      return Image.memory(
        Uint8List.fromList(bytes),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } catch (e) {
      return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Advertise with Us',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoadingData
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryGreen,
                          AppColors.primaryGreen.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.campaign,
                          color: Colors.white,
                          size: 48,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Promote Your Business',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your ad slides will appear on all home page sliders',
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // My Requests Section
                  if (_myAds.isNotEmpty) ...[
                    Text(
                      'My Advertisement Requests',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _myAds.length,
                      itemBuilder: (context, index) {
                        final ad = _myAds[index];
                        return _AdRequestCard(
                          ad: ad,
                          onMakePayment: _onMakePayment,
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  // New Request Form
                  Text(
                    'Submit New Request',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        TextFormField(
                          controller: _titleController,
                          decoration: _inputDecoration(
                            'Advertisement Title',
                            Icons.title,
                          ),
                          validator: (v) =>
                              v?.isEmpty ?? true ? 'Title is required' : null,
                        ),
                        const SizedBox(height: 16),

                        // Description
                        TextFormField(
                          controller: _descriptionController,
                          decoration: _inputDecoration(
                            'Description (optional)',
                            Icons.description,
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),

                        // ===== SLIDE IMAGES (5 slots) =====
                        Text(
                          'Banner Slide Images (up to 5)',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Recommended size: 1200x400 pixels. Add slides as per your need.',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),

                        ...List.generate(5, (index) {
                          final hasImage = _slideImages[index] != null;
                          final slidePrice =
                              _slidePricing[index]['price'] as int;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: hasImage
                                    ? AppColors.primaryGreen
                                    : Colors.grey[300]!,
                                width: hasImage ? 2 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Slide label with price
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: hasImage
                                        ? AppColors.primaryGreen.withOpacity(
                                            0.1,
                                          )
                                        : Colors.grey[50],
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(11),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        hasImage
                                            ? Icons.check_circle
                                            : Icons.image_outlined,
                                        color: hasImage
                                            ? AppColors.primaryGreen
                                            : Colors.grey,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Slide ${index + 1}',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                          color: hasImage
                                              ? AppColors.primaryGreen
                                              : Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: hasImage
                                              ? AppColors.primaryGreen
                                                    .withOpacity(0.15)
                                              : Colors.orange[50],
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          '\u{20B9}$slidePrice',
                                          style: TextStyle(
                                            color: hasImage
                                                ? AppColors.primaryGreen
                                                : Colors.orange[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      if (hasImage) ...[
                                        GestureDetector(
                                          onTap: () => _editSlideImage(index),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            margin: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[50],
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Icon(
                                              Icons.crop_rotate,
                                              color: Colors.blue[600],
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => _removeSlideImage(index),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.red[50],
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Icon(
                                              Icons.delete_outline,
                                              color: Colors.red[400],
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                // Image area
                                GestureDetector(
                                  onTap: () => _pickSlideImage(index),
                                  child: Container(
                                    height: hasImage ? 140 : 80,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: const BorderRadius.vertical(
                                        bottom: Radius.circular(11),
                                      ),
                                    ),
                                    child: hasImage
                                        ? ClipRRect(
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  bottom: Radius.circular(11),
                                                ),
                                            child: _buildSlideImage(
                                              _slideImages[index]!,
                                            ),
                                          )
                                        : Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.add_photo_alternate,
                                                color: Colors.grey[400],
                                                size: 28,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Tap to add image',
                                                style: TextStyle(
                                                  color: Colors.grey[500],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),

                                // Link input (shown when image is added)
                                if (hasImage)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      10,
                                      8,
                                      10,
                                      10,
                                    ),
                                    child: TextFormField(
                                      controller:
                                          _slideLinkControllers[index],
                                      decoration: InputDecoration(
                                        hintText:
                                            'Link URL (e.g. https://example.com)',
                                        hintStyle: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[400],
                                        ),
                                        prefixIcon: Icon(
                                          Icons.link,
                                          size: 18,
                                          color: AppColors.primaryGreen,
                                        ),
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                            color: AppColors.primaryGreen,
                                          ),
                                        ),
                                      ),
                                      keyboardType: TextInputType.url,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),

                        // Price summary
                        if (_slidesTotal > 0)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.primaryGreen.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.receipt_long,
                                  color: AppColors.primaryGreen,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Slides Total: ',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                Text(
                                  '\u{20B9}$_slidesTotal',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${_slideImages.where((s) => s != null).length} slide(s)',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 8),

                        // Cold Storage Selection (for cold storage owners only)
                        if (_myColdStorages.isNotEmpty &&
                            _userRole == 'cold-storage') ...[
                          Text(
                            'Select Cold Storage',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                hint: Text(tr('choose_your_cold_storage')),
                                value: _selectedColdStorageId,
                                items: _myColdStorages.map((cs) {
                                  return DropdownMenuItem<String>(
                                    value: cs['_id'],
                                    child: Text(cs['name'] ?? 'Unnamed'),
                                  );
                                }).toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedColdStorageId = v),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Start Date & Time
                        Text(
                          'Preferred Start Date & Time',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // Date picker
                            Expanded(
                              child: GestureDetector(
                                onTap: _pickStartDate,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        color: AppColors.primaryGreen,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _startDate != null
                                              ? '${_startDate!.day.toString().padLeft(2, '0')}/${_startDate!.month.toString().padLeft(2, '0')}/${_startDate!.year}'
                                              : 'Select Date',
                                          style: TextStyle(
                                            color: _startDate != null
                                                ? Colors.black
                                                : Colors.grey[500],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Time picker
                            Expanded(
                              child: GestureDetector(
                                onTap: _pickStartTime,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        color: AppColors.primaryGreen,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _startTime != null
                                              ? _startTime!.format(context)
                                              : 'Select Time',
                                          style: TextStyle(
                                            color: _startTime != null
                                                ? Colors.black
                                                : Colors.grey[500],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_startDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 14,
                                  color: Colors.grey[500],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Ad will start on ${_startDate!.day.toString().padLeft(2, '0')}/${_startDate!.month.toString().padLeft(2, '0')}/${_startDate!.year}${_startTime != null ? ' at ${_startTime!.format(context)}' : ''}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Duration Selection
                        Text(
                          'Advertisement Duration',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _durationOptions.map((opt) {
                            final isSelected = _selectedDuration == opt['days'];
                            return GestureDetector(
                              onTap: () => setState(
                                () => _selectedDuration = opt['days'],
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primaryGreen
                                      : Colors.white,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primaryGreen
                                        : Colors.grey[300]!,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      opt['label'],
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.black,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${opt['days']} days',
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white70
                                            : Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Estimated Total
                        if (_slidesTotal > 0)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primaryGreen.withOpacity(0.1),
                                  AppColors.primaryGreen.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primaryGreen.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      tr('slides_cost'),
                                      style: GoogleFonts.inter(
                                        color: Colors.grey[700],
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      '\u{20B9}$_slidesTotal',
                                      style: GoogleFonts.inter(fontSize: 14),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Duration: $_selectedDuration days (x$_selectedMultiplier)',
                                      style: GoogleFonts.inter(
                                        color: Colors.grey[700],
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      'x$_selectedMultiplier',
                                      style: GoogleFonts.inter(fontSize: 14),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      tr('estimated_total'),
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      '\u{20B9}$_totalPrice',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: AppColors.primaryGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Contact Details
                        TextFormField(
                          controller: _phoneController,
                          decoration: _inputDecoration(
                            'Contact Phone',
                            Icons.phone,
                          ),
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : Text(
                                    'Submit Request',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Note
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.orange[700],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Your request will be reviewed by admin. Once approved, you can make payment to activate the advertisement.',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primaryGreen),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryGreen),
      ),
      filled: true,
      fillColor: AppColors.inputFill(context),
    );
  }

  @override
  void dispose() {
    _razorpay.clear();
    _titleController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    for (final c in _slideLinkControllers) {
      c.dispose();
    }
    super.dispose();
  }
}

class _AdRequestCard extends StatelessWidget {
  final Map<String, dynamic> ad;
  final void Function(Map<String, dynamic> ad)? onMakePayment;

  const _AdRequestCard({required this.ad, this.onMakePayment});

  @override
  Widget build(BuildContext context) {
    final status = ad['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final images = ad['images'] as List? ?? [];
    final imageUrl = ad['imageUrl'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  ad['title'] ?? 'Untitled',
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
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Show slide count
          if (images.isNotEmpty)
            Text(
              '${images.length} slide${images.length > 1 ? 's' : ''} uploaded',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            )
          else if (imageUrl.isNotEmpty)
            Text(
              '1 image uploaded',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          const SizedBox(height: 4),

          Text(
            'Duration: ${ad['durationDays']} days  \u{2022}  Price: \u{20B9}${ad['price']}',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          if (status == 'rejected' && ad['rejectionReason'] != null) ...[
            const SizedBox(height: 8),
            Text(
              'Reason: ${ad['rejectionReason']}',
              style: TextStyle(color: Colors.red[700], fontSize: 13),
            ),
          ],
          if (status == 'approved') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => onMakePayment?.call(ad),
                icon: const Icon(Icons.payment, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                label: Text(
                  tr('make_payment'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
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
}
