import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/theme.dart';
import '../services/app_router.dart';
import '../services/opportunity_service.dart';
import '../services/api_service.dart';
import '../models/opportunity_model.dart';
import '../widgets/opportunity_detail_sheet.dart';

class LandingPageScreen extends StatefulWidget {
  const LandingPageScreen({super.key});

  @override
  State<LandingPageScreen> createState() => _LandingPageScreenState();
}

class _LandingPageScreenState extends State<LandingPageScreen> {
  bool _isLoading = true;
  List<OpportunityModel> _featuredOpportunities = [];
  Map<String, dynamic>? _liveStats;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final oppList = await OpportunityService.getOpportunities();
      final statsResult = await ApiService.get('dashboard/overview');

      if (mounted) {
        setState(() {
          _featuredOpportunities = oppList.take(4).toList();
          if (statsResult['status'] == true && statsResult['data'] != null) {
            _liveStats = statsResult['data'];
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: isDark ? AppTheme.cardBg : Colors.white,
        elevation: 1,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.teal, Color(0xFF0EA5E9)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'K',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            if (isDesktop) ...[
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'KREAVANA',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    'Pasar & Kolaborasi Kreatif',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          if (isDesktop) ...[
            TextButton(
              onPressed: () => context.go(AppRoutes.peluangProyek),
              child: const Text(
                'Peluang Proyek',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.explore),
              child: const Text(
                'Kreator',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
          ],
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.login),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(70, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Masuk'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => context.go(AppRoutes.register),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade600,
              foregroundColor: Colors.white,
              minimumSize: const Size(80, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Daftar'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32 : 16,
                vertical: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Hero Section ─────────────────────────────────────────
                  _buildHeroSection(context, isDark, isDesktop),
                  const SizedBox(height: 48),

                  // ── Live Stats (Real verified data only) ──────────────────
                  if (_liveStats != null) ...[
                    _buildLiveStats(isDark, isDesktop),
                    const SizedBox(height: 48),
                  ],

                  // ── How It Works (3 Steps) ───────────────────────────────
                  _buildWorkflowSection(isDark, isDesktop),
                  const SizedBox(height: 48),

                  // ── Featured Live Opportunities ──────────────────────────
                  _buildFeaturedOpportunities(context, isDark, isDesktop),
                  const SizedBox(height: 48),

                  // ── Categories & Tukang Kendang ──────────────────────────
                  _buildCategoriesSection(context, isDark),
                  const SizedBox(height: 48),

                  // ── Call to Action Banner ────────────────────────────────
                  _buildBottomCta(context, isDark, isDesktop),
                  const SizedBox(height: 32),

                  // ── Footer ──────────────────────────────────────────────
                  _buildFooter(isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, bool isDark, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 40 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [Colors.teal.shade50, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.teal.shade100,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, size: 16, color: Colors.teal.shade700),
                const SizedBox(width: 6),
                Text(
                  'Platform Kolaborasi Kreatif Terpercaya',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Temukan Talenta & Peluang Proyek Kreatif Tanpa Batas',
            style: TextStyle(
              fontSize: isDesktop ? 36 : 24,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Kreavana menghubungkan penyelenggara acara, instansi, dan bisnis dengan para kreator profesional — mulai dari Fotografer, Videografer, MC, hingga Seniman Tradisional seperti Tukang Kendang. Transparan, aman, dan tanpa biaya perantara tersembunyi.',
            style: TextStyle(
              fontSize: 15,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade800,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: () => context.go(AppRoutes.peluangProyek),
                icon: const Icon(Icons.work_outline, color: Colors.white),
                label: const Text(
                  'Jelajahi Peluang Proyek',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade600,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go(AppRoutes.explore),
                icon: const Icon(Icons.people_alt_outlined),
                label: const Text(
                  'Cari Kreator Berbakat',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStats(bool isDark, bool isDesktop) {
    final stats = _liveStats!;
    final totalOpportunities = stats['total_opportunities'] ?? 0;
    final totalCreators = stats['total_creators'] ?? 0;
    final totalContracts = stats['total_contracts'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _statCard('Peluang Terbuka', '$totalOpportunities Proyek', Icons.work, Colors.blue, isDark),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard('Kreator Terdaftar', '$totalCreators Talenta', Icons.groups, Colors.teal, isDark),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard('Kontrak Kolaborasi', '$totalContracts Berjalan', Icons.handshake, Colors.purple, isDark),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowSection(bool isDark, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bagaimana Kreavana Bekerja?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Alur transparan dan aman bagi pemilik proyek dan kreator profesional.',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 20),
        Flex(
          direction: isDesktop ? Axis.horizontal : Axis.vertical,
          children: [
            Expanded(
              flex: isDesktop ? 1 : 0,
              child: _workflowStep(
                step: '1',
                title: 'Pasang Kebutuhan Multi-Peran',
                desc: 'Tentukan jumlah talenta yang dibutuhkan (misal: 2 Fotografer, 1 MC, 1 Tukang Kendang) lengkap dengan anggaran transparan.',
                icon: Icons.post_add,
                isDark: isDark,
              ),
            ),
            SizedBox(width: isDesktop ? 16 : 0, height: isDesktop ? 0 : 16),
            Expanded(
              flex: isDesktop ? 1 : 0,
              child: _workflowStep(
                step: '2',
                title: 'Kreator Mengajukan Peluang',
                desc: 'Kreator memilih peran yang sesuai, melampirkan portofolio terverifikasi, dan mengajukan kesiapan waktu.',
                icon: Icons.how_to_reg,
                isDark: isDark,
              ),
            ),
            SizedBox(width: isDesktop ? 16 : 0, height: isDesktop ? 0 : 16),
            Expanded(
              flex: isDesktop ? 1 : 0,
              child: _workflowStep(
                step: '3',
                title: 'Review & Kontrak Resmi',
                desc: 'Pemilik proyek menyetujui pelamar secara selektif. Kontrak resmi diterbitkan demi keamanan hak kedua belah pihak.',
                icon: Icons.verified_user,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _workflowStep({
    required String step,
    required String title,
    required String desc,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.teal.shade600,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    step,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Icon(icon, color: Colors.teal.shade400, size: 24),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedOpportunities(
    BuildContext context,
    bool isDark,
    bool isDesktop,
  ) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_featuredOpportunities.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Peluang Proyek Terbaru',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.peluangProyek),
              child: const Row(
                children: [
                  Text('Lihat Semua'),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 16),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: _featuredOpportunities.map((opp) {
            return SizedBox(
              width: isDesktop ? 510 : double.infinity,
              child: Card(
                elevation: 0,
                color: isDark ? AppTheme.cardBg : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    OpportunityDetailSheet.show(
                      context,
                      opportunity: opp,
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                opp.subRoleLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade700,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (opp.budgetRange != null && opp.budgetRange!.isNotEmpty)
                              Text(
                                opp.budgetRange!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          opp.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          opp.description ?? 'Tidak ada deskripsi detail.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                opp.location ?? 'Indonesia',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              'Lihat Detail →',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCategoriesSection(BuildContext context, bool isDark) {
    final categories = [
      {'label': '🥁 Tukang Kendang & Musisi', 'slug': 'tukang_kendang'},
      {'label': '📸 Fotografer & Dokumentasi', 'slug': 'photographer'},
      {'label': '🎥 Videografer & Cinematographer', 'slug': 'videographer'},
      {'label': '🎤 Master of Ceremony (MC)', 'slug': 'mc'},
      {'label': '✂️ Editor & Post Production', 'slug': 'editor'},
      {'label': '💄 Makeup Artist (MUA)', 'slug': 'makeup_artist'},
      {'label': '🎪 Event & Wedding Organizer', 'slug': 'event_organizer'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kategori Talenta Kreatif',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: categories.map((c) {
            return ActionChip(
              label: Text(c['label']!),
              backgroundColor: isDark ? AppTheme.cardBg : Colors.white,
              side: BorderSide(
                color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
              ),
              onPressed: () {
                context.go(AppRoutes.explore);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBottomCta(BuildContext context, bool isDark, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 36 : 24),
      decoration: BoxDecoration(
        color: Colors.teal.shade700,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Siap Memulai Proyek Kreatif Anda?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Daftar gratis sekarang dan bangun kolaborasi luar biasa di seluruh penjuru negeri.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: () => context.go(AppRoutes.register),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.teal.shade900,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Daftar Sekarang',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Center(
      child: Text(
        '© 2026 Kreavana. Platform Kolaborasi & Ekosistem Kreatif Indonesia.',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
        ),
      ),
    );
  }
}
