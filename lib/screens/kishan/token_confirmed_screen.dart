import 'dart:math';

import 'package:aloo_sbji_mandi/core/service/token_service.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TokenConfirmedScreen extends StatefulWidget {
  final Map<String, dynamic> tokenData;
  final String coldStorageName;
  final VoidCallback? onViewLiveStatus;
  final VoidCallback? onCancelToken;

  const TokenConfirmedScreen({
    super.key,
    required this.tokenData,
    required this.coldStorageName,
    this.onViewLiveStatus,
    this.onCancelToken,
  });

  @override
  State<TokenConfirmedScreen> createState() => _TokenConfirmedScreenState();
}

class _TokenConfirmedScreenState extends State<TokenConfirmedScreen>
    with TickerProviderStateMixin {
  late AnimationController _confettiController;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  final List<_ConfettiPiece> _confettiPieces = [];

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _bounceAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );

    // Generate confetti pieces
    final random = Random();
    for (int i = 0; i < 40; i++) {
      _confettiPieces.add(_ConfettiPiece(
        x: random.nextDouble(),
        speed: 0.5 + random.nextDouble() * 1.5,
        size: 4 + random.nextDouble() * 8,
        color: [
          Colors.orange,
          Colors.green,
          Colors.yellow,
          Colors.red,
          const Color(0xFF5D4037),
          Colors.amber,
        ][random.nextInt(6)],
        rotation: random.nextDouble() * 360,
      ));
    }

    _confettiController.forward();
    _bounceController.forward();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  String get _tokenNumber {
    final data = widget.tokenData;
    final token = data['token'];
    if (token is Map) {
      return token['tokenNumber']?.toString() ?? '';
    }
    return data['tokenNumber']?.toString() ?? '';
  }

  int get _position {
    return widget.tokenData['position'] ?? 0;
  }

  int get _estimatedWait {
    return widget.tokenData['estimatedWaitMinutes'] ?? 0;
  }

  String get _counterName {
    return widget.tokenData['counterName'] ??
        'Counter ${widget.tokenData['counterNumber'] ?? ''}';
  }

  String get _tokenId {
    final token = widget.tokenData['token'];
    if (token is Map) {
      return token['_id']?.toString() ?? '';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0EA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: AnimatedBuilder(
              animation: _bounceAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: 0.5 + 0.5 * _bounceAnimation.value,
                  child: Opacity(
                    opacity: _bounceAnimation.value.clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
              child: _buildCard(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Confetti Header ──
            _buildConfettiHeader(),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              child: Column(
                children: [
                  // ── Counter Badge ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _counterName,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── "Your Token is Confirmed" ──
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: GoogleFonts.inter(fontSize: 22),
                      children: [
                        TextSpan(
                          text: 'Your Token ',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF3E2723),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: 'is ',
                          style: GoogleFonts.inter(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextSpan(
                          text: 'Confirmed',
                          style: GoogleFonts.inter(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Token Number ──
                  Text(
                    'Token #${_tokenNumber.replaceAll('T-', '')}',
                    style: GoogleFonts.inter(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF3E2723),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Estimated Waiting Time ──
                  Text(
                    'Estimated Waiting Time',
                    style: GoogleFonts.inter(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Divider(color: Colors.grey[200], indent: 40, endIndent: 40),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$_estimatedWait',
                          style: GoogleFonts.inter(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF3E2723),
                          ),
                        ),
                        TextSpan(
                          text: ' Minutes',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF3E2723),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Queue Position ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F0EA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: Colors.grey[700],
                        ),
                        children: [
                          const TextSpan(text: 'You are '),
                          TextSpan(
                            text: '${_position}${_getOrdinalSuffix(_position)}',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF3E2723),
                            ),
                          ),
                          const TextSpan(text: ' in queue'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── View Live Status Button ──
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: widget.onViewLiveStatus,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        'View Live Status',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Cancel Token Button ──
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: widget.onCancelToken,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE65100),
                        side: const BorderSide(
                          color: Color(0xFFE65100),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Cancel Token',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfettiHeader() {
    return AnimatedBuilder(
      animation: _confettiController,
      builder: (context, _) {
        return SizedBox(
          height: 100,
          width: double.infinity,
          child: CustomPaint(
            painter: _ConfettiPainter(
              pieces: _confettiPieces,
              progress: _confettiController.value,
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF5D4037),
                    const Color(0xFF5D4037).withValues(alpha: 0.85),
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.greenAccent,
                  size: 36,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _getOrdinalSuffix(int number) {
    if (number >= 11 && number <= 13) return 'th';
    switch (number % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}

class _ConfettiPiece {
  final double x;
  final double speed;
  final double size;
  final Color color;
  final double rotation;

  _ConfettiPiece({
    required this.x,
    required this.speed,
    required this.size,
    required this.color,
    required this.rotation,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> pieces;
  final double progress;

  _ConfettiPainter({required this.pieces, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final piece in pieces) {
      final paint = Paint()..color = piece.color.withValues(alpha: 1.0 - progress);
      final dx = piece.x * size.width;
      final dy = progress * size.height * piece.speed;
      canvas.drawCircle(Offset(dx, dy), piece.size * (1 - progress * 0.3), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
