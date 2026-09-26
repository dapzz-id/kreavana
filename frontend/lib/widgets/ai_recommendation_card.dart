import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../models/opportunity_model.dart';
import '../services/ai_service.dart';
import '../widgets/auth_guard_dialog.dart';
import '../widgets/upgrade_plan_modal.dart';
import '../widgets/opportunity_detail_sheet.dart';
import '../screens/explore_screen.dart';

/// Monochromatic Violet AI Recommendation Card Widget.
/// Allows Plus, Pro, and Super subscribers to get tailored AI recommendations
/// filtered by current location / custom city and target sub_role.
class AiRecommendationCard extends StatefulWidget {
  final UserModel? user;
  final String role;
  final String niche;

  const AiRecommendationCard({
    super.key,
    this.user,
    this.role = 'creator',
    this.niche = 'Kreatif',
  });

  @override
  State<AiRecommendationCard> createState() => _AiRecommendationCardState();
}

class _AiRecommendationCardState extends State<AiRecommendationCard> {
  bool _isLoading = false;
  List<dynamic>? _recommendations;
  List<dynamic>? _matchedItems;

  // Active filters
  String _selectedSubRole = 'all';
  String _locationMode = 'current'; // 'current' or 'custom'
  String _customCity = 'Jakarta';

  final List<Map<String, dynamic>> _subRoleOptions = [
    {'id': 'all', 'label': 'Semua', 'icon': Icons.tune_rounded},
    {'id': 'photographer', 'label': 'Photographer', 'icon': Icons.camera_alt_outlined},
    {'id': 'event_organizer', 'label': 'Event Organizer', 'icon': Icons.festival_outlined},
    {'id': 'school', 'label': 'School / Institusi', 'icon': Icons.school_outlined},
    {'id': 'videographer', 'label': 'Videographer', 'icon': Icons.videocam_outlined},
    {'id': 'wedding_organizer', 'label': 'Wedding Organizer', 'icon': Icons.celebration_outlined},
    {'id': 'editor', 'label': 'Editor', 'icon': Icons.movie_edit},
    {'id': 'mc', 'label': 'MC', 'icon': Icons.mic_external_on_outlined},
    {'id': 'makeup_artist', 'label': 'Makeup Artist', 'icon': Icons.brush_outlined},
    {'id': 'singer', 'label': 'Singer / Musisi', 'icon': Icons.music_note_outlined},
    {'id': 'community', 'label': 'Komunitas', 'icon': Icons.groups_outlined},
  ];

  final List<String> _popularCities = [
    'Jakarta',
    'Bandung',
    'Surabaya',
    'Bekasi',
    'Bali',
    'Medan',
    'Yogyakarta',
    'Semarang',
    'Malang',
    'Makassar',
    'Tangerang',
  ];

  String get _activeLocationLabel {
    if (_locationMode == 'current') {
      return 'Lokasi Sekarang (GPS)';
    }
    return _customCity;
  }

  String get _selectedSubRoleLabel {
    final opt = _subRoleOptions.firstWhere(
      (o) => o['id'] == _selectedSubRole,
      orElse: () => {'label': 'Semua'},
    );
    return opt['label'] as String;
  }

  Future<void> _fetchRecommendations() async {
    // 1. Intercept Guest user
    if (widget.user?.isGuest == true) {
      AuthGuardDialog.show(context, actionName: 'mengakses Rekomendasi AI Pintar');
      return;
    }

    setState(() => _isLoading = true);

    final locationParam = _locationMode == 'current' ? 'Lokasi Sekarang' : _customCity;

    final res = await AiService.getRecommendations(
      role: widget.role,
      niche: widget.niche,
      subRole: _selectedSubRole,
      location: locationParam,
    );

    if (!mounted) return;

    if (res != null && AiService.isProSubscriptionRequiredError(res)) {
      setState(() => _isLoading = false);
      UpgradePlanModal.show(context, user: widget.user);
      return;
    }

    if (res != null && res['status'] == true && res['data'] != null) {
      final recs = res['data']['recommendations'] as List?;
      final matched = res['data']['matched_items'] as List?;
      setState(() {
        _isLoading = false;
        _recommendations = recs;
        _matchedItems = matched;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _showLocationPickerModal(bool isDark) {
    final textController = TextEditingController(
      text: _locationMode == 'custom' ? _customCity : '',
    );
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    Widget buildPickerContent(BuildContext ctx, {bool inDialog = false}) {
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
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: AppTheme.primaryPurple, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Pilih Filter Lokasi AI',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              if (inDialog)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.pop(ctx),
                  tooltip: 'Tutup',
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Option 1: Lokasi Sekarang / GPS
          InkWell(
            onTap: () {
              setState(() {
                _locationMode = 'current';
              });
              Navigator.pop(ctx);
              _fetchRecommendations();
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _locationMode == 'current'
                    ? AppTheme.primaryPurple.withValues(alpha: 0.12)
                    : (isDark ? const Color(0xFF1E1A30) : const Color(0xFFF7F5FC)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _locationMode == 'current'
                      ? AppTheme.primaryPurple
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.my_location_rounded,
                    color: _locationMode == 'current' ? AppTheme.primaryPurple : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lokasi Sekarang (GPS)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Cari kreator & proyek terdekat dari posisimu',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  if (_locationMode == 'current')
                    const Icon(Icons.check_circle_rounded, color: AppTheme.primaryPurple, size: 18),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Option 2: Seluruh Indonesia
          InkWell(
            onTap: () {
              setState(() {
                _locationMode = 'all';
              });
              Navigator.pop(ctx);
              _fetchRecommendations();
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _locationMode == 'all'
                    ? AppTheme.primaryPurple.withValues(alpha: 0.12)
                    : (isDark ? const Color(0xFF1E1A30) : const Color(0xFFF7F5FC)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _locationMode == 'all'
                      ? AppTheme.primaryPurple
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.public_rounded,
                    color: _locationMode == 'all' ? AppTheme.primaryPurple : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Seluruh Indonesia',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Tampilkan rekomendasi dari semua kota',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  if (_locationMode == 'all')
                    const Icon(Icons.check_circle_rounded, color: AppTheme.primaryPurple, size: 18),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),
          const Text(
            'Atau pilih kota populer:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _popularCities.map((city) {
              final isSel = _locationMode == 'custom' && _customCity.toLowerCase() == city.toLowerCase();
              return ChoiceChip(
                label: Text(city),
                selected: isSel,
                selectedColor: AppTheme.primaryPurple.withValues(alpha: 0.18),
                backgroundColor: isDark ? const Color(0xFF1E1A30) : const Color(0xFFF2EFFB),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  color: isSel ? AppTheme.primaryPurple : (isDark ? Colors.white70 : Colors.black87),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSel ? AppTheme.primaryPurple : Colors.transparent,
                  ),
                ),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _locationMode = 'custom';
                      _customCity = city;
                    });
                    Navigator.pop(ctx);
                    _fetchRecommendations();
                  }
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 14),
          // Custom text input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: textController,
                  decoration: InputDecoration(
                    hintText: 'Ketik kota lainnya (misal: Bogor, Solo)',
                    hintStyle: const TextStyle(fontSize: 12),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E1A30) : const Color(0xFFF7F5FC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppTheme.primaryPurple.withValues(alpha: 0.3)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final text = textController.text.trim();
                  if (text.isNotEmpty) {
                    setState(() {
                      _locationMode = 'custom';
                      _customCity = text;
                    });
                    Navigator.pop(ctx);
                    _fetchRecommendations();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                child: const Text('Pilih', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      );
    }

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161426) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: buildPickerContent(ctx, inDialog: true),
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
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161426) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: buildPickerContent(ctx, inDialog: false),
          );
        },
      );
    }
  }

    @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = AppTheme.primaryPurple;
    final cardBg = isDark ? const Color(0xFF13111F) : const Color(0xFFFAF9FE);
    final borderColor = isDark ? const Color(0xFF2D264A) : const Color(0xFFE4DEF6);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.12 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Bar ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryPurple, AppTheme.deepPurple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rekomendasi AI Beranda',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Pencarian cerdas berbasis Lokasi & Sub-Role (${widget.niche})',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, color: Colors.amber, size: 12),
                      SizedBox(width: 3),
                      Text(
                        'PLUS • PRO • SUPER',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Interactive Filter Toolbar ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: isDark ? const Color(0xFF181528) : const Color(0xFFF6F3FC),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filter Row: Location Indicator & Action
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, size: 14, color: AppTheme.primaryPurple),
                    const SizedBox(width: 6),
                    const Text(
                      'Filter AI:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 10),
                    // Location Pill Button
                    InkWell(
                      onTap: () => _showLocationPickerModal(isDark),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF25203A) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _locationMode == 'current'
                                  ? Icons.my_location_rounded
                                  : Icons.location_on_rounded,
                              size: 13,
                              color: AppTheme.primaryPurple,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _activeLocationLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryPurple,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down_rounded, size: 16, color: AppTheme.primaryPurple),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_recommendations != null)
                      TextButton.icon(
                        onPressed: _isLoading ? null : _fetchRecommendations,
                        icon: const Icon(Icons.refresh_rounded, size: 14, color: AppTheme.primaryPurple),
                        label: const Text('Refresh', style: TextStyle(fontSize: 11, color: AppTheme.primaryPurple)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                // Sub-Role Chips (Horizontal Scrollable)
                SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _subRoleOptions.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 6),
                    itemBuilder: (ctx, idx) {
                      final item = _subRoleOptions[idx];
                      final isSelected = _selectedSubRole == item['id'];
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedSubRole = item['id'];
                          });
                          if (_recommendations != null) {
                            _fetchRecommendations();
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? accent
                                : (isDark ? const Color(0xFF221E38) : Colors.white),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? accent : borderColor,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item['icon'] as IconData,
                                size: 13,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? Colors.white70 : Colors.black87),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                item['label'] as String,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Main Content Area ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: _recommendations == null
                ? SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _fetchRecommendations,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.auto_awesome_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                      label: Text(
                        _isLoading
                            ? 'Menganalisis $_selectedSubRoleLabel di $_activeLocationLabel...'
                            : 'Dapatkan Rekomendasi AI ($_selectedSubRoleLabel • $_activeLocationLabel)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 2,
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // AI Insights Highlights
                      ..._recommendations!.map((rec) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1B182B) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.stars_rounded,
                                    color: accent,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      rec['title'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                rec['reason'] ?? '',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Dampak: ${rec['impact'] ?? ''}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      // Matched Items Carousel / List (Creators or Opportunities)
                      if (_matchedItems != null && _matchedItems!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.verified_user_rounded, size: 15, color: accent),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Kreator & Peluang Rekomendasi AI ($_activeLocationLabel):',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 140,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _matchedItems!.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 10),
                            itemBuilder: (ctx, i) {
                              final item = _matchedItems![i];
                              final isOpp = item['type'] == 'opportunity';
                              return Container(
                                width: 220,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1B182B) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.2),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: accent.withValues(alpha: 0.15),
                                          child: Icon(
                                            isOpp ? Icons.work_outline : Icons.person_outline,
                                            size: 15,
                                            color: accent,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            (isOpp ? item['title'] : item['name']) ?? 'Mitra AI',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: accent.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            item['sub_role'] ?? _selectedSubRoleLabel,
                                            style: const TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: accent,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            item['match_score'] ?? '98% Cocok',
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    Row(
                                      children: [
                                        Icon(Icons.location_on_outlined, size: 11, color: Colors.grey[600]),
                                        const SizedBox(width: 2),
                                        Expanded(
                                          child: Text(
                                            item['location'] ?? _activeLocationLabel,
                                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () {
                                            if (widget.user?.isGuest == true) {
                                              AuthGuardDialog.show(context, actionName: 'melihat detail hasil rekomendasi AI');
                                              return;
                                            }
                                            if (isOpp) {
                                              final opp = OpportunityModel(
                                                id: item['id']?.toString() ?? '1',
                                                title: item['title']?.toString() ?? 'Peluang Proyek AI',
                                                description: 'Peluang proyek yang direkomendasikan secara khusus oleh Kreavana AI.',
                                                subRoleSlug: item['sub_role']?.toString() ?? 'kreator',
                                                type: 'project',
                                                location: item['location']?.toString() ?? 'Indonesia',
                                                budgetRange: item['budget_range']?.toString() ?? 'Kompetitif',
                                                status: 'open',
                                                postedBy: 'admin',
                                              );
                                              OpportunityDetailSheet.show(
                                                context,
                                                opportunity: opp,
                                                currentUserId: widget.user?.id ?? '',
                                              );
                                            } else {
                                              if (widget.user != null) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => ExploreScreen(user: widget.user!),
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                          child: const Text(
                                            'Lihat >',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: accent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
