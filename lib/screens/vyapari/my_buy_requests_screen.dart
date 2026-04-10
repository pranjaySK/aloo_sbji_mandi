import 'package:aloo_sbji_mandi/core/models/chat_models.dart';
import 'package:aloo_sbji_mandi/core/service/buy_request_notification_state.dart';
import 'package:aloo_sbji_mandi/core/service/chat_service.dart';
import 'package:aloo_sbji_mandi/core/service/trader_request_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/toast_helper.dart';
import 'package:aloo_sbji_mandi/screens/chat/chat_detail_screen.dart';
import 'package:aloo_sbji_mandi/screens/vyapari/create_buy_request_screen.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/utils/ist_datetime.dart';

class MyBuyRequestsScreen extends StatefulWidget {
  const MyBuyRequestsScreen({super.key});

  @override
  State<MyBuyRequestsScreen> createState() => _MyBuyRequestsScreenState();
}

class _MyBuyRequestsScreenState extends State<MyBuyRequestsScreen> {
  final TraderRequestService _requestService = TraderRequestService();
  final ChatService _chatService = ChatService();

  List<dynamic> _requests = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    BuyRequestNotificationState.markSeen();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _requestService.getMyRequests();

    setState(() {
      _isLoading = false;
      if (result['success']) {
        _requests = result['data']['requests'] ?? [];
      } else {
        _error = result['message'];
      }
    });
  }

  Future<void> _startChatWithFarmer(Map<String, dynamic> response) async {
    final farmer = response['farmer'];
    if (farmer == null || farmer['_id'] == null) {
      ToastHelper.showError(context, 'Farmer info not available');
      return;
    }

    final farmerId = farmer['_id'].toString();
    final farmerName =
        '${farmer['firstName'] ?? ''} ${farmer['lastName'] ?? ''}'.trim();

    final result = await _chatService.startOrGetConversation(farmerId);

    if (result['success']) {
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
              contextType: 'buy_request',
            ),
          ),
        );
      }
    } else {
      ToastHelper.showError(
        context,
        result['message'] ?? 'Could not start chat',
      );
    }
  }

  Future<void> _acceptResponse(String requestId, String responseId) async {
    final result = await _requestService.updateResponseStatus(
      requestId: requestId,
      responseId: responseId,
      status: 'accepted',
    );

    if (result['success']) {
      ToastHelper.showSuccess(
        context,
        'Response accepted! You can now chat with the farmer.',
      );
      _loadRequests();
    } else {
      ToastHelper.showError(context, result['message'] ?? 'Failed');
    }
  }

  Future<void> _rejectResponse(String requestId, String responseId) async {
    final result = await _requestService.updateResponseStatus(
      requestId: requestId,
      responseId: responseId,
      status: 'rejected',
    );

    if (result['success']) {
      ToastHelper.showInfo(context, 'Response rejected');
      _loadRequests();
    } else {
      ToastHelper.showError(context, result['message'] ?? 'Failed');
    }
  }

  Future<void> _editRequest(Map<String, dynamic> request) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateBuyRequestScreen(
          existingRequest: request,
        ),
      ),
    );
    if (result == true) _loadRequests();
  }

  Future<void> _deleteRequest(Map<String, dynamic> request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 28),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Delete Request?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete your buy request for "${request['potatoVariety'] ?? 'Potato'}"?\n\nThis action cannot be undone.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              tr('cancel'),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final requestId = request['_id']?.toString() ?? '';
      final result = await _requestService.cancelRequest(requestId);
      if (result['success']) {
        // Immediately remove from local list so it disappears from screen
        setState(() {
          _requests.removeWhere((r) => r['_id']?.toString() == requestId);
        });
        ToastHelper.showSuccess(context, 'Request deleted successfully');
      } else {
        ToastHelper.showError(
          context,
          result['message'] ?? 'Failed to delete request',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'My Buy Requests',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadRequests,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateBuyRequestScreen(),
            ),
          );
          if (result == true) _loadRequests();
        },
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'New Request',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
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
                    onPressed: _loadRequests,
                    child: Text(tr('retry')),
                  ),
                ],
              ),
            )
          : _requests.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadRequests,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _requests.length,
                itemBuilder: (context, index) {
                  return _buildRequestCard(_requests[index]);
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No buy requests yet',
            style: GoogleFonts.inter(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Post what potatoes you need and\nfarmers will respond!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateBuyRequestScreen(),
                ),
              );
              if (result == true) _loadRequests();
            },
            icon: const Icon(Icons.add),
            label: Text(tr('create_buy_request')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final status = request['status'] ?? 'open';
    final responses = (request['responses'] as List?) ?? [];
    final createdAt = DateTime.tryParse(request['createdAt'] ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    request['potatoVariety'] ?? 'Potato',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _statusChip(status),
                if (status == 'open' || status == 'fulfilled') ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Icons.edit,
                        size: 18,
                        color: status == 'fulfilled'
                            ? Colors.grey[400]
                            : Colors.blue[700],
                      ),
                      tooltip: status == 'fulfilled'
                          ? 'Cannot edit fulfilled request'
                          : 'Edit',
                      onPressed: status == 'fulfilled'
                          ? () {
                              ToastHelper.showInfo(
                                context,
                                'Cannot edit a fulfilled request',
                              );
                            }
                          : () => _editRequest(request),
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: Colors.red[700],
                      tooltip: 'Delete',
                      onPressed: () => _deleteRequest(request),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow(
                  Icons.scale,
                  'Quantity',
                  '${request['quantity']} packets',
                ),
                _detailRow(
                  Icons.currency_rupee,
                  'Max Price',
                  '₹${request['maxPricePerQuintal']}/packet',
                ),
                _detailRow(
                  Icons.straighten,
                  'Type',
                  '${request['potatoType'] ?? 'Any'} • Size: ${request['size'] ?? 'Any'}',
                ),
                if (createdAt != null)
                  _detailRow(
                    Icons.access_time,
                    'Posted',
                    DateFormat('dd MMM yyyy').format(createdAt.toIST()),
                  ),
              ],
            ),
          ),

          // Responses Section
          if (responses.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.people, size: 20, color: Colors.grey[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Farmer Responses (${responses.length})',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...responses.map(
                    (resp) => _buildResponseTile(
                      request['_id'],
                      resp,
                      'Packet',
                    ),
                  ),
                ],
              ),
            ),
          ] else if (status == 'open') ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.hourglass_empty,
                    color: Colors.orange[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Waiting for farmer responses...',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResponseTile(
    String requestId,
    Map<String, dynamic> response,
    String unit,
  ) {
    final farmer = response['farmer'] ?? {};
    final farmerName =
        '${farmer['firstName'] ?? ''} ${farmer['lastName'] ?? ''}'.trim();
    final status = response['status'] ?? 'pending';
    final responseId = response['_id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant(context),
        borderRadius: BorderRadius.circular(12),
        border: status == 'accepted'
            ? Border.all(color: Colors.green, width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryGreen.withOpacity(0.2),
                child: const Icon(
                  Icons.person,
                  size: 18,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      farmerName.isEmpty ? 'Farmer' : farmerName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '₹${response['offeredPrice']}/${unitAbbr(unit)} • ${response['offeredQuantity']} ${unitAbbr(unit)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              _responseStatusChip(status),
            ],
          ),
          if (response['message'] != null &&
              response['message'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '"${response['message']}"',
              style: TextStyle(
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Action buttons
          Row(
            children: [
              if (status == 'pending') ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectResponse(requestId, responseId),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: Text(tr('reject')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _acceptResponse(requestId, responseId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(tr('accept')),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _startChatWithFarmer(response),
                    icon: const Icon(Icons.chat, size: 18),
                    label: Text(tr('chat_with_farmer')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _responseStatusChip(String status) {
    Color color;
    switch (status) {
      case 'accepted':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.blue;
      case 'fulfilled':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'expired':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }
}
