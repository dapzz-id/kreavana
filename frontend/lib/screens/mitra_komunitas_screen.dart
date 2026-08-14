import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../models/user_model.dart';
import '../widgets/desktop_sidebar_layout.dart';

class MitraKomunitasScreen extends StatelessWidget {
  final UserModel? user;
  final ValueChanged<UserModel>? onUserUpdated;

  const MitraKomunitasScreen({super.key, this.user, this.onUserUpdated});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final mitra = [
      {'name': 'Komunitas Kreator Indonesia', 'members': '2.450', 'category': 'Komunitas', 'color': Color(0xFFEC4899)},
      {'name': 'Asosiasi Videografer Nasional', 'members': '1.230', 'category': 'Asosiasi', 'color': Color(0xFF3B82F6)},
      {'name': 'Jejaring UMKM Digital', 'members': '5.680', 'category': 'UMKM', 'color': Color(0xFF10B981)},
      {'name': 'Forum Desainer Indonesia', 'members': '3.120', 'category': 'Komunitas', 'color': Color(0xFF8B5CF6)},
      {'name': 'Koperasi Kreator Nusantara', 'members': '890', 'category': 'Koperasi', 'color': Color(0xFFF59E0B)},
    ];

    final content = Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: const Text('Mitra & Komunitas', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: mitra.length,
        itemBuilder: (context, index) {
          final m = mitra[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardBg : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: (m['color'] as Color).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.groups_outlined, color: m['color'] as Color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text('${m['category']} · ${m['members']} anggota', style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMuted : Colors.grey.shade600)),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('Gabung', style: TextStyle(fontSize: 11)),
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
        activeRoute: 'mitra_komunitas',
        onUserUpdated: onUserUpdated,
        child: content,
      );
    }

    return content;
  }
}
