import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../app/subrole_theme_engine.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

import '../widgets/skeleton/skeleton_list.dart';

class UlasanReputasiScreen extends StatefulWidget {
  final UserModel? user;
  final ValueChanged<UserModel>? onUserUpdated;

  const UlasanReputasiScreen({super.key, this.user, this.onUserUpdated});

  @override
  State<UlasanReputasiScreen> createState() => _UlasanReputasiScreenState();
}

class _UlasanReputasiScreenState extends State<UlasanReputasiScreen> {
  bool _isLoading = false;
  String _selectedFilter = 'Semua';
  String _searchQuery = '';

  List<Map<String, dynamic>> _reviews = [];

  @override
  void initState() {
    super.initState();
    _fetchRealtimeReviews();
  }

  Future<void> _fetchRealtimeReviews() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get('/reviews');
      if (res['status'] == true && res['data'] != null) {
        final list = List<Map<String, dynamic>>.from(res['data']);
        if (mounted) {
          setState(() {
            _reviews = list;
          });
        }
      }
    } catch (_) {
      // Keep rich mock data if backend not active
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

    final filteredReviews = _reviews.where((r) {
      final rating = (r['rating'] as num).toDouble();
      if (_selectedFilter == '5★' && rating < 5.0) return false;
      if (_selectedFilter == '4★' && (rating < 4.0 || rating >= 5.0))
        return false;
      if (_selectedFilter == '3★' && (rating < 3.0 || rating >= 4.0))
        return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (r['name'] as String).toLowerCase();
        final project = (r['project'] as String).toLowerCase();
        final comment = (r['comment'] as String).toLowerCase();
        return name.contains(q) || project.contains(q) || comment.contains(q);
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: const Text(
          'Ulasan & Reputasi',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRealtimeReviews,
            tooltip: 'Perbarui Data Realtime',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchRealtimeReviews,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Summary Card ──
              _buildReputationBanner(accentColor, isDark),
              const SizedBox(height: 20),

              // ── Rating Breakdown Bars ──
              _buildRatingBreakdown(accentColor, isDark),
              const SizedBox(height: 20),

              // ── Search & Filter Row ──
              _buildFilterRow(accentColor, isDark),
              const SizedBox(height: 16),

              // ── Reviews List ──
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: SkeletonList(),
                )
              else if (filteredReviews.isEmpty)
                _buildEmptyState(isDark)
              else
                ...filteredReviews.map(
                  (r) => _buildReviewCard(r, accentColor, isDark),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReputationBanner(Color accentColor, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor,
            HSLColor.fromColor(accentColor).withLightness(0.25).toColor(),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('4.9', 'Rating Rata-rata', Icons.star_rounded),
          Container(width: 1, height: 45, color: Colors.white24),
          _buildStatItem(
            '${_reviews.length}',
            'Total Ulasan',
            Icons.rate_review_rounded,
          ),
          Container(width: 1, height: 45, color: Colors.white24),
          _buildStatItem('98%', 'Tepat Waktu', Icons.verified_outlined),
        ],
      ),
    );
  }

  Widget _buildStatItem(String val, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 6),
        Text(
          val,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildRatingBreakdown(Color accentColor, bool isDark) {
    final List<Map<String, dynamic>> breakdown = [];

    return Container(
      padding: const EdgeInsets.all(18),
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
            'Distribusian Penilaian',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...breakdown.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      b['star'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: b['pct'] as double,
                        minHeight: 8,
                        backgroundColor: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 24,
                    child: Text(
                      b['count'] as String,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.textMuted
                            : Colors.grey.shade600,
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

  Widget _buildFilterRow(Color accentColor, bool isDark) {
    final filters = ['Semua', '5★', '4★', '3★'];
    return Column(
      children: [
        TextField(
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: 'Cari ulasan atau proyek...',
            prefixIcon: const Icon(Icons.search, size: 20),
            filled: true,
            fillColor: isDark ? const Color(0xFF1A1830) : Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((f) {
              final isSel = _selectedFilter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f),
                  selected: isSel,
                  selectedColor: accentColor,
                  labelStyle: TextStyle(
                    color: isSel
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.grey.shade800),
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedFilter = f);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard(
    Map<String, dynamic> r,
    Color accentColor,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: accentColor.withValues(alpha: 0.12),
                child: Icon(Icons.person, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          r['name'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (r['verified'] == true) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.verified, size: 16, color: accentColor),
                        ],
                      ],
                    ),
                    Text(
                      '${r['role']} • ${r['project']}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.textMuted
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 14, color: Colors.amber.shade700),
                    const SizedBox(width: 4),
                    Text(
                      '${r['rating']}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            r['comment'] as String,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.grey.shade800,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                r['date'] as String,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.thumb_up_alt_outlined,
                    size: 14,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Membantu (${r['helpfulCount'] ?? 0})',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
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

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.rate_review_outlined,
            size: 48,
            color: isDark ? AppTheme.textMuted : Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'Tidak ada ulasan ditemukan',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
