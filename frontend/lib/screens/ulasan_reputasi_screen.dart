import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../app/subrole_theme_engine.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../widgets/skeleton/skeleton_list.dart';
import '../widgets/app_breadcrumbs.dart';
import 'main_navigation.dart';

class UlasanReputasiScreen extends StatefulWidget {
  final UserModel? user;
  final ValueChanged<UserModel>? onUserUpdated;

  const UlasanReputasiScreen({super.key, this.user, this.onUserUpdated});

  @override
  State<UlasanReputasiScreen> createState() => _UlasanReputasiScreenState();
}

class _UlasanReputasiScreenState extends State<UlasanReputasiScreen> {
  bool _isLoading = true;
  bool _isLoadingSummary = false;
  String _selectedFilter = 'Semua';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _reviews = [];
  Map<String, dynamic>? _dbStats;
  double _avgRating = 0.0;
  int _onTimePct = 0;
  Map<int, int> _distribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
  int _totalReviews = 0;

  @override
  void initState() {
    super.initState();
    _fetchRealtimeReviews();
    _fetchReviewSummary();
  }

  String? get _currentUserId {
    final u = widget.user;
    if (u == null) return null;
    return u.id;
  }

  Future<void> _fetchReviewSummary() async {
    final uid = _currentUserId;
    if (uid == null) return;
    setState(() => _isLoadingSummary = true);
    try {
      final res = await ApiService.get('creators/$uid/reviews/summary');
      if (res['status'] == true && res['data'] != null) {
        final d = Map<String, dynamic>.from(res['data']);
        final dist = d['distribution'];
        setState(() {
          _avgRating = (d['average_rating'] as num?)?.toDouble() ?? 0.0;
          _onTimePct = (d['on_time_percentage'] as num?)?.toInt() ?? 0;
          _totalReviews = (d['total_reviews'] as num?)?.toInt() ?? 0;
          if (dist is Map) {
            for (var i = 5; i >= 1; i--) {
              final v = dist['$i'] ?? dist[i];
              _distribution[i] = (v as num?)?.toInt() ?? 0;
            }
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingSummary = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchRealtimeReviews() async {
    final uid = _currentUserId;
    if (uid == null) return;
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get('creators/$uid/reviews');
      if (res['status'] == true && res['data'] != null) {
        final payload = Map<String, dynamic>.from(res['data']);
        final list = List<dynamic>.from(payload['items'] ?? []);
        if (mounted) {
          setState(() {
            _reviews = list.map((raw) {
              final item = Map<String, dynamic>.from(raw as Map);
              final reviewer = item['reviewer'] as Map<String, dynamic>?;
              final source = item['source'] as String?;
              final reviewerName = reviewer?['name']?.toString() ?? 'Pengguna Kreavana';
              final reviewerRole = reviewer?['sub_role']?.toString().replaceAll('_', ' ') ?? 'Kreator';
              return {
                'id': item['id'],
                'name': reviewerName,
                'role': reviewerRole,
                'company': reviewer?['company']?.toString() ?? 'Klien Kreavana',
                'project': source == 'opportunity' ? 'Kontrak Proyek' : 'Produk Marketplace',
                'rating': (item['rating'] as num?)?.toDouble() ?? 0.0,
                'comment': item['comment']?.toString() ?? '',
                'verified': source == 'opportunity' || (reviewer?['is_client_verified'] == true),
                'date': item['created_at']?.toString() ?? '',
                'is_on_time': item['is_on_time'],
                'helpfulCount': (item['helpful_count'] as num?)?.toInt() ?? 0,
                'isHelpful': false,
                'avatar_url': reviewer?['avatar_url']?.toString(),
              };
            }).toList();
            if (res['stats'] != null) {
              _dbStats = Map<String, dynamic>.from(res['stats']);
            }
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('Error fetching reviews: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleHelpful(int index) async {
    final item = _reviews[index];
    final isHelpful = (item['isHelpful'] as bool?) ?? false;
    final currentCount = (item['helpfulCount'] as int?) ?? 0;
    final reviewId = item['id'];

    setState(() {
      item['isHelpful'] = !isHelpful;
      item['helpfulCount'] =
          isHelpful ? (currentCount > 0 ? currentCount - 1 : 0) : currentCount + 1;
    });

    if (!isHelpful && reviewId != null) {
      try {
        await ApiService.post('reviews/$reviewId/helpful', {});
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final role = widget.user?.role ?? 'user';
    final subRole = widget.user?.subRole ?? 'general';
    final accentColor = SubRoleThemeEngine.getAccentColor(role, subRole);

    final filteredReviews = _reviews.where((r) {
      final rating = (r['rating'] as num?)?.toDouble() ?? 5.0;
      if (_selectedFilter == '5★' && rating < 4.9) return false;
      if (_selectedFilter == '4★' && (rating < 4.0 || rating >= 4.9)) {
        return false;
      }
      if (_selectedFilter == '3★' && (rating < 3.0 || rating >= 4.0)) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = ((r['name'] as String?) ?? '').toLowerCase();
        final project = ((r['project'] as String?) ?? '').toLowerCase();
        final comment = ((r['comment'] as String?) ?? '').toLowerCase();
        final company = ((r['company'] as String?) ?? '').toLowerCase();
        final category = ((r['category'] as String?) ?? '').toLowerCase();
        return name.contains(q) ||
            project.contains(q) ||
            comment.contains(q) ||
            company.contains(q) ||
            category.contains(q);
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
          'Ulasan & Reputasi',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchRealtimeReviews,
            tooltip: 'Perbarui Data Realtime',
          ),
          SizedBox(width: isDesktop ? 24 : 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchRealtimeReviews,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 32 : 18,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    label: 'Ulasan & Reputasi',
                    icon: Icons.star_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // ── 1. Hero Reputation Banner ──
              _buildReputationBanner(accentColor, isDark),
              const SizedBox(height: 18),

              // ── 2. Rating Breakdown Bars ──
              _buildRatingBreakdown(accentColor, isDark),
              const SizedBox(height: 22),

              // ── 3. Search & Filter Row ──
              _buildFilterRow(accentColor, isDark),
              const SizedBox(height: 18),

              // ── 4. Reviews List / Empty State ──
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: SkeletonList(),
                )
              else if (filteredReviews.isEmpty)
                _buildEmptyState(accentColor, isDark)
              else
                ...filteredReviews.asMap().entries.map(
                  (entry) => _buildReviewCard(
                    entry.value,
                    entry.key,
                    accentColor,
                    isDark,
                  ),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── Hero Reputation Banner ─────────────────────────────────────────────────
  Widget _buildReputationBanner(Color accentColor, bool isDark) {
    final total = _totalReviews > 0
        ? _totalReviews
        : (_dbStats?['total_reviews'] != null
            ? (_dbStats!['total_reviews'] as num).toInt()
            : _reviews.length);
    double avgRating = _avgRating > 0
        ? _avgRating
        : (_dbStats?['average_rating'] != null
            ? (_dbStats!['average_rating'] as num).toDouble()
            : 0.0);
    if (avgRating == 0.0 && _reviews.isNotEmpty) {
      final sum = _reviews.fold<double>(
        0.0,
        (prev, r) => prev + ((r['rating'] as num?)?.toDouble() ?? 0.0),
      );
      avgRating = sum / _reviews.length;
    }

    final onTimeStr = _onTimePct > 0
        ? '$_onTimePct%'
        : (total > 0
            ? (_dbStats?['on_time_rate'] != null ? '${_dbStats!['on_time_rate']}%' : '100%')
            : '0%');
    final satisfactionStr = total > 0
        ? (_dbStats?['satisfaction_rate'] != null ? '${_dbStats!['satisfaction_rate']}%' : '100%')
        : '0%';

    final isCreator = widget.user?.isCreator ?? false;
    final isVerified = isCreator
        ? (widget.user?.isCreatorVerified ?? false)
        : (widget.user?.isClientVerified ?? false);

    // Color and label according to Kreavana VerificationBadge rules:
    // Creator: Green (0xFF10B981) -> "Kreator Terverifikasi"
    // Client: Blue (0xFF2563EB) -> "Klien Terverifikasi"
    final badgeColor = isCreator ? const Color(0xFF10B981) : const Color(0xFF2563EB);
    final verifiedLabel = isCreator ? 'Kreator Terverifikasi' : 'Klien Terverifikasi';
    final unverifiedLabel = isCreator ? 'Kreator Belum Terverifikasi' : 'Klien Belum Terverifikasi';

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor,
            HSLColor.fromColor(accentColor).withLightness(0.25).toColor(),
            const Color(0xFF2D1457),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Row: Score + Badge
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Colors.amber, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      _isLoadingSummary
                          ? '—'
                          : (total > 0 ? avgRating.toStringAsFixed(1) : '0.0'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '/ 5.0',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (isVerified)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified_rounded, size: 16, color: badgeColor),
                      const SizedBox(width: 6),
                      Text(
                        verifiedLabel,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined,
                          size: 15, color: Colors.white70),
                      const SizedBox(width: 6),
                      Text(
                        unverifiedLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Divider Line
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.18),
          ),
          const SizedBox(height: 16),

          // Key Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('$total Ulasan', 'Diverifikasi',
                  Icons.rate_review_rounded),
              Container(
                  width: 1,
                  height: 35,
                  color: Colors.white.withValues(alpha: 0.2)),
              _buildStatItem(
                  onTimeStr, 'Tepat Waktu', Icons.alarm_on_rounded),
              Container(
                  width: 1,
                  height: 35,
                  color: Colors.white.withValues(alpha: 0.2)),
              _buildStatItem(satisfactionStr, 'Klien Puas', Icons.thumb_up_alt_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String val, String label, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 5),
            Text(
              val,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // ── Rating Breakdown Bars ──────────────────────────────────────────────────
  Widget _buildRatingBreakdown(Color accentColor, bool isDark) {
    final distTotal = _distribution.values.fold<int>(0, (s, v) => s + v);
    final total = distTotal > 0 ? distTotal : _reviews.length;
    final breakdownMap = _dbStats?['breakdown'] as Map<String, dynamic>?;

    final List<Map<String, dynamic>> breakdown = [5, 4, 3, 2, 1].map((star) {
      int count = 0;
      if (distTotal > 0 && (_distribution[star] ?? 0) > 0) {
        count = _distribution[star] ?? 0;
      } else if (breakdownMap != null && breakdownMap['$star'] != null) {
        count = (breakdownMap['$star'] as num).toInt();
      } else {
        count = _reviews.where((r) {
          final rtg = (r['rating'] as num?)?.toDouble() ?? 5.0;
          return rtg >= (star - 0.5) && rtg < (star + 0.5);
        }).length;
      }
      final pct = total > 0 ? (count / total) : 0.0;
      return {
        'star': '$star★',
        'pct': pct,
        'count': '$count',
      };
    }).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Distribusi Penilaian Klien',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
              ),
              Text(
                'Total $total Review',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...breakdown.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      b['star'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: (b['pct'] as num).toDouble(),
                        minHeight: 8,
                        backgroundColor: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          (b['star'] as String).contains('5')
                              ? Colors.amber.shade600
                              : accentColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 30,
                    child: Text(
                      b['count'] as String,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color:
                            isDark ? AppTheme.textMuted : Colors.grey.shade700,
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

  // ── Search & Filter Row ────────────────────────────────────────────────────
  Widget _buildFilterRow(Color accentColor, bool isDark) {
    final filters = [
      {'label': 'Semua', 'key': 'Semua'},
      {'label': '5★ Bintang', 'key': '5★'},
      {'label': '4★ Bintang', 'key': '4★'},
      {'label': '3★ Bintang', 'key': '3★'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: 'Cari ulasan klien, peran, atau nama proyek...',
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
            fillColor: isDark ? const Color(0xFF181528) : Colors.grey.shade100,
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((f) {
              final key = f['key'] as String;
              final label = f['label'] as String;
              final isSel = _selectedFilter == key;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(label),
                  selected: isSel,
                  selectedColor: accentColor,
                  backgroundColor:
                      isDark ? const Color(0xFF1E1A33) : Colors.grey.shade100,
                  side: BorderSide(
                    color: isSel
                        ? accentColor
                        : (isDark ? AppTheme.inputBorder : Colors.grey.shade300),
                  ),
                  labelStyle: TextStyle(
                    color: isSel
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.grey.shade800),
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedFilter = key);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Review Card ────────────────────────────────────────────────────────────
  Widget _buildReviewCard(
    Map<String, dynamic> r,
    int index,
    Color accentColor,
    bool isDark,
  ) {
    final rating = (r['rating'] as num?)?.toDouble() ?? 5.0;
    final isHelpful = (r['isHelpful'] as bool?) ?? false;
    final helpfulCount = (r['helpfulCount'] as int?) ?? 0;
    final colors = [
      Colors.teal,
      Colors.purple,
      Colors.indigo,
      Colors.amber.shade800,
      Colors.deepOrange,
      Colors.blueAccent,
    ];
    final avatarColor =
        (r['avatarColor'] as Color?) ?? colors[index % colors.length];
    final avatarIcon = (r['avatar'] as IconData?) ??
        (index % 2 == 0 ? Icons.person_rounded : Icons.person_outline_rounded);
    final avatarUrl = r['avatar_url'] as String?;

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
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Client Info Header
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: avatarColor.withValues(alpha: 0.15),
                backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? NetworkImage(ApiService.resolveAssetUrl(avatarUrl))
                    : null,
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? Icon(
                        avatarIcon,
                        color: avatarColor,
                        size: 22,
                      )
                    : null,
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
                            r['name'] as String? ?? 'Klien Terverifikasi',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (r['verified'] == true) ...[
                          const SizedBox(width: 5),
                          const Icon(Icons.verified_rounded,
                              size: 15, color: Colors.blue),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${r['role'] ?? 'Klien'} • ${r['company'] ?? 'Perusahaan'}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color:
                            isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Rating Pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded,
                        size: 16, color: Colors.amber.shade800),
                    const SizedBox(width: 4),
                    Text(
                      rating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Project & Category Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF181528)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.work_outline_rounded,
                    size: 13,
                    color:
                        isDark ? AppTheme.textMuted : Colors.grey.shade600),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${r['project']} (${r['category'] ?? 'Proyek'})',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Review Comment Text
          Text(
            r['comment'] as String? ?? '',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white.withValues(alpha: 0.88) : Colors.grey.shade800,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),

          // Footer: Date & Helpful Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 12,
                      color:
                          isDark ? AppTheme.textMuted : Colors.grey.shade500),
                  const SizedBox(width: 5),
                  Text(
                    r['date'] as String? ?? '2026',
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          isDark ? AppTheme.textMuted : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _toggleHelpful(index),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isHelpful
                        ? accentColor.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isHelpful
                          ? accentColor
                          : (isDark
                              ? AppTheme.inputBorder
                              : Colors.grey.shade300),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isHelpful
                            ? Icons.thumb_up_rounded
                            : Icons.thumb_up_alt_outlined,
                        size: 13,
                        color: isHelpful
                            ? accentColor
                            : (isDark
                                ? AppTheme.textMuted
                                : Colors.grey.shade600),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Membantu ($helpfulCount)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isHelpful ? FontWeight.bold : FontWeight.w500,
                          color: isHelpful
                              ? accentColor
                              : (isDark
                                  ? AppTheme.textMuted
                                  : Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Empty State ────────────────────────────────────────────────────────────
  Widget _buildEmptyState(Color accentColor, bool isDark) {
    final screenHeight = MediaQuery.of(context).size.height;
    final minEmptyHeight = (screenHeight - 320).clamp(320.0, 650.0);

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
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.rate_review_rounded,
                  size: 38,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Tidak Ada Ulasan Ditemukan',
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
                      ? 'Tidak ada ulasan yang sesuai dengan pencarian "$_searchQuery".'
                      : 'Belum ada ulasan untuk filter "$_selectedFilter". Coba pilih filter rating yang lain.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedFilter = 'Semua';
                  });
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset Pencarian'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
