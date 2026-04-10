import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/ist_datetime.dart';

import '../../core/models/receipt_model.dart';
import '../../core/service/receipt_service.dart';
import '../../core/utils/app_localizations.dart';

class ReceiptViewScreen extends StatefulWidget {
  final String? dealId;
  final String? receiptNumber;
  final Receipt? receipt;

  const ReceiptViewScreen({
    super.key,
    this.dealId,
    this.receiptNumber,
    this.receipt,
  }) : assert(dealId != null || receiptNumber != null || receipt != null);

  @override
  State<ReceiptViewScreen> createState() => _ReceiptViewScreenState();
}

class _ReceiptViewScreenState extends State<ReceiptViewScreen> {
  final ReceiptService _receiptService = ReceiptService();
  Receipt? _receipt;
  bool _isLoading = true;
  String? _error;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    if (widget.receipt != null) {
      _receipt = widget.receipt;
      _isLoading = false;
    } else {
      _loadReceipt();
    }
  }

  Future<void> _loadReceipt() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      Map<String, dynamic> result;

      if (widget.dealId != null) {
        result = await _receiptService.getReceiptByDealId(widget.dealId!);
      } else {
        result = await _receiptService.getReceiptByNumber(
          widget.receiptNumber!,
        );
      }

      if (result['success'] == true) {
        setState(() {
          _receipt = result['receipt'];
          _userRole = result['userRole'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = result['message'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(
        title: Text(tr('receipt')),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          if (_receipt != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareReceipt,
              tooltip: tr('share'),
            ),
          if (_receipt != null)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _downloadReceipt,
              tooltip: tr('download'),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadReceipt, child: Text(tr('retry'))),
          ],
        ),
      );
    }

    if (_receipt == null) {
      return Center(child: Text(tr('receipt_not_found')));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _buildReceiptCard(),
    );
  }

  Widget _buildReceiptCard() {
    final receipt = _receipt!;
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with logo and receipt number
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.agriculture,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  tr('aloo_sabzi_mandi'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('payment_receipt'),
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    '# ${receipt.receiptNumber}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Payment Status
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.green, size: 28),
                ),
                const SizedBox(width: 12),
                Text(
                  tr('payment_successful'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // Parties Section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // From (Farmer)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('seller_farmer'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        receipt.farmer.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (receipt.farmer.phone != null)
                        Text(
                          receipt.farmer.phone!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward, color: Colors.grey),
                // To (Payer)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${tr('buyer_label')} (${receipt.payer.role == 'vendor' ? tr('role_vyapari') : tr('role_cold_storage')})',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        receipt.payer.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      if (receipt.payer.phone != null)
                        Text(
                          receipt.payer.phone!,
                          style: TextStyle(
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

          const Divider(),

          // Deal Details
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('deal_details'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  tr('deal_type'),
                  receipt.isListingDeal
                      ? tr('vegetable_listing')
                      : tr('cold_storage'),
                ),
                if (receipt.dealDetails.listingTitle != null)
                  _buildDetailRow(
                    tr('item'),
                    receipt.dealDetails.listingTitle!,
                  ),
                _buildDetailRow(
                  tr('quantity'),
                  '${receipt.dealDetails.quantity} ${tr('packets')}',
                ),
                _buildDetailRow(
                  tr('rate'),
                  '₹${receipt.dealDetails.pricePerUnit.toStringAsFixed(2)} / ${tr('packet')}',
                ),
                if (receipt.dealDetails.duration != null &&
                    !receipt.isListingDeal)
                  _buildDetailRow(
                    tr('duration'),
                    '${receipt.dealDetails.duration} ${tr('days')}',
                  ),
              ],
            ),
          ),

          const Divider(),

          // Payment Details
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('payment_details'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  tr('subtotal'),
                  '₹${receipt.paymentDetails.subtotal.toStringAsFixed(2)}',
                ),
                if (receipt.paymentDetails.taxes > 0)
                  _buildDetailRow(
                    tr('taxes'),
                    '₹${receipt.paymentDetails.taxes.toStringAsFixed(2)}',
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tr('total_amount'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹${receipt.paymentDetails.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  tr('payment_method'),
                  receipt.paymentDetails.paymentMethodDisplayName,
                ),
                if (receipt.paymentDetails.paymentId != null)
                  _buildDetailRow(
                    tr('payment_id'),
                    receipt.paymentDetails.paymentId!,
                  ),
                if (receipt.paymentDetails.paidAt != null)
                  _buildDetailRow(
                    tr('paid_on'),
                    dateFormat.format(receipt.paymentDetails.paidAt!.toIST()),
                  ),
              ],
            ),
          ),

          const Divider(),

          // Receipt Info
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tr('receipt_date'),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      dateFormat.format(receipt.createdAt.toIST()),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Terms and Conditions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.verified, color: Colors.green.shade300, size: 32),
                const SizedBox(height: 8),
                Text(
                  receipt.termsAndConditions,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _shareReceipt() {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr('share_coming_soon'))));
  }

  void _downloadReceipt() async {
    if (_receipt != null) {
      await _receiptService.markAsDownloaded(_receipt!.id);
    }

    // TODO: Implement PDF download functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('download_coming_soon')),
        backgroundColor: Colors.green,
      ),
    );
  }
}

// Static method to show receipt in a dialog
Future<void> showReceiptDialog(
  BuildContext context, {
  String? dealId,
  Receipt? receipt,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ReceiptViewScreen(dealId: dealId, receipt: receipt),
            ),
          ],
        ),
      ),
    ),
  );
}
