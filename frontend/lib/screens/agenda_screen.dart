import 'package:flutter/material.dart';
import '../app/theme.dart';

class AgendaScreen extends StatelessWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final agenda = [
      {'title': 'Meeting Briefing Proyek Foto', 'date': '24', 'month': 'Mei', 'time': '09:00 - 10:00 WIB', 'type': 'Online', 'typeColor': const Color(0xFF3B82F6), 'icon': Icons.videocam_outlined},
      {'title': 'Review Draft Desain Poster', 'date': '25', 'month': 'Mei', 'time': '14:00 - 15:00 WIB', 'type': 'Online', 'typeColor': const Color(0xFF3B82F6), 'icon': Icons.videocam_outlined},
      {'title': 'Shooting Day - Video Promosi', 'date': '27', 'month': 'Mei', 'time': '08:00 - 17:00 WIB', 'type': 'Offline', 'typeColor': const Color(0xFFF97316), 'icon': Icons.location_on_outlined},
      {'title': 'Deadline Penyerahan Hasil Akhir', 'date': '29', 'month': 'Mei', 'time': '23:59 WIB', 'type': 'Deadline', 'typeColor': const Color(0xFFEF4444), 'icon': Icons.alarm_outlined},
      {'title': 'Konsultasi Desain Banner', 'date': '02', 'month': 'Jun', 'time': '10:00 - 11:00 WIB', 'type': 'Online', 'typeColor': const Color(0xFF3B82F6), 'icon': Icons.videocam_outlined},
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: const Text('Agenda', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: agenda.length,
        itemBuilder: (context, index) {
          final item = agenda[index];
          final typeColor = item['typeColor'] as Color;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardBg : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item['date'] as String, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                      Text(item['month'] as String, style: TextStyle(fontSize: 10, color: AppTheme.primaryPurple, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['title'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(item['icon'] as IconData, size: 12, color: isDark ? AppTheme.textMuted : Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(item['time'] as String, style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMuted : Colors.grey.shade500)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Text(item['type'] as String, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: typeColor)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
