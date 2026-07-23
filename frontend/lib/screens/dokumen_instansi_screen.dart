import 'package:flutter/material.dart';
import '../../app/theme.dart';

class DokumenInstansiScreen extends StatelessWidget {
  const DokumenInstansiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final dokumen = [
      {'name': 'SK Pendirian Instansi.pdf', 'size': '2.4 MB', 'date': '15 Jan 2025', 'icon': Icons.description_outlined, 'color': Color(0xFFEF4444)},
      {'name': 'Rencana Kerja Tahunan 2025.pdf', 'size': '5.1 MB', 'date': '10 Feb 2025', 'icon': Icons.article_outlined, 'color': Color(0xFF3B82F6)},
      {'name': 'Laporan Keuangan Q1.pdf', 'size': '3.8 MB', 'date': '1 Apr 2025', 'icon': Icons.receipt_long_outlined, 'color': Color(0xFF10B981)},
      {'name': 'Dokumen Tender Pengadaan.pdf', 'size': '1.2 MB', 'date': '20 Mar 2025', 'icon': Icons.folder_outlined, 'color': Color(0xFFF59E0B)},
      {'name': 'SOP Pelaporan Kegiatan.pdf', 'size': '890 KB', 'date': '5 Jan 2025', 'icon': Icons.menu_book_outlined, 'color': Color(0xFF8B5CF6)},
      {'name': 'Surat Edaran Internal.pdf', 'size': '450 KB', 'date': '12 Jun 2025', 'icon': Icons.mail_outline, 'color': Colors.grey},
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: const Text('Dokumen Instansi', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.add_circle_outline)),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: dokumen.length,
        itemBuilder: (context, index) {
          final d = dokumen[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardBg : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: (d['color'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(d['icon'] as IconData, color: d['color'] as Color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text('${d['size']} · ${d['date']}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : Colors.grey.shade500)),
                    ],
                  ),
                ),
                IconButton(onPressed: () {}, icon: Icon(Icons.download_outlined, size: 20, color: isDark ? AppTheme.textMuted : Colors.grey.shade600)),
              ],
            ),
          );
        },
      ),
    );
  }
}
