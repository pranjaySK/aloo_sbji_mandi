import 'package:aloo_sbji_mandi/core/service/auth_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RoleScreen extends StatefulWidget {
  const RoleScreen({super.key});

  @override
  State<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends State<RoleScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _selectedRole;

  Future<void> _selectRole(String role, String routeName) async {
    setState(() {
      _isLoading = true;
      _selectedRole = role;
    });

    final result = await _authService.updateUserRole(role: role);

    setState(() => _isLoading = false);

    if (result['success']) {
      if (mounted) {
        // Navigate to language selection with destination route
        Navigator.pushReplacementNamed(
          context,
          '/language',
          arguments: {'destinationRoute': routeName},
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? tr('failed_update_role')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget roleTile(String titleKey, String image, String role, String routeName) {
    final title = tr(titleKey);
    final isSelected = _selectedRole == role;
    
    return GestureDetector(
      onTap: _isLoading ? null : () => _selectRole(role, routeName),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardBg(context),
          border: Border.all(color: isSelected ? AppColors.primaryGreen : AppColors.border, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
          ],
        ),
        child: Row(
          children: [
            Image.asset(image, height: 40, width: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_isLoading && isSelected)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }

  /// Aloo Mitra tile that navigates to registration screen
  Widget _alooMitraTile() {
    final title = tr('aloo_mitra');
    final isSelected = _selectedRole == 'aloo-mitra';
    
    return GestureDetector(
      onTap: _isLoading ? null : () {
        // Navigate to Aloo Mitra registration screen
        Navigator.pushNamed(context, '/aloo_mitra_registration');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardBg(context),
          border: Border.all(color: isSelected ? AppColors.primaryGreen : AppColors.border, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.handshake,
                color: AppColors.primaryGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    tr('service_provider_bracket'),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Image.asset("assets/background_green.png"),
          //  greenBackground(),

          // whiteCurveLayer(),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),

                /// Logo
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.all(10),

                  child: Image.asset('assets/logo.png', height: 70),
                ),

                const SizedBox(height: 16),

                Text(
                  tr('what_defines_role'),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 60),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          roleTile("farmer", "assets/farmer.png", "farmer", "/kishan_navbar"),
                          roleTile("trader", "assets/businessman.png", "trader", "/vyapari_navbar"),
                          roleTile("cold_storage", "assets/cloud_storage.png", "cold-storage", "/cold_storage_navbar"),
                          _alooMitraTile(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
