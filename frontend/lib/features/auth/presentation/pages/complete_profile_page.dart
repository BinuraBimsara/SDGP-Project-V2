import 'package:flutter/material.dart';
import 'package:spotit/features/home/presentation/pages/home_controller_page.dart';

/// Mandatory profile completion page shown after first Google sign-in.
///
/// Collects: profile picture (optional), first name, last name, phone number.
/// No email field (already available from Google account).
/// No skip option — profile setup is mandatory.
class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  // ─── Theme Colors (Yellow/Amber) ──────────────────────────
  static const Color _amber = Color(0xFFF9A825);
  static const Color _darkBg = Color(0xFF1A1A10);

  // ─── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Title ──
              const Text(
                'Complete Profile',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 36),

              // Placeholder — image picker, form fields, and submit button
              // will be added in subsequent commits.

              const SizedBox(height: 40),

              // ── Temporary nav to home (will be replaced) ──
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const HomeControllerPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _amber,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Finish Setup',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
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
