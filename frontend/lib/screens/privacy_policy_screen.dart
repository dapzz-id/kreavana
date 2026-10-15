import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../features/auth/services/auth_service.dart';
import '../widgets/desktop_sidebar_layout.dart';
import '../widgets/app_breadcrumbs.dart';
import 'main_navigation.dart';
import 'pengaturan_screen.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  final UserModel? user;
  const PrivacyPolicyScreen({super.key, this.user});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    if (_user == null) {
      _loadUser();
    }
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getCurrentUser();
    if (mounted && user != null) {
      setState(() => _user = user);
    }
  }

  static const _sections = [
    {
      'title': '1. Data yang Kami Kumpulkan',
      'body':
          'Kami mengumpulkan data yang Anda berikan secara langsung, seperti nama, username, email, nomor telepon, alamat, data KTP saat pengajuan kreator, serta data penggunaan aplikasi seperti riwayat chat, transaksi, dan preferensi fitur.',
    },
    {
      'title': '2. Penggunaan Data',
      'body':
          'Data Anda digunakan untuk: (a) menyediakan dan mengelola layanan kolaborasi kreator-klien, (b) memproses transaksi dan dompet digital, (c) menghubungkan Anda dengan kreator atau klien lain, (d) meningkatkan pengalaman dan keamanan aplikasi, serta (e) mengirim notifikasi penting terkait layanan.',
    },
    {
      'title': '3. Berbagi Data',
      'body':
          'Kami hanya membagikan data Anda kepada pengguna lain sejauh diperlukan untuk fungsi inti layanan (misalnya nama dan nomor telepon saat kolaborasi). Kami tidak menjual data pribadi Anda kepada pihak ketiga mana pun.',
    },
    {
      'title': '4. Keamanan Data',
      'body':
          'Kami menerapkan enkripsi pada transmisi data, penyimpanan kata sandi yang ter-hash, serta kontrol akses berbasis peran. Meskipun demikian, tidak ada metode transmisi di internet yang 100% aman.',
    },
    {
      'title': '5. Retensi Data',
      'body':
          'Data pribadi disimpan selama akun Anda aktif. Jika Anda menghapus akun, data pribadi Anda akan dihapus sesuai ketentuan yang berlaku, kecuali data yang wajib disimpan karena kewajiban hukum.',
    },
    {
      'title': '6. Hak Anda',
      'body':
          'Anda berhak mengakses, memperbarui, atau menghapus data pribadi Anda melalui menu Profil dan Pengaturan. Anda juga dapat meminta salinan data atau menarik persetujuan kapan saja dengan menghubungi support@kreavana.id.',
    },
    {
      'title': '7. Perubahan Kebijakan',
      'body':
          'Kebijakan ini dapat diperbarui sewaktu-waktu. Perubahan signifikan akan diinformasikan melalui notifikasi dalam aplikasi atau email.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    final content = Scaffold(
      backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
      appBar: AppBar(
        automaticallyImplyLeading: !isDesktop && Navigator.canPop(context),
        toolbarHeight: isDesktop ? 80 : 70,
        titleSpacing: isDesktop ? 32 : 16,
        elevation: 0,
        title: const Text(
          'Kebijakan Privasi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 960 : double.infinity,
          ),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 32 : 20,
              16,
              isDesktop ? 32 : 20,
              40,
            ),
            children: [
              // ── Breadcrumbs ──────────────────────────────────────────
              AppBreadcrumbs(
                items: [
                  BreadcrumbItem(
                    label: 'Beranda',
                    icon: Icons.home_rounded,
                    onTap: () {
                      if (_user != null) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MainNavigation(
                              initialUser: _user!,
                              initialIndex: 0,
                            ),
                          ),
                          (r) => false,
                        );
                      }
                    },
                  ),
                  BreadcrumbItem(
                    label: 'Pengaturan',
                    icon: Icons.settings_rounded,
                    onTap: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else if (_user != null) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PengaturanScreen(user: _user),
                          ),
                        );
                      }
                    },
                  ),
                  const BreadcrumbItem(
                    label: 'Kebijakan Privasi',
                    icon: Icons.privacy_tip_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
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
                    const Icon(
                      Icons.privacy_tip_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kebijakan Privasi Kreavana',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Terakhir diperbarui: Januari 2026',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Kreavana berkomitmen melindungi privasi Anda. Kebijakan ini menjelaskan bagaimana kami mengumpulkan, menggunakan, dan melindungi data pribadi Anda saat menggunakan aplikasi Kreavana.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                ),
              ),
              const SizedBox(height: 22),
              ..._sections.map(
                (s) => Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardBg : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color:
                          isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s['title']!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s['body']!,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.6,
                          color: isDark
                              ? AppTheme.textMuted
                              : AppTheme.textMutedLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '© 2026 Kreavana ID · support@kreavana.id',
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (isDesktop && _user != null) {
      return DesktopSidebarLayout(
        user: _user!,
        activeRoute: 'pengaturan',
        child: content,
      );
    }

    return content;
  }
}
