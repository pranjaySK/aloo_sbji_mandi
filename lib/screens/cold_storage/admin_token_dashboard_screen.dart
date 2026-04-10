import 'dart:async';

import 'package:aloo_sbji_mandi/core/service/cold_storage_service.dart';
import 'package:aloo_sbji_mandi/core/service/socket_service.dart';
import 'package:aloo_sbji_mandi/core/service/token_service.dart';
import 'package:aloo_sbji_mandi/core/utils/auth_error_helper.dart';
import 'package:aloo_sbji_mandi/screens/cold_storage/lane_management_screen.dart';
import 'package:aloo_sbji_mandi/screens/cold_storage/token_queue_management_screen.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Admin dashboard showing a 2×2 grid of counter cards with CALL NEXT capability.
/// This is the primary entry point for cold-storage owners (Screenshot 4).
class AdminTokenDashboardScreen extends StatefulWidget {
  final String? coldStorageId;
  final String? coldStorageName;

  const AdminTokenDashboardScreen({
    super.key,
    this.coldStorageId,
    this.coldStorageName,
  });

  @override
  State<AdminTokenDashboardScreen> createState() =>
      _AdminTokenDashboardScreenState();
}

class _AdminTokenDashboardScreenState extends State<AdminTokenDashboardScreen> {
  final TokenService _tokenService = TokenService();
  final ColdStorageService _coldStorageService = ColdStorageService();
  final SocketService _socketService = SocketService();
  Timer? _pollTimer;

  String? _coldStorageId;
  String? _coldStorageName;
  List<Map<String, dynamic>> _allColdStorages = [];

  bool _isLoading = true;
  String? _error;

  // Per-counter data
  List<CounterInfo> _counters = [];
  List<Map<String, dynamic>> _counterQueues = [];
  QueueStats? _stats;
  int _pendingCount = 0;

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
          final data = result['data'];
          final storages = data is List
              ? data
              : (data['coldStorages'] ?? data['data'] ?? data['cold_storages'] ?? []);
          if (storages is List && storages.isNotEmpty) {
            _allColdStorages = storages
                .map<Map<String, dynamic>>((s) => {
                      '_id': s['_id']?.toString() ?? '',
                      'name': s['name']?.toString() ?? 'Cold Storage',
                    })
                .toList();
            setState(() {
              _coldStorageId = storages.first['_id']?.toString();
              _coldStorageName = storages.first['name']?.toString() ?? 'My Cold Storage';
            });
          }
        }
      } catch (_) {}
    }

    if (_coldStorageId != null) {
      await _loadAll();
      _setupSocket();
      _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) => _loadAll());
    } else {
      setState(() {
        _isLoading = false;
        _error = 'No cold storage found';
      });
    }
  }

  void _setupSocket() {
    _socketService.connect();
    _socketService.addTokenEventListener(_onTokenEvent);
  }

  void _onTokenEvent(Map<String, dynamic> data) {
    if (!mounted) return;
    final event = data['event'] as String?;
    if (event == 'token_queue_updated' ||
        event == 'token_request_pending' ||
        event == 'token_transferred') {
      _loadAll();
      if (event == 'token_request_pending') {
        _showSnack('New token request from ${data['farmerName'] ?? 'farmer'}', Colors.blue);
      }
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
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
        _stats = QueueStats.fromJson(d['stats'] ?? {});
        _pendingCount = _stats?.pending ?? 0;
        if (d['counterQueues'] != null) {
          _counterQueues = List<Map<String, dynamic>>.from(d['counterQueues']);
        }
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

  Future<void> _loadCounters() async {
    final result = await _tokenService.getCounters(_coldStorageId!);
    if (!mounted) return;
    if (result['success'] == true && result['data'] != null) {
      final data = result['data'];
      final list = data is List ? data : (data['counters'] as List? ?? []);
      setState(() {
        _counters =
            list.map((j) => CounterInfo.fromJson(j as Map<String, dynamic>)).toList();
      });
    }
  }

  // ── CALL NEXT ──
  Future<void> _callNext(CounterInfo counter) async {
    final result = await _tokenService.callNextToken(
      _coldStorageId!,
      counterId: counter.id,
      counterNumber: counter.number,
    );
    if (mounted) {
      if (result['success'] == true) {
        final tokenNum = result['data']?['token']?['tokenNumber'] ?? '';
        _showSnack('Called $tokenNum at ${counter.name}', AppColors.primaryGreen);
        _loadAll();
      } else {
        _showSnack(result['message'] ?? 'Failed', Colors.red);
      }
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 3)),
    );
  }

  // ── NAVIGATION ──
  void _openDetailedView() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TokenQueueManagementScreen(
          coldStorageId: _coldStorageId,
          coldStorageName: _coldStorageName,
        ),
      ),
    );
  }

  void _openLaneManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LaneManagementScreen(
          coldStorageId: _coldStorageId!,
          coldStorageName: _coldStorageName ?? '',
        ),
      ),
    ).then((_) => _loadCounters());
  }

  // ── HELPERS ──
  Map<String, dynamic>? _counterQueueFor(String counterId) {
    try {
      return _counterQueues.firstWhere(
        (cq) {
          // Backend returns counter as nested object: { counter: { _id, number, name }, ... }
          final cqCounterId = cq['counter']?['_id']?.toString() ??
              cq['counterId']?.toString();
          return cqCounterId == counterId;
        },
      );
    } catch (_) {
      return null;
    }
  }

  String _nowServingFor(String counterId) {
    final cq = _counterQueueFor(counterId);
    if (cq == null) return '--';
    final active = cq['activeToken'];
    if (active != null && active is Map) {
      return active['tokenNumber']?.toString().replaceAll('T-', '') ?? '--';
    }
    return '--';
  }

  int _waitingCountFor(String counterId) {
    final cq = _counterQueueFor(counterId);
    if (cq == null) return 0;
    final waiting = cq['waitingTokens'];
    if (waiting is List) return waiting.length;
    return 0;
  }

  // ══════════════════════════════════════════════════════════════
  //                         BUILD
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0EA),
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF5D4037),
      foregroundColor: Colors.white,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Token Dashboard',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          if (_coldStorageName != null)
            Text(
              _coldStorageName!,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.white70,
              ),
            ),
        ],
      ),
      actions: [
        // Pending requests badge
        if (_pendingCount > 0)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: Badge(
                label: Text('$_pendingCount', style: const TextStyle(fontSize: 10)),
                child: const Icon(Icons.notifications),
              ),
              onPressed: _openDetailedView,
              tooltip: 'View pending requests',
            ),
          ),
        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: 'Counter Settings',
          onPressed: _coldStorageId != null ? _openLaneManagement : null,
        ),
        IconButton(
          icon: const Icon(Icons.list_alt),
          tooltip: 'Detailed Queue',
          onPressed: _openDetailedView,
        ),
      ],
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
          ElevatedButton(onPressed: _loadAll, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final activeCounters = _counters.where((c) => c.isActive).toList();

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Summary Row ──
            _buildSummaryRow(),
            const SizedBox(height: 20),

            // ── Counter Cards Grid ──
            Text(
              'Counters',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF3E2723),
              ),
            ),
            const SizedBox(height: 12),
            if (activeCounters.isEmpty)
              _buildNoCounters()
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: activeCounters.length,
                itemBuilder: (context, index) =>
                    _buildCounterCard(activeCounters[index]),
              ),
          ],
        ),
      ),
    );
  }

  // ── Summary Cards ──
  Widget _buildSummaryRow() {
    return Row(
      children: [
        _buildSummaryItem(
          'Total Today',
          '${_stats?.total ?? 0}',
          Icons.confirmation_number,
          const Color(0xFF5D4037),
        ),
        const SizedBox(width: 10),
        _buildSummaryItem(
          'Waiting',
          '${_stats?.waiting ?? 0}',
          Icons.hourglass_top,
          Colors.orange,
        ),
        const SizedBox(width: 10),
        _buildSummaryItem(
          'Completed',
          '${_stats?.completed ?? 0}',
          Icons.check_circle,
          AppColors.primaryGreen,
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
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
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  // ── Counter Card ──
  Widget _buildCounterCard(CounterInfo counter) {
    final serving = _nowServingFor(counter.id);
    final waiting = _waitingCountFor(counter.id);
    final hasWaiting = waiting > 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasWaiting
              ? Colors.orange.withValues(alpha: 0.4)
              : Colors.grey.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Counter header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF5D4037).withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5D4037).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.warehouse_outlined,
                    color: Color(0xFF5D4037),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    counter.name,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF3E2723),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Now Serving
                  Text(
                    'Now Serving',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                  Text(
                    serving == '--' ? 'None' : 'Token $serving',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: serving == '--' ? Colors.grey[400] : const Color(0xFF3E2723),
                    ),
                  ),
                  const Spacer(),

                  // Waiting count
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 16,
                        color: hasWaiting ? Colors.orange : Colors.grey[400],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Waiting: $waiting',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: hasWaiting ? Colors.orange.shade800 : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Call Next button
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: ElevatedButton(
                      onPressed: hasWaiting ? () => _callNext(counter) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[200],
                        disabledForegroundColor: Colors.grey[400],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: hasWaiting ? 2 : 0,
                      ),
                      child: Text(
                        'CALL NEXT',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoCounters() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.warehouse_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            'No counters configured',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set up counters to manage your token queue efficiently.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _openLaneManagement,
            icon: const Icon(Icons.add),
            label: const Text('Setup Counters'),
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
}
