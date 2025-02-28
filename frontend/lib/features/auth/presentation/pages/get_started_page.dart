import 'package:flutter/material.dart';
import 'package:spotit/features/auth/presentation/pages/login_page.dart';

/// Get Started / onboarding page shown when the user first opens the app
/// (if not already authenticated).
///
/// Displays the SpotIT LK brand, a hero illustration area, motivational copy
/// and a "Get started" CTA that navigates to the Login page.
class GetStartedPage extends StatelessWidget {
  const GetStartedPage({super.key});

  // ─── Colors ──────────────────────────────────────────────
  static const Color _amberDark = Color(0xFFF8B500);
  static const Color _amberLight = Color(0xFFFCEABB);
  static const Color _buttonAmber = Color(0xFFF9A825);

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
            colors: [_amberLight, _amberDark],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 32),
              // ── Header ──
              _buildHeader(),
              const SizedBox(height: 24),
              // ── Hero Illustration ──
              _buildHeroIllustration(),
              const Spacer(),
              // ── Motivational Text ──
              _buildMotivationalText(),
              const SizedBox(height: 28),
              // ── Footer / CTA ──
              _buildFooter(context),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────

  Widget _buildHeader() {
    return const Column(
      children: [
        Text(
          'SpotIT LK',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Report, Track, Solve',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  // ─── Hero Illustration ───────────────────────────────────

  Widget _buildHeroIllustration() {
    return SizedBox(
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background decorative circle
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _amberDark.withValues(alpha: 0.25),
            ),
          ),

          // Map / monitor illustration (central)
          Positioned(
            top: 30,
            child: Container(
              width: 160,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _buttonAmber.withValues(alpha: 0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Map grid lines
                  Positioned.fill(
                    child: CustomPaint(painter: _MapGridPainter()),
                  ),
                  // Location pin overlay
                  const Positioned(
                    top: 25,
                    left: 55,
                    child: Icon(
                      Icons.location_on,
                      color: Color(0xFFE65100),
                      size: 30,
                    ),
                  ),
                  const Positioned(
                    top: 50,
                    right: 30,
                    child: Icon(
                      Icons.location_on,
                      color: Color(0xFFF9A825),
                      size: 22,
                    ),
                  ),
                  const Positioned(
                    bottom: 20,
                    left: 30,
                    child: Icon(
                      Icons.location_on,
                      color: Color(0xFFF9A825),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating gear icon (top-right)
          Positioned(
            top: 10,
            right: 40,
            child: Icon(
              Icons.settings,
              size: 32,
              color: _buttonAmber.withValues(alpha: 0.7),
            ),
          ),

          // Floating gear icon (top-left, smaller)
          Positioned(
            top: 0,
            left: 60,
            child: Icon(
              Icons.settings,
              size: 22,
              color: _buttonAmber.withValues(alpha: 0.5),
            ),
          ),

          // Location pin (floating, left)
          const Positioned(
            top: 35,
            left: 30,
            child: Icon(
              Icons.location_on,
              size: 26,
              color: Color(0xFFF9A825),
            ),
          ),

          // Location pin (floating, right)
          const Positioned(
            top: 55,
            right: 25,
            child: Icon(
              Icons.location_on,
              size: 22,
              color: Color(0xFFE65100),
            ),
          ),

          // People silhouettes (bottom)
          Positioned(
            bottom: 10,
            left: 30,
            child: Row(
              children: [
                _buildPersonIcon(Icons.person, 36, Colors.black54),
                const SizedBox(width: 6),
                _buildPersonIcon(Icons.person, 32, Colors.black45),
              ],
            ),
          ),

          Positioned(
            bottom: 10,
            right: 30,
            child: Row(
              children: [
                _buildPersonIcon(Icons.local_police, 32, Colors.brown),
                const SizedBox(width: 6),
                _buildPersonIcon(Icons.local_police, 36, Colors.brown.shade700),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonIcon(IconData icon, double size, Color color) {
    return Icon(icon, size: size, color: color);
  }

  // ─── Motivational Text ───────────────────────────────────

  Widget _buildMotivationalText() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Text(
            'SpotIT LK - Be a change maker',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Let's Get You Set Up\nfor Success",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Report your problem and help the government\nto build a better country',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.black.withValues(alpha: 0.55),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Footer with CTA ────────────────────────────────────

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LoginPage(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _buttonAmber,
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: _buttonAmber.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Get started',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Map Grid Painter ────────────────────────────────────────────────────────

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF9A825).withValues(alpha: 0.2)
      ..strokeWidth = 1;

    // Horizontal lines
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Vertical lines
    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // A diagonal "road" line
    final roadPaint = Paint()
      ..color = const Color(0xFFF9A825).withValues(alpha: 0.35)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, size.height * 0.7),
      Offset(size.width, size.height * 0.2),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.3, size.height),
      Offset(size.width * 0.8, 0),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
