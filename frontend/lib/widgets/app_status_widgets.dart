import 'dart:ui';
import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../app/app_animations.dart';
import 'skeleton_box.dart';

/// Full-area loading state with branded spinner and optional message.
/// Use inside a [SizedBox] / placed as the only child of a scroll view.
class AppLoadingState extends StatelessWidget {
  final String? message;
  final Widget? child;
  final Color? color;

  const AppLoadingState({super.key, this.message, this.child, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: AnimatedEntrance(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Branded loading indicator with glow
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (color ?? AppTheme.primaryPurple).withValues(
                  alpha: isDark ? 0.1 : 0.06,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  strokeCap: StrokeCap.round,
                  color: color ?? Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 20),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTheme.bodyMedium.copyWith(
                  color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                ),
              ),
            ],
            if (child != null) ...[const SizedBox(height: 24), child!],
          ],
        ),
      ),
    );
  }
}

/// Animated skeleton list rows — convenient for feed/chat/project loading.
class SkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final double spacing;
  final bool showLeadingCircle;
  final double borderRadius;

  const SkeletonList({
    super.key,
    this.itemCount = 6,
    this.itemHeight = 88,
    this.spacing = 12,
    this.showLeadingCircle = false,
    this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTheme.cardDark : AppTheme.cardLight;
    final borderColor = isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight;

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      separatorBuilder: (_, _) => SizedBox(height: spacing),
      itemBuilder: (context, index) => AnimatedEntrance(
        delay: Duration(milliseconds: 50 * index),
        child: Container(
          height: itemHeight,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            children: [
              if (showLeadingCircle) ...[
                const SkeletonBox(width: 44, height: 44, shape: BoxShape.circle),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    SkeletonBox(width: 120, height: 14, borderRadius: 6),
                    SizedBox(height: 10),
                    SkeletonBox(
                      width: double.infinity,
                      height: 12,
                      borderRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const SkeletonBox(width: 56, height: 22, borderRadius: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating error banner with icon + message, used inside screens (not SnackBar).
class AppErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final bool compact;

  const AppErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedEntrance(
      offset: const Offset(0, -0.1),
      child: Container(
        padding: EdgeInsets.all(compact ? 12 : 16),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: isDark ? 0.12 : 0.06),
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(
            color: AppTheme.error.withValues(alpha: isDark ? 0.3 : 0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: compact ? 28 : 32,
              height: compact ? 28 : 32,
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: AppTheme.error,
                size: compact ? 16 : 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  message,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppTheme.textWhite : AppTheme.textDark,
                  ),
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Coba Lagi',
                  style: AppTheme.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.error,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Success banner — used for inline success messages
class AppSuccessBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;

  const AppSuccessBanner({
    super.key,
    required this.message,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedEntrance(
      offset: const Offset(0, -0.1),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.success.withValues(alpha: isDark ? 0.12 : 0.06),
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(
            color: AppTheme.success.withValues(alpha: isDark ? 0.3 : 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.success,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppTheme.textWhite : AppTheme.textDark,
                ),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                onPressed: onDismiss,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Overlays a frosted glass scrim + spinner on top of existing content
/// (e.g. form submit). Premium glassmorphism effect.
class LoadingOverlay extends StatelessWidget {
  final bool visible;
  final Widget child;
  final String? message;

  const LoadingOverlay({
    super.key,
    required this.visible,
    required this.child,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (visible)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: 1,
              duration: AppMotion.fast,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: Center(
                    child: AnimatedEntrance(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 22,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface
                              .withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLG,
                          ),
                          border: Border.all(
                            color: AppTheme.primaryPurple.withValues(
                              alpha: 0.15,
                            ),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryPurple.withValues(
                                alpha: 0.1,
                              ),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                strokeCap: StrokeCap.round,
                                color: AppTheme.primaryPurple,
                              ),
                            ),
                            if (message != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                message!,
                                textAlign: TextAlign.center,
                                style: AppTheme.titleMedium.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Info banner for contextual tips and information
class AppInfoBanner extends StatelessWidget {
  final String message;
  final String? title;
  final IconData? icon;
  final Color? accentColor;

  const AppInfoBanner({
    super.key,
    required this.message,
    this.title,
    this.icon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = accentColor ?? AppTheme.info;
    return AnimatedEntrance(
      offset: const Offset(0, -0.1),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: isDark ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(
            color: accent.withValues(alpha: isDark ? 0.25 : 0.15),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? Icons.info_outline_rounded,
                color: accent,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: AppTheme.titleMedium.copyWith(
                        color: isDark ? AppTheme.textWhite : AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    message,
                    style: AppTheme.bodyMedium.copyWith(
                      color: isDark
                          ? AppTheme.textMuted
                          : AppTheme.textMutedLight,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
