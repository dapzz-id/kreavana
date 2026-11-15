import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app/theme.dart';

/// Shared responsive pagination bar and slicing helpers for paginated data views.
class AppPaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final String itemLabel;
  final Color? primaryColor;
  final Color? accentColor;
  final EdgeInsetsGeometry? margin;

  const AppPaginationBar({
    super.key,
    required this.currentPage,
    required this.totalItems,
    this.pageSize = 6,
    required this.onPageChanged,
    this.itemLabel = 'data',
    this.primaryColor,
    this.accentColor,
    this.margin,
  });

  /// Returns a safely bounded page number within `1..totalPages(totalItems, pageSize)`.
  static int safePage(int requestedPage, int totalItems, {int pageSize = 6}) {
    final pages = totalPages(totalItems, pageSize: pageSize);
    return requestedPage.clamp(1, pages);
  }

  /// Computes total page count (minimum 1).
  static int totalPages(int totalItems, {int pageSize = 6}) {
    if (totalItems <= 0 || pageSize <= 0) return 1;
    return (totalItems / pageSize).ceil();
  }

  /// Slices `items` for `currentPage` (1-indexed) with at most `pageSize` entries.
  static List<T> slicePage<T>(
    List<T> items,
    int currentPage, {
    int pageSize = 6,
  }) {
    if (items.isEmpty) return <T>[];
    final safe = safePage(currentPage, items.length, pageSize: pageSize);
    final start = (safe - 1) * pageSize;
    final end = (start + pageSize).clamp(0, items.length);
    return items.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    if (totalItems <= 0) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themePrimary = accentColor ?? primaryColor ?? const Color(0xFF4F46E5);

    final totalPagesCount = totalPages(totalItems, pageSize: pageSize);
    final effectivePage = safePage(currentPage, totalItems, pageSize: pageSize);

    final start = (effectivePage - 1) * pageSize + 1;
    final end = math.min(effectivePage * pageSize, totalItems);
    final String infoText = 'Menampilkan $start–$end dari $totalItems $itemLabel';

    final canPrev = effectivePage > 1;
    final canNext = effectivePage < totalPagesCount;
    final borderColor =
        isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF64748B);

    return Container(
      width: double.infinity,
      margin: margin ?? const EdgeInsets.only(top: 16, bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
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
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          Text(
            infoText,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textSecondary,
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: canPrev ? () => onPageChanged(effectivePage - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 16),
                label: const Text('Prev', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  side: BorderSide(color: borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              ..._buildPagePills(
                effectivePage: effectivePage,
                totalPages: totalPagesCount,
                isDark: isDark,
                themePrimary: themePrimary,
                borderColor: borderColor,
              ),
              OutlinedButton.icon(
                onPressed: canNext ? () => onPageChanged(effectivePage + 1) : null,
                icon: const Icon(Icons.chevron_right_rounded, size: 16),
                iconAlignment: IconAlignment.end,
                label: const Text('Next', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  side: BorderSide(color: borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPagePills({
    required int effectivePage,
    required int totalPages,
    required bool isDark,
    required Color themePrimary,
    required Color borderColor,
  }) {
    final List<Widget> pills = [];

    if (totalPages <= 5) {
      for (int i = 1; i <= totalPages; i++) {
        pills.add(_buildSinglePagePill(
          page: i,
          isActive: i == effectivePage,
          isDark: isDark,
          themePrimary: themePrimary,
          borderColor: borderColor,
        ));
      }
      return pills;
    }

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
        borderColor: borderColor,
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
    required Color borderColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isActive ? null : () => onPageChanged(page),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? themePrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? themePrimary : borderColor,
            ),
          ),
          child: Text(
            '$page',
            style: TextStyle(
              color: isActive
                  ? Colors.white
                  : (isDark ? Colors.white70 : const Color(0xFF475569)),
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }
}
