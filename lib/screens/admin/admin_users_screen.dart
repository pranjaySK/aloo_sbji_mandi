import 'package:aloo_sbji_mandi/core/service/advertisement_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final AdvertisementService _adService = AdvertisementService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  String? _selectedRole;

  final List<Map<String, String>> _roleFilters = [
    {'value': '', 'label': tr('all_users')},
    {'value': 'farmer', 'label': tr('farmers')},
    {'value': 'trader', 'label': tr('traders')},
    {'value': 'cold-storage', 'label': tr('cold_storage')},
    {'value': 'aloo-mitra', 'label': tr('aloo_mitra')},
    {'value': 'admin', 'label': tr('admins')},
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    final result = await _adService.getAllUsers(
      role: _selectedRole?.isNotEmpty == true ? _selectedRole : null,
    );

    if (result['success']) {
      _users = List<Map<String, dynamic>>.from(result['data']['users'] ?? []);
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          tr('manage_users'),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUsers),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _roleFilters.map((filter) {
                  final isSelected =
                      _selectedRole == filter['value'] ||
                      (_selectedRole == null && filter['value']!.isEmpty);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter['label']!),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedRole = filter['value']!.isEmpty
                              ? null
                              : filter['value'];
                        });
                        _loadUsers();
                      },
                      backgroundColor: Colors.grey[200],
                      selectedColor: const Color(0xFF1E3A5F).withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? const Color(0xFF1E3A5F)
                            : Colors.grey[700],
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Users List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          tr('no_users_found'),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadUsers,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        return _UserCard(user: user);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;

  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final role = user['role'] ?? tr('unknown');
    final roleColor = _getRoleColor(role);
    final address = user['address'] ?? {};

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 28,
            backgroundColor: roleColor.withOpacity(0.1),
            child: Icon(_getRoleIcon(role), color: roleColor, size: 28),
          ),
          const SizedBox(width: 16),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
                            .trim(),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _formatRoleName(role),
                        style: TextStyle(
                          color: roleColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (user['phone'] != null)
                  Row(
                    children: [
                      Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          user['phone'],
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                if (user['email'] != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.email, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          user['email'],
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (address['village'] != null ||
                    address['district'] != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${address['village'] ?? ''}, ${address['district'] ?? ''}, ${address['state'] ?? ''}'
                              .replaceAll(', , ', ', '),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'farmer':
        return Icons.agriculture;
      case 'trader':
        return Icons.store;
      case 'cold-storage':
        return Icons.ac_unit;
      case 'aloo-mitra':
        return Icons.handshake;
      case 'admin':
        return Icons.admin_panel_settings;
      case 'master':
        return Icons.shield;
      default:
        return Icons.person;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'farmer':
        return AppColors.primaryGreen;
      case 'trader':
        return Colors.blue;
      case 'cold-storage':
        return Colors.cyan;
      case 'aloo-mitra':
        return Colors.purple;
      case 'admin':
        return Colors.red;
      case 'master':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String _formatRoleName(String role) {
    switch (role) {
      case 'farmer':
        return tr('farmer');
      case 'trader':
        return tr('trader');
      case 'cold-storage':
        return tr('cold_storage');
      case 'aloo-mitra':
        return tr('aloo_mitra');
      case 'admin':
        return tr('admin');
      case 'master':
        return tr('master');
      default:
        return role;
    }
  }
}
