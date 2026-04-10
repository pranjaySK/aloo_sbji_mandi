import 'dart:convert';

import 'package:aloo_sbji_mandi/core/constants/state_city_data.dart';
import 'package:aloo_sbji_mandi/core/service/google_geocoding_service.dart';
import 'package:aloo_sbji_mandi/core/service/trader_request_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/toast_helper.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:aloo_sbji_mandi/widgets/location_map_widget.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreateBuyRequestScreen extends StatefulWidget {
  final Map<String, dynamic>? existingRequest;

  const CreateBuyRequestScreen({super.key, this.existingRequest});

  bool get isEditMode => existingRequest != null;

  @override
  State<CreateBuyRequestScreen> createState() => _CreateBuyRequestScreenState();
}

class _CreateBuyRequestScreenState extends State<CreateBuyRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final TraderRequestService _requestService = TraderRequestService();
  final GoogleGeocodingService _googleGeocodingService = GoogleGeocodingService();

  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customVarietyController = TextEditingController();
  final _customVillageController = TextEditingController();

  String? _selectedVariety;
  String _selectedPotatoType = 'Any';
  String _selectedSize = 'Any';
  String _selectedQuality = 'Any';
  String? _selectedState;
  String? _selectedDistrict;
  String? _selectedVillage;
  List<String> _availableDistricts = [];
  List<String> _availableVillages = [];
  bool _isLoading = false;

  // GPS location capture state
  double? _capturedLatitude;
  double? _capturedLongitude;
  String? _capturedAddress;
  bool _isCapturingLocation = false;

  final List<String> _potatoTypes = ['Any', 'Table', 'Seed', 'Processing'];
  final List<String> _sizes = ['Any', 'Small', 'Medium', 'Large'];
  final List<String> _qualities = ['Any', 'Low', 'Average', 'Good'];

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
    if (widget.isEditMode) {
      _prefillFromExistingRequest();
    } else {
      _loadProfileLocation();
    }
  }

  void _prefillFromExistingRequest() {
    final req = widget.existingRequest!;

    // Variety
    final variety = req['potatoVariety'] ?? '';
    if (_varietyList.contains(variety)) {
      _selectedVariety = variety;
    } else if (variety.isNotEmpty) {
      _selectedVariety = 'Others';
      _customVarietyController.text = variety;
    }

    // Potato type & size
    _selectedPotatoType = req['potatoType'] ?? 'Any';
    _selectedSize = req['size'] ?? 'Any';
    _selectedQuality = req['qualityGrade'] ?? 'Any';

    // Quantity & price
    _quantityController.text = (req['quantity'] ?? '').toString();
    _priceController.text = (req['maxPricePerQuintal'] ?? '').toString();

    // Description
    _descriptionController.text = req['description'] ?? '';

    // Delivery location
    final location = req['deliveryLocation'];
    if (location != null && location is Map) {
      final state = location['state'] ?? '';
      final district = location['district'] ?? '';
      final village = location['village'] ?? '';

      if (state.isNotEmpty &&
          StateCityData.states.contains(state)) {
        _selectedState = state;
        _availableDistricts =
            StateCityData.getCitiesForState(state);
        if (district.isNotEmpty && _availableDistricts.contains(district)) {
          _selectedDistrict = district;
          _availableVillages =
              StateCityData.getVillagesForDistrict(district);
        }
      }
      if (village.isNotEmpty) {
        if (_availableVillages.contains(village)) {
          _selectedVillage = village;
        } else {
          _selectedVillage = 'Others';
          _customVillageController.text = village;
        }
      }
    }

    // GPS captured location
    final captureLoc = req['captureLocation'];
    if (captureLoc != null && captureLoc is Map) {
      _capturedLatitude = (captureLoc['latitude'] as num?)?.toDouble();
      _capturedLongitude = (captureLoc['longitude'] as num?)?.toDouble();
      _capturedAddress = captureLoc['address']?.toString();
    }
  }

  Future<void> _loadProfileLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    if (userJson != null) {
      try {
        final userData = json.decode(userJson);
        final address = userData['address'];
        if (address != null) {
          final profileState = address['state'] ?? '';
          final profileDistrict = address['district'] ?? '';
          final profileVillage = address['village'] ?? address['city'] ?? '';

          setState(() {
            if (profileState.isNotEmpty &&
                StateCityData.states.contains(profileState)) {
              _selectedState = profileState;
              _availableDistricts =
                  StateCityData.getCitiesForState(profileState);
              if (profileDistrict.isNotEmpty &&
                  _availableDistricts.contains(profileDistrict)) {
                _selectedDistrict = profileDistrict;
                _availableVillages =
                    StateCityData.getVillagesForDistrict(profileDistrict);
              }
            }
            if (profileVillage.isNotEmpty) {
              if (_availableVillages.contains(profileVillage)) {
                _selectedVillage = profileVillage;
              } else {
                _selectedVillage = 'Others';
                _customVillageController.text = profileVillage;
              }
            }
          });
        }
      } catch (e) {
        debugPrint('Error loading profile: $e');
      }
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _customVarietyController.dispose();
    _customVillageController.dispose();
    super.dispose();
  }

  // ── GPS Location Capture ──────────────────────────────────────
  Future<void> _captureGPSLocation() async {
    setState(() => _isCapturingLocation = true);

    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ToastHelper.showError(context, 'Location permission denied');
          }
          setState(() => _isCapturingLocation = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ToastHelper.showError(
            context,
            'Location permission permanently denied. Enable in settings.',
          );
        }
        setState(() => _isCapturingLocation = false);
        return;
      }

      // Check if location service is enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ToastHelper.showError(context, 'Please enable location services');
        }
        setState(() => _isCapturingLocation = false);
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Reverse geocode using Google API
      String address = '';
      try {
        final geoResult = await _googleGeocodingService.reverseGeocode(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        if (geoResult != null) {
          address = GoogleGeocodingService.buildCompactAddress(geoResult);
        }
      } catch (e) {
        address = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        debugPrint('Reverse geocode failed: $e');
      }

      setState(() {
        _capturedLatitude = position.latitude;
        _capturedLongitude = position.longitude;
        _capturedAddress = address;
        _isCapturingLocation = false;
      });

      if (mounted) {
        ToastHelper.showCreated(context, 'GPS location captured!');
      }
    } catch (e) {
      debugPrint('GPS capture error: $e');
      if (mounted) {
        ToastHelper.showError(context, 'Failed to get location: $e');
      }
      setState(() => _isCapturingLocation = false);
    }
  }

  Future<void> _createRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final variety = _selectedVariety == 'Others'
        ? _customVarietyController.text.trim()
        : (_selectedVariety ?? '');

    if (variety.isEmpty) {
      ToastHelper.showError(context, tr('select_variety'));
      return;
    }

    setState(() => _isLoading = true);

    final deliveryLocation = {
      'district': _selectedDistrict ?? '',
      'state': _selectedState ?? '',
      'village': _selectedVillage == 'Others'
          ? _customVillageController.text.trim()
          : (_selectedVillage ?? ''),
    };

    // Build captureLocation if GPS was captured
    final Map<String, dynamic>? captureLocationData =
        (_capturedLatitude != null && _capturedLongitude != null)
            ? {
                'address': _capturedAddress ?? '',
                'latitude': _capturedLatitude,
                'longitude': _capturedLongitude,
              }
            : null;

    final Map<String, dynamic> result;

    if (widget.isEditMode) {
      result = await _requestService.updateRequest(
        requestId: widget.existingRequest!['_id'].toString(),
        potatoVariety: variety,
        quantity: int.parse(_quantityController.text),
        maxPricePerQuintal: int.parse(_priceController.text),
        potatoType: _selectedPotatoType,
        size: _selectedSize,
        qualityGrade: _selectedQuality,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        deliveryLocation: deliveryLocation,
        captureLocation: captureLocationData,
      );
    } else {
      result = await _requestService.createRequest(
        potatoVariety: variety,
        quantity: int.parse(_quantityController.text),
        maxPricePerQuintal: int.parse(_priceController.text),
        potatoType: _selectedPotatoType,
        size: _selectedSize,
        qualityGrade: _selectedQuality,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        deliveryLocation: deliveryLocation,
        captureLocation: captureLocationData,
      );
    }

    setState(() => _isLoading = false);

    if (result['success']) {
      ToastHelper.showCreated(
        context,
        widget.isEditMode
            ? tr('buy_request_updated')
            : tr('buy_request_created'),
      );
      Navigator.pop(context, true);
    } else {
      ToastHelper.showError(
        context,
        result['message'] ?? 'Failed',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardBg(context),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.isEditMode ? tr('edit_buy_request') : tr('post_buy_request'),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tr('buy_request_info'),
                        style: TextStyle(color: Colors.blue[700], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Potato Variety - Dropdown
              _buildLabel('${tr('potato_variety')} *'),
              DropdownButtonFormField<String>(
                value: _selectedVariety,
                decoration: _inputDecoration(tr('select_variety')),
                isExpanded: true,
                items: _varietyList.map((v) {
                  return DropdownMenuItem(value: v, child: Text(v));
                }).toList(),
                onChanged: (v) => setState(() => _selectedVariety = v),
                validator: (v) => v == null ? tr('select_variety') : null,
              ),

              // Show custom variety field when "Others" is selected
              if (_selectedVariety == 'Others') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customVarietyController,
                  decoration: _inputDecoration('e.g., Badshah, Kufri Jyoti'),
                  validator: (v) =>
                      _selectedVariety == 'Others' &&
                          (v == null || v.trim().isEmpty)
                      ? 'Required'
                      : null,
                ),
              ],

              const SizedBox(height: 16),

              // Potato Type & Quality in a row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel(tr('potato_type')),
                        DropdownButtonFormField<String>(
                          value: _selectedPotatoType,
                          decoration: _inputDecoration(null),
                          items: _potatoTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (v) =>
                              setState(() => _selectedPotatoType = v!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel(tr('categorize_by_size')),
                        DropdownButtonFormField<String>(
                          value: _selectedSize,
                          decoration: _inputDecoration(null),
                          items: _sizes.map((size) {
                            return DropdownMenuItem(
                              value: size,
                              child: Text(size),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _selectedSize = v!),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Quality Grade
              _buildLabel(tr('quality')),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: _qualities.map((q) {
                  final bool isSelected = _selectedQuality == q;
                  String label;
                  switch (q) {
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
                      label = 'Any';
                  }
                  return ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    selectedColor: AppColors.primaryGreen,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                    onSelected: (_) {
                      setState(() => _selectedQuality = q);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Quantity & Price in a row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel(tr('quantity_packets')),
                        TextFormField(
                          controller: _quantityController,
                          decoration: _inputDecoration('e.g., 50'),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v!.isEmpty) return 'Required';
                            if (int.tryParse(v) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel(tr('max_price_per_packet')),
                        TextFormField(
                          controller: _priceController,
                          decoration: _inputDecoration('e.g., 2500'),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v!.isEmpty) return 'Required';
                            if (int.tryParse(v) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Delivery Location
              _buildLabel(tr('delivery_location')),

              // State Dropdown
              DropdownButtonFormField<String>(
                value: _selectedState,
                decoration: _inputDecoration(tr('state')),
                isExpanded: true,
                items: StateCityData.states.map((state) {
                  return DropdownMenuItem(value: state, child: Text(state));
                }).toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedState = v;
                    _selectedDistrict = null;
                    _selectedVillage = null;
                    _availableDistricts =
                        StateCityData.getCitiesForState(v ?? '');
                    _availableVillages = [];
                  });
                },
              ),

              const SizedBox(height: 12),

              // District Dropdown
              DropdownButtonFormField<String>(
                key: ValueKey('district_${_selectedState}'),
                value: _selectedDistrict,
                decoration: _inputDecoration(tr('district')),
                isExpanded: true,
                items: _availableDistricts.map((city) {
                  return DropdownMenuItem(value: city, child: Text(city));
                }).toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedDistrict = v;
                    _selectedVillage = null;
                    _availableVillages =
                        StateCityData.getVillagesForDistrict(v ?? '');
                  });
                },
              ),

              const SizedBox(height: 12),

              // Village/City Dropdown
              DropdownButtonFormField<String>(
                key: ValueKey('village_${_selectedDistrict}'),
                value: _selectedVillage,
                decoration: _inputDecoration(tr('village')),
                isExpanded: true,
                items: [
                  DropdownMenuItem(value: 'Others', child: Text(tr('others'))),
                  ..._availableVillages.map((village) {
                    return DropdownMenuItem(value: village, child: Text(village));
                  }),
                ],
                onChanged: (v) => setState(() => _selectedVillage = v),
              ),

              if (_selectedVillage == 'Others') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customVillageController,
                  decoration: _inputDecoration(tr('village')),
                ),
              ],

              const SizedBox(height: 20),

              // ── GPS Location Capture Section ──────────────────
              _buildLabel('📍 Capture GPS Location'),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tap below to capture your exact GPS coordinates for precise delivery location.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isCapturingLocation ? null : _captureGPSLocation,
                        icon: _isCapturingLocation
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                _capturedLatitude != null
                                    ? Icons.refresh
                                    : Icons.gps_fixed,
                              ),
                        label: Text(
                          _isCapturingLocation
                              ? 'Capturing...'
                              : _capturedLatitude != null
                                  ? 'Re-capture Location'
                                  : 'Capture Current Location',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

                    // Show captured location info + map
                    if (_capturedLatitude != null && _capturedLongitude != null) ...[
                      const SizedBox(height: 12),
                      if (_capturedAddress != null && _capturedAddress!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(Icons.location_on, size: 16, color: Colors.green.shade700),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _capturedAddress!,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LocationMapWidget(
                          latitude: _capturedLatitude!,
                          longitude: _capturedLongitude!,
                          address: _capturedAddress ?? '',
                          compact: true,
                          height: 150,
                          zoom: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Description - only in create mode
              if (!widget.isEditMode) ...[
                _buildLabel(tr('additional_details')),
                TextFormField(
                  controller: _descriptionController,
                  decoration: _inputDecoration(tr('any_specific_requirements')),
                  maxLines: 3,
                ),
              ],

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          widget.isEditMode
                              ? tr('update_buy_request')
                              : tr('post_buy_request'),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Note
              Text(
                tr('buy_request_note'),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w500,
          fontSize: 14,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.inputFill(context),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[400]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[400]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
