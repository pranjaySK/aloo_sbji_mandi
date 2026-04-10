import 'package:aloo_sbji_mandi/core/service/mandi_price_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MandiPriceTrendScreen extends StatefulWidget {
  const MandiPriceTrendScreen({super.key});

  @override
  State<MandiPriceTrendScreen> createState() => _MandiPriceTrendScreenState();
}

class _MandiPriceTrendScreenState extends State<MandiPriceTrendScreen> {
  final MandiPriceService _service = MandiPriceService();

  String _market = '';
  String _district = '';
  String _state = '';
  double _currentPrice = 0;
  String _arrivalDate = '';

  List<Map<String, dynamic>> _priceHistory = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _isFavourite = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && _market.isEmpty) {
      _market = args['market'] as String? ?? '';
      _district = args['district'] as String? ?? '';
      _state = args['state'] as String? ?? '';
      _currentPrice = (args['modalPriceQuintal'] as num?)?.toDouble() ?? 0;
      _arrivalDate = args['arrivalDate'] as String? ?? '';
      _loadFavouriteStatus();
      _fetchHistory();
    }
  }

  Future<void> _loadFavouriteStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList('favourite_mandis') ?? [];
    final key = '${_market}_${_district}_$_state';
    if (mounted) {
      setState(() => _isFavourite = favs.contains(key));
    }
  }

  Future<void> _toggleFavourite() async {
    final prefs = await SharedPreferences.getInstance();
    final favs = (prefs.getStringList('favourite_mandis') ?? []).toSet();
    final key = '${_market}_${_district}_$_state';
    if (favs.contains(key)) {
      favs.remove(key);
    } else {
      favs.add(key);
    }
    await prefs.setStringList('favourite_mandis', favs.toList());
    if (mounted) {
      setState(() => _isFavourite = !_isFavourite);
    }
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final history = await _service.fetchPriceHistory(
        state: _state,
        market: _market,
        district: _district,
      );
      if (mounted) {
        setState(() {
          _priceHistory = history;
          _isLoading = false;
          // Update current price from most recent entry if available
          if (history.isNotEmpty) {
            _currentPrice =
                history.last['modalPriceQuintal'] as double;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _market,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFavourite ? Icons.favorite : Icons.favorite_border,
              color: _isFavourite ? Colors.red.shade300 : Colors.white,
            ),
            onPressed: _toggleFavourite,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1B5E20)))
          : _hasError
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            tr('error_loading_prices'),
            style: GoogleFonts.inter(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchHistory,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
            ),
            child: Text(tr('retry'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Price header card
          _buildPriceHeader(),

          // Price trend graph
          _buildPriceChart(),

          // Past prices list
          _buildPastPricesList(),
        ],
      ),
    );
  }

  Widget _buildPriceHeader() {
    final pricePerKg = _currentPrice / 100;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withOpacity(0.3),
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
              const Icon(Icons.store, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _market,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$_district, $_state',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('current_price'),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${_currentPrice.toStringAsFixed(0)}/${tr('quintal')}',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '₹${pricePerKg.toStringAsFixed(1)}/${tr('kg')}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              if (_priceHistory.length >= 2)
                _buildChangeIndicator(),
            ],
          ),
          if (_arrivalDate.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${tr('last_updated')}: $_arrivalDate',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.white60,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChangeIndicator() {
    final latest = _priceHistory.last['modalPriceQuintal'] as double;
    final previous =
        _priceHistory[_priceHistory.length - 2]['modalPriceQuintal'] as double;
    final change = latest - previous;
    final pctChange = previous > 0 ? (change / previous) * 100 : 0.0;
    final isUp = change > 0;
    final isNeutral = change.abs() < 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            isNeutral
                ? Icons.remove
                : isUp
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
            color: isNeutral
                ? Colors.amber.shade300
                : isUp
                    ? Colors.greenAccent
                    : Colors.redAccent.shade100,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            '${isUp ? '+' : ''}${pctChange.toStringAsFixed(1)}%',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceChart() {
    if (_priceHistory.length < 2) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            tr('not_enough_data_for_chart'),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ),
      );
    }

    // Prepare chart data
    final spots = <FlSpot>[];
    double minY = double.infinity;
    double maxY = 0;

    for (int i = 0; i < _priceHistory.length; i++) {
      final price = _priceHistory[i]['modalPriceQuintal'] as double;
      spots.add(FlSpot(i.toDouble(), price));
      if (price < minY) minY = price;
      if (price > maxY) maxY = price;
    }

    // Add padding to Y axis
    final yPadding = (maxY - minY) * 0.15;
    if (yPadding < 50) {
      minY = (minY - 50).clamp(0, double.infinity);
      maxY = maxY + 50;
    } else {
      minY = (minY - yPadding).clamp(0, double.infinity);
      maxY = maxY + yPadding;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(8, 24, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 16),
            child: Text(
              tr('price_trend'),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _getHorizontalInterval(minY, maxY),
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.shade200,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      interval: _getHorizontalInterval(minY, maxY),
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            '₹${value.toInt()}',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: _getBottomInterval(),
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= _priceHistory.length) {
                          return const SizedBox.shrink();
                        }
                        final date =
                            _priceHistory[idx]['date'] as DateTime?;
                        if (date == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat('dd/MM').format(date),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (_priceHistory.length - 1).toDouble(),
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: const Color(0xFF1B5E20),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.white,
                          strokeWidth: 2.5,
                          strokeColor: const Color(0xFF1B5E20),
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1B5E20).withOpacity(0.2),
                          const Color(0xFF1B5E20).withOpacity(0.02),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1B5E20),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final idx = spot.x.toInt();
                        final date = idx < _priceHistory.length
                            ? _priceHistory[idx]['date'] as DateTime?
                            : null;
                        final dateStr = date != null
                            ? DateFormat('dd MMM yyyy').format(date)
                            : '';
                        return LineTooltipItem(
                          '₹${spot.y.toStringAsFixed(0)}\n$dateStr',
                          GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getHorizontalInterval(double minY, double maxY) {
    final range = maxY - minY;
    if (range <= 200) return 50;
    if (range <= 500) return 100;
    if (range <= 1000) return 200;
    return 500;
  }

  double _getBottomInterval() {
    final count = _priceHistory.length;
    if (count <= 5) return 1;
    if (count <= 10) return 2;
    if (count <= 20) return 4;
    return (count / 5).ceilToDouble();
  }

  Widget _buildPastPricesList() {
    // Reverse to show most recent first
    final reversed = _priceHistory.reversed.toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Text(
            tr('past_prices'),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          if (reversed.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  tr('no_past_prices_available'),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            )
          else
            // Price entries as cards matching reference design
            ...List.generate(reversed.length, (index) {
              final entry = reversed[index];
              final price = entry['modalPriceQuintal'] as double;
              final date = entry['date'] as DateTime?;
              final dateStr = date != null
                  ? DateFormat('dd MMMM').format(date)
                  : entry['dateStr'] as String? ?? '';

              // Calculate percentage change from the next (earlier) entry
              double? pctChange;
              if (index < reversed.length - 1) {
                final prevPrice =
                    reversed[index + 1]['modalPriceQuintal'] as double;
                if (prevPrice > 0) {
                  pctChange = ((price - prevPrice) / prevPrice) * 100;
                }
              }

              return _PastPriceRow(
                dateStr: dateStr,
                price: price,
                percentChange: pctChange,
                isFirst: index == 0,
              );
            }),
        ],
      ),
    );
  }
}

class _PastPriceRow extends StatelessWidget {
  final String dateStr;
  final double price;
  final double? percentChange;
  final bool isFirst;

  const _PastPriceRow({
    required this.dateStr,
    required this.price,
    this.percentChange,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    final isUp = (percentChange ?? 0) > 0.5;
    final isDown = (percentChange ?? 0) < -0.5;
    final isNeutral = !isUp && !isDown;

    Color badgeColor;
    Color textColor;
    IconData icon;

    if (isUp) {
      badgeColor = const Color(0xFFE8F5E9);
      textColor = const Color(0xFF1B5E20);
      icon = Icons.arrow_upward;
    } else if (isDown) {
      badgeColor = const Color(0xFFFFEBEE);
      textColor = Colors.red.shade700;
      icon = Icons.arrow_downward;
    } else {
      badgeColor = const Color(0xFFFFF8E1);
      textColor = Colors.orange.shade800;
      icon = Icons.remove;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Date
          Expanded(
            flex: 3,
            child: Text(
              dateStr,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),

          // Price
          Text(
            '₹ ${price.toStringAsFixed(0)} / Q',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 12),

          // Change badge
          percentChange != null
              ? Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isNeutral ? Icons.swap_horiz : icon,
                        size: 14,
                        color: textColor,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${percentChange!.abs().toStringAsFixed(percentChange!.abs() >= 10 ? 1 : 2)}%',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: 60),
        ],
      ),
    );
  }
}
