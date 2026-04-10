/// Aloo Calculator Service — Role-Specific Calculations
///
/// FARMER:       Sell-Now vs Store-and-Sell-Later decision engine
/// VYAPARI:      total cost, total revenue, profit/loss
/// COLD STORAGE: quantity × charge × duration = total storage income
library;

import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';

// ─── Kisan Decision Result (Sell Now vs Store & Sell Later) ─────────────────

class KisanDecisionResult {
  // ── Inputs echoed back ──
  final double landArea; // in hectares (converted from acres if needed)
  final String landUnit; // 'ha' or 'acre'
  final double yieldPerHa; // tons
  final double currentPricePerKg;
  final double expectedFuturePricePerKg;
  final double storageCostPerKgPerMonth;
  final int storageDurationMonths;
  final double laborCostPerHa;
  final double seedCostPerHa;
  final double fertilizerCostPerHa;
  final double transportCostPerHa;

  // ── Computed ──
  final double totalYieldKg;
  final double totalProductionCost;
  final double sellNowRevenue;
  final double sellNowNetProfit;
  final double totalStorageCost;
  final double futureSellingRevenue;
  final double storeAndSellNetProfit;
  final double breakEvenFuturePrice;

  KisanDecisionResult({
    required this.landArea,
    required this.landUnit,
    required this.yieldPerHa,
    required this.currentPricePerKg,
    required this.expectedFuturePricePerKg,
    required this.storageCostPerKgPerMonth,
    required this.storageDurationMonths,
    required this.laborCostPerHa,
    required this.seedCostPerHa,
    required this.fertilizerCostPerHa,
    required this.transportCostPerHa,
    required this.totalYieldKg,
    required this.totalProductionCost,
    required this.sellNowRevenue,
    required this.sellNowNetProfit,
    required this.totalStorageCost,
    required this.futureSellingRevenue,
    required this.storeAndSellNetProfit,
    required this.breakEvenFuturePrice,
  });

  /// true if storing is more profitable than selling now
  bool get isStoreBetter => storeAndSellNetProfit > sellNowNetProfit;

  /// difference between the two options (positive = store is better)
  double get profitDifference => storeAndSellNetProfit - sellNowNetProfit;

  String recommendation({bool isHindi = false}) {
    if (isStoreBetter) {
      return trArgs('calc_store_better', {
        'amount': formatIndian(profitDifference.abs()),
      });
    } else {
      return trArgs('calc_sell_now_better', {
        'amount': formatIndian(profitDifference.abs()),
      });
    }
  }
}

// ─── Legacy Farmer Result (kept for backward compat) ────────────────────────

class FarmerCalcResult {
  final double quantityKg;
  final double pricePerKg;
  final double totalAmount;

  FarmerCalcResult({
    required this.quantityKg,
    required this.pricePerKg,
    required this.totalAmount,
  });

  String explanation({bool isHindi = false}) {
    return trArgs('calc_farmer_explanation', {
      'qty': _fmtNum(quantityKg),
      'price': _fmtNum(pricePerKg),
      'total': formatIndian(totalAmount),
    });
  }
}

// ─── Vyapari Result ─────────────────────────────────────────────────────────

class VyapariCalcResult {
  final double quantityKg;
  final double buyingPricePerKg;
  final double sellingPricePerKg;
  final double totalBuyingCost;
  final double totalSellingValue;
  final double profitOrLoss; // positive = profit, negative = loss

  VyapariCalcResult({
    required this.quantityKg,
    required this.buyingPricePerKg,
    required this.sellingPricePerKg,
    required this.totalBuyingCost,
    required this.totalSellingValue,
    required this.profitOrLoss,
  });

  bool get isProfit => profitOrLoss >= 0;
}

// ─── Cold Storage Result ────────────────────────────────────────────────────

class ColdStorageCalcResult {
  final double quantityKg;
  final double chargePerKg;
  final int duration;
  final String durationUnit; // 'days' or 'months'
  final double totalIncome;

  ColdStorageCalcResult({
    required this.quantityKg,
    required this.chargePerKg,
    required this.duration,
    required this.durationUnit,
    required this.totalIncome,
  });

  String durationLabel() {
    if (durationUnit == 'months') {
      return trArgs('duration_months', {'duration': duration.toString()});
    }
    return trArgs('duration_days_label', {'duration': duration.toString()});
  }
}

// ─── Service ────────────────────────────────────────────────────────────────

class AlooCalculatorService {
  /// ─── NEW: Kisan Sell-Now vs Store-and-Sell-Later ──────────────────────────
  ///
  /// Formulas:
  ///   totalYieldKg           = landArea(ha) × yieldPerHa(tons) × 1000
  ///   totalProductionCost    = (labor + seed + fertilizer + transport) × landArea
  ///   sellNowRevenue         = totalYieldKg × currentPrice
  ///   sellNowNetProfit       = sellNowRevenue − totalProductionCost
  ///   totalStorageCost       = totalYieldKg × storageCostPerKg × durationMonths
  ///   futureSellingRevenue   = totalYieldKg × expectedFuturePrice
  ///   storeAndSellNetProfit  = futureSellingRevenue − totalProductionCost − totalStorageCost
  ///   breakEvenFuturePrice   = (totalProductionCost + totalStorageCost) / totalYieldKg
  ///
  static KisanDecisionResult calculateKisanDecision({
    required double landArea,
    required String landUnit, // 'ha' or 'acre'
    required double yieldPerHa, // tons per hectare
    required double currentPricePerKg,
    required double expectedFuturePricePerKg,
    required double storageCostPerKgPerMonth,
    required int storageDurationMonths,
    double laborCostPerHa = 0,
    double seedCostPerHa = 0,
    double fertilizerCostPerHa = 0,
    double transportCostPerHa = 0,
  }) {
    // Convert acres to hectares if needed (1 acre ≈ 0.4047 ha)
    final landHa = landUnit == 'acre' ? landArea * 0.4047 : landArea;

    final totalYieldKg = landHa * yieldPerHa * 1000; // tons → kg
    final totalProductionCost =
        (laborCostPerHa +
            seedCostPerHa +
            fertilizerCostPerHa +
            transportCostPerHa) *
        landHa;

    // Sell Now
    final sellNowRevenue = totalYieldKg * currentPricePerKg;
    final sellNowNetProfit = sellNowRevenue - totalProductionCost;

    // Store & Sell Later
    final totalStorageCost =
        totalYieldKg * storageCostPerKgPerMonth * storageDurationMonths;
    final futureSellingRevenue = totalYieldKg * expectedFuturePricePerKg;
    final storeAndSellNetProfit =
        futureSellingRevenue - totalProductionCost - totalStorageCost;

    // Break-even: price at which storing just matches production + storage costs
    final breakEvenFuturePrice = totalYieldKg > 0
        ? (totalProductionCost + totalStorageCost) / totalYieldKg
        : 0.0;

    return KisanDecisionResult(
      landArea: landArea,
      landUnit: landUnit,
      yieldPerHa: yieldPerHa,
      currentPricePerKg: currentPricePerKg,
      expectedFuturePricePerKg: expectedFuturePricePerKg,
      storageCostPerKgPerMonth: storageCostPerKgPerMonth,
      storageDurationMonths: storageDurationMonths,
      laborCostPerHa: laborCostPerHa,
      seedCostPerHa: seedCostPerHa,
      fertilizerCostPerHa: fertilizerCostPerHa,
      transportCostPerHa: transportCostPerHa,
      totalYieldKg: totalYieldKg,
      totalProductionCost: totalProductionCost,
      sellNowRevenue: sellNowRevenue,
      sellNowNetProfit: sellNowNetProfit,
      totalStorageCost: totalStorageCost,
      futureSellingRevenue: futureSellingRevenue,
      storeAndSellNetProfit: storeAndSellNetProfit,
      breakEvenFuturePrice: breakEvenFuturePrice,
    );
  }

  /// Farmer: quantity × price (legacy)
  static FarmerCalcResult calculateFarmer({
    required double quantityKg,
    required double pricePerKg,
  }) {
    return FarmerCalcResult(
      quantityKg: quantityKg,
      pricePerKg: pricePerKg,
      totalAmount: quantityKg * pricePerKg,
    );
  }

  /// Vyapari: buying cost, selling value, profit/loss
  static VyapariCalcResult calculateVyapari({
    required double quantityKg,
    required double buyingPricePerKg,
    required double sellingPricePerKg,
  }) {
    final totalBuyingCost = quantityKg * buyingPricePerKg;
    final totalSellingValue = quantityKg * sellingPricePerKg;
    return VyapariCalcResult(
      quantityKg: quantityKg,
      buyingPricePerKg: buyingPricePerKg,
      sellingPricePerKg: sellingPricePerKg,
      totalBuyingCost: totalBuyingCost,
      totalSellingValue: totalSellingValue,
      profitOrLoss: totalSellingValue - totalBuyingCost,
    );
  }

  /// Cold Storage: quantity × charge × duration
  static ColdStorageCalcResult calculateColdStorage({
    required double quantityKg,
    required double chargePerKg,
    required int duration,
    required String durationUnit, // 'days' or 'months'
  }) {
    return ColdStorageCalcResult(
      quantityKg: quantityKg,
      chargePerKg: chargePerKg,
      duration: duration,
      durationUnit: durationUnit,
      totalIncome: quantityKg * chargePerKg * duration,
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

String _fmtNum(double n) {
  if (n == n.roundToDouble()) return n.toInt().toString();
  return n.toStringAsFixed(2);
}

/// Format number in Indian style with commas  (1,23,456)
String formatIndian(double number) {
  final isNeg = number < 0;
  final abs = number.abs();
  final intPart = abs.truncate();
  final decPart = abs - intPart;

  String formatted = _formatIndianInt(intPart);
  if (decPart > 0.004) {
    formatted = '$formatted.${decPart.toStringAsFixed(2).substring(2)}';
  }
  return isNeg ? '-$formatted' : formatted;
}

String _formatIndianInt(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${parts.join(',')},$last3';
}
