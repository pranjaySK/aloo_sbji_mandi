import 'package:aloo_sbji_mandi/core/models/chat_models.dart';
import 'package:aloo_sbji_mandi/core/service/chat_service.dart';
import 'package:aloo_sbji_mandi/core/service/trader_request_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/toast_helper.dart';
import 'package:aloo_sbji_mandi/screens/chat/chat_detail_screen.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:aloo_sbji_mandi/widgets/location_map_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/ist_datetime.dart';

class TraderRequestsScreen extends StatefulWidget {
  const TraderRequestsScreen({super.key});

  @override
  State<TraderRequestsScreen> createState() => _TraderRequestsScreenState();
}

class _TraderRequestsScreenState extends State<TraderRequestsScreen> {
  final TraderRequestService _requestService = TraderRequestService();
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();

  // Open requests state
  List<dynamic> _requests = [];
  List<dynamic> _filteredRequests = [];
  bool _isLoading = true;
  String? _error;
  bool _showFilters = false;

  // ── Filter state ──────────────────────────────────────────────
  String _searchQuery = '';
  RangeValues? _quantityRange;
  RangeValues? _priceRange;
  String? _selectedDuration; // '3d', '7d', '15d', '30d', null=all
  String? _selectedDistrict;
  String _sortBy = 'newest'; // 'newest', 'price_low', 'price_high', 'qty_high'

  // Derived limits for range sliders
  double _maxQuantity = 1000;
  double _maxPrice = 10000;
  List<String> _availableDistricts = [];

  // Dismissed/hidden request IDs (local persistence)
  Set<String> _dismissedIds = {};

  @override
  void initState() {
    super.initState();
    _loadDismissedIds();
    _loadRequests();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
        _applyFilters();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _requestService.getAllRequests();

    setState(() {
      _isLoading = false;
      if (result['success']) {
        final all = result['data']['requests'] ?? [];
        // Filter out locally dismissed requests
        _requests = all
            .where((r) => !_dismissedIds.contains(r['_id']?.toString()))
            .toList();
        _computeFilterLimits();
        _applyFilters();
      } else {
        _error = result['message'];
      }
    });
  }

  void _computeFilterLimits() {
    double mxQ = 100, mxP = 5000;
    final districts = <String>{};
    for (final r in _requests) {
      final q = (r['quantity'] is num)
          ? (r['quantity'] as num).toDouble()
          : 0.0;
      final p = (r['maxPricePerQuintal'] is num)
          ? (r['maxPricePerQuintal'] as num).toDouble()
          : 0.0;
      if (q > mxQ) mxQ = q;
      if (p > mxP) mxP = p;
      final loc = r['deliveryLocation'];
      if (loc != null &&
          loc['district'] != null &&
          loc['district'].toString().isNotEmpty) {
        districts.add(loc['district'].toString());
      }
    }
    _maxQuantity = mxQ;
    _maxPrice = mxP;
    _availableDistricts = districts.toList()..sort();
  }

  void _applyFilters() {
    List<dynamic> result = List.from(_requests);

    // Text search: name / variety / description / trader name
    if (_searchQuery.isNotEmpty) {
      result = result.where((r) {
        final variety = (r['potatoVariety'] ?? '').toString().toLowerCase();
        final desc = (r['description'] ?? '').toString().toLowerCase();
        final trader = r['trader'] ?? {};
        final tName = '${trader['firstName'] ?? ''} ${trader['lastName'] ?? ''}'
            .toLowerCase();
        final district = (r['deliveryLocation']?['district'] ?? '')
            .toString()
            .toLowerCase();
        return variety.contains(_searchQuery) ||
            desc.contains(_searchQuery) ||
            tName.contains(_searchQuery) ||
            district.contains(_searchQuery);
      }).toList();
    }

    // Quantity range
    if (_quantityRange != null) {
      result = result.where((r) {
        final q = (r['quantity'] is num)
            ? (r['quantity'] as num).toDouble()
            : 0.0;
        return q >= _quantityRange!.start && q <= _quantityRange!.end;
      }).toList();
    }

    // Price range
    if (_priceRange != null) {
      result = result.where((r) {
        final p = (r['maxPricePerQuintal'] is num)
            ? (r['maxPricePerQuintal'] as num).toDouble()
            : 0.0;
        return p >= _priceRange!.start && p <= _priceRange!.end;
      }).toList();
    }

    // Duration filter
    if (_selectedDuration != null) {
      final now = DateTime.now();
      int days = 0;
      switch (_selectedDuration) {
        case '3d':
          days = 3;
          break;
        case '7d':
          days = 7;
          break;
        case '15d':
          days = 15;
          break;
        case '30d':
          days = 30;
          break;
      }
      if (days > 0) {
        final cutoff = now.subtract(Duration(days: days));
        result = result.where((r) {
          final created = DateTime.tryParse(r['createdAt'] ?? '');
          return created != null && created.isAfter(cutoff);
        }).toList();
      }
    }

    // District filter
    if (_selectedDistrict != null) {
      result = result.where((r) {
        final d = (r['deliveryLocation']?['district'] ?? '').toString();
        return d == _selectedDistrict;
      }).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'newest':
        result.sort((a, b) {
          final da = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime(2000);
          final db = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime(2000);
          return db.compareTo(da);
        });
        break;
      case 'price_low':
        result.sort((a, b) {
          final pa = (a['maxPricePerQuintal'] is num)
              ? a['maxPricePerQuintal']
              : 0;
          final pb = (b['maxPricePerQuintal'] is num)
              ? b['maxPricePerQuintal']
              : 0;
          return (pa as num).compareTo(pb as num);
        });
        break;
      case 'price_high':
        result.sort((a, b) {
          final pa = (a['maxPricePerQuintal'] is num)
              ? a['maxPricePerQuintal']
              : 0;
          final pb = (b['maxPricePerQuintal'] is num)
              ? b['maxPricePerQuintal']
              : 0;
          return (pb as num).compareTo(pa as num);
        });
        break;
      case 'qty_high':
        result.sort((a, b) {
          final qa = (a['quantity'] is num) ? a['quantity'] : 0;
          final qb = (b['quantity'] is num) ? b['quantity'] : 0;
          return (qb as num).compareTo(qa as num);
        });
        break;
    }

    _filteredRequests = result;
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _quantityRange = null;
      _priceRange = null;
      _selectedDuration = null;
      _selectedDistrict = null;
      _sortBy = 'newest';
      _applyFilters();
    });
  }

  int get _activeFilterCount {
    int c = 0;
    if (_quantityRange != null) c++;
    if (_priceRange != null) c++;
    if (_selectedDuration != null) c++;
    if (_selectedDistrict != null) c++;
    if (_sortBy != 'newest') c++;
    return c;
  }

  // ── Dismiss / Delete helpers ──────────────────────────────────
  Future<void> _loadDismissedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('dismissed_trader_requests') ?? [];
    setState(() => _dismissedIds = ids.toSet());
  }

  Future<void> _saveDismissedIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'dismissed_trader_requests', _dismissedIds.toList());
  }

  void _confirmDeleteRequest(Map<String, dynamic> request) {
    final trader = request['trader'] ?? {};
    final traderName =
        '${trader['firstName'] ?? ''} ${trader['lastName'] ?? ''}'.trim();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr('delete_request')),
        content: Text(
          '${tr('delete_request_confirm')}\n\n${request['potatoVariety'] ?? 'Potato'} – ${traderName.isEmpty ? 'Trader' : traderName}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _dismissRequest(request['_id']);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(tr('delete')),
          ),
        ],
      ),
    );
  }

  void _dismissRequest(String requestId) {
    setState(() {
      _dismissedIds.add(requestId);
      _requests.removeWhere((r) => r['_id'] == requestId);
      _applyFilters();
    });
    _saveDismissedIds();
    ToastHelper.showSuccess(context, tr('request_deleted'));
  }

  Future<void> _startChatWithTrader(Map<String, dynamic> request) async {
    final trader = request['trader'];
    if (trader == null || trader['_id'] == null) {
      ToastHelper.showError(context, 'Trader info not available');
      return;
    }

    final traderId = trader['_id'].toString();
    final traderName =
        '${trader['firstName'] ?? ''} ${trader['lastName'] ?? ''}'.trim();

    final result = await _chatService.startOrGetConversation(traderId);

    if (result['success']) {
      final data = result['data'];
      final conversation = data is Map ? (data['conversation'] ?? data) : null;
      if (conversation != null && conversation['_id'] != null && mounted) {
        // Create ChatUser object for the trader
        final chatUser = ChatUser(
          id: traderId,
          firstName: trader['firstName']?.toString() ?? traderName,
          lastName: trader['lastName']?.toString() ?? '',
          role: trader['role']?.toString() ?? 'vendor',
          isOnline: trader['isOnline'] ?? false,
          phone: trader['phone']?.toString(),
        );

        // Get request quantity and price for deal auto-fill
        final requestQuantity = request['quantity'] is num
            ? (request['quantity'] as num).toDouble()
            : double.tryParse(request['quantity']?.toString() ?? '');
        final requestPrice = request['pricePerKg'] is num
            ? (request['pricePerKg'] as num).toDouble()
            : double.tryParse(request['pricePerKg']?.toString() ?? '');

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              conversationId: conversation['_id']?.toString() ?? '',
              otherUser: chatUser,
              contextType: 'trader_request',
              initialQuantity: requestQuantity,
              initialPrice: requestPrice,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          tr('trader_requests'),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // Filter badge button
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(
                  _showFilters ? Icons.filter_list_off : Icons.filter_list,
                  color: Colors.white,
                ),
                onPressed: () => setState(() => _showFilters = !_showFilters),
              ),
              if (_activeFilterCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_activeFilterCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadRequests,
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
      return Center(
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
      );
    }
    return Column(
      children: [
        // ── Search Bar ────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: tr('search_by_name_variety'),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // ── Filters Panel ────────────────────────────
        if (_showFilters) _buildFiltersPanel(),

        // ── Results count + Active filter chips ──────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          child: Row(
            children: [
              Text(
                '${_filteredRequests.length} ${tr('results_found')}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const Spacer(),
              if (_activeFilterCount > 0)
                TextButton.icon(
                  onPressed: _clearAllFilters,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: Text(tr('clear_filters')),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red[700],
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ),

        const Divider(height: 1),

        // ── Request List ─────────────────────────────
        Expanded(
          child: _filteredRequests.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadRequests,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredRequests.length,
                    itemBuilder: (context, index) {
                      return _buildRequestCard(
                        _filteredRequests[index],
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  FILTERS PANEL
  // ══════════════════════════════════════════════════════════════
  Widget _buildFiltersPanel() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),

          // ── Sort By ──────────────────────────────────────────
          Text(
            tr('sort_by'),
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _sortChip('newest', tr('newest')),
                _sortChip('price_low', tr('price_low_to_high')),
                _sortChip('price_high', tr('price_high_to_low')),
                _sortChip('qty_high', tr('quantity_high')),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Duration Filter ──────────────────────────────────
          Text(
            tr('posted_within'),
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _durationChip(null, tr('all')),
                _durationChip('3d', tr('last_3_days')),
                _durationChip('7d', tr('last_7_days')),
                _durationChip('15d', tr('last_15_days')),
                _durationChip('30d', tr('last_30_days')),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── District Filter ──────────────────────────────────
          if (_availableDistricts.isNotEmpty) ...[
            Text(
              tr('location_district'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _districtChip(null, tr('all')),
                  ..._availableDistricts.map((d) => _districtChip(d, d)),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // ── Quantity Range ───────────────────────────────────
          if (_maxQuantity > 0) ...[
            Row(
              children: [
                Text(
                  tr('quantity_range'),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                if (_quantityRange != null)
                  Text(
                    '${_quantityRange!.start.round()} – ${_quantityRange!.end.round()} ${tr('pckt')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            RangeSlider(
              values: _quantityRange ?? RangeValues(0, _maxQuantity),
              min: 0,
              max: _maxQuantity,
              divisions: (_maxQuantity / 10).ceil().clamp(1, 100),
              activeColor: AppColors.primaryGreen,
              labels: RangeLabels(
                '${(_quantityRange?.start ?? 0).round()}',
                '${(_quantityRange?.end ?? _maxQuantity).round()}',
              ),
              onChanged: (v) {
                setState(() {
                  // If they moved the slider to full range, treat as no filter
                  if (v.start == 0 && v.end == _maxQuantity) {
                    _quantityRange = null;
                  } else {
                    _quantityRange = v;
                  }
                  _applyFilters();
                });
              },
            ),
          ],

          // ── Price Range ──────────────────────────────────────
          if (_maxPrice > 0) ...[
            Row(
              children: [
                Text(
                  tr('price_range'),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                if (_priceRange != null)
                  Text(
                    '₹${_priceRange!.start.round()} – ₹${_priceRange!.end.round()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            RangeSlider(
              values: _priceRange ?? RangeValues(0, _maxPrice),
              min: 0,
              max: _maxPrice,
              divisions: (_maxPrice / 100).ceil().clamp(1, 100),
              activeColor: AppColors.primaryGreen,
              labels: RangeLabels(
                '₹${(_priceRange?.start ?? 0).round()}',
                '₹${(_priceRange?.end ?? _maxPrice).round()}',
              ),
              onChanged: (v) {
                setState(() {
                  if (v.start == 0 && v.end == _maxPrice) {
                    _priceRange = null;
                  } else {
                    _priceRange = v;
                  }
                  _applyFilters();
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _sortChip(String value, String label) {
    final selected = _sortBy == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 12)),
        selected: selected,
        selectedColor: AppColors.primaryGreen.withOpacity(0.2),
        labelStyle: TextStyle(
          color: selected ? AppColors.primaryGreen : Colors.grey[700],
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
        onSelected: (_) {
          setState(() {
            _sortBy = value;
            _applyFilters();
          });
        },
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _durationChip(String? value, String label) {
    final selected = _selectedDuration == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 12)),
        selected: selected,
        selectedColor: AppColors.primaryGreen.withOpacity(0.2),
        labelStyle: TextStyle(
          color: selected ? AppColors.primaryGreen : Colors.grey[700],
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
        onSelected: (_) {
          setState(() {
            _selectedDuration = value;
            _applyFilters();
          });
        },
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _districtChip(String? value, String label) {
    final selected = _selectedDistrict == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 12)),
        selected: selected,
        selectedColor: AppColors.primaryGreen.withOpacity(0.2),
        labelStyle: TextStyle(
          color: selected ? AppColors.primaryGreen : Colors.grey[700],
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
        onSelected: (_) {
          setState(() {
            _selectedDistrict = value;
            _applyFilters();
          });
        },
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasFilters = _activeFilterCount > 0 || _searchQuery.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilters ? Icons.filter_alt_off : Icons.shopping_basket_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters
                ? tr('no_results_for_filters')
                : tr('no_trader_requests_yet'),
            style: GoogleFonts.inter(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilters
                ? tr('try_changing_filters')
                : tr('trader_requests_hint'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          if (hasFilters)
            ElevatedButton.icon(
              onPressed: _clearAllFilters,
              icon: const Icon(Icons.clear_all),
              label: Text(tr('clear_filters')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _loadRequests,
              icon: const Icon(Icons.refresh),
              label: Text(tr('refresh')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final trader = request['trader'] ?? {};
    final traderName =
        '${trader['firstName'] ?? ''} ${trader['lastName'] ?? ''}'.trim();
    final createdAt = DateTime.tryParse(request['createdAt'] ?? '');
    final expiresAt = DateTime.tryParse(request['expiresAt'] ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with trader info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.blue.withOpacity(0.2),
                  child: const Icon(Icons.business, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        traderName.isEmpty ? 'Trader' : traderName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      if (createdAt != null)
                        Text(
                          'Posted ${DateFormat('dd MMM').format(createdAt.toIST())}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'OPEN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Request Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Variety
                Text(
                  request['potatoVariety'] ?? 'Potato',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                // Details in chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _infoChip(
                      Icons.scale,
                      '${request['quantity']} ${tr('pckt')}',
                    ),
                    _infoChip(
                      Icons.currency_rupee,
                      '₹${request['maxPricePerQuintal']}/${tr('pckt')}',
                    ),
                    _infoChip(
                      Icons.category,
                      '${request['potatoType'] ?? tr('all')}',
                    ),
                    _infoChip(
                      Icons.straighten,
                      '${tr('size')}: ${request['size'] ?? tr('all')}',
                    ),
                  ],
                ),

                // Location
                if (request['deliveryLocation'] != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${request['deliveryLocation']['district'] ?? ''}, ${request['deliveryLocation']['state'] ?? ''}'
                            .replaceAll(RegExp(r'^, |, $'), ''),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],

                // GPS Captured Location Map
                if (request['captureLocation'] != null &&
                    request['captureLocation'] is Map &&
                    request['captureLocation']['latitude'] != null &&
                    request['captureLocation']['longitude'] != null) ...[  
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LocationMapWidget(
                      latitude: (request['captureLocation']['latitude'] as num).toDouble(),
                      longitude: (request['captureLocation']['longitude'] as num).toDouble(),
                      address: request['captureLocation']['address'] ?? '',
                      compact: true,
                      height: 140,
                      zoom: 14,
                    ),
                  ),
                ],

                // Description
                if (request['description'] != null &&
                    request['description'].toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    request['description'],
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],

                // Expiry
                if (expiresAt != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.timer, size: 16, color: Colors.orange[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Expires ${DateFormat('dd MMM yyyy').format(expiresAt.toIST())}',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _startChatWithTrader(request),
                    icon: const Icon(Icons.chat, size: 18),
                    label: Text(tr('chat')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => _confirmDeleteRequest(request),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: tr('delete'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryGreen),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _labelStyle() {
    return GoogleFonts.inter(
      fontWeight: FontWeight.w500,
      fontSize: 14,
      color: Colors.grey[700],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.inputFill(context),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
