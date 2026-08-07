import 'package:flutter/material.dart';
import '../app/theme.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String iconName;
  final Color accentColor;
  final String? trend;
  final bool trendUp;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.iconName,
    required this.accentColor,
    this.trend,
    this.trendUp = true,
  });

  IconData _getIconData(String name) {
    switch (name.toLowerCase()) {
      case 'work':
      case 'explore':
        return Icons.work_outline;
      case 'people':
      case 'store':
        return Icons.people_outline;
      case 'star':
      case 'rating':
        return Icons.star_outline_rounded;
      case 'check':
      case 'done_all':
      case 'check_circle':
        return Icons.check_circle_outline;
      case 'inbox':
        return Icons.inbox_outlined;
      case 'pending':
        return Icons.pending_actions_outlined;
      case 'event':
      case 'event_note':
        return Icons.event_note_outlined;
      case 'favorite':
        return Icons.favorite_border;
      case 'school':
        return Icons.school_outlined;
      case 'business':
        return Icons.business_outlined;
      case 'gavel':
        return Icons.gavel_outlined;
      case 'groups':
        return Icons.groups_outlined;
      case 'corporate_fare':
        return Icons.corporate_fare_outlined;
      case 'handshake':
        return Icons.handshake_outlined;
      case 'campaign':
        return Icons.campaign_outlined;
      case 'wallet':
        return Icons.account_balance_wallet_outlined;
      case 'trending_up':
        return Icons.trending_up;
      default:
        return Icons.bar_chart_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 360;

    return Container(
      padding: EdgeInsets.all(isCompact ? 10 : 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight,
          width: 1,
        ),
        boxShadow: isDark ? null : AppTheme.cardShadowLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isCompact ? 10 : 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: EdgeInsets.all(isCompact ? 5 : 7),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Icon(
                  _getIconData(iconName),
                  size: isCompact ? 14 : 16,
                  color: accentColor,
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 8 : 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isCompact ? 16 : 20,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          if (trend != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  trendUp ? Icons.trending_up : Icons.trending_down,
                  size: 12,
                  color: trendUp ? AppTheme.success : AppTheme.error,
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    trend!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: trendUp ? AppTheme.success : AppTheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
