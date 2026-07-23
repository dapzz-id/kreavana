import 'package:flutter/material.dart';
import '../../app/theme.dart';

class PengumumanPublikScreen extends StatelessWidget {
  const PengumumanPublikScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final pengumuman = [
      {
        'title': 'Peluang Kolaborasi Terbuka!',
        'description': 'Instansi membuka peluang kolaborasi untuk program "Inovasi Layanan Publik 2025". Ayo berkolaborasi dan ciptakan dampak positif bersama!',
        'date': '18 Juli 2025',
        'type': 'Kolaborasi',
        'type_color': Color(0xFF3B82F6),
        'icon': Icons.campaign_outlined,
      },
      {
        'title': 'Lomba Konten Promosi Daerah',
        'description': 'Dibuka pendaftaran lomba konten promosi daerah tingkat nasional. Daftarkan karya terbaik Anda dan menangkan total hadiah Rp 50 Juta!',
        'date': '10 Juli 2025',
        'type': 'Lomba',
        'type_color': Color(0xFFEF4444),
        'icon': Icons.emoji_events_outlined,
      },
      {
        'title': 'Pelatihan Digital Marketing Gratis',
        'description': 'Diskominfo mengadakan pelatihan digital marketing untuk pelaku UMKM. Kuota terbatas, daftar sekarang!',
        'date': '5 Juli 2025',
        'type': 'Pelatihan',
        'type_color': Color(0xFF10B981),
        'icon': Icons.school_outlined,
      },
      {
        'title': 'Pengumuman Hasil Tender Q2',
        'description': 'Daftar pemenang tender pengadaan jasa kreatif Q2 2025 telah diumumkan. Silakan cek hasilnya di portal tender.',
        'date': '1 Juli 2025',
        'type': 'Pengumuman',
        'type_color': Color(0xFFF59E0B),
        'icon': Icons.info_outline,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: const Text('Pengumuman Publik', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: pengumuman.length,
        itemBuilder: (context, index) {
          final p = pengumuman[index];
          return Container(
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
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: (p['type_color'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: Icon(p['icon'] as IconData, color: p['type_color'] as Color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 10, color: isDark ? AppTheme.textMuted : Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(p['date'] as String, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : Colors.grey.shade500)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: (p['type_color'] as Color).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                                child: Text(p['type'] as String, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: p['type_color'] as Color)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(p['description'] as String, style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMuted : Colors.grey.shade600, height: 1.5)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text('Baca Selengkapnya', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
