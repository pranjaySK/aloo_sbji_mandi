import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/utils/app_localizations.dart';

class VyapariAiAdvisoryScreen extends StatefulWidget {
  const VyapariAiAdvisoryScreen({super.key});

  @override
  State<VyapariAiAdvisoryScreen> createState() =>
      _VyapariAiAdvisoryScreenState();
}

class _VyapariAiAdvisoryScreenState extends State<VyapariAiAdvisoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sellerPriceController = TextEditingController();
  final _quantityController = TextEditingController();

  String _selectedQuality = ''; // Low / Average / Good
  String _localDemand = ''; // Low / Medium / High

  bool _isLoading = false;
  Map<String, dynamic>? _advisoryResult;

  final List<String> _qualityOptions = ['Low', 'Average', 'Good'];
  final List<String> _demandOptions = ['Low', 'Medium', 'High'];

  @override
  void dispose() {
    _sellerPriceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  String _qualityLabel(String val) {
    switch (val) {
      case 'Low':
        return tr('quality_low');
      case 'Average':
        return tr('quality_avg');
      case 'Good':
        return tr('quality_good');
      default:
        return val;
    }
  }

  String _demandLabel(String val) {
    switch (val) {
      case 'Low':
        return tr('demand_low');
      case 'Medium':
        return tr('demand_medium');
      case 'High':
        return tr('demand_high');
      default:
        return val;
    }
  }

  void _getAdvisory() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedQuality.isEmpty || _localDemand.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('fill_all_fields'))));
      return;
    }

    setState(() => _isLoading = true);

    Future.delayed(const Duration(seconds: 2), () {
      final result = _generateVyapariAdvisory(
        quality: _selectedQuality,
        sellerPrice: double.tryParse(_sellerPriceController.text) ?? 0,
        quantity: double.tryParse(_quantityController.text) ?? 0,
        localDemand: _localDemand,
      );
      setState(() {
        _advisoryResult = result;
        _isLoading = false;
      });
    });
  }

  Map<String, dynamic> _generateVyapariAdvisory({
    required String quality,
    required double sellerPrice,
    required double quantity,
    required String localDemand,
  }) {
    String recommendation;
    String reasoning;
    List<String> risks;
    Color recommendationColor;
    IconData recommendationIcon;

    final bool priceLow = sellerPrice < 800;
    final bool priceHigh = sellerPrice >= 1400;
    final bool priceMid = !priceLow && !priceHigh;
    final bool qualityGood = quality == 'Good';
    final bool qualityLow = quality == 'Low';
    final bool demandHigh = localDemand == 'High';
    final bool demandLow = localDemand == 'Low';
    final bool largeQty = quantity > 100;

    if (qualityGood && priceLow && demandHigh) {
      // Great deal: good quality, low seller price, high demand
      recommendation = tr('buy_now_advice');
      reasoning = trArgs('buy_now_reasoning', {
        'price': sellerPrice.toInt().toString(),
      });
      risks = [tr('risk_storage_cost_large'), tr('risk_demand_drop')];
      recommendationColor = Colors.green;
      recommendationIcon = Icons.shopping_cart;
    } else if (qualityGood && priceHigh && demandHigh) {
      // Good quality but expensive → Negotiate
      recommendation = tr('negotiate_price');
      reasoning = trArgs('negotiate_reasoning', {
        'price': sellerPrice.toInt().toString(),
        'low': (sellerPrice * 0.85).toInt().toString(),
        'high': (sellerPrice * 0.9).toInt().toString(),
      });
      risks = [tr('risk_thin_margin'), tr('risk_seller_sell_others')];
      recommendationColor = Colors.orange;
      recommendationIcon = Icons.handshake;
    } else if (qualityLow && demandLow) {
      // Poor quality + low demand → Wait
      recommendation = tr('wait_advice_red');
      reasoning = tr('wait_poor_quality_reasoning');
      risks = [tr('risk_no_buyers_low_quality'), tr('risk_stock_slow_sell')];
      recommendationColor = Colors.red;
      recommendationIcon = Icons.pause_circle;
    } else if (priceLow && demandHigh) {
      // Low price + high demand → Buy
      recommendation = tr('buy_advice');
      reasoning = trArgs('buy_low_demand_reasoning', {
        'price': sellerPrice.toInt().toString(),
      });
      risks = [tr('risk_verify_quality'), tr('risk_transport_cost')];
      recommendationColor = Colors.green;
      recommendationIcon = Icons.thumb_up;
    } else if (priceHigh && demandLow) {
      // High price + low demand → Don't buy
      recommendation = tr('avoid_buying');
      reasoning = trArgs('avoid_buying_reasoning', {
        'price': sellerPrice.toInt().toString(),
      });
      risks = [tr('risk_negative_margin'), tr('risk_stock_stuck')];
      recommendationColor = Colors.red;
      recommendationIcon = Icons.block;
    } else if (priceMid && qualityGood) {
      // Mid price + good quality → Negotiate slightly
      recommendation = tr('negotiate_and_buy');
      reasoning = trArgs('negotiate_buy_reasoning', {
        'price': sellerPrice.toInt().toString(),
      });
      risks = [tr('risk_price_fluctuate'), tr('risk_arrange_storage')];
      recommendationColor = Colors.orange;
      recommendationIcon = Icons.handshake;
    } else {
      // Default moderate
      recommendation = tr('buy_with_caution');
      reasoning = tr('buy_caution_reasoning');
      risks = [tr('risk_large_qty_risky'), tr('risk_check_quality_demand')];
      recommendationColor = Colors.orange;
      recommendationIcon = Icons.visibility;
    }

    // Margin estimate
    double estimatedSellingPrice = sellerPrice * 1.15; // 15% markup estimate
    if (demandHigh) estimatedSellingPrice = sellerPrice * 1.25;
    if (demandLow) estimatedSellingPrice = sellerPrice * 1.05;

    return {
      'recommendation': recommendation,
      'reasoning': reasoning,
      'risks': risks,
      'color': recommendationColor,
      'icon': recommendationIcon,
      'estimatedMargin':
          ((estimatedSellingPrice - sellerPrice) / sellerPrice * 100)
              .toStringAsFixed(1),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(
        title: Text(
          tr('ai_advisory_vyapari'),
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
              _buildHeaderCard(),
              const SizedBox(height: 20),
              _buildSectionTitle(tr('enter_details')),
              const SizedBox(height: 12),
              _buildQualitySelector(),
              const SizedBox(height: 14),
              _buildSellerPriceField(),
              const SizedBox(height: 14),
              _buildQuantityField(),
              const SizedBox(height: 14),
              _buildDemandSelector(),
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
          const Icon(Icons.analytics, color: Colors.white, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('ai_advisory_vyapari_title'),
                  style: GoogleFonts.notoSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('ai_advisory_vyapari_subtitle'),
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

  Widget _buildQualitySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('potato_quality'),
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

  Widget _buildSellerPriceField() {
    return TextFormField(
      controller: _sellerPriceController,
      keyboardType: TextInputType.number,
      style: GoogleFonts.notoSans(color: AppColors.textPrimary(context)),
      decoration: InputDecoration(
        labelText: tr('seller_price'),
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

  Widget _buildDemandSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('local_demand'),
          style: GoogleFonts.notoSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: _demandOptions.map((d) {
            final selected = _localDemand == d;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: d != _demandOptions.last ? 8 : 0,
                ),
                child: ChoiceChip(
                  label: Text(
                    _demandLabel(d),
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
                  onSelected: (_) => setState(() => _localDemand = d),
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
    final String margin = result['estimatedMargin'] as String;

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
        const SizedBox(height: 12),
        // Margin estimate mini card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primaryGreen.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.trending_up,
                color: AppColors.primaryGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '${tr('estimated_margin')}: ~$margin%',
                style: GoogleFonts.notoSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
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
