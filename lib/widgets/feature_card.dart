import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/opportunity_model.dart';

class FeatureCard extends StatelessWidget {
  final OpportunityModel opportunity;
  final VoidCallback? onTap;
  final Color accentColor;

  const FeatureCard({
    super.key,
    required this.opportunity,
    required this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: !isDark
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        opportunity.pihakSlug.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ),
                    if (opportunity.budgetRange != null)
                      Text(
                        opportunity.budgetRange!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? theme.colorScheme.secondary : Colors.green.shade700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  opportunity.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (opportunity.description != null &&
                    opportunity.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    opportunity.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Divider(
                  color: isDark ? AppTheme.inputBorder : Colors.grey.shade100,
                  height: 1,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (opportunity.location != null) ...[
                      const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          opportunity.location!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    if (opportunity.deadline != null) ...[
                      const Icon(Icons.calendar_month_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        opportunity.deadline!,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
