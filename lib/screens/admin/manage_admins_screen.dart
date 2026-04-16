import 'package:aloo_sbji_mandi/core/service/admin_management_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';

class ManageAdminsScreen extends StatefulWidget {
  const ManageAdminsScreen({super.key});

  @override
  State<ManageAdminsScreen> createState() => _ManageAdminsScreenState();
}

class _ManageAdminsScreenState extends State<ManageAdminsScreen> {
  final AdminManagementService _adminService = AdminManagementService();
  List<Map<String, dynamic>> _admins = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  Future<void> _loadAdmins() async {
    setState(() => _isLoading = true);
    final result = await _adminService.getAllAdmins();
    if (result['success']) {
      setState(() {
        _admins = List<Map<String, dynamic>>.from(result['data'] ?? []);
      });
    } else {
      _showToast(
        result['message'] ?? tr('failed_to_load_admins'),
        isError: true,
      );
    }
    setState(() => _isLoading = false);
  }

  void _showToast(String message, {bool isError = false}) {
    Fluttertoast.showToast(
      msg: message,
      backgroundColor: isError ? Colors.red : Colors.green,
      textColor: Colors.white,
    );
  }

  Future<void> _showCreateAdminDialog() async {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    final emailController = TextEditingController();
    bool isCreating = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person_add,
                  color: Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                tr('create_new_admin'),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(
                  firstNameController,
                  tr('first_name'),
                  Icons.person,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  lastNameController,
                  tr('last_name'),
                  Icons.person_outline,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  phoneController,
                  tr('phone_number'),
                  Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  emailController,
                  tr('email_optional'),
                  Icons.email,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  passwordController,
                  tr('password'),
                  Icons.lock,
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isCreating ? null : () => Navigator.pop(context),
              child: Text(
                tr('cancel'),
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: isCreating
                  ? null
                  : () async {
                      if (firstNameController.text.isEmpty ||
                          lastNameController.text.isEmpty ||
                          phoneController.text.isEmpty ||
                          passwordController.text.isEmpty) {
                        _showToast(
                          tr('fill_all_required_fields'),
                          isError: true,
                        );
                        return;
                      }
                      if (passwordController.text.length < 6) {
                        _showToast(tr('password_min_6_chars'), isError: true);
                        return;
                      }

                      setDialogState(() => isCreating = true);
                      final result = await _adminService.createAdmin(
                        firstName: firstNameController.text.trim(),
                        lastName: lastNameController.text.trim(),
                        phone: phoneController.text.trim(),
                        password: passwordController.text,
                        email: emailController.text.trim().isNotEmpty
                            ? emailController.text.trim()
                            : null,
                      );

                      if (result['success']) {
                        _showToast(
                          result['message'] ?? tr('admin_created_success'),
                        );
                        if (context.mounted) Navigator.pop(context);
                        _loadAdmins();
                      } else {
                        _showToast(
                          result['message'] ?? tr('failed_to_create_admin'),
                          isError: true,
                        );
                        setDialogState(() => isCreating = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isCreating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      tr('create_admin_button'),
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditAdminDialog(Map<String, dynamic> admin) async {
    final firstNameController = TextEditingController(
      text: admin['firstName'] ?? '',
    );
    final lastNameController = TextEditingController(
      text: admin['lastName'] ?? '',
    );
    final phoneController = TextEditingController(text: admin['phone'] ?? '');
    final emailController = TextEditingController(text: admin['email'] ?? '');
    final passwordController = TextEditingController();
    bool isUpdating = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit, color: Colors.blue, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr('edit_admin'),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(
                  firstNameController,
                  tr('first_name'),
                  Icons.person,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  lastNameController,
                  tr('last_name'),
                  Icons.person_outline,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  phoneController,
                  tr('phone_number'),
                  Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  emailController,
                  tr('email_optional'),
                  Icons.email,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  passwordController,
                  tr('new_password_optional'),
                  Icons.lock,
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUpdating ? null : () => Navigator.pop(context),
              child: Text(
                tr('cancel'),
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: isUpdating
                  ? null
                  : () async {
                      setDialogState(() => isUpdating = true);
                      final result = await _adminService.updateAdmin(
                        adminId: admin['_id'],
                        firstName: firstNameController.text.trim(),
                        lastName: lastNameController.text.trim(),
                        phone: phoneController.text.trim(),
                        email: emailController.text.trim().isNotEmpty
                            ? emailController.text.trim()
                            : null,
                        password: passwordController.text.isNotEmpty
                            ? passwordController.text
                            : null,
                      );

                      if (result['success']) {
                        _showToast(tr('admin_updated_success'));
                        if (context.mounted) Navigator.pop(context);
                        _loadAdmins();
                      } else {
                        _showToast(
                          result['message'] ?? tr('failed_to_update_admin'),
                          isError: true,
                        );
                        setDialogState(() => isUpdating = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isUpdating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(tr('update'), style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAdmin(Map<String, dynamic> admin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(
              tr('delete_admin'),
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          tr('are_you_sure_delete_admin') +
              '"${admin['firstName']} ${admin['lastName']}"' +
              tr('this_action_cannot_be_undone'),
          style: GoogleFonts.inter(fontSize: 15),
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
            child: Text(tr('delete'), style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await _adminService.deleteAdmin(admin['_id']);
      if (result['success']) {
        _showToast(tr('admin_deleted_success'));
        _loadAdmins();
      } else {
        _showToast(
          result['message'] ?? tr('failed_to_delete_admin'),
          isError: true,
        );
      }
    }
  }

  Future<void> _confirmDemoteAdmin(Map<String, dynamic> admin) async {
    String selectedRole = 'farmer';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.arrow_downward, color: Colors.orange, size: 28),
              const SizedBox(width: 8),
              Text(
                tr('demote_admin'),
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('demote_prefix') +
                    '${admin['firstName']} ${admin['lastName']}' +
                    tr('demote_suffix'),
                style: GoogleFonts.inter(fontSize: 15),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'farmer',
                    child: Text(tr('role_farmer')),
                  ),
                  DropdownMenuItem(
                    value: 'trader',
                    child: Text(tr('role_trader')),
                  ),
                  DropdownMenuItem(
                    value: 'cold-storage',
                    child: Text(tr('role_cold_storage')),
                  ),
                  DropdownMenuItem(
                    value: 'aloo-mitra',
                    child: Text(tr('role_aloo_mitra')),
                  ),
                ],
                onChanged: (value) {
                  setDialogState(() => selectedRole = value ?? 'farmer');
                },
              ),
            ],
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
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(tr('demote'), style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final result = await _adminService.demoteAdmin(
        admin['_id'],
        newRole: selectedRole,
      );
      if (result['success']) {
        _showToast(result['message'] ?? tr('admin_demoted_success'));
        _loadAdmins();
      } else {
        _showToast(
          result['message'] ?? tr('failed_to_demote_admin'),
          isError: true,
        );
      }
    }
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        title: Text(
          tr('manage_admins'),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAdmins,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateAdminDialog,
        backgroundColor: const Color(0xFF1E3A5F),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: Text(
          tr('add_admin_action'),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _admins.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr('no_admins_found'),
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('tap_plus_create_admin'),
                    style: GoogleFonts.inter(color: Colors.grey[400]),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAdmins,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _admins.length,
                itemBuilder: (context, index) {
                  final admin = _admins[index];
                  return _AdminCard(
                    admin: admin,
                    onEdit: () => _showEditAdminDialog(admin),
                    onDelete: () => _confirmDeleteAdmin(admin),
                    onDemote: () => _confirmDemoteAdmin(admin),
                  );
                },
              ),
            ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final Map<String, dynamic> admin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDemote;

  const _AdminCard({
    required this.admin,
    required this.onEdit,
    required this.onDelete,
    required this.onDemote,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMaster =
        admin['isMaster'] == true || admin['role'] == 'master';
    final String name = '${admin['firstName'] ?? ''} ${admin['lastName'] ?? ''}'
        .trim();
    final String phone = admin['phone'] ?? 'N/A';
    final String email = admin['email'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isMaster
            ? Border.all(color: Colors.amber.shade600, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isMaster
                      ? Colors.amber.shade100
                      : const Color(0xFF1E3A5F).withOpacity(0.1),
                  child: Icon(
                    isMaster ? Icons.shield : Icons.admin_panel_settings,
                    color: isMaster
                        ? Colors.amber.shade800
                        : const Color(0xFF1E3A5F),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                // Name & Role
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isMaster
                                  ? Colors.amber.shade100
                                  : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isMaster ? tr('master_badge') : tr('admin_badge'),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isMaster
                                    ? Colors.amber.shade900
                                    : Colors.blue.shade900,
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
                          Text(
                            phone,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.email,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                email,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                                overflow: TextOverflow.ellipsis,
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
            // Action buttons - only for non-master admins
            if (!isMaster) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ActionButton(
                    icon: Icons.edit,
                    label: tr('edit'),
                    color: Colors.blue,
                    onTap: onEdit,
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    icon: Icons.arrow_downward,
                    label: tr('demote'),
                    color: Colors.orange,
                    onTap: onDemote,
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    icon: Icons.delete,
                    label: tr('delete'),
                    color: Colors.red,
                    onTap: onDelete,
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, size: 14, color: Colors.amber.shade800),
                    const SizedBox(width: 6),
                    Text(
                      tr('protected_admin_msg'),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.amber.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
