import 'package:flutter/material.dart';
import 'dart:ui' show PointerDeviceKind;
import '../../../app/theme.dart';
import '../../../app/subrole_theme_engine.dart';
import '../../../models/user_model.dart';
import '../services/dashboard_service.dart';
import '../../../widgets/dashboard_stats_charts.dart';
import '../../../widgets/subrole_right_sidebar.dart';
import '../../../screens/explore_screen.dart';
import '../../../screens/global_search_screen.dart';
import '../../../screens/daftar_kebutuhan_screen.dart';
import '../../../screens/notifications_screen.dart';
import '../../../screens/direct_message_screen.dart';
import '../../../screens/buat_kebutuhan_screen.dart';
import '../../../screens/peluang_proyek_screen.dart';
import '../../../services/badge_service.dart';

class UmkmDashboardScreen extends StatefulWidget {
  final UserModel user;
  final ValueChanged<UserModel> onUserUpdated;

  const UmkmDashboardScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
  });

  @override
  State<UmkmDashboardScreen> createState() => _UmkmDashboardScreenState();
}

class _UmkmDashboardScreenState extends State<UmkmDashboardScreen> {
  final Color _accentColor = SubRoleThemeEngine.getAccentColor('user', 'umkm');
  bool _isLoading = true;
  List<Map<String, String>> _realtimeStats = [];
  Map<String, List<Map<String, String>>> _allSubRoleStats = {};

  @override
  void initState() {
    super.initState();
    _fetchRealtimeData();
  }
  Future<void> _fetchRealtimeData() async {
    try {
      final stats = await DashboardService.getStats(subRole: 'umkm', roleType: 'user');
      final allStats = await DashboardService.getAllSubRoleStats(
        subRoleSlugs: ['umkm', 'company', 'government', 'community', 'school'],
        roleType: 'user',
      );
      if (mounted) {
        setState(() {
          _realtimeStats = stats;
          _allSubRoleStats = allStats;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      appBar: _buildAppBar(isDark),
      body: RefreshIndicator(
        onRefresh: _fetchRealtimeData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 24 : 16,
            16,
            isDesktop ? 24 : 16,
            110,
          ),
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Content Left Column
                    Expanded(
                      flex: 7,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeroBanner(isDark),
                          const SizedBox(height: 24),
                          _buildMetricsRow(isDark),
                          const SizedBox(height: 24),
                          _buildChartSection(isDark),
                          const SizedBox(height: 24),
                          _buildPackagesSection(isDark),
                          const SizedBox(height: 24),
                          _buildActiveProjectsSection(isDark),
                          const SizedBox(height: 24),
                          _buildCreatorRosterSection(isDark),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Right Sidebar Column (Profile completeness, Quick Actions, AI Tips)
                    Expanded(
                      flex: 3,
                      child: SubRoleRightSidebar(
                        user: widget.user,
                        onUserUpdated: widget.onUserUpdated,
                        isDark: isDark,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroBanner(isDark),
                    const SizedBox(height: 24),
                    _buildMetricsRow(isDark),
                    const SizedBox(height: 24),
                    _buildChartSection(isDark),
                    const SizedBox(height: 24),
                    SubRoleRightSidebar(
                      user: widget.user,
                      onUserUpdated: widget.onUserUpdated,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 24),
                    _buildPackagesSection(isDark),
                    const SizedBox(height: 24),
                    _buildActiveProjectsSection(isDark),
                    const SizedBox(height: 24),
                    _buildCreatorRosterSection(isDark),
                  ],
                ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      toolbarHeight: 75,
      title: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GlobalSearchScreen(user: widget.user),
                ),
              ),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1830) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Icon(
                      Icons.search,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Cari kreator, paket foto UMKM, desain produk...',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.storefront_rounded, size: 16, color: _accentColor),
                const SizedBox(width: 6),
                Text(
                  'UMKM Hub',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _accentColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ListenableBuilder(
            listenable: BadgeService(),
            builder: (_, _) => _buildAppBarBadge(Icons.notifications_none_outlined, BadgeService().unreadNotificationsText, isDark),
          ),
          const SizedBox(width: 4),
          ListenableBuilder(
            listenable: BadgeService(),
            builder: (_, _) => _buildAppBarBadge(Icons.chat_bubble_outline, BadgeService().unreadMessagesText, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _accentColor,
            HSLColor.fromColor(_accentColor).withLightness(0.25).toColor(),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Akselerasi Produk Lokal',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Halo, ${widget.user.name}! 👋',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tingkatkan omzet UMKM Anda dengan katalog foto produk profesional, video Reels viral, dan desain kemasan siap jual.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExploreScreen(user: widget.user),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _accentColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: const Text('Buat Project Foto Produk', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              OutlinedButton.icon(
                onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => PeluangProyekScreen(user: widget.user))); },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.card_giftcard, size: 18),
                label: const Text('Klaim Subsidi Branding UMKM'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(bool isDark) {
    final metrics = _realtimeStats.isNotEmpty
        ? _realtimeStats.map((item) {
            return {
              'title': item['label'] ?? 'Metrik',
              'value': item['value'] ?? '0',
              'icon': Icons.insights_rounded,
              'change': 'Realtime API',
            };
          }).toList()
        : [
            {'title': 'Project Aktif', 'value': '3 Katalog', 'icon': Icons.inventory_2_outlined, 'change': '+1 bulan ini'},
            {'title': 'Kreator Terhubung', 'value': '8 Vendor', 'icon': Icons.people_outline, 'change': 'Rating avg 4.9'},
            {'title': 'Total Investasi', 'value': 'Rp 4.250.000', 'icon': Icons.account_balance_wallet_outlined, 'change': 'Escrow Terjamin'},
            {'title': 'Aset Selesai', 'value': '142 File HD', 'icon': Icons.cloud_download_outlined, 'change': 'Siap Pakai'},
          ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isMobile ? 2 : 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isMobile ? 1.4 : 1.6,
          ),
          itemBuilder: (context, index) {
            final m = metrics[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardBg : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _accentColor.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: _accentColor.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          m['title'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon((m['icon'] as IconData?) ?? Icons.image_outlined, color: _accentColor, size: 20),
                    ],
                  ),
                  Text(
                    m['value'] as String,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                  ),
                  Text(
                    m['change'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _accentColor,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChartSection(bool isDark) {
    final subRolesList = [
      {'slug': 'umkm', 'name': 'UMKM', 'color': _accentColor},
      {'slug': 'company', 'name': 'Perusahaan', 'color': Colors.blue},
      {'slug': 'government', 'name': 'Government', 'color': Colors.indigo},
      {'slug': 'community', 'name': 'Komunitas', 'color': Colors.cyan},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withValues(alpha: 0.2)),
      ),
      child: DashboardStatsCharts(
        subRoleList: subRolesList,
        allSubRoleStats: _allSubRoleStats,
        selectedSubRole: 'umkm',
        currentRole: 'user',
        isDark: isDark,
      ),
    );
  }

  Widget _buildPackagesSection(bool isDark) {
    final packages = [
      {'title': 'Paket Foto Katalog Minimarket', 'price': 'Rp 750.000', 'desc': '20 Foto Clean Background White + Lighting Studio', 'tag': 'Populer'},
      {'title': 'Paket Video Reels IG/TikTok', 'price': 'Rp 1.200.000', 'desc': '3 Short Video 1080p dengan VO Model & Musik Trending', 'tag': 'Best Value'},
      {'title': 'Paket Redesain Kemasan / Stiker', 'price': 'Rp 950.000', 'desc': 'Vector Master AI/PSD Siap Cetak + Mockup 3D', 'tag': 'Desain'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Paket Spesial Kebutuhan UMKM',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
            ),
            TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DaftarKebutuhanScreen()),
                    );
                  },
                  child: Text('Lihat Semua', style: TextStyle(color: _accentColor)),
                ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 170,
          child: ScrollConfiguration(
            behavior: _DragScrollBehavior(),
            child: RawScrollbar(
              thumbVisibility: true,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: packages.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final pkg = packages[i];
                  return Container(
                    width: 280,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.cardBg : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                pkg['tag'] as String,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _accentColor),
                              ),
                            ),
                            Text(
                              pkg['price'] as String,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _accentColor),
                            ),
                          ],
                        ),
                        Text(
                          pkg['title'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        Text(
                          pkg['desc'] as String,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          height: 32,
                          child: ElevatedButton(
                            onPressed: () {
                              final title = (pkg['title'] as String).toLowerCase();
                              String kategori = 'lainnya';
                              if (title.contains('foto') || title.contains('katalog')) {
                                kategori = 'fotografi';
                              } else if (title.contains('video') || title.contains('reels')) kategori = 'videografi';
                              else if (title.contains('desain') || title.contains('redesain') || title.contains('stiker')) kategori = 'desain-grafis';

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BuatKebutuhanScreen(
                                    initialTitle: pkg['title'] as String,
                                    initialDescription: pkg['desc'] as String,
                                    initialKategori: kategori,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accentColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: EdgeInsets.zero,
                            ),
                            child: const Text('Pesan Paket Ini', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveProjectsSection(bool isDark) {
    final active = [
      {'name': 'Foto Makanan Keripik Pedas Bude', 'status': 'Proses Editing (80%)', 'vendor': 'Aruna Studio', 'deadline': 'Besok, 18:00'},
      {'name': 'Desain Stiker Botol Minuman Herbal', 'status': 'Revisi Mockup', 'vendor': 'Nusantara Graphix', 'deadline': '10 Ags 2026'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Project UMKM Berjalan',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: active.map((proj) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardBg : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _accentColor.withValues(alpha: 0.12),
                    child: Icon(Icons.inventory, color: _accentColor, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          proj['name']!,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Vendor: ${proj['vendor']!} • Deadline: ${proj['deadline']!}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      proj['status']!,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _accentColor),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCreatorRosterSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.stars_rounded, color: _accentColor, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Butuh Rekomendasi Kreator Sesuai Budget?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tim AI Kreavana siap mencocokkan produk UMKM Anda dengan fotografer & desainer lokal terverifikasi.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const DirectMessageScreen())); },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Konsultasi Gratis'),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarBadge(IconData icon, String count, bool isDark) {
    final isNotification = icon == Icons.notifications_none_outlined;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => isNotification
                ? NotificationsScreen(userId: widget.user.id ?? '')
                : const DirectMessageScreen(),
          ),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1830) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: isDark ? AppTheme.textMuted : Colors.grey.shade600),
          ),
          if (count.isNotEmpty)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  count,
                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Custom scroll behavior to allow mouse dragging on web/desktop
class _DragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };
}
