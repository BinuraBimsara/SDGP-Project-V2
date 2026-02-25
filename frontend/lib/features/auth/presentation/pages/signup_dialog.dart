import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:spotit/features/auth/data/services/auth_service.dart';
import 'package:spotit/features/home/presentation/pages/home_controller_page.dart';

// ─── Animated Blur Route ─────────────────────────────────────────────────────

/// Shows the [SignUpDialog] with a blurred backdrop that fades in,
/// and the dialog card itself scales + fades in (pop-up effect).
Future<void> showSignUpDialog(BuildContext context) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const SignUpDialog();
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return child; // Animations handled inside the widget itself.
      },
    ),
  );
}

// ─── Sign Up Dialog ──────────────────────────────────────────────────────────

class SignUpDialog extends StatefulWidget {
  const SignUpDialog({super.key});

  @override
  State<SignUpDialog> createState() => _SignUpDialogState();
}

class _SignUpDialogState extends State<SignUpDialog>
    with SingleTickerProviderStateMixin {
  static const Color _green = Color(0xFF2EAA5E);

  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _blurAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _blurAnimation = Tween<double>(begin: 0, end: 18).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 1.0, curve: Curves.elasticOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    if (mounted) Navigator.of(context).pop();
  }

  void _handleGoogleSignUp(BuildContext context) async {
    try {
      final userCredential = await AuthService().signInWithGoogle();
      if (userCredential == null) return; // cancelled
      if (!context.mounted) return;
      Navigator.of(context).pop(); // close dialog
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeControllerPage()),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign-up failed: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            // ── Blurred + tinted backdrop ──
            GestureDetector(
              onTap: _dismiss,
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: _blurAnimation.value,
                  sigmaY: _blurAnimation.value,
                ),
                child: Container(
                  color: Colors.black
                      .withValues(alpha: 0.25 * _fadeAnimation.value),
                ),
              ),
            ),

            // ── Dialog card (scale + slide + fade) ──
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: _buildCard(context),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Material(
        type: MaterialType.transparency,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 40,
                    spreadRadius: 4,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header Row ──
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Create Account',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            fontSize: 20,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _dismiss,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.black45, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ── Subtitle ──
                  Text(
                    'Sign up with your Google account to get started.',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 26),

                  // ── Google Sign-Up Button ──
                  OutlinedButton(
                    onPressed: () => _handleGoogleSignUp(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      side: BorderSide(color: _green.withValues(alpha: 0.45)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.5),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _GoogleLogoSmall(size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Continue with Google',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Google Logo (small) ─────────────────────────────────────────────────────

class _GoogleLogoSmall extends StatelessWidget {
  final double size;
  const _GoogleLogoSmall({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainterSmall()),
    );
  }
}

class _GoogleLogoPainterSmall extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;
    final double sw = size.width * 0.18;

    Paint p(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.butt;

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.75);

    canvas.drawArc(rect, -1.1, 2.25, false, p(const Color(0xFF4285F4)));
    canvas.drawArc(rect, 1.15, 1.65, false, p(const Color(0xFFFBBC05)));
    canvas.drawArc(rect, 2.8, 1.65, false, p(const Color(0xFF34A853)));
    canvas.drawArc(rect, -2.75, 1.65, false, p(const Color(0xFFEA4335)));

    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + r * 0.75, cy),
      Paint()
        ..color = const Color(0xFF4285F4)
        ..strokeWidth = sw,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
