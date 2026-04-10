import 'dart:async';

import 'package:aloo_sbji_mandi/core/service/auth_service.dart';
import 'package:aloo_sbji_mandi/core/service/chat_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class OTPLoginScreen extends StatefulWidget {
  const OTPLoginScreen({super.key});

  @override
  State<OTPLoginScreen> createState() => _OTPLoginScreenState();
}

class _OTPLoginScreenState extends State<OTPLoginScreen> {
  final phoneController = TextEditingController();
  final List<TextEditingController> otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> otpFocusNodes = List.generate(6, (_) => FocusNode());

  final authService = AuthService();
  bool isLoading = false;
  bool otpSent = false;
  String? errorMessage;
  String? devOTP;
  int resendTimer = 0;
  Timer? _timer;

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

  void startResendTimer() {
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

  Future<void> sendOTP() async {
    if (phoneController.text.isEmpty || phoneController.text.length < 10) {
      setState(() => errorMessage = "Please enter a valid phone number");
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final result = await authService.sendLoginOTP(
      phone: phoneController.text.trim(),
    );

    setState(() => isLoading = false);

    if (result['success']) {
      setState(() {
        otpSent = true;
        devOTP = result['data']?['otp'];
      });
      startResendTimer();

      // Auto-fill OTP in dev mode
      if (devOTP != null) {
        for (int i = 0; i < devOTP!.length && i < 6; i++) {
          otpControllers[i].text = devOTP![i];
        }
      }
    } else {
      setState(() => errorMessage = result['message']);
    }
  }

  Future<void> resendOTP() async {
    if (resendTimer > 0) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final result = await authService.sendLoginOTP(
      phone: phoneController.text.trim(),
    );

    setState(() => isLoading = false);

    if (result['success']) {
      setState(() {
        devOTP = result['data']?['otp'];
      });
      startResendTimer();

      for (var c in otpControllers) {
        c.clear();
      }
      if (devOTP != null) {
        for (int i = 0; i < devOTP!.length && i < 6; i++) {
          otpControllers[i].text = devOTP![i];
        }
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('otp_resent'))));
    } else {
      setState(() => errorMessage = result['message']);
    }
  }

  Future<void> verifyOTP() async {
    final otp = otpControllers.map((c) => c.text).join();

    if (otp.length != 6) {
      setState(() => errorMessage = "Please enter complete OTP");
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final result = await authService.verifyLoginOTP(
      phone: phoneController.text.trim(),
      otp: otp,
    );

    setState(() => isLoading = false);

    if (result['success']) {
      final user = result['data']['user'];
      final role = user['role'];

      // Connect to socket after successful login
      final chatService = ChatService();
      chatService.connectSocket();

      if (mounted) {
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
        }
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFCFFF9E), Color(0xFFEFFBE6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 50),

                // Logo
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Image.asset('assets/logo.png', height: 80),
                ),

                const SizedBox(height: 30),

                Text(
                  otpSent ? "Verify OTP" : "Login with OTP",
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryGreen,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  otpSent
                      ? "Enter the 6-digit OTP sent to\n+91 ${phoneController.text}"
                      : "Enter your registered phone number",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 30),

                // Error message
                if (errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Dev mode OTP display
                if (devOTP != null && otpSent)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.developer_mode, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          "Dev Mode OTP: $devOTP",
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (!otpSent) ...[
                  // Phone input
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.inter(fontSize: 16),
                    decoration: InputDecoration(
                      counterText: "",
                      prefixIcon: const Icon(
                        Icons.phone,
                        color: AppColors.primaryGreen,
                      ),
                      prefixText: "+91 ",
                      prefixStyle: GoogleFonts.inter(
                        color: AppColors.textPrimary(context),
                        fontSize: 16,
                      ),
                      hintText: "Enter Phone Number",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primaryGreen,
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Send OTP Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : sendOTP,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              "Send OTP",
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ] else ...[
                  // OTP Input boxes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(6, (index) {
                      return SizedBox(
                        width: 45,
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
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            counterText: "",
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primaryGreen,
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            if (value.isNotEmpty && index < 5) {
                              otpFocusNodes[index + 1].requestFocus();
                            }
                            if (value.isEmpty && index > 0) {
                              otpFocusNodes[index - 1].requestFocus();
                            }
                          },
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 24),

                  // Timer / Resend
                  if (resendTimer > 0)
                    Text(
                      "Resend OTP in ${resendTimer}s",
                      style: GoogleFonts.inter(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  else
                    TextButton(
                      onPressed: isLoading ? null : resendOTP,
                      child: Text(
                        "Resend OTP",
                        style: GoogleFonts.inter(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Verify Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : verifyOTP,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              "Verify & Login",
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Change phone
                  TextButton(
                    onPressed: () {
                      setState(() {
                        otpSent = false;
                        devOTP = null;
                        for (var c in otpControllers) {
                          c.clear();
                        }
                      });
                    },
                    child: Text(
                      "Change Phone Number",
                      style: GoogleFonts.inter(
                        color: Colors.grey[600],
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 30),

                // Register link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "New here? ",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          Navigator.pushNamed(context, '/otp_register'),
                      child: Text(
                        "Create Account",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
