import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../widgets/role_toggle.dart';
import '../../../services/theme_transition_service.dart';
import '../../../services/api_service.dart';
import '../../../screens/agenda_screen.dart';
import '../../../screens/marketplace_karya_screen.dart';
import '../../../screens/profile_screen.dart';
import '../../../screens/global_search_screen.dart';
import '../../../models/user_model.dart';
import '../../../screens/buat_kebutuhan_screen.dart';
import '../../../screens/proyek_saya_screen.dart';
import '../../../screens/explore_screen.dart';
import '../../../screens/notifications_screen.dart';
import '../../../screens/direct_message_screen.dart';
import '../../../screens/transfer_screen.dart';
import '../../../screens/laporan_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late String _currentRole;
  Map<String, dynamic> _overviewSummary = {};
  List<Map<String, dynamic>> _vendorRecommendations = [];
  List<Map<String, dynamic>> _projectNeeds = [];
  List<Map<String, dynamic>> _agenda = [];
  List<Map<String, dynamic>> _projectAssets = [];

  late AnimationController _statsAnimController;
  late List<Animation<double>> _statsAnims;
  late AnimationController _handWaveController;
  late Animation<double> _handWaveAnimation;

  bool get _isCreator => _currentRole == 'creator';

  final GlobalKey _themeBtnKey = GlobalKey();

  // ── Mock creators ────────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _mockCreators = [
    {'name':'Aruna Studio','category':'Fotografer','location':'Jakarta','rating':'4.9','review_count':'128','starting_price':'Mulai Rp750.000','gradient_colors':[const Color(0xFF667EE7),const Color(0xFF764BA2)]},
    {'name':'Frame Story','category':'Videografer','location':'Bandung','rating':'4.8','review_count':'96','starting_price':'Mulai Rp1.200.000','gradient_colors':[const Color(0xFFF093FB),const Color(0xFFF5576C)]},
    {'name':'Graphix Studio','category':'Desainer','location':'Yogyakarta','rating':'4.9','review_count':'110','starting_price':'Mulai Rp450.000','gradient_colors':[const Color(0xFF4FACFE),const Color(0xFF00F2FE)]},
    {'name':'Kreasi Konten ID','category':'Konten Kreator','location':'Surabaya','rating':'4.7','review_count':'84','starting_price':'Mulai Rp800.000','gradient_colors':[const Color(0xFF43E97B),const Color(0xFF38F9D7)]},
  ];

  // ── Mock opportunities ───────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _mockOpportunities = [
    {'title':'UGC Review Produk','badge':'UGC','badge_color':const Color(0xFF7C3AED),'location':'Jakarta','price':'Rp2.800.000','action_label':'Lihat Detail','icon':Icons.spa_outlined,'gradient_colors':[const Color(0xFF667EE7),const Color(0xFF764BA2)]},
    {'title':'Konten Reels Brand','badge':'REELS','badge_color':const Color(0xFFEC4899),'location':'Bekasi','price':'Rp3.500.000','action_label':'Lihat Detail','icon':Icons.videocam_outlined,'gradient_colors':[const Color(0xFFF093FB),const Color(0xFFF5576C)]},
    {'title':'Liputan Event Komunitas','badge':'EVENT','badge_color':const Color(0xFF3B82F6),'location':'Bandung','price':'Rp2.200.000','action_label':'Lihat Detail','icon':Icons.celebration_outlined,'gradient_colors':[const Color(0xFF4FACFE),const Color(0xFF00F2FE)]},
    {'title':'Komunitas Content Creator ID','badge':'KOLABORASI','badge_color':const Color(0xFFF97316),'location':'Online','price':'Gratis','action_label':'Gabung Komunitas','icon':Icons.groups_outlined,'gradient_colors':[const Color(0xFF43E97B),const Color(0xFF38F9D7)]},
  ];

  final List<Map<String, dynamic>> _mockPortfolio = [
    {'title':'UGC','type':'photo','gradient':[const Color(0xFF667EE7),const Color(0xFF764BA2)],'icon':Icons.spa_outlined},
    {'title':'Reels','type':'video','gradient':[const Color(0xFFF093FB),const Color(0xFFF5576C)],'icon':Icons.videocam_outlined},
    {'title':'Review','type':'photo','gradient':[const Color(0xFF4FACFE),const Color(0xFF00F2FE)],'icon':Icons.rate_review_outlined},
    {'title':'Lifestyle','type':'photo','gradient':[const Color(0xFFFDBB2D),const Color(0xFF22C1C3)],'icon':Icons.landscape_outlined},
    {'title':'Beauty','type':'photo','gradient':[const Color(0xFFF7971E),const Color(0xFFFFD200)],'icon':Icons.face_retouching_natural_outlined},
    {'title':'Campaign','type':'photo','gradient':[const Color(0xFF43E97B),const Color(0xFF38F9D7)],'icon':Icons.campaign_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _currentRole = widget.user.role;
    _statsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _statsAnims = List.generate(
      4,
      (i) => CurvedAnimation(
        parent: _statsAnimController,
        curve: Interval(i * 0.15, 0.6 + i * 0.1, curve: Curves.easeOutCubic),
      ),
    );
    _handWaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _handWaveAnimation = Tween<double>(begin: -0.35, end: 0.35).animate(
      CurvedAnimation(parent: _handWaveController, curve: Curves.easeInOut),
    );
    _loadDashboardData();
  }

  @override
  void dispose() {
    _statsAnimController.dispose();
    _handWaveController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user.role != oldWidget.user.role ||
        widget.user.subRole != oldWidget.user.subRole) {
      setState(() => _currentRole = widget.user.role);
      _loadDashboardData();
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      if (mounted) {
        setState(() {
          _overviewSummary = {
            'active_needs': '12','proposals_count': '28',
            'running_projects': '6','estimated_expenses': 'Rp18.750.000',
            'matching_campaigns': '21','posting_schedule': '8',
            'engagement': '6,9%','monthly_income': 'Rp18.450.000',
          };
          _vendorRecommendations = _mockCreators;
          _projectNeeds = [
            {'title':'Foto Katalog Produk','status':'Baru','status_color':'#7C3AED','description':'Toko Fashion'},
            {'title':'Video Promosi Instagram','status':'Diproses','status_color':'#F59E0B','description':'Toko Fashion'},
            {'title':'Dokumentasi Event Komunitas','status':'Briefing','status_color':'#3B82F6','description':'Komunitas'},
            {'title':'Desain Poster Campaign','status':'Selesai','status_color':'#10B981','description':'Promo Brand'},
          ];
          _agenda = [
            {'title':'Meeting Briefing Proyek Foto','date':'24','month':'Mei','time':'09:00 - 10:00','type':'Online','type_color':'#3B82F6'},
            {'title':'Review Draft Desain Poster','date':'25','month':'Mei','time':'14:00 - 15:00','type':'Online','type_color':'#3B82F6'},
            {'title':'Shooting Day - Video Promosi','date':'27','month':'Mei','time':'08:00 - 17:00','type':'Offline','type_color':'#F97316'},
            {'title':'Deadline Penyerahan Hasil','date':'29','month':'Mei','time':'23:59','type':'Deadline','type_color':'#EF4444'},
          ];
          _projectAssets = [
            {'title':'Foto Katalog Produk','type':'photo','gradient':[const Color(0xFF667EE7),const Color(0xFF764BA2)]},
            {'title':'Video Promosi Instagram','type':'video','gradient':[const Color(0xFFF093FB),const Color(0xFFF5576C)]},
            {'title':'Dokumentasi Event','type':'photo','gradient':[const Color(0xFF4FACFE),const Color(0xFF00F2FE)]},
            {'title':'Desain Poster Campaign','type':'design','gradient':[const Color(0xFF43E97B),const Color(0xFF38F9D7)]},
          ];
        });
        _statsAnimController.forward(from: 0);
      }
    } catch (_) {}
  }

  void _showDummyActionMessage(String action) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Fitur "$action" segera hadir!'),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _navigateTo(String feature) {
    switch (feature) {
      case 'Buat Kebutuhan':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const BuatKebutuhanScreen()));
        break;
      case 'Cari Kreator':
      case 'Cari Campaign':
        Navigator.push(context, MaterialPageRoute(builder: (_) => ExploreScreen(user: widget.user)));
        break;
      case 'Lengkapi Profil':
      case 'Lihat Profil':
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(user: widget.user, onUserUpdated: widget.onUserUpdated, onLogout: () {})));
        break;
      case 'Lihat Semua':
      case 'Lihat Semua Proyek':
      case 'Semua Proyek':
      case 'Semua Kebutuhan & Proyek':
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProyekSayaScreen(user: widget.user)));
        break;
      case 'Lihat Semua Agenda':
      case 'Lihat Kalender':
      case 'Atur Jadwal':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AgendaScreen()));
        break;
      case 'Lihat Semua Karya':
      case 'Buka Semua Aset':
      case 'Tambah Karya':
        Navigator.push(context, MaterialPageRoute(builder: (_) => MarketplaceKaryaScreen(user: widget.user, onUserUpdated: widget.onUserUpdated)));
        break;
      case 'Notifikasi':
        Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen(userId: widget.user.id ?? '')));
        break;
      case 'Pesan':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const DirectMessageScreen()));
        break;
      case 'Bayar DP':
      case 'Tarik Dana':
        Navigator.push(context, MaterialPageRoute(builder: (_) => TransferScreen(user: widget.user)));
        break;
      case 'Laporan':
        Navigator.push(context, MaterialPageRoute(builder: (_) => LaporanScreen(user: widget.user, onUserUpdated: widget.onUserUpdated)));
        break;
      case 'Cari Peluang':
        Navigator.push(context, MaterialPageRoute(builder: (_) => ExploreScreen(user: widget.user)));
        break;
      case 'Bandingkan':
      case 'Setujui Proyek':
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProyekSayaScreen(user: widget.user)));
        break;
      case 'Kirim Proposal':
        Navigator.push(context, MaterialPageRoute(builder: (_) => ExploreScreen(user: widget.user)));
        break;
      case 'Komunitas':
        Navigator.push(context, MaterialPageRoute(builder: (_) => ExploreScreen(user: widget.user)));
        break;
      default:
        _showDummyActionMessage(feature);
    }
  }

  // ── Hero Banner ──────────────────────────────────────────────────────────────
  Widget _buildHeroBanner(bool isDark) {
    final greeting = _isCreator ? 'Halo, Kreator!' : 'Halo, ${widget.user.name.split(' ').first}!';
    final subtitle = _isCreator
        ? 'Temukan campaign, kelola jadwal, bangun media kit, dan tingkatkan reputasimu.'
        : 'Buat kebutuhan, temukan kreator terbaik, dan pantau proyek dalam satu tempat.';
    final primaryLabel = _isCreator ? 'Lengkapi Profil' : 'Buat Kebutuhan';
    final secondaryLabel = _isCreator ? 'Cari Campaign' : 'Cari Kreator';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B38), const Color(0xFF13111F)]
              : [const Color(0xFFEDE9FE), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : AppTheme.dividerLight,
        ),
        boxShadow: isDark ? AppTheme.cardShadowDark : AppTheme.cardShadowLight,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Role badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: AppTheme.pinkPurpleGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _isCreator ? '✦ KREATOR' : '✦ KLIEN',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      greeting,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textDark,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedBuilder(
                      animation: _handWaveAnimation,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _handWaveAnimation.value,
                          alignment: Alignment.bottomCenter,
                          child: child,
                        );
                      },
                      child: Text(
                        '👋',
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _HeroButton(
                      label: primaryLabel,
                      icon: _isCreator ? Icons.settings_suggest_outlined : Icons.add_circle_outline,
                      onTap: () => _navigateTo(primaryLabel),
                      gradient: AppTheme.primaryGradient,
                    ),
                    _HeroButton(
                      label: secondaryLabel,
                      icon: Icons.search_rounded,
                      onTap: () => _navigateTo(secondaryLabel),
                      outlined: true,
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Decorative illustration
          SizedBox(
            width: 100,
            height: 120,
            child: Stack(
              children: [
                Positioned(
                  bottom: 0, left: 0,
                  child: Container(
                    width: 80, height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _isCreator ? Icons.camera_alt_outlined : Icons.laptop_mac_outlined,
                      color: AppTheme.primaryPurple.withValues(alpha: 0.5),
                      size: 28,
                    ),
                  ),
                ),
                Positioned(
                  top: 0, right: 0,
                  child: Container(
                    width: 56, height: 70,
                    decoration: BoxDecoration(
                      color: AppTheme.accentPink.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.person_outline,
                      color: AppTheme.accentPink.withValues(alpha: 0.4),
                      size: 32,
                    ),
                  ),
                ),
                Positioned(
                  top: 4, left: 4,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: AppTheme.cardShadowLight,
                    ),
                    child: Icon(Icons.play_arrow_rounded, color: AppTheme.primaryPurple, size: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Animated Metric Cards ────────────────────────────────────────────────────
  Widget _buildMetricCards(bool isDark) {
    final metrics = _isCreator
        ? [
            {'label':'Campaign Cocok','value':_overviewSummary['matching_campaigns']?.toString() ?? '21','icon':Icons.event_available_outlined,'color':const Color(0xFF7C3AED),'trend':'↑ 5 minggu ini'},
            {'label':'Jadwal Posting','value':_overviewSummary['posting_schedule']?.toString() ?? '8','icon':Icons.calendar_today_outlined,'color':const Color(0xFF10B981),'trend':'↑ 2 minggu ini'},
            {'label':'Engagement','value':_overviewSummary['engagement']?.toString() ?? '6,9%','icon':Icons.favorite_border,'color':const Color(0xFF3B82F6),'trend':'Rata-rata konten'},
            {'label':'Pendapatan Bulan Ini','value':_overviewSummary['monthly_income']?.toString() ?? 'Rp18,4 Jt','icon':Icons.account_balance_wallet_outlined,'color':const Color(0xFFF97316),'trend':'↑ 24% bulan lalu'},
          ]
        : [
            {'label':'Kebutuhan Aktif','value':_overviewSummary['active_needs']?.toString() ?? '12','icon':Icons.description_outlined,'color':const Color(0xFF3B82F6),'trend':'↑ 2 minggu ini'},
            {'label':'Proposal Masuk','value':_overviewSummary['proposals_count']?.toString() ?? '28','icon':Icons.mail_outline,'color':const Color(0xFF10B981),'trend':'↑ 6 minggu ini'},
            {'label':'Proyek Berjalan','value':_overviewSummary['running_projects']?.toString() ?? '6','icon':Icons.folder_open,'color':const Color(0xFF14B8A6),'trend':'↑ 1 minggu ini'},
            {'label':'Est. Pengeluaran','value':_overviewSummary['estimated_expenses']?.toString() ?? 'Rp18,7 Jt','icon':Icons.account_balance_wallet_outlined,'color':const Color(0xFF7C3AED),'trend':'↑ 12% bulan ini'},
          ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        if (isMobile) {
          // 2x2 grid on mobile
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildAnimatedMetricCard(metrics[0], 0, isDark)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildAnimatedMetricCard(metrics[1], 1, isDark)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildAnimatedMetricCard(metrics[2], 2, isDark)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildAnimatedMetricCard(metrics[3], 3, isDark)),
                ],
              ),
            ],
          );
        }
        // Desktop: single row
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(metrics.length, (i) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 6, right: i == metrics.length - 1 ? 0 : 6),
                child: _buildAnimatedMetricCard(metrics[i], i, isDark),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildAnimatedMetricCard(Map<String, Object> m, int i, bool isDark) {
    return FadeTransition(
      opacity: _statsAnims[i],
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
            .animate(_statsAnims[i]),
        child: _MetricCard(
          label: m['label'] as String,
          value: m['value'] as String,
          icon: (m['icon'] as IconData?) ?? Icons.image_outlined,
          color: m['color'] as Color,
          trend: m['trend'] as String,
          isDark: isDark,
        ),
      ),
    );
  }

  // ── Recommendation Section ───────────────────────────────────────────────────
  Widget _buildRecommendationSection(bool isDark) {
    final items = _isCreator ? _mockOpportunities : (_vendorRecommendations.isNotEmpty ? _vendorRecommendations : _mockCreators);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: _isCreator ? 'Rekomendasi Untuk Anda' : 'Kreator Rekomendasi',
          onViewAll: () => _navigateTo('Lihat Semua'),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.hardEdge,
            itemCount: items.length,
            itemBuilder: (context, index) => _isCreator
                ? _buildOpportunityCard(items[index], isDark)
                : _buildCreatorCard(items[index], isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildOpportunityCard(Map<String, dynamic> item, bool isDark) {
    final gradientColors = item['gradient_colors'] as List<Color>? ?? [AppTheme.primaryPurple, AppTheme.deepPurple];
    final badgeColor = item['badge_color'] as Color? ?? AppTheme.primaryPurple;
    return Container(
      width: 210,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight),
        boxShadow: isDark ? null : AppTheme.cardShadowLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image/gradient header
          Container(
            height: 90,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusMD)),
            ),
            child: Stack(children: [
              Center(child: Icon((item['icon'] as IconData?) ?? Icons.image_outlined, color: Colors.white.withValues(alpha: 0.4), size: 36)),
              Positioned(top: 8, left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(20)),
                  child: Text(item['badge']?.toString() ?? '', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              Positioned(top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.bookmark_border, color: AppTheme.primaryPurple, size: 14),
                ),
              ),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.location_on_outlined, size: 10, color: AppTheme.textMuted),
                    const SizedBox(width: 2),
                    Expanded(child: Text(item['location']?.toString() ?? '', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted), overflow: TextOverflow.ellipsis)),
                  ]),
                  const Spacer(),
                  Text(item['price']?.toString() ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity, height: 28,
                    child: ElevatedButton(
                      onPressed: () => _navigateTo(item['action_label']?.toString() ?? ''),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: badgeColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(item['action_label']?.toString() ?? 'Lihat', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
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
    final gradientColors = vendor['gradient_colors'] as List<Color>? ?? [AppTheme.primaryPurple, AppTheme.deepPurple];
    final category = vendor['category']?.toString() ?? 'Creator';
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight),
        boxShadow: isDark ? null : AppTheme.cardShadowLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 90,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusMD)),
            ),
            child: Stack(children: [
              Center(child: Icon(Icons.person_outline, color: Colors.white.withValues(alpha: 0.4), size: 40)),
              Positioned(top: 8, left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(20)),
                  child: Text(category, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.black87)),
                ),
              ),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vendor['name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.location_on_outlined, size: 10, color: AppTheme.textMuted),
                    const SizedBox(width: 2),
                    Expanded(child: Text(vendor['location']?.toString() ?? '', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted), overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.star, size: 11, color: Colors.amber.shade600),
                    const SizedBox(width: 2),
                    Text('${vendor['rating'] ?? '4.8'} (${vendor['review_count'] ?? '0'})', style: const TextStyle(fontSize: 10)),
                  ]),
                  const Spacer(),
                  Text(vendor['starting_price']?.toString() ?? '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primaryPurple)),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity, height: 28,
                    child: OutlinedButton(
                      onPressed: () => _navigateTo('Cari Kreator'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: BorderSide(color: AppTheme.primaryPurple.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        foregroundColor: AppTheme.primaryPurple,
                      ),
                      child: const Text('Lihat Profil', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
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

  // ── Three-column section ─────────────────────────────────────────────────────
  Widget _buildThreeColumnSection(bool isDark) {
    final w = MediaQuery.of(context).size.width;
    if (w > 700) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _buildProjectNeedsSection(isDark)),
        const SizedBox(width: 14),
        Expanded(child: _buildAgendaSection(isDark)),
        const SizedBox(width: 14),
        Expanded(child: _buildProjectAssetsSection(isDark)),
      ]);
    }
    return Column(children: [
      _buildProjectNeedsSection(isDark),
      const SizedBox(height: 14),
      _buildAgendaSection(isDark),
      const SizedBox(height: 14),
      _buildProjectAssetsSection(isDark),
    ]);
  }

  Widget _buildProjectNeedsSection(bool isDark) {
    final needs = _projectNeeds.isNotEmpty ? _projectNeeds : [
      {'title':'Brief campaign skincare','status':'Berjalan','status_color':'#10B981','description':'Brand Kosmetik'},
      {'title':'Draft script reels','status':'Diproses','status_color':'#F59E0B','description':'Campaign Herbal'},
      {'title':'Review caption promosi','status':'Menunggu','status_color':'#3B82F6','description':'Produk Fashion'},
    ];
    return _SectionCard(
      title: _isCreator ? 'Proyek & Aktivitas' : 'Kebutuhan & Proyek',
      onViewAll: () => _navigateTo('Lihat Semua Proyek'),
      isDark: isDark,
      child: Column(
        children: needs.map((need) => _buildNeedItem(need, isDark)).toList(),
      ),
    );
  }

  Widget _buildNeedItem(Map<String, dynamic> need, bool isDark) {
    Color statusColor;
    try {
      final hex = (need['status_color'] as String?)?.replaceFirst('#', '') ?? '7C3AED';
      statusColor = Color(int.parse('FF$hex', radix: 16));
    } catch (_) { statusColor = AppTheme.primaryPurple; }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.inputDark : AppTheme.inputLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: Row(children: [
        Container(width: 32, height: 32,
          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.folder_outlined, color: statusColor, size: 16),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(need['title']?.toString() ?? '-', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(need['description']?.toString() ?? '', style: TextStyle(fontSize: 10, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
          child: Text(need['status']?.toString() ?? '', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor)),
        ),
      ]),
    );
  }

  Widget _buildAgendaSection(bool isDark) {
    final agenda = _agenda.isNotEmpty ? _agenda : [
      {'title':'Meeting brief campaign','date':'24','month':'Mei','time':'10:00 - 11:00','type':'Hari ini','type_color':'#7C3AED'},
      {'title':'Shooting konten produk','date':'25','month':'Mei','time':'13:00 - 16:00','type':'Besok','type_color':'#3B82F6'},
      {'title':'Posting campaign','date':'29','month':'Mei','time':'16:00','type':'4 hari lagi','type_color':'#F97316'},
    ];
    return _SectionCard(
      title: _isCreator ? 'Agenda / Kalender' : 'Agenda & Jadwal',
      onViewAll: () => _navigateTo('Lihat Kalender'),
      viewAllLabel: 'Kalender',
      isDark: isDark,
      child: Column(children: agenda.map((item) => _buildAgendaItem(item, isDark)).toList()),
    );
  }

  Widget _buildAgendaItem(Map<String, dynamic> item, bool isDark) {
    Color typeColor;
    try {
      final hex = (item['type_color'] as String?)?.replaceFirst('#', '') ?? '3B82F6';
      typeColor = Color(int.parse('FF$hex', radix: 16));
    } catch (_) { typeColor = Colors.blue; }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.inputDark : AppTheme.inputLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: AppTheme.primaryPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(item['date']?.toString() ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
            Text(item['month']?.toString() ?? '', style: TextStyle(fontSize: 8, color: AppTheme.primaryPurple, fontWeight: FontWeight.w500)),
          ]),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item['title']?.toString() ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(item['time']?.toString() ?? '', style: TextStyle(fontSize: 10, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: Text(item['type']?.toString() ?? '', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: typeColor)),
        ),
      ]),
    );
  }

  Widget _buildProjectAssetsSection(bool isDark) {
    final assets = _projectAssets.isNotEmpty ? _projectAssets : (_isCreator ? _mockPortfolio : [
      {'title':'Foto Katalog','type':'photo','gradient':[const Color(0xFF667EE7),const Color(0xFF764BA2)]},
      {'title':'Video Promosi','type':'video','gradient':[const Color(0xFFF093FB),const Color(0xFFF5576C)]},
      {'title':'Dokumentasi Event','type':'photo','gradient':[const Color(0xFF4FACFE),const Color(0xFF00F2FE)]},
      {'title':'Desain Poster','type':'design','gradient':[const Color(0xFF43E97B),const Color(0xFF38F9D7)]},
    ]);
    return _SectionCard(
      title: _isCreator ? 'Portofolio & Karya' : 'Aset & Hasil Proyek',
      onViewAll: () => _navigateTo('Lihat Semua Karya'),
      isDark: isDark,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.4),
        itemCount: assets.length > 4 ? 4 : assets.length,
        itemBuilder: (context, index) => _buildAssetThumbnail(assets[index], isDark),
      ),
    );
  }

  Widget _buildAssetThumbnail(Map<String, dynamic> asset, bool isDark) {
    final gradientColors = asset['gradient'] as List<Color>? ?? [AppTheme.primaryPurple, AppTheme.deepPurple];
    final type = asset['type']?.toString() ?? 'photo';
    final iconData = (asset['icon'] as IconData?) ?? (type == 'video' ? Icons.play_circle_outline : Icons.photo_outlined);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(children: [
        Center(child: Icon(iconData, color: Colors.white.withValues(alpha: 0.4), size: 24)),
        Positioned(bottom: 5, left: 6, right: 6,
          child: Text(asset['title']?.toString() ?? '', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600, shadows: [Shadow(blurRadius: 4, color: Colors.black54)]), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  // ── Workflow steps ───────────────────────────────────────────────────────────
  Widget _buildWorkflowSection(bool isDark) {
    final steps = _isCreator ? [
      {'n':'1','title':'Profil Lengkap','sub':'Isi data & niche','icon':Icons.person_outline,'color':const Color(0xFF7C3AED)},
      {'n':'2','title':'Dapat Rekomendasi','sub':'Peluang sesuai niche','icon':Icons.auto_awesome,'color':const Color(0xFFEAB308)},
      {'n':'3','title':'Ajukan Proposal','sub':'Kirim penawaran terbaik','icon':Icons.description_outlined,'color':const Color(0xFF3B82F6)},
      {'n':'4','title':'Jalankan Campaign','sub':'Produksi & publikasi','icon':Icons.event_note_outlined,'color':const Color(0xFF7C3AED)},
      {'n':'5','title':'Dapat Review','sub':'Ulasan & rating klien','icon':Icons.star_outline,'color':const Color(0xFF10B981)},
      {'n':'6','title':'Reputasi Naik','sub':'Peluang meningkat','icon':Icons.trending_up,'color':const Color(0xFF14B8A6)},
    ] : [
      {'n':'1','title':'Buat Kebutuhan','sub':'Tulis brief','icon':Icons.edit_note,'color':const Color(0xFF3B82F6)},
      {'n':'2','title':'Cocokkan Kreator','sub':'AI matching otomatis','icon':Icons.auto_awesome,'color':const Color(0xFF7C3AED)},
      {'n':'3','title':'Terima Proposal','sub':'Bandingkan tawaran','icon':Icons.mail_outline,'color':const Color(0xFF10B981)},
      {'n':'4','title':'Pilih Kreator','sub':'Setujui kolaborator','icon':Icons.person_add_outlined,'color':const Color(0xFFF97316)},
      {'n':'5','title':'Pantau Proyek','sub':'Review progres','icon':Icons.analytics_outlined,'color':const Color(0xFF14B8A6)},
      {'n':'6','title':'Beri Ulasan','sub':'Bangun ekosistem','icon':Icons.star_outline,'color':const Color(0xFFEAB308)},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight),
        boxShadow: isDark ? null : AppTheme.cardShadowLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_isCreator ? 'Alur Pertumbuhan Kreator' : 'Alur Kerja Klien', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('6 langkah menuju kolaborasi sukses di Kreavana', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight)),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: steps.asMap().entries.map((e) {
                final step = e.value;
                final isLast = e.key == steps.length - 1;
                final color = step['color'] as Color;
                return Row(children: [
                  SizedBox(
                    width: 110,
                    child: Column(children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)]),
                          shape: BoxShape.circle,
                          border: Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Icon((step['icon'] as IconData?) ?? Icons.image_outlined, color: color, size: 20),
                      ),
                      const SizedBox(height: 8),
                      Text('${step['n']}. ${step['title']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      const SizedBox(height: 3),
                      Text(step['sub'].toString(), style: TextStyle(fontSize: 9, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight), textAlign: TextAlign.center),
                    ]),
                  ),
                  if (!isLast)
                    Icon(Icons.chevron_right_rounded, color: AppTheme.primaryPurple.withValues(alpha: 0.3), size: 20),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Right sidebar ────────────────────────────────────────────────────────────
  Widget _buildRightSidebar(bool isDark) {
    return Column(children: [
      _buildProfileCard(isDark),
      const SizedBox(height: 14),
      _buildQuickActionsCard(isDark),
      const SizedBox(height: 14),
      _buildAiTipsCard(isDark),
    ]);
  }

  Widget _buildProfileCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight),
        boxShadow: isDark ? null : AppTheme.cardShadowLight,
      ),
      child: Column(
        children: [
          Row(children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.1),
              backgroundImage: widget.user.avatarUrl?.isNotEmpty == true ? CachedNetworkImageProvider(ApiService.resolveAssetUrl(widget.user.avatarUrl!)) : null,
              child: widget.user.avatarUrl?.isNotEmpty != true ? Icon(Icons.person, color: AppTheme.primaryPurple, size: 26) : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(widget.user.subRole ?? (_isCreator ? 'Content Creator' : 'Klien'), style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight)),
            ])),
            TextButton(
              onPressed: () => _navigateTo('Lihat Profil'),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: const Text('Profil', style: TextStyle(fontSize: 11)),
            ),
          ]),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _isCreator ? 0.83 : 0.68,
              minHeight: 6,
              backgroundColor: isDark ? AppTheme.inputBorder : AppTheme.dividerLight,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
            ),
          ),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Kelengkapan profil', style: TextStyle(fontSize: 10, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight)),
            Text(_isCreator ? '83%' : '68%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _navigateTo('Lengkapi Profil'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                side: BorderSide(color: AppTheme.primaryPurple.withValues(alpha: 0.4)),
                foregroundColor: AppTheme.primaryPurple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Lengkapi Profil', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(bool isDark) {
    final actions = _isCreator ? [
      {'icon':Icons.search,'label':'Cari Peluang'},
      {'icon':Icons.description_outlined,'label':'Kirim Proposal'},
      {'icon':Icons.add_photo_alternate_outlined,'label':'Tambah Karya'},
      {'icon':Icons.calendar_month_outlined,'label':'Atur Jadwal'},
      {'icon':Icons.payments_outlined,'label':'Tarik Dana'},
      {'icon':Icons.groups_outlined,'label':'Komunitas'},
    ] : [
      {'icon':Icons.add_circle_outline,'label':'Buat Kebutuhan'},
      {'icon':Icons.search,'label':'Cari Kreator'},
      {'icon':Icons.compare_arrows,'label':'Bandingkan'},
      {'icon':Icons.check_circle_outline,'label':'Setujui Proyek'},
      {'icon':Icons.payment,'label':'Bayar DP'},
      {'icon':Icons.analytics_outlined,'label':'Laporan'},
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight),
        boxShadow: isDark ? null : AppTheme.cardShadowLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Aksi Cepat', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 10, childAspectRatio: 0.9),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              return InkWell(
                onTap: () => _navigateTo(action['label'] as String),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withValues(alpha: isDark ? 0.1 : 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: isDark ? 0.2 : 0.1)),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon((action['icon'] as IconData?) ?? Icons.image_outlined, color: AppTheme.primaryPurple, size: 22),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(action['label'] as String, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.textDark), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAiTipsCard(bool isDark) {
    final tips = _isCreator
        ? ['Perbarui media kit dan insight terbaru', 'Tambahkan portofolio reels & UGC terbaru', 'Aktif di komunitas creator untuk kolaborasi']
        : ['Buat brief lebih detail agar proposal lebih tepat', 'Simpan kreator favorit untuk proyek berikutnya', 'Gunakan agenda untuk memantau deadline'];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark ? [const Color(0xFF1E1B38), const Color(0xFF13111F)] : [const Color(0xFFF5F3FF), Colors.white],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: isDark ? AppTheme.inputBorder : AppTheme.dividerLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 8),
            const Text('Tips dari AI', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 14),
          ...tips.map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                margin: const EdgeInsets.only(top: 3),
                width: 6, height: 6,
                decoration: const BoxDecoration(color: AppTheme.primaryPurple, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(tip, style: TextStyle(fontSize: 12, height: 1.4, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight))),
            ]),
          )),
        ],
      ),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      toolbarHeight: 70,
      title: Row(children: [
        // Search bar
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GlobalSearchScreen(user: widget.user))),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.inputDark : AppTheme.inputLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight),
              ),
              child: Row(children: [
                const SizedBox(width: 12),
                Icon(Icons.search, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isCreator ? 'Cari peluang, campaign, komunitas...' : 'Cari kreator, layanan, proyek...',
                    style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text('⌘K', style: TextStyle(fontSize: 10, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight)),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Notification
        _NotifIconBtn(icon: Icons.notifications_none_outlined, count: _isCreator ? 9 : 2, onTap: () => _navigateTo('Notifikasi'), isDark: isDark),
        const SizedBox(width: 2),
        // Chat
        _NotifIconBtn(icon: Icons.chat_bubble_outline, count: _isCreator ? 5 : 3, onTap: () => _navigateTo('Pesan'), isDark: isDark),
        const SizedBox(width: 8),
        // Theme toggle
        Builder(builder: (btnCtx) => IconButton(
          key: _themeBtnKey,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => RotationTransition(turns: Tween(begin: 0.75, end: 1.0).animate(anim), child: FadeTransition(opacity: anim, child: child)),
            child: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, key: ValueKey(isDark), size: 20),
          ),
          onPressed: () {
            final box = _themeBtnKey.currentContext?.findRenderObject() as RenderBox?;
            final origin = box != null ? box.localToGlobal(box.size.center(Offset.zero)) : Offset.zero;
            ThemeTransitionService.animateToggle(origin: origin, toDark: !isDark);
          },
        )),
        // Avatar
        GestureDetector(
          onTap: () => _navigateTo('Lihat Profil'),
          child: Row(children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.15),
              backgroundImage: widget.user.avatarUrl?.isNotEmpty == true ? CachedNetworkImageProvider(ApiService.resolveAssetUrl(widget.user.avatarUrl!)) : null,
              child: widget.user.avatarUrl?.isNotEmpty != true ? Icon(Icons.person, color: AppTheme.primaryPurple, size: 18) : null,
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(widget.user.name.split(' ').first, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Text(widget.user.subRole ?? (_isCreator ? 'Creator' : 'Klien'), style: TextStyle(fontSize: 10, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight)),
            ]),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 16, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight),
          ]),
        ),
      ]),
      bottom: (widget.user.role == 'creator' && widget.user.isCreatorApproved)
          ? PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: RoleToggle(
                  currentRole: _currentRole,
                  isCreator: true,
                  onRoleChanged: (role) { setState(() => _currentRole = role); _loadDashboardData(); },
                ),
              ),
            )
          : null,
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width > 1100;

    return Scaffold(
      appBar: _buildAppBar(isDark),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          child: isWide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildHeroBanner(isDark),
                    const SizedBox(height: 20),
                    _buildMetricCards(isDark),
                    const SizedBox(height: 24),
                    _buildRecommendationSection(isDark),
                    const SizedBox(height: 24),
                    _buildThreeColumnSection(isDark),
                    const SizedBox(height: 24),
                    _buildWorkflowSection(isDark),
                  ])),
                  const SizedBox(width: 20),
                  SizedBox(width: 290, child: _buildRightSidebar(isDark)),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildHeroBanner(isDark),
                  const SizedBox(height: 20),
                  _buildMetricCards(isDark),
                  const SizedBox(height: 24),
                  _buildRecommendationSection(isDark),
                  const SizedBox(height: 24),
                  _buildThreeColumnSection(isDark),
                  const SizedBox(height: 24),
                  _buildWorkflowSection(isDark),
                ]),
        ),
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────
class _HeroButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final LinearGradient? gradient;
  final bool outlined;
  final bool isDark;

  const _HeroButton({required this.label, required this.icon, required this.onTap, this.gradient, this.outlined = false, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          side: BorderSide(color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight),
          foregroundColor: isDark ? Colors.white : AppTheme.textDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(10),
        boxShadow: AppTheme.primaryShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label, value, trend;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _MetricCard({required this.label, required this.value, required this.icon, required this.color, required this.trend, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight),
        boxShadow: isDark ? null : AppTheme.cardShadowLight,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 6),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        ),
        const SizedBox(height: 3),
        Text(trend, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;
  final String viewAllLabel;

  const _SectionHeader({required this.title, this.onViewAll, this.viewAllLabel = 'Lihat Semua'});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      if (onViewAll != null)
        TextButton(
          onPressed: onViewAll,
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
          child: Text(viewAllLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryPurple)),
        ),
    ]);
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;
  final String viewAllLabel;
  final bool isDark;
  final Widget child;

  const _SectionCard({required this.title, this.onViewAll, this.viewAllLabel = 'Lihat Semua', required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight),
        boxShadow: isDark ? null : AppTheme.cardShadowLight,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionHeader(title: title, onViewAll: onViewAll, viewAllLabel: viewAllLabel),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }
}

class _NotifIconBtn extends StatelessWidget {
  final IconData icon;
  final int count;
  final VoidCallback onTap;
  final bool isDark;

  const _NotifIconBtn({required this.icon, required this.count, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      IconButton(
        icon: Icon(icon, size: 22, color: isDark ? Colors.white70 : Colors.grey.shade700),
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
      ),
      if (count > 0)
        Positioned(
          top: 6, right: 6,
          child: Container(
            width: 16, height: 16,
            decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
            child: Center(child: Text(count > 9 ? '9+' : '$count', style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold))),
          ),
        ),
    ]);
  }
}
