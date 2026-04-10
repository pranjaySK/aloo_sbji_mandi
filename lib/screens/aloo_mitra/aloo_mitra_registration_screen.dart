import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aloo_sbji_mandi/core/constants/state_city_data.dart';
import 'package:aloo_sbji_mandi/core/service/auth_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AlooMitraRegistrationScreen extends StatefulWidget {
  const AlooMitraRegistrationScreen({super.key});

  @override
  State<AlooMitraRegistrationScreen> createState() =>
      _AlooMitraRegistrationScreenState();
}

class _AlooMitraRegistrationScreenState
    extends State<AlooMitraRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  // Form controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _pricingController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  // Fertilizers specific controllers
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _businessAddressController =
      TextEditingController();

  // Location for fertilizers
  double? _businessLatitude;
  double? _businessLongitude;
  final bool _isGettingLocation = false;

  // Dropdown values
  String? _selectedServiceType;
  String? _selectedState;
  String? _selectedDistrict;
  String? _selectedVillage;
  bool _isOtherState = false;
  bool _isOtherDistrict = false;
  bool _isOtherVillage = false;

  // Manual entry controllers for Other
  final TextEditingController _otherStateController = TextEditingController();
  final TextEditingController _otherDistrictController =
      TextEditingController();

  // Fertilizers specific controllers
  final TextEditingController _pincodeController = TextEditingController();

  // Majdoor specific controllers and variables
  final TextEditingController _majdoorMobileController =
      TextEditingController();
  final TextEditingController _majdoorNameController = TextEditingController();
  final TextEditingController _majdoorWagesController = TextEditingController(
    text: '500',
  );
  String? _selectedKaamType;
  String? _selectedKaamJagah;
  String? _selectedAvailability;
  File? _aadhaarImage;
  final ImagePicker _imagePicker = ImagePicker();

  // Business photos (for all service types except Majdoor)
  final List<XFile> _businessPhotos = [];

  // Majdoor dropdown options
  List<Map<String, String>> get _kaamTypes => [
    {'label': tr('kaam_aloo_chhantai'), 'value': 'aloo-chhantai'},
    {'label': tr('kaam_bori_bharai'), 'value': 'bori-bharai'},
    {'label': tr('kaam_loading'), 'value': 'loading'},
    {'label': tr('kaam_cold_storage'), 'value': 'cold-storage'},
  ];

  List<Map<String, String>> get _kaamJagahOptions => [
    {'label': tr('jagah_gaon'), 'value': 'gaon'},
    {'label': tr('jagah_mandi'), 'value': 'mandi'},
    {'label': tr('jagah_cold_storage'), 'value': 'cold-storage'},
  ];

  List<Map<String, String>> get _availabilityOptions => [
    {'label': tr('availability_daily'), 'value': 'daily'},
    {'label': tr('availability_seasonal'), 'value': 'seasonal'},
  ];

  // Gunny Bag specific controllers
  final TextEditingController _gunnyBagBusinessNameController =
      TextEditingController();
  final TextEditingController _gunnyBagPincodeController =
      TextEditingController();
  final TextEditingController _gunnyBagOwnerNameController =
      TextEditingController();
  double? _gunnyBagLatitude;
  double? _gunnyBagLongitude;
  final bool _isGettingGunnyBagLocation = false;

  // Machinery specific variables
  final TextEditingController _machineryBusinessNameController =
      TextEditingController();
  String? _selectedMachineryServiceType; // new-sale, rent, both
  String? _selectedMachineType;
  String? _selectedRentType; // per-hour, per-day
  RangeValues _salePriceRange = const RangeValues(50000, 500000);
  RangeValues _rentPriceRange = const RangeValues(500, 2500);

  // Machinery dropdown options
  List<Map<String, String>> get _machineTypes => [
    {'label': tr('machine_other'), 'value': 'other'},
    {'label': tr('machine_tractor'), 'value': 'tractor'},
    {'label': tr('machine_rotavator'), 'value': 'rotavator'},
    {'label': tr('machine_planter'), 'value': 'planter'},
    {'label': tr('machine_sprayer'), 'value': 'sprayer'},
    {'label': tr('machine_harvester'), 'value': 'harvester'},
  ];

  List<Map<String, String>> get _machineryServiceTypes => [
    {'label': tr('service_new_sale'), 'value': 'new-sale'},
    {'label': tr('service_rent'), 'value': 'rent'},
    {'label': tr('service_both'), 'value': 'both'},
  ];

  List<Map<String, String>> get _rentTypes => [
    {'label': tr('rent_per_hour'), 'value': 'per-hour'},
    {'label': tr('rent_per_day'), 'value': 'per-day'},
  ];

  bool _isLoading = false;

  // Service types with translations
  List<Map<String, String>> get _serviceTypes => [
    {'label': tr('service_potato_seeds'), 'value': 'potato-seeds'},
    {'label': tr('service_fertilizers_medicines'), 'value': 'fertilizers'},
    {'label': tr('service_machinery_rent'), 'value': 'machinery-rent'},
    {'label': tr('service_transportation'), 'value': 'transportation'},
    {'label': tr('service_gunny_bag'), 'value': 'gunny-bag'},
    {'label': tr('service_majdoor'), 'value': 'majdoor'},
  ];

  List<String> get _states {
    final states = StateCityData.states;
    return [tr('other_write'), ...states];
  }

  List<String> get _districts {
    // If other state is selected, only show "Other" option for district
    if (_isOtherState) return [tr('other_write')];
    if (_selectedState == null) return [];
    final districts = StateCityData.getCitiesForState(_selectedState ?? '');
    return [tr('other_write'), ...districts];
  }

  List<String> get _villages {
    // If other district is selected, only show "Other" option for village
    if (_isOtherDistrict) return [tr('other_write')];
    if (_selectedDistrict == null) return [];
    final villages = StateCityData.getVillagesForDistrict(_selectedDistrict ?? '');
    return [tr('other_write'), ...villages];
  }

  @override
  void initState() {
    super.initState();
    _prefillFromUserData();
  }

  /// Pre-fill form fields from existing user account data
  Future<void> _prefillFromUserData() async {
    final user = await _authService.getCurrentUser();
    if (user == null) return;

    final firstName = user['firstName'] ?? '';
    final lastName = user['lastName'] ?? '';
    // Use only firstName if lastName is a default placeholder like 'Kisan'
    final fullName = (lastName.isNotEmpty && lastName != 'Kisan')
        ? '$firstName $lastName'.trim()
        : firstName.trim();
    final phone = user['phone'] ?? '';
    final address = user['address'] ?? {};
    final userState = (address['state'] ?? '').toString();
    final userDistrict = (address['district'] ?? '').toString();
    final userVillage = (address['village'] ?? '').toString();

    setState(() {
      // Pre-fill name fields
      if (fullName.isNotEmpty) {
        _fullNameController.text = fullName;
        _majdoorNameController.text = fullName;
        _gunnyBagOwnerNameController.text = fullName;
      }

      // Pre-fill mobile for majdoor
      if (phone.isNotEmpty) {
        _majdoorMobileController.text = phone;
      }

      // Pre-fill state
      if (userState.isNotEmpty) {
        final availableStates = StateCityData.states;
        if (availableStates.contains(userState)) {
          _selectedState = userState;
          _isOtherState = false;
        } else {
          _isOtherState = true;
          _otherStateController.text = userState;
        }
      }

      // Pre-fill district
      if (userDistrict.isNotEmpty && _selectedState != null) {
        final availableDistricts =
            StateCityData.getCitiesForState(_selectedState ?? '');
        if (availableDistricts.contains(userDistrict)) {
          _selectedDistrict = userDistrict;
          _isOtherDistrict = false;
        } else {
          _isOtherDistrict = true;
          _otherDistrictController.text = userDistrict;
        }
      } else if (userDistrict.isNotEmpty && _isOtherState) {
        _isOtherDistrict = true;
        _otherDistrictController.text = userDistrict;
      }

      // Pre-fill village
      if (userVillage.isNotEmpty) {
        if (_selectedDistrict != null && !_isOtherDistrict) {
          final availableVillages =
              StateCityData.getVillagesForDistrict(_selectedDistrict ?? '');
          if (availableVillages.contains(userVillage)) {
            _selectedVillage = userVillage;
            _isOtherVillage = false;
          } else {
            _isOtherVillage = true;
            _cityController.text = userVillage;
          }
        } else {
          _isOtherVillage = true;
          _cityController.text = userVillage;
        }
      }
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _pricingController.dispose();
    _cityController.dispose();
    _businessNameController.dispose();
    _businessAddressController.dispose();
    _pincodeController.dispose();
    _otherStateController.dispose();
    _otherDistrictController.dispose();
    _majdoorMobileController.dispose();
    _majdoorNameController.dispose();
    _majdoorWagesController.dispose();
    _gunnyBagBusinessNameController.dispose();
    _gunnyBagPincodeController.dispose();
    _gunnyBagOwnerNameController.dispose();
    _machineryBusinessNameController.dispose();
    super.dispose();
  }

  // Get location for Gunny Bag business (GPS disabled)
  Future<void> _getGunnyBagLocation() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('location_not_available')),
        backgroundColor: Colors.orange,
      ),
    );
  }

  // Open Google Maps for Gunny Bag location
  Future<void> _openGunnyBagInGoogleMaps() async {
    if (_gunnyBagLatitude == null || _gunnyBagLongitude == null) {
      _showError(tr('get_location_first'));
      return;
    }

    final url =
        'https://www.google.com/maps/search/?api=1&query=$_gunnyBagLatitude,$_gunnyBagLongitude';
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showError(tr('cannot_open_google_maps'));
    }
  }

  // Pick Aadhaar image
  Future<void> _pickAadhaarImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _aadhaarImage = File(image.path);
        });
      }
    } catch (e) {
      _showError(tr('failed_pick_image'));
    }
  }

  // Pick business photos (max 3)
  Future<void> _pickBusinessPhotos() async {
    if (_businessPhotos.length >= 3) {
      _showError(tr('max_photos_limit'));
      return;
    }
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );

      if (image != null) {
        setState(() {
          _businessPhotos.add(image);
        });
      }
    } catch (e) {
      _showError(tr('failed_pick_image'));
    }
  }

  // Remove a business photo
  void _removeBusinessPhoto(int index) {
    setState(() {
      _businessPhotos.removeAt(index);
    });
  }

  // Convert business photos to base64 strings
  Future<List<String>> _convertPhotosToBase64() async {
    final List<String> base64Photos = [];
    for (final photo in _businessPhotos) {
      final bytes = await photo.readAsBytes();
      final base64String = base64Encode(bytes);
      base64Photos.add('data:image/jpeg;base64,$base64String');
    }
    return base64Photos;
  }

  // Get current location for business (GPS disabled)
  Future<void> _getCurrentLocation() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('location_not_available')),
        backgroundColor: Colors.orange,
      ),
    );
  }

  // Open Google Maps with location
  Future<void> _openInGoogleMaps() async {
    if (_businessLatitude == null || _businessLongitude == null) {
      _showError(tr('get_location_first'));
      return;
    }

    final url =
        'https://www.google.com/maps/search/?api=1&query=$_businessLatitude,$_businessLongitude';
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showError(tr('cannot_open_google_maps'));
    }
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedServiceType == null) {
      _showError(tr('select_service_type_error'));
      return;
    }

    // Validate state - either selected or other entered
    final stateValue = _isOtherState
        ? _otherStateController.text.trim()
        : _selectedState;
    final districtValue = _isOtherDistrict
        ? _otherDistrictController.text.trim()
        : _selectedDistrict;
    final cityValue = _isOtherVillage
        ? _cityController.text.trim()
        : (_selectedVillage ?? _cityController.text.trim());

    if ((stateValue == null || stateValue.isEmpty) ||
        (districtValue == null || districtValue.isEmpty)) {
      _showError(tr('select_state_district_error'));
      return;
    }

    // Validate fertilizers specific fields
    if (_selectedServiceType == 'fertilizers') {
      if (_businessNameController.text.trim().isEmpty) {
        _showError(tr('business_name_required'));
        return;
      }
      if (_businessAddressController.text.trim().isEmpty) {
        _showError(tr('business_address_required'));
        return;
      }
    }

    // Validate Majdoor specific fields
    if (_selectedServiceType == 'majdoor') {
      if (_majdoorMobileController.text.trim().isEmpty) {
        _showError(tr('mobile_number_required'));
        return;
      }
      if (_majdoorNameController.text.trim().isEmpty) {
        _showError(tr('name_required'));
        return;
      }
      if (_selectedKaamType == null) {
        _showError(tr('select_work_type'));
        return;
      }
      if (_selectedKaamJagah == null) {
        _showError(tr('select_work_location'));
        return;
      }
      if (_selectedAvailability == null) {
        _showError(tr('select_availability_error'));
        return;
      }
    }

    // Validate Gunny Bag specific fields
    if (_selectedServiceType == 'gunny-bag') {
      if (_gunnyBagBusinessNameController.text.trim().isEmpty) {
        _showError(tr('business_name_required'));
        return;
      }
      if (_gunnyBagPincodeController.text.trim().isEmpty) {
        _showError(tr('pincode_required'));
        return;
      }
      if (_gunnyBagPincodeController.text.trim().length != 6) {
        _showError(tr('pincode_6_digits'));
        return;
      }
      if (_gunnyBagOwnerNameController.text.trim().isEmpty) {
        _showError(tr('owner_name_required'));
        return;
      }
      if (_gunnyBagLatitude == null || _gunnyBagLongitude == null) {
        _showError(tr('get_business_location'));
        return;
      }
    }

    // Validate Machinery specific fields
    if (_selectedServiceType == 'machinery-rent') {
      if (_machineryBusinessNameController.text.trim().isEmpty) {
        _showError(tr('business_name_required'));
        return;
      }
      if (_selectedMachineType == null) {
        _showError(tr('select_machine_type'));
        return;
      }
      if (_selectedMachineryServiceType == null) {
        _showError(tr('select_sale_rent_type'));
        return;
      }
      if ((_selectedMachineryServiceType == 'rent' ||
              _selectedMachineryServiceType == 'both') &&
          _selectedRentType == null) {
        _showError(tr('select_rent_type'));
        return;
      }
      if (_fullNameController.text.trim().isEmpty) {
        _showError(tr('owner_name_required'));
        return;
      }
    }

    setState(() => _isLoading = true);

    // Convert business photos to base64 (for non-majdoor types)
    List<String>? photoBase64List;
    if (_selectedServiceType != 'majdoor' && _businessPhotos.isNotEmpty) {
      photoBase64List = await _convertPhotosToBase64();
    }

    // Update user role to aloo-mitra with service details
    final result = await _authService.updateUserRole(role: 'aloo-mitra');

    if (result['success']) {
      // Save service provider details
      final serviceResult = await _authService.updateAlooMitraProfile(
        serviceType: _selectedServiceType!,
        name: _selectedServiceType == 'fertilizers'
            ? _businessNameController.text.trim()
            : (_selectedServiceType == 'majdoor'
                  ? _majdoorNameController.text.trim()
                  : (_selectedServiceType == 'gunny-bag'
                        ? _gunnyBagOwnerNameController.text.trim()
                        : _fullNameController.text.trim())),
        state: stateValue,
        district: districtValue,
        city: cityValue,
        pricing: _selectedServiceType == 'majdoor'
            ? _majdoorWagesController.text.trim()
            : _pricingController.text.trim(),
        businessAddress: _selectedServiceType == 'fertilizers'
            ? _businessAddressController.text.trim()
            : null,
        pincode: _selectedServiceType == 'fertilizers'
            ? _pincodeController.text.trim()
            : (_selectedServiceType == 'gunny-bag'
                  ? _gunnyBagPincodeController.text.trim()
                  : null),
        latitude: _selectedServiceType == 'fertilizers'
            ? _businessLatitude
            : (_selectedServiceType == 'gunny-bag' ? _gunnyBagLatitude : null),
        longitude: _selectedServiceType == 'fertilizers'
            ? _businessLongitude
            : (_selectedServiceType == 'gunny-bag' ? _gunnyBagLongitude : null),
        // Majdoor-specific fields
        majdoorMobile: _selectedServiceType == 'majdoor'
            ? _majdoorMobileController.text.trim()
            : null,
        kaamType: _selectedServiceType == 'majdoor' ? _selectedKaamType : null,
        kaamJagah: _selectedServiceType == 'majdoor'
            ? _selectedKaamJagah
            : null,
        availability: _selectedServiceType == 'majdoor'
            ? _selectedAvailability
            : null,
        aadhaarImage: _selectedServiceType == 'majdoor' ? _aadhaarImage : null,
        // Gunny Bag-specific fields
        gunnyBagBusinessName: _selectedServiceType == 'gunny-bag'
            ? _gunnyBagBusinessNameController.text.trim()
            : null,
        gunnyBagOwnerName: _selectedServiceType == 'gunny-bag'
            ? _gunnyBagOwnerNameController.text.trim()
            : null,
        // Machinery-specific fields
        machineryBusinessName: _selectedServiceType == 'machinery-rent'
            ? _machineryBusinessNameController.text.trim()
            : null,
        machineType: _selectedServiceType == 'machinery-rent'
            ? _selectedMachineType
            : null,
        machineryServiceType: _selectedServiceType == 'machinery-rent'
            ? _selectedMachineryServiceType
            : null,
        rentType: _selectedServiceType == 'machinery-rent'
            ? _selectedRentType
            : null,
        salePriceMin:
            _selectedServiceType == 'machinery-rent' &&
                (_selectedMachineryServiceType == 'new-sale' ||
                    _selectedMachineryServiceType == 'both')
            ? _salePriceRange.start.round()
            : null,
        salePriceMax:
            _selectedServiceType == 'machinery-rent' &&
                (_selectedMachineryServiceType == 'new-sale' ||
                    _selectedMachineryServiceType == 'both')
            ? _salePriceRange.end.round()
            : null,
        rentPriceMin:
            _selectedServiceType == 'machinery-rent' &&
                (_selectedMachineryServiceType == 'rent' ||
                    _selectedMachineryServiceType == 'both')
            ? _rentPriceRange.start.round()
            : null,
        rentPriceMax:
            _selectedServiceType == 'machinery-rent' &&
                (_selectedMachineryServiceType == 'rent' ||
                    _selectedMachineryServiceType == 'both')
            ? _rentPriceRange.end.round()
            : null,
        // Business photos
        businessPhotos: photoBase64List,
      );

      // Ensure role is saved locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userRole', 'aloo-mitra');

      setState(() => _isLoading = false);

      if (serviceResult['success']) {
        if (mounted) {
          _showSuccessDialog();
        }
      } else {
        // Even if profile update fails, role was updated successfully
        // Show success and let user update profile later
        if (mounted) {
          _showSuccessDialog();
        }
      }
    } else {
      setState(() => _isLoading = false);
      _showError(result['message'] ?? 'Failed to update role');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
                tr('registration_successful'),
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tr('aloo_mitra_account_created'),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    // Navigate directly to Aloo Mitra dashboard
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/aloo_mitra_navbar',
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    tr('continue_btn'),
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
        );
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Image.asset(
            "assets/background_green.png",
            fit: BoxFit.cover,
            width: double.infinity,
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          tr('aloo_mitra_registration'),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Form Card
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Text(
                              tr('enter_service_details'),
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Service Type Dropdown
                            _buildDropdownField(
                              label: tr('service_type'),
                              hint: tr('select_service'),
                              value: _selectedServiceType,
                              items: _serviceTypes.map((type) {
                                return DropdownMenuItem<String>(
                                  value: type['value'],
                                  child: Text(
                                    type['label']!,
                                    style: GoogleFonts.inter(fontSize: 14),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() => _selectedServiceType = value);
                              },
                            ),
                            const SizedBox(height: 16),

                            // Conditional fields for Fertilizers
                            if (_selectedServiceType == 'fertilizers') ...[
                              // Business Name Field
                              _buildTextField(
                                controller: _businessNameController,
                                label: tr('business_name'),
                                hint: tr('enter_shop_business_name'),
                                validator: (value) {
                                  if (_selectedServiceType == 'fertilizers' &&
                                      (value == null || value.trim().isEmpty)) {
                                    return tr('business_name_required');
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Business Address Field
                              _buildTextField(
                                controller: _businessAddressController,
                                label: tr('business_address'),
                                hint: tr('enter_complete_address'),
                                validator: (value) {
                                  if (_selectedServiceType == 'fertilizers' &&
                                      (value == null || value.trim().isEmpty)) {
                                    return tr('business_address_required');
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Business Location
                              _buildLocationField(),
                              const SizedBox(height: 16),
                            ] else if (_selectedServiceType == 'gunny-bag') ...[
                              // Gunny Bag-specific fields
                              _buildGunnyBagFields(),
                            ] else if (_selectedServiceType ==
                                'machinery-rent') ...[
                              // Machinery-specific fields
                              _buildMachineryFields(),
                            ] else if (_selectedServiceType == 'majdoor') ...[
                              // Majdoor-specific fields
                              _buildMajdoorFields(),
                            ] else ...[
                              // Full Name Field (for non-fertilizers)
                              _buildTextField(
                                controller: _fullNameController,
                                label: tr('full_name'),
                                hint: tr('enter_full_name'),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return tr('full_name_required');
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ],

                            // State Dropdown with Other option
                            _buildStateField(),
                            const SizedBox(height: 16),

                            // District Dropdown with Other option
                            _buildDistrictField(),
                            const SizedBox(height: 16),

                            // Village Dropdown with Other option
                            _buildVillageField(),
                            const SizedBox(height: 16),

                            // Pincode Field (for fertilizers only)
                            if (_selectedServiceType == 'fertilizers') ...[
                              _buildTextField(
                                controller: _pincodeController,
                                label: tr('pincode'),
                                hint: tr('enter_pincode'),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (_selectedServiceType == 'fertilizers' &&
                                      (value == null || value.trim().isEmpty)) {
                                    return tr('pincode_required');
                                  }
                                  if (value != null &&
                                      value.trim().isNotEmpty &&
                                      value.trim().length != 6) {
                                    return tr('pincode_6_digits');
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Pricing Field (not shown for majdoor or machinery-rent - they have separate fields)
                            if (_selectedServiceType != 'majdoor' &&
                                _selectedServiceType != 'machinery-rent') ...[
                              _buildTextField(
                                controller: _pricingController,
                                label: tr('service_pricing'),
                                hint: tr('service_pricing_hint'),
                                keyboardType: TextInputType.text,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return tr('pricing_required');
                                  }
                                  return null;
                                },
                              ),
                            ],
                            const SizedBox(height: 16),

                            // Business Photos Section (not for Majdoor)
                            if (_selectedServiceType != null &&
                                _selectedServiceType != 'majdoor') ...[
                              _buildBusinessPhotosSection(),
                              const SizedBox(height: 16),
                            ],

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : _submitRegistration,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryGreen,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _isLoading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : Text(
                                        tr('register'),
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    Function(String)? onChanged,
    TextInputType? keyboardType,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          onChanged: onChanged,
          keyboardType: keyboardType,
          maxLength: maxLength,
          decoration: InputDecoration(
            counterText: maxLength != null ? '' : null,
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
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
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String hint,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: items.isNotEmpty
              ? () {
                  // This ensures the entire area is tappable
                }
              : null,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: DropdownButtonFormField<String>(
              initialValue: value,
              hint: Text(
                hint,
                style: GoogleFonts.inter(color: Colors.grey[400]),
              ),
              items: items,
              onChanged: onChanged,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
              ),
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
              isExpanded: true,
              dropdownColor: AppColors.cardBg(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('state'),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),

        // Dropdown for state selection
        GestureDetector(
          onTap: () {
            // Trigger dropdown programmatically
            FocusScope.of(context).unfocus();
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: DropdownButtonFormField<String>(
              initialValue: _isOtherState ? null : _selectedState,
              hint: Text(
                tr('select_state'),
                style: GoogleFonts.inter(color: Colors.grey[400]),
              ),
              items: _states.map((state) {
                return DropdownMenuItem<String>(
                  value: state,
                  child: Text(state, style: GoogleFonts.inter(fontSize: 14)),
                );
              }).toList(),
              onChanged: (value) {
                final isOther = value == tr('other_write');
                setState(() {
                  _isOtherState = isOther;
                  _selectedState = isOther ? null : value;
                  _selectedDistrict = null;
                  _selectedVillage = null;
                  _isOtherDistrict = false;
                  _isOtherVillage = false;
                  _otherStateController.clear();
                  _otherDistrictController.clear();
                  _cityController.clear();
                });
              },
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
              ),
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
              isExpanded: true,
              dropdownColor: AppColors.cardBg(context),
            ),
          ),
        ),

        // Manual entry field when "Other" is selected
        if (_isOtherState) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _otherStateController,
            decoration: InputDecoration(
              hintText: tr('enter_state_name'),
              hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primaryGreen,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              prefixIcon: Icon(Icons.edit, color: Colors.grey[500], size: 20),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDistrictField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('district'),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),

        // Dropdown for district selection
        GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: DropdownButtonFormField<String>(
              initialValue: _isOtherDistrict ? null : _selectedDistrict,
              hint: Text(
                tr('select_district'),
                style: GoogleFonts.inter(color: Colors.grey[400]),
              ),
              items: _districts.map((district) {
                return DropdownMenuItem<String>(
                  value: district,
                  child: Text(district, style: GoogleFonts.inter(fontSize: 14)),
                );
              }).toList(),
              onChanged: (_selectedState == null && !_isOtherState)
                  ? null
                  : (value) {
                      final isOther = value == tr('other_write');
                      setState(() {
                        _isOtherDistrict = isOther;
                        _selectedDistrict = isOther ? null : value;
                        _selectedVillage = null;
                        _isOtherVillage = false;
                        _otherDistrictController.clear();
                        _cityController.clear();
                      });
                    },
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
              ),
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
              isExpanded: true,
              dropdownColor: AppColors.cardBg(context),
            ),
          ),
        ),

        // Manual entry field when "Other" is selected
        if (_isOtherDistrict) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _otherDistrictController,
            decoration: InputDecoration(
              hintText: tr('enter_district_name'),
              hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primaryGreen,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              prefixIcon: Icon(Icons.edit, color: Colors.grey[500], size: 20),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVillageField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('city_village'),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),

        // Dropdown for village selection
        GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: DropdownButtonFormField<String>(
              initialValue: _isOtherVillage ? null : _selectedVillage,
              hint: Text(
                tr('select_village'),
                style: GoogleFonts.inter(color: Colors.grey[400]),
              ),
              items: _villages.map((village) {
                return DropdownMenuItem<String>(
                  value: village,
                  child: Text(village, style: GoogleFonts.inter(fontSize: 14)),
                );
              }).toList(),
              onChanged: (_selectedDistrict == null && !_isOtherDistrict)
                  ? null
                  : (value) {
                      final isOther = value == tr('other_write');
                      setState(() {
                        _isOtherVillage = isOther;
                        _selectedVillage = isOther ? null : value;
                        if (!isOther) {
                          _cityController.text = value ?? '';
                        } else {
                          _cityController.clear();
                        }
                      });
                    },
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
              ),
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
              isExpanded: true,
              dropdownColor: AppColors.cardBg(context),
            ),
          ),
        ),

        // Manual entry field when "Other" is selected
        if (_isOtherVillage) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _cityController,
            decoration: InputDecoration(
              hintText: tr('enter_village_name'),
              hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primaryGreen,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              prefixIcon: Icon(Icons.edit, color: Colors.grey[500], size: 20),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('business_location'),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: [
              // Location status
              if (_businessLatitude != null && _businessLongitude != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tr('location_captured'),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // View on map button
                      GestureDetector(
                        onTap: _openInGoogleMaps,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.map,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                tr('view_on_map'),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Get location button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isGettingLocation ? null : _getCurrentLocation,
                  icon: _isGettingLocation
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.my_location, size: 20),
                  label: Text(
                    _isGettingLocation
                        ? tr('getting_location')
                        : (_businessLatitude != null
                              ? tr('update_location')
                              : tr('share_live_location')),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              Text(
                tr('location_info_farmers'),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGunnyBagFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Business Name
        _buildTextField(
          controller: _gunnyBagBusinessNameController,
          label: tr('business_name_required_label'),
          hint: tr('enter_business_name'),
          validator: (value) {
            if (_selectedServiceType == 'gunny-bag' &&
                (value == null || value.trim().isEmpty)) {
              return tr('business_name_required');
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Pincode
        _buildTextField(
          controller: _gunnyBagPincodeController,
          label: tr('pincode_required_label'),
          hint: tr('enter_pincode'),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (_selectedServiceType == 'gunny-bag' &&
                (value == null || value.trim().isEmpty)) {
              return tr('pincode_required');
            }
            if (value != null &&
                value.trim().isNotEmpty &&
                value.trim().length != 6) {
              return tr('pincode_6_digits');
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // State Dropdown
        _buildStateField(),
        const SizedBox(height: 16),

        // District Dropdown
        _buildDistrictField(),
        const SizedBox(height: 16),

        // Village/Area Dropdown (Select Area)
        _buildVillageField(),
        const SizedBox(height: 16),

        // Business Location
        _buildGunnyBagLocationField(),
        const SizedBox(height: 16),

        // Owner Name
        _buildTextField(
          controller: _gunnyBagOwnerNameController,
          label: tr('owner_name_required_label'),
          hint: tr('enter_owner_name'),
          validator: (value) {
            if (_selectedServiceType == 'gunny-bag' &&
                (value == null || value.trim().isEmpty)) {
              return tr('owner_name_required');
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildGunnyBagLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('business_location_required_label'),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: [
              // Location status
              if (_gunnyBagLatitude != null && _gunnyBagLongitude != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tr('location_captured'),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // View on map button
                      GestureDetector(
                        onTap: _openGunnyBagInGoogleMaps,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.map,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                tr('view_on_map'),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Get location button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isGettingGunnyBagLocation
                      ? null
                      : _getGunnyBagLocation,
                  icon: _isGettingGunnyBagLocation
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.my_location, size: 20),
                  label: Text(
                    _isGettingGunnyBagLocation
                        ? tr('getting_location')
                        : (_gunnyBagLatitude != null
                              ? tr('update_location')
                              : tr('get_live_location')),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              Text(
                tr('location_info_google_maps'),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMachineryFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Business Name Field
        _buildTextField(
          controller: _machineryBusinessNameController,
          label: tr('business_name_required_label'),
          hint: tr('enter_business_name'),
          validator: (value) {
            if (_selectedServiceType == 'machinery-rent' &&
                (value == null || value.trim().isEmpty)) {
              return tr('business_name_required');
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Machine Type Dropdown
        Text(
          tr('machine_type_required_label'),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedMachineType,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: InputBorder.none,
              hintText: tr('select_machine_type_hint'),
              hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
            ),
            items: _machineTypes.map((type) {
              return DropdownMenuItem<String>(
                value: type['value'],
                child: Text(
                  type['label']!,
                  style: GoogleFonts.inter(fontSize: 14),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedMachineType = value;
              });
            },
            validator: (value) {
              if (_selectedServiceType == 'machinery-rent' && value == null) {
                return tr('select_machine_type');
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 20),

        // Service Type Radio Buttons (New Sale / Rent / Both)
        Text(
          tr('service_type_required_label'),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: _machineryServiceTypes.map((type) {
              return RadioListTile<String>(
                title: Text(
                  type['label']!,
                  style: GoogleFonts.inter(fontSize: 14),
                ),
                value: type['value']!,
                groupValue: _selectedMachineryServiceType,
                onChanged: (value) {
                  setState(() {
                    _selectedMachineryServiceType = value;
                  });
                },
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: AppColors.primaryGreen,
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),

        // Conditional Pricing based on service type
        if (_selectedMachineryServiceType == 'new-sale' ||
            _selectedMachineryServiceType == 'both') ...[
          // Sale Price Range Slider
          _buildPriceSlider(
            label: tr('sale_price_range'),
            rangeValues: _salePriceRange,
            min: 50000,
            max: 1000000,
            divisions: 19,
            onChanged: (values) {
              setState(() {
                _salePriceRange = values;
              });
            },
          ),
          const SizedBox(height: 20),
        ],

        if (_selectedMachineryServiceType == 'rent' ||
            _selectedMachineryServiceType == 'both') ...[
          // Rent Type Dropdown
          Text(
            tr('rent_type_required_label'),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedRentType,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: InputBorder.none,
                hintText: tr('select_rent_type_hint'),
                hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
              ),
              items: _rentTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type['value'],
                  child: Text(
                    type['label']!,
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedRentType = value;
                });
              },
              validator: (value) {
                if (_selectedServiceType == 'machinery-rent' &&
                    (_selectedMachineryServiceType == 'rent' ||
                        _selectedMachineryServiceType == 'both') &&
                    value == null) {
                  return tr('select_rent_type');
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 16),

          // Rent Price Range Slider
          _buildPriceSlider(
            label: tr('rent_price_range'),
            rangeValues: _rentPriceRange,
            min: 500,
            max: 5000,
            divisions: 9,
            onChanged: (values) {
              setState(() {
                _rentPriceRange = values;
              });
            },
          ),
          const SizedBox(height: 20),
        ],

        // Full Name Field
        _buildTextField(
          controller: _fullNameController,
          label: tr('owner_name_required_label'),
          hint: tr('enter_full_name'),
          validator: (value) {
            if (_selectedServiceType == 'machinery-rent' &&
                (value == null || value.trim().isEmpty)) {
              return tr('name_required');
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPriceSlider({
    required String label,
    required RangeValues rangeValues,
    required double min,
    required double max,
    required int divisions,
    required Function(RangeValues) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            color: Colors.grey[50],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₹${rangeValues.start.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  Text(
                    tr('range_to'),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    '₹${rangeValues.end.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppColors.primaryGreen,
                  inactiveTrackColor: Colors.grey[300],
                  thumbColor: AppColors.primaryGreen,
                  overlayColor: AppColors.primaryGreen.withOpacity(0.2),
                  rangeThumbShape: const RoundRangeSliderThumbShape(
                    enabledThumbRadius: 10,
                  ),
                  rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
                ),
                child: RangeSlider(
                  values: rangeValues,
                  min: min,
                  max: max,
                  divisions: divisions,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₹${min.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                  Text(
                    '₹${max.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBusinessPhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('business_photos_max3'),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tr('upload_business_photos_hint'),
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        // Photo grid
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            // Existing photos
            ..._businessPhotos.asMap().entries.map((entry) {
              final index = entry.key;
              final photo = entry.value;
              return Stack(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryGreen,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: FutureBuilder<Uint8List>(
                        future: photo.readAsBytes(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Image.memory(
                              snapshot.data!,
                              fit: BoxFit.cover,
                              width: 90,
                              height: 90,
                            );
                          }
                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    top: -4,
                    right: -4,
                    child: GestureDetector(
                      onTap: () => _removeBusinessPhoto(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
            // Add photo button
            if (_businessPhotos.length < 3)
              GestureDetector(
                onTap: _pickBusinessPhotos,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                    color: Colors.grey[50],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo,
                        color: Colors.grey[500],
                        size: 28,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr('photo'),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMajdoorFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mobile Number
        _buildTextField(
          controller: _majdoorMobileController,
          label: tr('mobile_number'),
          hint: tr('enter_mobile_number'),
          keyboardType: TextInputType.phone,
          maxLength: 10,
          validator: (value) {
            if (_selectedServiceType == 'majdoor' &&
                (value == null || value.trim().isEmpty)) {
              return tr('mobile_number_required');
            }
            if (value != null &&
                value.trim().isNotEmpty &&
                value.trim().length != 10) {
              return tr('mobile_10_digits');
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Full Name
        _buildTextField(
          controller: _majdoorNameController,
          label: tr('full_name'),
          hint: tr('enter_full_name'),
          validator: (value) {
            if (_selectedServiceType == 'majdoor' &&
                (value == null || value.trim().isEmpty)) {
              return tr('name_required');
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Kaam ka Type Dropdown
        _buildDropdownField(
          label: tr('work_type'),
          hint: tr('select_work_type'),
          value: _selectedKaamType,
          items: _kaamTypes.map((type) {
            return DropdownMenuItem<String>(
              value: type['value'],
              child: Text(
                type['label']!,
                style: GoogleFonts.inter(fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedKaamType = value);
          },
        ),
        const SizedBox(height: 16),

        // Kaam ki Jagah Dropdown
        _buildDropdownField(
          label: tr('work_location'),
          hint: tr('select_work_location'),
          value: _selectedKaamJagah,
          items: _kaamJagahOptions.map((jagah) {
            return DropdownMenuItem<String>(
              value: jagah['value'],
              child: Text(
                jagah['label']!,
                style: GoogleFonts.inter(fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedKaamJagah = value);
          },
        ),
        const SizedBox(height: 16),

        // Availability Dropdown
        _buildDropdownField(
          label: tr('availability'),
          hint: tr('select_availability'),
          value: _selectedAvailability,
          items: _availabilityOptions.map((option) {
            return DropdownMenuItem<String>(
              value: option['value'],
              child: Text(
                option['label']!,
                style: GoogleFonts.inter(fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedAvailability = value);
          },
        ),
        const SizedBox(height: 16),

        // Expected Mazdoori (Daily Wages)
        _buildTextField(
          controller: _majdoorWagesController,
          label: tr('expected_daily_wage'),
          hint: tr('enter_daily_wage'),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (_selectedServiceType == 'majdoor' &&
                (value == null || value.trim().isEmpty)) {
              return tr('enter_wages_error');
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Aadhaar Upload
        _buildAadhaarUploadField(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAadhaarUploadField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('aadhaar_optional'),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickAadhaarImage,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _aadhaarImage != null
                    ? AppColors.primaryGreen
                    : Colors.grey[300]!,
                width: _aadhaarImage != null ? 2 : 1,
              ),
            ),
            child: _aadhaarImage != null
                ? Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _aadhaarImage!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: AppColors.primaryGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tr('aadhaar_uploaded'),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr('tap_to_change'),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Icon(
                        Icons.upload_file,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tr('upload_aadhaar_photo'),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr('tap_to_select'),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
