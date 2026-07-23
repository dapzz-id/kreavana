import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../services/theme_transition_service.dart';
import 'buat_kebutuhan_screen.dart';
import 'proyek_saya_screen.dart';
import 'explore_screen.dart';
import 'notifications_screen.dart';
import 'direct_message_screen.dart';
import 'global_search_screen.dart';
import 'wallet_screen.dart';

class CompanyDashboardScreen extends StatefulWidget {
  final UserModel user;
  final ValueChanged<UserModel> onUserUpdated;

  const CompanyDashboardScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
  });

  @override
  State<CompanyDashboardScreen> createState() => _CompanyDashboardScreenState();
}

class _CompanyDashboardScreenState extends State<CompanyDashboardScreen> {
  final GlobalKey _themeBtnKey = GlobalKey();

  static const Color _brandBlue = Color(0xFF2563EB);
  static const Color _brandLight = Color(0xFF3B82F6);

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
              _buildBottomThreeColumns(isDark),
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
                    Expanded(
                      child: Text(
                        'Cari proyek, kreator, atau transaksi...',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '⌘K',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          _buildAppBarBadge(Icons.notifications_none_outlined, '3', isDark),
          const SizedBox(width: 4),
          _buildAppBarBadge(Icons.chat_bubble_outline, '1', isDark),
          const SizedBox(width: 12),
          IconButton(
            key: _themeBtnKey,
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 20,
            ),
            onPressed: () {
              final box = _themeBtnKey.currentContext?.findRenderObject() as RenderBox?;
              final origin = box != null
                  ? box.localToGlobal(box.size.center(Offset.zero))
                  : const Offset(0, 0);
              ThemeTransitionService.animateToggle(origin: origin, toDark: !isDark);
            },
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _brandBlue.withValues(alpha: 0.1),
                child: const Icon(Icons.business, color: _brandBlue, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.user.name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Perusahaan',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarBadge(IconData icon, String count, bool isDark) {
    final isNotification = icon == Icons.notifications_none_outlined;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(icon, color: isDark ? Colors.white70 : Colors.grey.shade700, size: 24),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => isNotification
                    ? NotificationsScreen(userId: widget.user.id ?? '')
                    : const DirectMessageScreen(),
              ),
            );
          },
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            child: Center(
              child: Text(
                count,
                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
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
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Kelola proyek dan temukan talenta kreatif terbaik untuk bisnis Anda.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                  height: 1.5,
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
          label: const Text('Buat Proyek Baru'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _brandBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCards(bool isDark) {
    final metrics = [
      {
        'label': 'Total Proyek',
        'value': '12',
        'sub': '8 aktif, 4 selesai',
        'icon': Icons.folder_outlined,
        'color': _brandLight,
      },
      {
        'label': 'Pekerjaan Aktif',
        'value': '8',
        'sub': 'Sedang berjalan',
        'icon': Icons.play_circle_outline,
        'color': const Color(0xFF10B981),
      },
      {
        'label': 'Total Pembayaran',
        'value': 'Rp 45.750.000',
        'sub': 'Semua waktu',
        'icon': Icons.account_balance_wallet_outlined,
        'color': const Color(0xFF3B82F6),
      },
      {
        'label': 'Menunggu Pembayaran',
        'value': 'Rp 7.250.000',
        'sub': '3 invoice',
        'icon': Icons.receipt_long_outlined,
        'color': const Color(0xFFF59E0B),
      },
      {
        'label': 'Kreator Favorit',
        'value': '15',
        'sub': 'Kreator tersimpan',
        'icon': Icons.favorite_border,
        'color': const Color(0xFFEF4444),
      },
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: metrics.map((m) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(16),
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (m['color'] as Color).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(m['icon'] as IconData, color: m['color'] as Color, size: 20),
                ),
                const SizedBox(height: 12),
                Text(
                  m['label'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  m['value'] as String,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  m['sub'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                  ),
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
          Expanded(flex: 3, child: _buildActiveProjectsCard(isDark)),
        ],
      );
    }
    return Column(
      children: [
        _buildLineChartCard(isDark),
        const SizedBox(height: 16),
        _buildDonutChartCard(isDark),
        const SizedBox(height: 16),
        _buildActiveProjectsCard(isDark),
      ],
    );
  }

  Widget _buildLineChartCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ringkasan Pengeluaran', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(color: isDark ? Colors.white12 : Colors.grey.shade200),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        const labels = ['Des \'24', 'Jan \'25', 'Feb \'25', 'Mar \'25', 'Apr \'25', 'Mei \'25'];
                        final i = v.toInt();
                        if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                        return Text(labels[i], style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 6),
                      FlSpot(1, 10),
                      FlSpot(2, 14),
                      FlSpot(3, 16.25),
                      FlSpot(4, 11),
                      FlSpot(5, 15)
                    ],
                    isCurved: true,
                    color: _brandBlue,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
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
        border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pengeluaran Berdasarkan Kategori', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 35,
                sections: [
                  PieChartSectionData(value: 45, color: _brandBlue, radius: 18, showTitle: false),
                  PieChartSectionData(value: 25, color: const Color(0xFF10B981), radius: 18, showTitle: false),
                  PieChartSectionData(value: 15, color: const Color(0xFFF59E0B), radius: 18, showTitle: false),
                  PieChartSectionData(value: 10, color: const Color(0xFF8B5CF6), radius: 18, showTitle: false),
                  PieChartSectionData(value: 5, color: Colors.grey, radius: 18, showTitle: false),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildCatRow('Video & Fotografi', '45%', _brandBlue),
          _buildCatRow('Desain & Branding', '25%', const Color(0xFF10B981)),
          _buildCatRow('Event', '15%', const Color(0xFFF59E0B)),
          _buildCatRow('Marketing', '10%', const Color(0xFF8B5CF6)),
        ],
      ),
    );
  }

  Widget _buildCatRow(String name, String pct, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 11))),
          Text(pct, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActiveProjectsCard(bool isDark) {
    final projects = [
      {'title': 'Video Company Profile', 'creator': 'Kreasi Studio', 'progress': 0.60, 'status': 'Sedang Dikerjakan'},
      {'title': 'Desain Kemasan Produk', 'creator': 'DesignLab', 'progress': 0.40, 'status': 'Sedang Dikerjakan'},
      {'title': 'Event Gathering 2025', 'creator': 'EventPro Organizer', 'progress': 0.75, 'status': 'Dalam Proses'},
      {'title': 'Konten Media Sosial', 'creator': 'Content Creativa', 'progress': 0.30, 'status': 'Review'},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Proyek Aktif', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProyekSayaScreen()),
                ),
                child: const Text('Lihat Semua', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...projects.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _brandBlue.withValues(alpha: 0.1),
                      child: const Icon(Icons.work, color: _brandBlue, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['title'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          Text(p['creator'] as String, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Text(
                      '${((p['progress'] as double) * 100).round()}%',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )),
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
        border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Aktivitas Terbaru', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildActItem('Kreasi Studio mengirimkan update pekerjaan', '2 jam lalu', Icons.send),
          _buildActItem('Pembayaran sebesar Rp 7.500.000 berhasil', '4 jam lalu', Icons.check_circle, Colors.green),
          _buildActItem('DesignLab mengirimkan penawaran baru', '1 hari lalu', Icons.local_offer, Colors.orange),
          _buildActItem('EventPro Organizer menyelesaikan pekerjaan', '2 hari lalu', Icons.done_all, Colors.purple),
        ],
      ),
    );
  }

  Widget _buildActItem(String title, String time, IconData icon, [Color color = _brandBlue]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color, size: 16),
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
      {'name': 'Kreasi Studio', 'cat': 'Video & Fotografi', 'rating': '4.9'},
      {'name': 'DesignLab', 'cat': 'Desain & Branding', 'rating': '4.8'},
      {'name': 'Content Creativa', 'cat': 'Content Creator', 'rating': '4.9'},
      {'name': 'EventPro Organizer', 'cat': 'Event Organizer', 'rating': '4.7'},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kreator Favorit', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...creators.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: _brandBlue.withValues(alpha: 0.1),
                      child: Text(
                        c['name']![0],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c['name']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text(c['cat']!, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Icon(Icons.star, size: 14, color: Colors.amber.shade600),
                    Text(c['rating']!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildRecommendationsCard(bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tingkatkan efisiensi proyek Anda',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              const Text(
                'Gunakan fitur Brief Template untuk mempercepat proses pembuatan brief.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                child: const Text('Coba Sekarang', style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _brandBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _brandBlue.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Lihat Paket Langganan Enterprise',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              const Text(
                'Dapatkan keuntungan lebih untuk manajemen proyek skala besar.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {},
                child: const Text('Lihat Paket', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}