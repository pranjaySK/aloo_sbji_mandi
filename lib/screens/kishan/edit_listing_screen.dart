import 'package:aloo_sbji_mandi/core/service/listing_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:aloo_sbji_mandi/core/utils/toast_helper.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class EditListingScreen extends StatefulWidget {
  final Map<String, dynamic> listing;

  const EditListingScreen({super.key, required this.listing});

  @override
  State<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends State<EditListingScreen> {
  final ListingService _listingService = ListingService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _quantityController;
  late TextEditingController _priceController;
  late TextEditingController _phoneController;

  String? _selectedVariety;
  String _selectedSize = 'Medium';
  bool _isActive = true;
  bool _isLoading = false;

  final List<String> _varietyList = [
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

  final List<String> _sizeList = ['small', 'medium', 'large'];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _quantityController = TextEditingController(
      text: widget.listing['quantity']?.toString() ?? '',
    );
    _priceController = TextEditingController(
      text: widget.listing['pricePerQuintal']?.toString() ?? '',
    );
    String phoneText = '';
    if (widget.listing['contactPhone'] != null) {
      phoneText = widget.listing['contactPhone'].toString();
    } else if (widget.listing['seller'] is Map) {
      final sellerMap = widget.listing['seller'] as Map;
      if (sellerMap['phone'] != null) {
        phoneText = sellerMap['phone'].toString();
      }
    }
    _phoneController = TextEditingController(text: phoneText);

    _selectedVariety = widget.listing['potatoVariety'];
    _selectedSize = (widget.listing['size'] ?? 'medium').toString().toLowerCase();
    _isActive = widget.listing['isActive'] ?? true;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _updateListing() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await _listingService.updateListing(
      listingId: widget.listing['_id'],
      potatoVariety: _selectedVariety,
      quantity: int.tryParse(_quantityController.text),
      pricePerQuintal: int.tryParse(_priceController.text),
      size: _selectedSize[0].toUpperCase() + _selectedSize.substring(1), // Store as capitalized for DB compatibility if needed
      isActive: _isActive,
      contactPhone: _phoneController.text.isNotEmpty
          ? _phoneController.text
          : null,
    );

    setState(() => _isLoading = false);

    if (result['success']) {
      if (mounted) {
        _showSuccessDialog();
      }
    } else {
      if (mounted) {
        ToastHelper.showError(
          context,
          result['message'] ?? 'Failed to update listing',
        );
      }
    }
  }

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
              tr('updated_successfully'),
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              tr('listing_updated_message'),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(
                    context,
                    true,
                  ); // Return to listing screen with refresh flag
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  tr('ok'),
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

  @override
  Widget build(BuildContext context) {
    final type = widget.listing['type'] ?? 'sell';
    final sourceType = widget.listing['sourceType'] ?? 'field';
    final referenceId = widget.listing['referenceId'] as String?;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CustomRoundedAppBar(title: tr('edit_listing'), actions: const []),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Listing Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        type == 'sell' ? Icons.sell : Icons.shopping_cart,
                        color: AppColors.primaryGreen,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type == 'sell'
                                ? tr('sell_listing')
                                : tr('buy_listing'),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                sourceType == 'cold_storage'
                                    ? Icons.ac_unit
                                    : Icons.grass,
                                size: 14,
                                color: sourceType == 'cold_storage'
                                    ? Colors.blue
                                    : Colors.green,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                sourceType == 'cold_storage'
                                    ? tr('cold_storage')
                                    : tr('field'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          if (referenceId != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              referenceId,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[500],
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Active/Inactive Switch
                    Column(
                      children: [
                        Switch(
                          value: _isActive,
                          activeThumbColor: AppColors.primaryGreen,
                          onChanged: (value) {
                            setState(() => _isActive = value);
                          },
                        ),
                        Text(
                          _isActive ? tr('active') : tr('inactive'),
                          style: TextStyle(
                            fontSize: 10,
                            color: _isActive ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Variety Dropdown
              _buildLabel(tr('potato_variety')),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonFormField<String>(
                  initialValue: _varietyList.contains(_selectedVariety)
                      ? _selectedVariety
                      : null,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: InputBorder.none,
                    hintText: tr('select_variety'),
                  ),
                  items: _varietyList.map((variety) {
                    return DropdownMenuItem(
                      value: variety,
                      child: Text(variety),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedVariety = value);
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return tr('please_select_variety');
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Size Selection
              _buildLabel(tr('size')),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: _sizeList
                    .map((size) => _buildSizeChip(size))
                    .toList(),
              ),
              const SizedBox(height: 20),

              // Quantity
              _buildLabel(
                trArgs('quantity_in_unit', {
                  'unit': unitLabel(widget.listing['unit'] ?? 'Quintal'),
                }),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _inputDecoration(
                  hint: tr('enter_quantity'),
                  icon: Icons.inventory_2,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return tr('quantity_required');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Price
              _buildLabel(
                trArgs('price_per_unit', {
                  'unit': unitLabel(widget.listing['unit'] ?? 'Quintal'),
                }),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _inputDecoration(
                  hint: tr('enter_price'),
                  icon: Icons.currency_rupee,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return tr('price_required');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Phone Number
              _buildLabel(tr('phone_number')),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: _inputDecoration(
                  hint: tr('enter_phone'),
                  icon: Icons.phone,
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty && value.length != 10) {
                    return tr('phone_10_digits');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Update Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateListing,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          tr('update_listing'),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary(context),
      ),
    );
  }

  Widget _buildSizeChip(String size) {
    final isSelected = _selectedSize == size;
    return ChoiceChip(
      label: Text(tr(size)),
      selected: isSelected,
      selectedColor: AppColors.primaryGreen,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      onSelected: (_) {
        setState(() => _selectedSize = size);
      },
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.primaryGreen),
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
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }
}
