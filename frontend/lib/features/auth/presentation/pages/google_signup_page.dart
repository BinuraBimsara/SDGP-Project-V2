import 'package:flutter/material.dart';
import 'package:spotit/features/auth/data/services/auth_service.dart';
import 'package:spotit/features/home/presentation/pages/home_controller_page.dart';

/// Full-screen Google Sign Up page.
///
/// Shows the SpotIT LK branding with a golden gradient top area and a white
/// card at the bottom containing the "Continue with Google" button.
class GoogleSignupPage extends StatefulWidget {
  const GoogleSignupPage({super.key});

  @override
  State<GoogleSignupPage> createState() => _GoogleSignupPageState();
}

class _GoogleSignupPageState extends State<GoogleSignupPage> {
  // ─── Colors ──────────────────────────────────────────────
  static const Color _amberDark = Color(0xFFF8B500);
  static const Color _amberLight = Color(0xFFFCEABB);

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.55, 0.55, 1.0],
            colors: [
              _amberLight,
              _amberDark,
              Colors.white,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              // ── Golden Header ──
              _buildGoldenHeader(),
              const SizedBox(height: 20),
              // ── Decorative Icons ──
              _buildDecorativeIcons(),
              const Spacer(),
              // ── White Card ──
              _buildSignUpCard(context),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Golden Header ───────────────────────────────────────

  Widget _buildGoldenHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          // Brand icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _amberDark.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_on,
              size: 28,
              color: Colors.orange.shade800,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'SpotIT LK',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Google Sign Up for\na Secure Account.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black.withValues(alpha: 0.7),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Decorative Icons ────────────────────────────────────

  Widget _buildDecorativeIcons() {
    return SizedBox(
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Cloud shape (left)
          Positioned(
            left: 40,
            child: Icon(
              Icons.cloud,
              size: 50,
              color: _amberDark.withValues(alpha: 0.6),
            ),
          ),
          // Cloud shape (right)
          Positioned(
            right: 40,
            child: Icon(
              Icons.cloud,
              size: 40,
              color: _amberDark.withValues(alpha: 0.5),
            ),
          ),
          // Gear icon (center-right)
          Positioned(
            right: 70,
            top: 5,
            child: Icon(
              Icons.settings,
              size: 28,
              color: _amberDark.withValues(alpha: 0.7),
            ),
          ),
          // Small gear (left)
          Positioned(
            left: 85,
            top: 0,
            child: Icon(
              Icons.settings,
              size: 20,
              color: _amberDark.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sign Up Card ────────────────────────────────────────

  Widget _buildSignUpCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Title ──
          const Text(
            'Google Sign Up\nfor a Secure Account',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 24),

          // ── Continue with Google Button ──
          _buildGoogleButton(),
          const SizedBox(height: 16),

          // ── Terms Text ──
          _buildTermsText(),
          const SizedBox(height: 24),

          // ── Sign In Link ──
          _buildSignInLink(context),
        ],
      ),
    );
  }

  // ─── Google Button ───────────────────────────────────────

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _handleGoogleSignUp,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          backgroundColor: Colors.white,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CustomPaint(painter: _GoogleLogoPainter()),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ─── Terms Text ──────────────────────────────────────────

  Widget _buildTermsText() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
          height: 1.5,
        ),
        children: const [
          TextSpan(text: 'By signing up, you agree to our '),
          TextSpan(
            text: 'Terms of Service',
            style: TextStyle(
              color: Colors.blueAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: TextStyle(
              color: Colors.blueAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sign In Link ────────────────────────────────────────

  Widget _buildSignInLink(BuildContext context) {
    return Column(
      children: [
        Text(
          'For an existing account?',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Text(
            'Sign In',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Google Sign Up Action ───────────────────────────────

  Future<void> _handleGoogleSignUp() async {
    setState(() => _isLoading = true);
    try {
      final userCredential = await AuthService().signInWithGoogle();
      if (userCredential == null) {
        // User cancelled
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pop(); // close this page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeControllerPage()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign-up failed: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ─── Google Logo Painter ─────────────────────────────────────────────────────

class _GoogleLogoPainter extends CustomPainter {
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
