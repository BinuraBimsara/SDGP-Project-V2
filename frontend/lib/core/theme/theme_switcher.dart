import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotit/main.dart';

// ThemeSwitcher wraps the entire app in a RepaintBoundary + Stack.
// When the user taps the dark/light mode button, it:
//   1. Takes a screenshot of the current screen
//   2. Toggles the theme underneath (so the new theme renders invisibly)
//   3. Plays an animated circular "reveal" that peels the screenshot away,
//      revealing the new theme behind it — exactly like the Telegram app does.
//
// A Stack-based overlay is used instead of Flutter's Overlay widget because
// the screenshot layer must survive MaterialApp rebuilds when the theme changes.
class ThemeSwitcher extends StatefulWidget {
  final Widget child; // the whole app
  const ThemeSwitcher({super.key, required this.child});

  // GlobalKey lets any widget in the tree call ThemeSwitcher.instanceKey.currentState
  // to trigger the animation from anywhere. It's set once and shared globally.
  static final GlobalKey<ThemeSwitcherState> instanceKey =
      GlobalKey<ThemeSwitcherState>();

  // Call this static method from any widget to trigger the circular reveal animation.
  // tapPosition is the screen coordinate where the reveal circle expands from.
  static Future<void> switchTheme(
      BuildContext context, Offset tapPosition) async {
    final state = instanceKey.currentState;
    if (state == null) return; // widget not yet mounted
    await state._performSwitch(tapPosition);
  }

  @override
  State<ThemeSwitcher> createState() => ThemeSwitcherState();
}

class ThemeSwitcherState extends State<ThemeSwitcher>
    with SingleTickerProviderStateMixin { // needed for AnimationController

  final GlobalKey _boundaryKey = GlobalKey(); // key to access the RepaintBoundary
  late AnimationController _controller;

  bool _switching = false;       // prevents double-triggering if user taps twice
  ui.Image? _screenshot;         // the captured frame before the theme changes
  Offset _tapPosition = Offset.zero; // where the animation circle expands from
  bool _goingToDark = false;     // true = switching to dark, false = switching to light
  Size _boundarySize = Size.zero; // actual pixel size of the screen

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), // total animation time
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _screenshot?.dispose(); // release the native image memory
    super.dispose();
  }

  // Calculates the maximum circle radius needed to completely cover the screen
  // starting from a given center point.
  // We measure from the center to each corner and take the longest distance.
  double _calcMaxRadius(Size size, Offset center) {
    final corners = [
      Offset.zero,                       // top-left
      Offset(size.width, 0),             // top-right
      Offset(0, size.height),            // bottom-left
      Offset(size.width, size.height),   // bottom-right
    ];
    return corners.map((c) => (c - center).distance).reduce(max);
  }

  Future<void> _performSwitch(Offset tapPosition) async {
    if (_switching) return; // don't start if already animating
    _switching = true;

    try {
      // Step 1: Capture the current frame as a raw image.
      // RepaintBoundary.toImage() renders the widget to a bitmap in memory.
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        _switching = false;
        return;
      }

      final pixelRatio = MediaQuery.of(context).devicePixelRatio; // account for high-DPI screens
      final image = await boundary.toImage(pixelRatio: pixelRatio);

      // Step 2: Figure out which direction we're switching BEFORE toggling.
      final isDark = SpotItApp.themeNotifier.value == ThemeMode.dark;

      // Step 3: Put the screenshot on top of the screen via setState.
      // The Stack now shows: [new theme (not painted yet)] underneath [old screenshot on top]
      setState(() {
        _screenshot = image;
        _tapPosition = tapPosition;
        _goingToDark = !isDark; // remember direction for the clipper
        _boundarySize = boundary.size;
      });

      // Step 4: Toggle the theme underneath the screenshot.
      // The app rebuilds with the new theme but the screenshot hides it.
      final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
      SpotItApp.themeNotifier.value = newMode;

      // Also save the choice to disk so it persists across app restarts
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setString(
          'themeMode',
          newMode == ThemeMode.dark ? 'dark' : 'light',
        ),
      );

      _controller.value = 0.0; // reset to the beginning

      // Step 5: Wait one frame so Flutter has time to paint the new theme
      // underneath the screenshot before we start animating.
      final completer = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
      await completer.future;

      // Step 6: Animate the circular reveal.
      // Going to DARK: the old light screenshot has a growing hole punched in it
      //   → dark theme expands outward from the icon tap point.
      // Going to LIGHT: the old dark screenshot is clipped to a shrinking circle
      //   → dark collapses toward the icon, revealing light from the outer edges.
      await _controller.animateTo(1.0, curve: Curves.easeInOut);

      // Step 7: Clean up — remove the screenshot overlay after animation completes
      _cleanUpScreenshot();
      _switching = false;

    } catch (_) {
      // If anything fails (e.g. image capture fails), just remove the screenshot
      // and move on. The theme was already toggled so it won't get stuck.
      _cleanUpScreenshot();
      _switching = false;
    }
  }

  void _cleanUpScreenshot() {
    final oldImage = _screenshot;
    setState(() {
      _screenshot = null; // removes the overlay from the Stack
    });
    // Dispose the native image AFTER the widget tree stops using it.
    // Disposing immediately would cause a crash if the frame is still rendering.
    if (oldImage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldImage.dispose(); // free the GPU/CPU memory
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Bottom layer: the real app (with the new theme after toggle)
        RepaintBoundary(
          key: _boundaryKey, // needed to call toImage() on this widget
          child: widget.child,
        ),
        // Top layer: old-theme screenshot being revealed/hidden by the animation.
        // Only present during the animation — removed after completion.
        if (_screenshot != null)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final maxRadius = _calcMaxRadius(_boundarySize, _tapPosition);
                final progress = _controller.value; // 0.0 → 1.0 as animation runs

                return ClipPath(
                  // The clipper determines the visible shape of the screenshot
                  clipper: _goingToDark
                      ? _CircularRevealClipper(
                          center: _tapPosition,
                          radius: maxRadius * progress, // growing hole (going to dark)
                          reverse: false,
                        )
                      : _CircularRevealClipper(
                          center: _tapPosition,
                          radius: maxRadius * (1.0 - progress), // shrinking circle (going to light)
                          reverse: true,
                        ),
                  child: child,
                );
              },
              child: IgnorePointer(
                // IgnorePointer prevents the screenshot from blocking touch events
                child: RawImage(
                  image: _screenshot, // render the captured bitmap
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

// Custom clipper that cuts the screenshot into a circle shape.
// It handles two modes:
//   reverse == false (going to dark):
//     Full screen rect WITH a circular hole — hole grows, revealing dark theme.
//   reverse == true (going to light):
//     Just a circle — circle shrinks, collapsing the dark screenshot toward the tap point.
class _CircularRevealClipper extends CustomClipper<Path> {
  final Offset center; // origin of the circle (where the user tapped)
  final double radius; // current radius (changes each animation frame)
  final bool reverse;  // true = clip to a circle; false = clip to a hole

  _CircularRevealClipper({
    required this.center,
    required this.radius,
    required this.reverse,
  });

  @override
  Path getClip(Size size) {
    if (reverse) {
      // Going to light: old dark screenshot visible only inside the shrinking circle
      return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    } else {
      // Going to dark: old light screenshot visible everywhere EXCEPT the growing hole.
      // evenOdd fill rule makes the circle an "empty" punch through the rectangle.
      return Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height)) // full screen
        ..addOval(Rect.fromCircle(center: center, radius: radius)) // the hole
        ..fillType = PathFillType.evenOdd; // overlapping areas become transparent
    }
  }

  @override
  bool shouldReclip(_CircularRevealClipper oldClipper) {
    // Re-clip only when the radius or center actually changed (every animation frame)
    return oldClipper.radius != radius || oldClipper.center != center;
  }
}
