import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:spotit/main.dart';

/// Wraps the app in a [RepaintBoundary] and provides a static
/// [switchTheme] method that performs a Telegram-style circular reveal
/// animation for a smooth theme transition.
class ThemeSwitcher extends StatefulWidget {
  final Widget child;
  const ThemeSwitcher({super.key, required this.child});

  /// Global key used to find the [ThemeSwitcherState] from anywhere.
  static final GlobalKey<ThemeSwitcherState> instanceKey =
      GlobalKey<ThemeSwitcherState>();

  /// Call this from anywhere to toggle the theme with a circular reveal
  /// animation originating from [tapPosition].
  static Future<void> switchTheme(
      BuildContext context, Offset tapPosition) async {
    final state = instanceKey.currentState;
    if (state == null) return;
    await state._performSwitch(tapPosition);
  }

  @override
  State<ThemeSwitcher> createState() => ThemeSwitcherState();
}

class ThemeSwitcherState extends State<ThemeSwitcher>
    with SingleTickerProviderStateMixin {
  final GlobalKey _boundaryKey = GlobalKey();

  OverlayEntry? _overlayEntry;
  late AnimationController _controller;
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _controller.dispose();
    super.dispose();
  }

  /// Calculate the maximum radius needed to cover the entire screen
  /// from the given [center] point.
  double _calcMaxRadius(Size size, Offset center) {
    final corners = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];
    return corners.map((c) => (c - center).distance).reduce(max);
  }

  Future<void> _performSwitch(Offset tapPosition) async {
    if (_switching) return; // guard against rapid taps during animation
    _switching = true;

    try {
      // 1. Capture the current frame as an image.
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        _switching = false;
        return;
      }

      final pixelRatio = MediaQuery.of(context).devicePixelRatio;
      final image = await boundary.toImage(pixelRatio: pixelRatio);

      // 2. Toggle the theme.
      final isDark = SpotItApp.themeNotifier.value == ThemeMode.dark;
      SpotItApp.themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;

      // 3. Calculate the max radius for the circular reveal.
      final screenSize = MediaQuery.of(context).size;
      final maxRadius = _calcMaxRadius(screenSize, tapPosition);

      _controller.value = 0.0;

      // 4. Show old-theme screenshot with a growing circular hole.
      _overlayEntry = OverlayEntry(
        builder: (_) => AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return ClipPath(
              clipper: _CircularRevealClipper(
                center: tapPosition,
                radius: maxRadius * _controller.value,
              ),
              child: child,
            );
          },
          child: SizedBox.expand(
            child: IgnorePointer(
              child: RawImage(
                image: image,
                fit: BoxFit.cover,
                width: boundary.size.width,
                height: boundary.size.height,
              ),
            ),
          ),
        ),
      );

      // Insert after the current frame so the new theme is already painted.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final overlay = Overlay.of(context, rootOverlay: true);
        overlay.insert(_overlayEntry!);

        // 5. Animate the circular reveal from 0 → maxRadius.
        await _controller.animateTo(1.0, curve: Curves.easeInOut);

        _overlayEntry?.remove();
        _overlayEntry = null;
        image.dispose();
        _switching = false;
      });
    } catch (_) {
      // If anything goes wrong, just toggle without animation.
      _switching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _boundaryKey,
      child: widget.child,
    );
  }
}

/// Custom clipper that creates a full-screen rectangle with a circular
/// hole cut out. As [radius] grows, more of the old screenshot is removed,
/// revealing the new theme underneath — a Telegram-style circular reveal.
class _CircularRevealClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;

  _CircularRevealClipper({
    required this.center,
    required this.radius,
  });

  @override
  Path getClip(Size size) {
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;
    return path;
  }

  @override
  bool shouldReclip(_CircularRevealClipper oldClipper) {
    return oldClipper.radius != radius || oldClipper.center != center;
  }
}
