import 'package:aloo_sbji_mandi/core/constants/state_city_data.dart';
import 'package:aloo_sbji_mandi/core/service/auth_service.dart';
import 'package:aloo_sbji_mandi/core/service/boli_alert_service.dart';
import 'package:aloo_sbji_mandi/core/service/cold_storage_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/screens/cold_storage/manage_storage_screen.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/utils/ist_datetime.dart';

class ManageBoliAlertsScreen extends StatefulWidget {
  const ManageBoliAlertsScreen({super.key});

  @override
  State<ManageBoliAlertsScreen> createState() => _ManageBoliAlertsScreenState();
}

class _ManageBoliAlertsScreenState extends State<ManageBoliAlertsScreen> {
  final BoliAlertService _service = BoliAlertService();
  List<BoliAlert> _myAlerts = [];
  bool _isLoading = true;
  String? _error;

  bool get isHindi => AppLocalizations.isHindi;

  @override
  void initState() {
    super.initState();
    _loadMyAlerts();
  }

  Future<void> _loadMyAlerts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _service.getMyBoliAlerts();
      if (result['success'] == true && result['data'] != null) {
        setState(() {
          _myAlerts = (result['data'] as List)
              .map((json) => BoliAlert.fromJson(json))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = result['message'] ?? 'Failed to load alerts';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          tr('manage_boli_alerts'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorView()
          : _myAlerts.isEmpty
          ? _buildEmptyView()
          : _buildAlertsList(),
      // Only show FAB when there are alerts (empty state has its own button)
      floatingActionButton: _myAlerts.isNotEmpty
          ? Container(
              margin: const EdgeInsets.only(bottom: 16, right: 8),
              child: FloatingActionButton.extended(
                onPressed: () => _showCreateAlertDialog(),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                elevation: 8,
                icon: const Icon(Icons.add_alert, size: 28),
                label: Text(
                  tr('new_alert'),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                extendedPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            tr('something_went_wrong'),
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(_error ?? '', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadMyAlerts,
            icon: const Icon(Icons.refresh),
            label: Text(tr('retry_btn')),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            tr('no_boli_alerts'),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr('create_first_weekly_alert'),
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreateAlertDialog(),
            icon: const Icon(Icons.add, size: 24),
            label: Text(
              tr('create_alert'),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsList() {
    return RefreshIndicator(
      onRefresh: _loadMyAlerts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myAlerts.length,
        itemBuilder: (context, index) {
          final alert = _myAlerts[index];
          return _buildAlertCard(alert);
        },
      ),
    );
  }

  Widget _buildAlertCard(BoliAlert alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: alert.isRecurring ? AppColors.primaryGreen : Colors.orange,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  alert.isRecurring ? Icons.repeat : Icons.schedule,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  alert.isRecurring
                      ? tr('weekly_auction')
                      : tr('one_time_auction'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  isHindi ? alert.dayNameHindi : alert.dayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  alert.title,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Details grid
                Row(
                  children: [
                    Expanded(
                      child: _infoItem(
                        Icons.calendar_today,
                        tr('next_auction'),
                        DateFormat('dd MMM yyyy').format(alert.nextBoliDate.toIST()),
                      ),
                    ),
                    Expanded(
                      child: _infoItem(
                        Icons.access_time,
                        tr('time_label'),
                        alert.boliTimeFormatted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _infoItem(
                        Icons.location_on,
                        tr('location_label'),
                        alert.location.city,
                      ),
                    ),
                    Expanded(
                      child: _infoItem(
                        Icons.phone,
                        tr('contact_label'),
                        alert.contactPhone,
                      ),
                    ),
                  ],
                ),

                // Potato varieties
                if (alert.potatoVarieties.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: alert.potatoVarieties
                        .map(
                          (v) => Chip(
                            label: Text(
                              v,
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor: Colors.green[50],
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        )
                        .toList(),
                  ),
                ],

                const Divider(height: 24),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showEditAlertDialog(alert),
                      icon: const Icon(Icons.edit, size: 18),
                      label: Text(tr('edit_btn')),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _confirmDelete(alert),
                      icon: const Icon(
                        Icons.delete,
                        size: 18,
                        color: Colors.red,
                      ),
                      label: Text(
                        tr('delete_btn'),
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCreateAlertDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BoliAlertFormSheet(
        onSaved: () {
          Navigator.pop(context);
          _loadMyAlerts();
        },
      ),
    );
  }

  void _showEditAlertDialog(BoliAlert alert) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BoliAlertFormSheet(
        alert: alert,
        onSaved: () {
          Navigator.pop(context);
          _loadMyAlerts();
        },
      ),
    );
  }

  void _confirmDelete(BoliAlert alert) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('delete_alert_q')),
        content: Text(
          trArgs('confirm_delete_alert_msg', {'title': alert.title}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('cancel_btn')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAlert(alert);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(tr('delete_btn')),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAlert(BoliAlert alert) async {
    final result = await _service.deleteBoliAlert(alert.id);
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('alert_deleted')),
          backgroundColor: Colors.green,
        ),
      );
      _loadMyAlerts();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? tr('failed_to_delete')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// Form for creating/editing boli alerts
class BoliAlertFormSheet extends StatefulWidget {
  final BoliAlert? alert;
  final VoidCallback onSaved;

  const BoliAlertFormSheet({super.key, this.alert, required this.onSaved});

  @override
  State<BoliAlertFormSheet> createState() => _BoliAlertFormSheetState();
}

class _BoliAlertFormSheetState extends State<BoliAlertFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final BoliAlertService _service = BoliAlertService();
  final ColdStorageService _coldStorageService = ColdStorageService();

  bool _isLoading = false;
  bool _isLoadingColdStorage = true;
  String? _coldStorageId;
  String? _coldStorageError;
  List<Map<String, dynamic>> _myColdStorages = [];
  bool get isHindi => AppLocalizations.isHindi;
  bool get isEditing => widget.alert != null;

  // Form fields
  late TextEditingController _titleController;
  late TextEditingController _contactPersonController;
  late TextEditingController _contactPhoneController;
  late TextEditingController _addressController;
  late TextEditingController _landmarkController;
  late TextEditingController _expectedQuantityController;
  late TextEditingController _priceMinController;
  late TextEditingController _priceMaxController;
  late TextEditingController _instructionsController;

  // State & City & District dropdowns
  String? _selectedState;
  String? _selectedDistrict;
  String? _selectedCity;
  List<String> _districts = [];
  List<String> _cities = [];
  String _targetAudience = 'all'; // 'customers' or 'all'

  int _selectedDayOfWeek = 0; // Sunday
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  bool _isRecurring = true;
  List<String> _selectedVarieties = [];

  // States list - uses merged StateCityData (all Indian states + UTs)
  List<String> get _states => ['Others', ...StateCityData.states];

  final List<String> _potatoVarieties = [
    'Jyoti',
    'Kufri Pukhraj',
    'Chipsona',
    'Kufri Badshah',
    '3797',
    'Kufri Sindhuri',
    'Lady Rosetta',
    'Kufri Chandramukhi',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadMyColdStorage();
    if (!isEditing) {
      _autoFetchLocationFromProfile();
    }
  }

  Future<void> _autoFetchLocationFromProfile() async {
    try {
      final authService = AuthService();
      final user = await authService.getCurrentUser();
      if (user == null) return;

      final address = user['address'] as Map<String, dynamic>?;
      if (address == null) return;

      final profileState = address['state']?.toString() ?? '';
      final profileDistrict = address['district']?.toString() ?? '';
      final profileCity = address['village']?.toString() ?? '';

      if (profileState.isEmpty) return;

      // Match state from profile to dropdown list
      String? matchedState;
      for (final s in _states) {
        if (s.toLowerCase() == profileState.toLowerCase() ||
            profileState.toLowerCase().contains(s.toLowerCase()) ||
            s.toLowerCase().contains(profileState.toLowerCase())) {
          matchedState = s;
          break;
        }
      }

      if (matchedState == null || matchedState == 'Others') return;

      setState(() {
        _selectedState = matchedState;
        _districts = StateCityData.getCitiesForState(matchedState ?? '');

        // Match district
        if (profileDistrict.isNotEmpty) {
          String? matchedDistrict;
          for (final d in _districts) {
            if (d.toLowerCase() == profileDistrict.toLowerCase() ||
                profileDistrict.toLowerCase().contains(d.toLowerCase()) ||
                d.toLowerCase().contains(profileDistrict.toLowerCase())) {
              matchedDistrict = d;
              break;
            }
          }
          if (matchedDistrict != null && matchedDistrict != 'Others') {
            _selectedDistrict = matchedDistrict;
            _cities = StateCityData.getVillagesForDistrict(matchedDistrict);
            if (_cities.isEmpty) {
              _cities = StateCityData.getCitiesForState(matchedState ?? '');
            }
          } else {
            _cities = StateCityData.getCitiesForState(matchedState ?? '');
          }
        } else {
          _cities = StateCityData.getCitiesForState(matchedState ?? '');
        }

        // Match city
        if (profileCity.isNotEmpty && _cities.isNotEmpty) {
          for (final c in _cities) {
            if (c.toLowerCase() == profileCity.toLowerCase() ||
                profileCity.toLowerCase().contains(c.toLowerCase()) ||
                c.toLowerCase().contains(profileCity.toLowerCase())) {
              _selectedCity = c;
              break;
            }
          }
        }
      });
    } catch (e) {
      print('Auto-fetch location error: $e');
    }
  }

  Future<void> _loadMyColdStorage() async {
    if (isEditing) {
      // If editing, we already have the cold storage from the alert
      setState(() {
        _coldStorageId = widget.alert?.coldStorageId;
        _isLoadingColdStorage = false;
      });
      return;
    }

    try {
      final result = await _coldStorageService.getMyColdStorages();
      print('Boli Alert - Cold Storage Result: $result');

      if (result['success'] == true && result['data'] != null) {
        // The API returns { coldStorages: [...], count: N }
        final data = result['data'];
        final storages = data['coldStorages'] as List? ?? data as List? ?? [];

        if (storages.isNotEmpty) {
          setState(() {
            _myColdStorages = storages
                .map(
                  (s) => {
                    'id': s['_id']?.toString() ?? '',
                    'name': s['name']?.toString() ?? 'Unknown',
                    'city': s['city']?.toString() ?? '',
                  },
                )
                .toList();
            _coldStorageId = _myColdStorages[0]['id'];
            _isLoadingColdStorage = false;
          });
        } else {
          setState(() {
            _coldStorageError = tr('register_cs_first_boli');
            _isLoadingColdStorage = false;
          });
        }
      } else {
        setState(() {
          _coldStorageError = tr('register_cs_first_boli');
          _isLoadingColdStorage = false;
        });
      }
    } catch (e) {
      print('Boli Alert - Cold Storage Error: $e');
      setState(() {
        _coldStorageError = 'Error: $e';
        _isLoadingColdStorage = false;
      });
    }
  }

  void _initializeControllers() {
    final alert = widget.alert;

    _titleController = TextEditingController(text: alert?.title ?? '');
    _contactPersonController = TextEditingController(
      text: alert?.contactPerson ?? '',
    );
    _contactPhoneController = TextEditingController(
      text: alert?.contactPhone ?? '',
    );
    _addressController = TextEditingController(
      text: alert?.location.address ?? '',
    );
    _landmarkController = TextEditingController(
      text: alert?.location.landmark ?? '',
    );
    _expectedQuantityController = TextEditingController(
      text: alert?.expectedQuantity?.toString() ?? '',
    );
    _priceMinController = TextEditingController(
      text: alert?.expectedPriceMin?.toString() ?? '',
    );
    _priceMaxController = TextEditingController(
      text: alert?.expectedPriceMax?.toString() ?? '',
    );
    _instructionsController = TextEditingController(
      text: alert?.instructions ?? '',
    );

    // Initialize state, district and city
    _selectedState = alert?.location.state ?? 'Uttar Pradesh';
    _districts = StateCityData.getCitiesForState(_selectedState ?? '');
    _selectedDistrict = alert?.location.district;
    if (_selectedDistrict != null && !_districts.contains(_selectedDistrict)) {
      _districts.insert(0, _selectedDistrict!);
    }
    _cities = _selectedDistrict != null
        ? (StateCityData.getVillagesForDistrict(_selectedDistrict!).isNotEmpty
              ? StateCityData.getVillagesForDistrict(_selectedDistrict!)
              : StateCityData.getCitiesForState(_selectedState ?? ''))
        : StateCityData.getCitiesForState(_selectedState ?? '');
    _selectedCity = alert?.location.city;
    if (_selectedCity != null && !_cities.contains(_selectedCity)) {
      _cities.insert(0, _selectedCity!);
    }

    // Initialize target audience
    _targetAudience = alert?.targetAudience ?? 'all';

    if (alert != null) {
      _selectedDayOfWeek = alert.dayOfWeek;
      _isRecurring = alert.isRecurring;
      _selectedVarieties = List.from(alert.potatoVarieties);

      // Parse time
      final timeParts = alert.boliTime.split(':');
      if (timeParts.length == 2) {
        _selectedTime = TimeOfDay(
          hour: int.tryParse(timeParts[0]) ?? 10,
          minute:
              int.tryParse(timeParts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contactPersonController.dispose();
    _contactPhoneController.dispose();
    _addressController.dispose();
    _landmarkController.dispose();
    _expectedQuantityController.dispose();
    _priceMinController.dispose();
    _priceMaxController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    isEditing ? tr('edit_boli_alert') : tr('new_boli_alert'),
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Form
            Expanded(
              child: _isLoadingColdStorage
                  ? const Center(child: CircularProgressIndicator())
                  : _coldStorageError != null && !isEditing
                  ? _buildNoColdStorageView()
                  : Form(
                      key: _formKey,
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // Cold Storage Selection (only for new alerts)
                          if (!isEditing && _myColdStorages.length > 1) ...[
                            Text(
                              tr('select_cold_storage'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _coldStorageId,
                                  isExpanded: true,
                                  icon: const Icon(
                                    Icons.arrow_drop_down,
                                    color: AppColors.primaryGreen,
                                  ),
                                  items: _myColdStorages.map((storage) {
                                    return DropdownMenuItem<String>(
                                      value: storage['id'],
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.warehouse,
                                            color: AppColors.primaryGreen,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${storage['name']} - ${storage['city']}',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() => _coldStorageId = value);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Show selected cold storage info if only one
                          if (!isEditing && _myColdStorages.length == 1) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.primaryGreen.withOpacity(
                                    0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.warehouse,
                                    color: AppColors.primaryGreen,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tr('cold_storage_label'),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          '${_myColdStorages[0]['name']} - ${_myColdStorages[0]['city']}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // â”€â”€ Target Audience â”€â”€
                          Text(
                            tr('send_alert_to'),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(
                                    () => _targetAudience = 'customers',
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _targetAudience == 'customers'
                                          ? AppColors.primaryGreen.withOpacity(
                                              0.15,
                                            )
                                          : Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _targetAudience == 'customers'
                                            ? AppColors.primaryGreen
                                            : Colors.grey[300]!,
                                        width: _targetAudience == 'customers'
                                            ? 2
                                            : 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.people,
                                          color: _targetAudience == 'customers'
                                              ? AppColors.primaryGreen
                                              : Colors.grey[500],
                                          size: 28,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          tr('my_customers'),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight:
                                                _targetAudience == 'customers'
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color:
                                                _targetAudience == 'customers'
                                                ? AppColors.primaryGreen
                                                : Colors.grey[700],
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          tr('stored_potato_subtitle'),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _targetAudience = 'all'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _targetAudience == 'all'
                                          ? AppColors.primaryGreen.withOpacity(
                                              0.15,
                                            )
                                          : Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _targetAudience == 'all'
                                            ? AppColors.primaryGreen
                                            : Colors.grey[300]!,
                                        width: _targetAudience == 'all' ? 2 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.public,
                                          color: _targetAudience == 'all'
                                              ? AppColors.primaryGreen
                                              : Colors.grey[500],
                                          size: 28,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          tr('all_farmers'),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: _targetAudience == 'all'
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: _targetAudience == 'all'
                                                ? AppColors.primaryGreen
                                                : Colors.grey[700],
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          tr('nearby_area_subtitle'),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32),

                          // Title
                          _buildTextField(
                            controller: _titleController,
                            label: tr('auction_title'),
                            hint: tr('auction_title_hint'),
                            icon: Icons.title,
                            validator: (v) => v?.isEmpty == true
                                ? tr('title_field_required')
                                : null,
                          ),
                          const SizedBox(height: 16),

                          // Day of week
                          Text(
                            tr('auction_day'),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 48,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: 7,
                              itemBuilder: (context, index) {
                                final dayAbbrKeys = [
                                  'day_abbr_sun',
                                  'day_abbr_mon',
                                  'day_abbr_tue',
                                  'day_abbr_wed',
                                  'day_abbr_thu',
                                  'day_abbr_fri',
                                  'day_abbr_sat',
                                ];
                                final isSelected = _selectedDayOfWeek == index;

                                return GestureDetector(
                                  onTap: () => setState(
                                    () => _selectedDayOfWeek = index,
                                  ),
                                  child: Container(
                                    width: 50,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primaryGreen
                                          : AppColors.surfaceVariant(context),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      tr(dayAbbrKeys[index]),
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.black,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Time picker
                          GestureDetector(
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: _selectedTime,
                              );
                              if (time != null) {
                                setState(() => _selectedTime = time);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    color: AppColors.primaryGreen,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    tr('time_label'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _selectedTime.format(context),
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.edit, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Recurring toggle
                          SwitchListTile(
                            value: _isRecurring,
                            onChanged: (v) => setState(() => _isRecurring = v),
                            title: Text(tr('repeat_every_week')),
                            subtitle: Text(tr('auction_same_day_weekly')),
                            activeThumbColor: AppColors.primaryGreen,
                          ),
                          const Divider(height: 32),

                          // Contact info
                          Text(
                            tr('contact_information'),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),

                          _buildTextField(
                            controller: _contactPersonController,
                            label: tr('contact_person_label'),
                            icon: Icons.person,
                            validator: (v) =>
                                v?.isEmpty == true ? tr('name_required') : null,
                          ),
                          const SizedBox(height: 12),

                          _buildTextField(
                            controller: _contactPhoneController,
                            label: tr('phone_number'),
                            icon: Icons.phone,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (v) => v?.isEmpty == true
                                ? tr('phone_required')
                                : null,
                          ),
                          const Divider(height: 32),

                          // Location
                          Text(
                            tr('location_label'),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),

                          _buildTextField(
                            controller: _addressController,
                            label: tr('address_label'),
                            icon: Icons.location_on,
                            maxLines: 2,
                            validator: (v) => v?.isEmpty == true
                                ? tr('address_required')
                                : null,
                          ),
                          const SizedBox(height: 12),

                          // State Dropdown (with Others at top)
                          DropdownButtonFormField<String>(
                            initialValue: _selectedState,
                            decoration: InputDecoration(
                              labelText: tr('state_label'),
                              prefixIcon: const Icon(
                                Icons.map,
                                color: AppColors.primaryGreen,
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                            ),
                            items: _states
                                .map(
                                  (state) => DropdownMenuItem(
                                    value: state,
                                    child: Text(
                                      state,
                                      style: TextStyle(
                                        fontWeight: state == 'Others'
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: state == 'Others'
                                            ? Colors.orange[800]
                                            : null,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedState = value;
                                _districts = StateCityData.getCitiesForState(value ?? '');
                                _selectedDistrict = null;
                                _cities = StateCityData.getCitiesForState(value ?? '');
                                _selectedCity = null;
                              });
                            },
                            validator: (v) =>
                                v == null ? tr('select_state_label') : null,
                          ),
                          const SizedBox(height: 12),

                          // District Dropdown (with Others at top)
                          DropdownButtonFormField<String>(
                            initialValue: _selectedDistrict,
                            decoration: InputDecoration(
                              labelText: tr('district_label'),
                              prefixIcon: const Icon(
                                Icons.domain,
                                color: AppColors.primaryGreen,
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                            ),
                            items: _districts
                                .map(
                                  (district) => DropdownMenuItem(
                                    value: district,
                                    child: Text(
                                      district,
                                      style: TextStyle(
                                        fontWeight: district == 'Others'
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: district == 'Others'
                                            ? Colors.orange[800]
                                            : null,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedDistrict = value;
                                final villageCities = StateCityData.getVillagesForDistrict(value ?? '');
                                _cities = villageCities.isNotEmpty
                                    ? villageCities
                                    : StateCityData.getCitiesForState(_selectedState ?? '');
                                _selectedCity = null;
                              });
                            },
                          ),
                          const SizedBox(height: 12),

                          // City Dropdown (with Others at top)
                          DropdownButtonFormField<String>(
                            initialValue: _selectedCity,
                            decoration: InputDecoration(
                              labelText: tr('city_label'),
                              prefixIcon: const Icon(
                                Icons.location_city,
                                color: AppColors.primaryGreen,
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                            ),
                            items: _cities
                                .map(
                                  (city) => DropdownMenuItem(
                                    value: city,
                                    child: Text(
                                      city,
                                      style: TextStyle(
                                        fontWeight: city == 'Others'
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: city == 'Others'
                                            ? Colors.orange[800]
                                            : null,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() => _selectedCity = value);
                            },
                            validator: (v) =>
                                v == null ? tr('select_city') : null,
                          ),
                          const SizedBox(height: 12),

                          _buildTextField(
                            controller: _landmarkController,
                            label: tr('landmark_label'),
                            hint: tr('optional'),
                            icon: Icons.place,
                          ),
                          const SizedBox(height: 16),

                          _buildTextField(
                            controller: _instructionsController,
                            label: tr('additional_instructions'),
                            hint: tr('optional'),
                            icon: Icons.info_outline,
                            maxLines: 3,
                          ),

                          const SizedBox(height: 32),

                          // Submit button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _submitForm,
                              icon: _isLoading
                                  ? const SizedBox.shrink()
                                  : Icon(
                                      isEditing
                                          ? Icons.update
                                          : Icons.notifications_active,
                                    ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              label: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      isEditing
                                          ? tr('update_alert_btn')
                                          : tr('create_alert'),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoColdStorageView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warehouse_outlined, size: 80, color: Colors.orange[300]),
            const SizedBox(height: 24),
            Text(
              tr('no_cold_storage_found'),
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              tr('register_cs_for_boli'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageStorageScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add_business),
              label: Text(
                tr('register_cs_btn_boli'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null
            ? Icon(icon, color: AppColors.primaryGreen)
            : null,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final hour = _selectedTime.hourOfPeriod == 0 ? 12 : _selectedTime.hourOfPeriod;
    final amPm = _selectedTime.period == DayPeriod.am ? 'AM' : 'PM';
    final timeString =
        '${hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')} $amPm';

    final data = {
      if (!isEditing && _coldStorageId != null) 'coldStorageId': _coldStorageId,
      'title': _titleController.text,
      'dayOfWeek': _selectedDayOfWeek,
      'boliTime': timeString,
      'isRecurring': _isRecurring,
      'contactPerson': _contactPersonController.text,
      'contactPhone': _contactPhoneController.text,
      'location': {
        'address': _addressController.text,
        'city': _selectedCity ?? '',
        'district': _selectedDistrict ?? '',
        'state': _selectedState ?? 'Uttar Pradesh',
        'landmark': _landmarkController.text.isNotEmpty
            ? _landmarkController.text
            : null,
      },
      'targetAudience': _targetAudience,
      'potatoVarieties': _selectedVarieties,
      if (_expectedQuantityController.text.isNotEmpty)
        'expectedQuantity': double.tryParse(_expectedQuantityController.text),
      if (_priceMinController.text.isNotEmpty)
        'expectedPriceMin': double.tryParse(_priceMinController.text),
      if (_priceMaxController.text.isNotEmpty)
        'expectedPriceMax': double.tryParse(_priceMaxController.text),
      if (_instructionsController.text.isNotEmpty)
        'instructions': _instructionsController.text,
    };

    Map<String, dynamic> result;
    if (isEditing) {
      result = await _service.updateBoliAlert(widget.alert!.id, data);
    } else {
      result = await _service.createBoliAlertFromMap(data);
    }

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? tr('alert_updated') : tr('alert_created')),
          backgroundColor: Colors.green,
        ),
      );
      widget.onSaved();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? tr('failed_to_save')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}