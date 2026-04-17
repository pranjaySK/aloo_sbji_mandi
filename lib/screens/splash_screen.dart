import 'package:aloo_sbji_mandi/core/service/chat_service.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndNavigate();
    });
  }

  Future<void> _checkAuthAndNavigate() async {
    debugPrint('[SplashScreen] Checking auth state...');

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    final role = prefs.getString('userRole');

    debugPrint('[SplashScreen] token=$token');
    debugPrint('[SplashScreen] role=$role');

    if (token == null || token.isEmpty) {
      debugPrint('[SplashScreen] No session -> LoginScreen');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    debugPrint('[SplashScreen] Session found -> navigating for role=$role');

    try {
      ChatService().connectSocket();
    } catch (e) {
      debugPrint('[SplashScreen] Socket connect error (non-fatal): $e');
    }

    if (!mounted) return;

    switch (role) {
      case 'farmer':
        Navigator.pushReplacementNamed(context, '/kishan_navbar');
        break;
      case 'trader':
        Navigator.pushReplacementNamed(context, '/vyapari_navbar');
        break;
      case 'cold-storage':
        Navigator.pushReplacementNamed(context, '/cold_storage_navbar');
        break;
      case 'cold-storage-manager':
        Navigator.pushReplacementNamed(context, '/manager_navbar');
        break;
      case 'aloo-mitra':
        Navigator.pushReplacementNamed(context, '/aloo_mitra_navbar');
        break;
      case 'admin':
      case 'master':
        Navigator.pushReplacementNamed(context, '/admin_home');
        break;
      default:
        debugPrint('[SplashScreen] Unknown role "$role" -> LoginScreen');
        Navigator.pushReplacementNamed(context, '/login');
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
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
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
                      Icon(Icons.eco, size: 50, color: AppColors.primaryGreen),
                      const SizedBox(height: 4),
                      Text(
                        'ALOO MARKET',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
