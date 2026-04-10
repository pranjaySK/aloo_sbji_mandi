import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aloo_sbji_mandi/core/service/cold_storage_service.dart';
import 'package:aloo_sbji_mandi/core/service/google_geocoding_service.dart';
import 'package:aloo_sbji_mandi/core/service/listing_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:aloo_sbji_mandi/core/utils/toast_helper.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:aloo_sbji_mandi/widgets/common_widget.dart/drop_down_widget.dart';
import 'package:aloo_sbji_mandi/widgets/common_widget.dart/label_widget.dart';
import 'package:aloo_sbji_mandi/widgets/location_map_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/utils/ist_datetime.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreateSellRequestScreen extends StatefulWidget {
  final String listingType; // 'seed' or 'crop'
  final String sourceType; // 'field' or 'cold_storage'
  final bool showQuality; // Show quality selector (Vyapari only)

  const CreateSellRequestScreen({
    super.key,
    this.listingType = 'crop',
    this.sourceType = 'field',
    this.showQuality = false,
  });

  @override
  State<CreateSellRequestScreen> createState() =>
      _CreateSellRequestScreenState();
}

class _CreateSellRequestScreenState extends State<CreateSellRequestScreen> {
  String? selectedVariety;
  String selectedSize = "Large";
  String selectedQuality = "Good";
  String selectedUnit = "Packet";
  double _packetWeight = 50.0;

  // Source type - for seed it's always cold_storage, for crop it comes from widget.sourceType
  late String _selectedSourceType;

  // Unit options - Packet first
  final List<String> _unitOptions = ['Packet', 'Quintal', 'Kg'];

  // Controllers
  final TextEditingController _customVarietyController =
      TextEditingController();
  final TextEditingController _quantityController = TextEditingController(
    text: '49',
  );
  final FocusNode _quantityFocusNode = FocusNode();
  final TextEditingController _pricePerUnitController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _kisanNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _coldStorageNameController =
      TextEditingController();
  final TextEditingController _coldStorageLocationController =
      TextEditingController();

  // Image & Location
  File? _capturedImage;
  File? _capturedImage2; // Optional second photo

  // Per-photo location data (photo 1)
  String? _captureDateTime;
  String? _captureLocation;
  double? _captureLatitude;
  double? _captureLongitude;

  // Per-photo location data (photo 2)
  String? _captureDateTime2;
  String? _captureLocation2;
  double? _captureLatitude2;
  double? _captureLongitude2;

  bool _isCapturing1 = false;
  bool _isCapturing2 = false;
  bool _isSubmitting = false;

  // Services
  final ListingService _listingService = ListingService();
  final GoogleGeocodingService _googleGeocodingService = GoogleGeocodingService();

  // Cold Storage suggestions
  final ColdStorageService _coldStorageService = ColdStorageService();
  List<Map<String, dynamic>> _allColdStorages = [];
  List<Map<String, dynamic>> _filteredColdStorages = [];
  Map<String, dynamic>? _selectedColdStorage;

  // Variety list with "Others" option at top
  final List<String> _varietyList = [
    "Others",
    "Kufri Bahar (3797)",
    "Kufri Jyoti",
    "Kufri Pukhraj",
    "Kufri Chipsona-1",
    "Kufri Chipsona-2",
    "Kufri Chipsona-3",
    "Kufri Ashoka",
    "Kufri Badshah",
    "Kufri Ganga",
    "Kufri Girma",
    "Kufri Gaurav",
    "Kufri Giriraj",
    "Kufri Himalini",
    "Kufri Himsona",
    "Kufri Red",
    "Kufri Lalima",
    "Kufri Sutlej",
    "Kufri Sangam",
    "Kufri Ratan",
    "Kufri Tejas",
    "Kufri Chipbharat-1",
    "Kufri Chipbharat-2",
    "Kufri Chandramukhi",
  ];

  @override
  void initState() {
    super.initState();
    // For seed, always use cold_storage. For crop, use the sourceType passed from SellLocationScreen
    _selectedSourceType = widget.listingType == 'seed'
        ? 'cold_storage'
        : widget.sourceType;
    _loadKisanInfo();
    _loadColdStorages();
    _quantityController.addListener(_calculatePrice);
    _pricePerUnitController.addListener(_calculatePrice);
    _coldStorageNameController.addListener(_filterColdStorages);
    _quantityFocusNode.addListener(_onQuantityFocusChange);
  }

  @override
  void dispose() {
    _quantityFocusNode.removeListener(_onQuantityFocusChange);
    _quantityController.removeListener(_calculatePrice);
    _pricePerUnitController.removeListener(_calculatePrice);
    _coldStorageNameController.removeListener(_filterColdStorages);
    _customVarietyController.dispose();
    _quantityFocusNode.dispose();
    _quantityController.dispose();
    _pricePerUnitController.dispose();
    _priceController.dispose();
    _kisanNameController.dispose();
    _mobileController.dispose();
    _descriptionController.dispose();
    _coldStorageNameController.dispose();
    _coldStorageLocationController.dispose();
    super.dispose();
  }

  /// When user leaves the quantity field, enforce minimum 49
  void _onQuantityFocusChange() {
    if (!_quantityFocusNode.hasFocus) {
      final text = _quantityController.text;
      final quantity = int.tryParse(text) ?? 0;
      if (quantity < 49) {
        _quantityController.text = '49';
        _quantityController.selection = TextSelection.collapsed(offset: 2);
      }
    }
  }

  /// Calculate price based on quantity and price per unit
  void _calculatePrice() {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    final pricePerUnit = double.tryParse(_pricePerUnitController.text) ?? 0;
    final totalPrice = quantity * pricePerUnit;

    if (quantity > 0 && pricePerUnit > 0) {
      _priceController.text = totalPrice.toStringAsFixed(0);
    } else {
      _priceController.text = '';
    }
  }

  /// Load Kisan information from SharedPreferences (actual user data)
  Future<void> _loadKisanInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');

    if (userJson != null) {
      try {
        final userData = json.decode(userJson);
        setState(() {
          // Get name from firstName + lastName or name field
          String firstName = userData['firstName'] ?? '';
          String lastName = userData['lastName'] ?? '';
          String fullName = '$firstName $lastName'.trim();
          if (fullName.isEmpty) {
            fullName = userData['name'] ?? '';
          }
          _kisanNameController.text = fullName;
          final rawPhone = userData['phone']?.toString() ?? '';
          final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
          if (digits.length >= 10) {
            _mobileController.text = digits.substring(digits.length - 10);
          }
        });
      } catch (e) {
        debugPrint('Error parsing user data: $e');
      }
    }
  }

  /// Load all cold storages for suggestions
  Future<void> _loadColdStorages() async {
    debugPrint('Loading cold storages...');
    final result = await _coldStorageService.getAllColdStorages();
    debugPrint('Cold storage result: $result');
    if (result['success'] == true && result['data'] != null) {
      setState(() {
        // API returns data.coldStorages array
        final coldStoragesData =
            result['data']['coldStorages'] ?? result['data'];
        _allColdStorages = List<Map<String, dynamic>>.from(coldStoragesData);
        debugPrint('Loaded ${_allColdStorages.length} cold storages');
      });
    } else {
      debugPrint('Failed to load cold storages: ${result['message']}');
    }
  }

  /// Filter cold storages based on user input
  void _filterColdStorages() {
    final query = _coldStorageNameController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredColdStorages = [];
        _selectedColdStorage = null;
      });
      return;
    }

    setState(() {
      _filteredColdStorages = _allColdStorages
          .where((storage) {
            final name = (storage['name'] ?? '').toString().toLowerCase();
            final location = (storage['location'] ?? storage['city'] ?? '')
                .toString()
                .toLowerCase();
            return name.contains(query) || location.contains(query);
          })
          .take(5)
          .toList();
    });
  }

  /// Select a cold storage from suggestions
  void _selectColdStorage(Map<String, dynamic> storage) {
    setState(() {
      _selectedColdStorage = storage;
      _coldStorageNameController.text = storage['name'] ?? '';
      _coldStorageLocationController.text =
          storage['location'] ?? storage['city'] ?? '';
      _filteredColdStorages = [];
    });
  }

  /// Add watermark with date, time, and location to the captured image
  Future<File?> _addWatermarkToImage(
    File imageFile,
    String dateTime,
    String location,
  ) async {
    try {
      // Read the image bytes
      final Uint8List imageBytes = await imageFile.readAsBytes();

      // Decode the image
      final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image originalImage = frameInfo.image;

      // Create a recording canvas
      final int width = originalImage.width;
      final int height = originalImage.height;

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      // Draw the original image
      canvas.drawImage(originalImage, Offset.zero, Paint());

      // Calculate text size based on image dimensions (responsive)
      final double fontSize = (width * 0.025).clamp(14.0, 32.0);
      final double padding = (width * 0.02).clamp(10.0, 30.0);
      final double lineHeight = fontSize * 1.4;

      // Create watermark lines (avoid emojis — they crash Canvas on some Android devices)
      // Use readable address for watermark, never raw lat/lng
      final List<String> watermarkLines = ['Date: $dateTime', 'Loc: $location'];

      // Calculate background rectangle dimensions
      final double rectHeight =
          (watermarkLines.length * lineHeight) + (padding * 2);
      final double rectWidth = width * 0.95;
      final double rectX = (width - rectWidth) / 2;
      final double rectY = height - rectHeight - padding;

      // Draw semi-transparent background
      final Paint bgPaint = Paint()
        ..color = Colors.black.withOpacity(0.7)
        ..style = PaintingStyle.fill;

      final RRect backgroundRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(rectX, rectY, rectWidth, rectHeight),
        const Radius.circular(12),
      );
      canvas.drawRRect(backgroundRect, bgPaint);

      // Draw border
      final Paint borderPaint = Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(backgroundRect, borderPaint);

      // Draw text lines
      double currentY = rectY + padding;
      for (final String line in watermarkLines) {
        final ui.ParagraphBuilder paragraphBuilder =
            ui.ParagraphBuilder(
                ui.ParagraphStyle(
                  textAlign: TextAlign.left,
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                ),
              )
              ..pushStyle(
                ui.TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    const ui.Shadow(
                      color: Colors.black,
                      blurRadius: 4,
                      offset: Offset(1, 1),
                    ),
                  ],
                ),
              )
              ..addText(line);

        final ui.Paragraph paragraph = paragraphBuilder.build()
          ..layout(ui.ParagraphConstraints(width: rectWidth - (padding * 2)));

        canvas.drawParagraph(paragraph, Offset(rectX + padding, currentY));
        currentY += lineHeight;
      }

      // Convert canvas to image
      final ui.Picture picture = recorder.endRecording();
      final ui.Image watermarkedImage = await picture.toImage(width, height);

      // Convert to bytes
      final ByteData? byteData = await watermarkedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) return null;

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Save to a new file
      final Directory tempDir = await getTemporaryDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final File watermarkedFile = File(
        '${tempDir.path}/potato_$timestamp.png',
      );
      await watermarkedFile.writeAsBytes(pngBytes);

      return watermarkedFile;
    } catch (e) {
      debugPrint('Error adding watermark: $e');
      return null;
    }
  }

  /// Builds a photo capture slot (used for photo 1 and photo 2)
  Widget _buildPhotoSlot({
    required File? image,
    required String label,
    required VoidCallback onCapture,
    required VoidCallback onRemove,
    required bool isCapturing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: isCapturing ? null : onCapture,
          child: Container(
            width: double.infinity,
            height: image != null ? 250 : 90,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryGreen, width: 1.5),
            ),
            child: image != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.file(
                          image,
                          width: double.infinity,
                          height: 250,
                          fit: BoxFit.contain,
                        ),
                      ),
                      // Retake button
                      Positioned(
                        top: 8,
                        right: 48,
                        child: GestureDetector(
                          onTap: onCapture,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  tr('retake'),
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Remove button
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: onRemove,
                          child: Container(
                            padding: const EdgeInsets.all(5),
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
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      isCapturing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.camera_alt,
                              size: 30,
                              color: AppColors.primaryGreen,
                            ),
                      const SizedBox(height: 6),
                      Text(
                        isCapturing
                            ? tr('opening_camera')
                            : tr('capture_live_photo'),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _capturePhoto({bool isSecond = false}) async {
    setState(() {
      if (isSecond) {
        _isCapturing2 = true;
      } else {
        _isCapturing1 = true;
      }
    });

    try {
      // Step 1: Get GPS location with address
      String locationString = 'Location not available';
      double? lat;
      double? lng;
      try {
        // Check & request location permission
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final Position position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          );

          lat = position.latitude;
          lng = position.longitude;

          // Reverse geocode using Google Geocoding API (precise)
          try {
            final geocodeResult = await _googleGeocodingService.reverseGeocode(
              latitude: position.latitude,
              longitude: position.longitude,
            );
            if (geocodeResult != null) {
              locationString = GoogleGeocodingService.buildCompactAddress(geocodeResult);
              if (locationString.isEmpty) {
                locationString = geocodeResult['formattedAddress'] ?? '';
              }
            }
          } catch (e) {
            debugPrint('Google Geocoding error: $e');
          }

          // Fallback: use Dart geocoding package if Google API failed
          if (locationString == 'Location not available' || locationString.isEmpty) {
            try {
              final placemarks = await geocoding.placemarkFromCoordinates(
                position.latitude,
                position.longitude,
              );
              if (placemarks.isNotEmpty) {
                final p = placemarks.first;
                final parts = <String>[
                  if (p.subLocality != null && p.subLocality!.isNotEmpty) p.subLocality!,
                  if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
                  if (p.subAdministrativeArea != null && p.subAdministrativeArea!.isNotEmpty) p.subAdministrativeArea!,
                  if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) p.administrativeArea!,
                  if (p.postalCode != null && p.postalCode!.isNotEmpty) p.postalCode!,
                ];
                if (parts.isNotEmpty) {
                  locationString = parts.join(', ');
                }
              }
            } catch (e) {
              debugPrint('Dart geocoding fallback error: $e');
            }
          }

          // Final fallback: show coordinates if we have them, otherwise generic message
          if (locationString == 'Location not available' || locationString.isEmpty) {
            if (lat != null && lng != null) {
              locationString = '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
            } else {
              locationString = 'Location captured';
            }
          }
        }
      } catch (e) {
        debugPrint('Location error: $e');
        locationString = 'Location not available';
      }

      // Step 2: Open camera directly (rear camera, no dialog)
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 90,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (photo != null) {
        // Step 3: Get current date and time
        final now = nowIST();
        final dateFormat = DateFormat('dd MMM yyyy, hh:mm:ss a');
        final String dateTimeString = dateFormat.format(now);

        // Step 4: Add watermark with time and GPS location
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(tr('adding_watermark')),
                ],
              ),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 5),
            ),
          );
        }

        final File originalFile = File(photo.path);
        final File? watermarkedFile = await _addWatermarkToImage(
          originalFile,
          dateTimeString,
          locationString,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }

        setState(() {
          if (isSecond) {
            _capturedImage2 = watermarkedFile ?? originalFile;
            _captureDateTime2 = dateTimeString;
            _captureLocation2 = locationString;
            _captureLatitude2 = lat;
            _captureLongitude2 = lng;
          } else {
            _capturedImage = watermarkedFile ?? originalFile;
            _captureDateTime = dateTimeString;
            _captureLocation = locationString;
            _captureLatitude = lat;
            _captureLongitude = lng;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('photo_captured_success')),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error capturing photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr('camera_error')}: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: tr('retry'),
              textColor: Colors.white,
              onPressed: () => _capturePhoto(),
            ),
          ),
        );
      }
    } finally {
      setState(() {
        _isCapturing1 = false;
        _isCapturing2 = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get listing type and source labels
    String listingTypeLabel = widget.listingType == 'seed' ? tr('seed') : tr('crop');
    String sourceLabel = _selectedSourceType == 'field'
        ? tr('from_field')
        : tr('from_cold_storage');
    Color sourceColor = _selectedSourceType == 'field'
        ? AppColors.primaryGreen
        : Colors.blue;
    IconData sourceIcon = _selectedSourceType == 'field'
        ? Icons.grass
        : Icons.warehouse;

    // Listing validity: 48 hours for field, 60 days for cold storage
    bool isFieldSource = _selectedSourceType == 'field';
    int expiryDays = isFieldSource ? 0 : 60; // 0 means hours-based
    int expiryHours = isFieldSource ? 48 : 0;
    String expiryLabel = isFieldSource
        ? tr('expiry_48_hours')
        : trArgs('expiry_days', {'days': expiryDays.toString()});

    return Scaffold(
      backgroundColor: AppColors.cardBg(context),
      appBar: CustomRoundedAppBar(
        title: tr('create_sell_request'),
        actions: const [],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Listing Type & Source Badge
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: sourceColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: sourceColor, width: 1),
              ),
              child: Row(
                children: [
                  Icon(sourceIcon, color: sourceColor, size: 24),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${tr('selling')}: $listingTypeLabel',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: sourceColor,
                        ),
                      ),
                      Text(
                        sourceLabel,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: sourceColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _selectedSourceType == 'field'
                          ? '📍 ${tr('live_location')}'
                          : '🏭 ${tr('storage')}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Expiry validity notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade300, width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.timer, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(
                            'listing_valid_for',
                          ).replaceAll('{expiry}', expiryLabel),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr(
                            'listing_auto_remove',
                          ).replaceAll('{expiry}', expiryLabel),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            label(tr('potato_variety')),
            dropdown(
              hint: tr('select_variety'),
              value: selectedVariety,
              items: _varietyList,
              onChanged: (v) => setState(() => selectedVariety = v),
            ),

            if (selectedVariety == "Others") ...[
              const SizedBox(height: 12),
              label(tr('enter_variety_name')),
              TextField(
                controller: _customVarietyController,
                decoration: InputDecoration(
                  hintText: tr('type_variety_hint'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.primaryGreen,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      label(tr('unit_required')),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg(context),
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedUnit,
                            isExpanded: true,
                            dropdownColor: AppColors.cardBg(context),
                            icon: Icon(
                              Icons.keyboard_arrow_down,
                              color: AppColors.primaryGreen,
                            ),
                            items: _unitOptions.map((unit) {
                              return DropdownMenuItem(
                                value: unit,
                                child: Text(
                                  tr(unit.toLowerCase()),
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => selectedUnit = value);
                                _calculatePrice();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      label(tr('quantity_min_49')),
                      TextField(
                        controller: _quantityController,
                        focusNode: _quantityFocusNode,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (value) {
                          _calculatePrice();
                        },
                        decoration: InputDecoration(
                          hintText: '49',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.primaryGreen,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Packet weight slider - only visible when unit is Packet
            if (selectedUnit == 'Packet') ...[
              const SizedBox(height: 16),
              label(tr('packet_weight')),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '50 kg',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: AppColors.primaryGreen,
                        inactiveTrackColor: AppColors.primaryGreen.withOpacity(
                          0.2,
                        ),
                        thumbColor: AppColors.primaryGreen,
                        overlayColor: AppColors.primaryGreen.withOpacity(0.1),
                        valueIndicatorColor: AppColors.primaryGreen,
                        valueIndicatorTextStyle: const TextStyle(
                          color: Colors.white,
                        ),
                      ),
                      child: Slider(
                        value: _packetWeight,
                        min: 50,
                        max: 55,
                        divisions: 5,
                        label: '${_packetWeight.round()} kg',
                        onChanged: (value) {
                          setState(() => _packetWeight = value);
                        },
                      ),
                    ),
                  ),
                  Text(
                    '55 kg',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              Center(
                child: Text(
                  '${_packetWeight.round()} kg',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            Text(
              tr('categorize_by_size'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                "Large",
                "Medium",
                "Small",
              ].map((size) => sizeChip(size)).toList(),
            ),

            // Quality selector - only for Vyapari
            if (widget.showQuality) ...[
              const SizedBox(height: 16),
              Text(
                tr('quality'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  "Low",
                  "Average",
                  "Good",
                ].map((q) => _qualityChip(q)).toList(),
              ),
            ],

            const SizedBox(height: 16),

            label('${tr('price_per')} ${tr(selectedUnit.toLowerCase())}*'),
            TextField(
              controller: _pricePerUnitController,
              keyboardType: TextInputType.number,
              maxLength: 5,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
              decoration: InputDecoration(
                counterText: '',
                hintText: tr('enter_price_max_5'),
                prefixText: "₹ ",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.primaryGreen,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),

            const SizedBox(height: 16),

            label(tr('total_price_auto')),
            TextField(
              controller: _priceController,
              readOnly: true,
              decoration: InputDecoration(
                hintText: tr('enter_quantity_first'),
                prefixText: "₹ ",
                filled: true,
                fillColor: AppColors.inputFill(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),

            const SizedBox(height: 20),

            label(tr('description_required_label')),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: tr('description_hint'),
                prefixIcon: Icon(Icons.description, color: AppColors.primaryGreen),
                filled: true,
                fillColor: AppColors.inputFill(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              tr('capture_potato_photo'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            // Photo 1 (Required)
            _buildPhotoSlot(
              image: _capturedImage,
              label: '${tr('photo')} 1 *',
              isCapturing: _isCapturing1,
              onCapture: () => _capturePhoto(),
              onRemove: () => setState(() {
                _capturedImage = null;
                _captureLocation = null;
                _captureLatitude = null;
                _captureLongitude = null;
                _captureDateTime = null;
              }),
            ),

            const SizedBox(height: 12),

            // Photo 2 (Optional)
            _buildPhotoSlot(
              image: _capturedImage2,
              label: '${tr('photo')} 2 (${tr('optional')})',
              isCapturing: _isCapturing2,
              onCapture: () => _capturePhoto(isSecond: true),
              onRemove: () => setState(() {
                _capturedImage2 = null;
                _captureLocation2 = null;
                _captureLatitude2 = null;
                _captureLongitude2 = null;
                _captureDateTime2 = null;
              }),
            ),

            // Location info for Photo 1
            if (_captureLocation != null && _capturedImage != null) ...[
              const SizedBox(height: 12),
              _buildCapturedLocationCard(
                label: '${tr('photo')} 1 - ${tr('captured_location')}',
                address: _captureLocation!,
                dateTime: _captureDateTime,
                latitude: _captureLatitude,
                longitude: _captureLongitude,
              ),
            ],

            // Location info for Photo 2
            if (_captureLocation2 != null && _capturedImage2 != null) ...[
              const SizedBox(height: 12),
              _buildCapturedLocationCard(
                label: '${tr('photo')} 2 - ${tr('captured_location')}',
                address: _captureLocation2!,
                dateTime: _captureDateTime2,
                latitude: _captureLatitude2,
                longitude: _captureLongitude2,
              ),
            ],

            const SizedBox(height: 24),

            // Cold Storage Details (only show if source is cold_storage)
            if (_selectedSourceType == 'cold_storage') ...[
              Text(
                tr('select_cold_storage_required'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              // Dropdown for selecting cold storage
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.cardBg(context),
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedColdStorage != null
                        ? _selectedColdStorage!['_id']
                        : null,
                    isExpanded: true,
                    hint: Text(
                      _allColdStorages.isEmpty
                          ? tr('loading')
                          : tr('select_cold_storage_hint'),
                      style: GoogleFonts.inter(color: Colors.grey[600]),
                    ),
                    dropdownColor: AppColors.cardBg(context),
                    icon: Icon(Icons.keyboard_arrow_down, color: Colors.blue),
                    items: [
                      // All cold storages from API
                      ..._allColdStorages.map((storage) {
                        return DropdownMenuItem<String>(
                          value: storage['_id'],
                          child: Text(
                            '${storage['name'] ?? 'Unknown'} - ${storage['location'] ?? storage['city'] ?? ''}',
                            style: GoogleFonts.inter(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                      // Other option
                      DropdownMenuItem<String>(
                        value: 'other',
                        child: Text(
                          tr('other_enter_name'),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == 'other') {
                        setState(() {
                          _selectedColdStorage = {
                            '_id': 'other',
                            'name': '',
                            'location': '',
                          };
                          _coldStorageNameController.clear();
                        });
                      } else if (value != null) {
                        final selected = _allColdStorages.firstWhere(
                          (s) => s['_id'] == value,
                        );
                        _selectColdStorage(selected);
                      }
                    },
                  ),
                ),
              ),

              // Show text field for custom cold storage name when "Other" is selected
              if (_selectedColdStorage != null &&
                  _selectedColdStorage!['_id'] == 'other') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _coldStorageNameController,
                  decoration: InputDecoration(
                    labelText: tr('cold_storage_name'),
                    hintText: tr('enter_cold_storage_name'),
                    prefixIcon: Icon(Icons.warehouse, color: Colors.blue),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                ),
              ],

              // Show selected cold storage details (only for existing cold storages)
              if (_selectedColdStorage != null &&
                  _selectedColdStorage!['_id'] != 'other') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedColdStorage!['name'] ?? '',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              _selectedColdStorage!['location'] ??
                                  _selectedColdStorage!['city'] ??
                                  '',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],

            Row(
              children: [
                Text(
                  tr('kisan_information'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: AppColors.primaryGreen,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tr('auto_fetched'),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _kisanNameController,
              decoration: InputDecoration(
                labelText: '${tr('kisan_name')} *',
                prefixIcon: Icon(Icons.person, color: AppColors.primaryGreen),
                filled: true,
                fillColor: AppColors.inputFill(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                counterText: '',
                labelText: '${tr('mobile_number')} *',
                hintText: tr('enter_mobile_number'),
                prefixIcon: Icon(Icons.phone, color: AppColors.primaryGreen),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.primaryGreen,
                    width: 2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSubmitting ? null : _submitListing,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        tr('submit_listing'),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Submit the listing to the server
  Future<void> _submitListing() async {
    // Validate required fields
    final variety = selectedVariety == 'Others'
        ? _customVarietyController.text
        : selectedVariety;

    if (variety == null || variety.isEmpty) {
      ToastHelper.showError(context, tr('please_select_variety'));
      return;
    }

    if (_quantityController.text.isEmpty) {
      ToastHelper.showError(context, tr('please_enter_quantity'));
      return;
    }

    final quantity = int.tryParse(_quantityController.text) ?? 0;
    if (quantity < 49) {
      ToastHelper.showError(context, tr('quantity_min_49_error'));
      return;
    }

    if (_pricePerUnitController.text.isEmpty) {
      ToastHelper.showError(context, tr('please_enter_price'));
      return;
    }

    if (_kisanNameController.text.trim().isEmpty) {
      ToastHelper.showError(context, tr('please_enter_kisan_name'));
      return;
    }

    final mobile = _mobileController.text.trim();
    if (mobile.isEmpty) {
      ToastHelper.showError(context, tr('mobile_number_required'));
      return;
    }
    if (mobile.length != 10 || !RegExp(r'^\d{10}$').hasMatch(mobile)) {
      ToastHelper.showError(context, tr('mobile_10_digits'));
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      ToastHelper.showError(context, tr('please_enter_description'));
      return;
    }

    if (_selectedSourceType == 'cold_storage') {
      if (_selectedColdStorage == null) {
        ToastHelper.showError(context, tr('please_pick_cold_storage'));
        return;
      }
      if (_selectedColdStorage!['_id'] == 'other' &&
          _coldStorageNameController.text.trim().isEmpty) {
        ToastHelper.showError(context, tr('cold_storage_name_required'));
        return;
      }
    }

    if (_capturedImage == null) {
      ToastHelper.showError(context, tr('please_capture_potato_photo'));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Get user location from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      Map<String, String>? location;

      if (userJson != null) {
        try {
          final userData = json.decode(userJson);
          final address = userData['address'];
          if (address != null) {
            location = {
              'state': address['state'] ?? '',
              'district': address['district'] ?? '',
              'city': address['city'] ?? '',
            };
          }
        } catch (e) {
          debugPrint('Error parsing user address: $e');
        }
      }

      // Convert captured images to base64
      final List<String> imageBase64List = [];
      if (_capturedImage != null) {
        final bytes1 = await _capturedImage!.readAsBytes();
        final ext1 = _capturedImage!.path.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
        imageBase64List.add('data:image/$ext1;base64,${base64Encode(bytes1)}');
      }
      if (_capturedImage2 != null) {
        final bytes2 = await _capturedImage2!.readAsBytes();
        final ext2 = _capturedImage2!.path.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
        imageBase64List.add('data:image/$ext2;base64,${base64Encode(bytes2)}');
      }

      final result = await _listingService.createListing(
        type: 'sell',
        potatoVariety: variety,
        quantity: int.tryParse(_quantityController.text) ?? 0,
        pricePerQuintal: int.tryParse(_pricePerUnitController.text) ?? 0,
        description: _descriptionController.text.trim(),
        contactPhone: mobile,
        size: selectedSize,
        quality: widget.showQuality ? selectedQuality : null,
        location: location,
        sourceType: _selectedSourceType,
        listingType: widget.listingType,
        unit: selectedUnit,
        packetWeight: selectedUnit == 'Packet' ? _packetWeight.round() : null,
        expiryHours: _selectedSourceType == 'field' ? 48 : null,
        images: imageBase64List,
        coldStorageId: _selectedSourceType == 'cold_storage' &&
                _selectedColdStorage != null &&
                _selectedColdStorage!['_id'] != 'other'
            ? _selectedColdStorage!['_id']
            : null,
        coldStorageName: _selectedSourceType == 'cold_storage' &&
                _selectedColdStorage != null
            ? (_selectedColdStorage!['_id'] == 'other'
                ? _coldStorageNameController.text.trim()
                : _selectedColdStorage!['name'])
            : null,
        captureLocation: (_captureLocation != null || _captureLocation2 != null)
            ? {
                'address': _captureLocation ?? _captureLocation2,
                if (_captureLatitude != null) 'latitude': _captureLatitude,
                if (_captureLongitude != null) 'longitude': _captureLongitude,
                if (_captureLatitude == null && _captureLatitude2 != null) 'latitude': _captureLatitude2,
                if (_captureLongitude == null && _captureLongitude2 != null) 'longitude': _captureLongitude2,
              }
            : null,
      );

      setState(() => _isSubmitting = false);

      if (result['success']) {
        if (mounted) {
          _showSuccessDialog();
        }
      } else {
        if (mounted) {
          ToastHelper.showError(
            context,
            result['message'] ?? 'Failed to create listing',
          );
        }
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ToastHelper.showError(context, 'Error: $e');
      }
    }
  }

  /// Show success dialog after listing is created
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                size: 50,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              tr('listing_created'),
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              tr('listing_created_message'),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pushReplacementNamed(
                    context,
                    '/seller_listing',
                  ); // Go to My Listings
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  tr('view_my_listings'),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a captured location card showing readable address (no raw lat/lng)
  Widget _buildCapturedLocationCard({
    required String label,
    required String address,
    String? dateTime,
    double? latitude,
    double? longitude,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on, size: 18, color: AppColors.primaryGreen),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Show readable address only
              Text(
                address,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (dateTime != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      dateTime,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        // Static Google Map below location card
        if (latitude != null && longitude != null) ...[
          const SizedBox(height: 10),
          LocationMapWidget(
            latitude: latitude,
            longitude: longitude,
            address: address,
            height: 150,
            compact: true,
            zoom: 14,
          ),
        ],
      ],
    );
  }

  Widget sizeChip(String size) {
    final bool isSelected = selectedSize == size;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(tr(size.toLowerCase())),
        selected: isSelected,
        selectedColor: AppColors.primaryGreen,
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
        onSelected: (_) {
          setState(() {
            selectedSize = size;
            _calculatePrice();
          });
        },
      ),
    );
  }

  Widget _qualityChip(String quality) {
    final bool isSelected = selectedQuality == quality;
    String label;
    switch (quality) {
      case 'Low':
        label = tr('quality_low');
        break;
      case 'Average':
        label = tr('quality_avg');
        break;
      case 'Good':
        label = tr('quality_good');
        break;
      default:
        label = quality;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primaryGreen,
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
        onSelected: (_) {
          setState(() => selectedQuality = quality);
        },
      ),
    );
  }

}
