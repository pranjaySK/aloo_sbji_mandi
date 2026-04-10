import 'dart:convert';
import 'package:aloo_sbji_mandi/core/service/listing_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:aloo_sbji_mandi/core/utils/toast_helper.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:aloo_sbji_mandi/widgets/common_widget.dart/drop_down_widget.dart' show dropdown;
import 'package:aloo_sbji_mandi/widgets/common_widget.dart/label_widget.dart' show label;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Screen for Aloo Mitra (Seed Producers) to create a seed listing
class CreateSeedListingScreen extends StatefulWidget {
  const CreateSeedListingScreen({super.key});

  @override
  State<CreateSeedListingScreen> createState() => _CreateSeedListingScreenState();
}

class _CreateSeedListingScreenState extends State<CreateSeedListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final ListingService _listingService = ListingService();
  
  // Controllers
  final TextEditingController _quantityController = TextEditingController(text: '10');
  final TextEditingController _pricePerQuintalController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _customVarietyController = TextEditingController();
  
  // Selections
  String? _selectedVariety;
  String _selectedSize = "Medium";
  bool _isSubmitting = false;
  
  // User data
  Map<String, dynamic>? _userData;
  
  // Variety list with "Others" at top
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
  
  final List<String> _sizeOptions = ["Small", "Medium", "Large"];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _pricePerQuintalController.dispose();
    _descriptionController.dispose();
    _customVarietyController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    
    if (userJson != null) {
      try {
        setState(() {
          _userData = json.decode(userJson);
        });
      } catch (e) {
        print('Error parsing user data: $e');
      }
    }
  }

  Future<void> _submitListing() async {
    if (!_formKey.currentState!.validate()) return;
    
    final variety = _selectedVariety == "Others" 
        ? _customVarietyController.text.trim()
        : _selectedVariety;
    
    if (variety == null || variety.isEmpty) {
      ToastHelper.showError(
        context, 
        tr('please_select_seed_variety'),
      );
      return;
    }
    
    setState(() => _isSubmitting = true);
    
    try {
      // Get location from user data (Aloo Mitra profile)
      final alooMitraProfile = _userData?['alooMitraProfile'];
      
      final location = {
        'state': _userData?['address']?['state'] ?? alooMitraProfile?['state'] ?? '',
        'district': _userData?['address']?['district'] ?? alooMitraProfile?['district'] ?? '',
        'city': _userData?['address']?['city'] ?? alooMitraProfile?['city'] ?? '',
      };
      
      final result = await _listingService.createListing(
        type: 'sell',
        potatoVariety: variety,
        quantity: int.tryParse(_quantityController.text) ?? 0,
        pricePerQuintal: int.tryParse(_pricePerQuintalController.text) ?? 0,
        description: _descriptionController.text.trim(),
        size: _selectedSize,
        location: location.map((key, value) => MapEntry(key, value.toString())),
        sourceType: 'cold_storage', // Seeds are typically stored in cold storage
        listingType: 'seed',
      );
      
      if (result['success']) {
        ToastHelper.showSuccess(
          context, 
          tr('seed_listing_created_successfully'),
        );
        Navigator.pop(context, true);
      } else {
        ToastHelper.showError(
          context, 
          result['message'] ?? tr('failed_to_create_listing'),
        );
      }
    } catch (e) {
      ToastHelper.showError(
        context, 
        tr('something_went_wrong'),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardBg(context),
      appBar: CustomRoundedAppBar(
        title: tr("new_seed_listing"),
        leadingIcon: Icons.arrow_back,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.eco, color: AppColors.primaryGreen, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr("create_seed_listing"),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tr("listing_visible_to_farmers"),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Variety Selection
              label(tr("potato_variety_required")),
              const SizedBox(height: 8),
              dropdown(
                hint: tr("select_variety"),
                value: _selectedVariety,
                items: _varietyList,
                onChanged: (value) {
                  setState(() {
                    _selectedVariety = value;
                    if (value != "Others") {
                      _customVarietyController.clear();
                    }
                  });
                },
              ),
              
              // Custom variety input (if "Others" selected)
              if (_selectedVariety == "Others") ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customVarietyController,
                  decoration: InputDecoration(
                    hintText: tr("enter_variety_name"),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  validator: (value) {
                    if (_selectedVariety == "Others" && (value == null || value.isEmpty)) {
                      return tr("please_enter_variety_name");
                    }
                    return null;
                  },
                ),
              ],
              
              const SizedBox(height: 20),
              
              // Quantity
              label(tr("quantity_quintal_required")),
              const SizedBox(height: 8),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: tr("enter_quantity"),
                  suffixText: tr("qtl"),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return tr("please_enter_quantity");
                  }
                  final qty = int.tryParse(value);
                  if (qty == null || qty <= 0) {
                    return tr("quantity_must_be_greater_than_zero");
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 20),
              
              // Price per Quintal
              label(tr("price_per_quintal_required")),
              const SizedBox(height: 8),
              TextFormField(
                controller: _pricePerQuintalController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: tr("enter_price"),
                  prefixText: "₹ ",
                  suffixText: tr("per_qtl"),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return tr("please_enter_price");
                  }
                  final price = int.tryParse(value);
                  if (price == null || price <= 0) {
                    return tr("price_must_be_greater_than_zero");
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 20),
              
              // Size Selection
              label(tr("potato_size")),
              const SizedBox(height: 8),
              Row(
                children: _sizeOptions.map((size) {
                  final isSelected = _selectedSize == size;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedSize = size),
                      child: Container(
                        margin: EdgeInsets.only(
                          right: size != _sizeOptions.last ? 8 : 0,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? AppColors.primaryGreen 
                              : AppColors.surfaceVariant(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected 
                                ? AppColors.primaryGreen 
                                : Colors.grey[300]!,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _getSizeLabel(size),
                            style: GoogleFonts.inter(
                              color: isSelected ? Colors.white : Colors.grey[700],
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 20),
              
              // Description (Optional)
              label(tr("description_optional")),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: tr("write_additional_seed_details"),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitListing,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
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
                          tr("create_listing"),
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
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tr("listing_active_for_60_days"),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.amber[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
  
  String _getSizeLabel(String size) {
    switch (size) {
      case 'Small':
        return tr('small');
      case 'Medium':
        return tr('medium');
      case 'Large':
        return tr('large');
      default:
        return size;
    }
  }
}
