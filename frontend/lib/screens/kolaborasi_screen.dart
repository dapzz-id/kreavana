import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../app/subrole_theme_engine.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/chat_service.dart';
import 'direct_message_screen.dart';
import '../widgets/skeleton/skeleton_list.dart';
import '../widgets/app_breadcrumbs.dart';
import 'main_navigation.dart';

class KolaborasiScreen extends StatefulWidget {
  final UserModel? user;
  final ValueChanged<UserModel>? onUserUpdated;

  const KolaborasiScreen({super.key, this.user, this.onUserUpdated});

  @override
  State<KolaborasiScreen> createState() => _KolaborasiScreenState();
}

class _KolaborasiScreenState extends State<KolaborasiScreen> {
  bool _isLoading = false;
  String _selectedStatus = 'Semua';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _collabs = [];

  @override
  void initState() {
    super.initState();
    _fetchRealtimeCollabs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchRealtimeCollabs() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get('collaborations');
      if (res['status'] == true && res['data'] != null) {
        final raw = res['data'];
        final List<dynamic> list = raw is List ? raw : (raw['data'] ?? []);
        final mapped = list.map((item) {
          final m = Map<String, dynamic>.from(item as Map);
          final rawAvatar = m['avatar'];
          IconData avatarIcon = Icons.people_outline_rounded;
          if (rawAvatar == 'videocam') {
            avatarIcon = Icons.videocam_rounded;
          } else if (rawAvatar == 'palette') {
            avatarIcon = Icons.palette_rounded;
          } else if (rawAvatar == 'camera') {
            avatarIcon = Icons.camera_alt_rounded;
          } else if (rawAvatar == 'music') {
            avatarIcon = Icons.music_note_rounded;
          } else if (rawAvatar == 'campaign') {
            avatarIcon = Icons.campaign_rounded;
          }

          final status = m['status']?.toString() ?? 'Aktif';
          Color statusColor = const Color(0xFF10B981);
          if (status == 'Menunggu') {
            statusColor = const Color(0xFFF59E0B);
          } else if (status == 'Selesai') {
            statusColor = const Color(0xFF6B7280);
          }

          return {
            'id': m['id']?.toString() ?? '',
            'user_id': m['user_id']?.toString() ?? '',
            'name': m['name']?.toString() ?? 'Kreator Kreavana',
            'email': m['email']?.toString() ?? '',
            'username': m['username']?.toString() ?? '',
            'role': m['role']?.toString() ?? 'Kreator',
            'avatar': avatarIcon,
            'avatar_url': (rawAvatar != null && rawAvatar.toString().startsWith('http')) ? rawAvatar.toString() : null,
            'project': m['project']?.toString() ?? '',
            'desc': m['desc']?.toString() ?? '',
            'neededRoles': (m['neededRoles'] as List?)?.map((e) => e.toString()).toList() ?? <String>[],
            'budget': m['budget']?.toString() ?? 'Sesuai Kesepakatan',
            'compensationType': m['compensationType']?.toString() ?? 'Escrow Kreavana',
            'status': status,
            'statusColor': statusColor,
            'membersCount': (m['membersCount'] as num?)?.toInt() ?? 1,
            'maxMembers': (m['maxMembers'] as num?)?.toInt() ?? 4,
            'date': m['date']?.toString() ?? '',
            'location': m['location']?.toString() ?? 'Indonesia',
            'tags': (m['tags'] as List?)?.map((e) => e.toString()).toList() ?? <String>['Kolaborasi'],
            'members': m['members'] ?? [],
          };
        }).toList();

        if (mounted) {
          setState(() {
            _collabs = mapped;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching collaborations: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final role = widget.user?.role ?? 'user';
    final subRole = widget.user?.subRole ?? 'general';
    final accentColor = SubRoleThemeEngine.getAccentColor(role, subRole);

    final filtered = _collabs.where((c) {
      final status = (c['status'] as String?) ?? 'Aktif';
      if (_selectedStatus != 'Semua' && status != _selectedStatus) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = ((c['name'] as String?) ?? '').toLowerCase();
        final proj = ((c['project'] as String?) ?? '').toLowerCase();
        final r = ((c['role'] as String?) ?? '').toLowerCase();
        final desc = ((c['desc'] as String?) ?? '').toLowerCase();
        final tags = (c['tags'] as List?)?.join(' ').toLowerCase() ?? '';
        return name.contains(q) ||
            proj.contains(q) ||
            r.contains(q) ||
            desc.contains(q) ||
            tags.contains(q);
      }
      return true;
    }).toList();

    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: Navigator.canPop(context),
        toolbarHeight: 80,
        titleSpacing: isDesktop ? 32 : 18,
        elevation: 0,
        title: const Text(
          'Kolaborasi',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchRealtimeCollabs,
            tooltip: 'Perbarui Data',
          ),
          SizedBox(width: isDesktop ? 24 : 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchRealtimeCollabs,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 18,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppBreadcrumbs(
                      items: [
                        BreadcrumbItem(
                          label: 'Beranda',
                          icon: Icons.home_rounded,
                          onTap: () {
                            if (widget.user != null) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MainNavigation(
                                    initialUser: widget.user!,
                                    initialIndex: 0,
                                  ),
                                ),
                                (r) => false,
                              );
                            }
                          },
                        ),
                        const BreadcrumbItem(
                          label: 'Kolaborasi',
                          icon: Icons.handshake_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
              // ── Search Bar ──
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Cari mitra, tim, atau proyek kolaborasi...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor:
                      isDark ? const Color(0xFF181528) : Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Filter Chips ──
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Semua', 'Aktif', 'Menunggu', 'Selesai'].map((st) {
                    final isSel = _selectedStatus == st;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(st),
                        selected: isSel,
                        selectedColor: accentColor,
                        backgroundColor: isDark
                            ? const Color(0xFF1E1A33)
                            : Colors.grey.shade100,
                        side: BorderSide(
                          color: isSel
                              ? accentColor
                              : (isDark
                                  ? AppTheme.inputBorder
                                  : Colors.grey.shade300),
                        ),
                        labelStyle: TextStyle(
                          color: isSel
                              ? Colors.white
                              : (isDark
                                  ? Colors.white70
                                  : Colors.grey.shade800),
                          fontWeight:
                              isSel ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _selectedStatus = st);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),

              // ── Main Content / Centered Empty State ──
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: SkeletonList(),
                )
              else if (filtered.isEmpty)
                _buildCenteredEmptyState(accentColor, isDark)
              else if (isDesktop)
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: filtered.map((c) {
                    final cardWidth = (MediaQuery.of(context).size.width > 1240
                            ? 1240
                            : MediaQuery.of(context).size.width) /
                        2 -
                        48;
                    return SizedBox(
                      width: cardWidth > 420 ? cardWidth : double.infinity,
                      child: _buildCollabCard(c, accentColor, isDark),
                    );
                  }).toList(),
                )
              else
                ...filtered.map(
                  (c) => _buildCollabCard(c, accentColor, isDark),
                ),
              const SizedBox(height: 70),
            ],
          ),
        ),
      ),
    ),
  ),
),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.width < 900 ? 76 : 0,
        ),
        child: FloatingActionButton.extended(
          heroTag: 'kolaborasi_fab',
          onPressed: () => _showNewCollabDialog(context, accentColor),
          backgroundColor: accentColor,
          elevation: 5,
          icon: const Icon(Icons.group_add_rounded, color: Colors.white),
          label: const Text(
            'Ajukan Kolaborasi',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }

  // ── Perfectly Centered Empty State ─────────────────────────────────────────
  Widget _buildCenteredEmptyState(Color accentColor, bool isDark) {
    // Dynamic height calculation so it centers vertically in available screen space
    final screenHeight = MediaQuery.of(context).size.height;
    final minEmptyHeight = (screenHeight - 270).clamp(320.0, 650.0);

    return SizedBox(
      height: minEmptyHeight,
      width: double.infinity,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.groups_rounded,
                  size: 42,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Belum ada data kolaborasi ditemukan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  _searchQuery.isNotEmpty
                      ? 'Tidak ada proyek yang sesuai dengan kata kunci "$_searchQuery". Coba kata kunci lain atau bersihkan filter.'
                      : 'Belum ada proyek kolaborasi pada kategori "$_selectedStatus". Mulai ajukan kolaborasi baru untuk mengajak kreator lain.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  if (_searchQuery.isNotEmpty || _selectedStatus != 'Semua')
                    OutlinedButton.icon(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _selectedStatus = 'Semua';
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Reset Filter'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: isDark
                              ? AppTheme.inputBorder
                              : Colors.grey.shade300,
                        ),
                      ),
                    ),
                  ElevatedButton.icon(
                    onPressed: () => _showNewCollabDialog(context, accentColor),
                    icon: const Icon(Icons.group_add_rounded,
                        size: 16, color: Colors.white),
                    label: const Text(
                      'Ajukan Kolaborasi Sekarang',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper Avatar Icon ─────────────────────────────────────────────────────
  IconData _resolveAvatarIcon(dynamic avatar) {
    if (avatar is IconData) return avatar;
    if (avatar is String) {
      switch (avatar.toLowerCase()) {
        case 'videocam':
          return Icons.videocam_rounded;
        case 'palette':
          return Icons.palette_rounded;
        case 'camera':
          return Icons.camera_alt_rounded;
        case 'music':
          return Icons.music_note_rounded;
        case 'campaign':
          return Icons.campaign_rounded;
        default:
          return Icons.person_rounded;
      }
    }
    return Icons.person_rounded;
  }

  // ── Open Team / Lead Creator Chat ──────────────────────────────────────────
  Future<void> _openTeamChat(BuildContext context, Map<String, dynamic> c) async {
    final userId = (c['user_id'] ?? c['userId'])?.toString();
    final creatorName = c['name']?.toString() ?? 'Kreator Partner';

    if (userId == null || userId.isEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const DirectMessageScreen(),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 16),
              Text(
                'Menghubungkan ke $creatorName...',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final res = await ChatService.startPersonalChat(userId);
      if (!context.mounted) return;
      Navigator.pop(context); // Tutup dialog loading

      if (res['status'] == true && res['data'] != null) {
        final chatData = Map<String, dynamic>.from(res['data']);
        final isDesktop = MediaQuery.of(context).size.width > 800;

        if (isDesktop) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DirectMessageScreen(
                initialChat: chatData,
                chatId: chatData['id'],
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Scaffold(
                body: ChatDetailSection(
                  chat: chatData,
                  isMobile: true,
                ),
              ),
            ),
          );
        }
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DirectMessageScreen(targetUserId: userId),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        Navigator.pop(context); // Tutup dialog jika error
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DirectMessageScreen(targetUserId: userId),
          ),
        );
      }
    }
  }

  // ── Collaboration Card ─────────────────────────────────────────────────────
  Widget _buildCollabCard(
    Map<String, dynamic> c,
    Color accentColor,
    bool isDark,
  ) {
    final status = (c['status'] as String?) ?? 'Aktif';
    final isFinished = status == 'Selesai';
    final statusColor = (c['statusColor'] as Color?) ??
        (status == 'Aktif'
            ? const Color(0xFF10B981)
            : (status == 'Menunggu'
                ? const Color(0xFFF59E0B)
                : const Color(0xFF6B7280)));

    final membersCount = (c['membersCount'] as int?) ?? 1;
    final maxMembers = (c['maxMembers'] as int?) ?? 4;
    final progress = (membersCount / maxMembers).clamp(0.0, 1.0);
    final neededRoles = (c['neededRoles'] as List?)?.cast<String>() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Avatar, Lead, Status Pill
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: accentColor.withValues(alpha: 0.15),
                child: Icon(
                  _resolveAvatarIcon(c['avatar']),
                  color: accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            c['name'] as String? ?? 'Kreator Partner',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.verified_rounded,
                            size: 15, color: accentColor),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${c['role'] ?? 'Kreator'} • ${c['location'] ?? 'Indonesia'}',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Project Title
          Text(
            c['project'] as String? ?? 'Proyek Kolaborasi',
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          if (c['desc'] != null) ...[
            const SizedBox(height: 6),
            Text(
              c['desc'] as String,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),

          // Needed Roles Badges
          if (neededRoles.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: neededRoles.map((r) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isFinished
                        ? (isDark ? Colors.grey.shade800 : Colors.grey.shade200)
                        : accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isFinished
                          ? Colors.grey.shade400.withValues(alpha: 0.3)
                          : accentColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isFinished
                            ? Icons.check_circle_rounded
                            : Icons.person_add_alt_1_rounded,
                        size: 12,
                        color: isFinished ? Colors.grey.shade500 : accentColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        r,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isFinished
                              ? (isDark ? Colors.white60 : Colors.grey.shade700)
                              : accentColor,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Team Member Progress Bar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isFinished
                              ? 'Status Tim: Selesai Dilaksanakan'
                              : 'Kebutuhan Tim: $membersCount / $maxMembers Talenta',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppTheme.textMuted
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          isFinished ? '100%' : '${(progress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isFinished ? statusColor : accentColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: isFinished ? 1.0 : progress,
                        minHeight: 6,
                        backgroundColor: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isFinished ? statusColor : accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Info Row: Budget & Timeline
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF181528)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    size: 15,
                    color: isFinished ? Colors.grey.shade500 : Colors.green.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${c['budget'] ?? 'TBA'} • ${c['compensationType'] ?? 'Kesepakatan'}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.calendar_today_rounded,
                    size: 13,
                    color:
                        isDark ? AppTheme.textMuted : Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  c['date'] as String? ?? '2026',
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        isDark ? AppTheme.textMuted : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Bottom Actions Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (isFinished)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.grey.shade800 : Colors.grey.shade200)
                        .withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          size: 14,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      const SizedBox(width: 5),
                      Text(
                        'Perekrutan Ditutup',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox.shrink(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showCollabDetailModal(context, c, accentColor),
                    icon: const Icon(Icons.info_outline_rounded, size: 15),
                    label: const Text('Detail Tim',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: BorderSide(
                        color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                      ),
                    ),
                  ),
                  if (!isFinished) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _openTeamChat(context, c),
                      icon: const Icon(Icons.chat_bubble_outline_rounded,
                          size: 15, color: Colors.white),
                      label: const Text('Chat Tim',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        elevation: 0,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Detail Project Modal ───────────────────────────────────────────────────
  void _showCollabDetailModal(
    BuildContext context,
    Map<String, dynamic> c,
    Color accentColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 600;
    final neededRoles = (c['neededRoles'] as List?)?.cast<String>() ?? [];
    final status = (c['status'] as String?) ?? 'Aktif';
    final isFinished = status == 'Selesai';
    final membersCount = (c['membersCount'] as int?) ?? 1;
    final maxMembers = (c['maxMembers'] as int?) ?? 4;
    final isFull = membersCount >= maxMembers;

    Widget buildModalContent(BuildContext ctx, {bool inDialog = false}) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!inDialog) ...[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
          if (inDialog)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Detail Proyek Kolaborasi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                  tooltip: 'Tutup',
                ),
              ],
            ),
              const SizedBox(height: 18),
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: accentColor.withValues(alpha: 0.15),
                    child: Icon(
                      _resolveAvatarIcon(c['avatar']),
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c['name'] as String? ?? 'Kreator Partner',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${c['role']} • ${c['location']}',
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppTheme.textMuted
                                  : Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (isFinished
                              ? Colors.grey.shade600
                              : (status == 'Aktif'
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF59E0B)))
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (isFinished
                                ? Colors.grey.shade600
                                : (status == 'Aktif'
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFF59E0B)))
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isFinished
                            ? Colors.grey.shade600
                            : (status == 'Aktif'
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                c['project'] as String? ?? '',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                c['desc'] as String? ?? '',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.grey.shade800,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),

              if (isFinished) ...[
                const Text(
                  'Status Perekrutan Tim:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.grey.shade800 : Colors.grey.shade200)
                        .withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 16, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        'Proyek Telah Selesai • Seluruh Kuota Tim Terpenuhi',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.grey.shade800 : Colors.grey.shade100)
                        .withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_clock_rounded,
                          size: 20,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Proyek kolaborasi ini telah rampung. Perekrutan talenta baru dan permohonan bergabung sudah tidak menerima pengajuan.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: isDark
                                ? Colors.grey.shade300
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: null, // Disabled!
                    icon: const Icon(Icons.lock_rounded, size: 16),
                    label: const Text(
                      'Proyek Telah Selesai (Perekrutan Ditutup)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      disabledBackgroundColor: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                      disabledForegroundColor:
                          isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                  ),
                ),
              ] else if (isFull) ...[
                const Text(
                  'Status Kuota Tim:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.grey.shade800 : Colors.grey.shade200)
                        .withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.group_rounded, size: 16, color: accentColor),
                      const SizedBox(width: 6),
                      Text(
                        'Kuota Tim Penuh ($membersCount / $maxMembers Talenta)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: null, // Disabled!
                    icon: const Icon(Icons.people_outline_rounded, size: 16),
                    label: const Text(
                      'Kuota Tim Sudah Penuh',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      disabledBackgroundColor: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                      disabledForegroundColor:
                          isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                  ),
                ),
              ] else ...[
                const Text(
                  'Peran yang Masih Dibutuhkan:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: neededRoles.map((r) {
                    return Chip(
                      label: Text(r),
                      backgroundColor: accentColor.withValues(alpha: 0.1),
                      labelStyle: TextStyle(
                        color: accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Pengajuan bergabung ke "${c['project']}" berhasil dikirim ke ${c['name']}!',
                          ),
                          backgroundColor: Colors.green.shade700,
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded,
                        color: Colors.white),
                    label: const Text(
                      'Ajukan Diri untuk Bergabung',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
    }

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF181528) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: buildModalContent(ctx, inDialog: true),
              ),
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF181528) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: buildModalContent(ctx, inDialog: false),
          );
        },
      );
    }
  }

  // ── New Collaboration Dialog ───────────────────────────────────────────────
  void _showNewCollabDialog(BuildContext context, Color accentColor) {
    final titleCtrl = TextEditingController();
    final roleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final budgetCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final isDesktop = MediaQuery.of(context).size.width >= 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool submitting = false;

    Widget buildFormContent(BuildContext ctx, {bool inDialog = false}) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!inDialog) ...[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ajukan Kolaborasi Baru',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (inDialog)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                    tooltip: 'Tutup',
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Publikasikan proyek tim Anda agar kreator lain dapat mengajukan diri.',
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Proyek / Campaign *',
                hintText: 'Contoh: Shooting Video Klip Musik Indie',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: roleCtrl,
              decoration: const InputDecoration(
                labelText: 'Peran yang Dibutuhkan (Pisahkan koma) *',
                hintText: 'Contoh: Videografer, MUA, Sound Engineer',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: budgetCtrl,
              decoration: const InputDecoration(
                labelText: 'Estimasi Budget / Pembagian Fee',
                hintText: 'Contoh: Rp 10.000.000 (Bagi Hasil)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: locCtrl,
              decoration: const InputDecoration(
                labelText: 'Lokasi Eksekusi',
                hintText: 'Contoh: Jakarta / Remote',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Deskripsi & Tujuan Proyek',
                hintText: 'Ceritakan detail proyek dan kualifikasi yang dicari...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: submitting
                    ? null
                    : () async {
                        if (titleCtrl.text.trim().isEmpty) return;
                        setSheetState(() => submitting = true);
                        try {
                          final now = DateTime.now();
                          final monthNames = [
                            'Januari', 'Februari', 'Maret', 'April',
                            'Mei', 'Juni', 'Juli', 'Agustus',
                            'September', 'Oktober', 'November', 'Desember'
                          ];
                          final dateLabel =
                              '${monthNames[now.month - 1]} ${now.year}';
                          final roles = roleCtrl.text.isNotEmpty
                              ? roleCtrl.text
                                  .split(',')
                                  .map((e) => e.trim())
                                  .where((e) => e.isNotEmpty)
                                  .toList()
                              : ['Partner Kreatif'];

                          final res = await ApiService.post(
                            'collaborations',
                            {
                              'project_title': titleCtrl.text.trim(),
                              'description': descCtrl.text.trim().isNotEmpty
                                  ? descCtrl.text.trim()
                                  : 'Peran yang dibutuhkan: ${roles.join(', ')}',
                              'budget': budgetCtrl.text.trim(),
                              'location': locCtrl.text.trim(),
                              'invitees': widget.user != null
                                  ? [
                                      {
                                        'user_id': widget.user!.id,
                                        'role': roles.first,
                                      }
                                    ]
                                  : [],
                            },
                          );
                          final created = res['data'];
                          if (mounted) {
                            setState(() {
                              _collabs.insert(0, {
                                'id': created?['id'] ??
                                    'collab-${now.millisecondsSinceEpoch}',
                                'name': widget.user?.name ?? 'Kreator Mandiri',
                                'role': widget.user?.subRole != null
                                    ? widget.user!.subRole!.toUpperCase()
                                    : (roles.isNotEmpty ? roles.first : 'Kreator'),
                                'project': titleCtrl.text.trim(),
                                'desc': descCtrl.text.trim().isNotEmpty
                                    ? descCtrl.text.trim()
                                    : 'Proyek kolaborasi baru yang siap dieksekusi bersama tim terpercaya.',
                                'neededRoles': roles,
                                'budget': budgetCtrl.text.trim().isNotEmpty
                                    ? budgetCtrl.text.trim()
                                    : 'Sesuai Kesepakatan',
                                'compensationType': 'Escrow Aman',
                                'status': 'Menunggu',
                                'statusColor': const Color(0xFFF59E0B),
                                'avatar': Icons.person_pin_rounded,
                                'membersCount':
                                    (created?['members'] as List?)?.length ?? 1,
                                'maxMembers': roles.length + 1,
                                'date': dateLabel,
                                'location': locCtrl.text.trim().isNotEmpty
                                    ? locCtrl.text.trim()
                                    : 'Indonesia',
                                'tags': ['New', 'Collaboration'],
                              });
                            });
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Proyek kolaborasi berhasil diajukan dan dipublikasikan!',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text('Gagal mengirim pengajuan: $e'),
                              ),
                            );
                          }
                        } finally {
                          if (ctx.mounted) {
                            setSheetState(() => submitting = false);
                          }
                        }
                      },
                child: submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Publikasikan Kolaborasi',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
          ],
        ),
      );
    }

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF181528) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: buildFormContent(ctx, inDialog: true),
              ),
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return Container(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF181528) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: buildFormContent(ctx, inDialog: false),
            ),
          );
        },
      );
    }
  }
}
