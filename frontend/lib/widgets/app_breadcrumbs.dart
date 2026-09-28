import 'package:flutter/material.dart';
import '../app/theme.dart';

class BreadcrumbItem {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  const BreadcrumbItem({
    required this.label,
    this.icon,
    this.onTap,
  });
}

class AppBreadcrumbs extends StatelessWidget {
  final List<BreadcrumbItem> items;
  final EdgeInsetsGeometry padding;
  final bool showCapsule;

  const AppBreadcrumbs({
    super.key,
    required this.items,
    this.padding = const EdgeInsets.only(top: 4, bottom: 12),
    this.showCapsule = true,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget rowContent = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _buildItem(items[i], i == items.length - 1, isDark),
          if (i < items.length - 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 15,
                color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
              ),
            ),
        ],
      ],
    );

    Widget breadcrumbWidget;
    if (showCapsule) {
      breadcrumbWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E293B).withValues(alpha: 0.65)
              : const Color(0xFFF1F5F9).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? const Color(0xFF334155).withValues(alpha: 0.5)
                : const Color(0xFFE2E8F0),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : const Color(0xFF64748B).withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: rowContent,
      );
    } else {
      breadcrumbWidget = rowContent;
    }

    return Padding(
      padding: padding,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: breadcrumbWidget,
      ),
    );
  }

  Widget _buildItem(BreadcrumbItem item, bool isLast, bool isDark) {
    final hasAction = item.onTap != null && !isLast;

    if (isLast) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
        decoration: BoxDecoration(
          color: AppTheme.primaryPurple.withValues(alpha: isDark ? 0.22 : 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.primaryPurple.withValues(alpha: isDark ? 0.45 : 0.2),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.icon != null) ...[
              Icon(
                item.icon,
                size: 13.5,
                color: isDark ? const Color(0xFFC084FC) : AppTheme.primaryPurple,
              ),
              const SizedBox(width: 4.5),
            ],
            Text(
              item.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFE9D5FF) : AppTheme.primaryPurple,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      );
    }

    final normalContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.icon != null) ...[
            Icon(
              item.icon,
              size: 13.5,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
            ),
            const SizedBox(width: 4.5),
          ],
          Text(
            item.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );

    if (hasAction) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(14),
          hoverColor: AppTheme.primaryPurple.withValues(alpha: 0.08),
          child: normalContent,
        ),
      );
    }

    return normalContent;
  }
}
