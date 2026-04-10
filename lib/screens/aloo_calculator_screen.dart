import 'package:aloo_sbji_mandi/core/service/aloo_calculator_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// role: 'farmer' | 'vyapari' | 'cold_storage'
class AlooCalculatorScreen extends StatefulWidget {
  final String role;
  const AlooCalculatorScreen({super.key, required this.role});

  @override
  State<AlooCalculatorScreen> createState() => _AlooCalculatorScreenState();
}

class _AlooCalculatorScreenState extends State<AlooCalculatorScreen> {
  bool get isHindi => AppLocalizations.isHindi;
  final _formKey = GlobalKey<FormState>();

  // ── Farmer — Land & Yield ───
  final _landAreaController = TextEditingController();
  String _landUnit = 'ha'; // 'ha' or 'acre'
  final _yieldPerHaController = TextEditingController();

  // ── Farmer — Prices ───
  final _currentPriceController = TextEditingController();
  final _futurePriceController = TextEditingController();

  // ── Farmer — Cold Storage ───
  final _storageCostController = TextEditingController();
  final _storageDurationController = TextEditingController();

  // ── Farmer — Production Costs ───
  final _laborCostController = TextEditingController();
  final _seedCostController = TextEditingController();
  final _fertilizerCostController = TextEditingController();
  final _transportCostController = TextEditingController();

  // ── Vyapari ──
  final _quantityController = TextEditingController();
  final _buyPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();

  // ── Cold Storage ──
  final _chargeController = TextEditingController();
  final _durationController = TextEditingController();
  String _durationUnit = 'months';

  // ── Result state ──
  bool _hasResult = false;
  KisanDecisionResult? _kisanResult;
  VyapariCalcResult? _vyapariResult;
  ColdStorageCalcResult? _coldStorageResult;
  // ScrollController to auto-scroll to results
  final _scrollController = ScrollController();
  final _resultsKey = GlobalKey();

  @override
  void dispose() {
    _landAreaController.dispose();
    _yieldPerHaController.dispose();
    _currentPriceController.dispose();
    _futurePriceController.dispose();
    _storageCostController.dispose();
    _storageDurationController.dispose();
    _laborCostController.dispose();
    _seedCostController.dispose();
    _fertilizerCostController.dispose();
    _transportCostController.dispose();
    _quantityController.dispose();
    _buyPriceController.dispose();
    _sellPriceController.dispose();
    _chargeController.dispose();
    _durationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CALCULATE
  // ═══════════════════════════════════════════════════════════════════════════

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _hasResult = false;
      _kisanResult = null;
      _vyapariResult = null;
      _coldStorageResult = null;
    });

    switch (widget.role) {
      case 'farmer':
        final landArea = double.parse(_landAreaController.text.trim());
        final yieldPerHa = double.parse(_yieldPerHaController.text.trim());
        final currentPrice = double.parse(_currentPriceController.text.trim());
        final futurePrice = double.parse(_futurePriceController.text.trim());
        final storageCost = double.parse(_storageCostController.text.trim());
        final storageDuration = int.parse(
          _storageDurationController.text.trim(),
        );
        final labor = double.tryParse(_laborCostController.text.trim()) ?? 0;
        final seed = double.tryParse(_seedCostController.text.trim()) ?? 0;
        final fertilizer =
            double.tryParse(_fertilizerCostController.text.trim()) ?? 0;
        final transport =
            double.tryParse(_transportCostController.text.trim()) ?? 0;

        _kisanResult = AlooCalculatorService.calculateKisanDecision(
          landArea: landArea,
          landUnit: _landUnit,
          yieldPerHa: yieldPerHa,
          currentPricePerKg: currentPrice,
          expectedFuturePricePerKg: futurePrice,
          storageCostPerKgPerMonth: storageCost,
          storageDurationMonths: storageDuration,
          laborCostPerHa: labor,
          seedCostPerHa: seed,
          fertilizerCostPerHa: fertilizer,
          transportCostPerHa: transport,
        );
        break;
      case 'vyapari':
        final qty = double.parse(_quantityController.text.trim());
        final buy = double.parse(_buyPriceController.text.trim());
        final sell = double.parse(_sellPriceController.text.trim());
        _vyapariResult = AlooCalculatorService.calculateVyapari(
          quantityKg: qty,
          buyingPricePerKg: buy,
          sellingPricePerKg: sell,
        );
        break;
      case 'cold_storage':
        final qty = double.parse(_quantityController.text.trim());
        final charge = double.parse(_chargeController.text.trim());
        final dur = int.parse(_durationController.text.trim());
        _coldStorageResult = AlooCalculatorService.calculateColdStorage(
          quantityKg: qty,
          chargePerKg: charge,
          duration: dur,
          durationUnit: _durationUnit,
        );
        break;
    }

    setState(() => _hasResult = true);

    // Auto-scroll to results after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_resultsKey.currentContext != null) {
        Scrollable.ensureVisible(
          _resultsKey.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _reset() {
    if (widget.role == 'farmer') {
      _landAreaController.clear();
      _yieldPerHaController.clear();
      _currentPriceController.clear();
      _futurePriceController.clear();
      _storageCostController.clear();
      _storageDurationController.clear();
      _laborCostController.clear();
      _seedCostController.clear();
      _fertilizerCostController.clear();
      _transportCostController.clear();
      _landUnit = 'ha';
    } else {
      _quantityController.clear();
      _buyPriceController.clear();
      _sellPriceController.clear();
      _chargeController.clear();
      _durationController.clear();
      _durationUnit = 'months';
    }
    _hasResult = false;
    _kisanResult = null;
    _vyapariResult = null;
    _coldStorageResult = null;
    setState(() {});
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: _roleColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _title,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _reset,
            tooltip: tr('reset'),
          ),
          if (widget.role == 'farmer')
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white),
              onPressed: _showFormulaInfo,
              tooltip: tr('formulas'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 20),
              _buildInputFields(),
              const SizedBox(height: 20),
              _buildCalcButton(),
              if (_hasResult) ...[
                const SizedBox(height: 24),
                Container(key: _resultsKey, child: _buildResultCard()),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  FORMULA INFO DIALOG
  // ═══════════════════════════════════════════════════════════════════════════

  void _showFormulaInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.functions, color: _roleColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tr('calc_formulas'),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _formulaItem(
                tr('calc_total_yield'),
                tr('calc_total_yield_formula'),
              ),
              _formulaItem(
                tr('calc_production_cost'),
                tr('calc_production_cost_formula'),
              ),
              _formulaItem(
                tr('calc_sell_now_revenue'),
                tr('calc_sell_now_revenue_formula'),
              ),
              _formulaItem(
                tr('calc_storage_cost'),
                tr('calc_storage_cost_formula'),
              ),
              _formulaItem(
                tr('calc_break_even_price'),
                tr('calc_break_even_formula'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('ok'), style: TextStyle(color: _roleColor)),
          ),
        ],
      ),
    );
  }

  Widget _formulaItem(String title, String formula) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              formula,
              style: GoogleFonts.robotoMono(
                fontSize: 11,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  ROLE HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  String get _title {
    switch (widget.role) {
      case 'farmer':
        return tr('farmer_calculator');
      case 'vyapari':
        return tr('vyapari_calculator');
      case 'cold_storage':
        return tr('cold_storage_calculator');
      default:
        return '🥔 Aloo Calculator';
    }
  }

  Color get _roleColor {
    switch (widget.role) {
      case 'farmer':
        return const Color(0xFF2E7D32); // deep green
      case 'vyapari':
        return const Color(0xFFFF9800);
      case 'cold_storage':
        return const Color(0xFF2196F3);
      default:
        return AppColors.primaryGreen;
    }
  }

  IconData get _roleIcon {
    switch (widget.role) {
      case 'farmer':
        return Icons.agriculture;
      case 'vyapari':
        return Icons.storefront;
      case 'cold_storage':
        return Icons.ac_unit;
      default:
        return Icons.calculate;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHeaderCard() {
    String subtitle;
    switch (widget.role) {
      case 'farmer':
        subtitle = tr('calc_farmer_subtitle');
        break;
      case 'vyapari':
        subtitle = tr('calc_vyapari_subtitle');
        break;
      case 'cold_storage':
        subtitle = tr('calc_cs_subtitle');
        break;
      default:
        subtitle = '';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_roleColor, _roleColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _roleColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_roleIcon, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              subtitle,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  INPUT FIELDS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildInputFields() {
    switch (widget.role) {
      case 'farmer':
        return _farmerInputs();
      case 'vyapari':
        return _vyapariInputs();
      case 'cold_storage':
        return _coldStorageInputs();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── FARMER: 4-Section Sell-vs-Store Decision Input ────────────────────────

  Widget _farmerInputs() {
    return Column(
      children: [
        // ─── Section 1: Land & Yield ───
        _sectionCard(
          icon: Icons.landscape,
          emoji: '🌿',
          title: tr('calc_land_yield'),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _inputField(
                    controller: _landAreaController,
                    label: tr('calc_land_area'),
                    suffix: _landUnit == 'ha'
                        ? tr('calc_hectare')
                        : tr('calc_acre'),
                    icon: Icons.square_foot,
                    isDecimal: true,
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    children: [
                      Text(
                        tr('calc_unit'),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      ToggleButtons(
                        isSelected: [_landUnit == 'ha', _landUnit == 'acre'],
                        onPressed: (i) =>
                            setState(() => _landUnit = i == 0 ? 'ha' : 'acre'),
                        borderRadius: BorderRadius.circular(8),
                        selectedColor: Colors.white,
                        fillColor: _roleColor,
                        constraints: const BoxConstraints(
                          minHeight: 36,
                          minWidth: 50,
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              tr('calc_ha_short'),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              tr('calc_acre'),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _inputField(
              controller: _yieldPerHaController,
              label: tr('calc_yield_per_ha'),
              suffix: tr('calc_tons'),
              icon: Icons.grass,
              isDecimal: true,
              helperText: tr('calc_avg_yield_hint'),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ─── Section 2: Prices ───
        _sectionCard(
          icon: Icons.currency_rupee,
          emoji: '💰',
          title: tr('calc_prices'),
          children: [
            Column(
              children: [
                _inputField(
                  controller: _currentPriceController,
                  label: tr('calc_current_price'),
                  prefix: '₹',
                  suffix: '/kg',
                  icon: Icons.price_check,
                  isDecimal: true,
                ),
                const SizedBox(height: 12),
                _inputField(
                  controller: _futurePriceController,
                  label: tr('calc_expected_price'),
                  prefix: '₹',
                  suffix: '/kg',
                  icon: Icons.trending_up,
                  isDecimal: true,
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ─── Section 3: Cold Storage ───
        _sectionCard(
          icon: Icons.ac_unit,
          emoji: '❄️',
          title: tr('calc_cold_storage'),
          children: [
            Column(
              children: [
                _inputField(
                  controller: _storageCostController,
                  label: tr('calc_storage_charge_label'),
                  prefix: '₹',
                  suffix: tr('calc_per_kg_month'),
                  icon: Icons.payments,
                  isDecimal: true,
                ),
                const SizedBox(height: 12),
                _inputField(
                  controller: _storageDurationController,
                  label: tr('calc_duration'),
                  suffix: tr('calc_months'),
                  icon: Icons.access_time,
                  isInteger: true,
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ─── Section 4: Production Costs (optional) ───
        _sectionCard(
          icon: Icons.receipt_long,
          emoji: '📊',
          title: tr('calc_production_costs'),
          subtitle: tr('calc_optional_per_ha'),
          children: [
            Row(
              children: [
                Expanded(
                  child: _inputField(
                    controller: _laborCostController,
                    label: tr('calc_labor'),
                    prefix: '₹',
                    icon: Icons.people,
                    isDecimal: true,
                    isOptional: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _inputField(
                    controller: _seedCostController,
                    label: tr('calc_seeds'),
                    prefix: '₹',
                    icon: Icons.spa,
                    isDecimal: true,
                    isOptional: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _inputField(
                    controller: _fertilizerCostController,
                    label: tr('calc_fertilizer'),
                    prefix: '₹',
                    icon: Icons.science,
                    isDecimal: true,
                    isOptional: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _inputField(
                    controller: _transportCostController,
                    label: tr('calc_transport'),
                    prefix: '₹',
                    icon: Icons.local_shipping,
                    isDecimal: true,
                    isOptional: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// Section card wrapper with icon, emoji, title
  Widget _sectionCard({
    required IconData icon,
    required String emoji,
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _roleColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: _roleColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$emoji $title',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _vyapariInputs() {
    return Column(
      children: [
        _inputField(
          controller: _quantityController,
          label: tr('potato_quantity_label'),
          suffix: 'kg',
          icon: Icons.scale,
        ),
        const SizedBox(height: 16),
        _inputField(
          controller: _buyPriceController,
          label: tr('buying_price_per_kg'),
          prefix: '₹',
          suffix: '/kg',
          icon: Icons.shopping_cart,
        ),
        const SizedBox(height: 16),
        _inputField(
          controller: _sellPriceController,
          label: tr('expected_selling_price'),
          prefix: '₹',
          suffix: '/kg',
          icon: Icons.sell,
        ),
      ],
    );
  }

  Widget _coldStorageInputs() {
    return Column(
      children: [
        _inputField(
          controller: _quantityController,
          label: tr('quantity_stored'),
          suffix: 'kg',
          icon: Icons.inventory_2,
        ),
        const SizedBox(height: 16),
        _inputField(
          controller: _chargeController,
          label: trArgs('calc_storage_charge_per_kg', {
            'unit': _durationUnitLabel,
          }),
          prefix: '₹',
          icon: Icons.payments,
          isDecimal: true,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _inputField(
                controller: _durationController,
                label: tr('duration_label'),
                suffix: _durationUnitLabel,
                icon: Icons.access_time,
                isInteger: true,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                Text(
                  tr('unit_label'),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                ToggleButtons(
                  isSelected: [
                    _durationUnit == 'days',
                    _durationUnit == 'months',
                  ],
                  onPressed: (i) => setState(
                    () => _durationUnit = i == 0 ? 'days' : 'months',
                  ),
                  borderRadius: BorderRadius.circular(8),
                  selectedColor: Colors.white,
                  fillColor: _roleColor,
                  constraints: const BoxConstraints(
                    minHeight: 36,
                    minWidth: 56,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        tr('day_label'),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        tr('month_label'),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  String get _durationUnitLabel {
    if (_durationUnit == 'months') return tr('month_label');
    return tr('day_label');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CALCULATE BUTTON
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCalcButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _calculate,
        style: ElevatedButton.styleFrom(
          backgroundColor: _roleColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calculate, color: Colors.white, size: 26),
            const SizedBox(width: 10),
            Text(
              tr('calculate'),
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  RESULT CARDS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildResultCard() {
    switch (widget.role) {
      case 'farmer':
        return _kisanDecisionResultCard();
      case 'vyapari':
        return _vyapariResultCard();
      case 'cold_storage':
        return _coldStorageResultCard();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── KISAN SELL-NOW vs STORE DECISION RESULT ───────────────────────────────

  Widget _kisanDecisionResultCard() {
    final r = _kisanResult!;

    return Column(
      children: [
        // ─── Results Header ───
        _resultContainer(
          icon: Icons.bar_chart,
          title: tr('calc_results'),
          children: [
            // Total Yield
            _resultRow(
              icon: Icons.grass,
              label: tr('calc_total_yield'),
              value: '${formatIndian(r.totalYieldKg)} kg',
              valueColor: _roleColor,
            ),
            if (r.totalProductionCost > 0) ...[
              const SizedBox(height: 8),
              _resultRow(
                icon: Icons.receipt_long,
                label: tr('calc_production_cost'),
                value: '₹${formatIndian(r.totalProductionCost)}',
                valueColor: Colors.orange[800]!,
              ),
            ],
          ],
        ),

        const SizedBox(height: 16),

        // ─── Side-by-Side Comparison ───
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sell Now Card
            Expanded(
              child: _optionCard(
                title: tr('calc_sell_now'),
                icon: Icons.sell,
                gradientColors: [
                  const Color(0xFF43A047),
                  const Color(0xFF2E7D32),
                ],
                revenue: r.sellNowRevenue,
                cost: r.totalProductionCost,
                netProfit: r.sellNowNetProfit,
                isBetter: !r.isStoreBetter,
              ),
            ),
            const SizedBox(width: 12),
            // Store & Sell Card
            Expanded(
              child: _optionCard(
                title: tr('calc_store_sell'),
                icon: Icons.warehouse,
                gradientColors: [
                  const Color(0xFF1E88E5),
                  const Color(0xFF1565C0),
                ],
                revenue: r.futureSellingRevenue,
                cost: r.totalProductionCost + r.totalStorageCost,
                netProfit: r.storeAndSellNetProfit,
                isBetter: r.isStoreBetter,
                storageCost: r.totalStorageCost,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ─── Break-even & Recommendation ───
        _resultContainer(
          icon: Icons.lightbulb,
          title: tr('calc_recommendation'),
          children: [
            // Break-even price
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.balance, color: Colors.amber[800], size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('calc_break_even_price'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${formatIndian(r.breakEvenFuturePrice)}/kg',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[900],
                          ),
                        ),
                        Text(
                          tr('calc_break_even_desc'),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Profit difference
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: r.isStoreBetter
                      ? [const Color(0xFF1565C0), const Color(0xFF0D47A1)]
                      : [const Color(0xFF2E7D32), const Color(0xFF1B5E20)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    r.isStoreBetter ? Icons.warehouse : Icons.sell,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    r.isStoreBetter
                        ? tr('calc_storing_better')
                        : tr('calc_sell_now_better_title'),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '₹${formatIndian(r.profitDifference.abs())} ${tr('calc_extra_profit')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    r.recommendation(isHindi: isHindi),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ─── Detailed Breakdown ───
        _resultContainer(
          icon: Icons.list_alt,
          title: tr('calc_detailed_breakdown'),
          children: [
            _breakdownRow(
              tr('calc_land'),
              '${formatIndian(r.landArea)} ${r.landUnit == "ha" ? tr('calc_hectare_unit') : tr('calc_acre')}',
            ),
            _breakdownRow(
              tr('calc_yield_ha'),
              '${formatIndian(r.yieldPerHa)} ${tr('calc_tons')}',
            ),
            _breakdownRow(
              tr('calc_total_yield'),
              '${formatIndian(r.totalYieldKg)} kg',
            ),
            Divider(color: Colors.grey.withOpacity(0.2)),
            _breakdownRow(
              tr('calc_current_price'),
              '₹${formatIndian(r.currentPricePerKg)}/kg',
            ),
            _breakdownRow(
              tr('calc_expected_price'),
              '₹${formatIndian(r.expectedFuturePricePerKg)}/kg',
            ),
            _breakdownRow(
              tr('calc_storage_charge'),
              '₹${formatIndian(r.storageCostPerKgPerMonth)}/kg/${tr('calc_month_short')}',
            ),
            _breakdownRow(
              tr('calc_duration'),
              '${r.storageDurationMonths} ${tr('calc_months_lower')}',
            ),
            if (r.totalProductionCost > 0) ...[
              Divider(color: Colors.grey.withOpacity(0.2)),
              _breakdownRow(
                tr('calc_labor'),
                '₹${formatIndian(r.laborCostPerHa)}/ha',
              ),
              _breakdownRow(
                tr('calc_seeds'),
                '₹${formatIndian(r.seedCostPerHa)}/ha',
              ),
              _breakdownRow(
                tr('calc_fertilizer_short'),
                '₹${formatIndian(r.fertilizerCostPerHa)}/ha',
              ),
              _breakdownRow(
                tr('calc_transport'),
                '₹${formatIndian(r.transportCostPerHa)}/ha',
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// One of the two comparison cards (Sell Now / Store & Sell)
  Widget _optionCard({
    required String title,
    required IconData icon,
    required List<Color> gradientColors,
    required double revenue,
    required double cost,
    required double netProfit,
    required bool isBetter,
    double? storageCost,
  }) {
    final isPositive = netProfit >= 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(14),
        border: isBetter
            ? Border.all(color: gradientColors[0], width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Title bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isBetter)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '⭐ ${tr('calc_better')}',
                      style: const TextStyle(
                        color: Colors.yellowAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Revenue
          _miniRow(
            tr('calc_revenue'),
            '₹${formatIndian(revenue)}',
            Colors.blue[700]!,
          ),
          if (cost > 0)
            _miniRow(
              tr('calc_cost'),
              '-₹${formatIndian(cost)}',
              Colors.red[600]!,
            ),
          if (storageCost != null && storageCost > 0)
            _miniRow(
              tr('calc_storage'),
              '-₹${formatIndian(storageCost)}',
              Colors.orange[700]!,
            ),

          Divider(color: Colors.grey.withOpacity(0.2), height: 16),

          // Net Profit
          Text(
            tr('calc_net_profit'),
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '₹${formatIndian(netProfit)}',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isPositive ? Colors.green[700] : Colors.red[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _roleColor.withOpacity(0.7)),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  // ── VYAPARI RESULT ────────────────────────────────────────────────────────

  Widget _vyapariResultCard() {
    final r = _vyapariResult!;
    final isProfitable = r.isProfit;

    return _resultContainer(
      children: [
        // Calculation lines
        _calcLine(
          trArgs('calc_buy_line', {
            'qty': formatIndian(r.quantityKg),
            'price': formatIndian(r.buyingPricePerKg),
            'total': formatIndian(r.totalBuyingCost),
          }),
        ),
        const SizedBox(height: 6),
        _calcLine(
          trArgs('calc_sell_line', {
            'qty': formatIndian(r.quantityKg),
            'price': formatIndian(r.sellingPricePerKg),
            'total': formatIndian(r.totalSellingValue),
          }),
        ),
        const SizedBox(height: 20),

        // Row: Buying Cost | Selling Value
        Row(
          children: [
            Expanded(
              child: _infoBox(
                label: tr('total_buying_cost'),
                value: '₹${formatIndian(r.totalBuyingCost)}',
                color: Colors.red[700]!,
                bgColor: Colors.red.withOpacity(0.06),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _infoBox(
                label: tr('total_selling_value'),
                value: '₹${formatIndian(r.totalSellingValue)}',
                color: Colors.blue[700]!,
                bgColor: Colors.blue.withOpacity(0.06),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Profit / Loss — big card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isProfitable
                  ? [Colors.green[600]!, Colors.green[800]!]
                  : [Colors.red[600]!, Colors.red[800]!],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: (isProfitable ? Colors.green : Colors.red).withOpacity(
                  0.3,
                ),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                isProfitable ? Icons.trending_up : Icons.trending_down,
                color: Colors.white,
                size: 36,
              ),
              const SizedBox(height: 8),
              Text(
                isProfitable ? tr('profit_label') : tr('loss_label'),
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '₹${formatIndian(r.profitOrLoss.abs())}',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isProfitable ? tr('deal_profitable') : tr('deal_risky'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── COLD STORAGE RESULT ───────────────────────────────────────────────────

  Widget _coldStorageResultCard() {
    final r = _coldStorageResult!;

    return _resultContainer(
      children: [
        _calcLine(
          '${formatIndian(r.quantityKg)} kg  ×  ₹${formatIndian(r.chargePerKg)}/kg  ×  ${r.duration} ${r.durationLabel()}',
        ),
        const SizedBox(height: 20),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: _roleColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                tr('total_storage_income'),
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 6),
              Text(
                '₹${formatIndian(r.totalIncome)}',
                style: GoogleFonts.inter(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: _roleColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _breakdownRow(
          tr('quantity_stored'),
          '${formatIndian(r.quantityKg)} kg',
        ),
        _breakdownRow(
          trArgs('calc_charge_per_kg_unit', {'unit': _durationUnitLabel}),
          '₹${formatIndian(r.chargePerKg)}',
        ),
        _breakdownRow(tr('duration_label'), r.durationLabel()),

        const SizedBox(height: 14),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  trArgs('storage_income_summary', {
                    'qty': formatIndian(r.quantityKg),
                    'duration': r.durationLabel(),
                    'income': formatIndian(r.totalIncome),
                  }),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue[800],
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  REUSABLE WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _resultContainer({
    required List<Widget> children,
    IconData? icon,
    String? title,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon ?? Icons.analytics, color: _roleColor, size: 22),
              const SizedBox(width: 8),
              Text(
                title ?? tr('result'),
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ],
          ),
          Divider(color: Colors.grey.withOpacity(0.2)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _calcLine(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.robotoMono(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary(context),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _infoBox({
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(
            value,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    String? prefix,
    String? suffix,
    required IconData icon,
    bool isDecimal = false,
    bool isInteger = false,
    bool isOptional = false,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(
        decimal: isDecimal || !isInteger,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          isInteger ? RegExp(r'[0-9]') : RegExp(r'[0-9.]'),
        ),
      ],
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
        suffix: suffix != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _roleColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  suffix,
                  style: TextStyle(
                    color: _roleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        helperText: helperText,
        helperStyle: TextStyle(fontSize: 11, color: Colors.grey[500]),
        prefixIcon: Icon(icon, color: _roleColor, size: 20),
        filled: true,
        fillColor: AppColors.inputFill(context),
        contentPadding: const EdgeInsets.only(
          left: 12,
          right: 12,
          top: 14,
          bottom: 14,
        ),
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
          borderSide: BorderSide(color: _roleColor, width: 2),
        ),
      ),
      validator: isOptional
          ? null // optional fields skip validation
          : (v) {
              if (v == null || v.trim().isEmpty) {
                return tr('required_field');
              }
              final n = double.tryParse(v.trim());
              if (n == null || n <= 0) {
                return tr('enter_number_gt_0');
              }
              return null;
            },
    );
  }
}
