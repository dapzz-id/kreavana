import 'package:flutter/material.dart';
import '../app/theme.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String iconName;
  final Color accentColor;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.iconName,
    required this.accentColor,
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
      default:
        return Icons.bar_chart_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Deteksi layar kecil (seperti iPhone SE) untuk menyesuaikan layout
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 360;

    return Container(
      padding: EdgeInsets.all(isCompact ? 10 : 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: !isDark
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isCompact ? 11 : 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.all(isCompact ? 4 : 6),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIconData(iconName),
                  size: isCompact ? 14 : 16,
                  color: accentColor,
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 6 : 12),
          Text(
            value,
            style: TextStyle(
              fontSize: isCompact ? 18 : 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}
