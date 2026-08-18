import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../app/app_animations.dart';
import 'skeleton_box.dart';

/// Full-area loading state with a subtle fade + centered spinner.
/// Use inside a [SizedBox] / placed as the only child of a scroll view.
class AppLoadingState extends StatelessWidget {
  final String? message;
  final Widget? child;

  const AppLoadingState({super.key, this.message, this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: AnimatedEntrance(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
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
    final cardColor = isDark ? const Color(0xFF1E1E2C) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2D2D3D) : Colors.grey.shade200;

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      separatorBuilder: (_, _) => SizedBox(height: spacing),
      itemBuilder: (context, index) => Container(
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
          color: AppTheme.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.error.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: AppTheme.error,
              size: compact ? 18 : 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: compact ? 12.5 : 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  color: isDark ? AppTheme.textWhite : AppTheme.textDark,
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: onRetry,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    'Coba Lagi',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.error,
                    ),
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

/// Overlays a scrim + spinner on top of existing content (e.g. form submit).
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
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.35),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.cardShadowLight,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        if (message != null) ...[
                          const SizedBox(width: 14),
                          Text(
                            message!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
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
      ],
    );
  }
}
