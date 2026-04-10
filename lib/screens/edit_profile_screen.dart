import 'dart:convert';

import 'package:aloo_sbji_mandi/core/constants/state_city_data.dart';
import 'package:aloo_sbji_mandi/core/service/location_service.dart';
import 'package:aloo_sbji_mandi/core/service/user_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:aloo_sbji_mandi/widgets/common_widget.dart/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  // Dropdown selections
  String? _selectedState;
  String? _selectedDistrict;
  String? _selectedVillage;

  // Available options based on selections
  List<String> _availableStates = [];
  List<String> _availableDistricts = [];
  List<String> _availableVillages = [];

  final UserService _userService = UserService();
  final LocationService _locationService = LocationService();
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _initializeDropdowns();
    _loadUserData();
  }

  void _initializeDropdowns() {
    _availableStates = StateCityData.states;
  }

  void _onStateChanged(String? state) {
    setState(() {
      _selectedState = state;
      _selectedDistrict = null;
      _selectedVillage = null;
      _availableDistricts = state != null
          ? StateCityData.getCitiesForState(state)
          : [];
      _availableVillages = [];
    });
  }

  void _onDistrictChanged(String? district) {
    setState(() {
      _selectedDistrict = district;
      _selectedVillage = null;
      _availableVillages = district != null
          ? StateCityData.getVillagesForDistrict(district)
          : [];
    });
  }

  void _onVillageChanged(String? village) {
    setState(() {
      _selectedVillage = village;
    });
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    debugPrint('User data: $userJson');
    if (userJson != null) {
      final userData = json.decode(userJson);
      final savedState = userData['address']?['state'] as String?;
      final savedDistrict = userData['address']?['district'] as String?;
      final savedVillage = userData['address']?['village'] as String?;

      setState(() {
        _firstNameController.text = userData['firstName'] ?? '';
        _lastNameController.text = userData['lastName'] ?? '';

        // Set state and populate districts
        if (savedState != null && _availableStates.contains(savedState)) {
          _selectedState = savedState;
          _availableDistricts = StateCityData.getCitiesForState(savedState);

          // Set district and populate villages
          if (savedDistrict != null &&
              _availableDistricts.contains(savedDistrict)) {
            _selectedDistrict = savedDistrict;
            _availableVillages = StateCityData.getVillagesForDistrict(
              savedDistrict,
            );

            // Set village
            if (savedVillage != null &&
                _availableVillages.contains(savedVillage)) {
              _selectedVillage = savedVillage;
            }
          }
        }
        _isInitialized = true;
      });
    } else {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  // Fetch location from device
  Future<void> _fetchLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      final locationData = await _locationService.getLocationData();

      if (mounted) {
        final fetchedState = locationData['state'];
        final fetchedDistrict = locationData['district'];
        final fetchedVillage = locationData['village'];

        setState(() {
          // Set state if available
          if (fetchedState != null && _availableStates.contains(fetchedState)) {
            _selectedState = fetchedState;
            _availableDistricts = StateCityData.getCitiesForState(fetchedState);

            // Set district if available
            if (fetchedDistrict != null &&
                _availableDistricts.contains(fetchedDistrict)) {
              _selectedDistrict = fetchedDistrict;
              _availableVillages = StateCityData.getVillagesForDistrict(
                fetchedDistrict,
              );

              // Set village if available
              if (fetchedVillage != null &&
                  _availableVillages.contains(fetchedVillage)) {
                _selectedVillage = fetchedVillage;
              }
            }
          }
          _isLoadingLocation = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('location_updated')),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr('failed_to_get_location')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final result = await _userService.updateProfile(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      village: _selectedVillage ?? '',
      district: _selectedDistrict ?? '',
      state: _selectedState ?? '',
    );

    setState(() {
      _isLoading = false;
    });

    if (result['success']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('profile_updated')),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate update
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? tr('failed_update_profile')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: CustomRoundedAppBar(title: tr('edit_profile')),
      body: !_isInitialized
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('personal_info'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _firstNameController,
                      label: tr('first_name'),
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return tr('enter_first_name');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _lastNameController,
                      label: tr('last_name'),
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return tr('enter_last_name');
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 32),

                    Text(
                      tr('address_info'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildDropdownField(
                      label: 'State',
                      icon: Icons.map_outlined,
                      value: _selectedState,
                      items: _availableStates,
                      onChanged: _onStateChanged,
                      hint: tr('select_state'),
                    ),
                    const SizedBox(height: 16),

                    _buildDropdownField(
                      label: 'District',
                      icon: Icons.location_city_outlined,
                      value: _selectedDistrict,
                      items: _availableDistricts,
                      onChanged: _onDistrictChanged,
                      hint: tr('select_district'),
                      enabled: _selectedState != null,
                    ),
                    const SizedBox(height: 16),

                    _buildDropdownField(
                      label: 'City/Village',
                      icon: Icons.location_on_outlined,
                      value: _selectedVillage,
                      items: _availableVillages,
                      onChanged: _onVillageChanged,
                      hint: tr('select_village'),
                      enabled: _selectedDistrict != null,
                    ),

                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primaryGreen,
                              ),
                            )
                          : PrimaryButton(
                              text: tr('save_changes'),
                              onTap: _saveProfile,
                            ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primaryGreen),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppColors.inputFill(context),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          floatingLabelStyle: const TextStyle(color: AppColors.primaryGreen),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    required String hint,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: enabled
            ? AppColors.cardBg(context)
            : AppColors.surfaceVariant(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            icon,
            color: enabled ? AppColors.primaryGreen : Colors.grey,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: enabled
              ? AppColors.inputFill(context)
              : AppColors.surfaceVariant(context),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          floatingLabelStyle: const TextStyle(color: AppColors.primaryGreen),
        ),
        hint: Text(hint, style: TextStyle(color: Colors.grey.shade500)),
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
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: enabled ? onChanged : null,
        menuMaxHeight: 300,
      ),
    );
  }
}
