import 'dart:async';

import 'package:aloo_sbji_mandi/core/service/cold_storage_service.dart';
import 'package:aloo_sbji_mandi/core/service/socket_service.dart';
import 'package:aloo_sbji_mandi/core/service/token_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/auth_error_helper.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class TokenQueueManagementScreen extends StatefulWidget {
  final String? coldStorageId;
  final String? coldStorageName;

  const TokenQueueManagementScreen({
    super.key,
    this.coldStorageId,
    this.coldStorageName,
  });

  @override
  State<TokenQueueManagementScreen> createState() =>
      _TokenQueueManagementScreenState();
}

class _TokenQueueManagementScreenState extends State<TokenQueueManagementScreen>
    with SingleTickerProviderStateMixin {
  final TokenService _tokenService = TokenService();
  final ColdStorageService _coldStorageService = ColdStorageService();
  final SocketService _socketService = SocketService();
  late TabController _tabController;
  Timer? _refreshTimer;

  String? _coldStorageId;
  String? _coldStorageName;
  List<Map<String, dynamic>> _allColdStorages = [];
  List<QueueToken> _allTokens = [];
  QueueStats? _stats;
  QueueToken? _currentServing;
  bool _isLoading = true;
  String? _error;
  bool _isAuthError = false;

  // ── Multi-counter state ──
  List<CounterInfo> _counters = [];
  // Per-counter queues from API: { counterId: { activeToken, waitingTokens, ... } }
  List<Map<String, dynamic>> _counterQueues = [];
  // Filter: null = all counters, or a specific counter ID
  String? _selectedCounterId;

  bool get isHindi => AppLocalizations.isHindi;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _coldStorageId = widget.coldStorageId;
    _coldStorageName = widget.coldStorageName;
    _initializeAndLoad();
  }

  Future<void> _initializeAndLoad() async {
    // If cold storage ID not provided, fetch owner's cold storage
    if (_coldStorageId == null) {
      try {
        final result = await _coldStorageService.getMyColdStorages();
        debugPrint('🔍 getMyColdStorages result: $result');

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
            _allColdStorages = (storages).map<Map<String, dynamic>>((s) {
              return {
                '_id': s['_id']?.toString() ?? '',
                'name': s['name']?.toString() ?? 'Cold Storage',
                'address': s['address']?.toString() ?? '',
              };
            }).toList();
            final storage = storages.first;
            setState(() {
              _coldStorageId = storage['_id']?.toString();
              _coldStorageName =
                  storage['name']?.toString() ?? 'My Cold Storage';
            });
          } else {
            debugPrint('⚠️ No cold storages in list');
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
                      (isHindi
                          ? tr('cold_storage_load_failed')
                          : 'Failed to load cold storage'));
          });
          return;
        }
      } catch (e) {
        debugPrint('❌ Error fetching cold storages: $e');
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _error = 'Error: $e';
        });
        return;
      }
    }

    if (_coldStorageId != null) {
      await Future.wait([_loadQueue(), _loadCounters()]);
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _loadQueue(),
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

    if (event == 'token_queue_updated' ||
        event == 'token_request_pending' ||
        event == 'token_transferred') {
      _loadQueue();
      final action = data['action'];
      if (event == 'token_request_pending' || action == 'new_request') {
        _showSnackBar(
          isHindi
              ? '🆕 ${trArgs('new_token_request_notif', {'name': data['farmerName'] ?? ''})}'
              : '🆕 New token request: ${data['farmerName'] ?? ''}',
          Colors.blue,
        );
        if (_tabController.index != 0) {
          _tabController.animateTo(0);
        }
      } else if (action == 'cancelled') {
        _showSnackBar(
          isHindi
              ? trArgs('token_cancelled_notif', {
                  'number': data['tokenNumber']?.toString() ?? '',
                })
              : 'Token ${data['tokenNumber']} cancelled',
          Colors.orange,
        );
      } else if (event == 'token_transferred') {
        _loadCounters(); // refresh counter queue lengths too
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    _socketService.removeTokenEventListener(_onTokenEvent);
    super.dispose();
  }

  Future<void> _loadQueue() async {
    if (_coldStorageId == null) return;

    final result = await _tokenService.getTokenQueue(_coldStorageId!);

    if (result['success'] == true && result['data'] != null) {
      final data = result['data'];
      setState(() {
        _allTokens = (data['tokens'] as List)
            .map((json) => QueueToken.fromJson(json))
            .toList();
        _stats = QueueStats.fromJson(data['stats'] ?? {});
        _currentServing = data['currentServing'] != null
            ? QueueToken.fromJson(data['currentServing'])
            : null;
        // Parse per-counter queues from API
        if (data['counterQueues'] != null) {
          _counterQueues = List<Map<String, dynamic>>.from(
            data['counterQueues'],
          );
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
    if (_coldStorageId == null) return;
    try {
      final result = await _tokenService.getCounters(_coldStorageId!);
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        // API returns { counters: [...] }
        final list = data is List ? data : (data['counters'] as List? ?? []);
        if (mounted) {
          setState(() {
            _counters = list.map((j) => CounterInfo.fromJson(j as Map<String, dynamic>)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading counters: $e');
    }
  }

  // ── Cold Storage Picker ──
  void _showColdStoragePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  tr('select_cold_storage'),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const Divider(height: 1),
              ...(_allColdStorages.map((cs) {
                final isSelected = cs['_id'] == _coldStorageId;
                return ListTile(
                  leading: Icon(
                    Icons.ac_unit,
                    color: isSelected ? AppColors.primaryGreen : Colors.grey,
                  ),
                  title: Text(
                    cs['name'] ?? '',
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppColors.primaryGreen : null,
                    ),
                  ),
                  subtitle: Text(
                    cs['address'] ?? '',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    if (cs['_id'] != _coldStorageId) {
                      setState(() {
                        _coldStorageId = cs['_id'];
                        _coldStorageName = cs['name'];
                        _isLoading = true;
                        _allTokens = [];
                        _stats = null;
                        _currentServing = null;
                        _counters = [];
                        _counterQueues = [];
                        _selectedCounterId = null;
                      });
                      Future.wait([_loadQueue(), _loadCounters()]);
                    }
                  },
                );
              })),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ── Filtered token getters ──
  List<QueueToken> get _pendingTokens =>
      _allTokens.where((t) => t.status == 'pending').toList();

  List<QueueToken> get _waitingTokens {
    var tokens = _allTokens.where((t) => t.status == 'waiting').toList();
    if (_selectedCounterId != null) {
      tokens =
          tokens.where((t) => t.counterId == _selectedCounterId).toList();
    }
    return tokens;
  }

  List<QueueToken> get _activeTokens {
    var tokens = _allTokens
        .where((t) => ['called', 'in-service'].contains(t.status))
        .toList();
    if (_selectedCounterId != null) {
      tokens =
          tokens.where((t) => t.counterId == _selectedCounterId).toList();
    }
    return tokens;
  }

  List<QueueToken> get _completedTokens => _allTokens
      .where((t) => ['completed', 'skipped', 'cancelled'].contains(t.status))
      .toList();

  // ── Currently serving tokens across all counters ──
  List<QueueToken> get _allServingTokens {
    final serving = <QueueToken>[];
    for (final cq in _counterQueues) {
      if (cq['activeToken'] != null) {
        serving.add(QueueToken.fromJson(cq['activeToken']));
      }
    }
    // Also add _currentServing if not already included
    if (_currentServing != null &&
        !serving.any((t) => t.id == _currentServing!.id)) {
      serving.add(_currentServing!);
    }
    return serving;
  }

  // ══════════════════════════════════════════════════════════════
  //                        BUILD
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('token_management'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            if (_allColdStorages.length > 1)
              GestureDetector(
                onTap: _showColdStoragePicker,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _coldStorageName ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.swap_horiz,
                      size: 14,
                      color: Colors.white70,
                    ),
                  ],
                ),
              )
            else
              Text(
                _coldStorageName ?? '',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          // Counter management
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: tr('manage_counters'),
            onPressed: _showCounterManagement,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () {
            _loadQueue();
            _loadCounters();
          }),
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showIssueTokenDialog(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Column(
            children: [
              // Counter filter chips
              if (_counters.length > 1) _buildCounterChips(),
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            tr('pending_tab'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_stats != null && _stats!.pending > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_stats!.pending}',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            tr('waiting_tab'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_stats != null && _stats!.waiting > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_stats!.waiting}',
                              style: TextStyle(
                                color: AppColors.primaryGreen,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Tab(text: tr('active_tab')),
                  Tab(text: tr('done_tab')),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : Column(
                  children: [
                    // Per-counter serving banners
                    _buildServingBanners(),

                    // Stats bar
                    if (_stats != null) _buildStatsBar(),

                    // Token lists
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildPendingList(),
                          _buildTokenList(_waitingTokens, 'waiting'),
                          _buildTokenList(_activeTokens, 'active'),
                          _buildTokenList(_completedTokens, 'completed'),
                        ],
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _waitingTokens.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _showCallNextDialog(),
              backgroundColor: Colors.orange,
              icon: const Icon(Icons.notifications_active),
              label: Text(tr('call_next')),
            )
          : null,
    );
  }

  // ── Counter filter chips (below appbar title) ──
  Widget _buildCounterChips() {
    return Container(
      height: 36,
      padding: const EdgeInsets.only(bottom: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          // "All" chip
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(
                tr('all_counters'),
                style: TextStyle(
                  fontSize: 11,
                  color: _selectedCounterId == null
                      ? Colors.white
                      : Colors.white70,
                ),
              ),
              selected: _selectedCounterId == null,
              selectedColor: Colors.white24,
              backgroundColor: Colors.transparent,
              side: BorderSide(
                color: _selectedCounterId == null
                    ? Colors.white
                    : Colors.white30,
              ),
              onSelected: (_) => setState(() => _selectedCounterId = null),
            ),
          ),
          // Per-counter chips
          ..._counters.where((c) => c.isActive).map((counter) {
            final isSelected = _selectedCounterId == counter.id;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(
                  counter.name,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected ? Colors.white : Colors.white70,
                  ),
                ),
                selected: isSelected,
                selectedColor: Colors.white24,
                backgroundColor: Colors.transparent,
                side: BorderSide(
                  color: isSelected ? Colors.white : Colors.white30,
                ),
                avatar: counter.currentQueueLength > 0
                    ? CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.white,
                        child: Text(
                          '${counter.currentQueueLength}',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null,
                onSelected: (_) {
                  setState(() {
                    _selectedCounterId = isSelected ? null : counter.id;
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Serving banners for each counter ──
  Widget _buildServingBanners() {
    final servingTokens = _allServingTokens;
    if (servingTokens.isEmpty) return const SizedBox.shrink();

    // If a counter is selected, filter to that counter only
    final filtered = _selectedCounterId != null
        ? servingTokens
              .where((t) => t.counterId == _selectedCounterId)
              .toList()
        : servingTokens;

    if (filtered.isEmpty) return const SizedBox.shrink();

    return Column(
      children: filtered.map((token) => _buildServingBanner(token)).toList(),
    );
  }

  Widget _buildServingBanner(QueueToken token) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade600, Colors.orange.shade800],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              token.tokenNumber,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('now_serving'),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                Text(
                  token.farmerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  token.counterName ??
                      trArgs('counter_number', {
                        'number': token.counterNumber.toString(),
                      }),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          if (token.status == 'called')
            ElevatedButton(
              onPressed: () => _startServing(token.id),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
              child: Text(
                tr('start_btn'),
                style: TextStyle(color: Colors.orange.shade800),
              ),
            )
          else
            ElevatedButton(
              onPressed: () => _completeToken(token.id),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text(tr('done_tab')),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('${_stats!.pending}', tr('pending_tab'), Colors.amber),
          _statItem('${_stats!.waiting}', tr('waiting_tab'), Colors.blue),
          _statItem('${_stats!.inService}', tr('serving'), Colors.orange),
          _statItem('${_stats!.completed}', tr('done_tab'), Colors.green),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //                   TOKEN LIST BUILDERS
  // ══════════════════════════════════════════════════════════════

  Widget _buildTokenList(List<QueueToken> tokens, String type) {
    if (tokens.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'waiting'
                  ? Icons.hourglass_empty
                  : Icons.check_circle_outline,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              type == 'waiting'
                  ? tr('no_one_waiting')
                  : type == 'active'
                      ? tr('no_active_tokens')
                      : tr('none_completed_today'),
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadQueue,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: tokens.length,
        itemBuilder: (context, index) =>
            _buildTokenCard(tokens[index], index + 1),
      ),
    );
  }

  Widget _buildTokenCard(QueueToken token, int displayPosition) {
    Color statusColor;
    switch (token.status) {
      case 'waiting':
        statusColor = Colors.blue;
        break;
      case 'called':
        statusColor = Colors.orange;
        break;
      case 'in-service':
        statusColor = Colors.purple;
        break;
      case 'completed':
        statusColor = Colors.green;
        break;
      case 'skipped':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Token number
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor, width: 2),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    token.tokenNumber,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      fontSize: 16,
                    ),
                  ),
                  if (token.isWaiting)
                    Text(
                      '#${token.positionInQueue ?? displayPosition}',
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          token.farmerName,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isHindi
                              ? token.statusDisplayHindi
                              : token.statusDisplay,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          token.farmerPhone,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.inventory, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          isHindi
                              ? token.purposeDisplayHindi
                              : token.purposeDisplay,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (token.expectedQuantity != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${token.expectedQuantity} ${unitAbbr(token.unit)} ${token.potatoVariety ?? ''}',
                      style:
                          TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                  // Counter name + estimated wait
                  if (token.isWaiting || token.isCalled) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (token.counterName != null) ...[
                          Icon(Icons.meeting_room,
                              size: 13, color: Colors.grey[500]),
                          const SizedBox(width: 3),
                          Text(
                            token.counterName!,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (token.isWaiting &&
                            token.estimatedWaitMinutes > 0) ...[
                          Icon(Icons.timer,
                              size: 13, color: Colors.grey[500]),
                          const SizedBox(width: 3),
                          Text(
                            '~${token.estimatedWaitMinutes} min',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Actions
            if (token.isWaiting)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'call') _callSpecificToken(token);
                  if (value == 'skip') _skipToken(token.id);
                  if (value == 'transfer') _showTransferDialog(token);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'call',
                    child: Row(
                      children: [
                        const Icon(Icons.notifications, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(tr('call_btn')),
                      ],
                    ),
                  ),
                  if (_counters.length > 1)
                    PopupMenuItem(
                      value: 'transfer',
                      child: Row(
                        children: [
                          const Icon(Icons.swap_horiz, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(tr('transfer_token')),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'skip',
                    child: Row(
                      children: [
                        const Icon(Icons.skip_next, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(tr('skip_btn')),
                      ],
                    ),
                  ),
                ],
              )
            else if (token.status == 'skipped')
              IconButton(
                icon: const Icon(Icons.replay, color: Colors.blue),
                onPressed: () => _requeueToken(token.id),
                tooltip: tr('requeue_btn'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingList() {
    if (_pendingTokens.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              tr('no_pending_requests'),
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadQueue,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _pendingTokens.length,
        itemBuilder: (context, index) =>
            _buildPendingCard(_pendingTokens[index]),
      ),
    );
  }

  Widget _buildPendingCard(QueueToken token) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.shade300, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.amber.shade100,
                  radius: 24,
                  child: Text(
                    token.farmerName.isNotEmpty
                        ? token.farmerName[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade800,
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
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 14,
                            color: Colors.grey[500],
                          ),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tr('pending_tab'),
                    style: TextStyle(
                      color: Colors.amber.shade800,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.assignment, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  isHindi ? token.purposeDisplayHindi : token.purposeDisplay,
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
                if (token.expectedQuantity != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.scale, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    '${token.expectedQuantity} ${unitAbbr(token.unit)}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectToken(token),
                    icon: const Icon(Icons.close, size: 18),
                    label: Text(tr('reject_btn')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveToken(token),
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(tr('approve_issue')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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

  Widget _buildErrorView() {
    if (_isAuthError) {
      return AuthErrorHelper.buildSessionExpiredView(
        context: context,
        isHindi: isHindi,
      );
    }

    if (_error == tr('cold_storage_not_found') || _error == 'cold_storage_not_found') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              tr('cold_storage_not_found'),
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/cold-storage/register');
              },
              icon: const Icon(Icons.add),
              label: Text(tr('register_cold_storage')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
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

  // ══════════════════════════════════════════════════════════════
  //                     TOKEN ACTIONS
  // ══════════════════════════════════════════════════════════════

  Future<void> _approveToken(QueueToken token) async {
    final result = await _tokenService.approveTokenRequest(token.id);
    if (result['success'] == true) {
      final tokenData = result['data']?['token'];
      final tokenNum = tokenData?['tokenNumber'] ?? '';
      _showSnackBar(
        isHindi
            ? '✅ ${trArgs('token_approved_notif', {'number': tokenNum, 'name': token.farmerName})}'
            : '✅ Token approved: $tokenNum (${token.farmerName})',
        Colors.green,
      );
      _loadQueue();
      _loadCounters();
    } else {
      _showSnackBar(result['message'] ?? 'Failed', Colors.red);
    }
  }

  Future<void> _rejectToken(QueueToken token) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          tr('reject_request_q'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isHindi
                  ? trArgs('reject_token_confirm', {'name': token.farmerName})
                  : 'Reject token request from ${token.farmerName}?',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: tr('reason_optional'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel_btn')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              tr('reject_btn'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await _tokenService.rejectTokenRequest(
        token.id,
        reason: reasonController.text.isNotEmpty ? reasonController.text : null,
      );
      if (result['success'] == true) {
        _showSnackBar(tr('request_rejected'), Colors.orange);
        _loadQueue();
      } else {
        _showSnackBar(result['message'] ?? 'Failed', Colors.red);
      }
    }
    reasonController.dispose();
  }

  /// Show counter selection if multiple counters, then call next
  void _showCallNextDialog() {
    if (_counters.length <= 1 || _selectedCounterId != null) {
      // Single counter or already filtered — just call next
      _callNextToken(counterId: _selectedCounterId);
      return;
    }
    // Multiple counters — ask which one
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  tr('select_counter'),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const Divider(height: 1),
              ..._counters.where((c) => c.isActive).map((counter) {
                final waitCount = _allTokens
                    .where((t) =>
                        t.status == 'waiting' && t.counterId == counter.id)
                    .length;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      '${counter.number}',
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(counter.name),
                  subtitle: Text('$waitCount ${tr('waiting_tab')}'),
                  onTap: () {
                    Navigator.pop(context);
                    _callNextToken(counterId: counter.id);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _callNextToken({String? counterId}) async {
    if (_coldStorageId == null) return;
    final result = await _tokenService.callNextToken(
      _coldStorageId!,
      counterId: counterId,
    );
    if (result['success'] == true) {
      _showSnackBar(tr('next_token_called'), Colors.green);
      _loadQueue();
      _loadCounters();
    } else {
      _showSnackBar(result['message'] ?? 'Failed', Colors.red);
    }
  }

  Future<void> _callSpecificToken(QueueToken token) async {
    // Find tokens ahead in same counter
    final sameCounterWaiting = _allTokens
        .where((t) =>
            t.status == 'waiting' &&
            t.counterId == token.counterId &&
            t.sequenceNumber < token.sequenceNumber)
        .toList();

    if (sameCounterWaiting.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            tr('confirm_label'),
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: Text(
            isHindi
                ? trArgs('skip_farmers_confirm', {
                    'count': sameCounterWaiting.length.toString(),
                    'number': token.tokenNumber ?? '',
                  })
                : 'This will skip ${sameCounterWaiting.length} farmer(s) ahead of token ${token.tokenNumber}. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('cancel_btn')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: Text(
                tr('yes_skip'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    for (final t in sameCounterWaiting) {
      await _tokenService.skipToken(
        t.id,
        reason: 'Skipped to call another token',
      );
    }

    if (_coldStorageId != null) {
      await _tokenService.callNextToken(
        _coldStorageId!,
        counterId: token.counterId,
      );
    }
    _loadQueue();
    _loadCounters();
  }

  Future<void> _startServing(String tokenId) async {
    final result = await _tokenService.startServing(tokenId);
    if (result['success'] == true) {
      _showSnackBar(tr('service_started'), Colors.green);
      _loadQueue();
      _loadCounters();
    } else {
      _showSnackBar(result['message'] ?? 'Failed', Colors.red);
    }
  }

  Future<void> _completeToken(String tokenId) async {
    final result = await _tokenService.completeToken(tokenId);
    if (result['success'] == true) {
      _showSnackBar(tr('token_completed'), Colors.green);
      _loadQueue();
      _loadCounters();
    } else {
      _showSnackBar(result['message'] ?? 'Failed', Colors.red);
    }
  }

  Future<void> _skipToken(String tokenId) async {
    final result = await _tokenService.skipToken(tokenId);
    if (result['success'] == true) {
      _showSnackBar(tr('token_skipped'), Colors.orange);
      _loadQueue();
      _loadCounters();
    } else {
      _showSnackBar(result['message'] ?? 'Failed', Colors.red);
    }
  }

  Future<void> _requeueToken(String tokenId) async {
    final result = await _tokenService.requeueToken(tokenId);
    if (result['success'] == true) {
      _showSnackBar(tr('token_requeued'), Colors.green);
      _loadQueue();
      _loadCounters();
    } else {
      _showSnackBar(result['message'] ?? 'Failed', Colors.red);
    }
  }

  // ══════════════════════════════════════════════════════════════
  //                  TRANSFER TOKEN DIALOG
  // ══════════════════════════════════════════════════════════════

  void _showTransferDialog(QueueToken token) {
    final otherCounters =
        _counters.where((c) => c.isActive && c.id != token.counterId).toList();

    if (otherCounters.isEmpty) {
      _showSnackBar('No other counters available', Colors.orange);
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  tr('transfer_to_counter'),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${token.tokenNumber} — ${token.farmerName}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              ...otherCounters.map((counter) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      '${counter.number}',
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(counter.name),
                  subtitle: Text(
                    '${counter.currentQueueLength} ${tr('waiting_tab')}',
                  ),
                  trailing: const Icon(Icons.arrow_forward, size: 18),
                  onTap: () async {
                    Navigator.pop(context);
                    final result = await _tokenService.transferToken(
                      token.id,
                      targetCounterId: counter.id,
                    );
                    if (result['success'] == true) {
                      _showSnackBar(tr('token_transfer_success'), Colors.green);
                      _loadQueue();
                      _loadCounters();
                    } else {
                      _showSnackBar(
                        result['message'] ?? 'Transfer failed',
                        Colors.red,
                      );
                    }
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════
  //                 COUNTER MANAGEMENT
  // ══════════════════════════════════════════════════════════════

  void _showCounterManagement() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tr('manage_counters'),
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showAddCounterDialog();
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(tr('add_counter')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_counters.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Icon(Icons.meeting_room_outlined,
                                  size: 48, color: Colors.grey[300]),
                              const SizedBox(height: 8),
                              Text(
                                tr('no_counters'),
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  final result =
                                      await _tokenService.setupDefaultCounters(
                                    _coldStorageId!,
                                  );
                                  if (result['success'] == true) {
                                    _showSnackBar(
                                        tr('counter_added'), Colors.green);
                                    _loadCounters();
                                  } else {
                                    _showSnackBar(
                                        result['message'] ?? 'Failed', Colors.red);
                                  }
                                },
                                child: Text(tr('setup_counters')),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...List.generate(_counters.length, (i) {
                        final counter = _counters[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: counter.isActive
                                  ? AppColors.primaryGreen.withOpacity(0.15)
                                  : Colors.grey.shade200,
                              child: Text(
                                '${counter.number}',
                                style: TextStyle(
                                  color: counter.isActive
                                      ? AppColors.primaryGreen
                                      : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              counter.name,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '~${counter.averageServiceTime} min • ${counter.currentQueueLength} ${tr('waiting_tab')}'
                              '${!counter.isActive ? ' • ${tr('counter_inactive')}' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: counter.isActive
                                    ? Colors.grey[600]
                                    : Colors.red[300],
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) async {
                                Navigator.pop(context);
                                if (value == 'edit') {
                                  _showEditCounterDialog(counter);
                                } else if (value == 'toggle') {
                                  await _tokenService.updateCounter(
                                    counter.id,
                                    isActive: !counter.isActive,
                                  );
                                  _loadCounters();
                                } else if (value == 'delete') {
                                  _confirmDeleteCounter(counter);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.edit, size: 18),
                                      const SizedBox(width: 8),
                                      Text(tr('edit_btn')),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Row(
                                    children: [
                                      Icon(
                                        counter.isActive
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(counter.isActive
                                          ? tr('counter_inactive')
                                          : tr('active_tab')),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.delete,
                                          size: 18, color: Colors.red),
                                      const SizedBox(width: 8),
                                      Text(
                                        tr('delete_btn'),
                                        style:
                                            const TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddCounterDialog() {
    final nameController = TextEditingController();
    final timeController = TextEditingController(text: '10');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          tr('add_counter'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: tr('counter_name'),
                hintText: 'e.g. Counter 3',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: timeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr('avg_service_time'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('cancel_btn')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await _tokenService.createCounter(
                _coldStorageId!,
                name: nameController.text.isNotEmpty
                    ? nameController.text
                    : null,
                averageServiceTime: int.tryParse(timeController.text),
              );
              if (result['success'] == true) {
                _showSnackBar(tr('counter_added'), Colors.green);
                _loadCounters();
              } else {
                _showSnackBar(
                    result['message'] ?? 'Failed', Colors.red);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
            ),
            child: Text(
              tr('add_counter'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditCounterDialog(CounterInfo counter) {
    final nameController = TextEditingController(text: counter.name);
    final timeController =
        TextEditingController(text: '${counter.averageServiceTime}');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${tr('edit_btn')} ${counter.name}',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: tr('counter_name'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: timeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr('avg_service_time'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('cancel_btn')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await _tokenService.updateCounter(
                counter.id,
                name: nameController.text,
                averageServiceTime: int.tryParse(timeController.text),
              );
              if (result['success'] == true) {
                _showSnackBar(tr('counter_updated'), Colors.green);
                _loadCounters();
              } else {
                _showSnackBar(
                    result['message'] ?? 'Failed', Colors.red);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
            ),
            child: Text(
              tr('save_label'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCounter(CounterInfo counter) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${tr('delete_btn')} ${counter.name}?',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(tr('delete_counter_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('cancel_btn')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final result =
                  await _tokenService.deleteCounter(counter.id);
              if (result['success'] == true) {
                _showSnackBar(tr('counter_deleted'), Colors.green);
                _loadCounters();
                _loadQueue();
              } else {
                _showSnackBar(
                    result['message'] ?? 'Failed', Colors.red);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              tr('delete_btn'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //                  ISSUE TOKEN DIALOG
  // ══════════════════════════════════════════════════════════════

  void _showIssueTokenDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final quantityController = TextEditingController();
    String selectedPurpose = 'storage';
    String? selectedVariety;
    String? selectedCounterId;

    final varieties = ['Jyoti', 'Kufri Pukhraj', 'Chipsona', '3797', 'Other'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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
                Text(
                  tr('issue_new_token'),
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: tr('farmer_name_required'),
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: '',
                    labelText: tr('phone_number_required'),
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  initialValue: selectedPurpose,
                  decoration: InputDecoration(
                    labelText: tr('purpose'),
                    prefixIcon: const Icon(Icons.assignment),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'storage',
                      child: Text(tr('storage_purpose')),
                    ),
                    DropdownMenuItem(
                      value: 'withdrawal',
                      child: Text(tr('withdrawal')),
                    ),
                    DropdownMenuItem(
                      value: 'inspection',
                      child: Text(tr('inspection')),
                    ),
                  ],
                  onChanged: (v) =>
                      setModalState(() => selectedPurpose = v!),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: trArgs('quantity_in_unit', {
                            'unit': tr('quintal_abbr'),
                          }),
                          prefixIcon: const Icon(Icons.scale),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedVariety,
                        decoration: InputDecoration(
                          labelText: tr('variety_label'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: varieties
                            .map(
                              (v) =>
                                  DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setModalState(() => selectedVariety = v),
                      ),
                    ),
                  ],
                ),

                // Counter selection (if multiple counters)
                if (_counters.length > 1) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedCounterId,
                    decoration: InputDecoration(
                      labelText:
                          '${tr('select_counter')} (${isHindi ? 'वैकल्पिक' : 'Optional'})',
                      prefixIcon: const Icon(Icons.meeting_room),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text(
                            isHindi ? 'स्वचालित (सर्वश्रेष्ठ)' : 'Auto (Best)'),
                      ),
                      ..._counters
                          .where((c) => c.isActive)
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          ),
                    ],
                    onChanged: (v) =>
                        setModalState(() => selectedCounterId = v),
                  ),
                ],

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.isEmpty ||
                          phoneController.text.isEmpty) {
                        _showSnackBar(
                          isHindi
                              ? tr('name_phone_required')
                              : 'Name and phone are required',
                          Colors.red,
                        );
                        return;
                      }

                      Navigator.pop(context);

                      final result = await _tokenService.issueToken(
                        coldStorageId: _coldStorageId!,
                        farmerName: nameController.text,
                        farmerPhone: phoneController.text,
                        purpose: selectedPurpose,
                        expectedQuantity: double.tryParse(
                          quantityController.text,
                        ),
                        potatoVariety: selectedVariety,
                        counterId: selectedCounterId,
                      );

                      if (result['success'] == true) {
                        final token = result['data']['token'];
                        _showSnackBar(
                          trArgs('token_issued_msg', {
                            'tokenNumber': token['tokenNumber'].toString(),
                          }),
                          Colors.green,
                        );
                        _loadQueue();
                        _loadCounters();
                      } else {
                        _showSnackBar(
                          result['message'] ?? 'Failed',
                          Colors.red,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      tr('issue_token'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }
}
