import 'package:aloo_sbji_mandi/core/service/trader_request_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/screens/kishan/trader_requests_screen.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/utils/ist_datetime.dart';

class TraderRequestsSectionWidget extends StatefulWidget {
  const TraderRequestsSectionWidget({super.key});

  @override
  State<TraderRequestsSectionWidget> createState() =>
      _TraderRequestsSectionWidgetState();
}

class _TraderRequestsSectionWidgetState
    extends State<TraderRequestsSectionWidget> {
  final TraderRequestService _requestService = TraderRequestService();
  List<dynamic> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    final result = await _requestService.getAllRequests(limit: 5);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) {
          _requests = result['data']['requests'] ?? [];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with View All button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.shopping_cart,
                    color: Colors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  tr('trader_requests'),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TraderRequestsScreen(),
                  ),
                );
              },
              child: Text(
                tr('view_all').substring(0, 8),
                style: TextStyle(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Requests list
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_requests.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  tr('no_trader_requests_yet'),
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _requests.length > 5 ? 5 : _requests.length,
              itemBuilder: (context, index) {
                final request = _requests[index];
                return _buildRequestCard(request);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final trader = request['trader'] ?? {};
    final traderName = trader['name'] ?? 'Unknown Trader';
    final quantity = request['quantity'] ?? 0;
    final maxPrice = request['maxPricePerQuintal'] ?? 0;
    final unit = request['unit'] ?? 'Quintal';
    final variety = request['potatoVariety'] ?? 'Unknown';
    final size = request['size'] ?? 'Medium';
    final createdAt = request['createdAt'] != null
        ? DateFormat(
            'dd MMM',
          ).format(DateTime.parse(request['createdAt']).toIST())
        : '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TraderRequestsScreen()),
        );
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBg(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trader name and date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    traderName,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  createdAt,
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Variety chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$variety ($size)',
                style: TextStyle(
                  color: AppColors.primaryGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Quantity
            Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  '${tr('needs')} $quantity ${unitAbbr(unit)}',
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                ),
              ],
            ),

            const Spacer(),

            // Max price
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.currency_rupee,
                    size: 14,
                    color: Colors.orange,
                  ),
                  Text(
                    "$maxPrice/${unitAbbr(unit)}",
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
