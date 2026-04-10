import 'package:aloo_sbji_mandi/core/service/token_service.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Counter management screen for cold-storage owners (Screenshot 5).
/// Allows enabling/disabling counters, changing names, and viewing waiting counts.
class LaneManagementScreen extends StatefulWidget {
  final String coldStorageId;
  final String coldStorageName;

  const LaneManagementScreen({
    super.key,
    required this.coldStorageId,
    required this.coldStorageName,
  });

  @override
  State<LaneManagementScreen> createState() => _LaneManagementScreenState();
}

class _LaneManagementScreenState extends State<LaneManagementScreen> {
  final TokenService _tokenService = TokenService();

  List<CounterInfo> _counters = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCounters();
  }

  Future<void> _loadCounters() async {
    setState(() => _isLoading = true);
    final result = await _tokenService.getCounters(widget.coldStorageId);
    if (!mounted) return;
    if (result['success'] == true && result['data'] != null) {
      final data = result['data'];
      final list = data is List ? data : (data['counters'] as List? ?? []);
      setState(() {
        _counters =
            list.map((j) => CounterInfo.fromJson(j as Map<String, dynamic>)).toList();
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

  // ── Toggle active/inactive ──
  Future<void> _toggleActive(CounterInfo counter) async {
    final newActive = !counter.isActive;
    final result = await _tokenService.updateCounter(
      counter.id,
      isActive: newActive,
    );
    if (mounted) {
      if (result['success'] == true) {
        _loadCounters();
        _showSnack(
          '${counter.name} ${newActive ? 'activated' : 'paused'}',
          newActive ? AppColors.primaryGreen : Colors.orange,
        );
      } else {
        _showSnack(result['message'] ?? 'Failed', Colors.red);
      }
    }
  }

  // ── Edit counter name / settings ──
  void _showEditSheet(CounterInfo counter) {
    final nameCtrl = TextEditingController(text: counter.name);
    final avgTimeCtrl =
        TextEditingController(text: '${counter.averageServiceTime}');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Edit ${counter.name}',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF3E2723),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Name field
              Text(
                'Counter Name',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Counter 1',
                  filled: true,
                  fillColor: const Color(0xFFF5F0EA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Average service time
              Text(
                'Avg. Service Time (minutes)',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: avgTimeCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'e.g. 10',
                  filled: true,
                  fillColor: const Color(0xFFF5F0EA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final avgTime = int.tryParse(avgTimeCtrl.text.trim());
                    if (name.isEmpty) return;
                    Navigator.pop(ctx);
                    final result = await _tokenService.updateCounter(
                      counter.id,
                      name: name,
                      averageServiceTime: avgTime,
                    );
                    if (mounted) {
                      if (result['success'] == true) {
                        _loadCounters();
                        _showSnack('Updated $name', AppColors.primaryGreen);
                      } else {
                        _showSnack(result['message'] ?? 'Failed', Colors.red);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Save Changes',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Add new counter ──
  void _showAddLaneSheet() {
    final nameCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add New Counter',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3E2723),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Counter Name',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Counter ${_counters.length + 1}',
                  filled: true,
                  fillColor: const Color(0xFFF5F0EA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(ctx);
                    final result = await _tokenService.createCounter(
                      widget.coldStorageId,
                      name: name,
                    );
                    if (mounted) {
                      if (result['success'] == true) {
                        _loadCounters();
                        _showSnack('$name created', AppColors.primaryGreen);
                      } else {
                        _showSnack(result['message'] ?? 'Failed', Colors.red);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Create Counter',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Delete ──
  Future<void> _confirmDelete(CounterInfo counter) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete ${counter.name}?',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: const Text(
          'This counter will be permanently removed. Tokens currently at this counter will need to be transferred.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      final result = await _tokenService.deleteCounter(counter.id);
      if (mounted) {
        if (result['success'] == true) {
          _loadCounters();
          _showSnack('${counter.name} deleted', Colors.red);
        } else {
          _showSnack(result['message'] ?? 'Failed', Colors.red);
        }
      }
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //                         BUILD
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0EA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5D4037),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Counter Management',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddLaneSheet,
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add Counter',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
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
          ElevatedButton(onPressed: _loadCounters, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_counters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warehouse_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No counters yet',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add your first counter',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCounters,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _counters.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _buildCounterCard(_counters[i]),
      ),
    );
  }

  Widget _buildCounterCard(CounterInfo counter) {
    final isActive = counter.isActive;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? AppColors.primaryGreen.withValues(alpha: 0.25)
              : Colors.grey.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Counter icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF5D4037).withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.warehouse_outlined,
                color: isActive ? const Color(0xFF5D4037) : Colors.grey,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            // Name & meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    counter.name,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isActive ? const Color(0xFF3E2723) : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people_outline,
                          size: 14,
                          color: counter.currentQueueLength > 0
                              ? Colors.orange
                              : Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        'Waiting: ${counter.currentQueueLength}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: counter.currentQueueLength > 0
                              ? Colors.orange.shade800
                              : Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.timer_outlined,
                          size: 14, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        '~${counter.averageServiceTime} min',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Toggle + actions
            Column(
              children: [
                // Toggle switch
                Switch(
                  value: isActive,
                  onChanged: (_) => _toggleActive(counter),
                  activeColor: AppColors.primaryGreen,
                  inactiveTrackColor: Colors.orange.withValues(alpha: 0.3),
                  inactiveThumbColor: Colors.orange,
                ),
                // Action buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _showEditSheet(counter),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.edit_outlined,
                            size: 18, color: Colors.grey[600]),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _confirmDelete(counter),
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.delete_outline,
                            size: 18, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
