import 'dart:convert';
import 'dart:io';

import 'package:aloo_sbji_mandi/core/constants/state_city_data.dart';
import 'package:aloo_sbji_mandi/core/service/cold_storage_service.dart';
import 'package:aloo_sbji_mandi/core/service/google_geocoding_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/toast_helper.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:aloo_sbji_mandi/widgets/location_map_widget.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ManageStorageScreen extends StatefulWidget {
  const ManageStorageScreen({super.key});

  @override
  State<ManageStorageScreen> createState() => _ManageStorageScreenState();
}

class _ManageStorageScreenState extends State<ManageStorageScreen> {
  final ColdStorageService _coldStorageService = ColdStorageService();
  List<dynamic> _myStorages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMyStorages();
  }

  Future<void> _loadMyStorages() async {
    setState(() => _isLoading = true);

    final result = await _coldStorageService.getMyColdStorages();

    setState(() {
      _isLoading = false;
      if (result['success']) {
        _myStorages = result['data']['coldStorages'] ?? [];
      }
    });
  }

  Future<void> _toggleAvailability(String storageId, bool currentStatus) async {
    // Show bilingual confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              currentStatus ? Icons.visibility_off : Icons.visibility,
              color: currentStatus ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                currentStatus
                    ? tr('mark_unavailable')
                    : tr('mark_available'),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          currentStatus
              ? tr('storage_hidden_msg')
              : tr('storage_visible_msg'),
          style: TextStyle(color: Colors.grey[700], height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              tr('cancel'),
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: currentStatus
                  ? Colors.red
                  : AppColors.primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              currentStatus ? tr('yes_unavailable') : tr('yes_available'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await _coldStorageService.toggleAvailability(storageId);

    if (result['success']) {
      _loadMyStorages();
      ToastHelper.showSuccess(
        context,
        currentStatus
            ? tr('storage_hidden_msg')
            : tr('storage_visible_msg'),
      );
    } else {
      ToastHelper.showError(context, result['message'] ?? tr('failed_to_update'));
    }
  }

  // ── Manager Assignment ───────────────────────────────────────────────
  Future<void> _assignManager(String storageId) async {
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final phone = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.person_add, color: AppColors.primaryGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tr('assign_manager'),
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr('enter_manager_phone'),
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: tr('phone_number'),
                  prefixText: '+91 ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.phone),
                ),
                validator: (v) {
                  if (v == null || v.length != 10) {
                    return tr('invalid_phone_error');
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              tr('cancel'),
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, phoneController.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              tr('assign'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (phone == null || phone.isEmpty) return;

    setState(() => _isLoading = true);
    final result = await _coldStorageService.assignManager(
      coldStorageId: storageId,
      managerPhone: phone,
    );
    setState(() => _isLoading = false);

    if (result['success']) {
      _loadMyStorages();
      if (!mounted) return;
      ToastHelper.showSuccess(
        context,
        tr('manager_assigned'),
      );
    } else {
      if (!mounted) return;
      ToastHelper.showError(
        context,
        result['message'] ?? tr('failed_to_assign_manager'),
      );
    }
  }

  Future<void> _removeManager(String storageId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.person_remove, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tr('remove_manager'),
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ],
        ),
        content: Text(
          tr('manager_access_lost_msg'),
          style: TextStyle(color: Colors.grey[700], height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              tr('cancel'),
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              tr('remove'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final result = await _coldStorageService.removeManager(storageId);
    setState(() => _isLoading = false);

    if (result['success']) {
      _loadMyStorages();
      if (!mounted) return;
      ToastHelper.showSuccess(context, tr('manager_removed'));
    } else {
      if (!mounted) return;
      ToastHelper.showError(
        context,
        result['message'] ?? tr('failed_to_remove_manager'),
      );
    }
  }

  Future<void> _deleteStorage(String storageId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('delete_storage')),
        content: Text(tr('confirm_delete_storage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              tr('delete'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await _coldStorageService.deleteColdStorage(storageId);

      if (result['success']) {
        _loadMyStorages();
        if (!mounted) return;
        ToastHelper.showDeleted(context, tr('cold_storage'));
      } else {
        if (!mounted) return;
        ToastHelper.showError(context, result['message'] ?? tr('failed_to_delete'));
      }
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
          tr('manage_my_storage'),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMyStorages,
          ),
        ],
      ),
      floatingActionButton: _myStorages.length >= 1
          ? null // Hide FAB when limit reached
          : FloatingActionButton.extended(
              onPressed: () => _navigateToAddEdit(null),
              backgroundColor: AppColors.primaryGreen,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                '${tr('add_storage')} (${_myStorages.length}/1)',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : _myStorages.isEmpty
          ? _buildEmptyState()
          : _buildStorageList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.ac_unit, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 24),
          Text(
            tr('no_storage_added'),
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr('storage_limit_msg'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          Text(
            tr('storage_limit_msg'),
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navigateToAddEdit(null),
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text(
              '${tr('add_storage')} (0/1)',
              style: const TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageList() {
    // Calculate summary stats
    int totalCapacity = 0;
    int totalAvailable = 0;
    int activeListings = 0;

    for (var storage in _myStorages) {
      totalCapacity += (storage['capacity'] ?? 0) as int;
      totalAvailable += (storage['availableCapacity'] ?? 0) as int;
      if (storage['isAvailable'] == true) activeListings++;
    }

    return RefreshIndicator(
      onRefresh: _loadMyStorages,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryGreen,
                  AppColors.primaryGreen.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGreen.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tr('summary'),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_myStorages.length}/1',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _summaryItem(
                        '${_myStorages.length}',
                        tr('total_listings'),
                        Icons.list_alt,
                      ),
                    ),
                    Expanded(
                      child: _summaryItem(
                        '$activeListings',
                        tr('active_listings'),
                        Icons.check_circle,
                      ),
                    ),
                    Expanded(
                      child: _summaryItem(
                        '$totalCapacity ${tr('packets')}',
                        tr('total_capacity'),
                        Icons.inventory_2,
                      ),
                    ),
                    Expanded(
                      child: _summaryItem(
                        '$totalAvailable ${tr('packets')}',
                        tr('available_space'),
                        Icons.storage,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Limit reached info banner
          if (_myStorages.length >= 1)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.green.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('storage_limit_reached'),
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (_myStorages.length >= 1) const SizedBox(height: 16),

          Text(
            tr('my_cold_storages'),
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 12),

          // Storage List
          ..._myStorages.map((storage) => _buildStorageCard(storage)),

          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _summaryItem(String value, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 22),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.2),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageCard(Map<String, dynamic> storage) {
    final isAvailable = storage['isAvailable'] ?? false;
    final availableCapacity = storage['availableCapacity'] ?? 0;
    final totalCapacity = storage['capacity'] ?? 0;
    final pricePerTon = storage['pricePerTon'] ?? 0;
    final percentUsed = totalCapacity > 0
        ? ((totalCapacity - availableCapacity) / totalCapacity * 100).toInt()
        : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storage['name'] ?? tr('cold_storage'),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Colors.white70,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${storage['city']}, ${storage['state']}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Availability Toggle
                Column(
                  children: [
                    Switch(
                      value: isAvailable,
                      onChanged: (value) =>
                          _toggleAvailability(storage['_id'], isAvailable),
                      activeThumbColor: Colors.white,
                      activeTrackColor: Colors.green[300],
                    ),
                    Text(
                      isAvailable ? tr('available') : tr('unavailable'),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Stats
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Capacity Row
                Row(
                  children: [
                    Expanded(
                      child: _statItem(
                        icon: Icons.inventory_2,
                        label: tr('total_capacity'),
                        value: '$totalCapacity ${tr('packets')}',
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _statItem(
                        icon: Icons.check_circle,
                        label: tr('available'),
                        value: '$availableCapacity ${tr('packets')}',
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _statItem(
                        icon: Icons.currency_rupee,
                        label: tr('price_per_packet'),
                        value: '₹$pricePerTon',
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Progress Bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tr('capacity_usage'),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '$percentUsed%',
                          style: TextStyle(
                            color: percentUsed > 80 ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: percentUsed / 100,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          percentUsed > 80 ? Colors.red : Colors.green,
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Contact Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.phone,
                        color: AppColors.primaryGreen,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(storage['phone'] ?? tr('no_data')),
                      const Spacer(),
                      const Icon(
                        Icons.email,
                        color: AppColors.primaryGreen,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          storage['email'] ?? tr('no_data'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Manager Section ─────────────────────────────
                _buildManagerSection(storage),

                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _navigateToAddEdit(storage),
                        icon: const Icon(Icons.edit, size: 18),
                        label: Text(tr('edit')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryGreen,
                          side: const BorderSide(color: AppColors.primaryGreen),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _deleteStorage(storage['_id']),
                        icon: const Icon(Icons.delete, size: 18),
                        label: Text(tr('delete')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
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

  // ── Manager Section Widget ────────────────────────────────────────
  Widget _buildManagerSection(Map<String, dynamic> storage) {
    final manager = storage['manager'];
    final managerPhone = storage['managerPhone'];
    final hasManager = manager != null && manager is Map;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasManager
            ? Colors.blue.withOpacity(0.06)
            : Colors.grey.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasManager
              ? Colors.blue.withOpacity(0.2)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.admin_panel_settings,
                color: hasManager ? Colors.blue : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                tr('manager'),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: hasManager ? Colors.blue[800] : Colors.grey[700],
                ),
              ),
              const Spacer(),
              if (!hasManager)
                SizedBox(
                  height: 30,
                  child: ElevatedButton.icon(
                    onPressed: () => _assignManager(storage['_id']),
                    icon: const Icon(Icons.person_add, size: 14),
                    label: Text(
                      tr('assign'),
                      style: const TextStyle(fontSize: 11),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (hasManager) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.blue.withOpacity(0.15),
                  child: Text(
                    (manager['firstName'] ?? 'M')[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${manager['firstName'] ?? ''} ${manager['lastName'] ?? ''}'
                            .trim(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        managerPhone ?? manager['phone'] ?? '',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _removeManager(storage['_id']),
                  icon: const Icon(
                    Icons.person_remove,
                    color: Colors.red,
                    size: 20,
                  ),
                  tooltip: tr('remove_manager'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                tr('no_manager_assigned'),
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 14,
          ),
        ),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
      ],
    );
  }

  void _navigateToAddEdit(Map<String, dynamic>? storage) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditStorageScreen(storage: storage),
      ),
    ).then((_) => _loadMyStorages());
  }
}

// Add/Edit Storage Screen
class AddEditStorageScreen extends StatefulWidget {
  final Map<String, dynamic>? storage;

  const AddEditStorageScreen({super.key, this.storage});

  @override
  State<AddEditStorageScreen> createState() => _AddEditStorageScreenState();
}

class _AddEditStorageScreenState extends State<AddEditStorageScreen> {
  final _formKey = GlobalKey<FormState>();
  final ColdStorageService _coldStorageService = ColdStorageService();
  final ImagePicker _imagePicker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _pincodeController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _capacityController;
  late TextEditingController _availableCapacityController;
  late TextEditingController _priceController;

  String? _selectedState;
  String? _selectedCity;
  String? _selectedVillage;
  List<String> _availableCities = [];
  List<String> _availableVillages = [];
  bool _isAvailable = true;

  // Photo handling — two photos (first mandatory, second optional)
  XFile? _selectedImage1;
  XFile? _selectedImage2;
  String? _existingImageUrl1;
  String? _existingImageUrl2;
  bool _isLoading = false;

  // GPS location captured from photo
  double? _capturedLatitude;
  double? _capturedLongitude;
  String? _capturedAddress;
  bool _isCapturingGPS = false;
  final GoogleGeocodingService _geocodingService = GoogleGeocodingService();

  bool get isEditing => widget.storage != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.storage?['name'] ?? '',
    );
    _addressController = TextEditingController(
      text: widget.storage?['address'] ?? '',
    );
    _pincodeController = TextEditingController(
      text: widget.storage?['pincode'] ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.storage?['phone'] ?? '',
    );
    _emailController = TextEditingController(
      text: widget.storage?['email'] ?? '',
    );
    _capacityController = TextEditingController(
      text: (widget.storage?['capacity'] ?? '').toString(),
    );
    _availableCapacityController = TextEditingController(
      text: (widget.storage?['availableCapacity'] ?? '').toString(),
    );
    _priceController = TextEditingController(
      text: (widget.storage?['pricePerTon'] ?? '').toString(),
    );

    if (widget.storage != null) {
      _selectedState = widget.storage!['state'];
      _selectedCity = widget.storage!['city'];
      _selectedVillage = widget.storage!['village'];
      _isAvailable = widget.storage!['isAvailable'] ?? true;
      // Load existing images from images array
      final images = widget.storage!['images'] as List<dynamic>? ?? [];
      if (images.isNotEmpty) _existingImageUrl1 = images[0] as String?;
      if (images.length > 1) _existingImageUrl2 = images[1] as String?;
      // Fallback to legacy imageUrl field
      if (_existingImageUrl1 == null || _existingImageUrl1!.isEmpty) {
        _existingImageUrl1 = widget.storage!['imageUrl'];
      }
      // Load existing captureLocation if editing
      final capLoc = widget.storage!['captureLocation'];
      if (capLoc != null) {
        _capturedLatitude = (capLoc['latitude'] as num?)?.toDouble();
        _capturedLongitude = (capLoc['longitude'] as num?)?.toDouble();
        _capturedAddress = capLoc['address'] as String?;
      }
      if (_selectedState != null) {
        _availableCities = StateCityData.getCitiesForState(_selectedState!);
      }
      if (_selectedCity != null) {
        _availableVillages = StateCityData.getVillagesForDistrict(
          _selectedCity!,
        );
      }
    }
  }

  Future<void> _pickImage({int slot = 1}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          if (slot == 1) {
            _selectedImage1 = image;
          } else {
            _selectedImage2 = image;
          }
        });
        // Capture GPS only for the first photo
        if (slot == 1) _captureGPSLocation();
      }
    } catch (e) {
      ToastHelper.showError(context, tr('failed_to_pick_image'));
    }
  }

  Future<void> _captureImage({int slot = 1}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          if (slot == 1) {
            _selectedImage1 = image;
          } else {
            _selectedImage2 = image;
          }
        });
        // Capture GPS only for the first photo
        if (slot == 1) _captureGPSLocation();
      }
    } catch (e) {
      ToastHelper.showError(context, tr('failed_to_capture_image'));
    }
  }

  /// Capture live GPS location and reverse geocode it
  Future<void> _captureGPSLocation() async {
    setState(() => _isCapturingGPS = true);

    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ToastHelper.showError(context, tr('location_permission_denied'));
          }
          setState(() => _isCapturingGPS = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ToastHelper.showError(
            context,
            tr('location_permission_permanently_denied'),
          );
        }
        setState(() => _isCapturingGPS = false);
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 15));

      final lat = position.latitude;
      final lng = position.longitude;

      // Reverse geocode using Google API
      String? address;
      try {
        final geoResult = await _geocodingService.reverseGeocode(
          latitude: lat,
          longitude: lng,
        );
        if (geoResult != null) {
          address = geoResult['address'] as String? ??
              geoResult['formattedAddress'] as String?;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _capturedLatitude = lat;
          _capturedLongitude = lng;
          _capturedAddress = address ?? 'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}';
          _isCapturingGPS = false;
        });
        if (!mounted) return;
        ToastHelper.showSuccess(context, tr('gps_location_captured'));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCapturingGPS = false);
        ToastHelper.showError(context, tr('could_not_get_gps_location'));
      }
    }
  }

  bool _isFetchingLocation = false;

  /// Fetch location details from pincode using India Post API
  Future<void> _fetchLocationFromPincode(String pincode) async {
    if (pincode.length != 6) return;

    setState(() => _isFetchingLocation = true);

    try {
      final response = await http.get(
        Uri.parse('https://api.postalpincode.in/pincode/$pincode'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        if (data.isNotEmpty && data[0]['Status'] == 'Success') {
          final List<dynamic> postOffices = data[0]['PostOffice'] ?? [];

          if (postOffices.isNotEmpty) {
            final postOffice = postOffices[0];
            final String fetchedState = postOffice['State'] ?? '';
            final String fetchedDistrict = postOffice['District'] ?? '';
            final String fetchedArea = postOffice['Name'] ?? '';

            setState(() {
              // Set state if it exists in our data
              if (StateCityData.states.contains(fetchedState)) {
                _selectedState = fetchedState;
                _availableCities = StateCityData.getCitiesForState(
                  fetchedState,
                );

                // Set district if it exists in our data
                if (_availableCities.contains(fetchedDistrict)) {
                  _selectedCity = fetchedDistrict;
                  _availableVillages = StateCityData.getVillagesForDistrict(
                    fetchedDistrict,
                  );

                  // Set village/area if it exists
                  if (_availableVillages.contains(fetchedArea)) {
                    _selectedVillage = fetchedArea;
                  } else if (_availableVillages.contains(
                    '$fetchedDistrict City',
                  )) {
                    // Check for city variant
                    _selectedVillage = '$fetchedDistrict City';
                  }
                }
              }
            });

            ToastHelper.showSuccess(
              context,
              tr('location_autofilled_from_pincode'),
            );
          }
        } else {
          ToastHelper.showError(
            context,
            tr('invalid_pincode_or_not_found'),
          );
        }
      }
    } catch (e) {
      print('Pincode lookup error: $e');
      // Silent fail - user can still manually select
    } finally {
      setState(() => _isFetchingLocation = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _capacityController.dispose();
    _availableCapacityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _saveStorage() async {
    if (!_formKey.currentState!.validate()) return;

    // Frontend guard: prevent creating more than 1 cold storage
    if (!isEditing) {
      final myResult = await _coldStorageService.getMyColdStorages();
      if (myResult['success'] == true) {
        final existingStorages = myResult['data']?['coldStorages'] ?? [];
        if (existingStorages.length >= 1) {
          ToastHelper.showError(context, tr('one_storage_limit_msg'));
          Navigator.pop(context);
          return;
        }
      }
    }

    // Validate first photo is mandatory
    if (_selectedImage1 == null &&
        (_existingImageUrl1 == null || _existingImageUrl1!.isEmpty)) {
      ToastHelper.showError(context, tr('at_least_one_photo_msg'));
      return;
    }

    setState(() => _isLoading = true);

    // Convert captured images to base64
    final List<String> imageList = [];
    if (_selectedImage1 != null) {
      final bytes1 = await _selectedImage1!.readAsBytes();
      final ext1 = _selectedImage1!.path.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
      imageList.add('data:image/$ext1;base64,${base64Encode(bytes1)}');
    } else if (_existingImageUrl1 != null && _existingImageUrl1!.isNotEmpty) {
      imageList.add(_existingImageUrl1!);
    }
    if (_selectedImage2 != null) {
      final bytes2 = await _selectedImage2!.readAsBytes();
      final ext2 = _selectedImage2!.path.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
      imageList.add('data:image/$ext2;base64,${base64Encode(bytes2)}');
    } else if (_existingImageUrl2 != null && _existingImageUrl2!.isNotEmpty) {
      imageList.add(_existingImageUrl2!);
    }

    Map<String, dynamic> result;

    if (isEditing) {
      // Build captureLocation for update
      Map<String, dynamic>? captureLocationData;
      if (_capturedLatitude != null && _capturedLongitude != null) {
        captureLocationData = {
          'address': _capturedAddress ?? '',
          'latitude': _capturedLatitude,
          'longitude': _capturedLongitude,
        };
      }
      result = await _coldStorageService.updateColdStorage(
        id: widget.storage!['_id'],
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        city: _selectedCity,
        state: _selectedState,
        village: _selectedVillage,
        pincode: _pincodeController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        capacity: int.tryParse(_capacityController.text),
        availableCapacity: int.tryParse(_availableCapacityController.text),
        pricePerTon: double.tryParse(_priceController.text),
        isAvailable: _isAvailable,
        captureLocation: captureLocationData,
        images: imageList.isNotEmpty ? imageList : null,
      );
    } else {
      // Build captureLocation for create
      Map<String, dynamic>? captureLocationData;
      if (_capturedLatitude != null && _capturedLongitude != null) {
        captureLocationData = {
          'address': _capturedAddress ?? '',
          'latitude': _capturedLatitude,
          'longitude': _capturedLongitude,
        };
      }
      result = await _coldStorageService.createColdStorage(
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        city: _selectedCity!,
        state: _selectedState!,
        village: _selectedVillage,
        pincode: _pincodeController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        capacity: int.tryParse(_capacityController.text) ?? 0,
        pricePerTon: double.tryParse(_priceController.text) ?? 0,
        captureLocation: captureLocationData,
        images: imageList.isNotEmpty ? imageList : null,
      );
    }

    setState(() => _isLoading = false);

    if (result['success']) {
      if (isEditing) {
        if (!mounted) return;
        ToastHelper.showUpdated(context, tr('cold_storage'));
      } else {
        if (!mounted) return;
        ToastHelper.showCreated(context, tr('cold_storage'));
      }
      Navigator.pop(context);
    } else {
      if (!mounted) return;
      ToastHelper.showError(context, result['message'] ?? tr('failed_to_save'));
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
          isEditing ? tr('edit_storage') : tr('add_new_storage'),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Section
              _sectionTitle(tr('storage_photo')),
              _buildPhotoSection(),

              // GPS Location Map Preview
              if (_isCapturingGPS)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tr('capturing_gps'),
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              if (_capturedLatitude != null && _capturedLongitude != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: LocationMapWidget(
                    latitude: _capturedLatitude!,
                    longitude: _capturedLongitude!,
                    address: _capturedAddress,
                    height: 160,
                    compact: true,
                  ),
                ),
              const SizedBox(height: 16),

              // Basic Info Section
              _sectionTitle(tr('basic_info')),
              _buildTextField(
                controller: _nameController,
                label: tr('storage_name'),
                hint: tr('enter_storage_name_hint'),
                icon: Icons.ac_unit,
                validator: (v) => v!.isEmpty ? tr('name_is_required') : null,
              ),
              const SizedBox(height: 16),

              // Address Section
              _sectionTitle(tr('address_details')),
              _buildTextField(
                controller: _addressController,
                label: tr('address'),
                hint: tr('enter_address_hint'),
                icon: Icons.location_on,
                maxLines: 2,
                validator: (v) => v!.isEmpty ? tr('address_is_required') : null,
              ),
              const SizedBox(height: 12),

              // Pincode with auto-fetch location (FIRST - to auto-fill State/District/Village)
              _buildTextField(
                controller: _pincodeController,
                label: tr('pincode'),
                hint: tr('pincode_hint'),
                icon: Icons.pin_drop,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) {
                  if (value.length == 6) {
                    _fetchLocationFromPincode(value);
                  }
                },
                suffix: _isFetchingLocation
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(
                          Icons.search,
                          color: AppColors.primaryGreen,
                        ),
                        onPressed: () {
                          if (_pincodeController.text.length == 6) {
                            _fetchLocationFromPincode(_pincodeController.text);
                          }
                        },
                      ),
                validator: (v) {
                  if (v!.isEmpty) return tr('pincode_is_required');
                  if (v.length != 6) return tr('invalid_pincode_error');
                  return null;
                },
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      label: tr('state_label'),
                      value: _selectedState,
                      items: StateCityData.states,
                      onChanged: (v) {
                        setState(() {
                          _selectedState = v;
                          _selectedCity = null;
                          _selectedVillage = null;
                          _availableCities = v != null
                              ? StateCityData.getCitiesForState(v)
                              : [];
                          _availableVillages = [];
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown(
                      label: tr('district'),
                      value: _selectedCity,
                      items: _availableCities,
                      onChanged: (v) {
                        setState(() {
                          _selectedCity = v;
                          _selectedVillage = null;
                          _availableVillages = v != null
                              ? StateCityData.getVillagesForDistrict(v)
                              : [];
                        });
                      },
                      enabled: _selectedState != null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Village/Town dropdown
              _buildDropdown(
                label: tr('village_town'),
                value: _selectedVillage,
                items: _availableVillages,
                onChanged: (v) => setState(() => _selectedVillage = v),
                enabled: _selectedCity != null && _availableVillages.isNotEmpty,
              ),
              const SizedBox(height: 16),

              // Contact Section
              _sectionTitle(tr('contact_info')),
              _buildTextField(
                controller: _phoneController,
                label: tr('phone_number'),
                hint: tr('enter_phone_hint'),
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v!.isEmpty) return tr('phone_is_required');
                  if (v.length != 10) return tr('invalid_phone_error');
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _emailController,
                label: tr('email_optional'),
                hint: 'email@example.com',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Capacity Section
              _sectionTitle(tr('capacity')),
              _buildTextField(
                controller: _capacityController,
                label: tr('total_capacity_packets'),
                hint: tr('enter_capacity_hint'),
                icon: Icons.inventory_2,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => v!.isEmpty ? tr('capacity_is_required') : null,
              ),
              const SizedBox(height: 16),

              // Pricing Section
              _sectionTitle(tr('pricing')),
              _buildTextField(
                controller: _priceController,
                label: tr('price_per_packet_inr'),
                hint: tr('enter_price_hint'),
                icon: Icons.currency_rupee,
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? tr('price_is_required') : null,
              ),
              const SizedBox(height: 16),

              // Availability Toggle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBg(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isAvailable ? Icons.check_circle : Icons.cancel,
                          color: _isAvailable ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('storage_availability'),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              _isAvailable
                                  ? tr('visible_to_farmers')
                                  : tr('hidden_from_farmers'),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: _isAvailable,
                      onChanged: (v) => setState(() => _isAvailable = v),
                      activeThumbColor: AppColors.primaryGreen,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveStorage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          isEditing ? tr('update_storage') : tr('add_storage'),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryGreen,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    Function(String)? onChanged,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primaryGreen),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.inputFill(context),
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
          borderSide: const BorderSide(color: AppColors.primaryGreen),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    bool enabled = true,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[200],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      isExpanded: true,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: enabled ? onChanged : null,
      validator: (v) => v == null ? '${tr('please_select')} $label' : null,
    );
  }

  Widget _buildPhotoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Two photo slots side by side
          Row(
            children: [
              // Photo 1 (Mandatory)
              Expanded(
                child: _buildPhotoSlot(
                  slot: 1,
                  selectedImage: _selectedImage1,
                  existingUrl: _existingImageUrl1,
                  label: tr('photo_1_mandatory'),
                  isMandatory: true,
                ),
              ),
              const SizedBox(width: 12),
              // Photo 2 (Optional)
              Expanded(
                child: _buildPhotoSlot(
                  slot: 2,
                  selectedImage: _selectedImage2,
                  existingUrl: _existingImageUrl2,
                  label: tr('photo_2_optional'),
                  isMandatory: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tr('photo_mandatory_note'),
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSlot({
    required int slot,
    required XFile? selectedImage,
    required String? existingUrl,
    required String label,
    required bool isMandatory,
  }) {
    final hasImage = selectedImage != null ||
        (existingUrl != null && existingUrl.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isMandatory ? AppColors.primaryGreen : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _showImagePickerOptions(slot: slot),
          child: Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMandatory && !hasImage
                    ? Colors.red.shade300
                    : Colors.grey[300]!,
              ),
            ),
            child: selectedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: kIsWeb
                        ? Image.network(
                            selectedImage.path,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 140,
                          )
                        : Image.file(
                            File(selectedImage.path),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 140,
                          ),
                  )
                : existingUrl != null && existingUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          existingUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 140,
                          errorBuilder: (_, __, ___) =>
                              _buildPlaceholder(isMandatory: isMandatory),
                        ),
                      )
                    : _buildPlaceholder(isMandatory: isMandatory),
          ),
        ),
        if (hasImage) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () {
              setState(() {
                if (slot == 1) {
                  _selectedImage1 = null;
                  _existingImageUrl1 = null;
                } else {
                  _selectedImage2 = null;
                  _existingImageUrl2 = null;
                }
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete, size: 14, color: Colors.red[400]),
                const SizedBox(width: 4),
                Text(
                  tr('remove'),
                  style: TextStyle(color: Colors.red[400], fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlaceholder({bool isMandatory = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo, size: 32, color: Colors.grey[400]),
        const SizedBox(height: 4),
        Text(
          tr('tap_to_add'),
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }

  void _showImagePickerOptions({int slot = 1}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${tr('select_photo')} ${slot == 1 ? tr('required_label') : tr('optional_label')}',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.photo_library,
                    color: AppColors.primaryGreen,
                  ),
                ),
                title: Text(tr('choose_from_gallery')),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(slot: slot);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: AppColors.primaryGreen,
                  ),
                ),
                title: Text(tr('take_a_photo')),
                onTap: () {
                  Navigator.pop(context);
                  _captureImage(slot: slot);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
