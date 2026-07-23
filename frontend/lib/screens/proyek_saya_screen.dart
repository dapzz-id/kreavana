import 'package:flutter/material.dart';
import '../app/theme.dart';

class ProyekSayaScreen extends StatelessWidget {
  const ProyekSayaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final projects = [
      {'title': 'Foto Katalog Produk', 'status': 'Berjalan', 'statusColor': const Color(0xFF10B981), 'creator': 'Aruna Studio', 'progress': 0.65, 'deadline': '28 Mei 2026'},
      {'title': 'Video Promosi Instagram', 'status': 'Menunggu', 'statusColor': const Color(0xFFF59E0B), 'creator': 'Frame Story', 'progress': 0.0, 'deadline': '5 Juni 2026'},
      {'title': 'Desain Poster Campaign', 'status': 'Selesai', 'statusColor': const Color(0xFF3B82F6), 'creator': 'Graphix Studio', 'progress': 1.0, 'deadline': '15 Mei 2026'},
      {'title': 'Dokumentasi Event Komunitas', 'status': 'Berjalan', 'statusColor': const Color(0xFF10B981), 'creator': 'Kreasi Konten ID', 'progress': 0.35, 'deadline': '1 Juni 2026'},
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: const Text('Proyek Saya', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: projects.length,
        itemBuilder: (context, index) {
          final p = projects[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardBg : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(p['title'] as String, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: (p['statusColor'] as Color).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                      child: Text(p['status'] as String, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: p['statusColor'] as Color)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 14, color: isDark ? AppTheme.textMuted : Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(p['creator'] as String, style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMuted : Colors.grey.shade600)),
                    const Spacer(),
                    Icon(Icons.calendar_today_outlined, size: 14, color: isDark ? AppTheme.textMuted : Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(p['deadline'] as String, style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMuted : Colors.grey.shade600)),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: p['progress'] as double,
                    minHeight: 6,
                    backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(p['statusColor'] as Color),
                  ),
                ),
                const SizedBox(height: 6),
                Text('${((p['progress'] as double) * 100).toInt()}%', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : Colors.grey.shade500)),
              ],
            ),
          );
        },
      ),
    );
  }
}
