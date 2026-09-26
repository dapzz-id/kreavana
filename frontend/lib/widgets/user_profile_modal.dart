import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
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

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final data = await VerificationService.getPublicProfile(widget.userId);
    if (mounted) {
      final isCreator = (data?['role'] ?? widget.initialRole ?? 'user') == 'creator';
      _tabController = TabController(
        length: isCreator ? 3 : 2,
        vsync: this,
      );
      setState(() {
        _profile = data;
        _isLoading = false;
      });
    }
  }

  void _openChat() {
    Navigator.pop(context);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DirectMessageScreen(
          currentUser: widget.currentUser,
        ),
      ),
    );
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
                              : AppTheme.primaryPurple.withValues(alpha: 0.15),
                          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                              ? NetworkImage(ApiService.resolveAssetUrl(avatarUrl))
                              : null,
                          child: (avatarUrl == null || avatarUrl.isEmpty)
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: isCreator
                                        ? const Color(0xFF10B981)
                                        : AppTheme.primaryPurple,
                                  ),
                                )
                              : null,
                        ),
                        if (isVerified)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: VerificationBadge(
                              role: role,
                              isVerified: isVerified,
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
                                role: role,
                                isVerified: isVerified,
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
                                      : const Color(0xFF6366F1).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isCreator
                                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                        : const Color(0xFF6366F1).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  isCreator
                                      ? (subRoleLabel.isNotEmpty ? 'Kreator • $subRoleLabel' : 'Kreator')
                                      : 'Klien / Pemilik Proyek',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: isCreator
                                        ? const Color(0xFF059669)
                                        : const Color(0xFF4F46E5),
                                  ),
                                ),
                              ),
                              // Centang badge label
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
              labelColor: AppTheme.primaryPurple,
              unselectedLabelColor: isDark ? AppTheme.textMuted : Colors.grey.shade600,
              indicatorColor: AppTheme.primaryPurple,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: isCreator
                  ? const [
                      Tab(text: 'Portofolio Pribadi'),
                      Tab(text: 'Proyek di Kreavana'),
                      Tab(text: 'Pengalaman Luar'),
                    ]
                  : const [
                      Tab(text: 'Proyek Klien'),
                      Tab(text: 'Informasi Akun'),
                    ],
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
                              ]
                            : [
                                _buildClientProjectsTab(isDark),
                                _buildClientInfoTab(isDark),
                              ],
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

        return Container(
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
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
}
