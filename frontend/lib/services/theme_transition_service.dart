import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart';

/// High-performance theme transition service.
///
/// Instead of animating the entire widget tree's colors (which causes severe lag
/// due to 60+ full rebuilds), this service:
/// 1. Instantly covers the screen with a solid color matching the OLD theme.
/// 2. Changes the theme underneath (triggers 1 single rebuild frame).
/// 3. Smoothly fades out the overlay to reveal the new theme.
///
/// This runs at a perfect 60 FPS because animating a single overlay's opacity
/// is extremely lightweight for the GPU.
class ThemeTransitionService {
  ThemeTransitionService._();

  static OverlayEntry? _overlayEntry;

  /// Call this from any theme-toggle button.
  static Future<void> animateToggle({
    required Offset origin,
    required bool toDark,
  }) async {
    if (_overlayEntry != null) return;

    final overlayState = navigatorKey.currentState?.overlay;
    if (overlayState == null) {
      themeNotifier.value = toDark ? ThemeMode.dark : ThemeMode.light;
      return;
    }

    // Opaque color of the OLD theme that we are fading OUT of
    final oldThemeBgColor = toDark
        ? const Color(0xFFF8FAFC) // light bg
        : const Color(0xFF0F0D1A); // dark bg

    final completer = Completer<void>();

    _overlayEntry = OverlayEntry(
      builder: (_) => _ThemeFadeOverlay(
        color: oldThemeBgColor,
        onComplete: () {
          _overlayEntry?.remove();
          _overlayEntry?.dispose();
          _overlayEntry = null;
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );

    overlayState.insert(_overlayEntry!);

    // Wait for the overlay to be laid out and rendered as fully opaque,
    // then trigger the theme change on the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      themeNotifier.value = toDark ? ThemeMode.dark : ThemeMode.light;
    });

    await completer.future;
  }
}

class _ThemeFadeOverlay extends StatefulWidget {
  final Color color;
  final VoidCallback onComplete;

  const _ThemeFadeOverlay({
    required this.color,
    required this.onComplete,
  });

  @override
  State<_ThemeFadeOverlay> createState() => _ThemeFadeOverlayState();
}

class _ThemeFadeOverlayState extends State<_ThemeFadeOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    // Fade out the old theme screen overlay to reveal the new theme
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    // Start fading out
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: SizedBox.expand(
          child: ColoredBox(color: widget.color),
        ),
      ),
    );
  }
}
