// ──────────────────────────────────────────────────────────────
// My Plan Screen — Coming Soon (original code commented below)
// ──────────────────────────────────────────────────────────────
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MyPlanScreen extends StatelessWidget {
  const MyPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: CustomRoundedAppBar(title: tr('my_plan')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.rocket_launch_outlined,
                  size: 72,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                tr('coming_soon'),
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'We are working hard to bring you exciting subscription plans. Stay tuned!',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: Text(tr('go_back')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  side: const BorderSide(color: AppColors.primaryGreen),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ═══════════════════════════════════════════════════════════════
   ORIGINAL MY PLAN SCREEN CODE — COMMENTED OUT FOR COMING SOON
   ═══════════════════════════════════════════════════════════════

import 'dart:convert';

import 'package:aloo_sbji_mandi/core/services/subscription_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OrigMyPlanScreen extends StatefulWidget {
  const _OrigMyPlanScreen({super.key});

  @override
  State<_OrigMyPlanScreen> createState() => _OrigMyPlanScreenState();
}

class _OrigMyPlanScreenState extends State<_OrigMyPlanScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _currentPlan;
  String? _userRole;
  String? _userName;
  String? _userEmail;
  String? _userPhone;

  // Razorpay instance
  late Razorpay _razorpay;

  // Current order details for verification
  String? _currentOrderId;
  String? _currentSubscriptionId;
  Map<String, dynamic>? _pendingPlan;

  List<Map<String, dynamic>> get _plans => [
    {
      'id': 'free',
      'name': tr('plan_free_pass'),
      'price': 0,
      'duration': tr('plan_forever'),
      'features': [
        tr('feature_basic_listing'),
        tr('feature_five_listings'),
        tr('feature_chat_buyers'),
        tr('feature_basic_support'),
      ],
      'color': Colors.grey,
      'popular': false,
    },
    {
      'id': 'seasonal',
      'name': tr('plan_seasonal_pass'),
      'price': 699,
      'duration': tr('plan_four_months'),
      'features': [
        tr('feature_unlimited_listings'),
        tr('feature_priority_search'),
        tr('feature_featured_listings'),
        tr('feature_direct_calls'),
        tr('feature_advanced_analytics'),
        tr('feature_verified_badge'),
      ],
      'color': Colors.amber,
      'popular': true,
    },
    {
      'id': 'yearly',
      'name': tr('plan_yearly_pass'),
      'price': 1499,
      'duration': tr('plan_one_year'),
      'features': [
        tr('feature_everything_seasonal'),
        tr('feature_dedicated_manager'),
        tr('feature_market_insights'),
        tr('feature_bulk_operations'),
        tr('feature_premium_badge'),
        tr('feature_24_7_support'),
        tr('feature_no_ads'),
      ],
      'color': Colors.purple,
      'popular': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _initRazorpay();
    _loadCurrentPlan();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _initRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Verify payment with backend (server-side signature check)
      final result = await SubscriptionService.verifyPayment(
        orderId: response.orderId ?? _currentOrderId ?? '',
        paymentId: response.paymentId ?? '',
        signature: response.signature ?? '',
        subscriptionId: _currentSubscriptionId,
      );

      if (result['success']) {
        // Update local subscription cache
        final subscriptionData = result['data']?['subscription'];
        if (subscriptionData != null) {
          final prefs = await SharedPreferences.getInstance();
          final planCache = {
            'planId': subscriptionData['planId'],
            'planName': subscriptionData['planName'],
            'price': subscriptionData['price'],
            'startDate': subscriptionData['startDate'],
            'endDate': subscriptionData['endDate'],
            'status': subscriptionData['status'],
          };
          await prefs.setString('current_plan', json.encode(planCache));
          _currentPlan = planCache;
        }

        Fluttertoast.showToast(
          msg: AppLocalizations.isHindi
              ? trArgs('payment_success_msg', {
                  'plan': _pendingPlan?['name'] ?? tr('plan_default'),
                })
              : '🎉 Payment successful! ${_pendingPlan?['name'] ?? 'Plan'} activated!',
          backgroundColor: Colors.green,
          toastLength: Toast.LENGTH_LONG,
        );
      } else {
        Fluttertoast.showToast(
          msg: result['message'] ?? tr('payment_verification_failed'),
          backgroundColor: Colors.red,
          toastLength: Toast.LENGTH_LONG,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Verification error. If amount was deducted, your plan will activate automatically.',
        backgroundColor: Colors.orange,
        toastLength: Toast.LENGTH_LONG,
      );
    }

    // Reset pending data
    _currentOrderId = null;
    _currentSubscriptionId = null;
    _pendingPlan = null;

    if (mounted) setState(() => _isLoading = false);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    // Parse error message — Razorpay sends JSON in message field
    String errorMessage = 'Payment failed';
    try {
      if (response.message != null) {
        final errData = json.decode(response.message!);
        if (errData is Map) {
          errorMessage = errData['error']?['description'] ??
              errData['description'] ??
              response.message!;
        } else {
          errorMessage = response.message!;
        }
      }
    } catch (_) {
      errorMessage = response.message ?? 'Payment failed';
    }

    Fluttertoast.showToast(
      msg: '❌ ${tr('payment_failed')}: $errorMessage',
      backgroundColor: Colors.red,
      toastLength: Toast.LENGTH_LONG,
    );

    // Reset pending data
    _currentOrderId = null;
    _currentSubscriptionId = null;
    _pendingPlan = null;

    if (mounted) setState(() => _isLoading = false);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    Fluttertoast.showToast(
      msg: '${tr('external_wallet_selected')}: ${response.walletName}',
      backgroundColor: Colors.blue,
    );
  }

  Future<void> _loadCurrentPlan() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    final planJson = prefs.getString('current_plan');

    setState(() {
      if (userJson != null) {
        final userData = json.decode(userJson);
        _userRole = userData['role'];
        _userName = userData['name'] ?? userData['fullName'] ?? 'User';
        _userEmail = userData['email'];
        _userPhone = userData['phone'] ?? userData['mobileNumber'];
      }
      if (planJson != null) {
        _currentPlan = json.decode(planJson);
      } else {
        // Default to free plan
        _currentPlan = {
          'planId': 'free',
          'startDate': DateTime.now().toIso8601String(),
          'endDate': null,
          'status': 'active',
        };
      }
      _isLoading = false;
    });

    // Also fetch from server to sync
    _fetchCurrentSubscription();
  }

  Future<void> _fetchCurrentSubscription() async {
    final result = await SubscriptionService.getCurrentSubscription();
    if (result['success'] && result['data'] != null) {
      final data = result['data'];
      final prefs = await SharedPreferences.getInstance();

      final planData = {
        'planId': data['planId'] ?? 'free',
        'planName': data['planName'] ?? 'Free',
        'price': data['price'] ?? 0,
        'startDate': data['startDate'],
        'endDate': data['endDate'],
        'status': data['status'] ?? 'active',
      };

      await prefs.setString('current_plan', json.encode(planData));

      if (mounted) {
        setState(() {
          _currentPlan = planData;
        });
      }
    }
  }

  Future<void> _subscribeToPlan(Map<String, dynamic> plan) async {
    if (plan['id'] == 'free') return;

    // Show payment confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.star, color: plan['color']),
            const SizedBox(width: 8),
            Text(tr('subscribe_to_plan')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${plan['name']} - ₹${plan['price']}/${plan['duration']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(tr('confirm_subscribe_question')),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.qr_code_2, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tr('pay_via_upi_qr'),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.qr_code_2, size: 18),
            label: Text(tr('pay_now')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      setState(() => _isLoading = true);

      // Store pending plan for success handler
      _pendingPlan = plan;

      // Create order on backend
      final orderResult = await SubscriptionService.createSubscriptionOrder(
        plan['id'],
      );

      if (!orderResult['success']) {
        if (mounted) setState(() => _isLoading = false);
        Fluttertoast.showToast(
          msg: orderResult['message'] ?? tr('failed_to_create_order'),
          backgroundColor: Colors.red,
        );
        return;
      }

      final orderData = orderResult['data'];

      // Check if free plan was activated directly
      if (orderData['isFree'] == true) {
        final subscription = orderData['subscription'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'current_plan',
          json.encode({
            'planId': subscription['planId'],
            'planName': subscription['planName'],
            'startDate': subscription['startDate'],
            'endDate': subscription['endDate'],
            'status': 'active',
          }),
        );

        if (mounted) {
          setState(() {
            _currentPlan = {
              'planId': subscription['planId'],
              'planName': subscription['planName'],
              'startDate': subscription['startDate'],
              'endDate': subscription['endDate'],
              'status': 'active',
            };
            _isLoading = false;
          });
        }
        return;
      }

      // Store order details for verification
      _currentOrderId = orderData['orderId'];
      _currentSubscriptionId = orderData['subscriptionId'];

      // Open Razorpay checkout with UPI QR as preferred method
      var options = {
        'key': orderData['keyId'],
        'amount': orderData['amount'],
        'currency': orderData['currency'] ?? 'INR',
        'name': 'Aloo Sabji Mandi',
        'description': '${plan['name']} Plan - ${plan['duration']}',
        'order_id': orderData['orderId'],
        'prefill': {
          'name': _userName ?? '',
          'email': _userEmail ?? '',
          'contact': _userPhone ?? '',
        },
        'theme': {'color': '#4CAF50'},
        'notes': {'planId': plan['id'], 'planName': plan['name']},
        // Prefer UPI QR code payment
        'config': {
          'display': {
            'blocks': {
              'utib': {
                'name': 'Pay using UPI QR',
                'instruments': [
                  {
                    'method': 'upi',
                    'flows': ['qr'],
                  },
                  {
                    'method': 'upi',
                    'flows': ['collect', 'intent'],
                  },
                ],
              },
              'other': {
                'name': 'Other Payment Methods',
                'instruments': [
                  {'method': 'card'},
                  {'method': 'netbanking'},
                  {'method': 'wallet'},
                ],
              },
            },
            'sequence': ['block.utib', 'block.other'],
            'preferences': {'show_default_blocks': false},
          },
        },
      };

      try {
        if (mounted) setState(() => _isLoading = false);
        _razorpay.open(options);
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
        _currentOrderId = null;
        _currentSubscriptionId = null;
        _pendingPlan = null;
        Fluttertoast.showToast(
          msg: tr('error_starting_payment'),
          backgroundColor: Colors.red,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: CustomRoundedAppBar(title: tr('my_plan')),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current Plan Card
                  _buildCurrentPlanCard(),

                  const SizedBox(height: 24),

                  Text(
                    tr('available_plans'),
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Plan Cards
                  ..._plans.map(
                    (plan) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildPlanCard(plan),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // FAQ Section
                  _buildFAQSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentPlanCard() {
    final currentPlanId = _currentPlan?['planId'] ?? 'free';
    final currentPlanData = _plans.firstWhere((p) => p['id'] == currentPlanId);

    final hasEndDate = _currentPlan?['endDate'] != null;
    DateTime? endDate;
    int? daysLeft;

    if (hasEndDate) {
      endDate = DateTime.parse(_currentPlan!['endDate']);
      daysLeft = endDate.difference(DateTime.now()).inDays;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            currentPlanData['color'].shade700 ?? currentPlanData['color'],
            currentPlanData['color'].shade500 ?? currentPlanData['color'],
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: currentPlanData['color'].withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.star, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('current_plan'),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      currentPlanData['name'],
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tr('active'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          if (hasEndDate && daysLeft != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    daysLeft > 7 ? Icons.access_time : Icons.warning,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          daysLeft > 0
                              ? '$daysLeft ${tr('days_remaining')}'
                              : tr('expired'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${tr('expires')}: ${endDate!.day}/${endDate.month}/${endDate.year}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (daysLeft <= 7 && daysLeft > 0)
                    ElevatedButton(
                      onPressed: () => _subscribeToPlan(currentPlanData),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: currentPlanData['color'],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                      ),
                      child: Text(tr('renew')),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Progress to next tier
          if (currentPlanId != 'yearly') ...[
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: currentPlanId == 'free'
                          ? 0.33
                          : currentPlanId == 'seasonal'
                          ? 0.66
                          : 1.0,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${tr('upgrade')} ↑',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final isCurrentPlan = _currentPlan?['planId'] == plan['id'];
    final features = plan['features'];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: plan['popular'] == true
            ? Border.all(color: Colors.amber, width: 2)
            : isCurrentPlan
            ? Border.all(color: Colors.green, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Popular badge
          if (plan['popular'] == true)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Center(
                child: Text(
                  '⭐ ${tr('most_popular')}',
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: plan['color'].withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.star, color: plan['color'], size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan['name'],
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            plan['duration'],
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          plan['price'] == 0 ? tr('free') : '₹${plan['price']}',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: plan['color'],
                          ),
                        ),
                        if (plan['price'] > 0)
                          Text(
                            '/${plan['duration']}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                // Features
                ...features
                    .map<Widget>(
                      (feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green.shade600,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                feature,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),

                const SizedBox(height: 16),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  child: isCurrentPlan
                      ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green.shade700,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  tr('current_plan'),
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ElevatedButton(
                          onPressed: plan['price'] == 0
                              ? null
                              : () => _subscribeToPlan(plan),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: plan['color'],
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            plan['price'] == 0
                                ? tr('free_plan')
                                : tr('subscribe_now'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('faq'),
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          _faqItem(tr('faq_change_plan_q'), tr('faq_change_plan_a')),
          _faqItem(tr('faq_payment_q'), tr('faq_payment_a')),
          _faqItem(tr('faq_refund_q'), tr('faq_refund_a')),
        ],
      ),
    );
  }

  Widget _faqItem(String question, String answer) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        question,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            answer,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

═══════════════════════════════════════════════════════════════ */
