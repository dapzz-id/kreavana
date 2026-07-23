import 'package:flutter/material.dart';
import '../app/theme.dart';

class KolaborasiScreen extends StatelessWidget {
  const KolaborasiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final collabs = [
      {'name': 'Aruna Studio', 'role': 'Fotografer', 'project': 'Foto Katalog Produk', 'status': 'Aktif', 'statusColor': const Color(0xFF10B981)},
      {'name': 'Frame Story', 'role': 'Videografer', 'project': 'Video Promosi Instagram', 'status': 'Menunggu', 'statusColor': const Color(0xFFF59E0B)},
      {'name': 'Graphix Studio', 'role': 'Desainer', 'project': 'Desain Poster Campaign', 'status': 'Selesai', 'statusColor': const Color(0xFF3B82F6)},
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: const Text('Kolaborasi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: collabs.length,
        itemBuilder: (context, index) {
          final c = collabs[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardBg : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.1),
                  child: Icon(Icons.person_outline, color: AppTheme.primaryPurple),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c['name'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('${c['role']} • ${c['project']}', style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMuted : Colors.grey.shade600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: (c['statusColor'] as Color).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text(c['status'] as String, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c['statusColor'] as Color)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
