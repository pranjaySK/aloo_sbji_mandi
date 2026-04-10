import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/utils/app_localizations.dart';

class KishanAiAdvisoryScreen extends StatefulWidget {
  const KishanAiAdvisoryScreen({super.key});

  @override
  State<KishanAiAdvisoryScreen> createState() => _KishanAiAdvisoryScreenState();
}

class _KishanAiAdvisoryScreenState extends State<KishanAiAdvisoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _marketPriceController = TextEditingController();

  String _selectedQuality = ''; // Small / Medium / Large
  String _coldStorageAvailable = ''; // Yes / No

  bool _isLoading = false;
  Map<String, dynamic>? _advisoryResult;

  final List<String> _qualityOptions = ['Small', 'Medium', 'Large'];
  final List<String> _coldStorageOptions = ['Yes', 'No'];

  @override
  void dispose() {
    _quantityController.dispose();
    _marketPriceController.dispose();
    super.dispose();
  }

  String _qualityLabel(String val) {
    switch (val) {
      case 'Small':
        return tr('quality_small');
      case 'Medium':
        return tr('quality_medium');
      case 'Large':
        return tr('quality_large');
      default:
        return val;
    }
  }

  String _coldStorageLabel(String val) {
    return val == 'Yes' ? tr('yes') : tr('no');
  }

  void _getAdvisory() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedQuality.isEmpty || _coldStorageAvailable.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('fill_all_fields'))));
      return;
    }

    setState(() => _isLoading = true);

    // Simulate AI processing
    Future.delayed(const Duration(seconds: 2), () {
      final result = _generateKishanAdvisory(
        quantity: double.tryParse(_quantityController.text) ?? 0,
        quality: _selectedQuality,
        marketPrice: double.tryParse(_marketPriceController.text) ?? 0,
        coldStorageAvailable: _coldStorageAvailable == 'Yes',
      );
      setState(() {
        _advisoryResult = result;
        _isLoading = false;
      });
    });
  }

  Map<String, dynamic> _generateKishanAdvisory({
    required double quantity,
    required String quality,
    required double marketPrice,
    required bool coldStorageAvailable,
  }) {
    // Rule-based AI advisory logic
    String recommendation;
    String reasoning;
    List<String> risks;
    Color recommendationColor;
    IconData recommendationIcon;

    // Price thresholds (INR per quintal)
    final bool priceHigh = marketPrice >= 1500;
    final bool priceLow = marketPrice < 800;
    final bool qualityPremium = quality == 'Large';
    final bool qualityLow = quality == 'Small';
    final bool largeQuantity = quantity > 100;

    if (priceHigh && qualityPremium) {
      // High price + premium quality → Sell now
      recommendation = tr('sell_now_advice');
      reasoning = trArgs('sell_now_reasoning', {
        'price': marketPrice.toInt().toString(),
      });
      risks = [tr('risk_price_drop'), tr('risk_spoilage_storage')];
      recommendationColor = Colors.green;
      recommendationIcon = Icons.trending_up;
    } else if (priceLow && coldStorageAvailable && !qualityLow) {
      // Low price + cold storage available + decent quality → Store
      recommendation = tr('store_in_cold');
      reasoning = trArgs('store_cold_reasoning', {
        'price': marketPrice.toInt().toString(),
      });
      risks = [tr('risk_cold_storage_rent'), tr('risk_price_may_drop')];
      recommendationColor = Colors.blue;
      recommendationIcon = Icons.warehouse;
    } else if (priceLow && !coldStorageAvailable) {
      // Low price + no cold storage → Sell partially
      recommendation = tr('sell_partially');
      reasoning = trArgs('sell_half_reasoning', {
        'price': marketPrice.toInt().toString(),
      });
      risks = [tr('risk_no_cs_spoilage'), tr('risk_sell_quickly')];
      recommendationColor = Colors.orange;
      recommendationIcon = Icons.swap_horiz;
    } else if (priceHigh && qualityLow) {
      // High price but low quality → Sell now before quality drops further
      recommendation = tr('sell_now_green');
      reasoning = trArgs('sell_now_small_reasoning', {
        'price': marketPrice.toInt().toString(),
      });
      risks = [tr('risk_low_rate_small'), tr('risk_quality_deteriorate')];
      recommendationColor = Colors.green;
      recommendationIcon = Icons.trending_up;
    } else if (largeQuantity && coldStorageAvailable) {
      // Large quantity + storage → Stagger sales
      recommendation = tr('stagger_sales');
      reasoning = trArgs('stagger_reasoning', {
        'qty': quantity.toInt().toString(),
      });
      risks = [tr('risk_cs_cost'), tr('risk_market_uncertainty')];
      recommendationColor = Colors.blue;
      recommendationIcon = Icons.timeline;
    } else {
      // Default moderate advice
      recommendation = tr('watch_market_sell');
      reasoning = trArgs('watch_market_reasoning', {
        'price': marketPrice.toInt().toString(),
      });
      risks = [tr('risk_wait_loss'), tr('risk_weather_quality')];
      recommendationColor = Colors.orange;
      recommendationIcon = Icons.visibility;
    }

    return {
      'recommendation': recommendation,
      'reasoning': reasoning,
      'risks': risks,
      'color': recommendationColor,
      'icon': recommendationIcon,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(
        title: Text(
          tr('ai_advisory_kishan'),
          style: GoogleFonts.notoSans(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header card
              _buildHeaderCard(),
              const SizedBox(height: 20),
              // Input fields
              _buildSectionTitle(tr('enter_details')),
              const SizedBox(height: 12),
              _buildQuantityField(),
              const SizedBox(height: 14),
              _buildQualitySelector(),
              const SizedBox(height: 14),
              _buildMarketPriceField(),
              const SizedBox(height: 14),
              _buildColdStorageSelector(),
              const SizedBox(height: 24),
              _buildGetAdviceButton(),
              const SizedBox(height: 20),
              if (_isLoading) _buildLoadingIndicator(),
              if (_advisoryResult != null && !_isLoading)
                _buildAdvisoryResult(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF004711), Color(0xFF1B7A2B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.psychology, color: Colors.white, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('ai_advisory_kishan_title'),
                  style: GoogleFonts.notoSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('ai_advisory_kishan_subtitle'),
                  style: GoogleFonts.notoSans(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.notoSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary(context),
      ),
    );
  }

  Widget _buildQuantityField() {
    return TextFormField(
      controller: _quantityController,
      keyboardType: TextInputType.number,
      style: GoogleFonts.notoSans(color: AppColors.textPrimary(context)),
      decoration: InputDecoration(
        labelText: tr('potato_quantity_quintal'),
        hintText: tr('enter_quantity_hint'),
        labelStyle: GoogleFonts.notoSans(
          color: AppColors.textSecondary(context),
        ),
        hintStyle: GoogleFonts.notoSans(color: AppColors.textHint(context)),
        prefixIcon: Icon(Icons.inventory_2, color: AppColors.primaryGreen),
        filled: true,
        fillColor: AppColors.inputFill(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.dividerColor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.dividerColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return tr('field_required');
        if (double.tryParse(v) == null || double.parse(v) <= 0)
          return tr('enter_valid_number');
        return null;
      },
    );
  }

  Widget _buildQualitySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('potato_quality_size'),
          style: GoogleFonts.notoSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: _qualityOptions.map((q) {
            final selected = _selectedQuality == q;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: q != _qualityOptions.last ? 8 : 0,
                ),
                child: ChoiceChip(
                  label: Text(
                    _qualityLabel(q),
                    style: GoogleFonts.notoSans(
                      fontSize: 13,
                      color: selected
                          ? Colors.white
                          : AppColors.textPrimary(context),
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  selected: selected,
                  selectedColor: AppColors.primaryGreen,
                  backgroundColor: AppColors.inputFill(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: selected
                          ? AppColors.primaryGreen
                          : AppColors.dividerColor(context),
                    ),
                  ),
                  onSelected: (_) => setState(() => _selectedQuality = q),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMarketPriceField() {
    return TextFormField(
      controller: _marketPriceController,
      keyboardType: TextInputType.number,
      style: GoogleFonts.notoSans(color: AppColors.textPrimary(context)),
      decoration: InputDecoration(
        labelText: tr('current_market_price'),
        hintText: tr('price_per_quintal_hint'),
        labelStyle: GoogleFonts.notoSans(
          color: AppColors.textSecondary(context),
        ),
        hintStyle: GoogleFonts.notoSans(color: AppColors.textHint(context)),
        prefixIcon: Icon(Icons.currency_rupee, color: AppColors.primaryGreen),
        filled: true,
        fillColor: AppColors.inputFill(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.dividerColor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.dividerColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return tr('field_required');
        if (double.tryParse(v) == null || double.parse(v) <= 0)
          return tr('enter_valid_number');
        return null;
      },
    );
  }

  Widget _buildColdStorageSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('cold_storage_available'),
          style: GoogleFonts.notoSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: _coldStorageOptions.map((opt) {
            final selected = _coldStorageAvailable == opt;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: opt == 'Yes' ? 8 : 0),
                child: ChoiceChip(
                  label: Text(
                    _coldStorageLabel(opt),
                    style: GoogleFonts.notoSans(
                      fontSize: 13,
                      color: selected
                          ? Colors.white
                          : AppColors.textPrimary(context),
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  selected: selected,
                  selectedColor: AppColors.primaryGreen,
                  backgroundColor: AppColors.inputFill(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: selected
                          ? AppColors.primaryGreen
                          : AppColors.dividerColor(context),
                    ),
                  ),
                  onSelected: (_) =>
                      setState(() => _coldStorageAvailable = opt),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGetAdviceButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _getAdvisory,
        icon: const Icon(Icons.auto_awesome, color: Colors.white),
        label: Text(
          tr('get_ai_advice'),
          style: GoogleFonts.notoSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 20),
          const CircularProgressIndicator(color: AppColors.primaryGreen),
          const SizedBox(height: 12),
          Text(
            tr('ai_thinking'),
            style: GoogleFonts.notoSans(
              fontSize: 14,
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvisoryResult() {
    final result = _advisoryResult!;
    final Color recColor = result['color'] as Color;
    final IconData recIcon = result['icon'] as IconData;
    final List<String> risks = result['risks'] as List<String>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recommendation card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: recColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: recColor.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(recIcon, color: recColor, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      result['recommendation'],
                      style: GoogleFonts.notoSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: recColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                result['reasoning'],
                style: GoogleFonts.notoSans(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Risks card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.red, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    tr('risks_to_consider'),
                    style: GoogleFonts.notoSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...risks.map(
                (risk) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '• ',
                        style: TextStyle(color: Colors.red, fontSize: 14),
                      ),
                      Expanded(
                        child: Text(
                          risk,
                          style: GoogleFonts.notoSans(
                            fontSize: 13,
                            color: AppColors.textSecondary(context),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Disclaimer
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant(context),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: AppColors.textHint(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('ai_disclaimer'),
                  style: GoogleFonts.notoSans(
                    fontSize: 11,
                    color: AppColors.textHint(context),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
