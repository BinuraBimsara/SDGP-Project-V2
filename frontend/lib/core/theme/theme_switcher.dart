import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:spotit/main.dart';

/// Wraps the app in a [RepaintBoundary] + [Stack] and provides a static
/// [switchTheme] method that performs a Telegram-style circular reveal
/// animation for a smooth theme transition.
///
/// Uses a Stack-based overlay (not [Overlay]) so the screenshot layer
/// lives in ThemeSwitcher's own widget tree and survives MaterialApp rebuilds.
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
  late AnimationController _controller;

  bool _switching = false;
  ui.Image? _screenshot;
  Offset _tapPosition = Offset.zero;
  bool _goingToDark = false;
  Size _boundarySize = Size.zero;

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
    _controller.dispose();
    _screenshot?.dispose();
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

      // 2. Determine direction before toggling.
      final isDark = SpotItApp.themeNotifier.value == ThemeMode.dark;

      // 3. Place the screenshot on top via setState (Stack-based overlay).
      setState(() {
        _screenshot = image;
        _tapPosition = tapPosition;
        _goingToDark = !isDark;
        _boundarySize = boundary.size;
      });

      // 4. Toggle the theme underneath.
      SpotItApp.themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;

      // 5. Reset animation.
      _controller.value = 0.0;

      // 6. Wait one frame so the new theme paints under the screenshot.
      final completer = Completer<void>();
      WidgetsBinding.instance
          .addPostFrameCallback((_) => completer.complete());
      await completer.future;

      // 7. Animate the circular reveal.
      //    Forward  (→ dark):  old light screenshot has a GROWING hole
      //                        → dark theme expands outward from icon.
      //    Backward (→ light): old dark screenshot clipped to a SHRINKING circle
      //                        → dark collapses toward the icon, light revealed.
      await _controller.animateTo(1.0, curve: Curves.easeInOut);

      // 8. Clean up — remove screenshot after animation.
      _cleanUpScreenshot();
      _switching = false;
    } catch (_) {
      // If anything goes wrong, just toggle without animation.
      _cleanUpScreenshot();
      _switching = false;
    }
  }

  void _cleanUpScreenshot() {
    final oldImage = _screenshot;
    setState(() {
      _screenshot = null;
    });
    // Dispose native image after the widget tree no longer references it.
    if (oldImage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldImage.dispose();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Bottom layer: actual app content (new theme after toggle).
        RepaintBoundary(
          key: _boundaryKey,
          child: widget.child,
        ),
        // Top layer: old-theme screenshot being clipped away.
        if (_screenshot != null)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final maxRadius =
                    _calcMaxRadius(_boundarySize, _tapPosition);
                final progress = _controller.value;
                return ClipPath(
                  clipper: _goingToDark
                      ? _CircularRevealClipper(
                          center: _tapPosition,
                          radius: maxRadius * progress,
                          reverse: false,
                        )
                      : _CircularRevealClipper(
                          center: _tapPosition,
                          radius: maxRadius * (1.0 - progress),
                          reverse: true,
                        ),
                  child: child,
                );
              },
              child: IgnorePointer(
                child: RawImage(
                  image: _screenshot,
                  fit: BoxFit.cover,
                  width: _boundarySize.width,
                  height: _boundarySize.height,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Custom clipper for the circular reveal animation.
///
/// [reverse] == false (forward / going to dark):
///   Full-screen rect with a circular hole — hole grows, revealing the new theme.
///
/// [reverse] == true (backward / going to light):
///   Just a circle clip — circle shrinks, collapsing the old dark screenshot
///   toward the icon and revealing the light theme from the edges.
class _CircularRevealClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;
  final bool reverse;

  _CircularRevealClipper({
    required this.center,
    required this.radius,
    required this.reverse,
  });

  @override
  Path getClip(Size size) {
    if (reverse) {
      // Backward: old screenshot visible only inside the shrinking circle.
      return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    } else {
      // Forward: old screenshot visible everywhere EXCEPT the growing hole.
      return Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
        ..addOval(Rect.fromCircle(center: center, radius: radius))
        ..fillType = PathFillType.evenOdd;
    }
  }

  @override
  bool shouldReclip(_CircularRevealClipper oldClipper) {
    return oldClipper.radius != radius || oldClipper.center != center;
  }
}
