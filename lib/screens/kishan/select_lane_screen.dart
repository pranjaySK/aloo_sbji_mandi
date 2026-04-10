import 'package:aloo_sbji_mandi/core/service/token_service.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Data class for a lane/counter displayed on the selection screen.
class LaneInfo {
  final String id;
  final int number;
  final String name;
  final int waitingCount;
  final int estimatedWait;
  final bool isActive;
  final Map<String, dynamic>? currentlyServing;

  LaneInfo({
    required this.id,
    required this.number,
    required this.name,
    required this.waitingCount,
    required this.estimatedWait,
    required this.isActive,
    this.currentlyServing,
  });

  factory LaneInfo.fromJson(Map<String, dynamic> json) {
    return LaneInfo(
      id: json['_id']?.toString() ?? '',
      number: json['number'] ?? 0,
      name: json['name'] ?? 'Lane',
      waitingCount: json['waitingCount'] ?? 0,
      estimatedWait: json['estimatedWait'] ?? 0,
      isActive: json['isActive'] ?? true,
      currentlyServing: json['currentlyServing'],
    );
  }
}

/// Result returned when the farmer selects a lane.
class LaneSelectionResult {
  final String counterId;
  final int counterNumber;
  final String counterName;
  final String purpose;
  final double? quantity;
  final String unit;

  LaneSelectionResult({
    required this.counterId,
    required this.counterNumber,
    required this.counterName,
    required this.purpose,
    this.quantity,
    required this.unit,
  });
}

class SelectLaneScreen extends StatefulWidget {
  final String coldStorageId;
  final String coldStorageName;

  const SelectLaneScreen({
    super.key,
    required this.coldStorageId,
    required this.coldStorageName,
  });

  @override
  State<SelectLaneScreen> createState() => _SelectLaneScreenState();
}

class _SelectLaneScreenState extends State<SelectLaneScreen> {
  final TokenService _tokenService = TokenService();
  List<LaneInfo> _lanes = [];
  bool _isLoading = true;
  String? _error;
  int? _selectedLaneIndex;
  int? _lowestWaitIndex;

  // Purpose & quantity selection
  String _selectedPurpose = 'storage';
  String _selectedUnit = 'Packet';
  final TextEditingController _quantityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLanes();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadLanes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _tokenService.getQueueInfo(widget.coldStorageId);

    if (result['success'] == true && result['data'] != null) {
      final data = result['data'];
      final countersRaw = data['counters'] as List? ?? [];

      final lanes = countersRaw
          .map((c) => LaneInfo.fromJson(c as Map<String, dynamic>))
          .where((l) => l.isActive)
          .toList();

      // Find lane with lowest waiting count
      int? lowestIdx;
      int lowestCount = 999999;
      for (int i = 0; i < lanes.length; i++) {
        if (lanes[i].waitingCount < lowestCount) {
          lowestCount = lanes[i].waitingCount;
          lowestIdx = i;
        }
      }

      setState(() {
        _lanes = lanes;
        _lowestWaitIndex = lowestIdx;
        _selectedLaneIndex = lowestIdx; // Pre-select best lane
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _error = result['message'] ?? 'Failed to load lanes';
      });
    }
  }

  void _onConfirmSelection() {
    if (_selectedLaneIndex == null) return;
    final lane = _lanes[_selectedLaneIndex!];

    Navigator.pop(
      context,
      LaneSelectionResult(
        counterId: lane.id,
        counterNumber: lane.number,
        counterName: lane.name,
        purpose: _selectedPurpose,
        quantity: double.tryParse(_quantityController.text),
        unit: _selectedUnit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0EA),
      body: Column(
        children: [
          // ── Brown curved header ──
          _buildHeader(),
          // ── Body ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 20,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5D4037), Color(0xFF795548)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Select Your Lane',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadLanes,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_lanes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No lanes available right now.',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Lane Grid ──
          _buildLaneGrid(),
          const SizedBox(height: 8),
          // ── Inactive lanes message ──
          if (_lanes.length < 4)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  'No vacant lanes available right now.',
                  style: GoogleFonts.inter(
                    color: Colors.grey[500],
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 16),

          // ── Purpose Selection ──
          Text(
            'Purpose',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: const Color(0xFF3E2723),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _purposeChip('storage', 'Storage', Icons.inventory_2),
              _purposeChip('withdrawal', 'Withdrawal', Icons.output),
              _purposeChip('inspection', 'Inspection', Icons.search),
            ],
          ),
          const SizedBox(height: 16),

          // ── Unit & Quantity ──
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quantity',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: const Color(0xFF3E2723),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Enter qty',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unit',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: const Color(0xFF3E2723),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _unitToggle(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Confirm Button ──
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _selectedLaneIndex != null ? _onConfirmSelection : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
              child: Text(
                'Get Token',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLaneGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemCount: _lanes.length,
      itemBuilder: (context, index) => _buildLaneCard(index),
    );
  }

  Widget _buildLaneCard(int index) {
    final lane = _lanes[index];
    final isSelected = _selectedLaneIndex == index;
    final isLowest = _lowestWaitIndex == index;

    // Background — golden/brown gradient like wheat field
    final List<Color> bgColors = index % 2 == 0
        ? [const Color(0xFF6B8E23), const Color(0xFF556B2F)]
        : [const Color(0xFFCD853F), const Color(0xFFD2691E)];

    return GestureDetector(
      onTap: () => setState(() => _selectedLaneIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : Colors.transparent,
            width: isSelected ? 3 : 0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primaryGreen.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.1),
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              // Background gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: bgColors,
                  ),
                ),
              ),
              // Wave overlay at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.brown.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Lane ${lane.number}',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Waiting: ${lane.waitingCount}',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // "Lowest Waiting Time" badge
              if (isLowest)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Lowest Waiting\nTime',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              // Checkmark for selected
              if (isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: AppColors.primaryGreen,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _purposeChip(String value, String label, IconData icon) {
    final isSelected = _selectedPurpose == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedPurpose = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _unitToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          _unitOption('Packet', 'Pkt'),
          Container(height: 1, color: Colors.grey.shade200),
          _unitOption('Quintal', 'Qtl'),
        ],
      ),
    );
  }

  Widget _unitOption(String value, String label) {
    final isSelected = _selectedUnit == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedUnit = value),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGreen.withValues(alpha: 0.1)
              : Colors.transparent,
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: isSelected ? AppColors.primaryGreen : Colors.grey[600],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
