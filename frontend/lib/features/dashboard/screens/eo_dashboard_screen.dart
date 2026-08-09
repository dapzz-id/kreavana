import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../services/theme_transition_service.dart';
import '../../../screens/global_search_screen.dart';
import '../../../models/user_model.dart';
import '../../../screens/buat_kebutuhan_screen.dart';
import '../../../screens/explore_screen.dart';
import '../../../screens/notifications_screen.dart';
import '../../../screens/direct_message_screen.dart';
import '../../../screens/peluang_proyek_screen.dart';
import '../../../services/badge_service.dart';

class EoDashboardScreen extends StatefulWidget {
  final UserModel user;
  final ValueChanged<UserModel> onUserUpdated;

  const EoDashboardScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
  });

  @override
  State<EoDashboardScreen> createState() => _EoDashboardScreenState();
}

class _EoDashboardScreenState extends State<EoDashboardScreen> {
  final GlobalKey _themeBtnKey = GlobalKey();

  static const Color _eoPurple = Color(0xFF6366F1);
  static const Color _eoLight = Color(0xFF818CF8);

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
              _buildBottomThreeColumns(isDark), // <-- perbaikan utama
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
                        'Cari event, vendor, atau talent...',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
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
            builder: (_, _) => _buildAppBarBadge(Icons.notifications_none_outlined, BadgeService().unreadNotificationsText, isDark),
          ),
          const SizedBox(width: 4),
          ListenableBuilder(
            listenable: BadgeService(),
            builder: (_, _) => _buildAppBarBadge(Icons.chat_bubble_outline, BadgeService().unreadMessagesText, isDark),
          ),
          const SizedBox(width: 20),
          IconButton(
            key: _themeBtnKey,
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 20),
            onPressed: () {
              final box = _themeBtnKey.currentContext?.findRenderObject() as RenderBox?;
              final origin = box != null ? box.localToGlobal(box.size.center(Offset.zero)) : const Offset(0, 0);
              ThemeTransitionService.animateToggle(origin: origin, toDark: !isDark);
            },
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _eoPurple.withValues(alpha: 0.1),
                child: const Icon(Icons.event, color: _eoPurple, size: 20),
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
                    'Event Organizer',
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
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Kelola event Anda dengan lebih mudah dan temukan vendor terbaik bersama Kreavana.',
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
          label: const Text('Buat Event Baru'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _eoPurple,
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
      {'label': 'Total Event', 'value': '24', 'sub': '12 akan datang', 'icon': Icons.event, 'color': _eoLight},
      {'label': 'Event Aktif', 'value': '5', 'sub': 'Sedang berjalan', 'icon': Icons.play_circle_fill, 'color': const Color(0xFF10B981)},
      {'label': 'Total Nilai Proyek', 'value': 'Rp 285.750.000', 'sub': 'Semua waktu', 'icon': Icons.monetization_on, 'color': const Color(0xFF3B82F6)},
      {'label': 'Pending Pembayaran', 'value': 'Rp 38.500.000', 'sub': '4 invoice', 'icon': Icons.receipt, 'color': const Color(0xFFF59E0B)},
      {'label': 'Vendor Favorit', 'value': '18', 'sub': 'Vendor tersimpan', 'icon': Icons.star, 'color': const Color(0xFFEC4899)},
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
              border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
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
                  child: Icon((m['icon'] as IconData?) ?? Icons.image_outlined, color: m['color'] as Color, size: 20),
                ),
                const SizedBox(height: 12),
                Text(m['label'] as String, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 6),
                Text(m['value'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(m['sub'] as String, style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
          Expanded(flex: 3, child: _buildActiveEventsCard(isDark)),
        ],
      );
    }
    return Column(
      children: [
        _buildLineChartCard(isDark),
        const SizedBox(height: 16),
        _buildDonutChartCard(isDark),
        const SizedBox(height: 16),
        _buildActiveEventsCard(isDark),
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
          const Text('Ringkasan Event', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
                      FlSpot(0, 20),
                      FlSpot(1, 35),
                      FlSpot(2, 40),
                      FlSpot(3, 65.25),
                      FlSpot(4, 45),
                      FlSpot(5, 55),
                    ],
                    isCurved: true,
                    color: _eoPurple,
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
        border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Event Berdasarkan Status', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 35,
                sections: [
                  PieChartSectionData(value: 50, color: _eoPurple, radius: 18, showTitle: false),
                  PieChartSectionData(value: 21, color: const Color(0xFF10B981), radius: 18, showTitle: false),
                  PieChartSectionData(value: 17, color: const Color(0xFFF59E0B), radius: 18, showTitle: false),
                  PieChartSectionData(value: 12, color: Colors.grey, radius: 18, showTitle: false),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildCatRow('Akan Datang', '12 (50%)', _eoPurple),
          _buildCatRow('Sedang Berjalan', '5 (21%)', const Color(0xFF10B981)),
          _buildCatRow('Dalam Persiapan', '4 (17%)', const Color(0xFFF59E0B)),
          _buildCatRow('Selesai', '3 (12%)', Colors.grey),
        ],
      ),
    );
  }

  Widget _buildCatRow(String name, String val, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 11))),
          Text(val, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActiveEventsCard(bool isDark) {
    final events = [
      {'title': 'Tech Conference 2025', 'type': 'Konferensi', 'progress': 0.75, 'status': 'Sedang Berjalan'},
      {'title': 'Product Launch XYZ', 'type': 'Launching', 'progress': 0.45, 'status': 'Dalam Persiapan'},
      {'title': 'Corporate Gathering 2025', 'type': 'Gathering', 'progress': 0.30, 'status': 'Dalam Persiapan'},
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
              const Text('Event Aktif', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              TextButton(onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => PeluangProyekScreen(user: widget.user))); }, child: const Text('Lihat Semua', style: TextStyle(fontSize: 12))),
            ],
          ),
          const SizedBox(height: 8),
          ...events.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _eoPurple.withValues(alpha: 0.1),
                      child: const Icon(Icons.confirmation_number_outlined, color: _eoPurple, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e['title'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          Text(e['type'] as String, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Text('${((e['progress'] as double) * 100).round()}%',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
          Expanded(child: _buildTopVendorsCard(isDark)),
          const SizedBox(width: 16),
          Expanded(child: _buildSpendingAndRecs(isDark)),
        ],
      );
    }
    return Column(
      children: [
        _buildActivityCard(isDark),
        const SizedBox(height: 16),
        _buildTopVendorsCard(isDark),
        const SizedBox(height: 16),
        _buildSpendingAndRecs(isDark),
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
          _buildActItem('Pembayaran invoice #INV-2025-067 sebesar Rp 12.500.000', '2 jam lalu'),
          _buildActItem('Penawaran baru dari Kreasi Studio untuk event Anda', '4 jam lalu'),
          _buildActItem('Vendor Lighting Pro menerima pesanan Anda', '6 jam lalu'),
          _buildActItem('Task "Final Briefing" telah selesai', '1 hari lalu'),
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
            backgroundColor: _eoPurple.withValues(alpha: 0.1),
            child: const Icon(Icons.bolt, color: _eoPurple, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 12))),
          Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildTopVendorsCard(bool isDark) {
    final vendors = [
      {'name': 'Kreasi Studio', 'cat': 'Dekorasi & Stage', 'rating': '4.9'},
      {'name': 'Lighting Pro', 'cat': 'Lighting & Sound', 'rating': '4.8'},
      {'name': 'Grand Catering', 'cat': 'Catering', 'rating': '4.7'},
      {'name': 'MediaFrame', 'cat': 'Dokumentasi Foto & Video', 'rating': '4.9'},
      {'name': 'MC Professional', 'cat': 'MC & Entertainment', 'rating': '4.8'},
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
          const Text('Top Vendor Favorit', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...vendors.map((v) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: _eoPurple.withValues(alpha: 0.1),
                      child: Text(v['name']![0], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v['name']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text(v['cat']!, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Icon(Icons.star, size: 14, color: Colors.amber.shade600),
                    Text(v['rating']!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildSpendingAndRecs(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardBg : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pengeluaran Berdasarkan Kategori',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              _buildCatRow('Venue', '40% (Rp 98.900.000)', _eoPurple),
              _buildCatRow('Catering', '25% (Rp 61.800.000)', const Color(0xFF10B981)),
              _buildCatRow('Dekorasi', '15% (Rp 37.100.000)', const Color(0xFFF59E0B)),
              _buildCatRow('Dokumentasi', '10% (Rp 24.750.000)', const Color(0xFFEC4899)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _eoPurple.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _eoPurple.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Simpan lebih banyak vendor favorit',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              const Text(
                'Simpan vendor favorit untuk mempermudah pemilihan penawaran terbaik.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExploreScreen(user: widget.user),
                  ),
                ),
                child: const Text('Cari Vendor', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
      ],
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
