import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../services/badge_service.dart';
import '../screens/notifications_screen.dart';
import '../screens/direct_message_screen.dart';
import '../screens/global_search_screen.dart';

class AppBarBadgeWidget extends StatefulWidget {
  final IconData icon;
  final bool isDark;
  final Color? accentColor;
  final VoidCallback? onTap;

  const AppBarBadgeWidget({
    super.key,
    required this.icon,
    required this.isDark,
    this.accentColor,
    this.onTap,
  });

  @override
  State<AppBarBadgeWidget> createState() => _AppBarBadgeWidgetState();
}

class _AppBarBadgeWidgetState extends State<AppBarBadgeWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isNotification =
        widget.icon == Icons.notifications_none_outlined ||
        widget.icon == Icons.notifications_outlined ||
        widget.icon == Icons.notifications;

    final tooltip = isNotification ? 'Notifikasi' : 'Pesan & Obrolan';
    final accent = widget.accentColor ?? Theme.of(context).primaryColor;

    return ListenableBuilder(
      listenable: BadgeService(),
      builder: (context, _) {
        final countStr = isNotification
            ? BadgeService().unreadNotificationsText
            : BadgeService().unreadMessagesText;

        return Tooltip(
          message: tooltip,
          waitDuration: const Duration(milliseconds: 300),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: GestureDetector(
              onTap: widget.onTap ??
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => isNotification
                            ? const NotificationsScreen(userId: '')
                            : const DirectMessageScreen(),
                      ),
                    );
                  },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                transform: Matrix4.diagonal3Values(_isHovered ? 1.08 : 1.0, _isHovered ? 1.08 : 1.0, 1.0),
                transformAlignment: Alignment.center,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _isHovered
                      ? accent.withValues(alpha: widget.isDark ? 0.22 : 0.12)
                      : (widget.isDark ? const Color(0xFF2D2A3E) : Colors.grey.shade100),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isHovered
                        ? accent.withValues(alpha: 0.5)
                        : (widget.isDark ? AppTheme.inputBorder : Colors.transparent),
                    width: 1.2,
                  ),
                  boxShadow: _isHovered
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        widget.icon,
                        key: ValueKey('${widget.icon}_$_isHovered'),
                        size: 20,
                        color: _isHovered
                            ? accent
                            : (widget.isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    if (countStr.isNotEmpty && countStr != '0')
                      Positioned(
                        right: -5,
                        top: -5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: widget.isDark ? const Color(0xFF1A1830) : Colors.white,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            countStr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class InteractiveDashboardSearchBar extends StatefulWidget {
  final UserModel user;
  final bool isDark;
  final Color? accentColor;
  final String placeholder;
  final VoidCallback? onTap;

  const InteractiveDashboardSearchBar({
    super.key,
    required this.user,
    required this.isDark,
    this.accentColor,
    required this.placeholder,
    this.onTap,
  });

  @override
  State<InteractiveDashboardSearchBar> createState() =>
      _InteractiveDashboardSearchBarState();
}

class _InteractiveDashboardSearchBarState
    extends State<InteractiveDashboardSearchBar> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? Theme.of(context).primaryColor;

    return Tooltip(
      message: 'Klik untuk membuka pencarian (⌘K / Ctrl+K)',
      waitDuration: const Duration(milliseconds: 350),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap ??
              () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GlobalSearchScreen(user: widget.user),
                    ),
                  ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            height: 44,
            decoration: BoxDecoration(
              color: _isHovered
                  ? (widget.isDark ? const Color(0xFF232042) : Colors.white)
                  : (widget.isDark ? const Color(0xFF1A1830) : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isHovered
                    ? accent.withValues(alpha: 0.65)
                    : (widget.isDark ? AppTheme.inputBorder : Colors.grey.shade300),
                width: _isHovered ? 1.5 : 1.0,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: widget.isDark ? 0.22 : 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: widget.isDark ? 0.15 : 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.search,
                    color: _isHovered
                        ? accent
                        : (widget.isDark ? AppTheme.textMuted : Colors.grey.shade500),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
                      fontSize: 13,
                      fontWeight: _isHovered ? FontWeight.w500 : FontWeight.normal,
                      color: _isHovered
                          ? (widget.isDark ? Colors.white : Colors.grey.shade800)
                          : (widget.isDark ? AppTheme.textMuted : Colors.grey.shade500),
                    ),
                    overflow: TextOverflow.ellipsis,
                    child: Text(widget.placeholder),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _isHovered
                        ? accent.withValues(alpha: widget.isDark ? 0.25 : 0.12)
                        : (widget.isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _isHovered
                          ? accent.withValues(alpha: 0.35)
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '⌘K',
                    style: TextStyle(
                      fontSize: 11,
                      color: _isHovered
                          ? accent
                          : (widget.isDark ? AppTheme.textMuted : Colors.grey.shade600),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
