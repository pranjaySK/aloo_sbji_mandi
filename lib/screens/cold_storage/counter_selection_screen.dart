import 'dart:async';

import 'package:aloo_sbji_mandi/core/service/cold_storage_service.dart';
import 'package:aloo_sbji_mandi/core/service/token_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/screens/cold_storage/counter_detail_dashboard_screen.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Counter Selection Screen — shows 5 square rounded counter blocks (A–E).
/// Tapping a counter opens its detailed dashboard.
/// A manage button allows adding/removing/toggling counters.
class CounterSelectionScreen extends StatefulWidget {
  final String? coldStorageId;
  final String? coldStorageName;

  const CounterSelectionScreen({
    super.key,
    this.coldStorageId,
    this.coldStorageName,
  });

  @override
  State<CounterSelectionScreen> createState() => _CounterSelectionScreenState();
}

class _CounterSelectionScreenState extends State<CounterSelectionScreen> {
  final TokenService _tokenService = TokenService();
  final ColdStorageService _coldStorageService = ColdStorageService();
  Timer? _refreshTimer;

  String? _coldStorageId;
  String? _coldStorageName;

  bool _isLoading = true;
  String? _error;

  List<CounterInfo> _counters = [];
  List<Map<String, dynamic>> _counterQueues = [];

  // Default counter labels & colors
  static const List<String> _defaultLabels = ['A', 'B', 'C', 'D', 'E'];
  static const List<Color> _counterColors = [
    Color(0xFF1565C0), // Blue
    Color(0xFF2E7D32), // Green
    Color(0xFFEF6C00), // Orange
    Color(0xFF6A1B9A), // Purple
    Color(0xFFC62828), // Red
  ];
  static const List<IconData> _counterIcons = [
    Icons.looks_one_rounded,
    Icons.looks_two_rounded,
    Icons.looks_3_rounded,
    Icons.looks_4_rounded,
    Icons.looks_5_rounded,
  ];

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
                  storage['name']?.toString() ?? tr('cold_storage_not_found');
            });
          }
        }
      } catch (_) {}
    }

    if (_coldStorageId != null) {
      await _loadAll();
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _loadAll(),
      );
    } else {
      setState(() {
        _isLoading = false;
        _error = tr('cold_storage_not_found');
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (_coldStorageId == null) return;
    await Future.wait([_loadCounters(), _loadQueue()]);
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

  Future<void> _loadQueue() async {
    final result = await _tokenService.getTokenQueue(_coldStorageId!);
    if (!mounted) return;
    if (result['success'] == true && result['data'] != null) {
      final d = result['data'];
      if (d['counterQueues'] != null) {
        setState(() {
          _counterQueues =
              List<Map<String, dynamic>>.from(d['counterQueues']);
        });
      }
    }
  }

  // ── Counter Queue Helpers ──
  int _waitingCountFor(String counterId) {
    try {
      final cq = _counterQueues.firstWhere((cq) {
        final id =
            cq['counter']?['_id']?.toString() ?? cq['counterId']?.toString();
        return id == counterId;
      });
      final waiting = cq['waitingTokens'];
      if (waiting is List) return waiting.length;
    } catch (_) {}
    return 0;
  }

  String _nowServingFor(String counterId) {
    try {
      final cq = _counterQueues.firstWhere((cq) {
        final id =
            cq['counter']?['_id']?.toString() ?? cq['counterId']?.toString();
        return id == counterId;
      });
      final active = cq['activeToken'];
      if (active != null && active is Map) {
        return active['tokenNumber']?.toString().replaceAll('T-', '') ?? '--';
      }
    } catch (_) {}
    return '--';
  }

  // ════════════════════════════════════════════════════════════
  //                     COUNTER MANAGEMENT
  // ════════════════════════════════════════════════════════════

  Future<void> _addCounter() async {
    final nextNumber = _counters.length + 1;
    if (nextNumber > 10) {
      _showSnackBar(tr('max_counters_msg'), Colors.orange);
      return;
    }

    final label = nextNumber <= _defaultLabels.length
        ? _defaultLabels[nextNumber - 1]
        : '$nextNumber';

    final nameController =
        TextEditingController(text: '${tr('add_counter')} $label');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.add_circle, color: AppColors.primaryGreen, size: 28),
            const SizedBox(width: 10),
            Text(
              tr('add_counter'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: tr('counter_name_label'),
                hintText: tr('counter_name_hint'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(tr('add_counter')),
          ),
        ],
      ),
    );

    if (confirmed == true && _coldStorageId != null) {
      setState(() => _isLoading = true);
      final result = await _tokenService.createCounter(
        _coldStorageId!,
        name: nameController.text.trim(),
      );
      if (result['success'] == true) {
        _showSnackBar(tr('counter_added'), AppColors.primaryGreen);
        await _loadCounters();
      } else {
        _showSnackBar(result['message'] ?? tr('failed_to_add_counter'), Colors.red);
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleCounter(CounterInfo counter) async {
    final newActive = !counter.isActive;
    final result = await _tokenService.updateCounter(
      counter.id,
      isActive: newActive,
    );
    if (result['success'] == true) {
      _showSnackBar(
        newActive ? '${counter.name} ${tr('counter_activated')}' : '${counter.name} ${tr('counter_deactivated')}',
        newActive ? AppColors.primaryGreen : Colors.orange,
      );
      _loadCounters();
    } else {
      _showSnackBar(result['message'] ?? tr('failed_msg'), Colors.red);
    }
  }

  Future<void> _deleteCounter(CounterInfo counter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Text(tr('delete_counter')),
          ],
        ),
        content: Text(
          tr('delete_counter_confirm').replaceAll('this counter', '"${counter.name}"'),
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(tr('delete_counter')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await _tokenService.deleteCounter(counter.id);
      if (result['success'] == true) {
        _showSnackBar(tr('counter_deleted'), Colors.orange);
        _loadCounters();
      } else {
        _showSnackBar(result['message'] ?? tr('failed_msg'), Colors.red);
      }
    }
  }

  void _showManageSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ManageCountersSheet(
        counters: _counters,
        onToggle: _toggleCounter,
        onDelete: _deleteCounter,
        onAdd: _addCounter,
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
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
          tr('token_dashboard'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: tr('manage_counters_tooltip'),
            onPressed: _showManageSheet,
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
          Icon(Icons.error_outline, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
              });
              _init();
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

  Widget _buildBody() {
    final activeCounters = _counters.where((c) => c.isActive).toList();

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            if (_coldStorageName != null) ...[
              Text(
                _coldStorageName!,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              tr('select_a_counter'),
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1B4332),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tr('select_counter_sub'),
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),

            // ── Summary Row ──
            _buildSummaryRow(activeCounters),
            const SizedBox(height: 24),

            // ── Counter Grid (5 square blocks) ──
            if (activeCounters.isEmpty)
              _buildEmpty()
            else
              _buildCounterGrid(activeCounters),

            const SizedBox(height: 24),

            // ── Add Counter Button ──
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addCounter,
                icon: const Icon(Icons.add_rounded, size: 22),
                label: Text(
                  tr('add_new_counter'),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  side: BorderSide(
                    color: AppColors.primaryGreen.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Summary ──
  Widget _buildSummaryRow(List<CounterInfo> activeCounters) {
    int totalWaiting = 0;
    int totalServing = 0;
    for (final c in activeCounters) {
      totalWaiting += _waitingCountFor(c.id);
      if (_nowServingFor(c.id) != '--') totalServing++;
    }

    return Row(
      children: [
        _buildMiniStat(
          label: tr('active_counters'),
          value: '${activeCounters.length}',
          icon: Icons.grid_view_rounded,
          color: AppColors.primaryGreen,
        ),
        const SizedBox(width: 10),
        _buildMiniStat(
          label: tr('total_waiting'),
          value: '$totalWaiting',
          icon: Icons.hourglass_top_rounded,
          color: Colors.orange,
        ),
        const SizedBox(width: 10),
        _buildMiniStat(
          label: tr('now_serving'),
          value: '$totalServing',
          icon: Icons.play_circle_rounded,
          color: const Color(0xFF1565C0),
        ),
      ],
    );
  }

  Widget _buildMiniStat({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
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
              style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Counter Grid ──
  Widget _buildCounterGrid(List<CounterInfo> activeCounters) {
    // Calculate grid layout: 3 columns for better use of space
    final crossAxisCount = activeCounters.length <= 4 ? 2 : 3;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.0, // Square blocks
      ),
      itemCount: activeCounters.length,
      itemBuilder: (context, index) {
        final counter = activeCounters[index];
        final colorIndex = index % _counterColors.length;
        return _buildCounterBlock(
          counter: counter,
          label: index < _defaultLabels.length
              ? _defaultLabels[index]
              : '${index + 1}',
          color: _counterColors[colorIndex],
          icon: index < _counterIcons.length
              ? _counterIcons[index]
              : Icons.grid_view_rounded,
        );
      },
    );
  }

  Widget _buildCounterBlock({
    required CounterInfo counter,
    required String label,
    required Color color,
    required IconData icon,
  }) {
    final waiting = _waitingCountFor(counter.id);
    final serving = _nowServingFor(counter.id);
    final isServing = serving != '--';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CounterDetailDashboardScreen(
              coldStorageId: _coldStorageId!,
              coldStorageName: _coldStorageName,
              counterId: counter.id,
              counterName: counter.name,
              counterNumber: counter.number,
            ),
          ),
        ).then((_) => _loadAll());
      },
      onLongPress: () => _showManageSheet(),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.75)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background letter
            Positioned(
              right: -8,
              bottom: -12,
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 80,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Counter icon and name
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Icon(icon, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          counter.name,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Now serving
                  if (isServing) ...[
                    Text(
                      tr('serving_label'),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      '#$serving',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ] else ...[
                    Text(
                      tr('idle_label'),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Waiting badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: waiting > 0 ? 0.25 : 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_alt_rounded,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$waiting ${tr('n_waiting')}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Icon(Icons.dashboard_customize_rounded,
              size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            tr('no_counters_setup'),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr('add_counters_sub'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _addCounter,
            icon: const Icon(Icons.add_rounded),
            label: Text(tr('add_first_counter')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//                   MANAGE COUNTERS BOTTOM SHEET
// ════════════════════════════════════════════════════════════

class _ManageCountersSheet extends StatelessWidget {
  final List<CounterInfo> counters;
  final Function(CounterInfo) onToggle;
  final Function(CounterInfo) onDelete;
  final VoidCallback onAdd;

  const _ManageCountersSheet({
    required this.counters,
    required this.onToggle,
    required this.onDelete,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.tune_rounded,
                    color: AppColors.primaryGreen, size: 24),
                const SizedBox(width: 10),
                Text(
                  tr('manage_counters'),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onAdd();
                  },
                  icon: Icon(Icons.add_circle_rounded,
                      color: AppColors.primaryGreen, size: 28),
                  tooltip: tr('add_counter_tooltip'),
                ),
              ],
            ),
          ),
          const Divider(height: 24),

          // Counter List
          if (counters.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                tr('no_counters_yet_msg'),
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: counters.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final counter = counters[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: counter.isActive
                          ? Colors.green.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: counter.isActive
                            ? Colors.green.shade200
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: counter.isActive
                                ? AppColors.primaryGreen.withValues(alpha: 0.15)
                                : Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${counter.number}',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: counter.isActive
                                  ? AppColors.primaryGreen
                                  : Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                counter.name,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: counter.isActive
                                      ? Colors.black87
                                      : Colors.grey,
                                ),
                              ),
                              Text(
                                counter.isActive ? tr('active_status') : tr('inactive_status'),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: counter.isActive
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Toggle switch
                        Switch(
                          value: counter.isActive,
                          activeColor: AppColors.primaryGreen,
                          onChanged: (_) {
                            Navigator.pop(context);
                            onToggle(counter);
                          },
                        ),
                        // Delete
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 22),
                          onPressed: () {
                            Navigator.pop(context);
                            onDelete(counter);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
