import '../../../services/badge_service.dart';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../models/user_model.dart';
import '../../../services/api_service.dart';
import '../../../services/theme_transition_service.dart';
import '../../../screens/explore_screen.dart';
import '../../../screens/peluang_proyek_screen.dart';
import '../../../screens/mitra_komunitas_screen.dart';
import '../../../screens/global_search_screen.dart';
import '../../../screens/notifications_screen.dart';
import '../../../screens/direct_message_screen.dart';
import '../../../screens/profile_screen.dart';
import '../../../services/portfolio_service.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../../widgets/skeleton/skeleton_grid.dart';

class CreatorTalentDashboardScreen extends StatefulWidget {
  final UserModel user;
  final ValueChanged<UserModel> onUserUpdated;

  const CreatorTalentDashboardScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
  });

  @override
  State<CreatorTalentDashboardScreen> createState() =>
      _CreatorTalentDashboardScreenState();
}

class _CreatorTalentDashboardScreenState
    extends State<CreatorTalentDashboardScreen> {
  final GlobalKey _themeBtnKey = GlobalKey();

  static const Color _primaryColor = Color(0xFF8B5CF6);
  static const Color _secondaryColor = Color(0xFF3B82F6);

  List<PortfolioItemModel> _portfolioItems = [];
  bool _isLoadingPortfolio = true;

  @override
  void initState() {
    super.initState();
    _loadPortfolio();
  }

  Future<void> _loadPortfolio() async {
    final items = await PortfolioService.getPortfolio();
    if (mounted) {
      setState(() {
        _portfolioItems = items;
        _isLoadingPortfolio = false;
      });
    }
  }

  Future<void> _addPortfolioItem() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.first.path!);
    final nameController = TextEditingController();

    if (!mounted) return;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nama Portofolio'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: 'Contoh: Color Grading Sinematik',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    final item = await PortfolioService.addPortfolio(
      title: name,
      imageFile: file,
    );

    if (item != null && mounted) {
      setState(() => _portfolioItems.add(item));
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
              _buildRecommendationsSection(isDark),
              const SizedBox(height: 24),
              _buildMiddleThreeColumns(isDark),
              const SizedBox(height: 24),
              _buildGrowthRoadmap(isDark),
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
                        'Cari peluang, proyek, atau karya Talent / Model...',
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
          const SizedBox(width: 20),
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
          const SizedBox(width: 12),
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
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(
                  user: widget.user,
                  onUserUpdated: widget.onUserUpdated,
                  onLogout: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                ),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _primaryColor.withValues(alpha: 0.1),
                  backgroundImage: widget.user.avatarUrl?.isNotEmpty == true
                      ? NetworkImage(
                          ApiService.resolveAssetUrl(widget.user.avatarUrl!),
                        )
                      : null,
                  child: widget.user.avatarUrl?.isNotEmpty != true
                      ? const Icon(
                          Icons.star_outline,
                          color: _primaryColor,
                          size: 20,
                        )
                      : null,
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
                      'Talent / Model',
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
          ),
        ],
      ),
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

  Widget _buildHeroBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)]
              : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selamat Datang, Talent / Model 👋',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Kelola portofolio, tawaran pekerjaan, dan proyek Talent / Model Anda secara efisien.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : const Color(0xFF4338CA),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(
                            user: widget.user,
                            onUserUpdated: widget.onUserUpdated,
                            onLogout: () => Navigator.of(
                              context,
                            ).popUntil((r) => r.isFirst),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.person_outline, size: 18),
                      label: const Text('Lengkapi Profil'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExploreScreen(user: widget.user),
                        ),
                      ),
                      icon: const Icon(Icons.search, size: 18),
                      label: const Text('Cari Job Talent / Model'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCards(bool isDark) {
    final metrics = [
      {
        'label': 'Peluang Cocok',
        'value': '24',
        'sub': '↑ 12 dari minggu lalu',
        'icon': Icons.explore_outlined,
        'color': _primaryColor,
      },
      {
        'label': 'Proyek Aktif',
        'value': '7',
        'sub': '↑ 2 dari minggu lalu',
        'icon': Icons.folder_outlined,
        'color': const Color(0xFF10B981),
      },
      {
        'label': 'Skor Reputasi',
        'value': '92/100',
        'sub': 'Sangat Baik',
        'icon': Icons.star_outline,
        'color': const Color(0xFFF59E0B),
      },
      {
        'label': 'Pendapatan Bulan Ini',
        'value': 'Rp12.450.000',
        'sub': '↑ 18% dari bulan lalu',
        'icon': Icons.account_balance_wallet_outlined,
        'color': _secondaryColor,
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        Widget buildCard(Map<String, Object> m) {
          return Container(
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        m['label'] as String,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
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
                  ],
                ),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    m['value'] as String,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  m['sub'] as String,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }

        if (isMobile) {
          final rows = <Widget>[];
          for (var i = 0; i < metrics.length; i += 2) {
            final rc = <Widget>[Expanded(child: buildCard(metrics[i]))];
            if (i + 1 < metrics.length) {
              rc.add(const SizedBox(width: 10));
              rc.add(Expanded(child: buildCard(metrics[i + 1])));
            }
            if (i > 0) rows.add(const SizedBox(height: 10));
            rows.add(Row(children: rc));
          }
          return Column(children: rows);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: metrics.map((m) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: buildCard(m),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildRecommendationsSection(bool isDark) {
    final recs = [
      {
        'title': 'Festival Budaya Nusantara 2024',
        'type': 'EVENT',
        'price': 'Rp8.000.000',
        'color': Colors.purple,
      },
      {
        'title': 'Video Promosi Produk Kreatif',
        'type': 'PROYEK',
        'price': 'Rp5.000.000',
        'color': Colors.blue,
      },
      {
        'title': 'Kolaborasi Konten Series',
        'type': 'KOLABORASI',
        'price': 'Kesepakatan Bersama',
        'color': Colors.teal,
      },
      {
        'title': 'Komunitas Talent / Model Indonesia',
        'type': 'KOMUNITAS',
        'price': 'Gratis',
        'color': Colors.orange,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rekomendasi Untuk Anda',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: recs.map((r) {
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardBg : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: (r['color'] as Color).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        r['type'] as String,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: r['color'] as Color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      r['title'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r['price'] as String,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () {
                        if (r['type'] == 'KOMUNITAS') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  MitraKomunitasScreen(user: widget.user),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PeluangProyekScreen(user: widget.user),
                            ),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 32),
                      ),
                      child: const Text(
                        'Lihat Detail',
                        style: TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMiddleThreeColumns(bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 700) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildProjectsAndActivity(isDark)),
          const SizedBox(width: 16),
          Expanded(child: _buildAgendaCalendar(isDark)),
          const SizedBox(width: 16),
          Expanded(child: _buildPortfolioGrid(isDark)),
        ],
      );
    }
    return Column(
      children: [
        _buildProjectsAndActivity(isDark),
        const SizedBox(height: 16),
        _buildAgendaCalendar(isDark),
        const SizedBox(height: 16),
        _buildPortfolioGrid(isDark),
      ],
    );
  }

  Widget _buildProjectsAndActivity(bool isDark) {
    final items = [
      {
        'title': 'Job Talent / Model Professional',
        'client': 'PT Kreasi Muda',
        'status': 'Baru',
      },
      {
        'title': 'Sesi Project Talent / Model',
        'client': 'Event Musik Jakarta',
        'status': 'Diproses',
      },
      {
        'title': 'Workshop & Training Talent / Model',
        'client': 'Komunitas Kreatif ID',
        'status': 'Deadline',
      },
      {
        'title': 'Project Series Campaign',
        'client': 'Brand Lokal',
        'status': 'Selesai',
      },
    ];

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
          const Text(
            'Proyek & Aktivitas',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: _primaryColor.withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.star,
                      color: _primaryColor,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i['title']!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          i['client']!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    i['status']!,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
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

  Widget _buildAgendaCalendar(bool isDark) {
    final agendas = [
      {'date': '24 JUN', 'title': 'Briefing Project Talent / Model'},
      {'date': '25 SAB', 'title': 'Workshop & Sharing Session'},
      {'date': '27 SEN', 'title': 'Review hasil karya Klien'},
      {'date': '29 RAB', 'title': 'Deadline Final Delivery'},
    ];

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
          const Text(
            'Agenda / Kalender',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...agendas.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      a['date']!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      a['title']!,
                      style: const TextStyle(fontSize: 11),
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

  Widget _buildPortfolioGrid(bool isDark) {
    final accentColor = _primaryColor;
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Portofolio & Karya',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: _addPortfolioItem,
                child: Icon(
                  Icons.add_circle_outline,
                  color: accentColor,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingPortfolio)
            const SkeletonGrid(itemCount: 4)
          else if (_portfolioItems.isEmpty)
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: List.generate(
                6,
                (index) => GestureDetector(
                  onTap: _addPortfolioItem,
                  child: Container(
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.add_photo_alternate_outlined,
                      color: accentColor,
                      size: 20,
                    ),
                  ),
                ),
              ),
            )
          else
            GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _portfolioItems.length + 1,
              itemBuilder: (context, index) {
                if (index == _portfolioItems.length) {
                  return GestureDetector(
                    onTap: _addPortfolioItem,
                    child: Container(
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.add_photo_alternate_outlined,
                        color: accentColor,
                        size: 20,
                      ),
                    ),
                  );
                }
                final item = _portfolioItems[index];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      item.imageUrl != null && item.imageUrl!.isNotEmpty
                          ? Image.network(
                              ApiService.resolveAssetUrl(item.imageUrl!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: accentColor.withValues(alpha: 0.1),
                                child: Icon(
                                  Icons.broken_image,
                                  color: accentColor,
                                  size: 20,
                                ),
                              ),
                            )
                          : Container(
                              color: accentColor.withValues(alpha: 0.1),
                              child: Icon(
                                Icons.image,
                                color: accentColor,
                                size: 20,
                              ),
                            ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () async {
                            await PortfolioService.deletePortfolio(item.id);
                            if (mounted)
                              setState(() => _portfolioItems.removeAt(index));
                          },
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildGrowthRoadmap(bool isDark) {
    final steps = [
      '1. Profil Lengkap',
      '2. Dapat Rekomendasi',
      '3. Ajukan Proposal',
      '4. Kerjakan Proyek',
      '5. Dapat Review',
      '6. Reputasi Naik',
    ];

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
          Text(
            'Alur Pertumbuhan Talent / Model di Kreavana',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: steps
                .map(
                  (s) => Text(
                    s,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
