import 'package:flutter/material.dart';

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
              const Spacer(),
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

  // ─── Footer with CTA ────────────────────────────────────

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // "Get started" button — placeholder onPressed for now
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                // Navigation will be wired in a later commit
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
