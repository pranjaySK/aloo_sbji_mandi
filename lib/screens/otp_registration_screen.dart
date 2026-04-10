import 'dart:async';

import 'package:aloo_sbji_mandi/core/service/auth_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class OTPRegistrationScreen extends StatefulWidget {
  const OTPRegistrationScreen({super.key});

  @override
  State<OTPRegistrationScreen> createState() => _OTPRegistrationScreenState();
}

class _OTPRegistrationScreenState extends State<OTPRegistrationScreen> {
  // Controllers
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final List<TextEditingController> otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> otpFocusNodes = List.generate(6, (_) => FocusNode());

  // State
  final authService = AuthService();
  String selectedRole = 'farmer';
  String? selectedSubRole; // For Aloo Mitra sub-role
  bool isLoading = false;
  bool otpSent = false;
  String? errorMessage;
  String? devOTP; // For development mode
  int resendTimer = 0;
  Timer? _timer;

  // Sub-roles for Aloo Mitra
  List<Map<String, String>> get alooMitraSubRoles => [
    {'value': 'fertilizers', 'label': tr('subrole_fertilizers')},
    {'value': 'majdoor', 'label': tr('subrole_majdoor')},
    {'value': 'seed-provider', 'label': tr('subrole_seed_provider')},
  ];

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
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
    // Validate fields
    if (firstNameController.text.isEmpty || lastNameController.text.isEmpty) {
      setState(() => errorMessage = "Please enter your name");
      return;
    }
    if (phoneController.text.isEmpty || phoneController.text.length < 10) {
      setState(() => errorMessage = "Please enter a valid phone number");
      return;
    }
    if (passwordController.text.length < 6) {
      setState(() => errorMessage = "Password must be at least 6 characters");
      return;
    }
    if (selectedRole == 'aloo-mitra' && selectedSubRole == null) {
      setState(() => errorMessage = "Please select your Aloo Mitra category");
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final result = await authService.registerAndSendOTP(
      firstName: firstNameController.text.trim(),
      lastName: lastNameController.text.trim(),
      phone: phoneController.text.trim(),
      password: passwordController.text,
      role: selectedRole,
      subRole: selectedRole == 'aloo-mitra' ? selectedSubRole : null,
    );

    setState(() => isLoading = false);

    if (result['success']) {
      setState(() {
        otpSent = true;
        devOTP = result['data']?['otp']; // Only in dev mode
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

    final result = await authService.resendOTP(
      phone: phoneController.text.trim(),
    );

    setState(() => isLoading = false);

    if (result['success']) {
      setState(() {
        devOTP = result['data']?['otp'];
      });
      startResendTimer();

      // Clear and auto-fill OTP in dev mode
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

    final result = await authService.verifyOTPAndRegister(
      phone: phoneController.text.trim(),
      otp: otp,
    );

    setState(() => isLoading = false);

    if (result['success']) {
      final user = result['data']['user'];
      final role = user['role'];

      if (mounted) {
        // Navigate based on role
        if (role == 'farmer') {
          Navigator.pushReplacementNamed(context, '/kishan_navbar');
        } else if (role == 'trader') {
          Navigator.pushReplacementNamed(context, '/vyapari_navbar');
        } else if (role == 'cold-storage') {
          Navigator.pushReplacementNamed(context, '/cold_storage_navbar');
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
                const SizedBox(height: 30),

                // Logo
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Image.asset('assets/logo.png', height: 70),
                ),

                const SizedBox(height: 20),

                Text(
                  otpSent ? "Verify OTP" : "Create Account",
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryGreen,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  otpSent
                      ? "Enter the 6-digit OTP sent to ${phoneController.text}"
                      : "Register with your phone number",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

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
                  // Registration Form
                  _buildRegistrationForm(),
                ] else ...[
                  // OTP Form
                  _buildOTPForm(),
                ],

                const SizedBox(height: 20),

                // Back to login
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Already have an account? Login",
                    style: GoogleFonts.inter(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegistrationForm() {
    return Column(
      children: [
        // Name fields
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: firstNameController,
                hint: "First Name",
                icon: Icons.person,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                controller: lastNameController,
                hint: "Last Name",
                icon: Icons.person_outline,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Phone field
        _buildTextField(
          controller: phoneController,
          hint: "Phone Number",
          icon: Icons.phone,
          prefix: "+91 ",
          keyboardType: TextInputType.phone,
          maxLength: 10,
        ),

        const SizedBox(height: 16),

        // Password field
        _buildTextField(
          controller: passwordController,
          hint: "Password",
          icon: Icons.lock,
          isPassword: true,
        ),

        const SizedBox(height: 16),

        // Role selection
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Select Your Role",
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildRoleChip("farmer", "🌾 Farmer"),
                  const SizedBox(width: 8),
                  _buildRoleChip("trader", "🛒 Trader"),
                  const SizedBox(width: 8),
                  _buildRoleChip("cold-storage", "❄️ Storage"),
                  const SizedBox(width: 8),
                  _buildRoleChip("aloo-mitra", "🤝 Aloo Mitra"),
                ],
              ),
            ],
          ),
        ),

        // Aloo Mitra Sub-Role Selection
        if (selectedRole == 'aloo-mitra') ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryGreen),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Select Your Category",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedSubRole,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  hint: Text(
                    "Choose category",
                    style: GoogleFonts.inter(color: Colors.grey[500]),
                  ),
                  items: alooMitraSubRoles.map((subRole) {
                    return DropdownMenuItem<String>(
                      value: subRole['value'],
                      child: Text(
                        subRole['label']!,
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => selectedSubRole = value);
                  },
                ),
              ],
            ),
          ),
        ],

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
      ],
    );
  }

  Widget _buildOTPForm() {
    return Column(
      children: [
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                    "Verify & Create Account",
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 16),

        // Change phone number
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
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? prefix,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword,
      maxLength: maxLength,
      decoration: InputDecoration(
        counterText: "",
        prefixIcon: Icon(icon, color: AppColors.primaryGreen),
        prefixText: prefix,
        prefixStyle: GoogleFonts.inter(color: AppColors.textPrimary(context)),
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
      ),
    );
  }

  Widget _buildRoleChip(String role, String label) {
    final isSelected = selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          selectedRole = role;
          if (role != 'aloo-mitra') {
            selectedSubRole = null;
          }
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryGreen : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}
