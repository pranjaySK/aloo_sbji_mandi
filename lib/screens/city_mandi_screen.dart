import 'package:aloo_sbji_mandi/core/service/mandi_price_service.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class CityMandiPricesScreen extends StatefulWidget {
  const CityMandiPricesScreen({super.key});

  @override
  State<CityMandiPricesScreen> createState() => _CityMandiPricesScreenState();
}

class _CityMandiPricesScreenState extends State<CityMandiPricesScreen> {
  final MandiPriceService _service = MandiPriceService();

  String state = '';
  String district = '';
  DateTime selectedDate = DateTime.now();
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  /// Grouped records: market name → list of variety records
  Map<String, List<Map<String, dynamic>>> _groupedMarkets = {};

  /// The actual date for which data was found (may differ from selectedDate)
  DateTime? _dataDate;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Extract route arguments
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && state.isEmpty) {
      state = args['state'] ?? '';
      district = args['district'] ?? '';
      _fetchPrices();
    }
  }

  Future<void> _fetchPrices() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final result = await _service.fetchMandiPrices(
        state: state,
        district: district,
        date: selectedDate,
        limit: 100,
      );

      final records = (result['records'] as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();

      if (records.isEmpty) {
        // Try fetching latest available data (scans last 7 days)
        final latestResult = await _service.fetchLatestPrices(
          state: state,
          district: district,
          limit: 100,
        );
        final latestRecords = (latestResult['records'] as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        if (latestRecords.isNotEmpty) {
          setState(() {
            _groupedMarkets = MandiPriceService.groupByMarket(latestRecords);
            _dataDate = latestResult['fetchedDate'] as DateTime?;
            if (_dataDate != null) {
              selectedDate = _dataDate!;
            }
            _isLoading = false;
          });
          return;
        }
      }

      setState(() {
        _groupedMarkets = MandiPriceService.groupByMarket(records);
        _dataDate = selectedDate;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2007),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1B5E20),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      _fetchPrices();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('dd MMMM yyyy').format(selectedDate);

    return Scaffold(
      backgroundColor: AppColors.cardBg(context),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "$district Mandi Prices",
          style: GoogleFonts.inter(
              fontWeight: FontWeight.w500, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: _pickDate,
          ),
        ],
      ),
      body: Column(
        children: [
          // Date selector
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(dateLabel,
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  const Icon(Icons.arrow_drop_down, color: Colors.grey),
                ],
              ),
            ),
          ),

          // Content
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF1B5E20)),
            SizedBox(height: 16),
            Text('Fetching mandi prices...'),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Error loading prices',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(_errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchPrices,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20)),
                child:
                    const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (_groupedMarkets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline,
                  size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'No potato price data available\nfor $district, $state',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                'Try selecting a different date or district',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today, size: 16),
                label: const Text('Change Date'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final marketNames = _groupedMarkets.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: marketNames.length,
      itemBuilder: (context, index) {
        final marketName = marketNames[index];
        final records = _groupedMarkets[marketName]!;
        return _MarketCard(
          marketName: marketName,
          district: district,
          records: records,
          index: index + 1,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Market Card Widget — shows grouped varieties with prices
// ─────────────────────────────────────────────────────────────
class _MarketCard extends StatelessWidget {
  final String marketName;
  final String district;
  final List<Map<String, dynamic>> records;
  final int index;

  const _MarketCard({
    required this.marketName,
    required this.district,
    required this.records,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    // Compute aggregate prices across all varieties in this market
    double overallMin = double.infinity;
    double overallMax = 0;
    double overallModal = 0;

    for (final r in records) {
      final minKg = (r['minPriceKg'] as double);
      final maxKg = (r['maxPriceKg'] as double);
      final modalKg = (r['modalPriceKg'] as double);
      if (minKg < overallMin) overallMin = minKg;
      if (maxKg > overallMax) overallMax = maxKg;
      overallModal += modalKg;
    }
    overallModal = overallModal / records.length;

    if (overallMin == double.infinity) overallMin = 0;

    // Arrival status based on price spread
    final spread = overallMax - overallMin;
    String arrivalStatus;
    if (spread <= 2) {
      arrivalStatus = 'Stable';
    } else if (spread <= 5) {
      arrivalStatus = 'Moderate';
    } else {
      arrivalStatus = 'High Spread';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA67C44), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      marketName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      district,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Text(
                records.first['arrivalDate'] ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                  color: Color(0xFF0B5D1E),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Variety-wise prices
          ...records.map((r) => _varietyPriceRow(r)),

          const Divider(height: 16),

          // Summary prices
          _priceRow('Max (Super)', '₹${overallMax.toStringAsFixed(1)}/kg',
              isUp: true),
          _priceRow(
              'Modal (Good)', '₹${overallModal.toStringAsFixed(1)}/kg',
              isUp: true),
          _priceRow('Min (Average)', '₹${overallMin.toStringAsFixed(1)}/kg',
              isUp: false),

          const SizedBox(height: 8),

          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: arrivalStatus == 'Stable'
                      ? const Color(0xFFE8F5E9)
                      : arrivalStatus == 'Moderate'
                          ? const Color(0xFFFFF8E1)
                          : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Price: $arrivalStatus',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: arrivalStatus == 'Stable'
                        ? const Color(0xFF0B5D1E)
                        : arrivalStatus == 'Moderate'
                            ? Colors.orange.shade800
                            : Colors.red.shade700,
                  ),
                ),
              ),
              Text(
                '${records.length} ${records.length == 1 ? 'variety' : 'varieties'}',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _varietyPriceRow(Map<String, dynamic> r) {
    final variety = r['variety'] as String;
    final grade = r['grade'] as String;
    final minKg = (r['minPriceKg'] as double).toStringAsFixed(1);
    final maxKg = (r['maxPriceKg'] as double).toStringAsFixed(1);
    final modalKg = (r['modalPriceKg'] as double).toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              '$variety ($grade)',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              '₹$minKg - ₹$maxKg  (Modal: ₹$modalKg)',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0B5D1E),
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String price, {bool isUp = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Row(
            children: [
              Text(price,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              Icon(
                isUp ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: isUp ? Colors.green : Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
