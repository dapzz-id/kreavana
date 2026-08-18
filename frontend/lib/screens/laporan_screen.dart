import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../widgets/desktop_sidebar_layout.dart';

import '../widgets/ai_report_summary_widget.dart';

class LaporanScreen extends StatelessWidget {
  final UserModel? user;
  final ValueChanged<UserModel>? onUserUpdated;

  const LaporanScreen({super.key, this.user, this.onUserUpdated});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final reports = [
      {
        'title': 'Ringkasan Pengeluaran',
        'subtitle': 'Total pengeluaran bulan ini',
        'value': 'Rp 12.750.000',
        'icon': Icons.account_balance_wallet_outlined,
        'color': const Color(0xFF3B82F6),
      },
      {
        'title': 'Proyek Aktif',
        'subtitle': 'Proyek yang sedang berjalan',
        'value': '6 Proyek',
        'icon': Icons.folder_open,
        'color': const Color(0xFF10B981),
      },
      {
        'title': 'Proposal Terkirim',
        'subtitle': 'Total proposal bulan ini',
        'value': '12 Proposal',
        'icon': Icons.mail_outline,
        'color': const Color(0xFF7C3AED),
      },
      {
        'title': 'Rating Kreator',
        'subtitle': 'Rata-rata rating dari kreator',
        'value': '4.8 / 5.0',
        'icon': Icons.star_outline,
        'color': const Color(0xFFF59E0B),
      },
      {
        'title': 'Transaksi Selesai',
        'subtitle': 'Pembayaran berhasil',
        'value': '18 Transaksi',
        'icon': Icons.check_circle_outline,
        'color': const Color(0xFF14B8A6),
      },
    ];

    final content = Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: const Text(
          'Laporan',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: reports.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const AiReportSummaryWidget(
              title: 'Laporan Performa & Keuangan Bulanan',
              content:
                  'Laporan evaluasi pengeluaran, proyek aktif, dan performa kreator periode berjalan.',
              contextType: 'laporan_bulanan',
            );
          }
          final r = reports[index - 1];
          final color = r['color'] as Color;
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardBg : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    (r['icon'] as IconData?) ?? Icons.image_outlined,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r['title'] as String,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        r['subtitle'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.textMuted
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  r['value'] as String,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
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
        activeRoute: 'laporan',
        onUserUpdated: onUserUpdated,
        child: content,
      );
    }

    return content;
  }
}
