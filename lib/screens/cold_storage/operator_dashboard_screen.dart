import 'dart:async';

import 'package:aloo_sbji_mandi/core/service/cold_storage_service.dart';
import 'package:aloo_sbji_mandi/core/service/socket_service.dart';
import 'package:aloo_sbji_mandi/core/service/token_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/auth_error_helper.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OperatorDashboardScreen extends StatefulWidget {
  final String? coldStorageId;
  final String? coldStorageName;

  const OperatorDashboardScreen({
    super.key,
    this.coldStorageId,
    this.coldStorageName,
  });

  @override
  State<OperatorDashboardScreen> createState() =>
      _OperatorDashboardScreenState();
}

class _OperatorDashboardScreenState extends State<OperatorDashboardScreen> {
  final TokenService _tokenService = TokenService();
  final ColdStorageService _coldStorageService = ColdStorageService();
  final SocketService _socketService = SocketService();
  Timer? _refreshTimer;

  String? _coldStorageId;
  String? _coldStorageName;

  bool _isLoading = true;
  String? _error;
  bool _isAuthError = false;

  // Counters / Lanes
  List<CounterInfo> _counters = [];
  String? _selectedCounterId;

  // Queue data
  List<Map<String, dynamic>> _counterQueues = [];
  List<QueueToken> _allTokens = [];

  bool get isHindi => AppLocalizations.isHindi;

  @override
  void initState() {
    super.initState();
    _coldStorageId = widget.coldStorageId;
    _coldStorageName = widget.coldStorageName;
    _init();
  }

  Future<void> _init() async {
    if (_coldStorageId == null) {
      try {
        final result = await _coldStorageService.getMyColdStorages();
        if (result['success'] == true && result['data'] != null) {
          dynamic storages;
          final data = result['data'];
          if (data is Map) {
            storages =
                data['coldStorages'] ?? data['data'] ?? data['cold_storages'];
          } else if (data is List) {
            storages = data;
          }
          if (storages != null && storages is List && storages.isNotEmpty) {
            final storage = storages.first;
            setState(() {
              _coldStorageId = storage['_id']?.toString();
              _coldStorageName =
                  storage['name']?.toString() ?? 'My Cold Storage';
            });
          }
        } else {
          if (!mounted) return;
          final isAuth = AuthErrorHelper.isAuthError(
            result['message']?.toString(),
            statusCode: result['statusCode'] as int?,
          );
          setState(() {
            _isLoading = false;
            _isAuthError = isAuth;
            _error = isAuth
                ? AuthErrorHelper.getAuthErrorMessage(isHindi: isHindi)
                : (result['message']?.toString() ??
                    tr('cold_storage_load_failed'));
          });
          return;
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _error = 'Error: $e';
        });
        return;
      }
    }

    if (_coldStorageId != null) {
      await _loadAll();
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 20),
        (_) => _loadAll(),
      );
      _socketService.connect();
      _socketService.addTokenEventListener(_onTokenEvent);
    } else {
      setState(() {
        _isLoading = false;
        _error = tr('cold_storage_not_found');
      });
    }
  }

  void _onTokenEvent(Map<String, dynamic> data) {
    if (!mounted) return;
    final event = data['event'] as String?;
    if (event == 'token_queue_updated' ||
        event == 'token_request_pending' ||
        event == 'token_transferred' ||
        event == 'token_issued' ||
        event == 'token_completed') {
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
    if (_coldStorageId == null) return;
    await Future.wait([_loadQueue(), _loadCounters()]);
  }

  Future<void> _loadQueue() async {
    final result = await _tokenService.getTokenQueue(_coldStorageId!);
    if (!mounted) return;
    if (result['success'] == true && result['data'] != null) {
      final d = result['data'];
      setState(() {
        _allTokens = (d['tokens'] as List)
            .map((j) => QueueToken.fromJson(j))
            .toList();
        if (d['counterQueues'] != null) {
          _counterQueues =
              List<Map<String, dynamic>>.from(d['counterQueues']);
        }
        _isLoading = false;
        _error = null;
      });
    } else {
      final isAuth = AuthErrorHelper.isAuthError(
        result['message']?.toString(),
        statusCode: result['statusCode'] as int?,
      );
      setState(() {
        _isLoading = false;
        _isAuthError = isAuth;
        _error = isAuth
            ? AuthErrorHelper.getAuthErrorMessage(isHindi: isHindi)
            : (result['message'] ?? 'Failed to load');
      });
    }
  }

  Future<void> _loadCounters() async {
    final result = await _tokenService.getCounters(_coldStorageId!);
    if (!mounted) return;
    if (result['success'] == true && result['data'] != null) {
      final data = result['data'];
      final list = data is List ? data : (data['counters'] as List? ?? []);
      setState(() {
        _counters = list
            .map((j) => CounterInfo.fromJson(j as Map<String, dynamic>))
            .toList();
        // Auto-select first counter if none selected
        if (_selectedCounterId == null && _counters.isNotEmpty) {
          _selectedCounterId = _counters.first.id;
        }
      });
    }
  }

  // ════════════════════════════════════════════════════════════
  //                  COMPUTED DATA FOR SELECTED LANE
  // ════════════════════════════════════════════════════════════

  Map<String, dynamic>? get _selectedCounterQueue {
    if (_selectedCounterId == null) return null;
    try {
      return _counterQueues.firstWhere((cq) {
        final id =
            cq['counter']?['_id']?.toString() ?? cq['counterId']?.toString();
        return id == _selectedCounterId;
      });
    } catch (_) {
      return null;
    }
  }

  /// Tokens being processed (called / in-service)
  List<QueueToken> get _processingTokens {
    return _allTokens.where((t) {
      final match = _selectedCounterId == null ||
          t.counterId == _selectedCounterId;
      return match && (t.status == 'called' || t.status == 'in-service');
    }).toList();
  }

  /// Waiting tokens
  List<QueueToken> get _waitingTokens {
    return _allTokens.where((t) {
      final match = _selectedCounterId == null ||
          t.counterId == _selectedCounterId;
      return match && t.status == 'waiting';
    }).toList()
      ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
  }

  /// Finished tokens
  int get _finishedCount {
    return _allTokens.where((t) {
      final match = _selectedCounterId == null ||
          t.counterId == _selectedCounterId;
      return match && t.status == 'completed';
    }).length;
  }

  int get _waitingCount => _waitingTokens.length;
  int get _processingCount => _processingTokens.length;

  // ════════════════════════════════════════════════════════════
  //                         ACTIONS
  // ════════════════════════════════════════════════════════════

  Future<void> _moveToProcessing() async {
    if (_coldStorageId == null) return;

    _showLoadingDialog();

    // Determine counter info for the call
    final selectedCounter = _selectedCounterId != null
        ? _counters.where((c) => c.id == _selectedCounterId).firstOrNull
        : (_counters.isNotEmpty ? _counters.first : null);

    // Step 1: Call next token (waiting → called)
    final callResult = await _tokenService.callNextToken(
      _coldStorageId!,
      counterId: selectedCounter?.id,
      counterNumber: selectedCounter?.number ?? 1,
    );

    if (!mounted) return;

    if (callResult['success'] == true) {
      final tokenData = callResult['data']?['token'];
      final tokenId = tokenData?['_id']?.toString();

      // Step 2: Start serving (called → in-service)
      if (tokenId != null) {
        await _tokenService.startServing(tokenId);
      }

      if (!mounted) return;
      Navigator.pop(context); // dismiss loading

      final tokenNum = tokenData?['tokenNumber'] ?? '';
      _showSnackBar(
        isHindi
            ? '🔄 टोकन $tokenNum प्रोसेसिंग में भेजा गया'
            : '🔄 Token $tokenNum moved to processing',
        AppColors.primaryGreen,
      );
      _loadAll();
    } else {
      Navigator.pop(context);
      _showSnackBar(callResult['message'] ?? 'Failed', Colors.red);
    }
  }

  Future<void> _markFinished(QueueToken token) async {
    _showLoadingDialog();

    final result = await _tokenService.completeToken(token.id);

    if (!mounted) return;
    Navigator.pop(context);

    if (result['success'] == true) {
      _showSnackBar(
        isHindi
            ? '✅ टोकन #${token.tokenNumber} पूरा हुआ'
            : '✅ Token #${token.tokenNumber} completed',
        AppColors.primaryGreen,
      );
      _loadAll();
    } else {
      _showSnackBar(result['message'] ?? 'Failed', Colors.red);
    }
  }

  // ════════════════════════════════════════════════════════════
  //                          BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          tr('token_dashboard'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
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
            // ── Lane Dropdown ──
            _buildLaneDropdown(),
            const SizedBox(height: 16),

            // ── Stat Cards ──
            _buildStatCards(),
            const SizedBox(height: 20),

            // ── Processing Tokens ──
            _buildProcessingSection(),
            const SizedBox(height: 16),

            // ── Waiting Queue ──
            _buildWaitingSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Lane Dropdown ──
  Widget _buildLaneDropdown() {
    final activeCounters = _counters.where((c) => c.isActive).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCounterId,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
          hint: Text(
            tr('select_lane'),
            style: GoogleFonts.inter(color: Colors.grey),
          ),
          items: activeCounters.map((counter) {
            return DropdownMenuItem<String>(
              value: counter.id,
              child: Text(counter.name),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedCounterId = value;
            });
          },
        ),
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
          Text(
            tr('processing_tokens'),
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          if (_processingTokens.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  tr('no_processing_tokens'),
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ),
            )
          else
            ..._processingTokens.map((token) => _buildProcessingCard(token)),
        ],
      ),
    );
  }

  Widget _buildProcessingCard(QueueToken token) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${token.tokenNumber}',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  token.farmerName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '+91 ${token.farmerPhone}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 42,
            child: ElevatedButton(
              onPressed: () => _confirmMarkFinished(token),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: Text(
                tr('mark_finished'),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
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
              Text(
                tr('waiting_queue'),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Text(
                '$_waitingCount',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_waitingTokens.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  tr('no_waiting_tokens'),
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ),
            )
          else
            ..._waitingTokens.map((token) => _buildWaitingCard(token)),
        ],
      ),
    );
  }

  Widget _buildWaitingCard(QueueToken token) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${token.tokenNumber}',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  token.farmerName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '+91 ${token.farmerPhone}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 42,
            child: ElevatedButton(
              onPressed: () => _confirmMoveToProcessing(token),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(
                tr('move_to_processing'),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //                   CONFIRMATION DIALOGS
  // ════════════════════════════════════════════════════════════

  Future<void> _confirmMoveToProcessing(QueueToken token) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.play_circle_filled, color: Colors.orange.shade700, size: 28),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                tr('move_to_processing_title'),
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          isHindi
              ? 'अगले टोकन को प्रोसेसिंग में भेजें?\n\nयह कतार में अगले टोकन (#${token.tokenNumber}) को प्रोसेसिंग में ले जाएगा।'
              : 'Move next token to processing?\n\nThis will move the next token in queue (#${token.tokenNumber}) to processing.',
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

    if (confirm == true) {
      _moveToProcessing();
    }
  }

  Future<void> _confirmMarkFinished(QueueToken token) async {
    final confirm = await showDialog<bool>(
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
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          isHindi
              ? 'टोकन #${token.tokenNumber} (${token.farmerName}) को पूर्ण चिह्नित करें?'
              : 'Mark token #${token.tokenNumber} (${token.farmerName}) as finished?',
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

    if (confirm == true) {
      _markFinished(token);
    }
  }

  // ════════════════════════════════════════════════════════════
  //                       ERROR / HELPERS
  // ════════════════════════════════════════════════════════════

  Widget _buildErrorView() {
    if (_isAuthError) {
      return AuthErrorHelper.buildSessionExpiredView(
        context: context,
        isHindi: isHindi,
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Error',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
              });
              _init();
            },
            child: Text(tr('retry')),
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
