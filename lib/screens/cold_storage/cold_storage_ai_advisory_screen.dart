import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/utils/app_localizations.dart';

class ColdStorageAiAdvisoryScreen extends StatefulWidget {
  const ColdStorageAiAdvisoryScreen({super.key});

  @override
  State<ColdStorageAiAdvisoryScreen> createState() =>
      _ColdStorageAiAdvisoryScreenState();
}

class _ColdStorageAiAdvisoryScreenState
    extends State<ColdStorageAiAdvisoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _occupancyController = TextEditingController();

  String _incomingDemand = ''; // Low / Medium / High
  String _season = ''; // Peak / Normal / Off-season

  bool _isLoading = false;
  Map<String, dynamic>? _advisoryResult;

  final List<String> _demandOptions = ['Low', 'Medium', 'High'];
  final List<String> _seasonOptions = ['Peak', 'Normal', 'Off-season'];

  @override
  void dispose() {
    _occupancyController.dispose();
    super.dispose();
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

  String _seasonLabel(String val) {
    switch (val) {
      case 'Peak':
        return tr('season_peak');
      case 'Normal':
        return tr('season_normal');
      case 'Off-season':
        return tr('season_offseason');
      default:
        return val;
    }
  }

  void _getAdvisory() {
    if (!_formKey.currentState!.validate()) return;
    if (_incomingDemand.isEmpty || _season.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('fill_all_fields'))));
      return;
    }

    setState(() => _isLoading = true);

    Future.delayed(const Duration(seconds: 2), () {
      final result = _generateColdStorageAdvisory(
        occupancy: double.tryParse(_occupancyController.text) ?? 0,
        incomingDemand: _incomingDemand,
        season: _season,
      );
      setState(() {
        _advisoryResult = result;
        _isLoading = false;
      });
    });
  }

  Map<String, dynamic> _generateColdStorageAdvisory({
    required double occupancy,
    required String incomingDemand,
    required String season,
  }) {
    String recommendation;
    String reasoning;
    List<String> risks;
    Color recommendationColor;
    IconData recommendationIcon;
    String capacityStatus;

    final bool occupancyHigh = occupancy >= 85;
    final bool occupancyMid = occupancy >= 50 && occupancy < 85;
    final bool occupancyLow = occupancy < 50;
    final bool demandHigh = incomingDemand == 'High';
    final bool demandLow = incomingDemand == 'Low';
    final bool isPeak = season == 'Peak';
    final bool isOffSeason = season == 'Off-season';

    // Capacity status
    if (occupancyHigh) {
      capacityStatus = tr('near_full_capacity');
    } else if (occupancyMid) {
      capacityStatus = tr('balanced_capacity');
    } else {
      capacityStatus = tr('plenty_space');
    }

    if (occupancyHigh && demandHigh && isPeak) {
      // Full + high demand + peak → Be very cautious
      recommendation = tr('be_cautious');
      reasoning = trArgs('cs_cautious_reasoning', {
        'pct': occupancy.toInt().toString(),
      });
      risks = [tr('risk_overload_temp'), tr('risk_spoilage_increase')];
      recommendationColor = Colors.red;
      recommendationIcon = Icons.warning;
    } else if (occupancyHigh && demandHigh && !isPeak) {
      // Full + high demand + not peak → Cautious but can rotate
      recommendation = tr('rotate_stock');
      reasoning = trArgs('cs_rotate_reasoning', {
        'pct': occupancy.toInt().toString(),
      });
      risks = [tr('risk_old_stock_spoil'), tr('risk_storage_mgmt')];
      recommendationColor = Colors.orange;
      recommendationIcon = Icons.swap_vert;
    } else if (occupancyLow && demandHigh && isPeak) {
      // Low occupancy + high demand + peak → Accept more
      recommendation = tr('accept_more_stock');
      reasoning = trArgs('cs_accept_more_reasoning', {
        'pct': occupancy.toInt().toString(),
      });
      risks = [tr('risk_electricity_increase'), tr('risk_quality_check')];
      recommendationColor = Colors.green;
      recommendationIcon = Icons.add_circle;
    } else if (occupancyLow && demandLow && isOffSeason) {
      // Low everything → Offer discounts
      recommendation = tr('offer_rental_discounts');
      reasoning = trArgs('cs_discount_reasoning', {
        'pct': occupancy.toInt().toString(),
      });
      risks = [tr('risk_low_margin_work'), tr('risk_maintenance_continue')];
      recommendationColor = Colors.blue;
      recommendationIcon = Icons.local_offer;
    } else if (occupancyMid && demandHigh) {
      // Balanced + high demand → Accept strategically
      recommendation = tr('accept_new_stock');
      reasoning = trArgs('cs_accept_new_reasoning', {
        'pct': occupancy.toInt().toString(),
      });
      risks = [tr('risk_dont_exceed_80'), tr('risk_temp_monitoring')];
      recommendationColor = Colors.green;
      recommendationIcon = Icons.check_circle;
    } else if (occupancyHigh && demandLow) {
      // High occupancy + low demand → Clear stock
      recommendation = tr('clear_old_stock');
      reasoning = trArgs('cs_clear_stock_reasoning', {
        'pct': occupancy.toInt().toString(),
      });
      risks = [tr('risk_high_spoilage'), tr('risk_high_electricity')];
      recommendationColor = Colors.red;
      recommendationIcon = Icons.output;
    } else {
      // Default moderate advice
      recommendation = tr('continue_normal');
      reasoning = trArgs('cs_normal_reasoning', {
        'pct': occupancy.toInt().toString(),
      });
      risks = [tr('risk_demand_season_change'), tr('risk_power_cut_prep')];
      recommendationColor = Colors.orange;
      recommendationIcon = Icons.visibility;
    }

    return {
      'recommendation': recommendation,
      'reasoning': reasoning,
      'risks': risks,
      'color': recommendationColor,
      'icon': recommendationIcon,
      'capacityStatus': capacityStatus,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(
        title: Text(
          tr('ai_advisory_cold_storage'),
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
              _buildOccupancyField(),
              const SizedBox(height: 14),
              _buildDemandSelector(),
              const SizedBox(height: 14),
              _buildSeasonSelector(),
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
          const Icon(Icons.ac_unit, color: Colors.white, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('ai_advisory_cs_title'),
                  style: GoogleFonts.notoSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('ai_advisory_cs_subtitle'),
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

  Widget _buildOccupancyField() {
    return TextFormField(
      controller: _occupancyController,
      keyboardType: TextInputType.number,
      style: GoogleFonts.notoSans(color: AppColors.textPrimary(context)),
      decoration: InputDecoration(
        labelText: tr('current_occupancy'),
        hintText: tr('occupancy_hint'),
        labelStyle: GoogleFonts.notoSans(
          color: AppColors.textSecondary(context),
        ),
        hintStyle: GoogleFonts.notoSans(color: AppColors.textHint(context)),
        prefixIcon: Icon(Icons.warehouse, color: AppColors.primaryGreen),
        suffixText: '%',
        suffixStyle: GoogleFonts.notoSans(
          color: AppColors.textPrimary(context),
          fontWeight: FontWeight.w600,
        ),
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
        final val = double.tryParse(v);
        if (val == null || val < 0 || val > 100)
          return tr('enter_valid_percentage');
        return null;
      },
    );
  }

  Widget _buildDemandSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('incoming_demand'),
          style: GoogleFonts.notoSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: _demandOptions.map((d) {
            final selected = _incomingDemand == d;
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
                  onSelected: (_) => setState(() => _incomingDemand = d),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSeasonSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('current_season'),
          style: GoogleFonts.notoSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: _seasonOptions.map((s) {
            final selected = _season == s;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: s != _seasonOptions.last ? 8 : 0,
                ),
                child: ChoiceChip(
                  label: Text(
                    _seasonLabel(s),
                    style: GoogleFonts.notoSans(
                      fontSize: 12,
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
                  onSelected: (_) => setState(() => _season = s),
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
    final String capStatus = result['capacityStatus'] as String;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Capacity status mini card
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
                Icons.storage,
                color: AppColors.primaryGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '${tr('capacity_status')}: $capStatus',
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
