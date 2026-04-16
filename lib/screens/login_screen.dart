import 'dart:async';

import 'package:aloo_sbji_mandi/core/service/auth_service.dart';
import 'package:aloo_sbji_mandi/core/service/chat_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:aloo_sbji_mandi/widgets/common_widget.dart/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phoneController = TextEditingController();
  final List<TextEditingController> otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> otpFocusNodes = List.generate(6, (_) => FocusNode());

  final AuthService _authService = AuthService();

  int resendTimer = 0;
  Timer? _timer;
  bool otpSent = false;
  bool isLoading = false;
  String? errorMessage;
  String? devOTP; // For dev mode auto-fill

  @override
  void dispose() {
    phoneController.dispose();
    for (var c in otpControllers) {
      c.dispose();
    }
    for (var f in otpFocusNodes) {
      f.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() => resendTimer = 120);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendTimer > 0) {
        setState(() => resendTimer--);
      } else {
        timer.cancel();
      }
    });
  }

  /// Send OTP to the phone number via backend
  Future<void> _sendOTP() async {
    final phone = phoneController.text.trim();
    if (phone.length != 10) {
      setState(
        () => errorMessage = "Please enter a valid 10-digit phone number",
      );
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final result = await _authService.sendLoginOTP(phone: phone);

    setState(() => isLoading = false);

    if (result['success']) {
      setState(() {
        otpSent = true;
        devOTP = result['data']?['otp']?.toString();
      });
      _startResendTimer();

      // Auto-fill OTP in dev mode (when backend returns the OTP)
      if (devOTP != null) {
        for (int i = 0; i < devOTP!.length && i < 6; i++) {
          otpControllers[i].text = devOTP![i];
        }
      } else {
        // Focus first OTP field
        otpFocusNodes[0].requestFocus();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              devOTP != null
                  ? '✅ OTP sent: $devOTP (Dev Mode)'
                  : '✅ OTP sent to +91 $phone',
            ),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    } else {
      setState(() => errorMessage = result['message']);
    }
  }

  /// Verify OTP and login
  Future<void> _verifyOTP() async {
    final otp = otpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      setState(() => errorMessage = "Please enter the complete 6-digit OTP");
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final result = await _authService.verifyLoginOTP(
      phone: phoneController.text.trim(),
      otp: otp,
    );

    setState(() => isLoading = false);

    if (result['success']) {
      final user = result['data']['user'];
      final role = user['role'] ?? 'farmer';

      // Connect to socket after successful login
      final chatService = ChatService();
      chatService.connectSocket();

      if (mounted) {
        // Navigate based on user role — clear entire stack
        if (role == 'farmer') {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/kishan_navbar',
            (route) => false,
          );
        } else if (role == 'trader') {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/vyapari_navbar',
            (route) => false,
          );
        } else if (role == 'cold-storage') {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/cold_storage_navbar',
            (route) => false,
          );
        } else if (role == 'cold-storage-manager') {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/manager_navbar',
            (route) => false,
          );
        } else if (role == 'aloo-mitra') {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/aloo_mitra_navbar',
            (route) => false,
          );
        } else if (role == 'admin' || role == 'master') {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/admin_home',
            (route) => false,
          );
        } else {
          // Fallback: go to role selection
          Navigator.pushNamedAndRemoveUntil(context, '/role', (route) => false);
        }
      }
    } else {
      setState(() => errorMessage = result['message']);
    }
  }

  /// Resend OTP
  Future<void> _resendOTP() async {
    if (resendTimer > 0) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final result = await _authService.sendLoginOTP(
      phone: phoneController.text.trim(),
    );

    setState(() => isLoading = false);

    if (result['success']) {
      setState(() {
        devOTP = result['data']?['otp']?.toString();
      });
      _startResendTimer();

      // Clear and refill OTP fields
      for (var c in otpControllers) {
        c.clear();
      }
      if (devOTP != null) {
        for (int i = 0; i < devOTP!.length && i < 6; i++) {
          otpControllers[i].text = devOTP![i];
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('otp_resent'))));
      }
    } else {
      setState(() => errorMessage = result['message']);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final horizontalPadding = screenHeight < 700 ? 20.0 : 24.0;
    final topSpacing = screenHeight < 700 ? 24.0 : 40.0;
    final sectionSpacing = screenHeight < 700 ? 20.0 : 30.0;
    final buttonSpacing = screenHeight < 700 ? 12.0 : 16.0;
    final otpTopSpacing = screenHeight < 700 ? 10.0 : 12.0;
    final bottomSpacing = screenHeight < 700 ? 20.0 : 32.0;
    final logoHeight = screenHeight < 700 ? 110.0 : 140.0;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFCFFF9E), Color(0xFFEFFBE6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    children: [
                      SizedBox(height: topSpacing),

                      /// Logo
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/logo.png',
                          height: logoHeight,
                          fit: BoxFit.contain,
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
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: sectionSpacing),

                      Text(
                        "LOG IN with phone number",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.heading,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      SizedBox(height: buttonSpacing - 4),

                      /// Phone field
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        enabled: !otpSent,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          counterText: '',
                          prefixIcon: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text("🇮🇳 +91"),
                          ),
                          hintText: "Phone Number",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                              width: 1,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: buttonSpacing),

                      /// Send OTP Button
                      PrimaryButton(
                        text: isLoading && !otpSent ? "Sending..." : "Send OTP",
                        onTap: isLoading || otpSent ? null : _sendOTP,
                      ),

                      SizedBox(height: buttonSpacing),

                      /// Resend timer
                      if (otpSent && resendTimer > 0)
                        Text(
                          "Resend OTP in $resendTimer seconds",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.bulerTextColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                      /// OTP section — only visible after OTP is sent
                      if (otpSent) ...[
                        SizedBox(height: otpTopSpacing),
                        Text(
                          "Enter 6-digit OTP",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),

                        /// OTP boxes (6 digits)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                            6,
                            (index) => SizedBox(
                              width: 48,
                              child: TextField(
                                controller: otpControllers[index],
                                focusNode: otpFocusNodes[index],
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                maxLength: 1,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: (value) {
                                  if (value.isNotEmpty && index < 5) {
                                    otpFocusNodes[index + 1].requestFocus();
                                  } else if (value.isEmpty && index > 0) {
                                    otpFocusNodes[index - 1].requestFocus();
                                  }
                                },
                                decoration: InputDecoration(
                                  counterText: "",
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.border,
                                      width: .8,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: screenHeight < 700 ? 18.0 : 24.0),

                        /// Verify OTP Button
                        PrimaryButton(
                          text: isLoading ? "Verifying..." : "Verify OTP",
                          onTap: isLoading ? null : _verifyOTP,
                        ),

                        SizedBox(height: otpTopSpacing),

                        /// Resend OTP link
                        GestureDetector(
                          onTap: (resendTimer == 0 && otpSent && !isLoading)
                              ? _resendOTP
                              : null,
                          child: Text(
                            "Resend OTP",
                            style: GoogleFonts.inter(
                              color: (resendTimer == 0 && otpSent)
                                  ? AppColors.primaryGreen
                                  : Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],

                      /// Error message
                      if (errorMessage != null) ...[
                        SizedBox(height: buttonSpacing),
                        Container(
                          width: double.infinity,
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

                      SizedBox(height: bottomSpacing),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "New here?",
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(context, '/sign_up');
                            },
                            child: Text(
                              " Create an Account",
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenHeight < 700 ? 16.0 : 24.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
