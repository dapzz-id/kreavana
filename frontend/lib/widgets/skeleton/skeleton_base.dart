import 'package:flutter/material.dart';

/// A lightweight animator that pulses opacity. 
/// Designed to wrap multiple skeletons or an entire skeleton layout
/// so we only use one [AnimationController] per list/grid.
class SkeletonAnimator extends StatefulWidget {
  final Widget child;

  const SkeletonAnimator({
    super.key,
    required this.child,
  });

  @override
  State<SkeletonAnimator> createState() => _SkeletonAnimatorState();
}

class _SkeletonAnimatorState extends State<SkeletonAnimator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _opacity = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    // Will start playing automatically, but we check reduced motion below.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
      _controller.value = 0.5; // static half-opacity
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return Opacity(
        opacity: 0.5,
        child: widget.child,
      );
    }

    return FadeTransition(
      opacity: _opacity,
      child: widget.child,
    );
  }
}

/// A single primitive box (rectangle or circle) that inherits theme colors.
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final bool isCircle;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.isCircle = false,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2A3E) : Colors.grey.shade300,
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : BorderRadius.circular(borderRadius),
      ),
    );
  }
}
