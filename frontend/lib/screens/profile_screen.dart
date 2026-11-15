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
import '../utils/app_errors.dart';
import '../utils/form_validators.dart';
import '../widgets/skeleton_box.dart';
import '../widgets/desktop_sidebar_layout.dart';
import 'client_verification_page.dart';
import '../widgets/app_breadcrumbs.dart';
import '../widgets/auth_guard_dialog.dart';
import '../widgets/app_sweet_alert.dart';
import '../widgets/user_profile_modal.dart';
import 'main_navigation.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel user;
  final ValueChanged<UserModel> onUserUpdated;
  final VoidCallback onLogout;
  final bool showSidebar;
  final bool? isAccountProfileOnly;
  final bool? isInstitutionProfileOnly;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
    required this.onLogout,
    this.showSidebar = true,
    this.isAccountProfileOnly,
    this.isInstitutionProfileOnly,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;
  CreatorApplication? _latestApplication;
  late UserModel _currentUser;
  int _schoolProfileTab = 1; // 0 = Profil Akun (PIC), 1 = Profil Institusi (Publik)

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _profileFormKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // ── School / Institution Profile Controllers ─────────────────────────────
  final _schoolNameController = TextEditingController();
  final _npsnController = TextEditingController();
  final _institutionTypeController = TextEditingController();
  final _accreditationController = TextEditingController();
  final _permitNumberController = TextEditingController();
  final _headmasterNameController = TextEditingController();
  final _headmasterNipController = TextEditingController();
  final _schoolPhoneController = TextEditingController();
  final _schoolEmailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _schoolResourceId;
  bool _isSavingSchool = false;

  bool get _isSchool {
    if (_currentUser.isInstitution) return true;
    final sub = _currentUser.subRole?.toLowerCase().trim() ?? '';
    final role = _currentUser.role.toLowerCase().trim();
    final verif = _currentUser.verificationType?.toLowerCase().trim() ?? '';
    final uname = _currentUser.username.toLowerCase().trim();
    final mail = _currentUser.email.toLowerCase().trim();
    return [
      'school',
      'sekolah',
      'universitas',
      'institution',
      'kampus',
      'smk',
      'education',
      'institusi',
      'campus',
    ].contains(sub) ||
    ['school', 'institution', 'institusi'].contains(role) ||
    verif == 'institution' ||
    uname.contains('institution') ||
    uname.contains('sekolah') ||
    uname.contains('smk') ||
    mail.startsWith('institution@') ||
    mail.startsWith('smk@') ||
    mail.startsWith('sekolah@');
  }

  bool get _isGovernment {
    final sub = _currentUser.subRole?.toLowerCase().trim() ?? '';
    return [
      'government',
      'pemerintah',
      'instansi',
      'dinas',
      'bumn',
      'kementerian',
    ].contains(sub);
  }

  void _initSchoolDefaults() {
    _schoolNameController.text = _currentUser.name;
    _schoolPhoneController.text = _currentUser.phone ?? '';
    _schoolEmailController.text = _currentUser.email;
    _cityController.text = _currentUser.location ?? '';
    _addressController.text = _currentUser.location ?? '';
    _descriptionController.text = _currentUser.bio ?? '';
    _npsnController.text = '';
    _institutionTypeController.text = '';
    _accreditationController.text = '';
    _permitNumberController.text = '';
    _headmasterNameController.text = '';
    _headmasterNipController.text = '';
    _websiteController.text = '';
  }

  void _openPublicProfilePreview() {
    UserProfileModal.show(
      context,
      userId: _currentUser.id ?? '',
      initialName: _schoolNameController.text.trim().isNotEmpty
          ? _schoolNameController.text.trim()
          : _currentUser.name,
      initialUsername: _currentUser.username,
      initialAvatarUrl: _currentUser.avatarUrl,
      initialRole: _currentUser.role,
      currentUser: _currentUser,
    );
  }

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    if (widget.isAccountProfileOnly == true) {
      _schoolProfileTab = 0;
    } else if (widget.isInstitutionProfileOnly == true) {
      _schoolProfileTab = 1;
    } else {
      _schoolProfileTab = 1;
    }
    if (_currentUser.isGuest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AuthGuardDialog.show(context, actionName: 'mengakses profil akun');
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => MainNavigation(
                initialUser: widget.user,
                initialIndex: 0,
              ),
            ),
            (r) => false,
          );
        }
      });
      return;
    }
    _nameController.text = _currentUser.name;
    _phoneController.text = _currentUser.phone ?? '';
    _usernameController.text = _currentUser.username;
    _emailController.text = _currentUser.email;
    if (_isSchool) {
      _initSchoolDefaults();
    }
    _loadProfileDetails();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAccountProfileOnly != oldWidget.isAccountProfileOnly ||
        widget.isInstitutionProfileOnly != oldWidget.isInstitutionProfileOnly) {
      if (widget.isAccountProfileOnly == true) {
        setState(() => _schoolProfileTab = 0);
      } else if (widget.isInstitutionProfileOnly == true) {
        setState(() => _schoolProfileTab = 1);
      }
    }
    if (widget.user != oldWidget.user) {
      _currentUser = widget.user;
      if (_isSchool && _schoolNameController.text.isEmpty) {
        _initSchoolDefaults();
      }
    }
    if (widget.user.name != oldWidget.user.name) {
      _nameController.text = widget.user.name;
      if (_isSchool && _schoolNameController.text.isEmpty) {
        _schoolNameController.text = widget.user.name;
      }
    }
    if (widget.user.phone != oldWidget.user.phone) {
      _phoneController.text = widget.user.phone ?? '';
      if (_isSchool && _schoolPhoneController.text.isEmpty) {
        _schoolPhoneController.text = widget.user.phone ?? '';
      }
    }
    if (widget.user.username != oldWidget.user.username) {
      _usernameController.text = widget.user.username;
    }
    if (widget.user.email != oldWidget.user.email) {
      _emailController.text = widget.user.email;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _scrollController.dispose();
    _schoolNameController.dispose();
    _npsnController.dispose();
    _institutionTypeController.dispose();
    _accreditationController.dispose();
    _permitNumberController.dispose();
    _headmasterNameController.dispose();
    _headmasterNipController.dispose();
    _schoolPhoneController.dispose();
    _schoolEmailController.dispose();
    _websiteController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileDetails() async {
    setState(() => _isLoading = true);
    final result = await ProfileService.getProfile(_currentUser.id ?? '');
    if (mounted) {
      if (result.success == true) {
        _latestApplication = result.application;
        if (result.user != null) {
          _currentUser = result.user!;
          widget.onUserUpdated(result.user!);
          if (_isSchool && _schoolNameController.text.isEmpty) {
            _initSchoolDefaults();
          }
        }
      }
    }

    if (_isSchool) {
      try {
        final profileRes = await ApiService.get(
          'institution/resources',
          queryParams: {'type': 'profile'},
        );
        if (mounted && profileRes['status'] == true && profileRes['data'] is List) {
          final resList = profileRes['data'] as List;
          if (resList.isNotEmpty) {
            final profileItem = Map<String, dynamic>.from(resList.first);
            _schoolResourceId = profileItem['id']?.toString();
            final meta = profileItem['metadata'] is Map
                ? Map<String, dynamic>.from(profileItem['metadata'])
                : <String, dynamic>{};

            if (profileItem['title'] != null && profileItem['title'].toString().trim().isNotEmpty) {
              _schoolNameController.text = profileItem['title'].toString();
            }
            if (profileItem['description'] != null && profileItem['description'].toString().trim().isNotEmpty) {
              _descriptionController.text = profileItem['description'].toString();
            }
            if (meta['npsn'] != null) _npsnController.text = meta['npsn'].toString();
            if (meta['institution_type'] != null) _institutionTypeController.text = meta['institution_type'].toString();
            if (meta['accreditation'] != null) _accreditationController.text = meta['accreditation'].toString();
            if (meta['permit_number'] != null) _permitNumberController.text = meta['permit_number'].toString();
            if (meta['headmaster_name'] != null) _headmasterNameController.text = meta['headmaster_name'].toString();
            if (meta['headmaster_nip'] != null) _headmasterNipController.text = meta['headmaster_nip'].toString();
            if (meta['official_phone'] != null) _schoolPhoneController.text = meta['official_phone'].toString();
            if (meta['official_email'] != null) _schoolEmailController.text = meta['official_email'].toString();
            if (meta['website'] != null) _websiteController.text = meta['website'].toString();
            if (meta['city'] != null) _cityController.text = meta['city'].toString();
            if (meta['address'] != null) _addressController.text = meta['address'].toString();
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      // ignore: deprecated_member_use
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        // ignore: deprecated_member_use
        allowMultiple: false,
      );

      if (result != null &&
          (result.files.single.path != null ||
              // ignore: deprecated_member_use
              (kIsWeb && result.files.single.bytes != null))) {
        setState(() => _isLoading = true);

        Uint8List fileBytes;
        if (kIsWeb) {
          // ignore: deprecated_member_use
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
            AppSweetAlert.success(
              context,
              'Foto profil berhasil diperbarui.',
              title: 'Foto Diperbarui',
            );
          } else {
            AppSweetAlert.error(
              context,
              response.message ?? 'Gagal mengupload foto profil.',
              title: 'Upload Gagal',
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSweetAlert.error(
          context,
          'Terjadi kesalahan: $e',
          title: 'Error',
        );
      }
    }
  }

  void _handleUpdateProfile() async {
    if (_profileFormKey.currentState != null && !_profileFormKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    final result = await ProfileService.updateProfile(
      userId: _currentUser.id ?? '',
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result.success == true) {
        if (result.user != null) {
          setState(() {
            _currentUser = result.user!;
            _nameController.text = result.user!.name;
            _phoneController.text = result.user!.phone ?? '';
            _usernameController.text = result.user!.username;
            _emailController.text = result.user!.email;
          });
          widget.onUserUpdated(result.user!);
        }
        AppSweetAlert.success(
          context,
          'Profil pengelola berhasil diperbarui.',
          title: 'Perubahan Disimpan',
        );
      } else {
        AppSweetAlert.error(
          context,
          result.message ?? 'Gagal memperbarui profil.',
          title: 'Gagal Menyimpan',
        );
      }
    }
  }

  Future<void> _handleSaveSchoolProfile() async {
    setState(() => _isSavingSchool = true);

    try {
      final title = _schoolNameController.text.trim().isNotEmpty
          ? _schoolNameController.text.trim()
          : _currentUser.name;
      final phone = _schoolPhoneController.text.trim();
      final metadata = {
        'npsn': _npsnController.text.trim(),
        'institution_type': _institutionTypeController.text.trim(),
        'accreditation': _accreditationController.text.trim(),
        'permit_number': _permitNumberController.text.trim(),
        'headmaster_name': _headmasterNameController.text.trim(),
        'headmaster_nip': _headmasterNipController.text.trim(),
        'official_phone': phone,
        'official_email': _schoolEmailController.text.trim(),
        'website': _websiteController.text.trim(),
        'city': _cityController.text.trim(),
        'address': _addressController.text.trim(),
      };

      Map<String, dynamic> res;
      if (_schoolResourceId != null) {
        res = await ApiService.put('institution/resources/$_schoolResourceId', {
          'resource_type': 'profile',
          'title': title,
          'description': _descriptionController.text.trim(),
          'status': 'published',
          'metadata': metadata,
        });
      } else {
        res = await ApiService.post('institution/resources', {
          'resource_type': 'profile',
          'title': title,
          'description': _descriptionController.text.trim(),
          'status': 'published',
          'metadata': metadata,
        });
        if (res['status'] == true && res['data'] is Map && res['data']['id'] != null) {
          _schoolResourceId = res['data']['id'].toString();
        }
      }

      if (res['status'] != true) {
        if (mounted) {
          setState(() => _isSavingSchool = false);
          AppSweetAlert.error(
            context,
            AppErrors.messageFromResult(
              res,
              fallback: 'Gagal menyimpan data profil institusi.',
            ),
            title: 'Gagal Menyimpan',
          );
        }
        return;
      }

      // Sync nama & telepon ke user utama agar seluruh UI (sidebar, header) ikut terbarui
      final userUpdate = await ProfileService.updateProfile(
        userId: _currentUser.id ?? '',
        name: title,
        phone: phone,
      );

      if (mounted) {
        setState(() {
          _isSavingSchool = false;
          if (userUpdate.user != null) {
            _currentUser = userUpdate.user!;
            _nameController.text = userUpdate.user!.name;
            _phoneController.text = userUpdate.user!.phone ?? '';
            widget.onUserUpdated(userUpdate.user!);
          }
        });

        if (!userUpdate.success) {
          AppSweetAlert.warning(
            context,
            userUpdate.message ?? 'Profil institusi tersimpan, namun sinkronisasi akun PIC gagal.',
            title: 'Sinkronisasi Akun Terkendala',
          );
          return;
        }

        AppSweetAlert.success(
          context,
          'Data legalitas, nomor pokok institusi, dan profil berhasil diperbarui.',
          title: 'Profil Institusi Disimpan',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingSchool = false);
        AppSweetAlert.error(
          context,
          'Terjadi kesalahan saat menyimpan profil institusi: $e',
          title: 'Gagal Menyimpan',
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
        automaticallyImplyLeading: MediaQuery.of(context).size.width <= 900,
        toolbarHeight: 75,
        title: Text(
          _isSchool
              ? (_schoolProfileTab == 1 ? 'Profil Institusi' : 'Profil Akun (PIC)')
              : (_isGovernment ? 'Profil Instansi & Kedinasan' : 'Profil Pengguna'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isSchool)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
              child: OutlinedButton.icon(
                onPressed: _openPublicProfilePreview,
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Lihat Profil Publik'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1),
                  side: const BorderSide(color: Color(0xFF6366F1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
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
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 32 : 16,
                    24,
                    isDesktop ? 32 : 16,
                    isDesktop ? 110 : 16,
                  ),
                  child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppBreadcrumbs(
                            items: _currentUser.isAdmin
                                ? [
                                    BreadcrumbItem(
                                      label: 'Dasbor Admin',
                                      icon: Icons.admin_panel_settings_rounded,
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
                                    const BreadcrumbItem(
                                      label: 'Profil Saya',
                                      icon: Icons.person_rounded,
                                    ),
                                  ]
                                : [
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
                                    BreadcrumbItem(
                                      label: _isSchool
                                          ? (_schoolProfileTab == 1 ? 'Profil Institusi' : 'Profil Akun (PIC)')
                                          : (_isGovernment
                                              ? 'Profil Instansi'
                                              : 'Profil Saya'),
                                      icon: _isSchool
                                          ? (_schoolProfileTab == 1 ? Icons.account_balance_rounded : Icons.person_rounded)
                                          : (_isGovernment
                                              ? Icons.account_balance_rounded
                                              : Icons.person_rounded),
                                    ),
                                  ],
                          ),
                          const SizedBox(height: 12),
                          if (_isSchool) ...[
                            _buildSchoolTabSelector(isDark),
                            const SizedBox(height: 16),
                          ],
                          isDesktop
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Left Column - Profile Card
                                    Expanded(
                                      flex: (_isSchool && _schoolProfileTab == 1) ? 5 : 1,
                                      child: (_isSchool && _schoolProfileTab == 1)
                                          ? _buildSchoolProfileCard(theme, isDark)
                                          : _buildProfileCard(theme, isDark),
                                    ),
                                    const SizedBox(width: 24),
                                    // Right Column - Form only
                                    Expanded(
                                      flex: (_isSchool && _schoolProfileTab == 1) ? 7 : 1,
                                      child: (_isSchool && _schoolProfileTab == 1)
                                          ? _buildSchoolProfileForm(theme, isDark)
                                          : _buildProfileForm(theme, isDark),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    (_isSchool && _schoolProfileTab == 1)
                                        ? _buildSchoolProfileCard(theme, isDark)
                                        : _buildProfileCard(theme, isDark),
                                    const SizedBox(height: 24),
                                    (_isSchool && _schoolProfileTab == 1)
                                        ? _buildSchoolProfileForm(theme, isDark)
                                        : _buildProfileForm(theme, isDark),
                                  ],
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
    );

    final isGovOrSchool = _isSchool ||
        _currentUser.isInstitution ||
        _isGovernment ||
        ((_currentUser.role == 'user' || _currentUser.role == 'creator') &&
            const [
              'government',
              'pemerintah',
              'instansi',
              'school',
              'education',
              'campus',
              'sekolah',
              'kampus',
              'institution',
              'institusi',
            ].contains(_currentUser.subRole?.toLowerCase().trim()));

    if (isDesktop && widget.showSidebar && !_currentUser.isAdmin) {
      return DesktopSidebarLayout(
        user: _currentUser,
        activeRoute: isGovOrSchool
            ? (_schoolProfileTab == 1 ? 'profil_instansi' : 'profil_akun')
            : 'pengaturan',
        onUserUpdated: (u) {
          setState(() => _currentUser = u);
          widget.onUserUpdated(u);
        },
        child: content,
      );
    }

    return content;
  }

  Widget _buildSchoolTabSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B38) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _schoolProfileTab = 0),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: _schoolProfileTab == 0
                      ? (isDark ? AppTheme.primaryPurple : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _schoolProfileTab == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 18,
                      color: _schoolProfileTab == 0
                          ? (isDark ? Colors.white : AppTheme.primaryPurple)
                          : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Profil Akun (PIC / Pengelola)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _schoolProfileTab == 0
                            ? (isDark ? Colors.white : AppTheme.primaryPurple)
                            : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _schoolProfileTab = 1),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: _schoolProfileTab == 1
                      ? (isDark ? const Color(0xFF6366F1) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _schoolProfileTab == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_balance_outlined,
                      size: 18,
                      color: _schoolProfileTab == 1
                          ? (isDark ? Colors.white : const Color(0xFF6366F1))
                          : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Profil Institusi (Publik)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _schoolProfileTab == 1
                            ? (isDark ? Colors.white : const Color(0xFF6366F1))
                            : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
                  : (_isSchool ? 'PENGELOLA INSTITUSI / PIC' : 'KLIEN / USER'),
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
            if (!_currentUser.isVerified && !_currentUser.isCreator && !_currentUser.isCorporate)
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
      child: Form(
        key: _profileFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isSchool ? 'Informasi Akun Pengelola (PIC)' : 'Informasi Pribadi',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (_isSchool) ...[
              const SizedBox(height: 4),
              Text(
                'Kelola nama PIC, nomor kontak pribadi, dan identitas akun login pengelola institusi.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Lengkap',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Nama lengkap wajib diisi';
                if (v.trim().length < 2) return 'Nama minimal 2 karakter';
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
                LengthLimitingTextInputFormatter(25),
              ],
              decoration: const InputDecoration(
                labelText: 'Nomor Telepon',
                hintText: '081234567890 atau +6281234567890',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: FormValidators.phone,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'username_pengguna',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Username wajib diisi';
                if (v.trim().length < 3) return 'Username minimal 3 karakter';
                if (!RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(v.trim())) {
                  return 'Username hanya boleh huruf, angka, titik, strip, dan underscore';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'nama@domain.com',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
                if (!RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(v.trim())) {
                  return 'Format email tidak valid (contoh: nama@domain.com)';
                }
                return null;
              },
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
      ),
    );
  }

  // ── School Profile Left Card ───────────────────────────────────────────────

  Widget _buildSchoolProfileCard(ThemeData theme, bool isDark) {
    final schoolName = _schoolNameController.text.trim().isNotEmpty
        ? _schoolNameController.text.trim()
        : _currentUser.name;
    final npsn = _npsnController.text.trim().isNotEmpty ? _npsnController.text.trim() : '-';
    final akreditasi = _accreditationController.text.trim().isNotEmpty
        ? _accreditationController.text.trim()
        : '-';
    final jenjang = _institutionTypeController.text.trim().isNotEmpty
        ? _institutionTypeController.text.trim()
        : ((_currentUser.subRole != null && _currentUser.subRole!.isNotEmpty)
            ? _currentUser.subRole!
            : 'Institusi Pendidikan');

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E1B4B).withValues(alpha: 0.6),
                  const Color(0xFF1E293B).withValues(alpha: 0.8),
                ]
              : [
                  const Color(0xFFEEF2FF),
                  Colors.white,
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF4338CA).withValues(alpha: 0.4) : const Color(0xFFC7D2FE),
          width: 1.5,
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
          // Logo Sekolah / Institusi
          GestureDetector(
            onTap: _pickAndUploadAvatar,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 54,
                    backgroundColor: isDark ? const Color(0xFF312E81) : const Color(0xFFE0E7FF),
                    backgroundImage: _currentUser.avatarUrl != null &&
                            _currentUser.avatarUrl!.isNotEmpty
                        ? NetworkImage(
                            ApiService.resolveAssetUrl(_currentUser.avatarUrl!),
                          )
                        : null,
                    child: _currentUser.avatarUrl == null ||
                            _currentUser.avatarUrl!.isEmpty
                        ? const Icon(
                            Icons.school_rounded,
                            size: 52,
                            color: Color(0xFF4F46E5),
                          )
                        : null,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.scaffoldBackgroundColor,
                        width: 2.5,
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
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            schoolName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.3),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '@${_currentUser.username}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            jenjang,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6366F1),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          // Badge Role
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4338CA), Color(0xFF6366F1)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.school_outlined, size: 14, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'INSTITUSI PENDIDIKAN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Official Verification Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 15),
                SizedBox(width: 6),
                Text(
                  'Terverifikasi',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          // 3 Academic KPI Columns
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.indigo.shade50,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSchoolStat('NPSN / Kode PT', npsn, isDark),
                Container(height: 36, width: 1, color: isDark ? Colors.white12 : Colors.grey.shade300),
                _buildSchoolStat('Akreditasi', akreditasi.split(' ').first, isDark),
                Container(height: 36, width: 1, color: isDark ? Colors.white12 : Colors.grey.shade300),
                _buildSchoolStat('Status', 'Aktif', isDark),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Quick details snippet
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900.withValues(alpha: 0.4) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_pin_circle_outlined, size: 15, color: Color(0xFF6366F1)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _headmasterNameController.text.isNotEmpty
                            ? _headmasterNameController.text
                            : 'Pimpinan Institusi Terdaftar',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.pin_drop_outlined, size: 15, color: Color(0xFF6366F1)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _cityController.text.isNotEmpty
                            ? _cityController.text
                            : 'Kampus Budaya Vokasi Terpadu',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openPublicProfilePreview,
              icon: const Icon(Icons.visibility_outlined, size: 16),
              label: const Text('Lihat Tampilan Profil Publik'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6366F1),
                side: const BorderSide(color: Color(0xFF6366F1)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolStat(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4F46E5),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // ── School Profile Right Form ──────────────────────────────────────────────

  Widget _buildSchoolProfileForm(ThemeData theme, bool isDark) {
    const primary = Color(0xFF4F46E5);

    return Container(
      padding: const EdgeInsets.all(28),
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
          // Form Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance_rounded, color: primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informasi Legalitas & Profil Institusi',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Kelola data legalitas, nomor pokok institusi (NPSN / Kode PT), akreditasi, pimpinan, dan narahubung resmi institusi.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),

          // ── SEKSI 1: IDENTITAS & LEGALITAS ────────────────────────────────
          _buildFormSectionHeader('1. IDENTITAS & LEGALITAS PENDIDIKAN', Icons.verified_outlined, isDark),
          const SizedBox(height: 14),
          TextFormField(
            controller: _schoolNameController,
            decoration: const InputDecoration(
              labelText: 'Nama Resmi Institusi Pendidikan *',
              hintText: 'Contoh: SMK Negeri 1 Kreasi / Institut Seni & Rekayasa Kreatif',
              prefixIcon: Icon(Icons.school_outlined),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 550;
              return isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _npsnController,
                            keyboardType: TextInputType.text,
                            decoration: const InputDecoration(
                              labelText: 'Nomor Pokok / Kode Institusi (NPSN / Kode PT) *',
                              hintText: 'NPSN untuk sekolah atau Kode PT untuk kampus (misal: 20401829 / 001001)',
                              prefixIcon: Icon(Icons.pin_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _institutionTypeController,
                            decoration: const InputDecoration(
                              labelText: 'Jenjang / Tipe Institusi *',
                              hintText: 'SMK / Vokasi / Institut / Universitas',
                              prefixIcon: Icon(Icons.category_outlined),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        TextFormField(
                          controller: _npsnController,
                          keyboardType: TextInputType.text,
                          decoration: const InputDecoration(
                            labelText: 'Nomor Pokok / Kode Institusi (NPSN / Kode PT) *',
                            hintText: 'NPSN untuk sekolah atau Kode PT untuk kampus (misal: 20401829 / 001001)',
                            prefixIcon: Icon(Icons.pin_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _institutionTypeController,
                          decoration: const InputDecoration(
                            labelText: 'Jenjang / Tipe Institusi *',
                            hintText: 'SMK / Vokasi / Institut / Universitas',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                        ),
                      ],
                    );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 550;
              return isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _accreditationController,
                            decoration: const InputDecoration(
                              labelText: 'Status Akreditasi *',
                              hintText: 'A (Unggul) - BAN-PT',
                              prefixIcon: Icon(Icons.workspace_premium_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _permitNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Nomor SK Pendirian / Izin Operasional',
                              hintText: 'Contoh: 842/E/O/2021',
                              prefixIcon: Icon(Icons.assignment_outlined),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        TextFormField(
                          controller: _accreditationController,
                          decoration: const InputDecoration(
                            labelText: 'Status Akreditasi *',
                            hintText: 'A (Unggul) - BAN-PT',
                            prefixIcon: Icon(Icons.workspace_premium_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _permitNumberController,
                          decoration: const InputDecoration(
                            labelText: 'Nomor SK Pendirian / Izin Operasional',
                            hintText: 'Contoh: 842/E/O/2021',
                            prefixIcon: Icon(Icons.assignment_outlined),
                          ),
                        ),
                      ],
                    );
            },
          ),
          const SizedBox(height: 24),

          // ── SEKSI 2: PIMPINAN & NARAHUBUNG ──────────────────────────────
          _buildFormSectionHeader('2. PIMPINAN & NARAHUBUNG RESMI', Icons.person_pin_outlined, isDark),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 550;
              return isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _headmasterNameController,
                            decoration: const InputDecoration(
                              labelText: 'Nama Pimpinan Institusi (Rektor / Kepala Sekolah / Direktur) *',
                              hintText: 'Nama lengkap pimpinan beserta gelar',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _headmasterNipController,
                            decoration: const InputDecoration(
                              labelText: 'NIP / NIDN / Identitas Pimpinan',
                              hintText: 'NIP untuk ASN atau NIDN/NIK Pimpinan',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        TextFormField(
                          controller: _headmasterNameController,
                          decoration: const InputDecoration(
                            labelText: 'Nama Pimpinan Institusi (Rektor / Kepala Sekolah / Direktur) *',
                            hintText: 'Nama lengkap pimpinan beserta gelar',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _headmasterNipController,
                          decoration: const InputDecoration(
                            labelText: 'NIP / NIDN / Identitas Pimpinan',
                            hintText: 'NIP untuk ASN atau NIDN/NIK Pimpinan',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                      ],
                    );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 550;
              return isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _schoolPhoneController,
                            decoration: const InputDecoration(
                              labelText: 'Telepon Resmi Institusi / Narahubung *',
                              hintText: '(021) 8849-201',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _schoolEmailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email Resmi Institusi *',
                              hintText: 'kemitraan@kampus.ac.id',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        TextFormField(
                          controller: _schoolPhoneController,
                          decoration: const InputDecoration(
                            labelText: 'Telepon Resmi Institusi / Narahubung *',
                            hintText: '(021) 8849-201',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _schoolEmailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email Resmi Institusi *',
                            hintText: 'kemitraan@kampus.ac.id',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                      ],
                    );
            },
          ),
          const SizedBox(height: 24),

          // ── SEKSI 3: LOKASI & DESKRIPSI ───────────────────────────────────
          _buildFormSectionHeader('3. LOKASI & PROFIL INSTITUSI', Icons.place_outlined, isDark),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 550;
              return isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _websiteController,
                            decoration: const InputDecoration(
                              labelText: 'Website Resmi Institusi',
                              hintText: 'https://institusi.ac.id',
                              prefixIcon: Icon(Icons.language_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _cityController,
                            decoration: const InputDecoration(
                              labelText: 'Kota / Kabupaten & Provinsi',
                              hintText: 'Jakarta Selatan, DKI Jakarta',
                              prefixIcon: Icon(Icons.location_city_outlined),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        TextFormField(
                          controller: _websiteController,
                          decoration: const InputDecoration(
                            labelText: 'Website Resmi Institusi',
                            hintText: 'https://institusi.ac.id',
                            prefixIcon: Icon(Icons.language_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _cityController,
                          decoration: const InputDecoration(
                            labelText: 'Kota / Kabupaten & Provinsi',
                            hintText: 'Jakarta Selatan, DKI Jakarta',
                            prefixIcon: Icon(Icons.location_city_outlined),
                          ),
                        ),
                      ],
                    );
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Alamat Lengkap Institusi / Kampus',
              hintText: 'Jl. Pendidikan Kreatif No. 45, Kampus Budaya Vokasi Terpadu',
              prefixIcon: Icon(Icons.map_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Visi & Profil Singkat Institusi',
              hintText: 'Visi, misi, dan keunggulan program pendidikan/vokasi institusi...',
              prefixIcon: Icon(Icons.description_outlined),
            ),
          ),
          const SizedBox(height: 24),

          // ── KARTU AKUN LOGIN TERKAIT ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900.withValues(alpha: 0.5) : Colors.indigo.shade50.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.indigo.shade100,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.security_outlined, size: 20, color: Color(0xFF4F46E5)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Akun Pengguna: @${_currentUser.username} (${_currentUser.email})',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Untuk pengaturan kata sandi atau keamanan akun, silakan akses menu Pengaturan Akun.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── TOMBOL SIMPAN ────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSavingSchool ? null : _handleSaveSchoolProfile,
              icon: _isSavingSchool
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 20),
              label: Text(
                _isSavingSchool ? 'Menyimpan...' : 'Simpan Profil Institusi',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF4F46E5)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: isDark ? Colors.indigo.shade200 : Colors.indigo.shade800,
          ),
        ),
      ],
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
