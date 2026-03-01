import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spotit/features/auth/data/services/auth_service.dart';
import 'package:spotit/features/home/presentation/pages/home_controller_page.dart';

// ─── Show Sign-Up Dialog ─────────────────────────────────────────────────────

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

// ─── Role Enum ───────────────────────────────────────────────────────────────

enum _SignUpRole { citizen, official }

// ─── Sign Up Dialog ──────────────────────────────────────────────────────────

class SignUpDialog extends StatefulWidget {
  const SignUpDialog({super.key});

  @override
  State<SignUpDialog> createState() => _SignUpDialogState();
}

class _SignUpDialogState extends State<SignUpDialog>
    with SingleTickerProviderStateMixin {
  static const Color _amber = Color(0xFFF9A825);
  static const Color _lightAmber = Color(0xFFFFF8E1);

  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _blurAnimation;
  late final Animation<Offset> _slideAnimation;

  _SignUpRole _selectedRole = _SignUpRole.citizen;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

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
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    if (mounted) Navigator.of(context).pop();
  }

  // ─── Citizen Google Sign-Up ────────────────────────────────

  Future<void> _handleGoogleSignUp() async {
    setState(() => _isLoading = true);
    try {
      final userCredential = await AuthService().signInWithGoogle();
      if (userCredential == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Google sign-up was cancelled or redirected. Please wait a moment and try again if needed.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pop(); // close dialog
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeControllerPage()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final message = e.message ?? 'Authentication failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google sign-up failed (${e.code}): $message'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign-up failed: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ─── Build ─────────────────────────────────────────────────

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
              child: SingleChildScrollView(
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
                    const SizedBox(height: 6),
                    Text(
                      'Select your role and sign up.',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Role Selector ──
                    _buildRoleSelector(),
                    const SizedBox(height: 20),

                    // ── Content based on selected role ──
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _selectedRole == _SignUpRole.citizen
                          ? _buildCitizenSignUp()
                          : _buildOfficialSignUp(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Role Selector ────────────────────────────────────────

  Widget _buildRoleSelector() {
    return Column(
      children: [
        Text(
          'I am a',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _roleCard(
                _SignUpRole.citizen,
                Icons.person_outline,
                'Citizen',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _roleCard(
                _SignUpRole.official,
                Icons.shield_outlined,
                'Official',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _roleCard(_SignUpRole role, IconData icon, String label) {
    final isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = role;
          _emailController.clear();
          _passwordController.clear();
          _confirmPasswordController.clear();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? _lightAmber : Colors.grey[100],
          border: Border.all(
            color: isSelected ? _amber : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: isSelected ? _amber : Colors.grey[500]),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? _amber : Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Citizen Sign-Up (Google) ─────────────────────────────

  Widget _buildCitizenSignUp() {
    return Column(
      key: const ValueKey('citizen-signup'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Sign up with your Google account.',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),

        // ── Google Sign-Up Button ──
        OutlinedButton(
          onPressed: _isLoading ? null : _handleGoogleSignUp,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            side: BorderSide(color: _amber.withValues(alpha: 0.45)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            backgroundColor: Colors.white.withValues(alpha: 0.5),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Row(
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
        const SizedBox(height: 12),

        // ── Terms ──
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              fontSize: 11.5,
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
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ─── Official Sign-Up (Email + Password) ──────────────

  // Official sign-up handler
  Future<void> _handleOfficialSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await AuthService().createOfficialAccount(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(); // close dialog
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeControllerPage()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign-up failed: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildOfficialSignUp() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('official-signup'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Info Banner ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _lightAmber,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFFFFD54F), width: 1.2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    size: 18, color: Color(0xFFF9A825)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Create an account using your official government email.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.orange[900],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Email Field ──
          _buildLabel('Government Email'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDecoration('official@dept.gov.lk'),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!v.contains('@')) return 'Enter a valid email';
              if (!v.trim().toLowerCase().endsWith('.gov.lk')) {
                return 'Must use a .gov.lk email';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // ── Password Field ──
          _buildLabel('Create Password'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: _inputDecoration('••••••••').copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 6) return 'At least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 14),

          // ── Confirm Password Field ──
          _buildLabel('Confirm Password'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            decoration: _inputDecoration('••••••••').copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Confirm your password';
              if (v != _passwordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 22),

          // ── Sign Up Button ──
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleOfficialSignUp,
              style: ElevatedButton.styleFrom(
                backgroundColor: _amber,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Create Account',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: Colors.black87,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400]),
      filled: true,
      fillColor: Colors.grey[100],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _amber, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        borderRadius: BorderRadius.circular(10),
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
