import 'package:flutter/material.dart';
import 'skeleton_base.dart';
import '../../app/theme.dart';

class SkeletonGrid extends StatelessWidget {
  final int itemCount;
  final SliverGridDelegate gridDelegate;

  /// Creates a standard grid view of skeletons.
  /// Wrapped in a single [SkeletonAnimator] for performance.
  const SkeletonGrid({
    super.key,
    this.itemCount = 4,
    this.gridDelegate = const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 0.8,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonAnimator(
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        gridDelegate: gridDelegate,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardBg : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2D2A3E)
                          : Colors.grey.shade300,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox(width: double.infinity, height: 12),
                      SizedBox(height: 8),
                      SkeletonBox(width: 60, height: 10),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
