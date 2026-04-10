import 'dart:async';

import 'package:aloo_sbji_mandi/core/service/socket_service.dart';
import 'package:aloo_sbji_mandi/core/service/token_service.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Real-time token queue status screen for the farmer.
/// Shows now-serving token, visual queue timeline, estimated wait, and notification toggle.
class LiveTokenStatusScreen extends StatefulWidget {
  final String tokenId;
  final String coldStorageId;
  final String coldStorageName;
  final String initialTokenNumber;
  final String initialCounterName;
  final int initialCounterNumber;

  const LiveTokenStatusScreen({
    super.key,
    required this.tokenId,
    required this.coldStorageId,
    required this.coldStorageName,
    required this.initialTokenNumber,
    required this.initialCounterName,
    required this.initialCounterNumber,
  });

  @override
  State<LiveTokenStatusScreen> createState() => _LiveTokenStatusScreenState();
}

class _LiveTokenStatusScreenState extends State<LiveTokenStatusScreen> {
  final TokenService _tokenService = TokenService();
  final SocketService _socketService = SocketService();
  Timer? _pollTimer;

  // Live state
  String _myTokenNumber = '';
  String _nowServing = '--';
  int _position = 0;
  int _estimatedWait = 0;
  String _counterName = '';
  int _counterNumber = 1;
  String _status = 'waiting';
  bool _notificationsOn = true;
  bool _isLoading = true;
  String? _error;

  // Queue snapshot: list of token numbers ahead + current + behind
  List<_QueueSlot> _queueSlots = [];

  @override
  void initState() {
    super.initState();
    _myTokenNumber = widget.initialTokenNumber;
    _counterName = widget.initialCounterName;
    _counterNumber = widget.initialCounterNumber;
    _fetchTokenStatus();
    _setupSocket();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _fetchTokenStatus(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _socketService.removeTokenEventListener(_onTokenEvent);
    super.dispose();
  }

  // ────────────────── Socket ──────────────────

  void _setupSocket() {
    _socketService.connect();
    _socketService.addTokenEventListener(_onTokenEvent);
  }

  void _onTokenEvent(Map<String, dynamic> data) {
    if (!mounted) return;
    final event = data['event'] as String?;

    switch (event) {
      case 'token_queue_update':
        setState(() {
          _position = data['position'] ?? _position;
          _estimatedWait = data['estimatedWaitMinutes'] ?? _estimatedWait;
          if (data['currentlyServing'] != null) {
            _nowServing = data['currentlyServing'].toString();
          }
          _counterNumber = data['counterNumber'] ?? _counterNumber;
          if (data['counterName'] != null) {
            _counterName = data['counterName'];
          }
        });
        _rebuildSlots();
        break;
      case 'token_called':
        _fetchTokenStatus();
        if (data['tokenNumber'] == _myTokenNumber) {
          setState(() => _status = 'called');
          _showCalledDialog();
        }
        break;
      case 'token_in_service':
        if (data['tokenNumber'] == _myTokenNumber) {
          setState(() => _status = 'in-service');
        }
        _fetchTokenStatus();
        break;
      case 'token_completed':
        if (data['tokenNumber'] == _myTokenNumber) {
          setState(() => _status = 'completed');
          _showCompletedSnack();
        }
        _fetchTokenStatus();
        break;
      case 'token_skipped':
        if (data['tokenNumber'] == _myTokenNumber) {
          setState(() => _status = 'skipped');
        }
        _fetchTokenStatus();
        break;
      case 'token_transferred':
        _fetchTokenStatus();
        break;
      default:
        break;
    }
  }

  // ────────────────── API ──────────────────

  Future<void> _fetchTokenStatus() async {
    final result = await _tokenService.getTokenStatus(widget.tokenId);
    if (!mounted) return;

    if (result['success'] == true && result['data'] != null) {
      final d = result['data'] as Map<String, dynamic>;
      final token = d['token'] ?? d;
      setState(() {
        _myTokenNumber = token['tokenNumber'] ?? _myTokenNumber;
        _status = token['status'] ?? _status;
        _position = d['position'] ?? token['positionInQueue'] ?? _position;
        _estimatedWait =
            d['estimatedWaitMinutes'] ?? token['estimatedWaitMinutes'] ?? _estimatedWait;
        _counterNumber = token['counterNumber'] ?? _counterNumber;
        if (token['counterName'] != null) {
          _counterName = token['counterName'];
        }
        if (d['currentlyServing'] != null) {
          _nowServing = d['currentlyServing'].toString();
        }
        _isLoading = false;
        _error = null;
      });

      // Build queue slots from counterQueue if available
      if (d['counterQueue'] is List) {
        _buildSlotsFromQueue(d['counterQueue'] as List);
      } else {
        _rebuildSlots();
      }
    } else {
      setState(() {
        _isLoading = false;
        _error = result['message'];
      });
    }
  }

  void _buildSlotsFromQueue(List queue) {
    final slots = <_QueueSlot>[];
    for (final item in queue) {
      final num = item['tokenNumber']?.toString() ?? '';
      final isMe = num == _myTokenNumber;
      final st = item['status'] ?? 'waiting';
      slots.add(_QueueSlot(
        tokenNumber: num,
        isMe: isMe,
        status: st,
      ));
    }
    // Make sure my token is in the list
    if (!slots.any((s) => s.isMe)) {
      slots.add(_QueueSlot(
        tokenNumber: _myTokenNumber,
        isMe: true,
        status: _status,
      ));
    }
    setState(() => _queueSlots = slots);
  }

  void _rebuildSlots() {
    // Synthetic slots when we don't have full queue
    if (_queueSlots.isNotEmpty) return; // keep existing if we have them
    final seq = _extractSequence(_myTokenNumber);
    final servingSeq = _extractSequence(_nowServing);
    if (seq == 0 || servingSeq == 0) return;

    final slots = <_QueueSlot>[];
    for (int i = servingSeq; i <= seq; i++) {
      final num = 'T-$i';
      slots.add(_QueueSlot(
        tokenNumber: num,
        isMe: i == seq,
        status: i == servingSeq ? 'in-service' : 'waiting',
      ));
    }
    setState(() => _queueSlots = slots);
  }

  int _extractSequence(String tokenNumber) {
    final cleaned = tokenNumber.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? 0;
  }

  // ────────────────── Dialogs ──────────────────

  void _showCalledDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('🔔 ', style: TextStyle(fontSize: 28)),
            Expanded(
              child: Text(
                'Your Turn!',
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
                    _myTokenNumber,
                    style: GoogleFonts.inter(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Go to $_counterName',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
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
              child: const Text(
                'OK, On My Way!',
                style: TextStyle(
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

  void _showCompletedSnack() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Service completed! Thank you.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 4),
      ),
    );
  }

  // ────────────────── UI ──────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0EA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5D4037),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Live Status – $_counterName',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchTokenStatus,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildBody(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchTokenStatus,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // If token is completed, show a done view
    if (_status == 'completed') {
      return _buildCompletedView();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          // ── Now Serving Card ──
          _buildNowServingCard(),
          const SizedBox(height: 28),

          // ── Queue Timeline ──
          _buildQueueTimeline(),
          const SizedBox(height: 28),

          // ── Estimated Time ──
          _buildEstimatedTime(),
          const SizedBox(height: 28),

          // ── Status Indicator ──
          if (_status == 'called' || _status == 'in-service')
            _buildActiveStatus(),
          if (_status == 'called' || _status == 'in-service')
            const SizedBox(height: 28),

          // ── Notification Toggle ──
          _buildNotificationToggle(),
          const SizedBox(height: 28),

          // ── Cancel Button ──
          if (_status == 'waiting')
            _buildCancelButton(),
        ],
      ),
    );
  }

  // ── Now Serving ──
  Widget _buildNowServingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Now Serving',
            style: GoogleFonts.inter(
              color: Colors.grey[500],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Token ${_formatShort(_nowServing)}',
            style: GoogleFonts.inter(
              color: const Color(0xFF3E2723),
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _counterName,
              style: GoogleFonts.inter(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Queue Timeline ──
  Widget _buildQueueTimeline() {
    // Show at most the last N tokens up to and including "me"
    final slotsToShow = _queueSlots.isNotEmpty
        ? _queueSlots
        : _buildSyntheticSlots();

    if (slotsToShow.isEmpty) {
      return const SizedBox.shrink();
    }

    // Limit to last 6 for visual clarity
    final visibleSlots = slotsToShow.length > 6
        ? slotsToShow.sublist(slotsToShow.length - 6)
        : slotsToShow;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Queue',
            style: GoogleFonts.inter(
              color: Colors.grey[500],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: visibleSlots.length,
              itemBuilder: (context, index) {
                final slot = visibleSlots[index];
                final isLast = index == visibleSlots.length - 1;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSlotCircle(slot),
                    if (!isLast)
                      Container(
                        width: 24,
                        height: 3,
                        color: slot.status == 'in-service' || slot.status == 'called'
                            ? const Color(0xFF5D4037)
                            : Colors.grey[300],
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotCircle(_QueueSlot slot) {
    final isServing = slot.status == 'in-service' || slot.status == 'called';
    final bgColor = slot.isMe
        ? AppColors.primaryGreen
        : isServing
            ? const Color(0xFF5D4037)
            : Colors.grey[200]!;
    final textColor = slot.isMe || isServing ? Colors.white : Colors.grey[600]!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: slot.isMe
                ? Border.all(color: AppColors.lightGreen, width: 3)
                : null,
            boxShadow: slot.isMe
                ? [
                    BoxShadow(
                      color: AppColors.primaryGreen.withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            _formatShort(slot.tokenNumber),
            style: GoogleFonts.inter(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          slot.isMe ? 'You' : (isServing ? 'Serving' : ''),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: slot.isMe ? AppColors.primaryGreen : const Color(0xFF5D4037),
          ),
        ),
      ],
    );
  }

  List<_QueueSlot> _buildSyntheticSlots() {
    final mySeq = _extractSequence(_myTokenNumber);
    final servingSeq = _extractSequence(_nowServing);
    if (mySeq == 0) return [];

    final slots = <_QueueSlot>[];
    final start = servingSeq > 0 ? servingSeq : (mySeq - _position).clamp(1, mySeq);

    for (int i = start; i <= mySeq; i++) {
      slots.add(_QueueSlot(
        tokenNumber: 'T-$i',
        isMe: i == mySeq,
        status: i == start ? 'in-service' : 'waiting',
      ));
    }
    return slots;
  }

  // ── Estimated Time ──
  Widget _buildEstimatedTime() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.access_time, color: Color(0xFFE65100), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimated Wait',
                  style: GoogleFonts.inter(
                    color: Colors.grey[500],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$_estimatedWait',
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF3E2723),
                        ),
                      ),
                      TextSpan(
                        text: ' Minutes',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF3E2723),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Position badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F0EA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  '$_position',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF3E2723),
                  ),
                ),
                Text(
                  'in queue',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Active Status (called / in-service) ──
  Widget _buildActiveStatus() {
    final isCalled = _status == 'called';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCalled
              ? [Colors.orange.shade600, Colors.orange.shade400]
              : [AppColors.primaryGreen, const Color(0xFF1B5E20)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isCalled ? Colors.orange : AppColors.primaryGreen)
                .withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCalled ? Icons.campaign : Icons.settings,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCalled ? 'Your Turn!' : 'In Service',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isCalled
                      ? 'Please go to $_counterName'
                      : 'Service is in progress',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Notification Toggle ──
  Widget _buildNotificationToggle() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            _notificationsOn ? Icons.notifications_active : Icons.notifications_off,
            color: _notificationsOn ? Colors.orange : Colors.grey,
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Notifications',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF3E2723),
              ),
            ),
          ),
          Switch(
            value: _notificationsOn,
            onChanged: (v) => setState(() => _notificationsOn = v),
            activeColor: AppColors.primaryGreen,
          ),
        ],
      ),
    );
  }

  // ── Cancel Button ──
  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: _confirmCancel,
        icon: const Icon(Icons.cancel_outlined),
        label: Text(
          'Cancel Token',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFE65100),
          side: const BorderSide(color: Color(0xFFE65100), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmCancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancel Token?', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to cancel this token? You will lose your position in the queue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final result = await _tokenService.cancelMyToken(widget.tokenId);
      if (mounted) {
        if (result['success'] == true) {
          Navigator.pop(context, 'cancelled');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to cancel'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ── Completed View ──
  Widget _buildCompletedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppColors.primaryGreen,
                size: 80,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Service Completed',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Token $_myTokenNumber at $_counterName',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'completed'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Done',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatShort(String tokenNumber) {
    return tokenNumber.replaceAll('T-', '');
  }
}

class _QueueSlot {
  final String tokenNumber;
  final bool isMe;
  final String status;

  _QueueSlot({
    required this.tokenNumber,
    required this.isMe,
    required this.status,
  });
}
