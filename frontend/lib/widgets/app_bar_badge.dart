import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../services/app_router.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../services/badge_service.dart';
import '../services/api_service.dart';
import '../services/theme_transition_service.dart';
import '../screens/global_search_screen.dart';

// ── BADGE NOTIFIKASI & PESAN INTERAKTIF ──────────────────────────────────────────
class AppBarBadgeWidget extends StatefulWidget {
  final IconData icon;
  final bool isDark;
  final Color? accentColor;
  final VoidCallback? onTap;
  final int? customCount;
  final String? tooltipMessage;

  const AppBarBadgeWidget({
    super.key,
    required this.icon,
    required this.isDark,
    this.accentColor,
    this.onTap,
    this.customCount,
    this.tooltipMessage,
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

    final defaultTooltip = isNotification ? 'Notifikasi' : 'Pesan & Obrolan';
    final tooltip = widget.tooltipMessage ?? defaultTooltip;
    final accent = widget.accentColor ?? AppTheme.primaryPurple;

    return ListenableBuilder(
      listenable: BadgeService(),
      builder: (context, _) {
        final countStr = widget.customCount != null
            ? (widget.customCount! > 0 ? (widget.customCount! > 9 ? '9+' : '${widget.customCount}') : '')
            : (isNotification
                ? BadgeService().unreadNotificationsText
                : BadgeService().unreadMessagesText);

        return Tooltip(
          message: tooltip,
          waitDuration: const Duration(milliseconds: 250),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: GestureDetector(
              onTap: widget.onTap ??
                  () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                    context.go(
                      isNotification
                          ? AppRoutes.notifikasi
                          : AppRoutes.pesan,
                    );
                  },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                transform: Matrix4.diagonal3Values(
                  _isHovered ? 1.10 : 1.0,
                  _isHovered ? 1.10 : 1.0,
                  1.0,
                ),
                transformAlignment: Alignment.center,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _isHovered
                      ? accent.withValues(alpha: widget.isDark ? 0.24 : 0.14)
                      : (widget.isDark ? const Color(0xFF221F38) : Colors.grey.shade100),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isHovered
                        ? accent.withValues(alpha: 0.65)
                        : (widget.isDark ? AppTheme.inputBorder : Colors.transparent),
                    width: 1.3,
                  ),
                  boxShadow: _isHovered
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: widget.isDark ? 0.35 : 0.22),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        widget.icon,
                        size: 20,
                        color: _isHovered
                            ? accent
                            : (widget.isDark ? Colors.white70 : Colors.grey.shade700),
                      ),
                    ),
                    if (countStr.isNotEmpty && countStr != '0')
                      Positioned(
                        right: -5,
                        top: -5,
                        child: AnimatedScale(
                          scale: _isHovered ? 1.1 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.error,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: widget.isDark ? const Color(0xFF1A1830) : Colors.white,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.error.withValues(alpha: 0.45),
                                  blurRadius: 5,
                                  offset: const Offset(0, 1),
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

// ── SEARCH BAR INTERAKTIF DENGAN HOVER GLOW ─────────────────────────────────────
class InteractiveDashboardSearchBar extends StatefulWidget {
  final UserModel user;
  final bool isDark;
  final Color? accentColor;
  final String placeholder;
  final VoidCallback? onTap;
  final double height;
  final BoxConstraints? constraints;

  const InteractiveDashboardSearchBar({
    super.key,
    required this.user,
    required this.isDark,
    this.accentColor,
    required this.placeholder,
    this.onTap,
    this.height = 42,
    this.constraints,
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
    final accent = widget.accentColor ?? AppTheme.primaryPurple;

    Widget content = Tooltip(
      message: 'Cari proyek, event, vendor, atau talent (⌘K)',
      waitDuration: const Duration(milliseconds: 300),
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
            height: widget.height,
            decoration: BoxDecoration(
              color: _isHovered
                  ? (widget.isDark ? const Color(0xFF242045) : Colors.white)
                  : (widget.isDark ? AppTheme.inputDark : AppTheme.inputLight),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isHovered
                    ? accent.withValues(alpha: 0.8)
                    : (widget.isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight),
                width: _isHovered ? 1.5 : 1.0,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: widget.isDark ? 0.32 : 0.16),
                        blurRadius: 14,
                        offset: const Offset(0, 3),
                        spreadRadius: 1,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: widget.isDark ? 0.12 : 0.02),
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
                  transform: Matrix4.diagonal3Values(
                    _isHovered ? 1.15 : 1.0,
                    _isHovered ? 1.15 : 1.0,
                    1.0,
                  ),
                  transformAlignment: Alignment.center,
                  child: Icon(
                    Icons.search_rounded,
                    color: _isHovered
                        ? accent
                        : (widget.isDark ? AppTheme.textMuted : AppTheme.textMutedLight),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
                      fontSize: 12.5,
                      fontWeight: _isHovered ? FontWeight.w500 : FontWeight.normal,
                      color: _isHovered
                          ? (widget.isDark ? Colors.white : Colors.grey.shade900)
                          : (widget.isDark ? AppTheme.textMuted : AppTheme.textMutedLight),
                    ),
                    overflow: TextOverflow.ellipsis,
                    child: Text(widget.placeholder),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _isHovered
                        ? accent.withValues(alpha: widget.isDark ? 0.28 : 0.12)
                        : (widget.isDark ? AppTheme.inputBorder : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _isHovered
                          ? accent.withValues(alpha: 0.5)
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '⌘K',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: _isHovered
                          ? accent
                          : (widget.isDark ? AppTheme.textMuted : AppTheme.textMutedLight),
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

    if (widget.constraints != null) {
      return ConstrainedBox(
        constraints: widget.constraints!,
        child: content,
      );
    }
    return content;
  }
}

// ── THEME TOGGLE DENGAN HOVER GLOW & ROTASI ────────────────────────────────────
class AppBarThemeToggle extends StatefulWidget {
  final bool isDark;
  final GlobalKey btnKey;
  final Color? accentColor;
  final VoidCallback? onToggle;

  const AppBarThemeToggle({
    super.key,
    required this.isDark,
    required this.btnKey,
    this.accentColor,
    this.onToggle,
  });

  @override
  State<AppBarThemeToggle> createState() => _AppBarThemeToggleState();
}

class _AppBarThemeToggleState extends State<AppBarThemeToggle> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? AppTheme.primaryPurple;

    return Tooltip(
      message: widget.isDark ? 'Beralih ke Mode Terang' : 'Beralih ke Mode Gelap',
      waitDuration: const Duration(milliseconds: 250),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: () {
            if (widget.onToggle != null) {
              widget.onToggle!();
              return;
            }
            final box = widget.btnKey.currentContext?.findRenderObject() as RenderBox?;
            final origin = box != null
                ? box.localToGlobal(box.size.center(Offset.zero))
                : Offset.zero;
            ThemeTransitionService.animateToggle(
              origin: origin,
              toDark: !widget.isDark,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            transform: Matrix4.diagonal3Values(
              _isHovered ? 1.10 : 1.0,
              _isHovered ? 1.10 : 1.0,
              1.0,
            ),
            transformAlignment: Alignment.center,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: _isHovered
                  ? (widget.isDark
                      ? const Color(0xFF352F55)
                      : accent.withValues(alpha: 0.12))
                  : (widget.isDark ? const Color(0xFF221F38) : Colors.grey.shade100),
              shape: BoxShape.circle,
              border: Border.all(
                color: _isHovered
                    ? accent.withValues(alpha: 0.65)
                    : (widget.isDark ? AppTheme.inputBorder : Colors.transparent),
                width: 1.3,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: widget.isDark ? 0.35 : 0.22),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: AnimatedRotation(
              turns: _isHovered ? 0.08 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: AnimatedSwitcher(
                key: widget.btnKey,
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => RotationTransition(
                  turns: Tween(begin: 0.75, end: 1.0).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  widget.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  key: ValueKey(widget.isDark),
                  size: 20,
                  color: _isHovered
                      ? (widget.isDark ? const Color(0xFFFFD54F) : accent)
                      : (widget.isDark ? Colors.white70 : Colors.grey.shade700),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── PROFIL BADGE INTERAKTIF DENGAN CAPSULE GLOW ────────────────────────────────
class AppBarProfileBadge extends StatefulWidget {
  final UserModel user;
  final bool isDark;
  final Color? accentColor;
  final VoidCallback onTap;
  final String? customSubRole;

  const AppBarProfileBadge({
    super.key,
    required this.user,
    required this.isDark,
    this.accentColor,
    required this.onTap,
    this.customSubRole,
  });

  @override
  State<AppBarProfileBadge> createState() => _AppBarProfileBadgeState();
}

class _AppBarProfileBadgeState extends State<AppBarProfileBadge> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? AppTheme.primaryPurple;
    final subRole = widget.customSubRole ??
        widget.user.subRole ??
        (widget.user.role == 'creator' ? 'Creator' : 'Klien');

    return Tooltip(
      message: 'Lihat Profil & Pengaturan Akun (${widget.user.name})',
      waitDuration: const Duration(milliseconds: 250),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _isHovered
                  ? (widget.isDark
                      ? accent.withValues(alpha: 0.18)
                      : accent.withValues(alpha: 0.08))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _isHovered
                    ? accent.withValues(alpha: 0.5)
                    : Colors.transparent,
                width: 1.2,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: widget.isDark ? 0.28 : 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar with animated border glow
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isHovered ? accent : Colors.transparent,
                      width: 1.8,
                    ),
                    boxShadow: _isHovered
                        ? [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.45),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: accent.withValues(alpha: 0.18),
                    backgroundImage: widget.user.avatarUrl?.isNotEmpty == true
                        ? CachedNetworkImageProvider(
                            ApiService.resolveAssetUrl(widget.user.avatarUrl!),
                          )
                        : null,
                    child: widget.user.avatarUrl?.isNotEmpty != true
                        ? Icon(
                            Icons.person,
                            color: accent,
                            size: 18,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: _isHovered
                            ? accent
                            : (widget.isDark ? Colors.white : Colors.black87),
                      ),
                      child: Text(widget.user.name.split(' ').first),
                    ),
                    Text(
                      subRole,
                      style: TextStyle(
                        fontSize: 10,
                        color: widget.isDark
                            ? AppTheme.textMuted
                            : AppTheme.textMutedLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                AnimatedSlide(
                  offset: Offset(0, _isHovered ? 0.2 : 0),
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: _isHovered
                        ? accent
                        : (widget.isDark ? AppTheme.textMuted : AppTheme.textMutedLight),
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

// ── TOMBOL MASUK & DAFTAR (GUEST) DENGAN HOVER GLOW ────────────────────────────
class AppBarGuestActions extends StatefulWidget {
  final bool isDark;
  final Color? accentColor;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  const AppBarGuestActions({
    super.key,
    required this.isDark,
    this.accentColor,
    required this.onLogin,
    required this.onRegister,
  });

  @override
  State<AppBarGuestActions> createState() => _AppBarGuestActionsState();
}

class _AppBarGuestActionsState extends State<AppBarGuestActions> {
  bool _loginHovered = false;
  bool _registerHovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? AppTheme.primaryPurple;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tombol Masuk
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _loginHovered = true),
          onExit: (_) => setState(() => _loginHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.diagonal3Values(
              _loginHovered ? 1.05 : 1.0,
              _loginHovered ? 1.05 : 1.0,
              1.0,
            ),
            transformAlignment: Alignment.center,
            child: OutlinedButton(
              onPressed: widget.onLogin,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: const Size(0, 36),
                side: BorderSide(
                  color: _loginHovered
                      ? accent
                      : (widget.isDark ? AppTheme.inputBorder : accent.withValues(alpha: 0.5)),
                  width: _loginHovered ? 1.5 : 1.0,
                ),
                backgroundColor: _loginHovered
                    ? accent.withValues(alpha: widget.isDark ? 0.2 : 0.08)
                    : Colors.transparent,
                foregroundColor: widget.isDark ? Colors.white : accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Masuk',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Tombol Daftar
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _registerHovered = true),
          onExit: (_) => setState(() => _registerHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.diagonal3Values(
              _registerHovered ? 1.05 : 1.0,
              _registerHovered ? 1.05 : 1.0,
              1.0,
            ),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: _registerHovered
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: ElevatedButton(
              onPressed: widget.onRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: const Size(0, 36),
                elevation: _registerHovered ? 3 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Daftar',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
