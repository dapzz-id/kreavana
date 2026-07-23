import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../widgets/role_toggle.dart';
import '../services/theme_transition_service.dart';
import 'buat_kebutuhan_screen.dart';
import 'proyek_saya_screen.dart';
import 'agenda_screen.dart';
import 'marketplace_karya_screen.dart';
import 'explore_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'direct_message_screen.dart';
import 'global_search_screen.dart';

class DashboardScreen extends StatefulWidget {
  final UserModel user;
  final ValueChanged<UserModel> onUserUpdated;

  const DashboardScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late String _currentRole;
  Map<String, dynamic> _overviewSummary = {};
  List<Map<String, dynamic>> _vendorRecommendations = [];
  List<Map<String, dynamic>> _projectNeeds = [];
  List<Map<String, dynamic>> _agenda = [];
  List<Map<String, dynamic>> _projectAssets = [];

  bool get _isCreator => _currentRole == 'creator';

  // ── Mock data (Client) ──────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _mockCreators = [
    {
      'name': 'Aruna Studio',
      'category': 'Fotografer',
      'location': 'Jakarta, Indonesia',
      'rating': '4.9',
      'review_count': '128',
      'starting_price': 'Mulai Rp750.000',
      'avatar_url': '',
      'gradient_colors': [const Color(0xFF667EE7), const Color(0xFF764BA2)],
    },
    {
      'name': 'Frame Story',
      'category': 'Videografer',
      'location': 'Bandung, Indonesia',
      'rating': '4.8',
      'review_count': '96',
      'starting_price': 'Mulai Rp1.200.000',
      'avatar_url': '',
      'gradient_colors': [const Color(0xFFF093FB), const Color(0xFFF5576C)],
    },
    {
      'name': 'Graphix Studio',
      'category': 'Desainer',
      'location': 'Yogyakarta, Indonesia',
      'rating': '4.9',
      'review_count': '110',
      'starting_price': 'Mulai Rp450.000',
      'avatar_url': '',
      'gradient_colors': [const Color(0xFF4FACFE), const Color(0xFF00F2FE)],
    },
    {
      'name': 'Kreasi Konten ID',
      'category': 'Konten Kreator',
      'location': 'Surabaya, Indonesia',
      'rating': '4.7',
      'review_count': '84',
      'starting_price': 'Mulai Rp800.000',
      'avatar_url': '',
      'gradient_colors': [const Color(0xFF43E97B), const Color(0xFF38F9D7)],
    },
  ];

  // ── Mock data (Creator) ──────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _mockOpportunities = [
    {
      'title': 'UGC Review Produk',
      'badge': 'UGC',
      'badge_color': const Color(0xFF7C3AED),
      'location': 'Jakarta',
      'price': 'Rp2.800.000',
      'action_label': 'Lihat Detail',
      'icon': Icons.spa_outlined,
      'gradient_colors': [const Color(0xFF667EE7), const Color(0xFF764BA2)],
    },
    {
      'title': 'Konten Reels Brand',
      'badge': 'REELS',
      'badge_color': const Color(0xFFEC4899),
      'location': 'Bekasi',
      'price': 'Rp3.500.000',
      'action_label': 'Lihat Detail',
      'icon': Icons.videocam_outlined,
      'gradient_colors': [const Color(0xFFF093FB), const Color(0xFFF5576C)],
    },
    {
      'title': 'Liputan Event Komunitas',
      'badge': 'EVENT',
      'badge_color': const Color(0xFF3B82F6),
      'location': 'Bandung',
      'price': 'Rp2.200.000',
      'action_label': 'Lihat Detail',
      'icon': Icons.celebration_outlined,
      'gradient_colors': [const Color(0xFF4FACFE), const Color(0xFF00F2FE)],
    },
    {
      'title': 'Komunitas Content Creator Indonesia',
      'badge': 'KOLABORASI',
      'badge_color': const Color(0xFFF97316),
      'location': 'Online',
      'price': 'Gratis',
      'action_label': 'Gabung Komunitas',
      'icon': Icons.groups_outlined,
      'gradient_colors': [const Color(0xFF43E97B), const Color(0xFF38F9D7)],
    },
  ];

  final List<Map<String, dynamic>> _mockPortfolio = [
    {
      'title': 'UGC',
      'type': 'photo',
      'gradient': [const Color(0xFF667EE7), const Color(0xFF764BA2)],
      'icon': Icons.spa_outlined,
    },
    {
      'title': 'Reels',
      'type': 'video',
      'gradient': [const Color(0xFFF093FB), const Color(0xFFF5576C)],
      'icon': Icons.videocam_outlined,
    },
    {
      'title': 'Review',
      'type': 'photo',
      'gradient': [const Color(0xFF4FACFE), const Color(0xFF00F2FE)],
      'icon': Icons.rate_review_outlined,
    },
    {
      'title': 'Lifestyle',
      'type': 'photo',
      'gradient': [const Color(0xFFFDBB2D), const Color(0xFF22C1C3)],
      'icon': Icons.landscape_outlined,
    },
    {
      'title': 'Beauty',
      'type': 'photo',
      'gradient': [const Color(0xFFF7971E), const Color(0xFFFFD200)],
      'icon': Icons.face_retouching_natural_outlined,
    },
    {
      'title': 'Campaign',
      'type': 'photo',
      'gradient': [const Color(0xFF43E97B), const Color(0xFF38F9D7)],
      'icon': Icons.campaign_outlined,
    },
  ];

  final GlobalKey _themeBtnKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _currentRole = widget.user.role;
    _loadDashboardData();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user.role != oldWidget.user.role ||
        widget.user.subRole != oldWidget.user.subRole) {
      setState(() {
        _currentRole = widget.user.role;
      });
      _loadDashboardData();
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      if (mounted) {
        setState(() {
          _overviewSummary = {
            'active_needs': '12',
            'proposals_count': '28',
            'running_projects': '6',
            'estimated_expenses': 'Rp18.750.000',
          };
          _vendorRecommendations = [
            {
              'name': 'Aruna Studio',
              'avatar_url': '',
              'category': 'Fotografer',
              'location': 'Jakarta, Indonesia',
              'rating': '4.9',
              'review_count': '128',
              'starting_price': 'Mulai Rp750.000',
              'gradient_colors': [
                const Color(0xFF667EE7),
                const Color(0xFF764BA2),
              ],
            },
            {
              'name': 'Frame Story',
              'avatar_url': '',
              'category': 'Videografer',
              'location': 'Bandung, Indonesia',
              'rating': '4.8',
              'review_count': '96',
              'starting_price': 'Mulai Rp1.200.000',
              'gradient_colors': [
                const Color(0xFFF093FB),
                const Color(0xFFF5576C),
              ],
            },
            {
              'name': 'Graphix Studio',
              'avatar_url': '',
              'category': 'Desainer',
              'location': 'Yogyakarta, Indonesia',
              'rating': '4.9',
              'review_count': '110',
              'starting_price': 'Mulai Rp450.000',
              'gradient_colors': [
                const Color(0xFF4FACFE),
                const Color(0xFF00F2FE),
              ],
            },
          ];
          _projectNeeds = [
            {
              'title': 'Foto Katalog Produk',
              'status': 'Baru',
              'status_color': '#7C3AED',
              'description': 'Toko Fashion',
            },
            {
              'title': 'Video Promosi Instagram',
              'status': 'Diproses',
              'status_color': '#F59E0B',
              'description': 'Toko Fashion',
            },
            {
              'title': 'Dokumentasi Event Komunitas',
              'status': 'Briefing',
              'status_color': '#3B82F6',
              'description': 'Komunitas',
            },
            {
              'title': 'Desain Poster Campaign',
              'status': 'Selesai',
              'status_color': '#10B981',
              'description': 'Promo Brand',
            },
          ];
          _agenda = [
            {
              'title': 'Meeting Briefing Proyek Foto',
              'date': '24',
              'month': 'Mei',
              'time': '09:00 - 10:00',
              'type': 'Online',
              'type_color': '#3B82F6',
              'icon': Icons.videocam_outlined,
            },
            {
              'title': 'Review Draft Desain Poster',
              'date': '25',
              'month': 'Mei',
              'time': '14:00 - 15:00',
              'type': 'Online',
              'type_color': '#3B82F6',
              'icon': Icons.videocam_outlined,
            },
            {
              'title': 'Shooting Day - Video Promosi',
              'date': '27',
              'month': 'Mei',
              'time': '08:00 - 17:00',
              'type': 'Offline',
              'type_color': '#F97316',
              'icon': Icons.location_on_outlined,
            },
            {
              'title': 'Deadline Penyerahan Hasil Akhir',
              'date': '29',
              'month': 'Mei',
              'time': '23:59',
              'type': 'Deadline',
              'type_color': '#EF4444',
              'icon': Icons.alarm_outlined,
            },
          ];
          _projectAssets = [
            {
              'title': 'Foto Katalog Produk',
              'type': 'photo',
              'gradient': [const Color(0xFF667EE7), const Color(0xFF764BA2)],
            },
            {
              'title': 'Video Promosi Instagram',
              'type': 'video',
              'gradient': [const Color(0xFFF093FB), const Color(0xFFF5576C)],
            },
            {
              'title': 'Dokumentasi Event',
              'type': 'photo',
              'gradient': [const Color(0xFF4FACFE), const Color(0xFF00F2FE)],
            },
            {
              'title': 'Desain Poster Campaign',
              'type': 'design',
              'gradient': [const Color(0xFF43E97B), const Color(0xFF38F9D7)],
            },
          ];
        });
      }
    } catch (_) {}
  }

  void _showDummyActionMessage(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Fitur "$action" segera hadir!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _navigateTo(String feature) {
    switch (feature) {
      case 'Buat Kebutuhan':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BuatKebutuhanScreen()),
        );
        break;
      case 'Cari Kreator':
      case 'Cari Campaign':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ExploreScreen(user: widget.user)),
        );
        break;
      case 'Lengkapi Profil':
      case 'Lihat Profil':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileScreen(
              user: widget.user,
              onUserUpdated: widget.onUserUpdated,
              onLogout: () {},
            ),
          ),
        );
        break;
      case 'Lihat Semua':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProyekSayaScreen()),
        );
        break;
      case 'Lihat Semua Proyek':
      case 'Semua Proyek':
      case 'Semua Kebutuhan & Proyek':
      case 'Lihat Semua Kebutuhan':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProyekSayaScreen()),
        );
        break;
      case 'Lihat Semua Agenda':
      case 'Lihat Kalender':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AgendaScreen()),
        );
        break;
      case 'Lihat Semua Karya':
      case 'Buka Semua Aset':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MarketplaceKaryaScreen()),
        );
        break;
      case 'Notifikasi':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NotificationsScreen(userId: widget.user.id ?? ''),
          ),
        );
        break;
      case 'Pesan':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DirectMessageScreen()),
        );
        break;
      default:
        _showDummyActionMessage(feature);
    }
  }

  // ── Hero Banner ─────────────────────────────────────────────────────────────
  Widget _buildHeroBanner(bool isDark) {
    final greeting = _isCreator
        ? 'Selamat Datang, Content Creator 👋'
        : 'Selamat Datang, Klien 👋';
    final subtitle = _isCreator
        ? 'Temukan campaign yang cocok untukmu, kelola jadwal posting, bangun media kit profesional, dan tingkatkan reputasi serta penghasilan di Kreavana.'
        : 'Buat kebutuhan, temukan kreator terbaik, pantau progres proyek, dan dapatkan hasil berkualitas melalui Kreavana.';
    final primaryLabel = _isCreator ? 'Lengkapi Profil' : 'Buat Kebutuhan';
    final primaryIcon = _isCreator
        ? Icons.settings_suggest_outlined
        : Icons.add_circle_outline;
    final secondaryLabel = _isCreator ? 'Cari Campaign' : 'Cari Kreator';
    final secondaryIcon = Icons.search;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: !isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 14,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _navigateTo(primaryLabel),
                      icon: Icon(primaryIcon, size: 18),
                      label: Text(primaryLabel),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _navigateTo(secondaryLabel),
                      icon: Icon(secondaryIcon, size: 18),
                      label: Text(secondaryLabel),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Container(
            width: 260,
            height: 180,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryPurple.withValues(alpha: 0.15),
                  AppTheme.primaryPurple.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              children: [
                // Laptop
                Positioned(
                  bottom: 20,
                  left: 30,
                  child: Container(
                    width: 120,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Container(
                        width: 100,
                        height: 60,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade800 : Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          _isCreator
                              ? Icons.camera_alt_outlined
                              : Icons.laptop_mac_outlined,
                          color: AppTheme.primaryPurple.withValues(alpha: 0.5),
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),
                // Person silhouette
                Positioned(
                  right: 40,
                  top: 20,
                  child: Container(
                    width: 80,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.person_outline,
                      color: AppTheme.primaryPurple.withValues(alpha: 0.4),
                      size: 50,
                    ),
                  ),
                ),
                // Play button
                Positioned(
                  right: 20,
                  top: 15,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryPurple.withValues(alpha: 0.15),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: AppTheme.primaryPurple,
                      size: 18,
                    ),
                  ),
                ),
                // Bar chart
                Positioned(
                  left: 20,
                  top: 15,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.1),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildMiniBar(6, Colors.orange.shade400),
                        const SizedBox(width: 3),
                        _buildMiniBar(10, Colors.blue.shade400),
                        const SizedBox(width: 3),
                        _buildMiniBar(8, Colors.green.shade400),
                      ],
                    ),
                  ),
                ),
                // Pie chart
                Positioned(
                  right: 80,
                  bottom: 15,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withValues(alpha: 0.1),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.pie_chart_outline,
                      color: AppTheme.primaryPurple.withValues(alpha: 0.6),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBar(double height, Color color) {
    return Container(
      width: 6,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // ── Metric Cards Row ────────────────────────────────────────────────────────
  Widget _buildMetricCards(bool isDark) {
    final metrics = _isCreator
        ? [
            {
              'label': 'Campaign Cocok',
              'value':
                  _overviewSummary['matching_campaigns']?.toString() ?? '21',
              'icon': Icons.event_available_outlined,
              'color': const Color(0xFF7C3AED),
              'trend': '↑ 5 dari minggu lalu',
            },
            {
              'label': 'Jadwal Posting',
              'value': _overviewSummary['posting_schedule']?.toString() ?? '8',
              'icon': Icons.calendar_today_outlined,
              'color': const Color(0xFF10B981),
              'trend': '↑ 2 dari minggu lalu',
            },
            {
              'label': 'Engagement',
              'value': _overviewSummary['engagement']?.toString() ?? '6,9%',
              'icon': Icons.favorite_border,
              'color': const Color(0xFF3B82F6),
              'trend': 'Rata-rata performa konten',
            },
            {
              'label': 'Pendapatan Bulan Ini',
              'value':
                  _overviewSummary['monthly_income']?.toString() ??
                  'Rp18.450.000',
              'icon': Icons.account_balance_wallet_outlined,
              'color': const Color(0xFFF97316),
              'trend': '↑ 24% dari bulan lalu',
            },
          ]
        : [
            {
              'label': 'Kebutuhan Aktif',
              'value': _overviewSummary['active_needs']?.toString() ?? '12',
              'icon': Icons.description_outlined,
              'color': const Color(0xFF3B82F6),
              'trend': '↑ 2 dari minggu lalu',
            },
            {
              'label': 'Proposal Masuk',
              'value': _overviewSummary['proposals_count']?.toString() ?? '28',
              'icon': Icons.mail_outline,
              'color': const Color(0xFF10B981),
              'trend': '↑ 6 dari minggu lalu',
            },
            {
              'label': 'Proyek Berjalan',
              'value': _overviewSummary['running_projects']?.toString() ?? '6',
              'icon': Icons.folder_open,
              'color': const Color(0xFF14B8A6),
              'trend': '↑ 1 dari minggu lalu',
            },
            {
              'label': 'Estimasi Pengeluaran',
              'value':
                  _overviewSummary['estimated_expenses']?.toString() ??
                  'Rp18.750.000',
              'icon': Icons.account_balance_wallet_outlined,
              'color': const Color(0xFF7C3AED),
              'trend': '↑ 12% dari bulan lalu',
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
              boxShadow: !isDark
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (m['color'] as Color).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    m['icon'] as IconData,
                    color: m['color'] as Color,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  m['label'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  m['value'] as String,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  m['trend'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    color: m['color'] as Color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Recommendation Row (Creator: Peluang / Client: Kreator) ─────────────────
  Widget _buildRecommendationSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _isCreator
                  ? 'Rekomendasi Untuk Anda'
                  : 'Kreator Rekomendasi Untuk Anda',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => _navigateTo('Lihat Semua'),
              child: Text(
                'Lihat Semua',
                style: TextStyle(
                  color: AppTheme.primaryPurple,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 310,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.hardEdge,
            itemCount: _isCreator
                ? _mockOpportunities.length
                : (_vendorRecommendations.isNotEmpty
                      ? _vendorRecommendations.length
                      : _mockCreators.length),
            itemBuilder: (context, index) {
              if (_isCreator) {
                return _buildOpportunityCard(_mockOpportunities[index], isDark);
              }
              final vendor = _vendorRecommendations.isNotEmpty
                  ? _vendorRecommendations[index]
                  : _mockCreators[index];
              return _buildCreatorCard(vendor, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOpportunityCard(Map<String, dynamic> item, bool isDark) {
    final gradientColors =
        item['gradient_colors'] as List<Color>? ??
        [AppTheme.primaryPurple, AppTheme.deepPurple];
    final badgeColor = item['badge_color'] as Color? ?? AppTheme.primaryPurple;

    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: !isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    item['icon'] as IconData? ?? Icons.image_outlined,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 40,
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      item['badge']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.bookmark_border,
                      color: AppTheme.primaryPurple,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title']?.toString() ?? '-',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: isDark
                            ? AppTheme.textMuted
                            : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          item['location']?.toString() ?? '-',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppTheme.textMuted
                                : Colors.grey.shade500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item['price']?.toString() ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 34,
                    child: item['badge'] == 'KOLABORASI'
                        ? ElevatedButton(
                            onPressed: () => _navigateTo(
                              item['action_label']?.toString() ?? '',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF97316),
                              padding: const EdgeInsets.symmetric(vertical: 0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              item['action_label']?.toString() ?? '',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : OutlinedButton(
                            onPressed: () => _navigateTo(
                              item['action_label']?.toString() ?? '',
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: BorderSide(
                                color: AppTheme.primaryPurple.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Text(
                              item['action_label']?.toString() ??
                                  'Lihat Detail',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.primaryPurple,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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

  Widget _buildCreatorCard(Map<String, dynamic> vendor, bool isDark) {
    final gradientColors =
        vendor['gradient_colors'] as List<Color>? ??
        [AppTheme.primaryPurple, AppTheme.deepPurple];
    final category = vendor['category']?.toString() ?? 'Creator';
    final categoryIcon = _getCategoryIcon(category);

    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: !isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child:
                      vendor['avatar_url'] != null &&
                          vendor['avatar_url'].toString().isNotEmpty
                      ? Image.network(
                          vendor['avatar_url'].toString(),
                          width: double.infinity,
                          height: 100,
                          fit: BoxFit.cover,
                        )
                      : Icon(
                          categoryIcon,
                          color: Colors.white.withValues(alpha: 0.5),
                          size: 40,
                        ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.bookmark_border,
                      color: AppTheme.primaryPurple,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vendor['name']?.toString() ?? '-',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    category,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 10,
                        color: isDark
                            ? AppTheme.textMuted
                            : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          vendor['location']?.toString() ??
                              'Bandung, Indonesia',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? AppTheme.textMuted
                                : Colors.grey.shade500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.star, size: 12, color: Colors.amber.shade600),
                      const SizedBox(width: 3),
                      Text(
                        '${vendor['rating'] ?? '4.8'} (${vendor['review_count'] ?? '0'} ulasan)',
                        style: const TextStyle(fontSize: 10),
                      ),
                      const Spacer(),
                      Text(
                        vendor['starting_price']?.toString() ?? 'Rp 150.000',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 32,
                    child: OutlinedButton(
                      onPressed: () => _navigateTo('Cari Kreator'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: BorderSide(
                          color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'Lihat Profil',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.primaryPurple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'fotografer':
      case 'fotografi':
        return Icons.camera_alt_outlined;
      case 'videografer':
      case 'video':
        return Icons.videocam_outlined;
      case 'desainer':
      case 'desain':
        return Icons.palette_outlined;
      case 'konten kreator':
      case 'konten':
        return Icons.phone_android;
      default:
        return Icons.person_outline;
    }
  }

  // ── Three Column Section ────────────────────────────────────────────────────
  Widget _buildThreeColumnSection(bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 700) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildProjectNeedsSection(isDark)),
          const SizedBox(width: 16),
          Expanded(child: _buildAgendaSection(isDark)),
          const SizedBox(width: 16),
          Expanded(child: _buildProjectAssetsSection(isDark)),
        ],
      );
    }
    return Column(
      children: [
        _buildProjectNeedsSection(isDark),
        const SizedBox(height: 16),
        _buildAgendaSection(isDark),
        const SizedBox(height: 16),
        _buildProjectAssetsSection(isDark),
      ],
    );
  }

  Widget _buildSectionHeader(
    String title, {
    VoidCallback? onViewAll,
    String viewAllLabel = 'Lihat Semua',
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            child: Text(
              viewAllLabel,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.primaryPurple,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProjectNeedsSection(bool isDark) {
    final needs = _projectNeeds.isNotEmpty
        ? _projectNeeds
        : (_isCreator
              ? [
                  {
                    'title': 'Brief campaign skincare',
                    'status': 'Berjalan',
                    'status_color': '#10B981',
                    'description': 'Brand Kosmetik Lokal',
                  },
                  {
                    'title': 'Draft script reels',
                    'status': 'Diproses',
                    'status_color': '#F59E0B',
                    'description': 'Campaign Minuman Herbal',
                  },
                  {
                    'title': 'Review caption promosi',
                    'status': 'Menunggu',
                    'status_color': '#3B82F6',
                    'description': 'Produk Fashion Lokal',
                  },
                  {
                    'title': 'Kirim preview UGC',
                    'status': 'Selesai',
                    'status_color': '#10B981',
                    'description': 'Brand Makanan Sehat',
                  },
                  {
                    'title': 'Upload hasil final',
                    'status': 'Menunggu',
                    'status_color': '#F59E0B',
                    'description': 'Paket Monthly Content',
                  },
                ]
              : [
                  {
                    'title': 'Foto Katalog Produk',
                    'status': 'Baru',
                    'status_color': '#7C3AED',
                    'description': 'Toko Fashion',
                  },
                  {
                    'title': 'Video Promosi Instagram',
                    'status': 'Diproses',
                    'status_color': '#F59E0B',
                    'description': 'Toko Fashion',
                  },
                  {
                    'title': 'Dokumentasi Event Komunitas',
                    'status': 'Briefing',
                    'status_color': '#3B82F6',
                    'description': 'Komunitas',
                  },
                  {
                    'title': 'Desain Poster Campaign',
                    'status': 'Selesai',
                    'status_color': '#10B981',
                    'description': 'Promo Brand',
                  },
                ]);

    return Container(
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
          _buildSectionHeader(
            _isCreator ? 'Proyek & Aktivitas' : 'A. Kebutuhan & Proyek',
            onViewAll: () => _navigateTo('Lihat Semua Proyek'),
          ),
          const SizedBox(height: 12),
          ...needs.map((need) => _buildNeedItem(need, isDark)),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => _navigateTo('Semua Proyek'),
              child: Text(
                _isCreator
                    ? 'Lihat Semua Proyek →'
                    : 'Semua Kebutuhan & Proyek →',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeedItem(Map<String, dynamic> need, bool isDark) {
    Color statusColor;
    try {
      final hex =
          (need['status_color'] as String?)?.replaceFirst('#', '') ?? '7C3AED';
      statusColor = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      statusColor = AppTheme.primaryPurple;
    }

    final title = need['title']?.toString() ?? '-';
    IconData itemIcon;
    if (title.toLowerCase().contains('foto') ||
        title.toLowerCase().contains('preview') ||
        title.toLowerCase().contains('upload')) {
      itemIcon = Icons.photo_camera_outlined;
    } else if (title.toLowerCase().contains('video') ||
        title.toLowerCase().contains('reels') ||
        title.toLowerCase().contains('script')) {
      itemIcon = Icons.videocam_outlined;
    } else if (title.toLowerCase().contains('dokumentasi') ||
        title.toLowerCase().contains('event')) {
      itemIcon = Icons.event_outlined;
    } else if (title.toLowerCase().contains('desain') ||
        title.toLowerCase().contains('poster')) {
      itemIcon = Icons.palette_outlined;
    } else if (title.toLowerCase().contains('brief') ||
        title.toLowerCase().contains('review') ||
        title.toLowerCase().contains('caption')) {
      itemIcon = Icons.edit_note_outlined;
    } else {
      itemIcon = Icons.folder_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(itemIcon, color: statusColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  need['description']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              need['status']?.toString() ?? '',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaSection(bool isDark) {
    final agenda = _agenda.isNotEmpty
        ? _agenda
        : (_isCreator
              ? [
                  {
                    'title': 'Meeting brief campaign',
                    'date': '24',
                    'month': 'Mei',
                    'time': '10:00 - 11:00 WIB',
                    'type': 'Hari ini',
                    'type_color': '#7C3AED',
                  },
                  {
                    'title': 'Shooting konten produk',
                    'date': '25',
                    'month': 'Mei',
                    'time': '13:00 - 16:00 WIB',
                    'type': 'Besok',
                    'type_color': '#3B82F6',
                  },
                  {
                    'title': 'Editing reels',
                    'date': '27',
                    'month': 'Mei',
                    'time': '10:00 - 12:00 WIB',
                    'type': '2 hari lagi',
                    'type_color': '#3B82F6',
                  },
                  {
                    'title': 'Posting campaign',
                    'date': '29',
                    'month': 'Mei',
                    'time': '16:00 - 17:00 WIB',
                    'type': '4 hari lagi',
                    'type_color': '#F97316',
                  },
                  {
                    'title': 'Evaluasi hasil',
                    'date': '31',
                    'month': 'Mei',
                    'time': '10:00 - 11:00 WIB',
                    'type': '6 hari lagi',
                    'type_color': '#EF4444',
                  },
                ]
              : [
                  {
                    'title': 'Meeting Briefing Proyek Foto',
                    'date': '24',
                    'month': 'Mei',
                    'time': '09:00 - 10:00',
                    'type': 'Online',
                    'type_color': '#3B82F6',
                  },
                  {
                    'title': 'Review Draft Desain Poster',
                    'date': '25',
                    'month': 'Mei',
                    'time': '14:00 - 15:00',
                    'type': 'Online',
                    'type_color': '#3B82F6',
                  },
                  {
                    'title': 'Shooting Day - Video Promosi',
                    'date': '27',
                    'month': 'Mei',
                    'time': '08:00 - 17:00',
                    'type': 'Offline',
                    'type_color': '#F97316',
                  },
                  {
                    'title': 'Deadline Penyerahan Hasil Akhir',
                    'date': '29',
                    'month': 'Mei',
                    'time': '23:59',
                    'type': 'Deadline',
                    'type_color': '#EF4444',
                  },
                ]);

    return Container(
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
          _buildSectionHeader(
            _isCreator ? 'Agenda / Kalender' : 'B. Agenda / Kalender',
            viewAllLabel: 'Lihat Kalender',
          ),
          const SizedBox(height: 12),
          ...agenda.map((item) => _buildAgendaItem(item, isDark)),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => _navigateTo('Lihat Semua Agenda'),
              child: Text(
                'Lihat Semua Agenda →',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaItem(Map<String, dynamic> item, bool isDark) {
    Color typeColor;
    try {
      final hex =
          (item['type_color'] as String?)?.replaceFirst('#', '') ?? '3B82F6';
      typeColor = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      typeColor = Colors.blue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item['date']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryPurple,
                  ),
                ),
                Text(
                  item['month']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 9,
                    color: AppTheme.primaryPurple,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title']?.toString() ?? '-',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  item['time']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              item['type']?.toString() ?? '',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: typeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectAssetsSection(bool isDark) {
    final assets = _projectAssets.isNotEmpty
        ? _projectAssets
        : (_isCreator
              ? _mockPortfolio
              : [
                  {
                    'title': 'Foto Katalog Produk',
                    'type': 'photo',
                    'gradient': [
                      const Color(0xFF667EE7),
                      const Color(0xFF764BA2),
                    ],
                  },
                  {
                    'title': 'Video Promosi Instagram',
                    'type': 'video',
                    'gradient': [
                      const Color(0xFFF093FB),
                      const Color(0xFFF5576C),
                    ],
                  },
                  {
                    'title': 'Dokumentasi Event',
                    'type': 'photo',
                    'gradient': [
                      const Color(0xFF4FACFE),
                      const Color(0xFF00F2FE),
                    ],
                  },
                  {
                    'title': 'Desain Poster Campaign',
                    'type': 'design',
                    'gradient': [
                      const Color(0xFF43E97B),
                      const Color(0xFF38F9D7),
                    ],
                  },
                ]);

    return Container(
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
          _buildSectionHeader(
            _isCreator ? 'Portofolio & Karya' : 'C. Aset & Hasil Proyek',
            viewAllLabel: 'Lihat Semua',
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.2,
            ),
            itemCount: assets.length > (_isCreator ? 6 : 4)
                ? (_isCreator ? 6 : 4)
                : assets.length,
            itemBuilder: (context, index) =>
                _buildAssetThumbnail(assets[index], isDark),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => _navigateTo('Lihat Semua Karya'),
              child: Text(
                _isCreator ? 'Lihat Semua Karya →' : 'Buka Semua Aset →',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetThumbnail(Map<String, dynamic> asset, bool isDark) {
    final gradientColors =
        asset['gradient'] as List<Color>? ??
        [AppTheme.primaryPurple, AppTheme.deepPurple];
    final type = asset['type']?.toString() ?? 'photo';
    IconData typeIcon =
        asset['icon'] as IconData? ??
        (type == 'video'
            ? Icons.play_circle_outline
            : (type == 'design'
                  ? Icons.palette_outlined
                  : Icons.photo_outlined));

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              typeIcon,
              color: Colors.white.withValues(alpha: 0.5),
              size: 28,
            ),
          ),
          Positioned(
            bottom: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                asset['title']?.toString() ?? '',
                style: const TextStyle(
                  fontSize: 8,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (type == 'video')
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Workflow Steps ──────────────────────────────────────────────────────────
  Widget _buildWorkflowSection(bool isDark) {
    final steps = _isCreator
        ? [
            {
              'number': '1',
              'title': 'Profil Lengkap',
              'subtitle': 'Lengkapi data diri & niche',
              'icon': Icons.person_outline,
              'color': const Color(0xFF7C3AED),
            },
            {
              'number': '2',
              'title': 'Dapat Rekomendasi',
              'subtitle': 'Terima peluang sesuai niche',
              'icon': Icons.auto_awesome,
              'color': const Color(0xFFEAB308),
            },
            {
              'number': '3',
              'title': 'Ajukan Proposal',
              'subtitle': 'Kirim penawaran terbaik',
              'icon': Icons.description_outlined,
              'color': const Color(0xFF3B82F6),
            },
            {
              'number': '4',
              'title': 'Jalankan Campaign',
              'subtitle': 'Produksi & publikasi konten',
              'icon': Icons.event_note_outlined,
              'color': const Color(0xFF7C3AED),
            },
            {
              'number': '5',
              'title': 'Dapat Review',
              'subtitle': 'Terima ulasan & rating klien',
              'icon': Icons.chat_bubble_outline,
              'color': const Color(0xFF10B981),
            },
            {
              'number': '6',
              'title': 'Reputasi Naik',
              'subtitle': 'Peluang & penghasilan meningkat',
              'icon': Icons.trending_up,
              'color': const Color(0xFF14B8A6),
            },
          ]
        : [
            {
              'number': '1',
              'title': 'Buat Kebutuhan',
              'subtitle': 'Tulis brief yang dibutuhkan',
              'icon': Icons.edit_note,
              'color': const Color(0xFF3B82F6),
            },
            {
              'number': '2',
              'title': 'Dapat Rekomendasi',
              'subtitle': 'Sistem mencocokkan kreator',
              'icon': Icons.auto_awesome,
              'color': const Color(0xFF7C3AED),
            },
            {
              'number': '3',
              'title': 'Terima Proposal',
              'subtitle': 'Bandingkan tawaran',
              'icon': Icons.mail_outline,
              'color': const Color(0xFF10B981),
            },
            {
              'number': '4',
              'title': 'Pilih Kreator',
              'subtitle': 'Setujui kolaborator terbaik',
              'icon': Icons.person_add_outlined,
              'color': const Color(0xFFF97316),
            },
            {
              'number': '5',
              'title': 'Pantau Proyek',
              'subtitle': 'Review progres & hasil',
              'icon': Icons.analytics_outlined,
              'color': const Color(0xFF14B8A6),
            },
            {
              'number': '6',
              'title': 'Beri Ulasan',
              'subtitle': 'Bangun reputasi ekosistem',
              'icon': Icons.star_outline,
              'color': const Color(0xFFEAB308),
            },
          ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
          Text(
            _isCreator
                ? 'Alur Pertumbuhan Content Creator di Kreavana'
                : 'Alur Kerja Klien di Kreavana',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: steps.map((step) {
                final isLast = step == steps.last;
                final color = step['color'] as Color;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              step['icon'] as IconData,
                              color: color,
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${step['number']}. ${step['title']}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            step['subtitle']!.toString(),
                            style: TextStyle(
                              fontSize: 9,
                              color: isDark
                                  ? AppTheme.textMuted
                                  : Colors.grey.shade500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Icon(
                        Icons.arrow_forward,
                        color: AppTheme.primaryPurple.withValues(alpha: 0.4),
                        size: 18,
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Right Sidebar ──────────────────────────────────────────────────────────

  Widget _buildRightSidebar(bool isDark) {
    return Column(
      children: [
        _buildClientProfileCard(isDark),
        const SizedBox(height: 16),
        if (_isCreator)
          _buildReputationCard(isDark)
        else
          _buildProjectStatusCard(isDark),
        const SizedBox(height: 16),
        _buildAiTipsCard(isDark),
        const SizedBox(height: 16),
        _buildQuickActionsCard(isDark),
      ],
    );
  }

  Widget _buildClientProfileCard(bool isDark) {
    final completion = _isCreator ? 0.83 : 0.68;
    final completionLabel =
        '${(completion * 100).round()}% ${_isCreator ? "profil lengkap" : "lengkap"}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: !isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _isCreator
                      ? 'Profil Singkat Kreator'
                      : 'Profil Singkat Klien',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _navigateTo('Lihat Profil'),
                child: Text(
                  'Lihat Profil',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.1),
                backgroundImage:
                    widget.user.avatarUrl != null &&
                        widget.user.avatarUrl!.isNotEmpty
                    ? NetworkImage(widget.user.avatarUrl!)
                    : null,
                child:
                    widget.user.avatarUrl == null ||
                        widget.user.avatarUrl!.isEmpty
                    ? Icon(
                        Icons.person,
                        color: AppTheme.primaryPurple,
                        size: 28,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.user.subRole ??
                          (_isCreator ? 'Content Creator' : 'Klien Umum'),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.textMuted
                            : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: isDark
                              ? AppTheme.textMuted
                              : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Jakarta, Indonesia',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppTheme.textMuted
                                : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            completionLabel,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: completion,
              minHeight: 8,
              backgroundColor: isDark
                  ? Colors.grey.shade800
                  : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _navigateTo('Lengkapi Profil'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                side: BorderSide(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'Lengkapi Profil',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Creator-only: Reputasi & Ulasan card
  Widget _buildReputationCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: !isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Keterampilan Kreator',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.1),
                backgroundImage: null,
                child: const Icon(
                  Icons.person,
                  color: AppTheme.primaryPurple,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aruna Studio',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fotografer Profesional',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.textMuted
                            : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildSkillChip('Berkomunikasi', isDark),
                        const SizedBox(width: 6),
                        _buildSkillChip('Fotografi', isDark),
                        const SizedBox(width: 6),
                        _buildSkillChip('Edit Video', isDark),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildRatingStat('4.9', 'Rating', Icons.star_outline, isDark),
              const SizedBox(width: 24),
              _buildRatingStat('128', 'Ulasan', Icons.reviews_outlined, isDark),
              const SizedBox(width: 24),
              _buildRatingStat('6', 'Proyek', Icons.work_outline, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkillChip(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.primaryPurple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.primaryPurple.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: AppTheme.primaryPurple,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildRatingStat(
    String value,
    String label,
    IconData icon,
    bool isDark,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white70 : Colors.grey.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildProjectStatusCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: !isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Status Proyek & Vendor',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => _navigateTo('Lihat Semua'),
                child: Text(
                  'Lihat Semua',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatusItem('6', 'Proyek Berjalan', isDark)),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatusItem('18', 'Proposal Tersimpan', isDark),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildVendorScoreItem(
                  'Respon Vendor',
                  '4.8',
                  Icons.access_time,
                  isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildVendorScoreItem(
                  'Kualitas',
                  '4.6',
                  Icons.verified_outlined,
                  isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildVendorScoreItem(
                  'Ketepatan Waktu',
                  '4.7',
                  Icons.schedule,
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String count, String label, bool isDark) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryPurple,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildVendorScoreItem(
    String label,
    String score,
    IconData icon,
    bool isDark,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 18,
          color: AppTheme.primaryPurple.withValues(alpha: 0.6),
        ),
        const SizedBox(height: 4),
        Text(
          score,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAiTipsCard(bool isDark) {
    final tips = _isCreator
        ? [
            'Perbarui media kit dan insight terbaru',
            'Tambahkan portofolio reels & UGC',
            'Aktif di komunitas creator untuk kolaborasi',
            'Lengkapi verifikasi identitas',
          ]
        : [
            'Buat brief lebih detail agar proposal lebih tepat',
            'Simpan kreator favorit untuk proyek berikutnya',
            'Gunakan agenda untuk memantau deadline',
          ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: !isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isCreator
                ? 'Rekomendasi AI / Tips Berikutnya'
                : 'Rekomendasi AI / Tips Berikutnya',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          ...tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: AppTheme.primaryPurple,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tip,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.textMuted
                            : Colors.grey.shade700,
                        height: 1.4,
                      ),
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

  Widget _buildQuickActionsCard(bool isDark) {
    final actions = _isCreator
        ? [
            {'icon': Icons.search, 'label': 'Cari Peluang'},
            {'icon': Icons.description_outlined, 'label': 'Ajukan Proposal'},
            {
              'icon': Icons.add_photo_alternate_outlined,
              'label': 'Tambah Karya',
            },
            {'icon': Icons.calendar_month_outlined, 'label': 'Atur Jadwal'},
            {'icon': Icons.groups_outlined, 'label': 'Kirim Insight'},
            {'icon': Icons.payments_outlined, 'label': 'Tarik Dana'},
          ]
        : [
            {'icon': Icons.add_circle_outline, 'label': 'Buat Kebutuhan'},
            {'icon': Icons.search, 'label': 'Cari Kreator'},
            {'icon': Icons.person_add_outlined, 'label': 'Undang Kreator'},
            {'icon': Icons.compare_arrows, 'label': 'Bandingkan Proposal'},
            {'icon': Icons.check_circle_outline, 'label': 'Setujui Proyek'},
            {'icon': Icons.payment, 'label': 'Bayar DP'},
          ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: !isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aksi Cepat',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 14,
              childAspectRatio: 0.85,
            ),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              return InkWell(
                onTap: () => _navigateTo(action['label'] as String),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        action['icon'] as IconData,
                        color: AppTheme.primaryPurple,
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          action['label'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.grey.shade800,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: Row(
          children: [
            // Search bar
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
                      color: isDark
                          ? AppTheme.inputBorder
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Icon(
                        Icons.search,
                        color: isDark
                            ? AppTheme.textMuted
                            : Colors.grey.shade500,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isCreator
                              ? 'Cari peluang UGC, reels, review produk, campaign brand, event...'
                              : 'Cari kreator, layanan, proyek, atau komunitas...',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppTheme.textMuted
                                : Colors.grey.shade500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '⌘K',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppTheme.textMuted
                                : Colors.grey.shade600,
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
            // Notification bell
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.notifications_none_outlined,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                    size: 24,
                  ),
                  onPressed: () => _navigateTo('Notifikasi'),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _isCreator ? '9' : '2',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            // Chat icon
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.chat_bubble_outline,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                    size: 24,
                  ),
                  onPressed: () => _navigateTo('Pesan'),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _isCreator ? '5' : '3',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Theme toggle
            Builder(
              builder: (btnCtx) => IconButton(
                key: _themeBtnKey,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) => RotationTransition(
                    turns: Tween(begin: 0.75, end: 1.0).animate(anim),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Icon(
                    isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    key: ValueKey(isDark),
                    size: 20,
                  ),
                ),
                onPressed: () {
                  final box =
                      _themeBtnKey.currentContext?.findRenderObject()
                          as RenderBox?;
                  final origin = box != null
                      ? box.localToGlobal(box.size.center(Offset.zero))
                      : const Offset(0, 0);
                  ThemeTransitionService.animateToggle(
                    origin: origin,
                    toDark: !isDark,
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            // User profile
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.primaryPurple.withValues(
                    alpha: 0.1,
                  ),
                  backgroundImage:
                      widget.user.avatarUrl != null &&
                          widget.user.avatarUrl!.isNotEmpty
                      ? NetworkImage(widget.user.avatarUrl!)
                      : null,
                  child:
                      widget.user.avatarUrl == null ||
                          widget.user.avatarUrl!.isEmpty
                      ? Icon(
                          Icons.person,
                          color: AppTheme.primaryPurple,
                          size: 20,
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.user.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.user.subRole ??
                          (_isCreator ? 'Content Creator' : 'Klien Umum'),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.textMuted
                            : Colors.grey.shade600,
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
        bottom: (widget.user.role == 'creator' && widget.user.isCreatorApproved)
            ? PreferredSize(
                preferredSize: const Size.fromHeight(65),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: RoleToggle(
                    currentRole: _currentRole,
                    isCreator: true,
                    onRoleChanged: (role) {
                      setState(() => _currentRole = role);
                      _loadDashboardData();
                    },
                  ),
                ),
              )
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          child: MediaQuery.of(context).size.width > 1100
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeroBanner(isDark),
                          const SizedBox(height: 24),
                          _buildMetricCards(isDark),
                          const SizedBox(height: 28),
                          _buildRecommendationSection(isDark),
                          const SizedBox(height: 28),
                          _buildThreeColumnSection(isDark),
                          const SizedBox(height: 28),
                          _buildWorkflowSection(isDark),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    SizedBox(width: 300, child: _buildRightSidebar(isDark)),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroBanner(isDark),
                    const SizedBox(height: 24),
                    _buildMetricCards(isDark),
                    const SizedBox(height: 28),
                    _buildRecommendationSection(isDark),
                    const SizedBox(height: 28),
                    _buildThreeColumnSection(isDark),
                    const SizedBox(height: 28),
                    _buildWorkflowSection(isDark),
                  ],
                ),
        ),
      ),
    );
  }
}
