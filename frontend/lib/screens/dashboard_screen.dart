import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../models/opportunity_model.dart';
import '../services/dashboard_service.dart';
import '../services/profile_service.dart';
import '../services/opportunity_service.dart';
import '../widgets/role_toggle.dart';
import '../widgets/stat_card.dart';
import '../widgets/quick_action_button.dart';
import '../widgets/feature_card.dart';
import '../widgets/ai_matching_banner.dart';
import 'peluang_lokasi_screen.dart';
import 'peluang_proyek_screen.dart';
import '../widgets/opportunity_detail_sheet.dart';
import '../widgets/dashboard_stats_charts.dart';
import '../services/theme_transition_service.dart';
import 'wallet_screen.dart';

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
  late String _selectedPihak;
  bool _isLoading = false;
  List<Map<String, String>> _stats = [];
  Map<String, List<Map<String, String>>> _allPihakStats = {};
  List<OpportunityModel> _opportunities = [];

  /// Key used to find the theme-toggle button's screen position for the
  /// circular reveal animation origin.
  final GlobalKey _themeBtnKey = GlobalKey();

  final List<Map<String, dynamic>> _pihakList = [
    {
      'slug': 'kreator',
      'name': 'Kreator',
      'icon': Icons.brush_outlined,
      'color': const Color(0xFFF97316),
    },
    {
      'slug': 'eo',
      'name': 'Event Org',
      'icon': Icons.event_note_outlined,
      'color': const Color(0xFF3B82F6),
    },
    {
      'slug': 'wo',
      'name': 'Wedding Org',
      'icon': Icons.favorite_border,
      'color': const Color(0xFF8B5CF6),
    },
    {
      'slug': 'sekolah',
      'name': 'Pendidikan',
      'icon': Icons.school_outlined,
      'color': const Color(0xFF10B981),
    },
    {
      'slug': 'umkm',
      'name': 'Bisnis/UMKM',
      'icon': Icons.business_outlined,
      'color': const Color(0xFF06B6D4),
    },
    {
      'slug': 'pemerintah',
      'name': 'Pemerintah',
      'icon': Icons.gavel_outlined,
      'color': const Color(0xFF1E3A8A),
    },
    {
      'slug': 'komunitas',
      'name': 'Komunitas',
      'icon': Icons.groups_outlined,
      'color': const Color(0xFFEC4899),
    },
    {
      'slug': 'organisasi',
      'name': 'Organisasi',
      'icon': Icons.corporate_fare_outlined,
      'color': const Color(0xFF3F51B5),
    },
  ];

  @override
  void initState() {
    super.initState();
    _currentRole = (widget.user.role == 'creator' && widget.user.isCreatorApproved) ? 'creator' : 'user';
    _selectedPihak = widget.user.selectedPihak;
    _loadDashboardData();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user.role != oldWidget.user.role ||
        widget.user.isCreatorApproved != oldWidget.user.isCreatorApproved ||
        widget.user.selectedPihak != oldWidget.user.selectedPihak) {
      setState(() {
        _currentRole = (widget.user.role == 'creator' && widget.user.isCreatorApproved) ? 'creator' : 'user';
        _selectedPihak = widget.user.selectedPihak;
      });
      _loadDashboardData();
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final slugs = _pihakList.map((p) => p['slug'] as String).toList();

      final results = await Future.wait([
        DashboardService.getStats(
          pihak: _selectedPihak,
          roleType: _currentRole,
        ),
        DashboardService.getAllPihakStats(
          pihakSlugs: slugs,
          roleType: _currentRole,
        ),
        DashboardService.getOpportunities(
          pihak: _selectedPihak,
          limit: 5,
        ),
        ProfileService.getProfile(widget.user.id),
      ]);

      if (mounted) {
        setState(() {
          _stats = results[0] as List<Map<String, String>>;
          _allPihakStats = results[1] as Map<String, List<Map<String, String>>>;
          _opportunities = results[2] as List<OpportunityModel>;
          _isLoading = false;
        });

        final profileRes = results[3] as Map<String, dynamic>;
        if (profileRes['success'] == true) {
          widget.onUserUpdated(profileRes['user']);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onPihakSelected(String pihakSlug) async {
    setState(() => _selectedPihak = pihakSlug);

    await ProfileService.updateProfile(
      userId: widget.user.id,
      selectedPihak: pihakSlug,
    );

    final updatedUser = widget.user.copyWith(selectedPihak: pihakSlug);
    widget.onUserUpdated(updatedUser);

    _loadDashboardData();
  }

  void _onRoleChanged(String role) async {
    setState(() => _currentRole = role);

    await ProfileService.updateProfile(
      userId: widget.user.id,
      selectedPihak: _selectedPihak,
    );

    _loadDashboardData();
  }

  Color _getCurrentPihakColor() {
    final match = _pihakList.firstWhere(
      (element) => element['slug'] == _selectedPihak,
      orElse: () => _pihakList.first,
    );
    return match['color'] as Color;
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

  void _navigateToPeluangLokasi() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PeluangLokasiScreen(
          user: widget.user,
          pihakSlug: _selectedPihak,
        ),
      ),
    );
  }

  void _navigateToPeluangProyek() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PeluangProyekScreen(
          user: widget.user,
          pihakSlug: _selectedPihak,
        ),
      ),
    );
  }

  Future<void> _openOpportunityDetail(OpportunityModel op) async {
    var detail = op;
    final fetched = await OpportunityService.getDetail(op.id);
    if (fetched != null) detail = fetched;
    if (mounted) {
      OpportunityDetailSheet.show(
        context,
        opportunity: detail,
        currentUserId: widget.user.id,
      );
    }
  }

  Widget _buildSidebarQuickAction({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: color,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: color, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRupiah(double val) {
    final str = val.toStringAsFixed(0);
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return 'Rp ' + str.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }

  Widget _buildWalletCard(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF312E81), const Color(0xFF1E1B4B)]
              : [const Color(0xFF4F46E5), const Color(0xFF3730A3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.15 : 0.25),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Saldo Dompet',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _formatRupiah(widget.user.balance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WalletScreen(
                    user: widget.user,
                    onUserUpdated: widget.onUserUpdated,
                  ),
                ),
              ).then((_) => _loadDashboardData());
            },
            icon: const Icon(Icons.keyboard_arrow_right_rounded, size: 18),
            label: const Text('Detail'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper: mobile quick-action row ────────────────────────────────────────
  // Membungkus setiap QuickActionButton dengan Expanded agar Row tidak overflow
  // di layar sempit. mainAxisAlignment dibiarkan start karena Expanded
  // sudah mendistribusikan ruang secara merata.
  Widget _buildMobileQuickActions(List<Widget> buttons) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: buttons
          .map((btn) => Expanded(child: btn))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pihakColor = _getCurrentPihakColor();
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: isDark ? AppTheme.cardBg : Colors.grey.shade200,
              backgroundImage: widget.user.avatarUrl != null && widget.user.avatarUrl!.isNotEmpty
                  ? NetworkImage(widget.user.avatarUrl!)
                  : const AssetImage('assets/brandlogo.png') as ImageProvider,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, ${widget.user.name}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  '@${widget.user.username}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
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
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  key: ValueKey(isDark),
                ),
              ),
              onPressed: () {
                final box = _themeBtnKey.currentContext?.findRenderObject()
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
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadDashboardData,
          ),
        ],
        bottom: (widget.user.role == 'creator' && widget.user.isCreatorApproved)
            ? PreferredSize(
                preferredSize: const Size.fromHeight(65),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: RoleToggle(
                    currentRole: _currentRole,
                    isCreator: true,
                    onRoleChanged: _onRoleChanged,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWalletCard(theme, isDark),
              const SizedBox(height: 24),

              // 1. Category Selection Slider
              const Text(
                'Kategori Pihak / Peran',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 85,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pihakList.length,
                  itemBuilder: (context, index) {
                    final item = _pihakList[index];
                    final isSelected = item['slug'] == _selectedPihak;
                    final itemColor = item['color'] as Color;

                    return GestureDetector(
                      onTap: () => _onPihakSelected(item['slug']),
                      child: Container(
                        width: 75,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? itemColor.withValues(alpha: 0.15)
                              : (isDark ? AppTheme.cardBg : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? itemColor
                                : (isDark ? AppTheme.inputBorder : Colors.transparent),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              item['icon'] as IconData,
                              color: isSelected ? itemColor : Colors.grey.shade600,
                              size: 24,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item['name'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected
                                    ? (isDark ? Colors.white : itemColor)
                                    : (isDark ? AppTheme.textMuted : Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // 2. Stats Grid
              Text(
                'Statistik ${_pihakList.firstWhere((e) => e['slug'] == _selectedPihak)['name']} (${_currentRole == 'creator' ? 'Creator' : 'Klien'})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isDesktop ? 4 : 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: isDesktop ? 2.2 : 1.5,
                      ),
                      itemCount: _stats.length > 4 ? 4 : _stats.length,
                      itemBuilder: (context, index) {
                        final stat = _stats[index];
                        return StatCard(
                          label: stat['label'] ?? '',
                          value: stat['value'] ?? '',
                          iconName: stat['icon'] ?? '',
                          accentColor: pihakColor,
                        );
                      },
                    ),
              if (!_isLoading && _allPihakStats.isNotEmpty) ...[
                const SizedBox(height: 28),
                DashboardStatsCharts(
                  pihakList: _pihakList,
                  allPihakStats: _allPihakStats,
                  selectedPihak: _selectedPihak,
                  currentRole: _currentRole,
                  isDark: isDark,
                ),
              ],
              const SizedBox(height: 24),

              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AiMatchingBanner(
                            onTap: () => _showDummyActionMessage('Pencarian Pintar AI'),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Peluang & Kolaborasi Terbaru',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              TextButton(
                                onPressed: _navigateToPeluangProyek,
                                child: Text(
                                  'Lihat Semua',
                                  style: TextStyle(color: pihakColor, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _isLoading
                              ? const SizedBox()
                              : _opportunities.isEmpty
                                  ? _buildEmptyOpportunity(isDark)
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: _opportunities.length,
                                      itemBuilder: (context, index) {
                                        final op = _opportunities[index];
                                        return FeatureCard(
                                          opportunity: op,
                                          accentColor: pihakColor,
                                          onTap: () => _openOpportunityDetail(op),
                                        );
                                      },
                                    ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Right Column (Quick Actions)
                    SizedBox(
                      width: 320,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tindakan Cepat',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.cardBg : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                              ),
                            ),
                            child: Column(
                              children: _currentRole == 'creator'
                                  ? [
                                      _buildSidebarQuickAction(
                                        label: 'Peluang Lokasi',
                                        icon: Icons.map_outlined,
                                        color: Colors.teal,
                                        onTap: _navigateToPeluangLokasi,
                                      ),
                                      _buildSidebarQuickAction(
                                        label: 'Cari Proyek',
                                        icon: Icons.search,
                                        color: pihakColor,
                                        onTap: _navigateToPeluangProyek,
                                      ),
                                      _buildSidebarQuickAction(
                                        label: 'Update Portofolio',
                                        icon: Icons.portrait,
                                        color: Colors.purple,
                                        onTap: () => _showDummyActionMessage('Update Portofolio'),
                                      ),
                                    ]
                                  : [
                                      _buildSidebarQuickAction(
                                        label: 'Peluang Lokasi',
                                        icon: Icons.map_outlined,
                                        color: Colors.teal,
                                        onTap: _navigateToPeluangLokasi,
                                      ),
                                      _buildSidebarQuickAction(
                                        label: 'Peluang Proyek',
                                        icon: Icons.work_outline,
                                        color: pihakColor,
                                        onTap: _navigateToPeluangProyek,
                                      ),
                                      _buildSidebarQuickAction(
                                        label: 'Cari Vendor',
                                        icon: Icons.people_alt_outlined,
                                        color: Colors.purple,
                                        onTap: () => _showDummyActionMessage('Cari Vendor'),
                                      ),
                                    ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 3. AI Banner
                    AiMatchingBanner(
                      onTap: () => _showDummyActionMessage('Pencarian Pintar AI'),
                    ),
                    const SizedBox(height: 24),

                    // 4. Quick Actions
                    // FIX: tiap QuickActionButton dibungkus Expanded via _buildMobileQuickActions
                    const Text(
                      'Tindakan Cepat',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildMobileQuickActions(
                      _currentRole == 'creator'
                          ? [
                              QuickActionButton(
                                label: 'Peluang Lokasi',
                                icon: Icons.map_outlined,
                                color: Colors.teal,
                                onTap: _navigateToPeluangLokasi,
                              ),
                              QuickActionButton(
                                label: 'Cari Proyek',
                                icon: Icons.search,
                                color: pihakColor,
                                onTap: _navigateToPeluangProyek,
                              ),
                              QuickActionButton(
                                label: 'Portofolio',
                                icon: Icons.portrait,
                                color: Colors.purple,
                                onTap: () => _showDummyActionMessage('Update Portofolio'),
                              ),
                            ]
                          : [
                              QuickActionButton(
                                label: 'Peluang Lokasi',
                                icon: Icons.map_outlined,
                                color: Colors.teal,
                                onTap: _navigateToPeluangLokasi,
                              ),
                              QuickActionButton(
                                label: 'Peluang Proyek',
                                icon: Icons.work_outline,
                                color: pihakColor,
                                onTap: _navigateToPeluangProyek,
                              ),
                              QuickActionButton(
                                label: 'Cari Vendor',
                                icon: Icons.people_alt_outlined,
                                color: Colors.purple,
                                onTap: () => _showDummyActionMessage('Cari Vendor'),
                              ),
                            ],
                    ),
                    const SizedBox(height: 28),

                    // 5. Recent Opportunities
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Peluang & Kolaborasi Terbaru',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showDummyActionMessage('Lihat Semua Peluang'),
                          child: Text(
                            'Lihat Semua',
                            style: TextStyle(color: pihakColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _isLoading
                        ? const SizedBox()
                        : _opportunities.isEmpty
                            ? _buildEmptyOpportunity(isDark)
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _opportunities.length,
                                itemBuilder: (context, index) {
                                  final op = _opportunities[index];
                                  return FeatureCard(
                                    opportunity: op,
                                    accentColor: pihakColor,
                                    onTap: () => _openOpportunityDetail(op),
                                  );
                                },
                              ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyOpportunity(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.work_off_outlined, color: Colors.grey, size: 40),
          SizedBox(height: 10),
          Text(
            'Belum ada peluang tersedia di kategori ini.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}