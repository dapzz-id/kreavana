import 'dart:async';
import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../services/navigator_key.dart';

enum SweetAlertType {
  success,
  error,
  warning,
  info,
}

/// SweetAlert2-style Toast Notification for Kreavana.
/// Renders at the top-right corner on Web & Desktop, with sleek animations,
/// glowing colored icons, progress timer bar, and dark/light mode support.
class AppSweetAlert {
  static final List<_SweetAlertEntry> _activeAlerts = [];

  /// Show a SweetAlert toast notification
  static void show({
    BuildContext? context,
    required String message,
    String? title,
    SweetAlertType type = SweetAlertType.info,
    Duration duration = const Duration(milliseconds: 3600),
  }) {
    final targetContext = context ?? navigatorKey.currentContext;
    if (targetContext == null) return;

    final overlayState = Overlay.maybeOf(targetContext) ??
        navigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    // Clear previous alerts if there are already 3 stacked
    while (_activeAlerts.length >= 3) {
      _activeAlerts.first.dismiss();
    }

    late _SweetAlertEntry entry;
    final overlayEntry = OverlayEntry(
      builder: (ctx) => _SweetAlertToastWidget(
        title: title,
        message: message,
        type: type,
        duration: duration,
        onDismiss: () => entry.dismiss(),
      ),
    );

    entry = _SweetAlertEntry(overlayEntry: overlayEntry, overlayState: overlayState);
    _activeAlerts.add(entry);
    overlayState.insert(overlayEntry);
  }

  /// Shortcut for Success Toast (emerald green)
  static void success(
    BuildContext? context,
    String message, {
    String? title = 'Berhasil',
    Duration duration = const Duration(milliseconds: 3600),
  }) {
    show(
      context: context,
      title: title,
      message: message,
      type: SweetAlertType.success,
      duration: duration,
    );
  }

  /// Shortcut for Error Toast (rose red)
  static void error(
    BuildContext? context,
    String message, {
    String? title = 'Gagal',
    Duration duration = const Duration(milliseconds: 4000),
  }) {
    show(
      context: context,
      title: title,
      message: message,
      type: SweetAlertType.error,
      duration: duration,
    );
  }

  /// Shortcut for Info Toast (Kreavana purple)
  static void info(
    BuildContext? context,
    String message, {
    String? title = 'Informasi',
    Duration duration = const Duration(milliseconds: 3600),
  }) {
    show(
      context: context,
      title: title,
      message: message,
      type: SweetAlertType.info,
      duration: duration,
    );
  }

  /// Shortcut for Warning Toast (amber)
  static void warning(
    BuildContext? context,
    String message, {
    String? title = 'Perhatian',
    Duration duration = const Duration(milliseconds: 3800),
  }) {
    show(
      context: context,
      title: title,
      message: message,
      type: SweetAlertType.warning,
      duration: duration,
    );
  }

  /// Dismiss all active SweetAlert toasts
  static void dismissAll() {
    for (final alert in List.from(_activeAlerts)) {
      alert.dismiss();
    }
  }
}

class _SweetAlertEntry {
  final OverlayEntry overlayEntry;
  final OverlayState overlayState;
  bool _isRemoved = false;

  _SweetAlertEntry({
    required this.overlayEntry,
    required this.overlayState,
  });

  void dismiss() {
    if (_isRemoved) return;
    _isRemoved = true;
    try {
      overlayEntry.remove();
      overlayEntry.dispose();
    } catch (_) {}
    AppSweetAlert._activeAlerts.remove(this);
  }
}

class _SweetAlertToastWidget extends StatefulWidget {
  final String? title;
  final String message;
  final SweetAlertType type;
  final Duration duration;
  final VoidCallback onDismiss;

  const _SweetAlertToastWidget({
    this.title,
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_SweetAlertToastWidget> createState() => _SweetAlertToastWidgetState();
}

class _SweetAlertToastWidgetState extends State<_SweetAlertToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _dismissTimer;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Slide from right
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _controller.forward();
    _startTimer();
  }

  void _startTimer() {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(widget.duration, () {
      if (!mounted || _isHovered) return;
      _dismiss();
    });
  }

  void _dismiss() {
    if (!mounted) return;
    _dismissTimer?.cancel();
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = mediaQuery.size.width < 600;

    final Color accentColor = switch (widget.type) {
      SweetAlertType.success => const Color(0xFF10B981), // Emerald
      SweetAlertType.error => const Color(0xFFEF4444), // Rose Red
      SweetAlertType.warning => const Color(0xFFF59E0B), // Amber
      SweetAlertType.info => AppTheme.primaryPurple, // Purple
    };

    final IconData iconData = switch (widget.type) {
      SweetAlertType.success => Icons.check_circle_rounded,
      SweetAlertType.error => Icons.error_rounded,
      SweetAlertType.warning => Icons.warning_rounded,
      SweetAlertType.info => Icons.info_rounded,
    };

    final defaultTitle = switch (widget.type) {
      SweetAlertType.success => 'Berhasil',
      SweetAlertType.error => 'Gagal',
      SweetAlertType.warning => 'Pemberitahuan',
      SweetAlertType.info => 'Info',
    };

    final displayTitle = widget.title ?? defaultTitle;

    return Positioned(
      top: isMobile ? mediaQuery.padding.top + 16 : 24,
      right: isMobile ? 16 : 24,
      left: isMobile ? 16 : null,
      child: Material(
        type: MaterialType.transparency,
        child: MouseRegion(
          onEnter: (_) {
            _isHovered = true;
            _dismissTimer?.cancel();
          },
          onExit: (_) {
            _isHovered = false;
            _startTimer();
          },
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Dismissible(
                key: UniqueKey(),
                direction: DismissDirection.horizontal,
                onDismissed: (_) => widget.onDismiss(),
                child: Container(
                  width: isMobile ? double.infinity : 380,
                  constraints: const BoxConstraints(maxWidth: 420),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161B2E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? accentColor.withValues(alpha: 0.35)
                          : accentColor.withValues(alpha: 0.25),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.5)
                            : const Color(0xFF0F172A).withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: accentColor.withValues(alpha: isDark ? 0.15 : 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Status Icon ───────────────────────────────
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: accentColor.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  iconData,
                                  color: accentColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // ── Text Content ──────────────────────────────
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 1),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (displayTitle.isNotEmpty) ...[
                                        Text(
                                          displayTitle,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                      ],
                                      Text(
                                        widget.message,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          height: 1.35,
                                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // ── Close Button ──────────────────────────────
                              InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: _dismiss,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.black.withValues(alpha: 0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── Animated Progress Bar at Bottom ───────────
                        _SweetAlertTimerBar(
                          duration: widget.duration,
                          color: accentColor,
                          isPaused: _isHovered,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SweetAlertTimerBar extends StatefulWidget {
  final Duration duration;
  final Color color;
  final bool isPaused;

  const _SweetAlertTimerBar({
    required this.duration,
    required this.color,
    required this.isPaused,
  });

  @override
  State<_SweetAlertTimerBar> createState() => _SweetAlertTimerBarState();
}

class _SweetAlertTimerBarState extends State<_SweetAlertTimerBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _progressController.forward();
  }

  @override
  void didUpdateWidget(covariant _SweetAlertTimerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPaused && !oldWidget.isPaused) {
      _progressController.stop();
    } else if (!widget.isPaused && oldWidget.isPaused) {
      _progressController.forward();
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progressController,
      builder: (context, child) {
        return LinearProgressIndicator(
          value: 1.0 - _progressController.value,
          minHeight: 2.5,
          backgroundColor: widget.color.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation<Color>(
            widget.color.withValues(alpha: 0.85),
          ),
        );
      },
    );
  }
}
