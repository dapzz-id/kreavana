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

  const AppBreadcrumbs({
    super.key,
    required this.items,
    this.padding = const EdgeInsets.only(bottom: 16),
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: padding,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (int i = 0; i < items.length; i++) ...[
              _buildItem(items[i], i == items.length - 1, isDark),
              if (i < items.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: isDark ? Colors.white30 : Colors.grey.shade400,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItem(BreadcrumbItem item, bool isLast, bool isDark) {
    final hasAction = item.onTap != null && !isLast;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.icon != null) ...[
          Icon(
            item.icon,
            size: 15,
            color: isLast
                ? AppTheme.primaryPurple
                : (isDark ? AppTheme.textMuted : Colors.grey.shade600),
          ),
          const SizedBox(width: 5),
        ],
        Text(
          item.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
            color: isLast
                ? (isDark ? Colors.white : const Color(0xFF1E293B))
                : (isDark ? AppTheme.textMuted : Colors.grey.shade600),
          ),
        ),
      ],
    );

    if (hasAction) {
      return InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(6),
        hoverColor: AppTheme.primaryPurple.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: content,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: content,
    );
  }
}
