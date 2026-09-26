import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../app/app_animations.dart';

/// A polished empty state widget for lists, search results, etc.
/// Features an animated decorative pattern, clear messaging, and optional CTA.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;
  final double iconSize;
  final Color? accentColor;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.iconSize = 56,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = accentColor ?? AppTheme.primaryPurple;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        child: AnimatedEntrance(
          duration: AppMotion.normal,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Decorative icon container with rings ──
              _AnimatedIconContainer(
                icon: icon,
                iconSize: iconSize,
                accent: accent,
                isDark: isDark,
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTheme.titleLarge.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: AppTheme.bodyMedium.copyWith(
                      color: isDark
                          ? AppTheme.textMuted
                          : AppTheme.textMutedLight,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon ?? Icons.refresh_rounded, size: 18),
                  label: Text(actionLabel!),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated icon with concentric ring pulse effect
class _AnimatedIconContainer extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final Color accent;
  final bool isDark;

  const _AnimatedIconContainer({
    required this.icon,
    required this.iconSize,
    required this.accent,
    required this.isDark,
  });

  @override
  State<_AnimatedIconContainer> createState() => _AnimatedIconContainerState();
}

class _AnimatedIconContainerState extends State<_AnimatedIconContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations == true) {
      _controller.stop();
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
    final size = widget.iconSize + 40;
    final outerSize = size + 24;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = 0.5 + 0.5 * math.sin(_controller.value * math.pi);
        return SizedBox(
          width: outerSize,
          height: outerSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse ring
              Container(
                width: outerSize,
                height: outerSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.accent.withValues(
                      alpha: 0.06 + 0.06 * pulse,
                    ),
                    width: 1,
                  ),
                ),
              ),
              // Inner container
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.accent.withValues(
                        alpha: widget.isDark ? 0.12 : 0.08,
                      ),
                      widget.accent.withValues(
                        alpha: widget.isDark ? 0.06 : 0.03,
                      ),
                    ],
                  ),
                  border: Border.all(
                    color: widget.accent.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Icon(
                  widget.icon,
                  size: widget.iconSize,
                  color: widget.accent.withValues(alpha: 0.5 + 0.15 * pulse),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A compact error state with retry and animated icon
class AppErrorState extends StatelessWidget {
  final String message;
  final String? title;
  final VoidCallback? onRetry;
  final IconData? icon;

  const AppErrorState({
    super.key,
    this.message = 'Terjadi kesalahan. Silakan coba lagi.',
    this.title,
    this.onRetry,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: AnimatedEntrance(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AnimatedIconContainer(
                icon: icon ?? Icons.wifi_off_rounded,
                iconSize: 40,
                accent: AppTheme.error,
                isDark: isDark,
              ),
              const SizedBox(height: 20),
              Text(
                title ?? 'Gagal Memuat',
                style: AppTheme.titleLarge.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyMedium.copyWith(
                    color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                    height: 1.6,
                  ),
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Coba Lagi'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryPurple,
                    side: BorderSide(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A status/label badge with optional dot indicator
class AppBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  final double fontSize;
  final bool showDot;

  const AppBadge({
    super.key,
    required this.label,
    required this.color,
    this.filled = false,
    this.fontSize = 10,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: filled
            ? null
            : Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: filled ? Colors.white : color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: filled ? Colors.white : color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline notification dot
class AppDot extends StatelessWidget {
  final Color color;
  final double size;

  const AppDot({super.key, this.color = AppTheme.error, this.size = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
