import 'package:flutter/material.dart';

/// Central place for animation curves and durations used across the app.
class AppMotion {
  AppMotion._();

  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeInOut = Curves.easeInOutCubic;
  static const Curve spring = Curves.easeOutBack;

  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 450);

  /// Smooth fade + slight slide-up page transition used globally.
  static Widget buildPageTransition({
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
  }) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: easeOut,
      reverseCurve: Curves.easeIn,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.05, 0.03),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }

  /// Pure fade transition (used for dialogs / secondary routes).
  static Widget buildFadeTransition(
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: easeInOut);
    return FadeTransition(opacity: curved, child: child);
  }

  /// Registers the custom page transitions for all platforms.
  static PageTransitionsTheme pageTransitionsTheme() {
    return const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _KreavanaPageTransitionsBuilder(),
        TargetPlatform.iOS: _KreavanaPageTransitionsBuilder(),
        TargetPlatform.windows: _KreavanaPageTransitionsBuilder(),
        TargetPlatform.macOS: _KreavanaPageTransitionsBuilder(),
        TargetPlatform.linux: _KreavanaPageTransitionsBuilder(),
      },
    );
  }
}

class _KreavanaPageTransitionsBuilder extends PageTransitionsBuilder {
  const _KreavanaPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.settings.name == 'no_animation') return child;
    return AppMotion.buildPageTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

/// Fades and slides a widget in the first time it appears.
/// Use [delay] to stagger a list of children.
class AnimatedEntrance extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset offset;
  final Curve curve;

  const AnimatedEntrance({
    super.key,
    required this.child,
    this.duration = AppMotion.normal,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 0.06),
    this.curve = AppMotion.easeOut,
  });

  @override
  State<AnimatedEntrance> createState() => _AnimatedEntranceState();
}

class _AnimatedEntranceState extends State<AnimatedEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curved = CurvedAnimation(parent: _controller, curve: widget.curve);
    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _slide = Tween<Offset>(begin: widget.offset, end: Offset.zero).animate(curved);
    if (widget.delay > Duration.zero) {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Renders a column of children with staggered entrance animations.
class EntranceList extends StatelessWidget {
  final List<Widget> children;
  final Duration stepDelay;
  final Duration baseDuration;

  const EntranceList({
    super.key,
    required this.children,
    this.stepDelay = const Duration(milliseconds: 70),
    this.baseDuration = AppMotion.normal,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++)
          AnimatedEntrance(
            duration: baseDuration,
            delay: Duration(milliseconds: stepDelay.inMilliseconds * i),
            child: children[i],
          ),
      ],
    );
  }
}

/// Wraps any widget with a springy scale feedback on press.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final BorderRadius borderRadius;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.97,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: AppMotion.fast,
        curve: AppMotion.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Desktop-friendly hover: gently raises the card and adds a soft glow.
class HoverRaise extends StatefulWidget {
  final Widget child;
  final double raisedScale;
  final double riseOffset;
  final BorderRadius? borderRadius;
  final Color? glowColor;

  const HoverRaise({
    super.key,
    required this.child,
    this.raisedScale = 1.02,
    this.riseOffset = -3.0,
    this.borderRadius,
    this.glowColor,
  });

  @override
  State<HoverRaise> createState() => _HoverRaiseState();
}

class _HoverRaiseState extends State<HoverRaise> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final radius =
        widget.borderRadius ?? const BorderRadius.all(Radius.circular(14));
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.easeOut,
        transform: Matrix4(
          _hovered ? widget.raisedScale : 1.0,
          0,
          0,
          0,
          0,
          _hovered ? widget.raisedScale : 1.0,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          _hovered ? widget.riseOffset : 0.0,
          0,
          1,
        ),
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: (widget.glowColor ??
                            Theme.of(context).colorScheme.primary)
                        .withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}
