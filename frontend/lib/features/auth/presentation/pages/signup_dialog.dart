import 'package:flutter/material.dart';
import 'package:spotit/features/home/presentation/pages/home_controller_page.dart';

class SignUpDialog extends StatelessWidget {
  const SignUpDialog({super.key});

  static const Color _green = Color(0xFF2EAA5E);

  void _handleGoogleSignUp(BuildContext context) {
    Navigator.of(context).pop(); // close dialog
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeControllerPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
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
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Subtitle ──
            Text(
              'Sign up with your Google account to get started.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // ── Google Sign-Up Button ──
            OutlinedButton(
              onPressed: () => _handleGoogleSignUp(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: _green.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GoogleLogoSmall(size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 14,
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
