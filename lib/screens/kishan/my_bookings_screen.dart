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

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  final BookingService _bookingService = BookingService();
  late TabController _tabController;

  List<dynamic> _allBookings = [];
  bool _isLoading = true;
  String? _error;

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

    final result = await _bookingService.getMyBookings();

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
    if (status == 'all') return _allBookings;
    return _allBookings.where((b) => b['status'] == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Cold Storage Booking',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: [
            Tab(text: 'Pending (${_getBookingsByStatus('pending').length})'),
            Tab(text: 'Accepted (${_getBookingsByStatus('accepted').length})'),
            Tab(text: 'Rejected (${_getBookingsByStatus('rejected').length})'),
            Tab(text: 'All (${_allBookings.length})'),
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
                  ? 'No pending bookings'
                  : 'No ${status == 'all' ? '' : status} bookings',
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
          return FarmerBookingCard(
            booking: bookings[index],
            onStatusChanged: _loadBookings,
          );
        },
      ),
    );
  }
}

class FarmerBookingCard extends StatefulWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onStatusChanged;

  const FarmerBookingCard({
    super.key,
    required this.booking,
    required this.onStatusChanged,
  });

  @override
  State<FarmerBookingCard> createState() => _FarmerBookingCardState();
}

class _FarmerBookingCardState extends State<FarmerBookingCard> {
  final BookingService _bookingService = BookingService();
  final ChatService _chatService = ChatService();
  bool _isLoading = false;

  Map<String, dynamic> get booking => widget.booking;
  Map<String, dynamic> get owner => booking['owner'] ?? {};
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

  Future<void> _editBooking() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditBookingDialog(booking: booking),
    );

    if (result != null) {
      setState(() => _isLoading = true);

      final updateResult = await _bookingService.updateBooking(
        bookingId: booking['_id'],
        quantity: result['quantity'],
        duration: result['duration'],
        farmerNote: result['farmerNote'],
      );

      setState(() => _isLoading = false);

      if (updateResult['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('booking_updated')),
              backgroundColor: Colors.green,
            ),
          );
          widget.onStatusChanged();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(updateResult['message'] ?? tr('failed_to_update_booking')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _cancelBooking() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('cancel_booking')),
        content: Text(tr('confirm_cancel_booking')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('no')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(tr('yes_cancel'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);

      final result = await _bookingService.cancelBooking(booking['_id']);

      setState(() => _isLoading = false);

      if (result['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('booking_cancelled')),
              backgroundColor: Colors.orange,
            ),
          );
          widget.onStatusChanged();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? tr('failed_to_cancel_booking')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _startChat() async {
    // Get owner ID - check owner object first, then booking directly
    String? ownerId;
    String ownerName = 'Cold Storage Owner';

    if (owner.isNotEmpty && owner['_id'] != null) {
      ownerId = owner['_id'].toString();
      ownerName = '${owner['firstName'] ?? ''} ${owner['lastName'] ?? ''}'.trim();
      if (ownerName.isEmpty) ownerName = 'Cold Storage Owner';
    } else if (booking['owner'] != null) {
      // Owner might be stored as just an ID string
      if (booking['owner'] is String) {
        ownerId = booking['owner'];
      } else if (booking['owner'] is Map && booking['owner']['_id'] != null) {
        ownerId = booking['owner']['_id'].toString();
      }
    }

    if (ownerId == null || ownerId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('owner_info_not_available')),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    final result = await _chatService.startOrGetConversation(ownerId);

    setState(() => _isLoading = false);

    if (result['success']) {
      // Backend returns conversation directly in data, or nested under 'conversation'
      final data = result['data'];
      final conversation = data is Map ? (data['conversation'] ?? data) : null;
      if (conversation != null && conversation['_id'] != null && mounted) {
        // Create ChatUser object for the cold storage owner
        final chatUser = ChatUser(
          id: ownerId,
          firstName: owner['firstName']?.toString() ?? ownerName,
          lastName: owner['lastName']?.toString() ?? '',
          role: 'coldStorage',
          isOnline: owner['isOnline'] ?? false,
          phone: owner['phone']?.toString(),
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
          // Header with storage info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.ac_unit, color: AppColors.primaryGreen),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coldStorage['name'] ?? 'Cold Storage',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      Text(
                        '${coldStorage['city'] ?? ''}, ${coldStorage['state'] ?? ''}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
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
                // Owner info
                Row(
                  children: [
                    const Icon(Icons.person, color: Colors.grey, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Owner: ${owner['firstName'] ?? ''} ${owner['lastName'] ?? ''}'.trim(),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Quantity and Duration
                Row(
                  children: [
                    Expanded(
                      child: _infoItem(
                        'Quantity',
                        '${booking['quantity'] ?? 0} Packets',
                        Icons.inventory_2,
                      ),
                    ),
                    Expanded(
                      child: _infoItem(
                        'Duration',
                        '${booking['duration'] ?? 0} Month(s)',
                        Icons.calendar_month,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Price and Dates
                Row(
                  children: [
                    Expanded(
                      child: _infoItem(
                        'Total Price',
                        '₹${booking['totalPrice'] ?? 0}',
                        Icons.currency_rupee,
                        valueColor: AppColors.primaryGreen,
                      ),
                    ),
                    Expanded(
                      child: _infoItem(
                        'Booked On',
                        _formatDate(booking['createdAt']),
                        Icons.access_time,
                      ),
                    ),
                  ],
                ),

                // Your Note
                if (booking['farmerNote'] != null && booking['farmerNote'].isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Note:',
                          style: TextStyle(
                            color: Colors.blue[700],
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

                // Owner Response (if rejected or accepted)
                if (booking['ownerResponse'] != null && booking['ownerResponse'].isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (status == 'rejected' ? Colors.red : Colors.green).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Owner Response:',
                          style: TextStyle(
                            color: status == 'rejected' ? Colors.red[700] : Colors.green[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          booking['ownerResponse'],
                          style: TextStyle(
                            fontSize: 14,
                            color: status == 'rejected' ? Colors.red[900] : Colors.green[900],
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
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  // Chat button - only show for accepted bookings
                  if (status == 'accepted') ...[                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _startChat,
                        icon: const Icon(Icons.chat),
                        label: Text(tr('chat_with_owner')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryGreen,
                          side: const BorderSide(color: AppColors.primaryGreen),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ] else if (status == 'pending') ...[                    // Message showing chat will be available after acceptance
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange[700], size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Chat available after booking is accepted',
                                style: TextStyle(
                                  color: Colors.orange[800],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Edit/Cancel buttons (only for pending)
                  if (status == 'pending') ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _editBooking,
                        icon: const Icon(Icons.edit),
                        label: Text(tr('edit')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: const BorderSide(color: Colors.blue),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _cancelBooking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(tr('cancel'), style: const TextStyle(color: Colors.white)),
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

  Widget _infoItem(String label, String value, IconData icon, {Color? valueColor}) {
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

class EditBookingDialog extends StatefulWidget {
  final Map<String, dynamic> booking;

  const EditBookingDialog({super.key, required this.booking});

  @override
  State<EditBookingDialog> createState() => _EditBookingDialogState();
}

class _EditBookingDialogState extends State<EditBookingDialog> {
  late TextEditingController _quantityController;
  late TextEditingController _noteController;
  late int _duration;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: widget.booking['quantity']?.toString() ?? '1',
    );
    _noteController = TextEditingController(
      text: widget.booking['farmerNote'] ?? '',
    );
    _duration = widget.booking['duration'] ?? 1;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pricePerTon = widget.booking['pricePerTon'] ?? 0;
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final totalPrice = quantity * pricePerTon * _duration;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.edit, color: AppColors.primaryGreen),
                    const SizedBox(width: 8),
                    Text(
                      'Edit Booking',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Quantity
                Text(
                  'Quantity (Packets)',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixText: 'Packets',
                  ),
                  validator: (value) {
                    final qty = int.tryParse(value ?? '') ?? 0;
                    if (qty <= 0) return 'Enter valid quantity';
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 16),

                // Duration
                Text(
                  'Duration (Months)',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [1, 3, 6, 12].map((months) {
                    final isSelected = _duration == months;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text('$months'),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) setState(() => _duration = months);
                          },
                          selectedColor: AppColors.primaryGreen,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Note
                Text(
                  'Note (Optional)',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: tr('special_requirements_hint'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Price Summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryGreen),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(tr('estimated_total')),
                      Text(
                        '₹$totalPrice',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            Navigator.pop(context, {
                              'quantity': int.tryParse(_quantityController.text) ?? 1,
                              'duration': _duration,
                              'farmerNote': _noteController.text.trim(),
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Update',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
