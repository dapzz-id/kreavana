import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app/theme.dart';
import '../app/app_animations.dart';
import '../utils/app_errors.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  static const _faqs = [
    {
      'q': 'Bagaimana cara membuat akun di Kreavana?',
      'a': 'Buka halaman login lalu pilih "Daftar". Isi nama, username, email, dan kata sandi, lalu tekan tombol Daftar. Akun Anda siap digunakan untuk mencari karya atau kreator.',
    },
    {
      'q': 'Bagaimana cara menjadi kreator terverifikasi?',
      'a': 'Masuk ke menu Profil lalu ajukan pengajuan kreator. Lengkapi data KTP, sub-kategori keahlian, dan portofolio. Admin akan meninjau pengajuan Anda.',
    },
    {
      'q': 'Bagaimana cara membuat kebutuhan proyek?',
      'a': 'Dari dashboard, tekan tombol "Buat Kebutuhan". Isi judul, kategori, deskripsi, dan budget. Kebutuhan Anda akan muncul untuk kreator yang cocok.',
    },
    {
      'q': 'Bagaimana cara menjual karya di Marketplace?',
      'a': 'Buka menu Marketplace, lalu tekan tombol "Jual Karya". Isi judul, kategori, harga, dan deskripsi karya Anda. Karya langsung tampil untuk klien.',
    },
    {
      'q': 'Bagaimana cara menghubungi kreator / klien?',
      'a': 'Buka halaman Kontak atau detail karya/kebutuhan, lalu tekan tombol Chat. Anda juga bisa melakukan telepon atau video call melalui tombol telepon.',
    },
    {
      'q': 'Bagaimana cara menarik dana dari dompet?',
      'a': 'Buka menu Dompet, lalu pilih "Tarik Dana". Pastikan Anda sudah menambahkan metode pembayaran (bank / e-wallet) di menu Pengaturan > Metode Pembayaran.',
    },
  ];

  Future<void> _launch(String url) async {
    try {
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        AppSnackbar.error(context, 'Tidak dapat membuka tautan.');
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppErrors.friendly(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
      appBar: AppBar(
        toolbarHeight: 70,
        title: const Text('Bantuan & Dukungan', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          AnimatedEntrance(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryPurple, AppTheme.deepPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(Icons.support_agent_rounded, color: Colors.white, size: 36),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Butuh bantuan?',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 3),
                        Text(
                          'Tim dukungan kami siap membantu Anda setiap hari pukul 08.00 - 21.00 WIB.',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          AnimatedEntrance(
            delay: const Duration(milliseconds: 80),
            child: Text('PERTANYAAN UMUM',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                )),
          ),
          const SizedBox(height: 10),
          ..._faqs.asMap().entries.map((entry) {
            final i = entry.key;
            final faq = entry.value;
            return AnimatedEntrance(
              delay: Duration(milliseconds: 120 + i * 60),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardBg : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    leading: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.help_outline, color: AppTheme.primaryPurple, size: 17),
                    ),
                    title: Text(faq['q']!, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(faq['a']!,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.5,
                              color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                            )),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          AnimatedEntrance(
            delay: const Duration(milliseconds: 400),
            child: Text('HUBUNGI KAMI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                )),
          ),
          const SizedBox(height: 10),
          AnimatedEntrance(
            delay: const Duration(milliseconds: 460),
            child: _contactCard(
              isDark: isDark,
              icon: Icons.chat_rounded,
              color: const Color(0xFF25D366),
              title: 'WhatsApp',
              subtitle: 'Respons tercepat • chat langsung',
              onTap: () => _launch('https://wa.me/6281234567890?text=Halo%20Kreavana%2C%20saya%20butuh%20bantuan'),
            ),
          ),
          const SizedBox(height: 10),
          AnimatedEntrance(
            delay: const Duration(milliseconds: 520),
            child: _contactCard(
              isDark: isDark,
              icon: Icons.email_outlined,
              color: const Color(0xFF3B82F6),
              title: 'Email',
              subtitle: 'support@kreavana.id • balasan 1x24 jam',
              onTap: () => _launch('mailto:support@kreavana.id'),
            ),
          ),
          const SizedBox(height: 10),
          AnimatedEntrance(
            delay: const Duration(milliseconds: 580),
            child: _contactCard(
              isDark: isDark,
              icon: Icons.camera_alt_outlined,
              color: const Color(0xFFE1306C),
              title: 'Instagram',
              subtitle: '@kreavana.id • tips & pengumuman',
              onTap: () => _launch('https://instagram.com/kreavana.id'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactCard({
    required bool isDark,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isDark ? AppTheme.cardBg : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: isDark ? AppTheme.textMuted : Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
