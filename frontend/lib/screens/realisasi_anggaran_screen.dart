import 'package:flutter/material.dart';
import '../../app/theme.dart';

class RealisasiAnggaranScreen extends StatelessWidget {
  const RealisasiAnggaranScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final data = [
      {'name': 'Publikasi & Informasi', 'pagu': 'Rp 4.500.000.000', 'realisasi': 'Rp 2.350.000.000', 'percent': 52, 'color': Color(0xFF3B82F6)},
      {'name': 'Edukasi & Sosialisasi', 'pagu': 'Rp 3.600.000.000', 'realisasi': 'Rp 1.620.000.000', 'percent': 45, 'color': Color(0xFF10B981)},
      {'name': 'Ekonomi Kreatif', 'pagu': 'Rp 2.400.000.000', 'realisasi': 'Rp 1.100.000.000', 'percent': 46, 'color': Color(0xFFF59E0B)},
      {'name': 'Event & Pariwisata', 'pagu': 'Rp 1.850.000.000', 'realisasi': 'Rp 820.000.000', 'percent': 44, 'color': Color(0xFFEF4444)},
      {'name': 'Lainnya', 'pagu': 'Rp 500.000.000', 'realisasi': 'Rp 350.000.000', 'percent': 70, 'color': Colors.grey},
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: const Text('Realisasi Anggaran', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardBg : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ringkasan Anggaran 2025', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStat('Pagu Total', 'Rp 12.850.000.000', isDark),
                      const SizedBox(width: 16),
                      _buildStat('Terealisasi', 'Rp 6.240.000.000', isDark),
                      const SizedBox(width: 16),
                      _buildStat('Persentase', '48.5%', isDark),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...data.map((d) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardBg : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: d['color'] as Color, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(d['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                      Text('${d['percent']}%', style: TextStyle(fontWeight: FontWeight.bold, color: d['color'] as Color)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (d['percent'] as int) / 100,
                      minHeight: 8,
                      backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(d['color'] as Color),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Pagu: ${d['pagu']}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : Colors.grey.shade500)),
                      Text('Realisasi: ${d['realisasi']}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : Colors.grey.shade500)),
                    ],
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : Colors.grey.shade500)),
        ],
      ),
    );
  }
}
