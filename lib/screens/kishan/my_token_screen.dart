import 'dart:async';

import 'package:aloo_sbji_mandi/core/service/booking_service.dart';
import 'package:aloo_sbji_mandi/core/service/cold_storage_service.dart';
import 'package:aloo_sbji_mandi/core/service/socket_service.dart';
import 'package:aloo_sbji_mandi/core/service/token_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/screens/kishan/live_token_status_screen.dart';
// Lane selection removed â€” farmer now just requests token, owner assigns counter
import 'package:aloo_sbji_mandi/screens/kishan/token_confirmed_screen.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/utils/ist_datetime.dart';

class MyTokenScreen extends StatefulWidget {
  const MyTokenScreen({super.key});

  @override
  State<MyTokenScreen> createState() => _MyTokenScreenState();
}

class _MyTokenScreenState extends State<MyTokenScreen> {
  final TokenService _tokenService = TokenService();
  final BookingService _bookingService = BookingService();
  final SocketService _socketService = SocketService();
  Timer? _refreshTimer;

  List<QueueToken> _myTokens = [];
  bool _isLoading = true;
  bool _isRequestingToken = false;
  String? _error;

  // Live position data from socket per cold storage (keyed by coldStorageId)
  final Map<String, Map<String, dynamic>> _liveData = {};

  @override
  void initState() {
    super.initState();
    _loadMyTokens();
    _setupSocketListeners();
    // Fallback polling every 30s (socket handles instant updates)
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadMyTokens(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _socketService.removeTokenEventListener(_onTokenEvent);
    super.dispose();
  }

  void _setupSocketListeners() {
    _socketService.connect();
    _socketService.addTokenEventListener(_onTokenEvent);
  }

  void _onTokenEvent(Map<String, dynamic> data) {
    final event = data['event'] as String?;
    if (!mounted) return;

    switch (event) {
      case 'token_called':
        // Our turn! Show alert dialog
        _loadMyTokens();
        _showTurnAlert(data);
        break;
      case 'token_nearby':
        // Turn is coming soon
        _loadMyTokens();
        _showNearbyAlert(data);
        break;
      case 'token_queue_update':
        // Real-time position update - instant, no API call needed
        final csId =
            data['coldStorageId']?.toString() ??
            data['tokenId']?.toString() ??
            '';
        if (csId.isNotEmpty) {
          setState(() {
            _liveData[csId] = {
              'position': data['position'],
              'estimatedWaitMinutes': data['estimatedWaitMinutes'],
              'currentlyServing': data['currentlyServing'],
              'totalWaiting': data['totalWaiting'],
              'counterNumber': data['counterNumber'],
              'counterName': data['counterName'],
            };
          });
        }
        break;
      case 'token_transferred':
        // Token moved to a different counter
        _loadMyTokens();
        _showSnackBar(
          trArgs('token_transferred_msg', {
            'counter': data['newCounterName'] ?? '${data['newCounterNumber'] ?? ''}',
          }),
          Colors.blue,
        );
        break;
      case 'token_issued':
        // Token approved by owner! Reload and show approval alert
        _loadMyTokens();
        _showTokenApprovedAlert(data);
        break;
      case 'token_rejected':
        // Token request rejected
        _loadMyTokens();
        _showSnackBar(
          trArgs('token_request_rejected_msg', {'reason': data['reason'] ?? ''}),
          Colors.red,
        );
        break;
      case 'token_skipped':
        _loadMyTokens();
        _showSnackBar(
          trArgs('token_skipped_msg', {'tokenNumber': data['tokenNumber'] ?? ''}),
          Colors.red,
        );
        break;
      case 'token_in_service':
        _loadMyTokens();
        break;
      case 'token_completed':
        _loadMyTokens();
        _showSnackBar(tr('service_completed'), Colors.green);
        break;
      default:
        _loadMyTokens();
    }
  }

  void _showTokenApprovedAlert(Map<String, dynamic> data) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 60,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              tr('token_approved'),
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                data['tokenNumber'] ?? '',
                style: GoogleFonts.inter(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              trArgs('token_position_wait', {
                'position': (data['position'] ?? '').toString(),
                'minutes': (data['estimatedWaitMinutes'] ?? 0).toString(),
              }),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            if (data['coldStorageName'] != null) ...[
              const SizedBox(height: 8),
              Text(
                data['coldStorageName'],
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                tr('got_it'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTurnAlert(Map<String, dynamic> data) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Text('ðŸ”” ', style: TextStyle(fontSize: 28)),
            Expanded(
              child: Text(
                tr('your_turn_now'),
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange, width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    data['tokenNumber'] ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    trArgs('go_to_counter_n', {'counter': '${data['counterNumber'] ?? 1}'}),
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                  if (data['coldStorageName'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      data['coldStorageName'],
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                tr('ok_on_my_way'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNearbyAlert(Map<String, dynamic> data) {
    if (!mounted) return;
    final position = data['position'] ?? 0;
    _showSnackBar(
      trArgs('people_ahead_get_ready', {'count': '$position'}),
      Colors.blue,
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _loadMyTokens() async {
    final result = await _tokenService.getMyTokens();

    if (result['success'] == true && result['data'] != null) {
      setState(() {
        _myTokens = (result['data'] as List)
            .map((json) => QueueToken.fromJson(json))
            .toList();
        _isLoading = false;
        _error = null;
      });
    } else {
      setState(() {
        _isLoading = false;
        _error = result['message'];
      });
    }
  }

  List<QueueToken> get _activeTokens =>
      _myTokens.where((t) => t.isActive).toList();

  List<QueueToken> get _inactiveTokens =>
      _myTokens.where((t) => !t.isActive).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(
        title: Text(
          tr('my_token_title'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isLoading
                ? null
                : () async {
                    setState(() => _isLoading = true);
                    await _loadMyTokens();
                  },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorView()
          : _myTokens.isEmpty
          ? _buildNoTokenView()
          : _buildTokenView(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isRequestingToken ? null : _showRequestTokenSheet,
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.confirmation_number_rounded),
        label: Text(
          tr('request_token'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error ?? 'Error', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadMyTokens,
            icon: const Icon(Icons.refresh),
            label: Text(tr('retry')),
          ),
        ],
      ),
    );
  }

  Widget _buildNoTokenView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.confirmation_number_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              tr('no_token_today'),
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              tr('get_token_hint'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isRequestingToken ? null : _showRequestTokenSheet,
              icon: const Icon(Icons.confirmation_number_rounded),
              label: Text(
                tr('request_token'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/cold_storage_listing');
              },
              icon: Icon(Icons.ac_unit, color: Colors.grey[600]),
              label: Text(
                tr('view_cold_storages'),
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenView() {
    final activeTokens = _activeTokens;
    final inactiveTokens = _inactiveTokens;

    return RefreshIndicator(
      onRefresh: _loadMyTokens,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // All active tokens as cards
            const SizedBox(height: 8),
            for (final token in activeTokens) _buildActiveTokenCard(token),

            // Past/inactive tokens today
            if (inactiveTokens.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 20,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('todays_tokens'),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${inactiveTokens.length}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: inactiveTokens.length,
                itemBuilder: (context, index) {
                  return _buildTokenListItem(inactiveTokens[index]);
                },
              ),
            ],

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTokenCard(QueueToken token) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    String statusHint;

    switch (token.status) {
      case 'pending':
        statusColor = Colors.amber.shade800;
        statusLabel = tr('pending_status');
        statusIcon = Icons.hourglass_top_rounded;
        statusHint = tr('owner_approval_wait');
        break;
      case 'waiting':
        statusColor = Colors.blue;
        statusLabel = tr('in_queue_status');
        statusIcon = Icons.timer;
        statusHint = token.counterName != null
            ? '${token.counterName} â€¢ ${tr('your_turn_coming')}'
            : tr('your_turn_coming');
        break;
      case 'called':
        statusColor = Colors.orange;
        statusLabel = tr('your_turn');
        statusIcon = Icons.notifications_active;
        statusHint = trArgs('go_to_counter_n', {'counter': token.counterName ?? '${token.counterNumber}'});
        break;
      case 'in-service':
        statusColor = Colors.purple;
        statusLabel = tr('status_in_service');
        statusIcon = Icons.engineering;
        statusHint = tr('being_served_now');
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = token.status;
        statusIcon = Icons.info;
        statusHint = '';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            // Navigate to live status for waiting/called tokens
            if (token.isWaiting || token.isCalled) {
              _navigateToLiveStatus(
                tokenId: token.id,
                coldStorageId: token.coldStorageId,
                coldStorageName: token.coldStorageName ?? '',
                tokenNumber: token.tokenNumber,
                counterName: token.counterName ?? 'Counter ${token.counterNumber}',
                counterNumber: token.counterNumber,
              );
            } else {
              _showTokenDetailSheet(token);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Colored left accent strip
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                // Token icon
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 0, 14),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          statusColor.withValues(alpha: 0.15),
                          statusColor.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.2),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: token.isPending
                        ? Icon(
                            Icons.hourglass_top_rounded,
                            color: statusColor,
                            size: 26,
                          )
                        : Text(
                            token.tokenNumber,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // Info column
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          token.coldStorageName ?? tr('cold_storage'),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${isHindi ? token.purposeDisplayHindi : token.purposeDisplay}'
                          '${token.expectedQuantity != null ? ' â€¢ ${token.expectedQuantity} ${unitAbbr(token.unit)}' : ''}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(statusIcon, size: 14, color: statusColor),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                statusHint,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Show position on card for waiting tokens
                        if (token.isWaiting && ((token.position ?? 0) > 0 || token.positionInQueue != null))
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Builder(
                              builder: (_) {
                                final live = _liveData[token.coldStorageId];
                                final pos = live?['position'] ?? token.positionInQueue ?? token.position;
                                final wait = live?['estimatedWaitMinutes'] ?? token.estimatedWaitMinutes;
                                return Text(
                                  '#$pos${wait > 0 ? ' â€¢ ~$wait min' : ''}',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Status badge + actions
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      // Edit & Delete for pending tokens
                      if (token.isPending) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => _showEditTokenSheet(token),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.edit, size: 16, color: Colors.blue.shade700),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => _confirmDeleteToken(token),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTokenListItem(QueueToken token) {
    Color statusColor;
    IconData statusIcon;
    switch (token.status) {
      case 'pending':
        statusColor = Colors.amber;
        statusIcon = Icons.hourglass_top;
        break;
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'skipped':
        statusColor = Colors.red;
        statusIcon = Icons.skip_next;
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        statusIcon = Icons.cancel;
        break;
      case 'rejected':
        statusColor = Colors.red.shade300;
        statusIcon = Icons.block;
        break;
      default:
        statusColor = Colors.blue;
        statusIcon = Icons.info;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: () => _showTokenDetailSheet(token),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: token.tokenNumber.isNotEmpty
                    ? Text(
                        token.tokenNumber,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                          fontSize: 13,
                        ),
                      )
                    : Icon(statusIcon, color: statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      token.coldStorageName ?? tr('cold_storage'),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${isHindi ? token.purposeDisplayHindi : token.purposeDisplay} â€¢ ${isHindi ? token.statusDisplayHindi : token.statusDisplay}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(statusIcon, color: statusColor, size: 22),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showTokenDetailSheet(QueueToken token) {
    Color statusColor;
    IconData statusIcon;
    switch (token.status) {
      case 'pending':
        statusColor = Colors.amber.shade800;
        statusIcon = Icons.hourglass_top;
        break;
      case 'waiting':
        statusColor = Colors.blue;
        statusIcon = Icons.timer;
        break;
      case 'called':
        statusColor = Colors.orange;
        statusIcon = Icons.notifications_active;
        break;
      case 'in-service':
        statusColor = Colors.purple;
        statusIcon = Icons.engineering;
        break;
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'skipped':
        statusColor = Colors.red;
        statusIcon = Icons.skip_next;
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        statusIcon = Icons.cancel;
        break;
      case 'rejected':
        statusColor = Colors.red.shade300;
        statusIcon = Icons.block;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Token number / pending badge
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    statusColor.withOpacity(0.1),
                    statusColor.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(statusIcon, color: statusColor, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    token.isPending
                        ? tr('request_sent_status')
                        : token.tokenNumber.isNotEmpty
                        ? token.tokenNumber
                        : '-',
                    style: GoogleFonts.inter(
                      fontSize: token.isPending ? 18 : 36,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isHindi ? token.statusDisplayHindi : token.statusDisplay,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Detail rows
            _detailRow(
              Icons.ac_unit,
              tr('cold_storage_label'),
              token.coldStorageName ?? '-',
            ),
            if (token.coldStorageAddress != null)
              _detailRow(
                Icons.location_on,
                tr('address_label'),
                token.coldStorageAddress!,
              ),
            _detailRow(
              Icons.inventory,
              tr('purpose_label'),
              isHindi ? token.purposeDisplayHindi : token.purposeDisplay,
            ),
            if (token.expectedQuantity != null)
              _detailRow(
                Icons.scale,
                tr('quantity_label'),
                '${token.expectedQuantity} ${unitAbbr(token.unit)}',
              ),
            if (token.position != null && token.isWaiting)
              Builder(
                builder: (_) {
                  final live = _liveData[token.coldStorageId];
                  return _detailRow(
                    Icons.format_list_numbered,
                    tr('position_in_queue'),
                    '${live?['position'] ?? token.position}',
                  );
                },
              ),
            if (token.estimatedWaitMinutes > 0 && token.isWaiting)
              Builder(
                builder: (_) {
                  final live = _liveData[token.coldStorageId];
                  return _detailRow(
                    Icons.timer,
                    tr('est_wait'),
                    '~${live?['estimatedWaitMinutes'] ?? token.estimatedWaitMinutes} min',
                  );
                },
              ),
            if (token.isWaiting)
              Builder(
                builder: (_) {
                  final live = _liveData[token.coldStorageId];
                  final totalWaiting = live?['totalWaiting'];
                  final currentlyServing =
                      live?['currentlyServing'] ?? token.currentlyServing;
                  return Column(
                    children: [
                      if (totalWaiting != null)
                        _detailRow(
                          Icons.people,
                          tr('total_in_queue'),
                          '$totalWaiting',
                        ),
                      if (currentlyServing != null)
                        _detailRow(
                          Icons.play_arrow,
                          tr('now_serving'),
                          '$currentlyServing',
                        ),
                    ],
                  );
                },
              ),
            if (token.counterName != null || token.counterNumber > 0)
              _detailRow(
                Icons.meeting_room,
                tr('counter_label'),
                token.counterName ?? '${token.counterNumber}',
              ),
            _detailRow(
              Icons.access_time,
              tr('requested_at'),
              _formatTime(token.issuedAt),
            ),
            if (token.calledAt != null)
              _detailRow(
                Icons.notifications,
                tr('called_at'),
                _formatTime(token.calledAt!),
              ),
            if (token.completedAt != null)
              _detailRow(
                Icons.done_all,
                tr('completed_at'),
                _formatTime(token.completedAt!),
              ),

            const SizedBox(height: 20),

            // Edit & Delete buttons for pending tokens
            if (token.isPending) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showEditTokenSheet(token);
                      },
                      icon: Icon(Icons.edit, color: Colors.blue.shade700),
                      label: Text(
                        tr('edit_token'),
                        style: TextStyle(color: Colors.blue.shade700),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.blue.shade700),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _confirmDeleteToken(token);
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: Text(
                        tr('delete_token'),
                        style: const TextStyle(color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Cancel button for active (non-pending) tokens  
            if (token.isActive && !token.isPending)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _cancelToken(token);
                  },
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: Text(
                    tr('cancel_btn'),
                    style: const TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final ist = dt.toIST();
    final hour = ist.hour > 12 ? ist.hour - 12 : (ist.hour == 0 ? 12 : ist.hour);
    final amPm = ist.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${ist.minute.toString().padLeft(2, '0')} $amPm';
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // TOKEN REQUEST FLOW (farmer requests, owner assigns counter)
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  void _navigateToLiveStatus({
    required String tokenId,
    required String coldStorageId,
    required String coldStorageName,
    required String tokenNumber,
    required String counterName,
    required int counterNumber,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveTokenStatusScreen(
          tokenId: tokenId,
          coldStorageId: coldStorageId,
          coldStorageName: coldStorageName,
          initialTokenNumber: tokenNumber,
          initialCounterName: counterName,
          initialCounterNumber: counterNumber,
        ),
      ),
    ).then((_) => _loadMyTokens());
  }

  Future<void> _showRequestTokenSheet() async {
    // Try bookings first, then fallback to all cold storages
    setState(() => _isRequestingToken = true);
    final result = await _bookingService.getMyBookings();
    setState(() => _isRequestingToken = false);

    List<Map<String, dynamic>> storages = [];

    if (result['success'] == true && result['data'] != null) {
      final rawData = result['data'];
      final List allBookings = (rawData is List)
          ? rawData
          : (rawData is Map ? (rawData['bookings'] ?? []) as List : []);
      final bookings = allBookings
          .where((b) => b['status'] == 'pending' || b['status'] == 'accepted')
          .toList();

      // Extract unique cold storages from accepted bookings
      final Map<String, Map<String, dynamic>> storageMap = {};
      for (final b in bookings) {
        final cs = b['coldStorage'];
        final owner = b['owner'];
        if (cs != null && cs['_id'] != null) {
          final ownerName = owner != null
              ? '${owner['firstName'] ?? ''} ${owner['lastName'] ?? ''}'.trim()
              : '';
          storageMap[cs['_id'].toString()] = {
            '_id': cs['_id'].toString(),
            'name': cs['name'] ?? 'Unknown',
            'city': cs['city'] ?? cs['village'] ?? cs['address'] ?? '',
            'ownerName': ownerName,
          };
        }
      }
      storages = storageMap.values.toList();
    }

    // Fallback: if no booked storages, load ALL cold storages
    if (storages.isEmpty) {
      setState(() => _isRequestingToken = true);
      final csService = ColdStorageService();
      final csResult = await csService.getAllColdStorages();
      setState(() => _isRequestingToken = false);

      if (csResult['success'] == true && csResult['data'] != null) {
        final csData = csResult['data'];
        final List csList = csData is List
            ? csData
            : (csData is Map ? (csData['coldStorages'] ?? []) as List : []);

        for (final cs in csList) {
          final owner = cs['owner'];
          final ownerName = owner is Map
              ? '${owner['firstName'] ?? ''} ${owner['lastName'] ?? ''}'.trim()
              : '';
          storages.add({
            '_id': cs['_id']?.toString() ?? '',
            'name': cs['name'] ?? 'Unknown',
            'city': cs['city'] ?? cs['village'] ?? cs['address'] ?? '',
            'ownerName': ownerName,
          });
        }
      }
    }

    if (storages.isEmpty) {
      _showSnackBar(
        tr('no_cold_storages_available'),
        Colors.orange,
      );
      return;
    }

    // Sort coldstorages alphabetically by name for easier selection
    storages.sort(
      (a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo(
        (b['name'] ?? '').toString().toLowerCase(),
      ),
    );

    if (!mounted) return;

    String selectedPurpose = 'storage';
    String selectedUnit = 'Packet';
    // Auto-select if farmer has only one cold storage
    String? selectedStorageId = storages.length == 1
        ? storages[0]['_id']
        : null;
    final quantityController = TextEditingController();
    final remarkController = TextEditingController();
    final searchController = TextEditingController();
    String searchQuery = '';

    final requestData = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
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
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(Icons.send_rounded, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      tr('request_token_title'),
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Cold Storage â€” auto-selected or dropdown for multiple
                Text(
                  tr('your_cold_storage'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (storages.length == 1)
                  // Single storage â€” show as a card (no dropdown needed)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      border: Border.all(color: Colors.blue.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.ac_unit, color: Colors.blue.shade700),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${storages[0]['name']} - ${storages[0]['city']}',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                              if ((storages[0]['ownerName'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                                Text(
                                  'Owner: ${storages[0]['ownerName']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade600,
                          size: 20,
                        ),
                      ],
                    ),
                  )
                else
                  // Multiple storages â€” searchable list
                  Column(
                    children: [
                      // Search field
                      TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: tr('search_cold_storage'),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () => setModalState(() {
                                    searchController.clear();
                                    searchQuery = '';
                                  }),
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10,
                          ),
                        ),
                        onChanged: (v) => setModalState(() {
                          searchQuery = v.trim().toLowerCase();
                        }),
                      ),
                      const SizedBox(height: 8),
                      // Filtered storage list
                      Builder(builder: (context) {
                        final filtered = storages.where((s) {
                          if (searchQuery.isEmpty) return true;
                          final name = (s['name'] ?? '').toString().toLowerCase();
                          final city = (s['city'] ?? '').toString().toLowerCase();
                          final owner = (s['ownerName'] ?? '').toString().toLowerCase();
                          return name.contains(searchQuery) ||
                              city.contains(searchQuery) ||
                              owner.contains(searchQuery);
                        }).toList();

                        if (filtered.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              tr('no_matching_storage'),
                              style: TextStyle(color: Colors.grey[500], fontSize: 13),
                            ),
                          );
                        }

                        return ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final s = filtered[index];
                              final id = s['_id']?.toString() ?? '';
                              final isSelected = selectedStorageId == id;
                              return GestureDetector(
                                onTap: () => setModalState(() {
                                  selectedStorageId = id;
                                }),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.blue.shade50
                                        : Colors.grey[50],
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.blue.shade300
                                          : Colors.grey[300]!,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.ac_unit,
                                          color: isSelected
                                              ? Colors.blue.shade700
                                              : Colors.grey,
                                          size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${s['name']} - ${s['city']}',
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: isSelected
                                                    ? Colors.blue.shade900
                                                    : Colors.black87,
                                              ),
                                            ),
                                            if ((s['ownerName'] ?? '')
                                                .toString()
                                                .isNotEmpty)
                                              Text(
                                                'Owner: ${s['ownerName']}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isSelected
                                                      ? Colors.blue.shade700
                                                      : Colors.grey[600],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(Icons.check_circle,
                                            color: Colors.green.shade600,
                                            size: 20),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                const SizedBox(height: 16),

                // Purpose
                Text(
                  tr('purpose'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _purposeChip(
                      'storage',
                      tr('storage_purpose'),
                      selectedPurpose,
                      (v) => setModalState(() => selectedPurpose = v),
                    ),
                    _purposeChip(
                      'withdrawal',
                      tr('withdrawal'),
                      selectedPurpose,
                      (v) => setModalState(() => selectedPurpose = v),
                    ),
                    _purposeChip(
                      'inspection',
                      tr('inspection'),
                      selectedPurpose,
                      (v) => setModalState(() => selectedPurpose = v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Unit selector
                Text(
                  tr('unit_label_token'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _unitChip(
                      'Packet',
                      tr('packet_label'),
                      selectedUnit,
                      (v) => setModalState(() => selectedUnit = v),
                    ),
                    const SizedBox(width: 8),
                    _unitChip(
                      'Quintal',
                      tr('quintal_label'),
                      selectedUnit,
                      (v) => setModalState(() => selectedUnit = v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Quantity
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: trArgs('quantity_in_unit', {
                      'unit': unitLabel(selectedUnit),
                    }),
                    prefixIcon: const Icon(Icons.scale),
                    suffixText: unitAbbr(selectedUnit),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Note / Remark (Optional)
                Text(
                  tr('remark_optional'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: remarkController,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: tr('remark_hint'),
                    prefixIcon: const Icon(Icons.note_alt_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (selectedStorageId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              tr('select_cold_storage'),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      Navigator.pop(context, {
                        'coldStorageId': selectedStorageId,
                        'purpose': selectedPurpose,
                        'quantity': double.tryParse(quantityController.text),
                        'unit': selectedUnit,
                        'remark': remarkController.text.trim().isNotEmpty
                            ? remarkController.text.trim()
                            : null,
                      });
                    },
                    icon: const Icon(Icons.send_rounded),
                    label: Text(
                      tr('send_request'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
    );

    if (requestData == null || !mounted) return;

    // Send the token request
    setState(() => _isRequestingToken = true);
    final response = await _tokenService.requestToken(
      coldStorageId: requestData['coldStorageId'],
      purpose: requestData['purpose'] ?? 'storage',
      expectedQuantity: requestData['quantity'],
      unit: requestData['unit'] ?? 'Packet',
      remark: requestData['remark'],
    );
    setState(() => _isRequestingToken = false);

    if (response['success'] == true) {
      _showSnackBar(
        tr('token_request_sent_success'),
        Colors.green,
      );
      _loadMyTokens();
    } else {
      _showSnackBar(
        response['message'] ?? 'Failed to send request',
        Colors.red,
      );
    }
    quantityController.dispose();
    remarkController.dispose();
    searchController.dispose();
  }

  Widget _purposeChip(
    String value,
    String label,
    String selected,
    Function(String) onTap,
  ) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Chip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        backgroundColor: isSelected ? Colors.blue.shade700 : Colors.grey[200],
        side: BorderSide.none,
      ),
    );
  }

  Widget _unitChip(
    String value,
    String label,
    String selected,
    Function(String) onTap,
  ) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Chip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        backgroundColor: isSelected ? Colors.orange.shade700 : Colors.grey[200],
        side: BorderSide.none,
      ),
    );
  }

  Future<void> _confirmDeleteToken(QueueToken token) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(tr('delete_token_q'), style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(tr('delete_token_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel_btn')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              tr('yes_delete'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final result = await _tokenService.deleteMyToken(token.id);
      if (result['success'] == true) {
        _showSnackBar(tr('token_deleted'), Colors.green);
        _loadMyTokens();
      } else {
        _showSnackBar(result['message'] ?? tr('failed'), Colors.red);
      }
    }
  }

  Future<void> _showEditTokenSheet(QueueToken token) async {
    String selectedPurpose = token.purpose;
    String selectedUnit = token.unit;
    final quantityController = TextEditingController(
      text: token.expectedQuantity != null ? '${token.expectedQuantity}' : '',
    );
    final remarkController = TextEditingController(text: token.notes ?? '');

    final updatedData = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
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
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(Icons.edit_note, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      tr('edit_token_title'),
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Show cold storage name
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.ac_unit, color: Colors.blue.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          token.coldStorageName ?? tr('cold_storage'),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Purpose
                Text(
                  tr('purpose'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _purposeChip(
                      'storage',
                      tr('storage_purpose'),
                      selectedPurpose,
                      (v) => setModalState(() => selectedPurpose = v),
                    ),
                    _purposeChip(
                      'withdrawal',
                      tr('withdrawal'),
                      selectedPurpose,
                      (v) => setModalState(() => selectedPurpose = v),
                    ),
                    _purposeChip(
                      'inspection',
                      tr('inspection'),
                      selectedPurpose,
                      (v) => setModalState(() => selectedPurpose = v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Unit selector
                Text(
                  tr('unit_label_token'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _unitChip(
                      'Packet',
                      tr('packet_label'),
                      selectedUnit,
                      (v) => setModalState(() => selectedUnit = v),
                    ),
                    const SizedBox(width: 8),
                    _unitChip(
                      'Quintal',
                      tr('quintal_label'),
                      selectedUnit,
                      (v) => setModalState(() => selectedUnit = v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Quantity
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: trArgs('quantity_in_unit', {
                      'unit': unitLabel(selectedUnit),
                    }),
                    prefixIcon: const Icon(Icons.scale),
                    suffixText: unitAbbr(selectedUnit),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Note / Remark (Optional)
                Text(
                  tr('remark_optional'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: remarkController,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: tr('remark_hint'),
                    prefixIcon: const Icon(Icons.note_alt_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Update button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context, {
                        'purpose': selectedPurpose,
                        'quantity': double.tryParse(quantityController.text),
                        'unit': selectedUnit,
                        'remark': remarkController.text.trim().isNotEmpty
                            ? remarkController.text.trim()
                            : '',
                      });
                    },
                    icon: const Icon(Icons.check),
                    label: Text(
                      tr('update_request'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
    );

    if (updatedData == null || !mounted) return;

    final result = await _tokenService.updateMyToken(
      tokenId: token.id,
      purpose: updatedData['purpose'],
      expectedQuantity: updatedData['quantity'],
      unit: updatedData['unit'],
      remark: updatedData['remark'],
    );

    if (result['success'] == true) {
      _showSnackBar(tr('token_updated'), Colors.green);
      _loadMyTokens();
    } else {
      _showSnackBar(result['message'] ?? tr('failed'), Colors.red);
    }
    quantityController.dispose();
    remarkController.dispose();
  }

  Future<void> _cancelToken(QueueToken token) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('cancel_token_q')),
        content: Text(
          trArgs('cancel_token_confirm_msg', {'tokenNumber': token.tokenNumber}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('no_btn')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(tr('yes_cancel_token')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await _tokenService.cancelMyToken(token.id);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('token_cancelled')),
            backgroundColor: Colors.green,
          ),
        );
        _loadMyTokens();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? tr('failed')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
