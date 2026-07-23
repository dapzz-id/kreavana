import 'package:flutter/material.dart';
import '../app/theme.dart';

class MarketplaceKaryaScreen extends StatelessWidget {
  const MarketplaceKaryaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final items = [
      {'title': 'Paket Foto Produk Premium', 'creator': 'Aruna Studio', 'price': 'Rp 1.500.000', 'category': 'Fotografi', 'rating': '4.9', 'gradient': [const Color(0xFF667EE7), const Color(0xFF764BA2)]},
      {'title': 'Video Profil Usaha 1 Menit', 'creator': 'Frame Story', 'price': 'Rp 3.000.000', 'category': 'Videografi', 'rating': '4.8', 'gradient': [const Color(0xFFF093FB), const Color(0xFFF5576C)]},
      {'title': 'Paket Desain Logo & Branding', 'creator': 'Graphix Studio', 'price': 'Rp 2.000.000', 'category': 'Desain', 'rating': '4.9', 'gradient': [const Color(0xFF4FACFE), const Color(0xFF00F2FE)]},
      {'title': 'Konten Sosial Media 30 Hari', 'creator': 'Kreasi Konten ID', 'price': 'Rp 4.500.000', 'category': 'Konten', 'rating': '4.7', 'gradient': [const Color(0xFF43E97B), const Color(0xFF38F9D7)]},
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: const Text('Marketplace Karya', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.75),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardBg : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: item['gradient'] as List<Color>),
                    ),
                    child: Center(
                      child: Icon(Icons.photo_library_outlined, color: Colors.white.withValues(alpha: 0.5), size: 36),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppTheme.primaryPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text(item['category'] as String, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.primaryPurple)),
                        ),
                        const SizedBox(height: 6),
                        Text(item['title'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(item['creator'] as String, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : Colors.grey.shade600)),
                        const Spacer(),
                        Row(
                          children: [
                            Icon(Icons.star, size: 12, color: Colors.amber.shade600),
                            const SizedBox(width: 3),
                            Text(item['rating'] as String, style: const TextStyle(fontSize: 11)),
                            const Spacer(),
                            Text(item['price'] as String, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                          ],
                        ),
                      ],
                    ),
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
