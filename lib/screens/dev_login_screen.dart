import 'dart:convert';

import 'package:aloo_sbji_mandi/core/service/aloo_mitra_service.dart';
import 'package:aloo_sbji_mandi/core/service/auth_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DevLoginScreen extends StatefulWidget {
  const DevLoginScreen({super.key});

  @override
  State<DevLoginScreen> createState() => _DevLoginScreenState();
}

class _DevLoginScreenState extends State<DevLoginScreen> {
  final phoneController = TextEditingController();
  final List<TextEditingController> otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> otpFocusNodes = List.generate(6, (_) => FocusNode());

  final authService = AuthService();
  bool isLoading = false;
  bool otpSent = false;
  int resendTimer = 0;
  String? errorMessage;
  String? quickLoginRole; // Track which quick login is in progress

  @override
  void dispose() {
    phoneController.dispose();
    for (var c in otpControllers) {
      c.dispose();
    }
    for (var f in otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _sendOTP() async {
    if (phoneController.text.trim().length != 10) {
      setState(() => errorMessage = tr('enter_10_digit_phone'));
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final phone = phoneController.text.trim();

    // Use real backend OTP flow
    final result = await authService.sendLoginOTP(phone: phone);

    setState(() => isLoading = false);

    if (result['success']) {
      setState(() {
        otpSent = true;
        resendTimer = 30;
      });

      // Auto-fill OTP in dev mode (when backend returns the OTP)
      final devOTP = result['data']?['otp']?.toString();
      if (devOTP != null) {
        for (int i = 0; i < devOTP.length && i < 6; i++) {
          otpControllers[i].text = devOTP[i];
        }
      }

      // Start countdown timer
      _startResendTimer();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              devOTP != null
                  ? '✅ ${tr('otp_sent')}: $devOTP'
                  : '✅ ${tr('otp_sent')}',
            ),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    } else {
      setState(() => errorMessage = result['message']);
    }
  }

  void _startResendTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted && resendTimer > 0) {
        setState(() => resendTimer--);
        return true;
      }
      return false;
    });
  }

  // Offline fallback: save mock auth data locally and navigate
  Future<void> _offlineFallbackLogin(
    String role,
    String phone,
    String firstName,
    String lastName,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final mockUser = {
      '_id': 'offline_${role}_$phone',
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'role': role,
      'isOffline': true,
    };
    await prefs.setString('accessToken', 'offline_token_$phone');
    await prefs.setString('refreshToken', 'offline_refresh_$phone');
    await prefs.setString('user', json.encode(mockUser));
    await prefs.setString('userRole', role);
    await prefs.setString('userId', mockUser['_id'] as String);
  }

  // Quick login for developer convenience - one click login for any role
  Future<void> _quickLogin(String role, {String? serviceType}) async {
    print('\n🚀 ====== QUICK LOGIN STARTED ======');
    print('📋 Role: $role');
    print('📋 Service Type: $serviceType');
    print('🌐 API Base: ${AuthService.baseUrl}');

    setState(() {
      isLoading = true;
      errorMessage = null;
      quickLoginRole = serviceType != null ? 'aloo-mitra-$serviceType' : role;
    });

    // For cold-storage-manager, try to find the actual assigned manager first
    if (role == 'cold-storage-manager') {
      final managerResult = await authService.devFindManager();
      if (managerResult['success'] == true &&
          managerResult['data']?['found'] == true) {
        final managerPhone = managerResult['data']['phone'] as String;
        // Login as the actual assigned manager
        var result = await authService.login(
          phone: managerPhone,
          password: 'password123',
        );
        // If password login fails (manager may have been created via assignManager
        // with a different password), try sending OTP
        if (!result['success']) {
          // Try with dev-register to reset password and login
          result = await authService.register(
            firstName: managerResult['data']['firstName'] ?? 'Manager',
            lastName: managerResult['data']['lastName'] ?? 'User',
            phone: managerPhone,
            password: 'password123',
            role: 'cold-storage-manager',
          );
          // If user already exists (dev-register rejects duplicates),
          // the manager was created via assignManager with password 'manager123'
          if (!result['success']) {
            result = await authService.login(
              phone: managerPhone,
              password: 'manager123',
            );
          }
        }

        setState(() {
          isLoading = false;
          quickLoginRole = null;
        });

        if (result['success']) {
          final user = result['data']['user'];
          if (mounted) {
            _navigateToHome(user['role']);
          }
        } else {
          setState(
            () => errorMessage =
                'Manager found (${managerPhone}) but login failed: ${result['message']}',
          );
        }
        return;
      }
      // No assigned manager found — fall through to default dev phone behavior
    }

    // Generate a unique phone for dev testing based on role
    final devPhones = {
      'farmer': '9999900001',
      'trader': '9999900002',
      'cold-storage': '9999900003',
      'cold-storage-manager': '9999900006',
      'admin': '9999900004',
      'aloo-mitra': '9999900005',
      // Unique phones for each Aloo Mitra service type
      'aloo-mitra-potato-seeds': '9999900010',
      'aloo-mitra-fertilizers': '9999900011',
      'aloo-mitra-machinery-rent': '9999900012',
      'aloo-mitra-transportation': '9999900013',
      'aloo-mitra-gunny-bag': '9999900014',
      'aloo-mitra-majdoor': '9999900015',
    };

    final phoneKey = serviceType != null ? 'aloo-mitra-$serviceType' : role;
    final phone = devPhones[phoneKey] ?? '9999900001';
    final roleName = {
      'farmer': 'Kisan',
      'trader': 'Vyapari',
      'cold-storage': 'ColdStorage',
      'cold-storage-manager': 'Manager',
      'admin': 'Admin',
      'aloo-mitra': 'AlooMitra',
    };

    final actualRole = serviceType != null ? 'aloo-mitra' : role;

    // Try to login first with the dev phone
    print('🔐 Attempting login with phone: $phone');
    var result = await authService.login(phone: phone, password: 'password123');
    print(
      '🔐 Login result: ${result['success']}, message: ${result['message']}',
    );

    // If login fails, register with dev-register (no OTP required)
    if (!result['success']) {
      print('📝 Login failed, attempting dev-register...');
      result = await authService.register(
        firstName: roleName[actualRole] ?? 'Dev',
        lastName: serviceType != null ? _getServiceLabel(serviceType) : 'User',
        phone: phone,
        password: 'password123',
        role: actualRole,
      );
      print(
        '📝 Register result: ${result['success']}, message: ${result['message']}',
      );
    }

    // Show error if login/register failed (no offline fallback)
    if (!result['success']) {
      print('❌ Login/register failed: ${result['message']}');
    }

    // After login/register, set the Aloo Mitra service type
    if (result['success'] && serviceType != null) {
      print('🎯 Setting Aloo Mitra service type: $serviceType');
      final alooMitraService = AlooMitraService();
      await alooMitraService.updateAlooMitraProfile(
        serviceType: serviceType,
        businessName: 'Dev ${_getServiceLabel(serviceType)}',
        state: 'Uttar Pradesh',
        district: 'Agra',
        city: 'Agra',
        pricing: '100',
        description: 'Dev test account for $serviceType',
      );
      print('✅ Aloo Mitra profile updated');
    }

    print('🏁 Quick login finishing...');
    setState(() {
      isLoading = false;
      quickLoginRole = null;
    });

    if (result['success']) {
      print('✅ Login/Register successful!');
      final user = result['data']['user'];
      final userRole = user['role'];
      print('👤 User role: $userRole');

      if (mounted) {
        print('🏠 Navigating to home screen for role: $userRole');
        _navigateToHome(userRole);
      }
    } else {
      print('❌ Login/Register failed with message: ${result['message']}');
      setState(() => errorMessage = result['message']);
    }

    print('====== QUICK LOGIN ENDED ======\n');
  }

  String _getServiceLabel(String serviceType) {
    switch (serviceType) {
      case 'potato-seeds':
        return 'Potato Seeds';
      case 'fertilizers':
        return 'Fertilizers';
      case 'machinery-rent':
        return 'Machinery';
      case 'transportation':
        return 'Transport';
      case 'gunny-bag':
        return 'Gunny Bag';
      case 'majdoor':
        return 'Majdoor';
      default:
        return serviceType;
    }
  }

  void _showAlooMitraOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final serviceTypes = [
          {
            'value': 'potato-seeds',
            'label': '🌱 Potato Seeds',
            'color': const Color(0xFF388E3C),
          },
          {
            'value': 'fertilizers',
            'label': '🧪 Fertilizers',
            'color': const Color(0xFF7B1FA2),
          },
          {
            'value': 'machinery-rent',
            'label': '🚜 Machinery Rent',
            'color': const Color(0xFFE65100),
          },
          {
            'value': 'transportation',
            'label': '🚛 Transportation',
            'color': const Color(0xFF0277BD),
          },
          {
            'value': 'gunny-bag',
            'label': '📦 Gunny Bag',
            'color': const Color(0xFF795548),
          },
          {
            'value': 'majdoor',
            'label': '👷 Majdoor',
            'color': const Color(0xFFD84315),
          },
        ];

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '🌱 Aloo Mitra - Select Service',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF388E3C),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose a service type to test its dashboard',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ...List.generate(serviceTypes.length, (i) {
                final st = serviceTypes[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _quickLogin(
                          'aloo-mitra',
                          serviceType: st['value'] as String,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: st['color'] as Color,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        st['label'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _navigateToHome(String role) {
    if (role == 'farmer') {
      Navigator.pushReplacementNamed(context, '/kishan_navbar');
    } else if (role == 'trader') {
      Navigator.pushReplacementNamed(context, '/vyapari_navbar');
    } else if (role == 'cold-storage') {
      Navigator.pushReplacementNamed(context, '/cold_storage_navbar');
    } else if (role == 'cold-storage-manager') {
      Navigator.pushReplacementNamed(context, '/manager_navbar');
    } else if (role == 'aloo-mitra') {
      Navigator.pushReplacementNamed(context, '/aloo_mitra_navbar');
    } else if (role == 'admin' || role == 'master') {
      Navigator.pushReplacementNamed(context, '/admin_home');
    } else {
      Navigator.pushReplacementNamed(context, '/language');
    }
  }

  Widget _buildQuickLoginButton({
    required String role,
    required String label,
    required Color color,
  }) {
    final isCurrentLoading = isLoading && quickLoginRole == role;

    return ElevatedButton(
      onPressed: isLoading ? null : () => _quickLogin(role),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        disabledBackgroundColor: color.withOpacity(0.6),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: isCurrentLoading
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
    );
  }

  Future<void> _verifyOTP() async {
    final otp = otpControllers.map((c) => c.text).join();
    if (otp.length < 4) {
      setState(() => errorMessage = tr('enter_4_digit_otp'));
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final phone = phoneController.text.trim();

    // Use real backend OTP verification
    final result = await authService.verifyLoginOTP(phone: phone, otp: otp);

    // No offline fallback — require server connection

    setState(() => isLoading = false);

    if (result['success']) {
      final user = result['data']['user'];
      final role = user['role'];

      if (mounted) {
        _navigateToHome(role);
      }
    } else {
      setState(() => errorMessage = result['message']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFD4E8A8), Color(0xFFF5F9EC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.5],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Logo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/logo.png',
                    height: 100,
                    errorBuilder: (context, error, stackTrace) => Column(
                      children: [
                        Icon(
                          Icons.eco,
                          size: 50,
                          color: AppColors.primaryGreen,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ALOO MARKET',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        Text(
                          tr('app_tagline'),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Title
                Text(
                  tr('login_with_phone'),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen,
                  ),
                ),

                const SizedBox(height: 20),

                // Phone Number Field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    enabled: !otpSent,
                    style: GoogleFonts.inter(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: tr('phone_number_login'),
                      hintStyle: GoogleFonts.inter(color: Colors.grey),
                      counterText: '',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/flag_icon.png',
                              width: 24,
                              height: 24,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Text(
                                    '🇮🇳',
                                    style: TextStyle(fontSize: 18),
                                  ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '+91',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 70),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Send OTP Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : (otpSent ? null : _sendOTP),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B4332),
                      disabledBackgroundColor: Colors.grey.shade400,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: isLoading && !otpSent
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            tr('send_otp_login'),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                // Resend Timer
                if (otpSent) ...[
                  const SizedBox(height: 12),
                  Text(
                    resendTimer > 0
                        ? tr(
                            'resend_otp_timer',
                          ).replaceAll('{n}', '$resendTimer')
                        : '',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // OTP Input Boxes
                if (otpSent) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(6, (index) {
                      return Container(
                        width: 46,
                        height: 55,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: TextField(
                          controller: otpControllers[index],
                          focusNode: otpFocusNodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: const InputDecoration(
                            counterText: '',
                            border: InputBorder.none,
                          ),
                          onChanged: (value) {
                            if (value.isNotEmpty && index < 5) {
                              otpFocusNodes[index + 1].requestFocus();
                            } else if (value.isEmpty && index > 0) {
                              otpFocusNodes[index - 1].requestFocus();
                            }
                          },
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 24),

                  // Verify OTP Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _verifyOTP,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B4332),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              tr('verify_otp_login'),
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Resend OTP link
                  TextButton(
                    onPressed: resendTimer > 0
                        ? null
                        : () {
                            setState(() {
                              otpSent = false;
                              for (var c in otpControllers) {
                                c.clear();
                              }
                            });
                          },
                    child: Text(
                      tr('resend_otp_login'),
                      style: GoogleFonts.inter(
                        color: resendTimer > 0
                            ? Colors.grey
                            : AppColors.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                // Error Message
                if (errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: GoogleFonts.inter(
                              color: Colors.red.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // ============================================
                // DEV QUICK LOGIN SECTION
                // ============================================
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.developer_mode,
                              color: Colors.orange.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '⚡ Quick Dev Login',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'One-tap login for testing',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.orange.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Quick login buttons
                        Row(
                          children: [
                            Expanded(
                              child: _buildQuickLoginButton(
                                role: 'farmer',
                                label: '👨‍🌾 Kisan',
                                color: const Color(0xFF2D5A27),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildQuickLoginButton(
                                role: 'trader',
                                label: '🏪 Vyapari',
                                color: const Color(0xFF1565C0),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildQuickLoginButton(
                                role: 'cold-storage',
                                label: '❄️ Cold Storage',
                                color: const Color(0xFF00838F),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildQuickLoginButton(
                                role: 'admin',
                                label: '👑 Admin',
                                color: const Color(0xFF6A1B9A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildQuickLoginButton(
                                role: 'cold-storage-manager',
                                label: '🔑 Manager',
                                color: const Color(0xFF455A64),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(child: SizedBox()),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _showAlooMitraOptions,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF388E3C),
                              disabledBackgroundColor: const Color(
                                0xFF388E3C,
                              ).withOpacity(0.6),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child:
                                (isLoading &&
                                    (quickLoginRole?.startsWith('aloo-mitra') ??
                                        false))
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    '🌱 Aloo Mitra (Select Role →)',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // Create Account Link
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/sign_up'),
                  child: Text(
                    tr('new_here_create_account'),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
