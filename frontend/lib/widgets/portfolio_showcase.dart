import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../app/app_animations.dart';
import '../services/api_service.dart';

/// Portfolio item model untuk showcase.
class PortfolioItem {
  final String title;
  final String category;
  final List<Color> gradient;
  final IconData? icon;
  final String? imageUrl;
  final VoidCallback? onTap;

  const PortfolioItem({
    required this.title,
    required this.category,
    required this.gradient,
    this.icon,
    this.imageUrl,
    this.onTap,
  });
}

/// Powerful grid/tile untuk showcase portofolio.
/// Punya entrance animation, press feedback, dan glow.
class PortfolioShowcaseCard extends StatelessWidget {
  final PortfolioItem item;
  final int index;
  final double height;

  const PortfolioShowcaseCard({
    super.key,
    required this.item,
    this.index = 0,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(AppTheme.radiusLG);

    return AnimatedEntrance(
      duration: AppMotion.normal,
      delay: Duration(milliseconds: 70 * index),
      child: Pressable(
        borderRadius: borderRadius,
        onTap: item.onTap,
        child: Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              colors: item.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: AppTheme.primaryShadow,
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Stack(
              children: [
                if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                  Positioned.fill(
                    child: Image.network(
                      ApiService.resolveAssetUrl(item.imageUrl!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: item.gradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                  )
                else ...[
                  Positioned(
                    right: -30,
                    top: -30,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 40,
                    bottom: -50,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: item.gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (item.icon != null)
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color:
                                item.imageUrl != null &&
                                    item.imageUrl!.isNotEmpty
                                ? Colors.black.withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(item.icon, color: Colors.white, size: 24),
                        ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.category.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ],
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
