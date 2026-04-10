import 'package:aloo_sbji_mandi/core/service/dummy_payment_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/screens/payment/dummy_payment_screen.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/utils/ist_datetime.dart';

class PaymentTestScreen extends StatefulWidget {
  const PaymentTestScreen({super.key});

  @override
  State<PaymentTestScreen> createState() => _PaymentTestScreenState();
}

class _PaymentTestScreenState extends State<PaymentTestScreen> {
  final DummyPaymentService _paymentService = DummyPaymentService();
  final _amountController = TextEditingController(text: '1000');

  List<DummyPaymentResponse> _transactions = [];
  bool _isLoading = true;
  double _totalPayments = 0;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);

    final transactions = await _paymentService.getTransactionHistory();
    final total = await _paymentService.getTotalPayments();

    setState(() {
      _transactions = transactions;
      _totalPayments = total;
      _isLoading = false;
    });
  }

  void _startPayment() {
    double amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('enter_valid_amount')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            DummyPaymentScreen(amount: amount, description: 'Test Payment'),
      ),
    ).then((_) => _loadTransactions());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        title: Text(
          '💳 Payment Gateway Test',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.white),
            onPressed: () async {
              await _paymentService.clearTransactionHistory();
              _loadTransactions();
            },
            tooltip: tr('clear_history'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryGreen, Color(0xFF2E7D32)],
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.science, color: Colors.white70, size: 32),
                  const SizedBox(height: 8),
                  const Text(
                    'Test Payment Gateway',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${_totalPayments.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Total Successful Payments',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),

            // Make Payment Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Make a Test Payment',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: tr('amount_rupees'),
                          prefixIcon: const Icon(Icons.currency_rupee),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Quick amounts
                      Wrap(
                        spacing: 8,
                        children: [100, 500, 1000, 5000, 10000].map((amount) {
                          return ActionChip(
                            label: Text('₹$amount'),
                            onPressed: () =>
                                _amountController.text = amount.toString(),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _startPayment,
                          icon: const Icon(Icons.payment),
                          label: Text(tr('start_payment')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Test Cards Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                color: Colors.blue[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Test Card Numbers',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _testCardRow('✅', '4111 1111 1111 1111', 'Success'),
                      _testCardRow('✅', '5555 5555 5555 4444', 'Success (MC)'),
                      _testCardRow('❌', '4000 0000 0000 0002', 'Declined'),
                      _testCardRow('❌', '4000 0000 0000 9995', 'Insufficient'),
                      const Divider(),
                      _testCardRow('📱', 'yourname@upi', 'UPI Success'),
                      _testCardRow('📱', 'fail@upi', 'UPI Failure'),
                    ],
                  ),
                ),
              ),
            ),

            // Transaction History
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transaction History',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_transactions.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No transactions yet',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  else
                    ...(_transactions.take(10).map((t) => _transactionCard(t))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _testCardRow(String emoji, String card, String result) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              card,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
          Text(result, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }

  Widget _transactionCard(DummyPaymentResponse transaction) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: transaction.success
                ? Colors.green.withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            transaction.success ? Icons.check_circle : Icons.cancel,
            color: transaction.success ? Colors.green : Colors.red,
          ),
        ),
        title: Text(
          '₹${transaction.amount.toStringAsFixed(0)}',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${transaction.paymentMethod.toUpperCase()} • ${DateFormat('dd/MM/yy HH:mm').format(transaction.timestamp.toIST())}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          transaction.success ? 'Success' : 'Failed',
          style: TextStyle(
            color: transaction.success ? Colors.green : Colors.red,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
