import 'package:flutter/material.dart';
import '../app/theme.dart';

class SidebarHoverTile extends StatefulWidget {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final VoidCallback onTap;
  final bool isSelected;
  final bool isDark;
  final bool isCollapsed;
  final Color activeColor;
  final Widget? trailing;

  const SidebarHoverTile({
    super.key,
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.onTap,
    required this.isSelected,
    required this.isDark,
    this.isCollapsed = false,
    required this.activeColor,
    this.trailing,
  });

  @override
  State<SidebarHoverTile> createState() => _SidebarHoverTileState();
}

class _SidebarHoverTileState extends State<SidebarHoverTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final effectiveActiveColor = widget.activeColor;
    final effectiveIcon = widget.isSelected && widget.activeIcon != null
        ? widget.activeIcon!
        : widget.icon;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.isCollapsed ? 8 : 12,
        vertical: 2,
      ),
      child: Tooltip(
        message: widget.isCollapsed ? widget.label : '',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) {
            if (!_isHovered && mounted) {
              setState(() => _isHovered = true);
            }
          },
          onExit: (_) {
            if (_isHovered && mounted) {
              setState(() => _isHovered = false);
            }
          },
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: AnimatedSlide(
              offset: Offset(
                (_isHovered && !widget.isCollapsed) ? 0.025 : 0.0,
                0.0,
              ),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: widget.isCollapsed ? 0 : 12,
                  vertical: 9.5,
                ),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? effectiveActiveColor.withValues(
                          alpha: widget.isDark ? 0.18 : 0.10,
                        )
                      : (_isHovered
                          ? effectiveActiveColor.withValues(
                              alpha: widget.isDark ? 0.12 : 0.07,
                            )
                          : Colors.transparent),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.isSelected
                        ? effectiveActiveColor.withValues(
                            alpha: widget.isDark ? 0.45 : 0.28,
                          )
                        : (_isHovered
                            ? effectiveActiveColor.withValues(
                                alpha: widget.isDark ? 0.28 : 0.16,
                              )
                            : Colors.transparent),
                    width: widget.isSelected ? 1.2 : 1.0,
                  ),
                  boxShadow: widget.isSelected || _isHovered
                      ? [
                          BoxShadow(
                            color: effectiveActiveColor.withValues(
                              alpha: widget.isSelected
                                  ? (widget.isDark ? 0.20 : 0.10)
                                  : (widget.isDark ? 0.12 : 0.05),
                            ),
                            blurRadius: widget.isSelected ? 10 : 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: widget.isCollapsed
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    // Active or Hover Pill Indicator on the left
                    if (!widget.isCollapsed) ...[
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        width: widget.isSelected ? 3.5 : (_isHovered ? 3.0 : 0.0),
                        height: widget.isSelected ? 18.0 : (_isHovered ? 14.0 : 0.0),
                        decoration: BoxDecoration(
                          color: widget.isSelected
                              ? effectiveActiveColor
                              : effectiveActiveColor.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: widget.isSelected || _isHovered
                              ? [
                                  BoxShadow(
                                    color: effectiveActiveColor.withValues(alpha: 0.4),
                                    blurRadius: 4,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: widget.isSelected ? 8.0 : (_isHovered ? 6.0 : 0.0),
                      ),
                    ],

                    // Menu Icon with hover scale & micro-color animation
                    AnimatedScale(
                      scale: _isHovered ? 1.12 : 1.0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        effectiveIcon,
                        color: widget.isSelected
                            ? effectiveActiveColor
                            : (_isHovered
                                ? effectiveActiveColor
                                : (widget.isDark
                                    ? AppTheme.textMuted
                                    : AppTheme.textSecondary)),
                        size: 20,
                      ),
                    ),

                    if (!widget.isCollapsed) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          style: TextStyle(
                            fontFamily:
                                Theme.of(context).textTheme.bodyMedium?.fontFamily,
                            fontWeight: widget.isSelected
                                ? FontWeight.w700
                                : (_isHovered
                                    ? FontWeight.w600
                                    : FontWeight.w500),
                            fontSize: 13.5,
                            color: widget.isSelected
                                ? (widget.isDark
                                    ? Colors.white
                                    : effectiveActiveColor)
                                : (_isHovered
                                    ? (widget.isDark
                                        ? Colors.white
                                        : effectiveActiveColor)
                                    : (widget.isDark
                                        ? Colors.white70
                                        : AppTheme.textPrimary)),
                            letterSpacing: widget.isSelected ? 0.1 : 0,
                          ),
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (widget.trailing != null)
                        widget.trailing!
                      else
                        AnimatedOpacity(
                          opacity: _isHovered && !widget.isSelected ? 0.75 : 0.0,
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: effectiveActiveColor,
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
    );
  }
}
