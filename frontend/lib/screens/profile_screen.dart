import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../services/profile_service.dart';
import '../widgets/creator_application_card.dart';
import '../utils/form_validators.dart';

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

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.user.name;
    _phoneController.text = widget.user.phone ?? '';
    _loadProfileDetails();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    final result = await ProfileService.getProfile(widget.user.id);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _latestApplication = result['application'];
          widget.onUserUpdated(result['user']);
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

      if (result != null && (result.files.single.path != null || (kIsWeb && result.files.single.bytes != null))) {
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
          userId: widget.user.id,
          avatarUrl: dataUrl,
        );

        if (mounted) {
          setState(() => _isLoading = false);
          if (response['success'] == true) {
            widget.onUserUpdated(response['user']);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Foto profil berhasil diperbarui.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response['message'] ?? 'Gagal mengupload foto profil.'),
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
      userId: widget.user.id,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        widget.onUserUpdated(result['user']);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil berhasil diperbarui.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal memperbarui profil.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _handleApplyCreator({
    required String category,
    required String skills,
    required String portfolio,
    required String experience,
    required String nik,
    required String fullNameKtp,
    required String addressKtp,
    required String ktpPhotoBase64,
    required String selfiePhotoBase64,
    required String birthPlace,
    required String birthDate,
  }) async {
    setState(() => _isLoading = true);
    final result = await ProfileService.applyAsCreator(
      userId: widget.user.id,
      pihakCategory: category,
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
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        _loadProfileDetails();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pengajuan Kreator berhasil dikirim! Menunggu verifikasi admin.',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green.shade700,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal memproses pengajuan.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
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
          ? const Center(child: CircularProgressIndicator())
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
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 110),
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
                                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                      width: 4,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 48,
                                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                    backgroundImage: widget.user.avatarUrl != null && widget.user.avatarUrl!.isNotEmpty
                                        ? NetworkImage(widget.user.avatarUrl!)
                                        : null,
                                    child: widget.user.avatarUrl == null || widget.user.avatarUrl!.isEmpty
                                        ? Icon(
                                            widget.user.role == 'creator'
                                                ? Icons.verified_user_rounded
                                                : Icons.account_circle_outlined,
                                            size: 50,
                                            color: theme.colorScheme.primary,
                                          )
                                        : null,
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: theme.scaffoldBackgroundColor,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.15),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
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
                          const SizedBox(height: 16),
                          Text(
                            widget.user.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '@${widget.user.username}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: widget.user.isAdmin
                                  ? (isDark ? Colors.red.shade900.withValues(alpha: 0.2) : Colors.red.shade50)
                                  : (widget.user.role == 'creator'
                                      ? (isDark ? Colors.green.shade900.withValues(alpha: 0.2) : Colors.green.shade50)
                                      : (isDark ? Colors.grey.shade900 : Colors.grey.shade100)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: widget.user.isAdmin
                                    ? (isDark ? Colors.red.shade800.withValues(alpha: 0.4) : Colors.red.shade200)
                                    : (widget.user.role == 'creator'
                                        ? (isDark ? Colors.green.shade800.withValues(alpha: 0.4) : Colors.green.shade200)
                                        : (isDark ? Colors.grey.shade800 : Colors.grey.shade300)),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              widget.user.isAdmin
                                  ? 'ADMINISTRATOR'
                                  : (widget.user.role == 'creator' ? 'CREATOR / MITRA' : 'KLIEN / USER'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: widget.user.isAdmin
                                    ? (isDark ? Colors.red.shade300 : Colors.red.shade800)
                                    : (widget.user.role == 'creator'
                                        ? (isDark ? Colors.green.shade300 : Colors.green.shade800)
                                        : (isDark ? Colors.grey.shade400 : Colors.grey.shade700)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Profile Update Form
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.cardBg : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color: isDark
                                    ? AppTheme.inputBorder
                                    : Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Informasi Pribadi',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Nama Lengkap',
                                    prefixIcon: Icon(Icons.person_outline_rounded),
                                  ),
                                ),
                                const SizedBox(height: 18),
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
                                const SizedBox(height: 18),
                                TextFormField(
                                  initialValue: widget.user.username,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    labelText: 'Username',
                                    filled: true,
                                    fillColor: isDark
                                        ? Colors.grey.shade900.withValues(alpha: 0.5)
                                        : Colors.grey.shade100,
                                    prefixIcon: const Icon(
                                      Icons.alternate_email_rounded,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                TextFormField(
                                  initialValue: widget.user.email,
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
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _handleUpdateProfile,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: theme.colorScheme.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                    ),
                                    child: const Text('Simpan Perubahan'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          if (!widget.user.isAdmin) ...[
                            // Creator Application Card
                            CreatorApplicationCard(
                              user: widget.user,
                              application: _latestApplication,
                              onApply: _handleApplyCreator,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
