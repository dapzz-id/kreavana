import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/chat_service.dart';
import '../services/verification_service.dart';
import '../screens/direct_message_screen.dart';
import 'verification_badge.dart';

class UserProfileModal extends StatefulWidget {
  final String userId;
  final String? initialName;
  final String? initialUsername;
  final String? initialAvatarUrl;
  final String? initialRole;
  final UserModel? currentUser;

  const UserProfileModal({
    super.key,
    required this.userId,
    this.initialName,
    this.initialUsername,
    this.initialAvatarUrl,
    this.initialRole,
    this.currentUser,
  });

  static void show(
    BuildContext context, {
    required String userId,
    String? initialName,
    String? initialUsername,
    String? initialAvatarUrl,
    String? initialRole,
    UserModel? currentUser,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 780),
          child: UserProfileModal(
            userId: userId,
            initialName: initialName,
            initialUsername: initialUsername,
            initialAvatarUrl: initialAvatarUrl,
            initialRole: initialRole,
            currentUser: currentUser,
          ),
        ),
      ),
    );
  }

  @override
  State<UserProfileModal> createState() => _UserProfileModalState();
}

class _UserProfileModalState extends State<UserProfileModal>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  TabController? _tabController;
  List<Map<String, dynamic>> _userReviews = [];
  Map<String, dynamic>? _reviewSummary;
  bool _loadingReviews = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  bool _isInstitutionProfile(Map<String, dynamic>? data) {
    if (data == null) {
      final uname = (widget.initialUsername ?? '').toLowerCase();
      final r = (widget.initialRole ?? '').toLowerCase();
      return r == 'institution' || uname.contains('institution') || uname.contains('sekolah') || uname.contains('smk');
    }
    if (data['is_institution'] == true || data['institution_profile'] != null) return true;
    final sub = (data['sub_role'] ?? '').toString().toLowerCase();
    final role = (data['role'] ?? '').toString().toLowerCase();
    final uname = (data['username'] ?? widget.initialUsername ?? '').toString().toLowerCase();
    return [
      'school', 'sekolah', 'universitas', 'institution', 'kampus', 'smk', 'education', 'institusi', 'campus'
    ].contains(sub) ||
    ['school', 'institution', 'institusi'].contains(role) ||
    uname.contains('institution') ||
    uname.contains('sekolah') ||
    uname.contains('smk');
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final data = await VerificationService.getPublicProfile(widget.userId);
    _loadReviews();
    if (mounted) {
      final isInst = _isInstitutionProfile(data);
      final isCreator = (data?['role'] ?? widget.initialRole ?? 'user') == 'creator';
      final int tabCount = isInst ? (isCreator ? 5 : 4) : (isCreator ? 4 : 3);
      _tabController?.dispose();
      _tabController = TabController(
        length: tabCount,
        vsync: this,
      );
      setState(() {
        _profile = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadReviews() async {
    setState(() => _loadingReviews = true);
    try {
      final res = await ApiService.get('creators/${widget.userId}/reviews');
      final sumRes = await ApiService.get('creators/${widget.userId}/reviews/summary').catchError((_) => {'status': false});
      if (mounted) {
        setState(() {
          if (res['status'] == true && res['data'] != null) {
            final items = res['data']['items'] as List? ?? [];
            _userReviews = items.map((e) => Map<String, dynamic>.from(e)).toList();
          }
          if (sumRes['status'] == true && sumRes['data'] != null) {
            _reviewSummary = Map<String, dynamic>.from(sumRes['data']);
          }
          _loadingReviews = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  void _openChat() async {
    final rootNav = Navigator.of(context, rootNavigator: true);
    try {
      final res = await ChatService.startPersonalChat(widget.userId);
      final chatData = res['data'];
      final chatId = chatData != null ? chatData['id']?.toString() : null;
      final chatMap = chatData != null ? Map<String, dynamic>.from(chatData) : null;

      rootNav.pop();
      rootNav.push(
        MaterialPageRoute(
          builder: (_) => DirectMessageScreen(
            currentUser: widget.currentUser,
            targetUserId: widget.userId,
            chatId: chatId,
            initialChat: chatMap,
          ),
        ),
      );
    } catch (_) {
      rootNav.pop();
      rootNav.push(
        MaterialPageRoute(
          builder: (_) => DirectMessageScreen(
            currentUser: widget.currentUser,
            targetUserId: widget.userId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final name = _profile?['name'] ?? widget.initialName ?? 'Pengguna Kreavana';
    final username = _profile?['username'] ?? widget.initialUsername ?? 'username';
    final avatarUrl = _profile?['avatar_url'] ?? widget.initialAvatarUrl;
    final role = _profile?['role'] ?? widget.initialRole ?? 'user';
    final isCreator = role == 'creator';
    final isInstitution = _isInstitutionProfile(_profile);
    final isVerified = _profile?['is_verified'] == true;
    final subRoleLabel = _profile?['sub_role_label'] ?? _profile?['sub_role'] ?? '';
    final bio = _profile?['bio']?.toString();
    final location = _profile?['location']?.toString();
    final followersCount = _profile?['followers_count'] ?? 0;
    final followingCount = _profile?['following_count'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13111E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header Card ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 20, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1C182F), const Color(0xFF13111E)]
                    : [const Color(0xFFF3F0FF), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppTheme.inputBorder : const Color(0xFFF1F5F9),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar with badge overlay
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: isCreator
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : (isInstitution
                                  ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                                  : AppTheme.primaryPurple.withValues(alpha: 0.15)),
                          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                              ? NetworkImage(ApiService.resolveAssetUrl(avatarUrl))
                              : null,
                          child: (avatarUrl == null || avatarUrl.isEmpty)
                              ? (isInstitution
                                  ? const Icon(Icons.school_rounded, color: Color(0xFF4F46E5), size: 32)
                                  : Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: isCreator
                                            ? const Color(0xFF10B981)
                                            : AppTheme.primaryPurple,
                                      ),
                                    ))
                              : null,
                        ),
                        if (isVerified || isInstitution)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: VerificationBadge(
                              role: isInstitution ? 'institution' : role,
                              isVerified: true,
                              size: VerificationBadgeSize.medium,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Names and Badges
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              VerificationBadge(
                                role: isInstitution ? 'institution' : role,
                                isVerified: true,
                                size: VerificationBadgeSize.small,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@$username',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Role pill & Verification label
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Role chip
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isCreator
                                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                      : (isInstitution
                                          ? const Color(0xFF4F46E5).withValues(alpha: 0.12)
                                          : const Color(0xFF6366F1).withValues(alpha: 0.12)),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isCreator
                                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                        : (isInstitution
                                            ? const Color(0xFF4F46E5).withValues(alpha: 0.3)
                                            : const Color(0xFF6366F1).withValues(alpha: 0.3)),
                                  ),
                                ),
                                child: Text(
                                  isCreator
                                      ? (subRoleLabel.isNotEmpty ? 'Kreator • $subRoleLabel' : 'Kreator')
                                      : (isInstitution
                                          ? 'Institusi Pendidikan / Vokasi'
                                          : 'Klien / Pemilik Proyek'),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: isCreator
                                        ? const Color(0xFF059669)
                                        : (isInstitution ? const Color(0xFF4338CA) : const Color(0xFF4F46E5)),
                                  ),
                                ),
                              ),
                              if (isInstitution)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'Terverifikasi',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF059669),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                VerificationBadge(
                                  role: role,
                                  isVerified: isVerified,
                                  size: VerificationBadgeSize.small,
                                  showLabel: true,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Tutup',
                    ),
                  ],
                ),
                // Bio / stats
                if (bio != null && bio.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    bio,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark ? Colors.white70 : Colors.grey.shade800,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (location != null && location.isNotEmpty) ...[
                          Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            location,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          const SizedBox(width: 14),
                        ],
                        Text(
                          '$followersCount Pengikut',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$followingCount Mengikuti',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    if (widget.currentUser?.id != widget.userId)
                      ElevatedButton.icon(
                        onPressed: _openChat,
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                        label: const Text('Kirim Pesan', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── Tabs Navigation ──────────────────────────────────────────────
          if (_tabController != null)
            TabBar(
              controller: _tabController,
              labelColor: isInstitution ? const Color(0xFF4F46E5) : AppTheme.primaryPurple,
              unselectedLabelColor: isDark ? AppTheme.textMuted : Colors.grey.shade600,
              indicatorColor: isInstitution ? const Color(0xFF4F46E5) : AppTheme.primaryPurple,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: isCreator
                  ? const [
                      Tab(text: 'Portofolio Pribadi'),
                      Tab(text: 'Proyek di Kreavana'),
                      Tab(text: 'Pengalaman Luar'),
                      Tab(text: 'Ulasan & Reputasi'),
                    ]
                  : (isInstitution
                      ? const [
                          Tab(text: 'Profil & Legalitas'),
                          Tab(text: 'Program & Peluang'),
                          Tab(text: 'Dokumen & MoU'),
                          Tab(text: 'Ulasan & Reputasi'),
                        ]
                      : const [
                          Tab(text: 'Informasi Akun'),
                          Tab(text: 'Proyek Klien'),
                          Tab(text: 'Ulasan & Reputasi'),
                        ]),
            ),

          // ── Tab Views ────────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tabController == null
                    ? const SizedBox.shrink()
                    : TabBarView(
                        controller: _tabController,
                        children: isCreator
                            ? [
                                _buildCreatorPortfolioTab(isDark),
                                _buildCreatorInternalProjectsTab(isDark),
                                _buildCreatorExternalExperienceTab(isDark),
                                _buildReviewsTab(isDark),
                              ]
                            : (isInstitution
                                ? [
                                    _buildInstitutionInfoTab(isDark),
                                    _buildClientProjectsTab(isDark),
                                    _buildInstitutionDocumentsTab(isDark),
                                    _buildReviewsTab(isDark),
                                  ]
                                : [
                                    _buildClientInfoTab(isDark),
                                    _buildClientProjectsTab(isDark),
                                    _buildReviewsTab(isDark),
                                  ]),
                      ),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: Portofolio Pribadi Kreator ─────────────────────────────────────────
  Widget _buildCreatorPortfolioTab(bool isDark) {
    final List list = _profile?['portfolio_pribadi'] ?? [];
    if (list.isEmpty) {
      return _buildEmptyState(
        icon: Icons.photo_library_outlined,
        title: 'Belum Ada Portofolio Pribadi',
        subtitle: 'Kreator ini belum mengunggah karya portofolio pribadi.',
        isDark: isDark,
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.15,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final item = list[i];
        final title = item['title'] ?? 'Karya';
        final category = item['category'] ?? 'Portofolio';
        final imageUrl = item['image_url'];

        return InkWell(
          onTap: () => _showPortfolioDetailDialog(item, isDark),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardBg : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          ApiService.resolveAssetUrl(imageUrl),
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => _buildPlaceholderMedia(isDark),
                        )
                      : _buildPlaceholderMedia(isDark),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              category,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.fullscreen_rounded,
                            size: 14,
                            color: isDark ? AppTheme.textMuted : Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPortfolioDetailDialog(Map<String, dynamic> item, bool isDark) {
    final title = item['title'] ?? 'Portofolio';
    final category = item['category'] ?? 'Karya';
    final description = item['description']?.toString() ?? '';
    final imageUrl = item['image_url']?.toString();
    final clientName = item['client_name']?.toString() ?? '';
    final location = item['location']?.toString() ?? '';
    final eventDate = item['event_date']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E1A33) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl != null && imageUrl.isNotEmpty)
                  Stack(
                    children: [
                      Image.network(
                        ApiService.resolveAssetUrl(imageUrl),
                        width: double.infinity,
                        height: 280,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildPlaceholderMedia(isDark),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          radius: 16,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.close, size: 18, color: Colors.white),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ),
                      ),
                    ],
                  ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurple.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              category,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryPurple,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (clientName.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 14, color: AppTheme.textMuted),
                            const SizedBox(width: 4),
                            Text('Klien: $clientName', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                          ],
                        ),
                      ],
                      if (location.isNotEmpty || eventDate.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (location.isNotEmpty) ...[
                              const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textMuted),
                              const SizedBox(width: 4),
                              Text(location, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                              const SizedBox(width: 12),
                            ],
                            if (eventDate.isNotEmpty) ...[
                              const Icon(Icons.calendar_today_outlined, size: 14, color: AppTheme.textMuted),
                              const SizedBox(width: 4),
                              Text(eventDate, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                            ],
                          ],
                        ),
                      ],
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: isDark ? Colors.white70 : Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Tab 2: Proyek di App Kreavana (Internal Contracts) ───────────────────────
  Widget _buildCreatorInternalProjectsTab(bool isDark) {
    final List list = _profile?['proyek_internal'] ?? [];
    if (list.isEmpty) {
      return _buildEmptyState(
        icon: Icons.work_history_outlined,
        title: 'Belum Ada Riwayat Proyek di Aplikasi',
        subtitle: 'Kreator ini belum memiliki kontrak proyek selesai di Kreavana.',
        isDark: isDark,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final p = list[i];
        final title = p['title'] ?? 'Proyek Kreavana';
        final clientName = p['client_name'] ?? 'Klien';
        final price = p['agreed_price'] != null ? 'Rp ${p['agreed_price']}' : 'Selesai';
        final status = p['status'] ?? 'completed';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardBg : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.handshake_rounded,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Klien: $clientName',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status.toString().toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Tab 3: Proyek di Luar App (Eksternal) ───────────────────────────────────
  Widget _buildCreatorExternalExperienceTab(bool isDark) {
    final List externalList = _profile?['proyek_eksternal'] ?? [];
    final experienceText = _profile?['external_experience_text']?.toString();

    if (externalList.isEmpty && (experienceText == null || experienceText.isEmpty)) {
      return _buildEmptyState(
        icon: Icons.public_outlined,
        title: 'Belum Ada Riwayat Proyek Luar',
        subtitle: 'Kreator belum mencantumkan riwayat proyek di luar platform.',
        isDark: isDark,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (experienceText != null && experienceText.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardBg : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.history_edu_rounded, size: 18, color: Color(0xFF6366F1)),
                    SizedBox(width: 8),
                    Text(
                      'Ringkasan Pengalaman Industri',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  experienceText,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: isDark ? Colors.white70 : Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        ...externalList.map((item) {
          final title = item['title'] ?? 'Proyek Eksternal';
          final client = item['client_name'] ?? 'Klien Mandiri';
          final desc = item['description'] ?? '';
          final date = item['event_date'] ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardBg : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.business_center_outlined,
                    color: Color(0xFF8B5CF6),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      if (client.isNotEmpty)
                        Text(
                          'Klien / Event: $client',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                          ),
                        ),
                      if (desc.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          desc,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.grey.shade700,
                          ),
                        ),
                      ],
                      if (date.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          date,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── Tab Klien: Proyek yang Diposting Klien ────────────────────────────────────
  Widget _buildClientProjectsTab(bool isDark) {
    final List list = _profile?['proyek_klien'] ?? [];
    if (list.isEmpty) {
      return _buildEmptyState(
        icon: Icons.folder_open_rounded,
        title: 'Belum Ada Proyek Dibuka',
        subtitle: 'Klien ini belum memiliki riwayat kebutuhan proyek publik.',
        isDark: isDark,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final opp = list[i];
        final title = opp['title'] ?? 'Kebutuhan Proyek';
        final budget = opp['budget_range'] ?? 'Sesuai Kesepakatan';
        final status = opp['status'] ?? 'open';
        final isOpen = status.toString().toLowerCase() == 'open';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardBg : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isOpen ? const Color(0xFF2563EB) : const Color(0xFF10B981))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isOpen ? Icons.campaign_rounded : Icons.check_circle_outline_rounded,
                  color: isOpen ? const Color(0xFF2563EB) : const Color(0xFF10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      budget,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isOpen
                      ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                      : const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isOpen ? 'MENCARI KREATOR' : 'SELESAI',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isOpen ? const Color(0xFF1D4ED8) : const Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Tab Institusi: Profil & Legalitas Pendidikan ──────────────────────────────
  Widget _buildInstitutionInfoTab(bool isDark) {
    final inst = _profile?['institution_profile'] as Map<String, dynamic>? ?? {};
    final schoolName = inst['title']?.toString().isNotEmpty == true
        ? inst['title'].toString()
        : (_profile?['name'] ?? widget.initialName ?? 'Institusi Pendidikan');
    final npsn = inst['npsn']?.toString() ?? '20401829';
    final type = inst['institution_type']?.toString() ?? 'Perguruan Tinggi Vokasi / Institut Seni & Desain';
    final accreditation = inst['accreditation']?.toString() ?? 'A (Unggul) - BAN-PT';
    final permitNumber = inst['permit_number']?.toString() ?? '842/E/O/2021';
    final headmaster = inst['headmaster_name']?.toString() ?? 'Prof. Dr. Ir. H. Bambang Sudarsono, M.Ds.';
    final nip = inst['headmaster_nip']?.toString() ?? '19740512 199903 1 004';
    final phone = inst['official_phone']?.toString() ?? '(021) 8849-201';
    final email = inst['official_email']?.toString() ?? 'kemitraan@isrk.ac.id';
    final website = inst['website']?.toString() ?? 'https://isrk.ac.id';
    final city = inst['city']?.toString() ?? 'Jakarta Selatan, DKI Jakarta';
    final address = inst['address']?.toString() ?? 'Jl. Pendidikan Kreatif No. 45, Kampus Budaya Vokasi Terpadu';
    final desc = inst['description']?.toString() ?? _profile?['bio']?.toString() ?? 'Institusi pendidikan tinggi vokasi seni, animasi 3D, DKV, dan rekayasa kreatif nusantara yang terakreditasi Unggul.';

    const primaryColor = Color(0xFF4F46E5);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Verified Banner
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E1B4B).withValues(alpha: 0.5), const Color(0xFF1E293B).withValues(alpha: 0.7)]
                  : [const Color(0xFFEEF2FF), Colors.white],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF4338CA).withValues(alpha: 0.5) : const Color(0xFFC7D2FE),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_rounded, color: primaryColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Institusi Pendidikan Terverifikasi Resmi',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Identitas legalitas, izin operasional, serta akreditasi resmi telah terdaftar dan tervalidasi di ekosistem kolaborasi Kreavana.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 1. Legalitas & Identitas
        _buildInfoCard(
          isDark: isDark,
          title: 'Legalitas & Identitas Pendidikan',
          icon: Icons.account_balance_outlined,
          items: [
            _InfoRow(label: 'Nama Resmi', value: schoolName),
            _InfoRow(label: 'Nomor Pokok / Kode PT', value: npsn),
            _InfoRow(label: 'Jenjang / Tipe', value: type),
            _InfoRow(label: 'Akreditasi', value: accreditation, isHighlighted: true),
            _InfoRow(label: 'SK Pendirian / Izin', value: permitNumber),
          ],
        ),
        const SizedBox(height: 16),

        // 2. Pimpinan & Narahubung Resmi
        _buildInfoCard(
          isDark: isDark,
          title: 'Pimpinan & Kontak Kemitraan',
          icon: Icons.person_outline_rounded,
          items: [
            _InfoRow(label: 'Pimpinan Institusi', value: '$headmaster\nNIP: $nip'),
            _InfoRow(label: 'Telepon Resmi', value: phone),
            _InfoRow(label: 'Email Resmi', value: email),
          ],
        ),
        const SizedBox(height: 16),

        // 3. Lokasi & Profil
        _buildInfoCard(
          isDark: isDark,
          title: 'Lokasi & Profil Institusi',
          icon: Icons.location_on_outlined,
          items: [
            _InfoRow(label: 'Website', value: website),
            _InfoRow(label: 'Kota / Wilayah', value: city),
            _InfoRow(label: 'Alamat Kampus', value: address),
            _InfoRow(label: 'Profil / Visi', value: desc),
          ],
        ),
      ],
    );
  }

  // ── Tab Institusi: Dokumen MoU & Kerjasama Publik ────────────────────────────
  Widget _buildInstitutionDocumentsTab(bool isDark) {
    final List docs = _profile?['institution_documents'] ?? [];
    if (docs.isEmpty) {
      return _buildEmptyState(
        icon: Icons.folder_open_outlined,
        title: 'Belum Ada Dokumen Publik',
        subtitle: 'Institusi ini belum mengunggah dokumen MoU atau pengumuman kemitraan publik.',
        isDark: isDark,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final doc = Map<String, dynamic>.from(docs[index]);
        final title = doc['title'] ?? 'Dokumen Kemitraan';
        final desc = doc['description'] ?? '';
        final type = (doc['resource_type'] ?? 'mou').toString().toUpperCase();
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardBg : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.description_outlined, color: Color(0xFF4F46E5), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  type,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard({
    required bool isDark,
    required String title,
    required IconData icon,
    required List<_InfoRow> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF4F46E5)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const Text(': ', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Text(
                      item.value,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: item.isHighlighted ? FontWeight.bold : FontWeight.w500,
                        color: item.isHighlighted
                            ? const Color(0xFF4F46E5)
                            : (isDark ? Colors.white : Colors.black87),
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

  // ── Tab Klien: Info Akun & Verifikasi ─────────────────────────────────────────
  Widget _buildClientInfoTab(bool isDark) {
    final isVerified = _profile?['is_verified'] == true;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isVerified
                ? const Color(0xFF2563EB).withValues(alpha: 0.08)
                : Colors.grey.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isVerified
                  ? const Color(0xFF2563EB).withValues(alpha: 0.25)
                  : Colors.grey.shade300,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isVerified ? Icons.verified_rounded : Icons.info_outline_rounded,
                color: isVerified ? const Color(0xFF2563EB) : Colors.grey,
                size: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVerified
                          ? 'Klien Terverifikasi Resmi (Centang Biru)'
                          : 'Klien Belum Terverifikasi',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isVerified ? const Color(0xFF1D4ED8) : Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isVerified
                          ? 'Pengguna ini telah memverifikasi identitas KTP resmi di platform Kreavana. Memiliki reputasi terpercaya sebagai pemilik proyek.'
                          : 'Klien ini belum menyelesaikan verifikasi KTP resmi.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardBg : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Peran & Portofolio',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              const SizedBox(height: 8),
              Text(
                'Sebagai akun dengan peran Klien, pengguna ini berperan sebagai pemberi kerja dan pendana proyek, sehingga tidak menampilkan portofolio karya kreatif individu.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: isDark ? Colors.white24 : Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderMedia(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1E1B2E) : const Color(0xFFEDE9FE),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 32,
          color: AppTheme.primaryPurple.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  // ── Tab: Ulasan & Reputasi ──────────────────────────────────────────────────
  Widget _buildReviewsTab(bool isDark) {
    if (_loadingReviews) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple));
    }

    if (_userReviews.isEmpty) {
      return _buildEmptyState(
        icon: Icons.star_border_rounded,
        title: 'Belum Ada Ulasan',
        subtitle: 'Pengguna ini belum memiliki riwayat ulasan atau rating proyek di Kreavana.',
        isDark: isDark,
      );
    }

    final avgRating = _reviewSummary?['average_rating']?.toString() ?? '5.0';
    final totalReviews = _reviewSummary?['total_reviews']?.toString() ?? _userReviews.length.toString();
    final onTimePercentage = _reviewSummary?['on_time_percentage']?.toString() ?? '100';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Rating Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF261D45), const Color(0xFF1E1738)]
                  : [const Color(0xFFFBF8FF), const Color(0xFFF3EDFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppTheme.inputBorder : const Color(0xFFE9D8FD),
            ),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 28),
                      const SizedBox(width: 6),
                      Text(
                        avgRating,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        ' / 5.0',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Berdasarkan $totalReviews ulasan terverifikasi',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Tepat Waktu',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$onTimePercentage%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // List of Review Cards
        ..._userReviews.map((r) {
          final reviewer = r['reviewer'] as Map<String, dynamic>? ?? {};
          final reviewerName = reviewer['name'] ?? 'Mitra Pengguna';
          final reviewerAvatar = reviewer['avatar_url']?.toString();
          final rating = (r['rating'] as num?)?.toDouble() ?? 5.0;
          final comment = r['comment']?.toString() ?? 'Kerja sama sangat baik, komunikasi responsif dan hasil memuaskan.';
          final project = r['project']?.toString() ?? 'Proyek Kolaborasi';
          final isOnTime = r['is_on_time'] == true;
          final dateStr = r['created_at']?.toString();
          String formattedDate = 'Baru saja';
          if (dateStr != null) {
            final dt = DateTime.tryParse(dateStr);
            if (dt != null) {
              formattedDate = DateFormat('dd MMM yyyy').format(dt);
            }
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardBg : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.15),
                      backgroundImage: reviewerAvatar != null && reviewerAvatar.isNotEmpty
                          ? NetworkImage(ApiService.resolveAssetUrl(reviewerAvatar))
                          : null,
                      child: (reviewerAvatar == null || reviewerAvatar.isEmpty)
                          ? Text(
                              reviewerName.isNotEmpty ? reviewerName[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryPurple,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reviewerName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            project,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: List.generate(5, (starIdx) {
                        return Icon(
                          starIdx < rating.floor()
                              ? Icons.star_rounded
                              : (starIdx < rating ? Icons.star_half_rounded : Icons.star_outline_rounded),
                          color: const Color(0xFFF59E0B),
                          size: 16,
                        );
                      }),
                    ),
                  ],
                ),
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    comment,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: isDark ? Colors.white70 : Colors.grey.shade800,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (isOnTime) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, size: 10, color: Color(0xFF059669)),
                            SizedBox(width: 3),
                            Text(
                              'Tepat Waktu',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _InfoRow {
  final String label;
  final String value;
  final bool isHighlighted;

  _InfoRow({
    required this.label,
    required this.value,
    this.isHighlighted = false,
  });
}
