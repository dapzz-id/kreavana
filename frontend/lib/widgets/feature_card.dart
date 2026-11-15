import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/opportunity_model.dart';

class FeatureCard extends StatelessWidget {
  final OpportunityModel opportunity;
  final VoidCallback? onTap;
  final Color accentColor;
  final EdgeInsetsGeometry? margin;

  const FeatureCard({
    super.key,
    required this.opportunity,
    required this.accentColor,
    this.onTap,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Filter and deduplicate requirements
    final distinctRequirements = <String>{};
    final validRequirements = opportunity.requirements.where((r) {
      final slug = r.subRoleSlug.toLowerCase().trim();
      final label = r.label.trim();
      if (slug == 'kualifikasi' || label.toLowerCase().startsWith('kualifikasi')) {
        return false;
      }
      return distinctRequirements.add(label);
    }).toList();

    // Clean tags: strip '#' and truncate if needed, avoid duplicate tags
    final cleanTags = <String>[];
    for (final raw in opportunity.allTags) {
      final cleaned = raw.replaceAll('#', '').trim();
      if (cleaned.isNotEmpty &&
          !cleanTags.contains(cleaned) &&
          !distinctRequirements.contains(cleaned)) {
        cleanTags.add(cleaned);
      }
      if (cleanTags.length >= 2) break;
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight,
          width: 1,
        ),
        boxShadow: isDark ? null : AppTheme.cardShadowLight,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                // ── Header row ─────────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getSubRoleIcon(opportunity.subRoleSlug),
                        color: accentColor,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3.5,
                          ),
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
                              letterSpacing: 0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    if (opportunity.budgetRange != null &&
                        opportunity.budgetRange!.trim().isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.success.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          opportunity.budgetRange!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.success,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),

                // ── Title ──────────────────────────────────────────────────
                Text(
                  opportunity.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    height: 1.25,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                if (opportunity.description != null &&
                    opportunity.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    opportunity.description!.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark
                          ? AppTheme.textMuted
                          : AppTheme.textMutedLight,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 8),

                // ── Clean Multi-Role & Skills Badges ───────────────────────
                if (validRequirements.isNotEmpty || cleanTags.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      ...validRequirements.take(2).map((r) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            r.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                            ),
                          ),
                        );
                      }),
                      if (validRequirements.length > 2)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF262338) : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '+${validRequirements.length - 2} lainnya',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white60 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ...cleanTags.take(2).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF221F35) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white70 : Colors.grey.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                  ),
                ],

                // ── Spacer to ALWAYS pin Footer inside the bottom of card ──
                const Spacer(),

                // ── Divider ────────────────────────────────────────────────
                Divider(
                  color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                  height: 1,
                ),
                const SizedBox(height: 8),

                // ── Footer ─────────────────────────────────────────────────
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 13,
                      color: isDark
                          ? AppTheme.textMuted
                          : AppTheme.textMutedLight,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        (opportunity.location != null && opportunity.location!.trim().isNotEmpty)
                            ? opportunity.location!.trim()
                            : 'Indonesia',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppTheme.textMuted
                              : AppTheme.textMutedLight,
                        ),
                      ),
                    ),
                    if (opportunity.deadline != null && opportunity.deadline!.trim().isNotEmpty) ...[
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 12,
                        color: isDark
                            ? AppTheme.textMuted
                            : AppTheme.textMutedLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        opportunity.deadline!.trim(),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppTheme.textMuted
                              : AppTheme.textMutedLight,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
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
        .map(
          (w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '',
        )
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
      case 'drone_pilot':
        return Icons.airplanemode_active_outlined;
      case 'content':
      case 'content_creator':
        return Icons.phone_android_outlined;
      case 'mc':
        return Icons.mic_outlined;
      case 'singer':
      case 'musician':
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
