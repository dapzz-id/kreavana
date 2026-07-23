import 'package:flutter/material.dart';
import '../app/theme.dart';

class UlasanReputasiScreen extends StatelessWidget {
  const UlasanReputasiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final reviews = [
      {'name': 'Rina Sari', 'project': 'Foto Katalog Produk', 'rating': 5.0, 'comment': 'Hasil fotonya luar biasa! Produk jadi terlihat premium. Sangat puas dengan hasilnya.', 'date': '20 Mei 2026', 'avatar': Icons.person},
      {'name': 'Budi Santoso', 'project': 'Video Promosi Instagram', 'rating': 4.8, 'comment': 'Video yang dihasilkan sangat kreatif dan sesuai brand guideline. Pengiriman tepat waktu.', 'date': '18 Mei 2026', 'avatar': Icons.person},
      {'name': 'Maya Putri', 'project': 'Desain Poster Campaign', 'rating': 4.9, 'comment': 'Desainnya modern dan eye-catching. Komunikasi selama proyek berjalan sangat baik.', 'date': '15 Mei 2026', 'avatar': Icons.person},
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: const Text('Ulasan & Reputasi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.primaryPurple, AppTheme.deepPurple]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('4.9', 'Rating', Icons.star_outline),
                _buildStat('24', 'Ulasan', Icons.reviews_outlined),
                _buildStat('98%', 'Tepat Wschedule', Icons.check_circle_outline),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: reviews.length,
              itemBuilder: (context, index) {
                final r = reviews[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardBg : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(radius: 20, backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.1), child: Icon(r['avatar'] as IconData, color: AppTheme.primaryPurple, size: 20)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), Text(r['project'] as String, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : Colors.grey.shade500))])),
                          Row(children: [Icon(Icons.star, size: 14, color: Colors.amber.shade600), const SizedBox(width: 3), Text('${r['rating']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(r['comment'] as String, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey.shade700, height: 1.5)),
                      const SizedBox(height: 6),
                      Text(r['date'] as String, style: TextStyle(fontSize: 10, color: isDark ? AppTheme.textMuted : Colors.grey.shade500)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}
