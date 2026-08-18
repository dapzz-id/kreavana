import '../../../services/badge_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../widgets/upgrade_plan_modal.dart';
import '../../../app/theme.dart';
import '../../../services/theme_transition_service.dart';
import '../../../screens/global_search_screen.dart';
import '../../../models/user_model.dart';
import '../../../screens/buat_kebutuhan_screen.dart';
import '../../../screens/notifications_screen.dart';
import '../../../screens/direct_message_screen.dart';
import '../../../screens/peluang_proyek_screen.dart';

class IndividualDashboardScreen extends StatefulWidget {
  final UserModel user;
  final ValueChanged<UserModel> onUserUpdated;

  const IndividualDashboardScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
  });

  @override
  State<IndividualDashboardScreen> createState() =>
      _IndividualDashboardScreenState();
}

class _IndividualDashboardScreenState extends State<IndividualDashboardScreen> {
  final GlobalKey _themeBtnKey = GlobalKey();

  static const Color _indivPurple = Color(0xFF7C3AED);
  static const Color _indivLight = Color(0xFFA78BFA);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      appBar: _buildAppBar(isDark),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 24 : 16,
            16,
            isDesktop ? 24 : 16,
            110,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroBanner(isDark),
              const SizedBox(height: 24),
              _buildMetricCards(isDark),
              const SizedBox(height: 24),
              _buildTopThreeColumns(isDark),
              const SizedBox(height: 24),
              _buildBottomThreeColumns(isDark), // <- perbaikan: ganti $1
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
                  color: isDark
                      ? const Color(0xFF1A1830)
                      : Colors.grey.shade100,
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
                    Expanded(
                      child: Text(
                        'Cari kreator, layanan, atau event...',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppTheme.textMuted
                              : Colors.grey.shade500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ListenableBuilder(
            listenable: BadgeService(),
            builder: (_, _) => _buildAppBarBadge(
              Icons.notifications_none_outlined,
              BadgeService().unreadNotificationsText,
              isDark,
            ),
          ),
          const SizedBox(width: 4),
          ListenableBuilder(
            listenable: BadgeService(),
            builder: (_, _) => _buildAppBarBadge(
              Icons.chat_bubble_outline,
              BadgeService().unreadMessagesText,
              isDark,
            ),
          ),
          const SizedBox(width: 20),
          IconButton(
            key: _themeBtnKey,
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 20,
            ),
            onPressed: () {
              final box =
                  _themeBtnKey.currentContext?.findRenderObject() as RenderBox?;
              final origin = box != null
                  ? box.localToGlobal(box.size.center(Offset.zero))
                  : const Offset(0, 0);
              ThemeTransitionService.animateToggle(
                origin: origin,
                toDark: !isDark,
              );
            },
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _indivPurple.withValues(alpha: 0.1),
                child: const Icon(Icons.person, color: _indivPurple, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.user.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Individual',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selamat datang, ${widget.user.name}! 👋',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kelola momen, temukan talenta terbaik, dan wujudkan ide kreatif Anda bersama Kreavana.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BuatKebutuhanScreen()),
          ),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Buat Permintaan Baru'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _indivPurple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCards(bool isDark) {
    final metrics = [
      {
        'label': 'Permintaan Aktif',
        'value': '3',
        'sub': 'Sedang diproses',
        'icon': Icons.folder_open,
        'color': _indivLight,
      },
      {
        'label': 'Proyek / Event',
        'value': '5',
        'sub': 'Berlangsung',
        'icon': Icons.event,
        'color': const Color(0xFF10B981),
      },
      {
        'label': 'Selesai',
        'value': '12',
        'sub': 'Proyek selesai',
        'icon': Icons.check_circle_outline,
        'color': const Color(0xFF3B82F6),
      },
      {
        'label': 'Total Pengeluaran',
        'value': 'Rp 8.750.000',
        'sub': 'Semua transaksi',
        'icon': Icons.account_balance_wallet_outlined,
        'color': const Color(0xFFF59E0B),
      },
      {
        'label': 'Favorit',
        'value': '18',
        'sub': 'Kreator tersimpan',
        'icon': Icons.favorite_border,
        'color': const Color(0xFFEC4899),
      },
      {
        'label': 'Poin Kreavana',
        'value': '650',
        'sub': 'Gold Member',
        'icon': Icons.stars,
        'color': Colors.amber.shade600,
      },
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: metrics.map((m) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.all(14),
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
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (m['color'] as Color).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    (m['icon'] as IconData?) ?? Icons.image_outlined,
                    color: m['color'] as Color,
                    size: 18,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  m['label'] as String,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  m['value'] as String,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  m['sub'] as String,
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopThreeColumns(bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 700) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: _buildLineChartCard(isDark)),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: _buildDonutChartCard(isDark)),
          const SizedBox(width: 16),
          Expanded(flex: 3, child: _buildRecentRequestsCard(isDark)),
        ],
      );
    }
    return Column(
      children: [
        _buildLineChartCard(isDark),
        const SizedBox(height: 16),
        _buildDonutChartCard(isDark),
        const SizedBox(height: 16),
        _buildRecentRequestsCard(isDark),
      ],
    );
  }

  Widget _buildLineChartCard(bool isDark) {
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
          const Text(
            'Ringkasan Aktivitas',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 3),
                      FlSpot(1, 5),
                      FlSpot(2, 4),
                      FlSpot(3, 8),
                      FlSpot(4, 6),
                      FlSpot(5, 7),
                    ],
                    isCurved: true,
                    color: _indivPurple,
                    barWidth: 3,
                  ),
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 1),
                      FlSpot(1, 2),
                      FlSpot(2, 2),
                      FlSpot(3, 5),
                      FlSpot(4, 3),
                      FlSpot(5, 5),
                    ],
                    isCurved: true,
                    color: const Color(0xFF10B981),
                    barWidth: 3,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonutChartCard(bool isDark) {
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
          const Text(
            'Kategori Layanan Favorit',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 35,
                sections: [
                  PieChartSectionData(
                    value: 40,
                    color: _indivPurple,
                    radius: 18,
                    showTitle: false,
                  ),
                  PieChartSectionData(
                    value: 25,
                    color: const Color(0xFF3B82F6),
                    radius: 18,
                    showTitle: false,
                  ),
                  PieChartSectionData(
                    value: 15,
                    color: const Color(0xFF10B981),
                    radius: 18,
                    showTitle: false,
                  ),
                  PieChartSectionData(
                    value: 10,
                    color: const Color(0xFFF59E0B),
                    radius: 18,
                    showTitle: false,
                  ),
                  PieChartSectionData(
                    value: 10,
                    color: Colors.grey,
                    radius: 18,
                    showTitle: false,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildCatRow('Foto & Video', '40%', _indivPurple),
          _buildCatRow('Dekorasi & Event', '25%', const Color(0xFF3B82F6)),
          _buildCatRow('Desain & Konten', '15%', const Color(0xFF10B981)),
          _buildCatRow('Kursus & Pelatihan', '10%', const Color(0xFFF59E0B)),
        ],
      ),
    );
  }

  Widget _buildCatRow(String name, String val, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 11))),
          Text(
            val,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRequestsCard(bool isDark) {
    final requests = [
      {
        'title': 'Fotografi Pernikahan',
        'date': '18 Mei 2025',
        'price': 'Rp 3.500.000',
        'status': 'Sedang Diproses',
      },
      {
        'title': 'Dekorasi Ulang Tahun',
        'date': '10 Mei 2025',
        'price': 'Rp 1.250.000',
        'status': 'Menunggu Penawaran',
      },
      {
        'title': 'Foto Wisuda',
        'date': '3 Mei 2025',
        'price': 'Rp 800.000',
        'status': 'Selesai',
      },
      {
        'title': 'Desain Konten Instagram',
        'date': '28 Apr 2025',
        'price': 'Rp 450.000',
        'status': 'Selesai',
      },
    ];

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
              const Text(
                'Permintaan Terbaru',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PeluangProyekScreen(user: widget.user),
                    ),
                  );
                },
                child: const Text(
                  'Lihat Semua',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...requests.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _indivPurple.withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: _indivPurple,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r['title']!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          r['date']!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    r['price']!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomThreeColumns(bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 700) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildActivityCard(isDark)),
          const SizedBox(width: 16),
          Expanded(child: _buildFavoriteCreatorsCard(isDark)),
          const SizedBox(width: 16),
          Expanded(child: _buildRecommendationsCard(isDark)),
        ],
      );
    }
    return Column(
      children: [
        _buildActivityCard(isDark),
        const SizedBox(height: 16),
        _buildFavoriteCreatorsCard(isDark),
        const SizedBox(height: 16),
        _buildRecommendationsCard(isDark),
      ],
    );
  }

  Widget _buildActivityCard(bool isDark) {
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
          const Text(
            'Aktivitas Terbaru',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildActItem(
            'Permintaan "Fotografi Pernikahan" diperbarui',
            '2 jam lalu',
          ),
          _buildActItem('Pembayaran Rp 1.250.000 berhasil', '5 jam lalu'),
          _buildActItem(
            'Kreasi Studio menerima permintaan Anda',
            '1 hari lalu',
          ),
          _buildActItem(
            'Proyek "Desain Konten Instagram" selesai',
            '2 hari lalu',
          ),
          _buildActItem('Dapatkan 50 poin dari ulasan kreator', '3 hari lalu'),
        ],
      ),
    );
  }

  Widget _buildActItem(String title, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: _indivPurple.withValues(alpha: 0.1),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: _indivPurple,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 12))),
          Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildFavoriteCreatorsCard(bool isDark) {
    final creators = [
      {'name': 'Kreasi Studio', 'cat': 'Foto & Video', 'rating': '4.9'},
      {'name': 'DesignLab', 'cat': 'Desain Grafis & Konten', 'rating': '4.8'},
      {'name': 'EventPro Organizer', 'cat': 'Event Organizer', 'rating': '4.8'},
      {
        'name': 'DecorLine Studio',
        'cat': 'Dekorasi & Stylist',
        'rating': '4.7',
      },
      {'name': 'Makeup Artist Pro', 'cat': 'Make Up & Beauty', 'rating': '4.7'},
    ];

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
          const Text(
            'Kreator Favorit Saya',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...creators.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: _indivPurple.withValues(alpha: 0.1),
                    child: Text(
                      c['name']![0],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c['name']!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          c['cat']!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.star, size: 14, color: Colors.amber.shade600),
                  Text(
                    c['rating']!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsCard(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _indivPurple.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _indivPurple.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Jadi Member Premium',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              const Text(
                'Nikmati keuntungan eksklusif, diskon spesial, dan prioritas layanan.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => UpgradePlanModal.show(context),
                style: ElevatedButton.styleFrom(backgroundColor: _indivPurple),
                child: const Text(
                  'Upgrade Sekarang',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppBarBadge(IconData icon, String count, bool isDark) {
    final isNotification = icon == Icons.notifications_none_outlined;
    return ListenableBuilder(
      listenable: BadgeService(),
      builder: (context, _) {
        final badgeCount = isNotification
            ? BadgeService().unreadNotificationsText
            : BadgeService().unreadMessagesText;
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => isNotification
                    ? NotificationsScreen(userId: '')
                    : const DirectMessageScreen(),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D2A3E) : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                if (badgeCount.isNotEmpty && badgeCount != '0')
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badgeCount,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
