import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../models/opportunity_model.dart';
import '../services/dashboard_service.dart';
import '../services/profile_service.dart';
import '../widgets/role_toggle.dart';
import '../widgets/stat_card.dart';
import '../widgets/quick_action_button.dart';
import '../widgets/feature_card.dart';
import '../widgets/ai_matching_banner.dart';
import '../main.dart';

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
  List<OpportunityModel> _opportunities = [];

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
    // If user model was updated in parent (e.g. role changed or approval status changed), update local state
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
      final statsData = await DashboardService.getStats(
        pihak: _selectedPihak,
        roleType: _currentRole,
      );

      final opportunitiesData = await DashboardService.getOpportunities(
        pihak: _selectedPihak,
        limit: 5,
      );

      if (mounted) {
        setState(() {
          _stats = statsData;
          _opportunities = opportunitiesData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onPihakSelected(String pihakSlug) async {
    setState(() {
      _selectedPihak = pihakSlug;
    });

    // Update selected_pihak on server
    await ProfileService.updateProfile(
      userId: widget.user.id,
      selectedPihak: pihakSlug,
    );

    // Refresh user model in parent
    final updatedUser = widget.user.copyWith(selectedPihak: pihakSlug);
    widget.onUserUpdated(updatedUser);

    _loadDashboardData();
  }

  void _onRoleChanged(String role) async {
    setState(() {
      _currentRole = role;
    });

    // Update role locally and refresh stats
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
        content: Text('Fitur "$action" berhasil dipicu! (Demo)'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: color,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, color: color, size: 16),
            ],
          ),
        ),
      ),
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
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
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            onPressed: () {
              themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
            },
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
                              : (isDark
                                    ? AppTheme.cardBg
                                    : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? itemColor
                                : (isDark
                                      ? AppTheme.inputBorder
                                      : Colors.transparent),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              item['icon'] as IconData,
                              color: isSelected
                                  ? itemColor
                                  : Colors.grey.shade600,
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
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? (isDark ? Colors.white : itemColor)
                                    : (isDark
                                          ? AppTheme.textMuted
                                          : Colors.grey.shade700),
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
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
              const SizedBox(height: 24),

              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column (Opportunities & AI Banner)
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AiMatchingBanner(
                            onTap: () =>
                                _showDummyActionMessage('Pencarian Pintar AI'),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Peluang & Kolaborasi Terbaru',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  _showDummyActionMessage(
                                    'Lihat Semua Peluang',
                                  );
                                },
                                child: Text(
                                  'Lihat Semua',
                                  style: TextStyle(
                                    color: pihakColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _isLoading
                              ? const SizedBox()
                              : _opportunities.isEmpty
                              ? Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppTheme.cardBg
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Column(
                                    children: [
                                      Icon(
                                        Icons.work_off_outlined,
                                        color: Colors.grey,
                                        size: 40,
                                      ),
                                      SizedBox(height: 10),
                                      Text(
                                        'Belum ada peluang tersedia di kategori ini.',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _opportunities.length,
                                  itemBuilder: (context, index) {
                                    final op = _opportunities[index];
                                    return FeatureCard(
                                      opportunity: op,
                                      accentColor: pihakColor,
                                      onTap: () =>
                                          _showDummyActionMessage(op.title),
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
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.cardBg : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? AppTheme.inputBorder
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Column(
                              children: _currentRole == 'creator'
                                  ? [
                                      _buildSidebarQuickAction(
                                        label: 'Update Portofolio',
                                        icon: Icons.portrait,
                                        color: pihakColor,
                                        onTap: () => _showDummyActionMessage(
                                          'Update Portofolio',
                                        ),
                                      ),
                                      _buildSidebarQuickAction(
                                        label: 'Cari Proyek',
                                        icon: Icons.search,
                                        color: Colors.teal,
                                        onTap: () => _showDummyActionMessage(
                                          'Cari Proyek',
                                        ),
                                      ),
                                      _buildSidebarQuickAction(
                                        label: 'Kirim Proposal',
                                        icon: Icons.send,
                                        color: Colors.amber.shade700,
                                        onTap: () => _showDummyActionMessage(
                                          'Kirim Proposal',
                                        ),
                                      ),
                                    ]
                                  : [
                                      _buildSidebarQuickAction(
                                        label: 'Buat Peluang',
                                        icon: Icons.add_circle_outline,
                                        color: pihakColor,
                                        onTap: () => _showDummyActionMessage(
                                          'Buat Peluang',
                                        ),
                                      ),
                                      _buildSidebarQuickAction(
                                        label: 'Cari Vendor',
                                        icon: Icons.people_alt_outlined,
                                        color: Colors.purple,
                                        onTap: () => _showDummyActionMessage(
                                          'Cari Vendor',
                                        ),
                                      ),
                                      _buildSidebarQuickAction(
                                        label: 'Undang Kolaborasi',
                                        icon: Icons.handshake_outlined,
                                        color: Colors.teal,
                                        onTap: () => _showDummyActionMessage(
                                          'Undang Kolaborasi',
                                        ),
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
                      onTap: () =>
                          _showDummyActionMessage('Pencarian Pintar AI'),
                    ),
                    const SizedBox(height: 24),

                    // 4. Quick Actions
                    const Text(
                      'Tindakan Cepat',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: _currentRole == 'creator'
                          ? [
                              QuickActionButton(
                                label: 'Update Portofolio',
                                icon: Icons.portrait,
                                color: pihakColor,
                                onTap: () => _showDummyActionMessage(
                                  'Update Portofolio',
                                ),
                              ),
                              QuickActionButton(
                                label: 'Cari Proyek',
                                icon: Icons.search,
                                color: Colors.teal,
                                onTap: () =>
                                    _showDummyActionMessage('Cari Proyek'),
                              ),
                              QuickActionButton(
                                label: 'Kirim Proposal',
                                icon: Icons.send,
                                color: Colors.amber.shade700,
                                onTap: () =>
                                    _showDummyActionMessage('Kirim Proposal'),
                              ),
                            ]
                          : [
                              QuickActionButton(
                                label: 'Buat Peluang',
                                icon: Icons.add_circle_outline,
                                color: pihakColor,
                                onTap: () =>
                                    _showDummyActionMessage('Buat Peluang'),
                              ),
                              QuickActionButton(
                                label: 'Cari Vendor',
                                icon: Icons.people_alt_outlined,
                                color: Colors.purple,
                                onTap: () =>
                                    _showDummyActionMessage('Cari Vendor'),
                              ),
                              QuickActionButton(
                                label: 'Undang Kolaborasi',
                                icon: Icons.handshake_outlined,
                                color: Colors.teal,
                                onTap: () => _showDummyActionMessage(
                                  'Undang Kolaborasi',
                                ),
                              ),
                            ],
                    ),
                    const SizedBox(height: 28),

                    // 5. Recent Opportunities
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Peluang & Kolaborasi Terbaru',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            _showDummyActionMessage('Lihat Semua Peluang');
                          },
                          child: Text(
                            'Lihat Semua',
                            style: TextStyle(
                              color: pihakColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _isLoading
                        ? const SizedBox()
                        : _opportunities.isEmpty
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.cardBg
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Column(
                              children: [
                                Icon(
                                  Icons.work_off_outlined,
                                  color: Colors.grey,
                                  size: 40,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'Belum ada peluang tersedia di kategori ini.',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _opportunities.length,
                            itemBuilder: (context, index) {
                              final op = _opportunities[index];
                              return FeatureCard(
                                opportunity: op,
                                accentColor: pihakColor,
                                onTap: () => _showDummyActionMessage(op.title),
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
}
