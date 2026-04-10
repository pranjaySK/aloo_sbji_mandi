import 'dart:async';
import 'dart:convert';

import 'package:aloo_sbji_mandi/core/constants/state_city_data.dart';
import 'package:aloo_sbji_mandi/core/service/auth_service.dart';
import 'package:aloo_sbji_mandi/core/service/chat_service.dart';
import 'package:aloo_sbji_mandi/core/service/location_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final phoneController = TextEditingController();
  final nameController = TextEditingController();
  final List<TextEditingController> otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> otpFocusNodes = List.generate(6, (_) => FocusNode());

  // Dropdown selections
  String? _selectedState;
  String? _selectedDistrict;
  String? _selectedVillage;

  // Available options based on selections
  List<String> _availableStates = [];
  List<String> _availableDistricts = [];
  List<String> _availableVillages = [];

  // "Other" option tracking
  bool _isOtherState = false;
  bool _isOtherDistrict = false;
  bool _isOtherVillage = false;

  // Controllers for manual "Other" entry
  final _otherStateController = TextEditingController();
  final _otherDistrictController = TextEditingController();
  final _otherVillageController = TextEditingController();

  final _pincodeController = TextEditingController();

  final AuthService _authService = AuthService();
  final LocationService _locationService = LocationService();
  bool _isLoading = false;
  // bool _otpGenerated = false; // replaced by [_otpSent] (real OTP flow, same as login)
  bool _otpSent = false;
  int _resendTimer = 0;
  Timer? _otpTimer;
  bool _otpSendLoading = false;
  String? devSignupOtp;

  String? _errorMessage;
  bool _isLoadingLocation = false;
  bool _isFetchingPincode = false;

  @override
  void initState() {
    super.initState();
    _initializeDropdowns();
    // Auto-fetch on open (GPS → pincode → fields); user can tap Detect again to refresh.
    _autoFetchLocation();
  }

  void _initializeDropdowns() {
    _availableStates = StateCityData.states;
  }

  String get _otherOptionText => tr('other_write');

  void _onStateChanged(String? state) {
    final isOther = state == _otherOptionText;
    setState(() {
      _isOtherState = isOther;
      _selectedState = isOther ? null : state;
      _selectedDistrict = null;
      _selectedVillage = null;
      _isOtherDistrict = false;
      _isOtherVillage = false;
      _otherStateController.clear();
      _otherDistrictController.clear();
      _otherVillageController.clear();
      _availableDistricts = (state != null && !isOther)
          ? StateCityData.getCitiesForState(state)
          : [];
      _availableVillages = [];
    });
  }

  void _onDistrictChanged(String? district) {
    final isOther = district == _otherOptionText;
    setState(() {
      _isOtherDistrict = isOther;
      _selectedDistrict = isOther ? null : district;
      _selectedVillage = null;
      _isOtherVillage = false;
      _otherDistrictController.clear();
      _otherVillageController.clear();
      _availableVillages = (district != null && !isOther)
          ? StateCityData.getVillagesForDistrict(district)
          : [];
    });
  }

  void _onVillageChanged(String? village) {
    final isOther = village == _otherOptionText;
    setState(() {
      _isOtherVillage = isOther;
      _selectedVillage = isOther ? null : village;
      if (!isOther) {
        _otherVillageController.clear();
      }
    });
  }

  @override
  void dispose() {
    phoneController.dispose();
    nameController.dispose();
    for (var c in otpControllers) {
      c.dispose();
    }
    for (var f in otpFocusNodes) {
      f.dispose();
    }
    _pincodeController.dispose();
    _otherStateController.dispose();
    _otherDistrictController.dispose();
    _otherVillageController.dispose();
    _otpTimer?.cancel();
    super.dispose();
  }

  void _startSignupResendTimer() {
    setState(() => _resendTimer = 120);
    _otpTimer?.cancel();
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        timer.cancel();
      }
    });
  }

  /// Same pattern as [LoginScreen._sendOTP]: real API OTP via [AuthService.registerAndSendOTP].
  Future<void> _sendSignupOtp() async {
    if (!_validateFieldsBeforeOtp()) return;

    setState(() {
      _otpSendLoading = true;
      _errorMessage = null;
    });

    final nameParts = nameController.text.trim().split(' ');
    final firstName = nameParts.first;
    final lastName = nameParts.length > 1
        ? nameParts.sublist(1).join(' ')
        : 'User';

    final stateValue = _isOtherState
        ? _otherStateController.text.trim()
        : (_selectedState ?? '');
    final districtValue = _isOtherDistrict
        ? _otherDistrictController.text.trim()
        : (_selectedDistrict ?? '');
    final villageValue = _isOtherVillage
        ? _otherVillageController.text.trim()
        : (_selectedVillage ?? '');

    final result = await _authService.registerAndSendOTP(
      firstName: firstName,
      lastName: lastName,
      phone: phoneController.text.trim(),
      password: 'password123',
      role: 'farmer',
      address: {
        'village': villageValue,
        'district': districtValue,
        'state': stateValue,
        'pincode': _pincodeController.text.trim(),
      },
    );

    if (!mounted) return;
    setState(() => _otpSendLoading = false);

    if (result['success'] == true) {
      devSignupOtp = result['data']?['otp']?.toString();
      setState(() {
        _otpSent = true;
        _errorMessage = null;
      });
      _startSignupResendTimer();
      for (var c in otpControllers) {
        c.clear();
      }
      if (devSignupOtp != null && devSignupOtp!.length <= 6) {
        for (int i = 0; i < devSignupOtp!.length && i < 6; i++) {
          otpControllers[i].text = devSignupOtp![i];
        }
      } else {
        otpFocusNodes[0].requestFocus();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              devSignupOtp != null
                  ? '✅ OTP sent: $devSignupOtp (Dev Mode)'
                  : '✅ OTP sent to +91 ${phoneController.text.trim()}',
            ),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    } else {
      setState(() => _errorMessage = result['message']?.toString());
    }
  }

  Future<void> _resendSignupOtp() async {
    if (_resendTimer > 0 || !_otpSent) return;

    setState(() {
      _otpSendLoading = true;
      _errorMessage = null;
    });

    final result =
        await _authService.resendOTP(phone: phoneController.text.trim());

    if (!mounted) return;
    setState(() => _otpSendLoading = false);

    if (result['success'] == true) {
      devSignupOtp = result['data']?['otp']?.toString();
      _startSignupResendTimer();
      for (var c in otpControllers) {
        c.clear();
      }
      if (devSignupOtp != null && devSignupOtp!.length <= 6) {
        for (int i = 0; i < devSignupOtp!.length && i < 6; i++) {
          otpControllers[i].text = devSignupOtp![i];
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('otp_resent'))),
        );
      }
    } else {
      setState(() => _errorMessage = result['message']?.toString());
    }
  }

  bool _validateFieldsBeforeOtp() {
    if (phoneController.text.trim().length != 10) {
      setState(() => _errorMessage = tr('phone_10_digits'));
      return false;
    }
    if (nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = tr('enter_your_name'));
      return false;
    }
    if (_pincodeController.text.trim().length != 6) {
      setState(() => _errorMessage = tr('pincode_6_digits'));
      return false;
    }
    if (_selectedState == null && !_isOtherState) {
      setState(() => _errorMessage = tr('select_state'));
      return false;
    }
    if (_isOtherState && _otherStateController.text.trim().isEmpty) {
      setState(() => _errorMessage = tr('select_state'));
      return false;
    }
    if (_selectedDistrict == null && !_isOtherDistrict) {
      setState(() => _errorMessage = tr('select_district'));
      return false;
    }
    if (_isOtherDistrict && _otherDistrictController.text.trim().isEmpty) {
      setState(() => _errorMessage = tr('select_district'));
      return false;
    }
    if (_selectedVillage == null && !_isOtherVillage) {
      setState(() => _errorMessage = tr('select_village'));
      return false;
    }
    if (_isOtherVillage && _otherVillageController.text.trim().isEmpty) {
      setState(() => _errorMessage = tr('select_village'));
      return false;
    }
    return true;
  }

  /// Fetch location details from pincode using India Post API
  Future<void> _fetchLocationFromPincode(String pincode) async {
    if (pincode.length != 6) return;

    setState(() => _isFetchingPincode = true);

    try {
      final response = await http.get(
        Uri.parse('https://api.postalpincode.in/pincode/$pincode'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        if (data.isNotEmpty && data[0]['Status'] == 'Success') {
          final List<dynamic> postOffices = data[0]['PostOffice'] ?? [];

          if (postOffices.isNotEmpty) {
            final postOffice = postOffices[0];
            final String fetchedState = postOffice['State'] ?? '';
            final String fetchedDistrict = postOffice['District'] ?? '';
            final String fetchedArea = postOffice['Name'] ?? '';

            setState(() {
              _isOtherState = false;
              _isOtherDistrict = false;
              _isOtherVillage = false;

              // Set state if it exists in our data
              if (_availableStates.contains(fetchedState)) {
                _selectedState = fetchedState;
                _availableDistricts = StateCityData.getCitiesForState(
                  fetchedState,
                );

                // Set district if it exists
                if (_availableDistricts.contains(fetchedDistrict)) {
                  _selectedDistrict = fetchedDistrict;
                  _availableVillages = StateCityData.getVillagesForDistrict(
                    fetchedDistrict,
                  );

                  // Set village/area if it exists
                  if (_availableVillages.contains(fetchedArea)) {
                    _selectedVillage = fetchedArea;
                  } else if (_availableVillages.contains(
                    '$fetchedDistrict City',
                  )) {
                    _selectedVillage = '$fetchedDistrict City';
                  } else {
                    _selectedVillage = null;
                  }
                } else {
                  _selectedDistrict = null;
                  _selectedVillage = null;
                  _availableVillages = [];
                }
              } else {
                // State not in our list - set as Other
                _isOtherState = true;
                _otherStateController.text = fetchedState;
                _isOtherDistrict = true;
                _otherDistrictController.text = fetchedDistrict;
                _isOtherVillage = true;
                _otherVillageController.text = fetchedArea;
                _selectedState = null;
                _selectedDistrict = null;
                _selectedVillage = null;
                _availableDistricts = [];
                _availableVillages = [];
              }
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(tr('location_auto_filled')),
                  backgroundColor: AppColors.primaryGreen,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(tr('invalid_pincode')),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Pincode lookup error: $e');
    } finally {
      if (mounted) setState(() => _isFetchingPincode = false);
    }
  }

  // Detect / auto location: GPS + geocode when possible; pincode first then India Post fill.
  Future<void> _autoFetchLocation() async {
    setState(() => _isLoadingLocation = true);

    // ── OLD: IP-only snapshot, no pincode pipeline (kept for reference)
    // try {
    //   final locationData = await _locationService.getLocationData();
    //   if (mounted) {
    //     final fetchedState = locationData['state'];
    //     ...
    //   }
    // } catch (e) {
    //   print('Error fetching location: $e');
    // }

    try {
      final locationData = await _locationService.getLocationData();

      if (!mounted) return;

      final pinRaw = locationData['pincode']?.replaceAll(RegExp(r'\s'), '') ?? '';
      if (pinRaw.length == 6 && RegExp(r'^\d{6}$').hasMatch(pinRaw)) {
        setState(() {
          _pincodeController.text = pinRaw;
          _isLoadingLocation = false;
        });
        await Future.delayed(const Duration(milliseconds: 150));
        if (mounted) await _fetchLocationFromPincode(pinRaw);
        return;
      }

      final fetchedState = locationData['state'];
      final fetchedDistrict = locationData['district'];
      final fetchedVillage = locationData['village'];

      setState(() {
        if (fetchedState != null && _availableStates.contains(fetchedState)) {
          _selectedState = fetchedState;
          _availableDistricts = StateCityData.getCitiesForState(fetchedState);

          if (fetchedDistrict != null &&
              _availableDistricts.contains(fetchedDistrict)) {
            _selectedDistrict = fetchedDistrict;
            _availableVillages = StateCityData.getVillagesForDistrict(
              fetchedDistrict,
            );

            if (fetchedVillage != null &&
                _availableVillages.contains(fetchedVillage)) {
              _selectedVillage = fetchedVillage;
            }
          }
        }
        _isLoadingLocation = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  // Validate form fields (after real OTP sent — same as login: 6 digits)
  bool _validateForm() {
    if (!_validateFieldsBeforeOtp()) return false;

    if (!_otpSent) {
      setState(() => _errorMessage = tr('send_otp_first_signup'));
      return false;
    }

    final otp = otpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      setState(() => _errorMessage = tr('enter_complete_otp'));
      return false;
    }

    return true;
  }

  // Register user
  Future<void> _registerUser() async {
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // ── Used only by commented dev-register block above
    // final nameParts = nameController.text.trim().split(' ');
    // final firstName = nameParts.first;
    // final lastName = nameParts.length > 1
    //     ? nameParts.sublist(1).join(' ')
    //     : 'Kisan';
    // final stateValue = _isOtherState
    //     ? _otherStateController.text.trim()
    //     : (_selectedState ?? '');
    // final districtValue = _isOtherDistrict
    //     ? _otherDistrictController.text.trim()
    //     : (_selectedDistrict ?? '');
    // final villageValue = _isOtherVillage
    //     ? _otherVillageController.text.trim()
    //     : (_selectedVillage ?? '');

    final otp = otpControllers.map((c) => c.text).join();

    // ── OLD: dev-register without SMS OTP (kept for reference)
    // final result = await _authService.register(
    //   firstName: firstName,
    //   lastName: lastName,
    //   phone: phoneController.text.trim(),
    //   password: 'password123',
    //   role: 'farmer',
    //   address: {
    //     'village': villageValue,
    //     'district': districtValue,
    //     'state': stateValue,
    //     'pincode': _pincodeController.text.trim(),
    //   },
    // );

    final result = await _authService.verifyOTPAndRegister(
      phone: phoneController.text.trim(),
      otp: otp,
    );

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('registration_successful')),
            backgroundColor: Colors.green,
          ),
        );
        ChatService().connectSocket();
        Navigator.pushNamedAndRemoveUntil(context, '/role', (route) => false);
      }
    } else {
      setState(() => _errorMessage = result['message']?.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Green gradient background
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFD4E8A8), Color(0xFFF5F9EC)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.4],
              ),
            ),
          ),

          // Potato background image at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: 0.25,
              child: Image.asset(
                'assets/potato.png',
                height: MediaQuery.of(context).size.height * 0.3,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Logo
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/logo.png',
                        height: 70,
                        errorBuilder: (context, error, stackTrace) => Column(
                          children: [
                            Icon(
                              Icons.eco,
                              size: 40,
                              color: AppColors.primaryGreen,
                            ),
                            Text(
                              'ALOO MARKET',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Create Account with phone number
                  Text(
                    tr('create_account_phone'),
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 1. Phone Number field (rounded)
                  _buildRoundedInputField(
                    controller: phoneController,
                    hintText: tr('phone_hint'),
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    prefixWidget: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Image.asset(
                        "assets/flag_icon.png",
                        width: 24,
                        height: 24,
                        errorBuilder: (context, error, stackTrace) =>
                            const Text("🇮🇳", style: TextStyle(fontSize: 20)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 2. Enter Name field (rounded)
                  _buildRoundedInputField(
                    controller: nameController,
                    hintText: tr('enter_name'),
                    prefixWidget: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Image.asset(
                        "assets/name_icon.png",
                        width: 24,
                        height: 24,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.person,
                          color: Colors.amber[700],
                          size: 24,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── OLD: dummy 1234 OTP + 4 boxes (kept as comment — now real API + 6 digits after location)
                  // Row( ... generate_otp TextButton with fake 1234 ... )
                  // Row( children: List.generate(4, ...) )

                  // Location section header with refresh button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: AppColors.primaryGreen,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            tr('location_details'),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          if (_isLoadingLocation)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ),
                        ],
                      ),
                      GestureDetector(
                        onTap: _isLoadingLocation ? null : _autoFetchLocation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.my_location,
                                size: 14,
                                color: _isLoadingLocation
                                    ? Colors.grey
                                    : AppColors.primaryGreen,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                tr('detect'),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: _isLoadingLocation
                                      ? Colors.grey
                                      : AppColors.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Pincode field with auto-fetch
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                    ),
                    child: TextField(
                      controller: _pincodeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) {
                        if (value.length == 6) {
                          _fetchLocationFromPincode(value);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: tr('enter_pincode'),
                        hintStyle: GoogleFonts.inter(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                        counterText: '',
                        prefixIcon: const Icon(
                          Icons.pin_drop,
                          color: AppColors.primaryGreen,
                        ),
                        suffixIcon: _isFetchingPincode
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(
                                  Icons.search,
                                  color: AppColors.primaryGreen,
                                ),
                                onPressed: () {
                                  if (_pincodeController.text.length == 6) {
                                    _fetchLocationFromPincode(
                                      _pincodeController.text,
                                    );
                                  }
                                },
                              ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 4. State Dropdown with Other option
                  _buildDropdownField(
                    value: _isOtherState ? null : _selectedState,
                    items: [_otherOptionText, ..._availableStates],
                    hintText: tr('select_state'),
                    onChanged: _onStateChanged,
                  ),

                  // Manual state entry when "Other" selected
                  if (_isOtherState) ...[
                    const SizedBox(height: 8),
                    _buildOtherTextField(
                      controller: _otherStateController,
                      hintText: tr('enter_state_name'),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // 5. District Dropdown with Other option
                  _buildDropdownField(
                    value: _isOtherDistrict ? null : _selectedDistrict,
                    items: _isOtherState
                        ? [_otherOptionText]
                        : [
                            if (_availableDistricts.isNotEmpty ||
                                _selectedState != null)
                              _otherOptionText,
                            ..._availableDistricts,
                          ],
                    hintText: tr('select_district'),
                    onChanged: _onDistrictChanged,
                    enabled: _selectedState != null || _isOtherState,
                  ),

                  // Manual district entry when "Other" selected
                  if (_isOtherDistrict) ...[
                    const SizedBox(height: 8),
                    _buildOtherTextField(
                      controller: _otherDistrictController,
                      hintText: tr('enter_district_name'),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // 6. City/Village Dropdown with Other option
                  _buildDropdownField(
                    value: _isOtherVillage ? null : _selectedVillage,
                    items: _isOtherDistrict
                        ? [_otherOptionText]
                        : [
                            if (_availableVillages.isNotEmpty ||
                                _selectedDistrict != null)
                              _otherOptionText,
                            ..._availableVillages,
                          ],
                    hintText: tr('select_village'),
                    onChanged: _onVillageChanged,
                    enabled: _selectedDistrict != null || _isOtherDistrict,
                  ),

                  // Manual village entry when "Other" selected
                  if (_isOtherVillage) ...[
                    const SizedBox(height: 8),
                    _buildOtherTextField(
                      controller: _otherVillageController,
                      hintText: tr('enter_village_name'),
                    ),
                  ],

                  const SizedBox(height: 20),

                  Text(
                    tr('verify_otp'),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('fill_location_then_send_otp_hint'),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B4332),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: (_otpSendLoading || _otpSent)
                          ? null
                          : _sendSignupOtp,
                      child: Text(
                        _otpSendLoading
                            ? tr('sending_otp')
                            : tr('generate_otp'),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  if (_otpSent && _resendTimer > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      trArgs('resend_otp_countdown', {
                        'seconds': '$_resendTimer',
                      }),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],

                  if (_otpSent) ...[
                    const SizedBox(height: 16),
                    Text(
                      tr('enter_complete_otp'),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        6,
                        (index) => SizedBox(
                          width: 48,
                          child: TextField(
                            controller: otpControllers[index],
                            focusNode: otpFocusNodes[index],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (value) {
                              if (value.isNotEmpty && index < 5) {
                                otpFocusNodes[index + 1].requestFocus();
                              } else if (value.isEmpty && index > 0) {
                                otpFocusNodes[index - 1].requestFocus();
                              }
                            },
                            decoration: InputDecoration(
                              counterText: '',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.border,
                                  width: 0.8,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (devSignupOtp != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Dev: $devSignupOtp',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: (_resendTimer == 0 && !_otpSendLoading)
                          ? _resendSignupOtp
                          : null,
                      child: Text(
                        tr('resend_otp_login'),
                        style: GoogleFonts.inter(
                          color: (_resendTimer == 0)
                              ? AppColors.primaryGreen
                              : Colors.grey,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Error message
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.inter(
                                color: Colors.red.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // 7. Create button at bottom right
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B4332),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _isLoading ? null : _registerUser,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                tr('create'),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),

                  // Already have an account? Login link
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            tr('already_account'),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: Text(
                              tr('login_link'),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1B4332),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Rounded input field (for phone and name)
  Widget _buildRoundedInputField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    Widget? prefixWidget,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType ?? TextInputType.text,
        maxLength: maxLength,
        inputFormatters: inputFormatters,
        style: GoogleFonts.inter(fontSize: 14),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14),
          counterText: "", // Hide character counter
          filled: true,
          fillColor: AppColors.inputFill(context),
          prefixIcon: prefixWidget,
          prefixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // Text field for manual "Other" entry
  Widget _buildOtherTextField({
    required TextEditingController controller,
    required String hintText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: TextFormField(
        controller: controller,
        style: GoogleFonts.inter(fontSize: 14),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.inter(color: Colors.grey[500], fontSize: 14),
          filled: true,
          fillColor: AppColors.inputFill(context),
          prefixIcon: Icon(Icons.edit, color: Colors.grey[500], size: 20),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.primaryGreen, width: 1),
          ),
        ),
      ),
    );
  }

  // Dropdown field for State/District/Village selection
  Widget _buildDropdownField({
    required String? value,
    required List<String> items,
    required String hintText,
    required void Function(String?) onChanged,
    bool enabled = true,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(color: Colors.grey[500], fontSize: 14),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      isExpanded: true,
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: enabled ? AppColors.primaryGreen : Colors.grey,
      ),
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item,
            style: GoogleFonts.inter(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: enabled ? onChanged : null,
      menuMaxHeight: 300,
    );
  }
}
