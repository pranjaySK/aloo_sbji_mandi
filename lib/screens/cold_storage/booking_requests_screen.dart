import 'package:aloo_sbji_mandi/core/models/chat_models.dart';
import 'package:aloo_sbji_mandi/core/service/booking_service.dart';
import 'package:aloo_sbji_mandi/core/service/chat_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/screens/chat/chat_detail_screen.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/utils/ist_datetime.dart';

class BookingRequestsScreen extends StatefulWidget {
  final bool isManagerView;

  const BookingRequestsScreen({super.key, this.isManagerView = false});

  @override
  State<BookingRequestsScreen> createState() => _BookingRequestsScreenState();
}

class _BookingRequestsScreenState extends State<BookingRequestsScreen>
    with SingleTickerProviderStateMixin {
  final BookingService _bookingService = BookingService();
  late TabController _tabController;

  List<dynamic> _allBookings = [];
  bool _isLoading = true;
  String? _error;

  // Filter state
  DateTimeRange? _filterDateRange;
  RangeValues? _filterQuantityRange;
  RangeValues? _filterPriceRange;
  String _sortBy = 'newest'; // newest, oldest, qty_high, qty_low, price_high, price_low

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _bookingService.getBookingRequests();

    setState(() {
      _isLoading = false;
      if (result['success']) {
        _allBookings = result['data']['bookings'] ?? [];
      } else {
        _error = result['message'] ?? 'Failed to load bookings';
      }
    });
  }

  List<dynamic> _getBookingsByStatus(String status) {
    List<dynamic> filtered = status == 'all'
        ? List.from(_allBookings)
        : _allBookings.where((b) => b['status'] == status).toList();

    // Apply filters
    if (_filterPriceRange != null) {
      filtered = filtered.where((b) {
        final price = (b['totalPrice'] ?? 0).toDouble();
        return price >= _filterPriceRange!.start && price <= _filterPriceRange!.end;
      }).toList();
    }

    if (_filterDateRange != null) {
      filtered = filtered.where((b) {
        try {
          final date = DateTime.parse(b['createdAt'] ?? '');
          return date.isAfter(_filterDateRange!.start.subtract(const Duration(days: 1))) &&
              date.isBefore(_filterDateRange!.end.add(const Duration(days: 1)));
        } catch (e) {
          return true;
        }
      }).toList();
    }

    if (_filterQuantityRange != null) {
      filtered = filtered.where((b) {
        final qty = (b['quantity'] ?? 0).toDouble();
        return qty >= _filterQuantityRange!.start && qty <= _filterQuantityRange!.end;
      }).toList();
    }

    // Apply sorting
    switch (_sortBy) {
      case 'newest':
        filtered.sort((a, b) => (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));
        break;
      case 'oldest':
        filtered.sort((a, b) => (a['createdAt'] ?? '').compareTo(b['createdAt'] ?? ''));
        break;
      case 'qty_high':
        filtered.sort((a, b) => ((b['quantity'] ?? 0) as num).compareTo((a['quantity'] ?? 0) as num));
        break;
      case 'qty_low':
        filtered.sort((a, b) => ((a['quantity'] ?? 0) as num).compareTo((b['quantity'] ?? 0) as num));
        break;
      case 'price_high':
        filtered.sort((a, b) => ((b['totalPrice'] ?? 0) as num).compareTo((a['totalPrice'] ?? 0) as num));
        break;
      case 'price_low':
        filtered.sort((a, b) => ((a['totalPrice'] ?? 0) as num).compareTo((b['totalPrice'] ?? 0) as num));
        break;
    }

    return filtered;
  }

  bool get _hasActiveFilters =>
      _filterPriceRange != null ||
      _filterDateRange != null ||
      _filterQuantityRange != null ||
      _sortBy != 'newest';

  void _clearFilters() {
    setState(() {
      _filterDateRange = null;
      _filterQuantityRange = null;
      _filterPriceRange = null;
      _sortBy = 'newest';
    });
  }

  void _showFilterSheet() {
    DateTimeRange? tempDateRange = _filterDateRange;
    RangeValues? tempQuantityRange = _filterQuantityRange;
    RangeValues? tempPriceRange = _filterPriceRange;
    String tempSortBy = _sortBy;

    // Determine max quantity for slider
    double maxQty = 500;
    for (var b in _allBookings) {
      final q = (b['quantity'] ?? 0).toDouble();
      if (q > maxQty) maxQty = q;
    }
    maxQty = (maxQty / 100).ceilToDouble() * 100; // round up to nearest 100
    if (maxQty < 100) maxQty = 100;

    // Determine max price for slider
    double maxPrice = 10000;
    for (var b in _allBookings) {
      final p = (b['totalPrice'] ?? 0).toDouble();
      if (p > maxPrice) maxPrice = p;
    }
    maxPrice = (maxPrice / 1000).ceilToDouble() * 1000; // round up to nearest 1000
    if (maxPrice < 1000) maxPrice = 1000;

    final sortOptions = [
      {'value': 'newest', 'label': tr('newest_first'), 'icon': Icons.arrow_downward},
      {'value': 'oldest', 'label': tr('oldest_first'), 'icon': Icons.arrow_upward},
      {'value': 'qty_high', 'label': tr('qty_high_to_low'), 'icon': Icons.inventory_2},
      {'value': 'qty_low', 'label': tr('qty_low_to_high'), 'icon': Icons.inventory_2_outlined},
      {'value': 'price_high', 'label': tr('price_high_to_low'), 'icon': Icons.currency_rupee},
      {'value': 'price_low', 'label': tr('price_low_to_high'), 'icon': Icons.currency_rupee_outlined},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tr('filter_bookings'),
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Sort By
                    Text(tr('sort_by'), style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: sortOptions.map((opt) {
                        final isSelected = tempSortBy == opt['value'];
                        return ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                opt['icon'] as IconData,
                                size: 16,
                                color: isSelected ? Colors.white : AppColors.primaryGreen,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                opt['label'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          selected: isSelected,
                          selectedColor: AppColors.primaryGreen,
                          backgroundColor: Colors.grey.shade100,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300,
                            ),
                          ),
                          onSelected: (_) => setSheetState(() => tempSortBy = opt['value'] as String),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Date Range
                    Text(tr('booking_date_range'), style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2024),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          initialDateRange: tempDateRange,
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(primary: AppColors.primaryGreen),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setSheetState(() => tempDateRange = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                            const SizedBox(width: 10),
                            Text(
                              tempDateRange != null
                                  ? '${DateFormat('dd MMM yyyy').format(tempDateRange!.start)} – ${DateFormat('dd MMM yyyy').format(tempDateRange!.end)}'
                                  : tr('select_date_range'),
                              style: TextStyle(
                                color: tempDateRange != null ? Colors.black : Colors.grey[600],
                              ),
                            ),
                            const Spacer(),
                            if (tempDateRange != null)
                              GestureDetector(
                                onTap: () => setSheetState(() => tempDateRange = null),
                                child: const Icon(Icons.close, size: 18, color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Price Range
                    Text(tr('price_range_rupees'), style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    RangeSlider(
                      values: tempPriceRange ?? RangeValues(0, maxPrice),
                      min: 0,
                      max: maxPrice,
                      divisions: (maxPrice / 500).round().clamp(1, 200),
                      activeColor: AppColors.primaryGreen,
                      labels: RangeLabels(
                        '₹${(tempPriceRange?.start ?? 0).round()}',
                        '₹${(tempPriceRange?.end ?? maxPrice).round()}',
                      ),
                      onChanged: (v) => setSheetState(() => tempPriceRange = v),
                    ),
                    Text(
                      '₹${(tempPriceRange?.start ?? 0).round()} – ₹${(tempPriceRange?.end ?? maxPrice).round()}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 20),

                    // Quantity Range
                    Text(tr('quantity_range_packets'), style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    RangeSlider(
                      values: tempQuantityRange ?? RangeValues(0, maxQty),
                      min: 0,
                      max: maxQty,
                      divisions: (maxQty / 10).round().clamp(1, 100),
                      activeColor: AppColors.primaryGreen,
                      labels: RangeLabels(
                        '${(tempQuantityRange?.start ?? 0).round()}',
                        '${(tempQuantityRange?.end ?? maxQty).round()}',
                      ),
                      onChanged: (v) => setSheetState(() => tempQuantityRange = v),
                    ),
                    Text(
                      '${(tempQuantityRange?.start ?? 0).round()} – ${(tempQuantityRange?.end ?? maxQty).round()} ${tr('packets')}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setSheetState(() {
                                tempDateRange = null;
                                tempQuantityRange = null;
                                tempPriceRange = null;
                                tempSortBy = 'newest';
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey[700],
                              side: BorderSide(color: Colors.grey.shade400),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(tr('clear_all')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _filterDateRange = tempDateRange;
                                _sortBy = tempSortBy;
                                // Only apply quantity filter if it's not the full range
                                if (tempQuantityRange != null &&
                                    (tempQuantityRange!.start > 0 || tempQuantityRange!.end < maxQty)) {
                                  _filterQuantityRange = tempQuantityRange;
                                } else {
                                  _filterQuantityRange = null;
                                }
                                // Only apply price filter if it's not the full range
                                if (tempPriceRange != null &&
                                    (tempPriceRange!.start > 0 || tempPriceRange!.end < maxPrice)) {
                                  _filterPriceRange = tempPriceRange;
                                } else {
                                  _filterPriceRange = null;
                                }
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(tr('apply_filters'), style: const TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          tr('booking_requests'),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list, color: Colors.white),
                onPressed: _showFilterSheet,
                tooltip: tr('filter'),
              ),
              if (_hasActiveFilters)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          if (_hasActiveFilters)
            TextButton(
              onPressed: _clearFilters,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 36),
              ),
              child: Text(
                tr('clear_all'),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: [
            Tab(text: '${tr('pending')} (${_getBookingsByStatus('pending').length})'),
            Tab(text: '${tr('accepted')} (${_getBookingsByStatus('accepted').length})'),
            Tab(text: '${tr('rejected')} (${_getBookingsByStatus('rejected').length})'),
            Tab(text: '${tr('all')} (${_getBookingsByStatus('all').length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadBookings,
                    child: Text(tr('retry')),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBookingList('pending'),
                _buildBookingList('accepted'),
                _buildBookingList('rejected'),
                _buildBookingList('all'),
              ],
            ),
    );
  }

  Widget _buildBookingList(String status) {
    final bookings = _getBookingsByStatus(status);

    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              status == 'pending'
                  ? tr('no_pending_booking_requests')
                  : tr('no_bookings'),
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          return BookingRequestCard(
            booking: bookings[index],
            onStatusChanged: _loadBookings,
            isManagerView: widget.isManagerView,
          );
        },
      ),
    );
  }
}

class BookingRequestCard extends StatefulWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onStatusChanged;
  final bool isManagerView;

  const BookingRequestCard({
    super.key,
    required this.booking,
    required this.onStatusChanged,
    this.isManagerView = false,
  });

  @override
  State<BookingRequestCard> createState() => _BookingRequestCardState();
}

class _BookingRequestCardState extends State<BookingRequestCard> {
  final BookingService _bookingService = BookingService();
  final ChatService _chatService = ChatService();
  bool _isResponding = false;

  Map<String, dynamic> get booking => widget.booking;
  Map<String, dynamic> get farmer => booking['farmer'] ?? {};
  Map<String, dynamic> get coldStorage => booking['coldStorage'] ?? {};
  String get status => booking['status'] ?? 'pending';

  Color get statusColor {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date.toIST());
    } catch (e) {
      return '-';
    }
  }

  Future<void> _respond(String action) async {
    String? response;

    if (action == 'reject') {
      response = await showDialog<String>(
        context: context,
        builder: (context) => _ReasonDialog(action: action),
      );
      if (response == null) return; // User cancelled
    }

    setState(() => _isResponding = true);

    final result = await _bookingService.respondToBooking(
      bookingId: booking['_id'],
      action: action,
      ownerResponse: response,
    );

    setState(() => _isResponding = false);

    if (result['success']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'accept'
                  ? tr('booking_accepted_success')
                  : tr('booking_rejected_msg'),
            ),
            backgroundColor: action == 'accept' ? Colors.green : Colors.orange,
          ),
        );
        widget.onStatusChanged();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? tr('failed_to_action_booking')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteBooking() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('delete_booking')),
        content: Text(
          tr('delete_booking_confirm'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(tr('delete'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isResponding = true);

    final result = await _bookingService.deleteBooking(booking['_id']);

    setState(() => _isResponding = false);

    if (result['success']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('booking_deleted_success')),
            backgroundColor: Colors.green,
          ),
        );
        widget.onStatusChanged();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? tr('failed_to_delete_booking')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startChat() async {
    // Get farmer ID - check farmer object first, then booking directly
    String? farmerId;
    String farmerName = 'Farmer';

    if (farmer.isNotEmpty && farmer['_id'] != null) {
      farmerId = farmer['_id'].toString();
      farmerName = '${farmer['firstName'] ?? ''} ${farmer['lastName'] ?? ''}'
          .trim();
      if (farmerName.isEmpty) farmerName = 'Farmer';
    } else if (booking['farmer'] != null) {
      // Farmer might be stored as just an ID string
      if (booking['farmer'] is String) {
        farmerId = booking['farmer'];
      } else if (booking['farmer'] is Map && booking['farmer']['_id'] != null) {
        farmerId = booking['farmer']['_id'].toString();
      }
    }

    if (farmerId == null || farmerId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('farmer_info_not_available')),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isResponding = true);

    final result = await _chatService.startOrGetConversation(farmerId);

    setState(() => _isResponding = false);

    if (result['success']) {
      // Backend returns conversation directly in data, or nested under 'conversation'
      final data = result['data'];
      final conversation = data is Map ? (data['conversation'] ?? data) : null;
      if (conversation != null && conversation['_id'] != null && mounted) {
        // Create ChatUser object for the farmer
        final chatUser = ChatUser(
          id: farmerId,
          firstName: farmer['firstName']?.toString() ?? farmerName,
          lastName: farmer['lastName']?.toString() ?? '',
          role: 'farmer',
          isOnline: farmer['isOnline'] ?? false,
          phone: farmer['phone']?.toString(),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              conversationId: conversation['_id']?.toString() ?? '',
              otherUser: chatUser,
              contextType: 'booking',
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('could_not_start_conversation')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? tr('could_not_start_chat')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.withOpacity(0.2),
                  child: const Icon(Icons.person, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${farmer['firstName'] ?? ''} ${farmer['lastName'] ?? ''}'
                            .trim(),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        farmer['phone'] ?? '',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
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
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tr(status).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _isResponding ? null : _deleteBooking,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Booking details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Storage name
                Row(
                  children: [
                    const Icon(
                      Icons.ac_unit,
                      color: AppColors.primaryGreen,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        coldStorage['name'] ?? tr('cold_storage'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Quantity
                Row(
                  children: [
                    Expanded(
                      child: _infoItem(
                        tr('quantity'),
                        '${booking['quantity'] ?? 0} ${tr('packets')}',
                        Icons.inventory_2,
                      ),
                    ),
                    const Expanded(child: SizedBox()),
                  ],
                ),

                const SizedBox(height: 12),

                // Price and Dates
                Row(
                  children: [
                    Expanded(
                      child: _infoItem(
                        tr('total_price'),
                        '₹${booking['totalPrice'] ?? 0}',
                        Icons.currency_rupee,
                        valueColor: AppColors.primaryGreen,
                      ),
                    ),
                    Expanded(
                      child: _infoItem(
                        tr('requested_on'),
                        _formatDate(booking['createdAt']),
                        Icons.access_time,
                      ),
                    ),
                  ],
                ),

                // Farmer Note
                if (booking['farmerNote'] != null &&
                    booking['farmerNote'].isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('message_from_farmer'),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          booking['farmerNote'],
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],

                // Owner Response (if rejected)
                if (status == 'rejected' &&
                    booking['ownerResponse'] != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('rejection_reason'),
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          booking['ownerResponse'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red[900],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                // Chat button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _startChat,
                    icon: const Icon(Icons.chat),
                    label: Text(tr('chat')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      side: const BorderSide(color: AppColors.primaryGreen),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Accept/Reject buttons (only for pending, hidden for manager)
                if (status == 'pending' && !widget.isManagerView) ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isResponding
                          ? null
                          : () => _respond('reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isResponding
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              tr('reject'),
                              style: const TextStyle(color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isResponding
                          ? null
                          : () => _respond('accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isResponding
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              tr('accept'),
                              style: const TextStyle(color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReasonDialog extends StatefulWidget {
  final String action;

  const _ReasonDialog({required this.action});

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.action == 'reject' ? tr('rejection_reason') : tr('response')),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: widget.action == 'reject'
              ? tr('enter_rejection_reason_optional')
              : tr('enter_response'),
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('cancel')),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.action == 'reject'
                ? Colors.red
                : Colors.green,
          ),
          child: Text(
            widget.action == 'reject' ? tr('reject') : tr('confirm'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
