import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app/theme.dart';

class AppPaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final String itemLabel;
  final Color? primaryColor;
  final EdgeInsetsGeometry? margin;

  const AppPaginationBar({
    super.key,
    required this.currentPage,
    required this.totalItems,
    required this.pageSize,
    required this.onPageChanged,
    this.itemLabel = 'data',
    this.primaryColor,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themePrimary = primaryColor ?? const Color(0xFF4F46E5);

    final totalPages = totalItems > 0 ? (totalItems / pageSize).ceil() : 1;
    final effectivePage = currentPage.clamp(1, totalPages);

    final start = totalItems == 0 ? 0 : (effectivePage - 1) * pageSize + 1;
    final end = totalItems == 0 ? 0 : math.min(effectivePage * pageSize, totalItems);

    final String infoText = totalItems == 0
        ? 'Menampilkan 0 $itemLabel'
        : 'Menampilkan $start \u2013 $end dari $totalItems $itemLabel';

    final canPrev = effectivePage > 1;
    final canNext = effectivePage < totalPages;

    return Container(
      margin: margin ?? const EdgeInsets.only(top: 24, bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 440;

          final paginationControls = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Previous button (<)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: canPrev ? () => onPageChanged(effectivePage - 1) : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 22,
                      color: canPrev
                          ? (isDark ? Colors.white70 : const Color(0xFF64748B))
                          : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Page numbers
              ..._buildPagePills(
                effectivePage: effectivePage,
                totalPages: totalPages,
                isDark: isDark,
                themePrimary: themePrimary,
              ),

              const SizedBox(width: 4),
              // Next button (>)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: canNext ? () => onPageChanged(effectivePage + 1) : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: canNext
                          ? (isDark ? Colors.white70 : const Color(0xFF64748B))
                          : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
              ),
            ],
          );

          final labelWidget = Text(
            infoText,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
            ),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                labelWidget,
                const SizedBox(height: 12),
                paginationControls,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              labelWidget,
              paginationControls,
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildPagePills({
    required int effectivePage,
    required int totalPages,
    required bool isDark,
    required Color themePrimary,
  }) {
    final List<Widget> pills = [];

    // Simple display for <= 5 pages: render all page numbers
    if (totalPages <= 5) {
      for (int i = 1; i <= totalPages; i++) {
        pills.add(_buildSinglePagePill(
          page: i,
          isActive: i == effectivePage,
          isDark: isDark,
          themePrimary: themePrimary,
        ));
      }
      return pills;
    }

    // Truncated display for > 5 pages
    final Set<int> visiblePages = {1, totalPages, effectivePage};
    if (effectivePage > 1) visiblePages.add(effectivePage - 1);
    if (effectivePage < totalPages) visiblePages.add(effectivePage + 1);

    final sorted = visiblePages.toList()..sort();
    int lastPage = 0;

    for (final page in sorted) {
      if (lastPage != 0 && page - lastPage > 1) {
        pills.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '...',
              style: TextStyle(
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }

      pills.add(_buildSinglePagePill(
        page: page,
        isActive: page == effectivePage,
        isDark: isDark,
        themePrimary: themePrimary,
      ));
      lastPage = page;
    }

    return pills;
  }

  Widget _buildSinglePagePill({
    required int page,
    required bool isActive,
    required bool isDark,
    required Color themePrimary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isActive ? null : () => onPageChanged(page),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minWidth: 36),
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActive ? themePrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$page',
              style: TextStyle(
                color: isActive
                    ? Colors.white
                    : (isDark ? Colors.white70 : const Color(0xFF475569)),
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
