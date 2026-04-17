import 'dart:async';

import 'package:aloo_sbji_mandi/core/service/socket_service.dart';
import 'package:aloo_sbji_mandi/core/service/token_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Per-counter dashboard — shows Waiting / Processing / Finished stats,
/// processing tokens list, waiting queue, and action buttons for a single counter.
class CounterDetailDashboardScreen extends StatefulWidget {
  final String coldStorageId;
  final String? coldStorageName;
  final String counterId;
  final String counterName;
  final int counterNumber;

  const CounterDetailDashboardScreen({
    super.key,
    required this.coldStorageId,
    this.coldStorageName,
    required this.counterId,
    required this.counterName,
    required this.counterNumber,
  });

  @override
  State<CounterDetailDashboardScreen> createState() =>
      _CounterDetailDashboardScreenState();
}

class _CounterDetailDashboardScreenState
    extends State<CounterDetailDashboardScreen> {
  final TokenService _tokenService = TokenService();
  final SocketService _socketService = SocketService();
  Timer? _refreshTimer;

  bool _isLoading = true;
  String? _error;

  List<QueueToken> _allTokens = [];
  List<Map<String, dynamic>> _counterQueues = [];

  bool get isHindi => AppLocalizations.isHindi;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loadAll(),
    );
    _socketService.connect();
    _socketService.addTokenEventListener(_onTokenEvent);
  }

  void _onTokenEvent(Map<String, dynamic> data) {
    if (!mounted) return;
    final event = data['event'] as String?;
    if (event == 'token_queue_updated' ||
        event == 'token_request_pending' ||
        event == 'token_transferred' ||
        event == 'token_issued' ||
        event == 'token_completed' ||
        event == 'token_called' ||
        event == 'token_in_service') {
      _loadAll();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _socketService.removeTokenEventListener(_onTokenEvent);
    super.dispose();
  }

  Future<void> _loadAll() async {
    final result =
        await _tokenService.getTokenQueue(widget.coldStorageId);
    if (!mounted) return;
    if (result['success'] == true && result['data'] != null) {
      final d = result['data'];
      setState(() {
        _allTokens =
            (d['tokens'] as List? ?? []).map((j) => QueueToken.fromJson(j)).toList();
        if (d['counterQueues'] != null) {
          _counterQueues =
              List<Map<String, dynamic>>.from(d['counterQueues']);
        }
        _isLoading = false;
        _error = null;
      });
    } else {
      setState(() {
        _isLoading = false;
        _error = result['message'] ?? tr('failed_to_load');
      });
    }
  }

  // ════════════════════════════════════════════════════════════
  //                     COMPUTED DATA
  // ════════════════════════════════════════════════════════════

  List<QueueToken> get _processingTokens {
    return _allTokens.where((t) {
      return t.counterId == widget.counterId &&
          (t.status == 'called' || t.status == 'in-service');
    }).toList();
  }

  List<QueueToken> get _waitingTokens {
    return _allTokens.where((t) {
      return t.counterId == widget.counterId && t.status == 'waiting';
    }).toList()
      ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
  }

  int get _finishedCount {
    return _allTokens.where((t) {
      return t.counterId == widget.counterId && t.status == 'completed';
    }).length;
  }

  int get _waitingCount => _waitingTokens.length;
  int get _processingCount => _processingTokens.length;

  // ════════════════════════════════════════════════════════════
  //                         ACTIONS
  // ════════════════════════════════════════════════════════════

  Future<void> _callNextToken() async {
    _showLoadingDialog();

    final result = await _tokenService.callNextToken(
      widget.coldStorageId,
      counterId: widget.counterId,
      counterNumber: widget.counterNumber,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final tokenData = result['data']?['token'];
      final tokenId = tokenData?['_id']?.toString();

      // Auto-start serving
      if (tokenId != null) {
        await _tokenService.startServing(tokenId);
      }

      if (!mounted) return;
      Navigator.pop(context); // dismiss loading

      final tokenNum = tokenData?['tokenNumber'] ?? '';
      _showSnackBar(
        '🔄 ${tr('token_processing_notif')} $tokenNum',
        AppColors.primaryGreen,
      );
      _loadAll();
    } else {
      Navigator.pop(context);
      _showSnackBar(result['message'] ?? tr('no_waiting_tokens_msg'), Colors.orange);
    }
  }

  Future<void> _markFinished(QueueToken token) async {
    _showLoadingDialog();
    final result = await _tokenService.completeToken(token.id);

    if (!mounted) return;
    Navigator.pop(context);

    if (result['success'] == true) {
      _showSnackBar(
        '✅ ${tr('token_completed_notif')} #${token.tokenNumber}',
        AppColors.primaryGreen,
      );
      _loadAll();
    } else {
      _showSnackBar(result['message'] ?? tr('failed_msg'), Colors.red);
    }
  }

  Future<void> _skipToken(QueueToken token) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.skip_next_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            Text(tr('skip_token')),
          ],
        ),
        content: Text(
          '${tr('skip_token')} #${token.tokenNumber} (${token.farmerName})?',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel_btn')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text(tr('skip_btn')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _showLoadingDialog();
      final result = await _tokenService.skipToken(token.id);
      if (!mounted) return;
      Navigator.pop(context);
      if (result['success'] == true) {
        _showSnackBar('${tr('token_skipped')} #${token.tokenNumber}', Colors.orange);
        _loadAll();
      } else {
        _showSnackBar(result['message'] ?? tr('failed_msg'), Colors.red);
      }
    }
  }

  // ════════════════════════════════════════════════════════════
  //                           BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          widget.counterName,
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadAll();
            },
          ),
        ],
      ),
      floatingActionButton: _waitingCount > 0
          ? FloatingActionButton.extended(
              onPressed: _callNextToken,
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                tr('call_next'),
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Counter Info Header ──
            _buildCounterHeader(),
            const SizedBox(height: 16),

            // ── Stat Cards ──
            _buildStatCards(),
            const SizedBox(height: 20),

            // ── Processing Tokens ──
            _buildProcessingSection(),
            const SizedBox(height: 16),

            // ── Waiting Queue ──
            _buildWaitingSection(),
            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),
    );
  }

  static const _counterLetters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J'];

  String get _counterLabel {
    final idx = widget.counterNumber - 1;
    return (idx >= 0 && idx < _counterLetters.length)
        ? _counterLetters[idx]
        : '${widget.counterNumber}';
  }

  Widget _buildCounterHeader() {
    final serving = _processingTokens.isNotEmpty
        ? _processingTokens.first.tokenNumber
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryGreen, const Color(0xFF1B7A2B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              _counterLabel,
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.counterName,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  serving != null
                      ? '${tr('now_serving_label')} #$serving'
                      : tr('no_token_serving'),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          if (serving != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.circle, color: Colors.greenAccent, size: 10),
                  const SizedBox(width: 6),
                  Text(
                    tr('live_label'),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Stat Cards ──
  Widget _buildStatCards() {
    return Column(
      children: [
        // Waiting Card (orange)
        _buildGradientStatCard(
          count: _waitingCount,
          label: tr('waiting_label'),
          gradient: [const Color(0xFFE88D20), const Color(0xFFF5A623)],
          icon: Icons.access_time_rounded,
        ),
        const SizedBox(height: 10),
        // Processing Card (green-yellow)
        _buildGradientStatCard(
          count: _processingCount,
          label: tr('processing_label'),
          gradient: [const Color(0xFF3A8C2E), const Color(0xFF7AB648)],
          icon: Icons.settings_rounded,
        ),
        const SizedBox(height: 10),
        // Finished Card (dark green)
        _buildGradientStatCard(
          count: _finishedCount,
          label: tr('finished_label'),
          gradient: [AppColors.primaryGreen, const Color(0xFF1B7A2B)],
          icon: Icons.check_circle_rounded,
        ),
      ],
    );
  }

  Widget _buildGradientStatCard({
    required int count,
    required String label,
    required List<Color> gradient,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  // ── Processing Section ──
  Widget _buildProcessingSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.engineering_rounded,
                  color: AppColors.primaryGreen, size: 22),
              const SizedBox(width: 8),
              Text(
                tr('processing_tokens'),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_processingTokens.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_rounded, size: 40, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text(
                      tr('no_processing_tokens'),
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._processingTokens.map(_buildProcessingCard),
        ],
      ),
    );
  }

  Widget _buildProcessingCard(QueueToken token) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          // Token number badge
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              '#${token.tokenNumber.replaceAll('T-', '')}',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  token.farmerName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '+91 ${token.farmerPhone}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 2),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    token.purposeDisplay,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Mark Finished
          SizedBox(
            height: 42,
            child: ElevatedButton.icon(
              onPressed: () => _confirmMarkFinished(token),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(
                tr('mark_finished'),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Waiting Section ──
  Widget _buildWaitingSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.queue_rounded, color: Colors.orange, size: 22),
              const SizedBox(width: 8),
              Text(
                tr('waiting_queue'),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_waitingCount',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_waitingTokens.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 40, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text(
                      tr('no_waiting_tokens'),
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._waitingTokens.asMap().entries.map((entry) {
              return _buildWaitingCard(entry.value, entry.key + 1);
            }),
        ],
      ),
    );
  }

  Widget _buildWaitingCard(QueueToken token, int position) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          // Position badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              '$position',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.orange.shade800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '#${token.tokenNumber}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      token.farmerName,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '+91 ${token.farmerPhone}  •  ${token.purposeDisplay}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Skip button
          IconButton(
            onPressed: () => _skipToken(token),
            icon: Icon(Icons.skip_next_rounded,
                color: Colors.orange.shade700, size: 24),
            tooltip: tr('skip_tooltip'),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //                  CONFIRMATION DIALOGS
  // ════════════════════════════════════════════════════════════

  Future<void> _confirmMarkFinished(QueueToken token) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                tr('mark_finished_title'),
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          '${tr('mark_finished_confirm')} #${token.tokenNumber} (${token.farmerName})?',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel_btn')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: Text(tr('confirm')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _markFinished(token);
    }
  }

  // ════════════════════════════════════════════════════════════
  //                        ERROR / HELPERS
  // ════════════════════════════════════════════════════════════

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            _error ?? tr('error'),
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
              });
              _loadAll();
            },
            icon: const Icon(Icons.refresh),
            label: Text(tr('retry')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }
}
