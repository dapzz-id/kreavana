import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../app/app_animations.dart';

/// Status tiap milestone.
enum MilestoneStatus { completed, active, pending }

class Milestone {
  final String title;
  final String? description;
  final MilestoneStatus status;
  final DateTime? dueDate;

  const Milestone({
    required this.title,
    this.description,
    this.status = MilestoneStatus.pending,
    this.dueDate,
  });

  bool get isDone => status == MilestoneStatus.completed;
  bool get isActive => status == MilestoneStatus.active;
}

/// Animated milestone tracker — garis progres animasi + ikon bertahap.
/// Siap dipakai di detail proyek / kontrak.
class MilestoneTracker extends StatelessWidget {
  final List<Milestone> milestones;
  final double dotSize;

  const MilestoneTracker({
    super.key,
    required this.milestones,
    this.dotSize = 34,
  });

  @override
  Widget build(BuildContext context) {
    if (milestones.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final doneCount = milestones.where((m) => m.isDone).length;
    final progress = doneCount / milestones.length.clamp(1, milestones.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Milestone Proyek',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              '$doneCount/${milestones.length} selesai',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryPurple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: AppMotion.slow,
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: isDark ? const Color(0xFF2D2A3E) : Colors.grey.shade200,
              color: AppTheme.primaryPurple,
            ),
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < milestones.length; i++) ...[
          _buildMilestoneRow(i, context),
          if (i < milestones.length - 1)
            _buildConnector(i, context),
        ],
      ],
    );
  }

  Widget _buildConnector(int index, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final done = milestones[index].isDone;
    return Container(
      margin: EdgeInsets.only(left: dotSize / 2 - 1.5),
      width: 3,
      height: 28,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: done
              ? [AppTheme.primaryPurple, AppTheme.primaryPurple]
              : [
                  isDark ? const Color(0xFF2D2A3E) : Colors.grey.shade300,
                  isDark ? const Color(0xFF2D2A3E) : Colors.grey.shade300,
                ],
        ),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildMilestoneRow(int index, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final m = milestones[index];

    return AnimatedEntrance(
      duration: AppMotion.normal,
      delay: Duration(milliseconds: 90 * index),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MilestoneDot(
            size: dotSize,
            status: m.status,
            isDark: isDark,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          m.title,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: m.isActive || m.isDone
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: m.isDone
                                ? (isDark
                                    ? Colors.white70
                                    : Colors.grey.shade600)
                                : Theme.of(context).colorScheme.onSurface,
                            decoration: m.isDone
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: isDark
                                ? Colors.white38
                                : Colors.grey.shade500,
                          ),
                        ),
                      ),
                      if (m.dueDate != null)
                        Text(
                          _formatDate(m.dueDate!),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppTheme.textMuted
                                : AppTheme.textMutedLight,
                          ),
                        ),
                    ],
                  ),
                  if (m.description != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      m.description!,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color:
                            isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}

class _MilestoneDot extends StatelessWidget {
  final double size;
  final MilestoneStatus status;
  final bool isDark;

  const _MilestoneDot({
    required this.size,
    required this.status,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    final Widget icon;
    switch (status) {
      case MilestoneStatus.completed:
        color = AppTheme.success;
        icon = Icon(Icons.check_rounded, color: Colors.white, size: size * 0.55);
        break;
      case MilestoneStatus.active:
        color = AppTheme.primaryPurple;
        icon = Icon(Icons.circle, color: Colors.white, size: size * 0.3);
        break;
      case MilestoneStatus.pending:
        color = isDark ? const Color(0xFF2D2A3E) : Colors.grey.shade300;
        icon = Icon(Icons.circle,
            color: isDark ? const Color(0xFF3D3A52) : Colors.white,
            size: size * 0.32);
        break;
    }

    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: AppMotion.normal,
          curve: AppMotion.spring,
          builder: (context, t, _) => Transform.scale(
            scale: t,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: status != MilestoneStatus.pending
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Center(child: icon),
            ),
          ),
        ),
      ],
    );
  }
}