import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../services/profile_service.dart';
import '../widgets/creator_application_card.dart';
import '../widgets/app_breadcrumbs.dart';
import '../utils/app_errors.dart';
import '../widgets/desktop_sidebar_layout.dart';
import '../features/auth/services/auth_service.dart';
import 'main_navigation.dart';

class CreatorApplicationPage extends StatefulWidget {
  final UserModel? user;
  final ValueChanged<UserModel>? onUserUpdated;

  const CreatorApplicationPage({
    super.key,
    this.user,
    this.onUserUpdated,
  });

  @override
  State<CreatorApplicationPage> createState() => _CreatorApplicationPageState();
}

class _CreatorApplicationPageState extends State<CreatorApplicationPage> {
  bool _isLoading = false;
  CreatorApplication? _latestApplication;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    if (_currentUser == null) {
      AuthService.getCurrentUser().then((u) {
        if (mounted && u != null) {
          setState(() => _currentUser = u);
          _loadApplication();
        }
      });
    } else {
      _loadApplication();
    }
  }

  Future<void> _loadApplication() async {
    final uid = _currentUser?.id ?? widget.user?.id;
    if (uid == null || uid.isEmpty) return;
    setState(() => _isLoading = true);
    final result = await ProfileService.getProfile(uid);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success) {
          _latestApplication = result.application;
          if (result.user != null) {
            _currentUser = result.user;
            widget.onUserUpdated?.call(result.user!);
          }
        }
      });
    }
  }

  Future<void> _handleApply({
    required String category,
    required String skills,
    required String portfolio,
    required String experience,
    String? nik,
    String? fullNameKtp,
    String? addressKtp,
    String? ktpPhotoBase64,
    String? selfiePhotoBase64,
    String? birthPlace,
    String? birthDate,
    bool reuseKtp = false,
    String? nibNumber,
    String? nibFileBase64,
  }) async {
    setState(() => _isLoading = true);
    final result = await ProfileService.applyAsCreator(
      userId: _user?.id ?? '',
      subRoleCategory: category,
      skillDescription: skills,
      portfolioLink: portfolio,
      experience: experience,
      nik: nik,
      fullNameKtp: fullNameKtp,
      addressKtp: addressKtp,
      ktpPhotoBase64: ktpPhotoBase64,
      selfiePhotoBase64: selfiePhotoBase64,
      birthPlace: birthPlace,
      birthDate: birthDate,
      reuseKtp: reuseKtp,
      nibNumber: nibNumber,
      nibFileBase64: nibFileBase64,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      AppSnackbar.success(
        context,
        'Pengajuan Kreator berhasil dikirim! Menunggu verifikasi admin.',
      );
      await _loadApplication();
      if (mounted) Navigator.pop(context, true);
    } else {
      AppSnackbar.error(
        context,
        result.message ?? 'Gagal mengirim pengajuan.',
      );
    }
  }

  UserModel? get _user => _currentUser ?? widget.user;

  bool get _isCreatorApproved => _user?.isCreator == true || _user?.isCreatorApproved == true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    final content = Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        toolbarHeight: 72,
        titleSpacing: isDesktop ? 32 : 16,
        elevation: 0,
        title: const Text(
          'Pengajuan Menjadi Kreator',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: (_isLoading || _user == null)
          ? const Center(child: CircularProgressIndicator())
          : _isCreatorApproved
              ? _buildApprovedState(isDark)
              : _buildApplicationForm(isDark, isDesktop),
    );

    if (isDesktop && _currentUser != null) {
      return DesktopSidebarLayout(
        user: _currentUser!,
        activeRoute: 'pengaturan',
        child: content,
      );
    }

    return content;
  }

  Widget _buildApprovedState(bool isDark) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          border: Border.all(
            color: const Color(0xFF22C55E).withValues(alpha: 0.3),
          ),
          boxShadow: isDark ? null : AppTheme.cardShadowLight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                ),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Anda Sudah Menjadi Kreator!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Akun Anda telah disetujui sebagai Kreator di Kreavana. '
              'Nikmati semua fitur eksklusif kreator dan mulai terima proyek.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            // Creator badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF22C55E),
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Kreator Terverifikasi',
                    style: TextStyle(
                      color: Color(0xFF22C55E),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationForm(bool isDark, bool isDesktop) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 40 : 16,
        16,
        isDesktop ? 40 : 16,
        120,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Breadcrumbs
              AppBreadcrumbs(
                items: [
                  BreadcrumbItem(
                    label: 'Beranda',
                    icon: Icons.home_rounded,
                    onTap: () {
                      if (_currentUser != null) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MainNavigation(
                              initialUser: _currentUser!,
                              initialIndex: 0,
                            ),
                          ),
                          (r) => false,
                        );
                      }
                    },
                  ),
                  BreadcrumbItem(
                    label: 'Pengaturan',
                    icon: Icons.settings_rounded,
                    onTap: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else if (_currentUser != null) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MainNavigation(
                              initialUser: _currentUser!,
                              initialIndex: 8,
                            ),
                          ),
                          (r) => false,
                        );
                      }
                    },
                  ),
                  const BreadcrumbItem(
                    label: 'Pengajuan Kreator',
                    icon: Icons.workspace_premium_rounded,
                  ),
                ],
              ),

              // Info banner
              _CreatorInfoBanner(isDark: isDark),
              const SizedBox(height: 24),

              // Application status banner if pending
              if (_latestApplication != null &&
                  _latestApplication!.status == 'pending') ...[
                _PendingBanner(
                  isDark: isDark,
                  application: _latestApplication!,
                ),
                const SizedBox(height: 20),
              ] else if (_latestApplication != null &&
                  _latestApplication!.status == 'rejected') ...[
                _RejectedBanner(
                  isDark: isDark,
                  application: _latestApplication!,
                ),
                const SizedBox(height: 20),
              ],

              // KTP reuse badge if applicable
              if (_user?.isVerified == true &&
                  _user?.nik != null) ...[
                _KtpReuseBanner(isDark: isDark),
                const SizedBox(height: 20),
              ],

              // The actual form card
              CreatorApplicationCard(
                user: _user!,
                application: _latestApplication,
                onApply: _handleApply,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _CreatorInfoBanner extends StatelessWidget {
  final bool isDark;
  const _CreatorInfoBanner({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A2744), const Color(0xFF1E1B38)]
              : [const Color(0xFFF5F3FF), const Color(0xFFEDE9FE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: AppTheme.primaryPurple.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.workspace_premium_outlined,
              color: AppTheme.primaryPurple,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bergabung sebagai Kreator',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF4C1D95),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Daftarkan diri Anda sebagai Kreator dan buka peluang kerja dari ribuan klien. '
                  'Anda akan mendapatkan badge centang hijau dan akses ke dashboard kreator.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark
                        ? const Color(0xFFC4B5FD)
                        : const Color(0xFF6D28D9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  final bool isDark;
  final CreatorApplication application;

  const _PendingBanner({
    required this.isDark,
    required this.application,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.hourglass_empty_rounded,
            color: Color(0xFFF59E0B),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pengajuan Sedang Ditinjau',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Pengajuan Anda ${application.subRoleCategory} sedang dalam proses review admin. '
                  'Proses biasanya memakan waktu 1-3 hari kerja.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RejectedBanner extends StatelessWidget {
  final bool isDark;
  final CreatorApplication application;

  const _RejectedBanner({
    required this.isDark,
    required this.application,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(
          color: AppTheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.cancel_outlined,
            color: AppTheme.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pengajuan Sebelumnya Ditolak',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.error,
                  ),
                ),
                if (application.adminNote != null &&
                    application.adminNote!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Alasan: ${application.adminNote}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.grey.shade700,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Anda dapat mengajukan ulang dengan melengkapi data yang diperlukan.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KtpReuseBanner extends StatelessWidget {
  final bool isDark;
  const _KtpReuseBanner({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(
          color: const Color(0xFF22C55E).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.badge_outlined,
            color: Color(0xFF22C55E),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'KTP Anda sudah terverifikasi sebelumnya. '
              'Anda dapat menggunakan KTP yang sama untuk pengajuan ini.',
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
