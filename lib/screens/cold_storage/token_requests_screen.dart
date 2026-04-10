import 'dart:async';

import 'package:aloo_sbji_mandi/core/service/cold_storage_service.dart';
import 'package:aloo_sbji_mandi/core/service/socket_service.dart';
import 'package:aloo_sbji_mandi/core/service/token_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/auth_error_helper.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TokenRequestsScreen extends StatefulWidget {
  final String? coldStorageId;
  final String? coldStorageName;

  const TokenRequestsScreen({
    super.key,
    this.coldStorageId,
    this.coldStorageName,
  });

  @override
  State<TokenRequestsScreen> createState() => _TokenRequestsScreenState();
}

class _TokenRequestsScreenState extends State<TokenRequestsScreen> {
  final TokenService _tokenService = TokenService();
  final ColdStorageService _coldStorageService = ColdStorageService();
  final SocketService _socketService = SocketService();
  Timer? _refreshTimer;

  String? _coldStorageId;
  String? _coldStorageName;
  List<QueueToken> _pendingTokens = [];
  List<CounterInfo> _counters = [];
  bool _isLoading = true;
  String? _error;
  bool _isAuthError = false;

  bool get isHindi => AppLocalizations.isHindi;

  @override
  void initState() {
    super.initState();
    _coldStorageId = widget.coldStorageId;
    _coldStorageName = widget.coldStorageName;
    _initializeAndLoad();
  }

  Future<void> _initializeAndLoad() async {
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
      await Future.wait([
        _loadPendingTokens(),
        _loadCounters(),
      ]);
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _loadPendingTokens(),
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
    final event = data['event'] as String?;
    if (!mounted) return;

    if (event == 'token_request_pending' ||
        event == 'token_queue_updated') {
      _loadPendingTokens();
      if (event == 'token_request_pending') {
        _showSnackBar(
          isHindi
              ? '🆕 ${trArgs('new_token_request_notif', {'name': data['farmerName'] ?? ''})}'
              : '🆕 New token request: ${data['farmerName'] ?? ''}',
          Colors.blue,
        );
      }
    }
  }

  Future<void> _loadPendingTokens() async {
    if (_coldStorageId == null) return;
    try {
      final result = await _tokenService.getTokenQueue(_coldStorageId!);
      if (!mounted) return;

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        final allTokens = (data['tokens'] as List)
            .map((json) => QueueToken.fromJson(json))
            .toList();
        setState(() {
          _pendingTokens =
              allTokens.where((t) => t.status == 'pending').toList();
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Error: $e';
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _socketService.removeTokenEventListener(_onTokenEvent);
    super.dispose();
  }

  Future<void> _loadCounters() async {
    if (_coldStorageId == null) return;
    try {
      final result = await _tokenService.getCounters(_coldStorageId!);
      if (!mounted) return;
      if (result['success'] == true && result['data'] != null) {
        final countersData = result['data']['counters'];
        if (countersData is List) {
          setState(() {
            _counters =
                countersData.map((c) => CounterInfo.fromJson(c)).toList();
          });
        }
      }
    } catch (_) {
      // Silently ignore — cards will just show default value
    }
  }

  int get _currentServiceTime {
    if (_counters.isNotEmpty) {
      return _counters.first.averageServiceTime;
    }
    return 10; // default
  }

  // ════════════════════════════════════════════════════════════
  //                          BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(
        title: Text(
          tr('token_requests'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          if (_pendingTokens.isNotEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_pendingTokens.length}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildErrorView();
    }
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_loadPendingTokens(), _loadCounters()]);
      },
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // ── Summary Cards Row ──
          _buildSummaryCards(),
          const SizedBox(height: 16),
          // ── Request List or Empty ──
          if (_pendingTokens.isEmpty)
            _buildEmptyView()
          else
            ..._pendingTokens.map((t) => _buildRequestCard(t)),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        // ── Pending Requests Card ──
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade400, Colors.deepOrange.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.assignment_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${_pendingTokens.length}',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('pending_requests'),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // ── Time Settings Card ──
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade400, Colors.green.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.timer_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const Spacer(),
                    // Clock icon button to open settings
                    InkWell(
                      onTap: _showTimeSettingsDialog,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.access_time_filled,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '$_currentServiceTime ${tr('min_label')}',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('min_per_100_packets'),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyView() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            tr('no_pending_requests'),
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr('token_requests_empty_sub'),
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }

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
              _initializeAndLoad();
            },
            child: Text(tr('retry')),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //                     REQUEST CARD
  // ════════════════════════════════════════════════════════════

  Widget _buildRequestCard(QueueToken token) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.orange.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: Token Number + Badge ──
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#${token.tokenNumber.isNotEmpty ? token.tokenNumber : token.sequenceNumber}',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _coldStorageName ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Text(
                    tr('pending_tab'),
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // ── Farmer Info ──
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green.shade50,
                  radius: 22,
                  child: Text(
                    token.farmerName.isNotEmpty
                        ? token.farmerName[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
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
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            token.farmerPhone,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Purpose + Quantity Row ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.assignment_outlined,
                      size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    token.purposeDisplay,
                    style: GoogleFonts.inter(
                      color: Colors.grey[700],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (token.expectedQuantity != null) ...[
                    const Spacer(),
                    Icon(Icons.scale, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      '${token.expectedQuantity} ${unitAbbr(token.unit)}',
                      style: GoogleFonts.inter(
                        color: Colors.grey[700],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Action Buttons ──
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () => _showRejectDialog(token),
                      icon: const Icon(Icons.close, size: 18),
                      label: Text(
                        tr('reject_btn'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () => _showApproveDialog(token),
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(
                        tr('approve_btn'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //                 TIME SETTINGS DIALOG
  // ════════════════════════════════════════════════════════════

  Future<void> _showTimeSettingsDialog() async {
    final controller =
        TextEditingController(text: '$_currentServiceTime');
    bool isUpdating = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.timer_outlined,
                    color: Colors.teal.shade600, size: 24),
              ),
              const SizedBox(width: 10),
              Text(
                tr('time_settings'),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('time_per_100_packets'),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. 10',
                  suffixText: tr('min_label'),
                  suffixStyle: GoogleFonts.inter(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.teal.shade400, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tr('valid_for_new_tokens'),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed:
                  isUpdating ? null : () => Navigator.pop(ctx),
              child: Text(tr('cancel_btn')),
            ),
            ElevatedButton(
              onPressed: isUpdating
                  ? null
                  : () async {
                      final val = int.tryParse(controller.text.trim());
                      if (val == null || val <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(tr('enter_valid_time')),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      setDialogState(() => isUpdating = true);
                      await _updateServiceTime(val);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade500,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
              child: isUpdating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      tr('update_btn'),
                      style:
                          GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _updateServiceTime(int minutes) async {
    if (_counters.isEmpty) {
      _showSnackBar(tr('no_counters_found'), Colors.red);
      return;
    }
    // Update all counters with the new average service time
    bool anySuccess = false;
    for (final counter in _counters) {
      final result = await _tokenService.updateCounter(
        counter.id,
        averageServiceTime: minutes,
      );
      if (result['success'] == true) anySuccess = true;
    }
    if (anySuccess) {
      _showSnackBar(
        '${tr('time_updated_to')} $minutes ${tr('min_label')}',
        Colors.teal,
      );
      await _loadCounters(); // refresh to update card
    } else {
      _showSnackBar(tr('time_update_failed'), Colors.red);
    }
  }

  // ════════════════════════════════════════════════════════════
  //                 APPROVE / REJECT ACTIONS
  // ════════════════════════════════════════════════════════════

  Future<void> _showApproveDialog(QueueToken token) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 8),
            Text(
              tr('approve_request_title'),
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          trArgs('approve_token_confirm', {'name': token.farmerName}),
          style: GoogleFonts.inter(fontSize: 15),
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
            child: Text(tr('approve_btn')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _performApprove(token);
    }
  }

  Future<void> _performApprove(QueueToken token) async {
    // Show loading overlay
    _showLoadingDialog();
    final result = await _tokenService.approveTokenRequest(token.id);
    if (!mounted) return;
    Navigator.pop(context); // dismiss loading

    if (result['success'] == true) {
      final tokenData = result['data']?['token'];
      final tokenNum = tokenData?['tokenNumber'] ?? '';
      _showSnackBar(
        isHindi
            ? '✅ ${trArgs('token_approved_notif', {'number': tokenNum, 'name': token.farmerName})}'
            : '✅ Token approved: $tokenNum (${token.farmerName})',
        Colors.green,
      );
      _loadPendingTokens();
    } else {
      _showSnackBar(result['message'] ?? 'Failed', Colors.red);
    }
  }

  Future<void> _showRejectDialog(QueueToken token) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.cancel, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Text(
              tr('reject_request_q'),
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trArgs('reject_token_confirm', {'name': token.farmerName}),
              style: GoogleFonts.inter(fontSize: 15),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: tr('reason_optional'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel_btn')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(tr('reject_btn')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _performReject(token, reasonController.text);
    }
    reasonController.dispose();
  }

  Future<void> _performReject(QueueToken token, String reason) async {
    _showLoadingDialog();
    final result = await _tokenService.rejectTokenRequest(
      token.id,
      reason: reason.isNotEmpty ? reason : null,
    );
    if (!mounted) return;
    Navigator.pop(context); // dismiss loading

    if (result['success'] == true) {
      _showSnackBar(tr('request_rejected'), Colors.orange);
      _loadPendingTokens();
    } else {
      _showSnackBar(result['message'] ?? 'Failed', Colors.red);
    }
  }

  // ════════════════════════════════════════════════════════════
  //                       HELPERS
  // ════════════════════════════════════════════════════════════

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
