import 'dart:math' as math;
import 'package:flutter/material.dart';

class CustomDiamondBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isDark;
  final List<CustomNavItem> items;

  const CustomDiamondBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.isDark,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final unselectedColor = Colors.grey.shade500;

    final screenWidth = MediaQuery.of(context).size.width;
    const margin = 16.0;
    final barWidth = screenWidth - (margin * 2);
    final itemWidth = barWidth / items.length;
    const diamondSize = 50.0;

    final activeCenterX = (itemWidth * currentIndex) + (itemWidth / 2);

    return SizedBox(
      height: 95,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // Background pill bar
          Container(
            height: 68,
            margin: const EdgeInsets.fromLTRB(margin, 0, margin, 14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.shade200,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, -4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: List.generate(items.length, (index) {
                final isSelected = index == currentIndex;
                final item = items[index];

                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(index),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon: smoothly fade out when selected
                        AnimatedOpacity(
                          opacity: isSelected ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: AnimatedScale(
                            scale: isSelected ? 0.5 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              item.icon,
                              color: unselectedColor,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Text: smoothly fade out when selected
                        AnimatedOpacity(
                          opacity: isSelected ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: unselectedColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),

          // Diamond — slides smoothly via AnimatedPositioned
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            bottom: 36,
            left: margin + activeCenterX - (diamondSize / 2) - 4,
            child: GestureDetector(
              onTap: () => onTap(currentIndex),
              child: Transform.rotate(
                angle: 45 * math.pi / 180,
                child: Container(
                  width: diamondSize + 8,
                  height: diamondSize + 8,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: diamondSize,
                      height: diamondSize,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Transform.rotate(
                        angle: -45 * math.pi / 180,
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            switchInCurve: Curves.easeIn,
                            switchOutCurve: Curves.easeOut,
                            child: Icon(
                              items[currentIndex].activeIcon,
                              key: ValueKey(currentIndex),
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  CustomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
