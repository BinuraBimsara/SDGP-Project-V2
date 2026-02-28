import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:spotit/main.dart';

/// Wraps the app in a [RepaintBoundary] and provides a static
/// [switchTheme] method that cross-fades the old theme screenshot
/// over the new theme for a silky-smooth transition.
class ThemeSwitcher extends StatefulWidget {
  final Widget child;
  const ThemeSwitcher({super.key, required this.child});

  /// Global key used to find the [ThemeSwitcherState] from anywhere.
  static final GlobalKey<ThemeSwitcherState> instanceKey =
      GlobalKey<ThemeSwitcherState>();

  /// Call this from anywhere to smoothly toggle the theme.
  static Future<void> switchTheme(BuildContext context) async {
    final state = instanceKey.currentState;
    if (state == null) return;
    await state._performSwitch();
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
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _controller.dispose();
    super.dispose();
  }

  Future<void> _performSwitch() async {
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

      // 3. Show the old-theme screenshot as an overlay and fade it out.
      _controller.value = 1.0; // start fully visible

      _overlayEntry = OverlayEntry(
        builder: (_) => AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Opacity(
            opacity: _controller.value,
            child: child,
          ),
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

        // 4. Animate opacity from 1 → 0.
        await _controller.animateTo(
          0.0,
          curve: Curves.easeInOut,
        );

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
