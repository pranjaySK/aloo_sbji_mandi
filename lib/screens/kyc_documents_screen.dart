// ──────────────────────────────────────────────────────────────
// KYC Documents Screen — Coming Soon (original code commented below)
// ──────────────────────────────────────────────────────────────
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class KYCDocumentsScreen extends StatelessWidget {
  const KYCDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: CustomRoundedAppBar(title: tr('kyc_documents')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  size: 72,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                tr('coming_soon'),
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'KYC verification will be available soon. We are setting up a secure and seamless verification process for you.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: Text(tr('go_back')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  side: const BorderSide(color: AppColors.primaryGreen),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ═══════════════════════════════════════════════════════════════
   ORIGINAL KYC DOCUMENTS SCREEN CODE — COMMENTED OUT
   ═══════════════════════════════════════════════════════════════

class _OrigKYCDocumentsScreenState extends State<_OrigKYCDocumentsScreen>
    with TickerProviderStateMixin {
  final KycService _kycService = KycService();
  final _aadhaarController = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());

  // State
  String _kycStatus = 'not_started'; // not_started, otp_sent, verified
  String? _maskedAadhaar;
  String? _transactionId;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isVerifying = false;
  String? _errorMessage;
  String? _successMessage;

  // OTP Timer
  Timer? _otpTimer;
  int _otpSecondsLeft = 0;
  bool _canResend = false;

  // Photo
  String? _aadhaarPhotoBase64;
  bool _hasPhoto = false;

  // Animation
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(
      begin: 0,
      end: 10,
    ).chain(CurveTween(curve: Curves.elasticIn)).animate(_shakeController);
    _loadKycStatus();
  }

  @override
  void dispose() {
    _aadhaarController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _otpTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _loadKycStatus() async {
    try {
      final result = await _kycService.getKycStatus();
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (result['success'] && result['data'] != null) {
            final data = result['data'];
            _kycStatus = data['status'] ?? 'not_started';
            _maskedAadhaar = data['maskedAadhaar'];
            _hasPhoto = data['hasPhoto'] ?? false;
          } else {
            // API failed but don't block — default to not_started so user can still begin
            _kycStatus = 'not_started';
            _errorMessage = result['message'];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _kycStatus = 'not_started';
          _errorMessage = AppLocalizations.isHindi
              ? tr('kyc_status_load_error')
              : 'Could not load status. Please try again.';
        });
      }
    }
  }

  // ─── AADHAAR VALIDATION ──────────────────────
  String? _validateAadhaar(String value) {
    final cleaned = value.replaceAll(RegExp(r'\s|-'), '');
    if (cleaned.isEmpty) return tr('enter_aadhaar_number');
    if (cleaned.length != 12) return tr('must_be_12_digits');
    if (!RegExp(r'^\d{12}$').hasMatch(cleaned))
      return tr('only_digits_allowed');
    if (cleaned.startsWith('0') || cleaned.startsWith('1')) {
      return tr('invalid_aadhaar');
    }
    if (!_verhoeffCheck(cleaned)) {
      return tr('invalid_aadhaar');
    }
    return null;
  }

  // Verhoeff algorithm
  static const List<List<int>> _d = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
    [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
    [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
    [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
    [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
    [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
    [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
    [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
    [9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
  ];
  static const List<List<int>> _p = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
    [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
    [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
    [9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
    [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
    [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
    [7, 0, 4, 6, 9, 1, 3, 2, 5, 8],
  ];

  bool _verhoeffCheck(String num) {
    int c = 0;
    final reversed = num.split('').reversed.toList();
    for (int i = 0; i < reversed.length; i++) {
      c = _d[c][_p[i % 8][int.parse(reversed[i])]];
    }
    return c == 0;
  }

  // ─── SEND OTP ────────────────────────────────
  Future<void> _sendOtp() async {
    final cleaned = _aadhaarController.text.replaceAll(RegExp(r'\s|-'), '');
    final error = _validateAadhaar(cleaned);
    if (error != null) {
      setState(() => _errorMessage = error);
      _shakeController.forward(from: 0);
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final result = await _kycService.sendAadhaarOtp(cleaned);

    if (mounted) {
      setState(() {
        _isSending = false;
        if (result['success']) {
          _kycStatus = 'otp_sent';
          _transactionId = result['data']['transactionId'];
          _maskedAadhaar = result['data']['maskedAadhaar'];
          _successMessage = AppLocalizations.isHindi
              ? tr('otp_sent_to_aadhaar')
              : 'OTP sent to your Aadhaar-linked mobile';
          _startOtpTimer();
        } else {
          _errorMessage = result['message'] ?? 'Failed to send OTP';
          _shakeController.forward(from: 0);
        }
      });
    }
  }

  // ─── VERIFY OTP ──────────────────────────────
  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      setState(() => _errorMessage = tr('enter_complete_otp'));
      _shakeController.forward(from: 0);
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final result = await _kycService.verifyAadhaarOtp(otp, _transactionId!);

    if (mounted) {
      setState(() {
        _isVerifying = false;
        if (result['success']) {
          _kycStatus = 'verified';
          _maskedAadhaar = result['data']['maskedAadhaar'];
          _otpTimer?.cancel();
          _successMessage = AppLocalizations.isHindi
              ? tr('aadhaar_verified')
              : 'Aadhaar verified successfully! ✅';
        } else {
          _errorMessage = result['message'] ?? 'Verification failed';
          _shakeController.forward(from: 0);
          for (final c in _otpControllers) {
            c.clear();
          }
          if (_otpFocusNodes[0].canRequestFocus) {
            _otpFocusNodes[0].requestFocus();
          }
        }
      });
    }
  }

  // ─── RESEND OTP ──────────────────────────────
  Future<void> _resendOtp() async {
    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    final result = await _kycService.resendAadhaarOtp();

    if (mounted) {
      setState(() {
        _isSending = false;
        if (result['success']) {
          _transactionId = result['data']['transactionId'];
          _successMessage = AppLocalizations.isHindi
              ? tr('new_otp_sent')
              : 'New OTP sent';
          _startOtpTimer();
          for (final c in _otpControllers) {
            c.clear();
          }
        } else {
          _errorMessage = result['message'];
        }
      });
    }
  }

  void _startOtpTimer() {
    _otpTimer?.cancel();
    _otpSecondsLeft = 60;
    _canResend = false;
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _otpSecondsLeft--;
          if (_otpSecondsLeft <= 0) {
            _canResend = true;
            timer.cancel();
          }
        });
      }
    });
  }

  // ─── UPLOAD PHOTO ────────────────────────────
  Future<void> _pickAndUploadPhoto() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        // Check file size (max 5MB)
        if (bytes.length > 5 * 1024 * 1024) {
          if (mounted) {
            setState(
              () => _errorMessage = AppLocalizations.isHindi
                  ? tr('photo_size_limit')
                  : 'Photo must be less than 5MB',
            );
          }
          return;
        }
        final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        if (mounted) setState(() => _aadhaarPhotoBase64 = base64Str);

        final result = await _kycService.uploadAadhaarPhoto(base64Str);
        if (mounted) {
          setState(() {
            if (result['success']) {
              _hasPhoto = true;
              _successMessage = tr('photo_uploaded');
            } else {
              _errorMessage = result['message'];
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = AppLocalizations.isHindi
              ? tr('photo_upload_failed')
              : 'Failed to upload photo',
        );
      }
    }
  }

  // ─── GO BACK ─────────────────────────────────
  void _goBackToAadhaarEntry() {
    setState(() {
      _kycStatus = 'not_started';
      _otpTimer?.cancel();
      _errorMessage = null;
      _successMessage = null;
      for (final c in _otpControllers) {
        c.clear();
      }
    });
  }

  // ═══════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: CustomRoundedAppBar(title: tr('kyc_documents')),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: 20),

                  // Messages
                  if (_errorMessage != null)
                    _buildMessageBanner(_errorMessage!, isError: true),
                  if (_successMessage != null)
                    _buildMessageBanner(_successMessage!, isError: false),
                  if (_errorMessage != null || _successMessage != null)
                    const SizedBox(height: 16),

                  // Step content
                  if (_kycStatus == 'not_started' || _kycStatus == 'failed')
                    _buildAadhaarEntryStep(),
                  if (_kycStatus == 'otp_sent') _buildOtpStep(),
                  if (_kycStatus == 'verified') _buildVerifiedStep(),

                  const SizedBox(height: 24),
                  _buildBenefitsCard(),
                  const SizedBox(height: 24),
                  _buildSecurityNote(),
                ],
              ),
            ),
    );
  }

  // ─── STATUS CARD ─────────────────────────────
  Widget _buildStatusCard() {
    final isVerified = _kycStatus == 'verified';
    final isOtpSent = _kycStatus == 'otp_sent';

    IconData icon;
    String title;
    String subtitle;
    double progress;

    if (isVerified) {
      icon = Icons.verified;
      title = tr('verified_tick');
      subtitle = tr('aadhaar_verified_msg');
      progress = 1.0;
    } else if (isOtpSent) {
      icon = Icons.sms_outlined;
      title = tr('otp_sent_label');
      subtitle = _maskedAadhaar != null
          ? '${tr('aadhaar_label')}: $_maskedAadhaar'
          : '';
      progress = 0.5;
    } else {
      icon = Icons.shield_outlined;
      title = tr('verify_identity');
      subtitle = tr('verify_via_aadhaar');
      progress = 0.0;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isVerified
              ? [Colors.green.shade600, Colors.green.shade400]
              : [AppColors.primaryGreen, Colors.green.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 3-step indicator
          Row(
            children: [
              _stepDot(1, tr('aadhaar_label'), progress >= 0.0),
              Expanded(
                child: Container(
                  height: 2,
                  color: progress >= 0.5 ? Colors.white : Colors.white30,
                ),
              ),
              _stepDot(2, 'OTP', progress >= 0.5),
              Expanded(
                child: Container(
                  height: 2,
                  color: progress >= 1.0 ? Colors.white : Colors.white30,
                ),
              ),
              _stepDot(3, tr('done_label'), progress >= 1.0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepDot(int num, String label, bool active) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? Colors.white : Colors.white24,
          ),
          child: Center(
            child: active
                ? Icon(Icons.check, size: 16, color: AppColors.primaryGreen)
                : Text(
                    '$num',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(active ? 1 : 0.6),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  // ─── STEP 1: AADHAAR ENTRY ───────────────────
  Widget _buildAadhaarEntryStep() {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            _shakeAnimation.value *
                ((_shakeController.status == AnimationStatus.forward) ? 1 : 0),
            0,
          ),
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBg(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.credit_card,
                    color: Colors.orange.shade700,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.isHindi
                            ? tr('enter_aadhaar_title')
                            : 'Enter Aadhaar Number',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        AppLocalizations.isHindi
                            ? tr('otp_will_be_sent_aadhaar')
                            : 'OTP will be sent to Aadhaar-linked mobile',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Aadhaar Input
            TextField(
              controller: _aadhaarController,
              keyboardType: TextInputType.number,
              maxLength: 12,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.inter(
                fontSize: 20,
                letterSpacing: 3,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'XXXX XXXX XXXX',
                hintStyle: TextStyle(
                  color: Colors.grey.shade300,
                  letterSpacing: 3,
                ),
                prefixIcon: const Icon(
                  Icons.badge_outlined,
                  color: AppColors.primaryGreen,
                ),
                counterText: '',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
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
            const SizedBox(height: 8),
            Text(
              AppLocalizations.isHindi
                  ? tr('aadhaar_secure_msg')
                  : '🔒 Your Aadhaar number is encrypted & secure',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),

            const SizedBox(height: 16),

            // Optional Photo Upload
            GestureDetector(
              onTap: _pickAndUploadPhoto,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _aadhaarPhotoBase64 != null
                      ? Colors.green.shade50
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _aadhaarPhotoBase64 != null
                        ? Colors.green.shade300
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _aadhaarPhotoBase64 != null
                          ? Icons.check_circle
                          : Icons.add_a_photo_outlined,
                      color: _aadhaarPhotoBase64 != null
                          ? Colors.green
                          : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _aadhaarPhotoBase64 != null
                            ? (AppLocalizations.isHindi
                                  ? tr('photo_uploaded_check')
                                  : 'Photo uploaded ✅')
                            : (AppLocalizations.isHindi
                                  ? tr('upload_aadhaar_photo')
                                  : 'Upload Aadhaar card photo (optional)'),
                        style: TextStyle(
                          color: _aadhaarPhotoBase64 != null
                              ? Colors.green.shade700
                              : Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Send OTP Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSending ? null : _sendOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 3,
                ),
                child: _isSending
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tr('send_otp'),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── STEP 2: OTP ENTRY ───────────────────────
  Widget _buildOtpStep() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.sms_outlined,
                  color: Colors.blue.shade700,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('enter_otp'),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      AppLocalizations.isHindi
                          ? tr('sent_to_aadhaar_mobile')
                          : 'Sent to Aadhaar-linked mobile',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_maskedAadhaar != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${tr('aadhaar_label')}: $_maskedAadhaar',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          const SizedBox(height: 20),

          // 6-digit OTP boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (index) {
              return SizedBox(
                width: 46,
                height: 54,
                child: TextField(
                  controller: _otpControllers[index],
                  focusNode: _otpFocusNodes[index],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppColors.primaryGreen,
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty && index < 5) {
                      _otpFocusNodes[index + 1].requestFocus();
                    } else if (value.isEmpty && index > 0) {
                      _otpFocusNodes[index - 1].requestFocus();
                    }
                    // Auto-verify when all 6 digits entered
                    if (index == 5 && value.isNotEmpty) {
                      final otp = _otpControllers.map((c) => c.text).join();
                      if (otp.length == 6) {
                        _verifyOtp();
                      }
                    }
                  },
                ),
              );
            }),
          ),

          const SizedBox(height: 16),

          // Timer & Resend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_canResend) ...[
                Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  trArgs('resend_otp_countdown', {
                    'seconds': _otpSecondsLeft.toString(),
                  }),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ] else
                TextButton.icon(
                  onPressed: _isSending ? null : _resendOtp,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(
                    tr('resend_otp'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Verify Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isVerifying ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 3,
              ),
              child: _isVerifying
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tr('verify_otp_btn'),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 12),

          // Change Aadhaar
          Center(
            child: TextButton(
              onPressed: _goBackToAadhaarEntry,
              child: Text(
                tr('change_aadhaar'),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── STEP 3: VERIFIED ────────────────────────
  Widget _buildVerifiedStep() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade300, width: 2),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.verified, color: Colors.green.shade700, size: 48),
          ),
          const SizedBox(height: 16),
          Text(
            tr('aadhaar_verified_congrats'),
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          ),
          const SizedBox(height: 8),
          if (_maskedAadhaar != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.credit_card,
                    color: Colors.green.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _maskedAadhaar!,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.isHindi
                ? tr('identity_verified_msg')
                : 'Your identity is verified.\nYou now have access to more features!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.green.shade700,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── MESSAGE BANNER ──────────────────────────
  Widget _buildMessageBanner(String message, {required bool isError}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isError ? Colors.red.shade200 : Colors.green.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? Colors.red.shade700 : Colors.green.shade700,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError ? Colors.red.shade800 : Colors.green.shade800,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── BENEFITS CARD ───────────────────────────
  Widget _buildBenefitsCard() {
    final benefits = AppLocalizations.isHindi
        ? [
            tr('kyc_benefit_trust'),
            tr('kyc_benefit_buyers'),
            tr('kyc_benefit_secure'),
            tr('kyc_benefit_offers'),
          ]
        : [
            '✅ Increased trust among users',
            '✅ More buyers and sellers connect with you',
            '✅ Secure transactions',
            '✅ Access to exclusive offers',
          ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                tr('benefits_of_kyc'),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...benefits.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                b,
                style: TextStyle(color: Colors.blue.shade700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SECURITY NOTE ───────────────────────────
  Widget _buildSecurityNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: Colors.grey.shade600, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppLocalizations.isHindi
                  ? tr('aadhaar_encryption_note')
                  : 'Your Aadhaar number is encrypted and secured as per UIDAI guidelines. We never store your full Aadhaar number.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

═══════════════════════════════════════════════════════════════ */
