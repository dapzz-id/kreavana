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
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight,
          width: 1,
        ),
        boxShadow: isDark ? null : AppTheme.cardShadowLight,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header row ─────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getSubRoleIcon(opportunity.subRoleSlug),
                        color: accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _formatSubRole(opportunity.subRoleSlug),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (opportunity.budgetRange != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.success.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          opportunity.budgetRange!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.success,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // ── Title ──────────────────────────────────────────────────
                Text(
                  opportunity.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                if (opportunity.description != null &&
                    opportunity.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    opportunity.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppTheme.textMuted
                          : AppTheme.textMutedLight,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // ── Divider ────────────────────────────────────────────────
                Divider(
                  color: isDark
                      ? AppTheme.dividerDark
                      : AppTheme.dividerLight,
                  height: 1,
                ),
                const SizedBox(height: 10),

                // ── Footer ─────────────────────────────────────────────────
                Row(
                  children: [
                    if (opportunity.location != null) ...[
                      Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: isDark
                            ? AppTheme.textMuted
                            : AppTheme.textMutedLight,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          opportunity.location!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppTheme.textMuted
                                : AppTheme.textMutedLight,
                          ),
                        ),
                      ),
                    ] else
                      const Spacer(),
                    if (opportunity.deadline != null) ...[
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color: isDark
                            ? AppTheme.textMuted
                            : AppTheme.textMutedLight,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        opportunity.deadline!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.textMuted
                              : AppTheme.textMutedLight,
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: accentColor.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatSubRole(String slug) {
    return slug
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty
            ? '${w[0].toUpperCase()}${w.substring(1)}'
            : '')
        .join(' ')
        .toUpperCase();
  }

  IconData _getSubRoleIcon(String slug) {
    switch (slug) {
      case 'photographer':
        return Icons.camera_alt_outlined;
      case 'videographer':
        return Icons.videocam_outlined;
      case 'editor':
        return Icons.edit_outlined;
      case 'designer':
        return Icons.palette_outlined;
      case 'makeup_artist':
        return Icons.face_retouching_natural_outlined;
      case 'talent':
        return Icons.star_outline;
      case 'drone':
        return Icons.airplanemode_active_outlined;
      case 'content':
        return Icons.phone_android_outlined;
      case 'mc':
        return Icons.mic_outlined;
      case 'singer':
        return Icons.music_note_outlined;
      case 'wedding_organizer':
        return Icons.favorite_outline;
      case 'event_organizer':
        return Icons.event_outlined;
      case 'community':
        return Icons.groups_outlined;
      case 'government':
        return Icons.account_balance_outlined;
      case 'institution':
        return Icons.school_outlined;
      default:
        return Icons.work_outline;
    }
  }
}
