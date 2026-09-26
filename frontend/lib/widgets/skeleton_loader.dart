import 'package:flutter/material.dart';
import '../app/theme.dart';

/// Alternative skeleton loader with a horizontal sweep gradient.
/// Useful for larger content blocks like cards or sections.
class SkeletonLoader extends StatefulWidget {
  final double height;
  final double? width;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const SkeletonLoader({
    super.key,
    required this.height,
    this.width,
    this.borderRadius = 14,
    this.margin,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Use AppTheme colors for brand consistency
    final baseColor = isDark ? AppTheme.cardDark2 : const Color(0xFFE8E5F3);
    final highlightColor = isDark ? AppTheme.inputDark : AppTheme.surfaceLight;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          margin: widget.margin,
          width: widget.width ?? double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                (_ctrl.value - 0.3).clamp(0.0, 1.0),
                _ctrl.value,
                (_ctrl.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}
