import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../services/profile_service.dart';
import '../services/api_service.dart';
import '../utils/form_validators.dart';
import '../widgets/skeleton_box.dart';
import '../widgets/desktop_sidebar_layout.dart';
import 'client_verification_page.dart';
import '../widgets/app_breadcrumbs.dart';
import 'main_navigation.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel user;
  final ValueChanged<UserModel> onUserUpdated;
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
    required this.onLogout,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;
  CreatorApplication? _latestApplication;
  late UserModel _currentUser;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _nameController.text = _currentUser.name;
    _phoneController.text = _currentUser.phone ?? '';
    _loadProfileDetails();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user != oldWidget.user) {
      _currentUser = widget.user;
    }
    if (widget.user.name != oldWidget.user.name) {
      _nameController.text = widget.user.name;
    }
    if (widget.user.phone != oldWidget.user.phone) {
      _phoneController.text = widget.user.phone ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileDetails() async {
    setState(() => _isLoading = true);
    final result = await ProfileService.getProfile(_currentUser.id ?? '');
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success == true) {
          _latestApplication = result.application;
          if (result.user != null) {
            _currentUser = result.user!;
            widget.onUserUpdated(result.user!);
          }
        }
      });
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null &&
          (result.files.single.path != null ||
              (kIsWeb && result.files.single.bytes != null))) {
        setState(() => _isLoading = true);

        Uint8List fileBytes;
        if (kIsWeb) {
          fileBytes = result.files.single.bytes!;
        } else {
          final file = io.File(result.files.single.path!);
          fileBytes = await file.readAsBytes();
        }

        final extension = result.files.single.extension ?? 'png';
        final base64String = base64Encode(fileBytes);
        final dataUrl = 'data:image/$extension;base64,$base64String';

        final response = await ProfileService.updateProfile(
          userId: _currentUser.id ?? '',
          avatarUrl: dataUrl,
        );

        if (mounted) {
          setState(() => _isLoading = false);
          if (response.success == true) {
            if (response.user != null) {
              setState(() => _currentUser = response.user!);
              widget.onUserUpdated(response.user!);
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Foto profil berhasil diperbarui.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  response.message ?? 'Gagal mengupload foto profil.',
                ),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.red.shade700,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _handleUpdateProfile() async {
    setState(() => _isLoading = true);
    final result = await ProfileService.updateProfile(
      userId: _currentUser.id ?? '',
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result.success == true) {
        if (result.user != null) {
          setState(() => _currentUser = result.user!);
          widget.onUserUpdated(result.user!);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil berhasil diperbarui.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Gagal memperbarui profil.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Widget _buildStatColumn(String label, String count, bool isDark) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    final content = Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: Navigator.canPop(context),
        toolbarHeight: 75,
        title: const Text(
          'Profil Pengguna',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.red),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Keluar Akun'),
                  content: const Text(
                    'Apakah Anda yakin ingin keluar dari Kreavana?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onLogout();
                      },
                      child: const Text(
                        'Keluar',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading && _latestApplication == null
          ? const ProfileSkeleton()
          : Scrollbar(
              controller: _scrollController,
              thumbVisibility: false,
              thickness: 5,
              radius: const Radius.circular(8),
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        24,
                        16,
                        isDesktop ? 110 : 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppBreadcrumbs(
                            items: [
                              BreadcrumbItem(
                                label: 'Beranda',
                                icon: Icons.home_rounded,
                                onTap: () => Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MainNavigation(
                                      initialUser: _currentUser,
                                      initialIndex: 0,
                                    ),
                                  ),
                                  (r) => false,
                                ),
                              ),
                              BreadcrumbItem(
                                label: 'Pengaturan',
                                icon: Icons.settings_rounded,
                                onTap: () {
                                  if (Navigator.canPop(context)) {
                                    Navigator.pop(context);
                                  } else {
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MainNavigation(
                                          initialUser: _currentUser,
                                          initialIndex: 8,
                                        ),
                                      ),
                                      (r) => false,
                                    );
                                  }
                                },
                              ),
                              const BreadcrumbItem(
                                label: 'Profil Saya',
                                icon: Icons.person_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          isDesktop
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Left Column - Profile Card
                                    Expanded(
                                      flex: 1,
                                      child: _buildProfileCard(theme, isDark),
                                    ),
                                    const SizedBox(width: 24),
                                    // Right Column - Form only
                                    Expanded(
                                      flex: 1,
                                      child: _buildProfileForm(theme, isDark),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    _buildProfileCard(theme, isDark),
                                    const SizedBox(height: 24),
                                    _buildProfileForm(theme, isDark),
                                  ],
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );

    if (isDesktop) {
      final isGov = (_currentUser.role == 'user' || _currentUser.role == 'creator') &&
          (_currentUser.subRole == 'government' ||
              _currentUser.subRole == 'institution' ||
              _currentUser.subRole == 'pemerintah' ||
              _currentUser.subRole == 'instansi');
      return DesktopSidebarLayout(
        user: _currentUser,
        activeRoute: isGov ? 'profil_instansi' : 'pengaturan',
        onUserUpdated: (u) {
          setState(() => _currentUser = u);
          widget.onUserUpdated(u);
        },
        child: content,
      );
    }

    return content;
  }

  Widget _buildProfileCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  theme.colorScheme.primary.withValues(alpha: 0.15),
                  theme.colorScheme.secondary.withValues(alpha: 0.1),
                ]
              : [
                  theme.colorScheme.primary.withValues(alpha: 0.05),
                  Colors.white,
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile Header Icon
          GestureDetector(
            onTap: _pickAndUploadAvatar,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 56,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.1,
                    ),
                    backgroundImage:
                        widget.user.avatarUrl != null &&
                            widget.user.avatarUrl!.isNotEmpty
                        ? NetworkImage(
                            ApiService.resolveAssetUrl(_currentUser.avatarUrl!),
                          )
                        : null,
                    child:
                        _currentUser.avatarUrl == null ||
                            _currentUser.avatarUrl!.isEmpty
                        ? Icon(
                            _currentUser.role == 'creator'
                                ? Icons.verified_user_rounded
                                : Icons.account_circle_outlined,
                            size: 56,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.scaffoldBackgroundColor,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _currentUser.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '@${_currentUser.username}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _currentUser.isAdmin
                    ? [Colors.red.shade400, Colors.red.shade600]
                    : _currentUser.role == 'creator'
                    ? [Colors.green.shade400, Colors.green.shade600]
                    : [Colors.grey.shade400, Colors.grey.shade600],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color:
                      (_currentUser.isAdmin
                              ? Colors.red
                              : _currentUser.role == 'creator'
                              ? Colors.green
                              : Colors.grey)
                          .withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              _currentUser.isAdmin
                  ? 'ADMINISTRATOR'
                  : _currentUser.role == 'creator'
                  ? 'CREATOR / MITRA'
                  : 'KLIEN / USER',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatColumn(
                'Pengikut',
                _currentUser.followersCount.toString(),
                isDark,
              ),
              const SizedBox(width: 32),
              Container(
                height: 40,
                width: 1,
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
              ),
              const SizedBox(width: 32),
              _buildStatColumn(
                'Mengikuti',
                _currentUser.followingCount.toString(),
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 20),
          // ── Verification & Role Badges ─────────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              // Client verification badge (blue)
              if (_currentUser.isVerified && !_currentUser.isCreator)
                _VerificationBadge(
                  label: 'Klien Terverifikasi',
                  icon: Icons.verified_rounded,
                  color: const Color(0xFF3B82F6),
                ),
              // Creator badge (green)
              if (_currentUser.isCreator)
                _VerificationBadge(
                  label: 'Kreator Terverifikasi',
                  icon: Icons.verified_rounded,
                  color: const Color(0xFF22C55E),
                ),
            ],
          ),
          // ── Quick action buttons ─────────────────────────────────────────
          if (!_currentUser.isAdmin) ...[
            const SizedBox(height: 16),
            if (!_currentUser.isVerified && !_currentUser.isCreator)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClientVerificationPage(
                          user: _currentUser,
                          onSuccess: _loadProfileDetails,
                        ),
                      ),
                    );
                    _loadProfileDetails();
                  },
                  icon: const Icon(Icons.badge_outlined, size: 16),
                  label: const Text('Verifikasi Identitas (KTP)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF3B82F6),
                    side: const BorderSide(color: Color(0xFF3B82F6)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            // (Daftar menjadi kreator dipindahkan ke pengaturan)
          ],
        ],
      ),
    );
  }

  Widget _buildProfileForm(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informasi Pribadi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nama Lengkap',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(15),
            ],
            decoration: const InputDecoration(
              labelText: 'Nomor Telepon',
              hintText: '081234567890',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: FormValidators.phone,
          ),
          const SizedBox(height: 20),
          TextFormField(
            initialValue: _currentUser.username,
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Username',
              filled: true,
              fillColor: isDark
                  ? Colors.grey.shade900.withValues(alpha: 0.5)
                  : Colors.grey.shade100,
              prefixIcon: const Icon(Icons.alternate_email_rounded),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            initialValue: _currentUser.email,
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Email',
              filled: true,
              fillColor: isDark
                  ? Colors.grey.shade900.withValues(alpha: 0.5)
                  : Colors.grey.shade100,
              prefixIcon: const Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _handleUpdateProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Simpan Perubahan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Verification Badge Widget ─────────────────────────────────────────────────

class _VerificationBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _VerificationBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
