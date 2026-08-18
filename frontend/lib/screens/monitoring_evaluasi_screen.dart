import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../models/user_model.dart';
import '../widgets/desktop_sidebar_layout.dart';

class MonitoringEvaluasiScreen extends StatelessWidget {
  final UserModel? user;
  final ValueChanged<UserModel>? onUserUpdated;

  const MonitoringEvaluasiScreen({super.key, this.user, this.onUserUpdated});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final programs = [
      {
        'title': 'Festival Kreativitas Pemuda 2025',
        'progress': 0.72,
        'status': 'Berjalan',
        'color': Color(0xFF10B981),
      },
      {
        'title': 'Sosialisasi Literasi Digital',
        'progress': 0.85,
        'status': 'Berjalan',
        'color': Color(0xFF10B981),
      },
      {
        'title': 'Lomba Konten Promosi Daerah',
        'progress': 0.45,
        'status': 'Dalam Review',
        'color': Color(0xFFF59E0B),
      },
      {
        'title': 'Pelatihan Fotografi Dasar',
        'progress': 0.15,
        'status': 'Akan Datang',
        'color': Color(0xFF3B82F6),
      },
      {
        'title': 'Pengelolaan Media Sosial',
        'progress': 0.95,
        'status': 'Hampir Selesai',
        'color': Color(0xFF10B981),
      },
    ];

    final content = Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: const Text(
          'Monitoring & Evaluasi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: programs.length,
        itemBuilder: (context, index) {
          final p = programs[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardBg : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        p['title'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: (p['color'] as Color).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        p['status'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: p['color'] as Color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: p['progress'] as double,
                          minHeight: 8,
                          backgroundColor: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(
                            p['color'] as Color,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${((p['progress'] as double) * 100).round()}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Dokumentasi: ${((p['progress'] as double) * 100).round()}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.textMuted
                            : Colors.grey.shade500,
                      ),
                    ),
                    Text(
                      'Laporan: ${((p['progress'] as double) * 100).round()}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.textMuted
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    if (user != null) {
      return DesktopSidebarLayout(
        user: user!,
        activeRoute: 'monitoring_evaluasi',
        onUserUpdated: onUserUpdated,
        child: content,
      );
    }

    return content;
  }
}
