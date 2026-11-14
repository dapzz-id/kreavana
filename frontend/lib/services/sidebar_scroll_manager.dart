import 'package:flutter/widgets.dart';

/// Manages and persists sidebar scroll positions across navigation and screen transitions.
class SidebarScrollManager {
  SidebarScrollManager._();

  static double _savedOffset = 0.0;

  /// Current saved offset in pixels.
  static double get savedOffset => _savedOffset;

  /// Update saved offset.
  static set savedOffset(double value) {
    if (value >= 0.0) {
      _savedOffset = value;
    }
  }

  /// Reset saved offset (e.g. on logout).
  static void reset() {
    _savedOffset = 0.0;
  }

  /// Create a ScrollController pre-initialized to savedOffset.
  static ScrollController createController() {
    return ScrollController(
      initialScrollOffset: _savedOffset,
      keepScrollOffset: true,
    );
  }

  /// Safely restore scroll position across layout passes.
  static void restoreScroll(ScrollController controller) {
    if (_savedOffset <= 0.0) return;

    void tryJump() {
      if (!controller.hasClients) return;
      final target = _savedOffset;
      if (target <= 0.0) return;
      try {
        final pos = controller.position;
        final max = pos.maxScrollExtent;
        final clamped = (max > 0 && target > max) ? max : target;
        if ((pos.pixels - clamped).abs() > 1.0) {
          controller.jumpTo(clamped);
        }
      } catch (_) {}
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      tryJump();
      Future.delayed(const Duration(milliseconds: 40), tryJump);
      Future.delayed(const Duration(milliseconds: 120), tryJump);
      Future.delayed(const Duration(milliseconds: 300), tryJump);
    });
  }
}
