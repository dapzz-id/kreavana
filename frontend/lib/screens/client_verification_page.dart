import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../services/verification_service.dart';
import '../utils/app_errors.dart';
import '../widgets/app_breadcrumbs.dart';
import '../widgets/ktp_camera_view.dart';
import '../widgets/desktop_sidebar_layout.dart';
import '../features/auth/services/auth_service.dart';
import 'main_navigation.dart';

class ClientVerificationPage extends StatefulWidget {
  final UserModel? user;
  final VoidCallback? onSuccess;

  const ClientVerificationPage({
    super.key,
    this.user,
    this.onSuccess,
  });

  @override
  State<ClientVerificationPage> createState() => _ClientVerificationPageState();
}

class _ClientVerificationPageState extends State<ClientVerificationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nikController = TextEditingController();
  final _nameController = TextEditingController();
  final _birthPlaceController = TextEditingController();
  final _addressController = TextEditingController();

  DateTime? _selectedBirthDate;

  // KTP
  PlatformFile? _ktpFile;
  String? _ktpBase64;

  // Selfie
  PlatformFile? _selfieFile;
  String? _selfieBase64;

  UserModel? _currentUser;
  bool _isSubmitting = false;
  int _currentStep = 0; // 0 = Data KTP, 1 = Upload Foto, 2 = Review

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    if (_currentUser == null) {
      AuthService.getCurrentUser().then((u) {
        if (mounted && u != null) {
          setState(() => _currentUser = u);
        }
      });
    }
  }

  @override
  void dispose() {
    _nikController.dispose();
    _nameController.dispose();
    _birthPlaceController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickKtp() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes != null) {
        final b64 =
            'data:image/${file.extension ?? 'jpg'};base64,${base64Encode(file.bytes!)}';
        setState(() {
          _ktpFile = file;
          _ktpBase64 = b64;
        });
      }
    }
  }

  Future<void> _pickSelfie() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes != null) {
        final b64 =
            'data:image/${file.extension ?? 'jpg'};base64,${base64Encode(file.bytes!)}';
        setState(() {
          _selfieFile = file;
          _selfieBase64 = b64;
        });
      }
    }
  }

  Future<void> _openKtpCamera() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KtpCameraView(
          onImageCaptured: (String imagePath) async {
            Navigator.of(context).pop();
            if (!kIsWeb) {
              try {
                final bytes = await io.File(imagePath).readAsBytes();
                final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                if (mounted) {
                  setState(() {
                    _ktpBase64 = b64;
                    _ktpFile = null;
                  });
                }
              } catch (_) {}
            }
          },
          onCancel: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 17, now.month, now.day),
    );
    if (picked != null) {
      setState(() => _selectedBirthDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_ktpBase64 == null) {
      AppSnackbar.error(context, 'Foto KTP wajib diupload.');
      return;
    }

    setState(() => _isSubmitting = true);

    final res = await VerificationService.applyClientVerification(
      nik: _nikController.text.trim(),
      fullNameKtp: _nameController.text.trim(),
      birthPlace: _birthPlaceController.text.trim().isNotEmpty
          ? _birthPlaceController.text.trim()
          : null,
      birthDate: _selectedBirthDate != null
          ? '${_selectedBirthDate!.year}-${_selectedBirthDate!.month.toString().padLeft(2, '0')}-${_selectedBirthDate!.day.toString().padLeft(2, '0')}'
          : null,
      addressKtp: _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : null,
      ktpPhotoBase64: _ktpBase64!,
      selfiePhotoBase64: _selfieBase64,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res['status'] == true) {
      AppSnackbar.success(
        context,
        'Pengajuan verifikasi berhasil dikirim! Tim kami akan meninjau dalam 1-3 hari kerja.',
      );
      widget.onSuccess?.call();
      Navigator.pop(context, true);
    } else {
      AppSnackbar.error(
        context,
        res['message']?.toString() ?? 'Gagal mengirim pengajuan verifikasi.',
      );
    }
  }

  bool get _isAlreadyVerified {
    final u = _currentUser ?? widget.user;
    return u?.isVerified == true && u?.verificationType == 'client';
  }

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
          'Verifikasi Identitas',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isAlreadyVerified
          ? _buildVerifiedState(isDark)
          : _buildForm(isDark, isDesktop),
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

  Widget _buildVerifiedState(bool isDark) {
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
                Icons.verified_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Identitas Sudah Terverifikasi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Akun Anda telah memiliki badge verifikasi identitas (centang biru). '
              'Anda dapat membuat proyek dan menggunakan semua fitur klien.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF3B82F6),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Klien Terverifikasi',
                    style: const TextStyle(
                      color: Color(0xFF3B82F6),
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

  Widget _buildForm(bool isDark, bool isDesktop) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 40 : 16,
        16,
        isDesktop ? 40 : 16,
        120,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Form(
            key: _formKey,
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
                    BreadcrumbItem(
                      label: 'Pengaturan',
                      icon: Icons.settings_rounded,
                      onTap: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else if (widget.user != null) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MainNavigation(
                                initialUser: widget.user!,
                                initialIndex: 8,
                              ),
                            ),
                            (r) => false,
                          );
                        }
                      },
                    ),
                    const BreadcrumbItem(
                      label: 'Verifikasi Identitas',
                      icon: Icons.badge_rounded,
                    ),
                  ],
                ),
                _InfoBanner(isDark: isDark),
                const SizedBox(height: 24),
                _StepIndicator(currentStep: _currentStep, isDark: isDark),
                const SizedBox(height: 28),

                if (_currentStep == 0) ...[
                  _SectionCard(
                    isDark: isDark,
                    title: 'Data KTP',
                    icon: Icons.badge_outlined,
                    children: [
                      _buildField(
                        controller: _nikController,
                        label: 'NIK (16 digit)',
                        hint: 'Nomor Induk Kependudukan',
                        isDark: isDark,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'NIK wajib diisi';
                          if (v.length != 16) return 'NIK harus 16 digit';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _nameController,
                        label: 'Nama Lengkap (sesuai KTP)',
                        hint: 'Nama seperti di KTP',
                        isDark: isDark,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Nama wajib diisi';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _birthPlaceController,
                        label: 'Tempat Lahir',
                        hint: 'Kota/Kabupaten tempat lahir',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: _pickBirthDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E1B30)
                                : const Color(0xFFF8F9FF),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSM),
                            border: Border.all(
                              color: isDark
                                  ? AppTheme.inputBorder
                                  : AppTheme.dividerLight,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                                color: isDark
                                    ? AppTheme.textMuted
                                    : AppTheme.textMutedLight,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _selectedBirthDate != null
                                      ? '${_selectedBirthDate!.day.toString().padLeft(2, '0')}/${_selectedBirthDate!.month.toString().padLeft(2, '0')}/${_selectedBirthDate!.year}'
                                      : 'Tanggal Lahir',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _selectedBirthDate != null
                                        ? (isDark
                                            ? Colors.white
                                            : const Color(0xFF1E293B))
                                        : (isDark
                                            ? AppTheme.textMuted
                                            : AppTheme.textMutedLight),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _addressController,
                        label: 'Alamat (sesuai KTP)',
                        hint: 'Alamat lengkap seperti di KTP',
                        isDark: isDark,
                        maxLines: 3,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildNavButtons(
                    isDark: isDark,
                    onNext: () {
                      if (_formKey.currentState!.validate()) {
                        setState(() => _currentStep = 1);
                      }
                    },
                  ),
                ],

                if (_currentStep == 1) ...[
                  _SectionCard(
                    isDark: isDark,
                    title: 'Foto KTP',
                    icon: Icons.photo_camera_outlined,
                    children: [
                      Text(
                        'Upload foto KTP Anda yang jelas dan tidak buram. Pastikan seluruh bagian KTP terlihat.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppTheme.textMuted
                              : AppTheme.textMutedLight,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _PhotoUploadTile(
                        label: 'Foto KTP',
                        sublabel: 'JPG, JPEG, atau PNG (maks. 5MB)',
                        icon: Icons.badge_outlined,
                        hasFile: _ktpBase64 != null,
                        fileName: _ktpFile?.name,
                        isDark: isDark,
                        onPickFile: _pickKtp,
                        onOpenCamera: _openKtpCamera,
                        previewBase64: _ktpBase64,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SectionCard(
                    isDark: isDark,
                    title: 'Selfie dengan KTP',
                    icon: Icons.face_outlined,
                    children: [
                      Text(
                        'Upload foto selfie sambil memegang KTP Anda. Pastikan wajah dan KTP terlihat jelas.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppTheme.textMuted
                              : AppTheme.textMutedLight,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _PhotoUploadTile(
                        label: 'Selfie dengan KTP',
                        sublabel: 'JPG, JPEG, atau PNG (maks. 5MB)',
                        icon: Icons.face_outlined,
                        hasFile: _selfieBase64 != null,
                        fileName: _selfieFile?.name,
                        isDark: isDark,
                        onPickFile: _pickSelfie,
                        previewBase64: _selfieBase64,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildNavButtons(
                    isDark: isDark,
                    showBack: true,
                    onBack: () => setState(() => _currentStep = 0),
                    onNext: () {
                      if (_ktpBase64 == null) {
                        AppSnackbar.error(context, 'Foto KTP wajib diupload.');
                        return;
                      }
                      setState(() => _currentStep = 2);
                    },
                  ),
                ],

                if (_currentStep == 2) ...[
                  _SectionCard(
                    isDark: isDark,
                    title: 'Konfirmasi Data',
                    icon: Icons.checklist_outlined,
                    children: [
                      _ReviewRow(
                        label: 'NIK',
                        value: _nikController.text,
                        isDark: isDark,
                      ),
                      _ReviewRow(
                        label: 'Nama',
                        value: _nameController.text,
                        isDark: isDark,
                      ),
                      if (_birthPlaceController.text.isNotEmpty)
                        _ReviewRow(
                          label: 'Tempat Lahir',
                          value: _birthPlaceController.text,
                          isDark: isDark,
                        ),
                      if (_selectedBirthDate != null)
                        _ReviewRow(
                          label: 'Tanggal Lahir',
                          value:
                              '${_selectedBirthDate!.day.toString().padLeft(2, '0')}/'
                              '${_selectedBirthDate!.month.toString().padLeft(2, '0')}/'
                              '${_selectedBirthDate!.year}',
                          isDark: isDark,
                        ),
                      if (_addressController.text.isNotEmpty)
                        _ReviewRow(
                          label: 'Alamat KTP',
                          value: _addressController.text,
                          isDark: isDark,
                        ),
                      const SizedBox(height: 8),
                      Divider(
                        color: isDark
                            ? AppTheme.inputBorder
                            : AppTheme.dividerLight,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _StatusChip(
                            label: 'Foto KTP',
                            ok: _ktpBase64 != null,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _StatusChip(
                            label: 'Selfie',
                            ok: _selfieBase64 != null,
                            isDark: isDark,
                            optional: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                      border: Border.all(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFF3B82F6),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Dengan mengirim formulir ini, Anda menyetujui bahwa data yang diberikan adalah benar. '
                            'Verifikasi akan diproses dalam 1-3 hari kerja.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppTheme.textMuted
                                  : const Color(0xFF1E40AF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildNavButtons(
                    isDark: isDark,
                    showBack: true,
                    onBack: () => setState(() => _currentStep = 1),
                    nextLabel: 'Kirim Pengajuan',
                    isLoading: _isSubmitting,
                    onNext: _submit,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? Colors.white24 : Colors.grey.shade400,
              fontSize: 13,
            ),
            isDense: true,
            filled: true,
            fillColor:
                isDark ? const Color(0xFF1E1B30) : const Color(0xFFF8F9FF),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              borderSide: BorderSide(
                color: isDark ? AppTheme.inputBorder : AppTheme.dividerLight,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              borderSide: BorderSide(
                color: isDark ? AppTheme.inputBorder : AppTheme.dividerLight,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              borderSide: const BorderSide(
                color: AppTheme.primaryPurple,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavButtons({
    required bool isDark,
    bool showBack = false,
    VoidCallback? onBack,
    required VoidCallback onNext,
    String nextLabel = 'Lanjut',
    bool isLoading = false,
  }) {
    return Row(
      children: [
        if (showBack) ...[
          OutlinedButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Kembali'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
              side: BorderSide(
                color: isDark ? AppTheme.inputBorder : AppTheme.dividerLight,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: ElevatedButton(
            onPressed: isLoading ? null : onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        nextLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (nextLabel == 'Lanjut') ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward, size: 16),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final bool isDark;
  const _InfoBanner({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E3A5F), const Color(0xFF1A2744)]
              : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: Color(0xFF3B82F6),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verifikasi Identitas Klien',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF1E40AF),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Verifikasi diperlukan untuk membuat proyek. Anda akan mendapatkan badge centang biru. '
                  'Proses ini tidak mengubah akun Anda menjadi Kreator.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark
                        ? const Color(0xFF93C5FD)
                        : const Color(0xFF1D4ED8),
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

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final bool isDark;

  const _StepIndicator({required this.currentStep, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final steps = ['Data KTP', 'Upload Foto', 'Konfirmasi'];
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final stepIndex = i ~/ 2;
          final isDone = stepIndex < currentStep;
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 24),
              color: isDone
                  ? AppTheme.primaryPurple
                  : (isDark ? Colors.white12 : Colors.grey.shade200),
            ),
          );
        }
        final idx = i ~/ 2;
        final isActive = idx == currentStep;
        final isDone = idx < currentStep;
        final color = isDone || isActive
            ? AppTheme.primaryPurple
            : (isDark ? Colors.white24 : Colors.grey.shade300);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone || isActive
                    ? AppTheme.primaryPurple
                    : Colors.transparent,
                border: Border.all(color: color, width: 2),
              ),
              child: Center(
                child: isDone
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 16,
                      )
                    : Text(
                        '${idx + 1}',
                        style: TextStyle(
                          color: isActive
                              ? Colors.white
                              : (isDark ? Colors.white38 : Colors.grey.shade400),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              steps[idx],
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.w400,
                color: isActive
                    ? AppTheme.primaryPurple
                    : (isDark ? Colors.white38 : Colors.grey.shade400),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final bool isDark;
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.isDark,
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : AppTheme.dividerLight,
        ),
        boxShadow: isDark ? null : AppTheme.cardShadowLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: AppTheme.primaryPurple, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? AppTheme.inputBorder : AppTheme.dividerLight,
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoUploadTile extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final bool hasFile;
  final String? fileName;
  final bool isDark;
  final VoidCallback onPickFile;
  final VoidCallback? onOpenCamera;
  final String? previewBase64;

  const _PhotoUploadTile({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.hasFile,
    this.fileName,
    required this.isDark,
    required this.onPickFile,
    this.onOpenCamera,
    this.previewBase64,
  });

  @override
  Widget build(BuildContext context) {
    final preview = previewBase64;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (preview != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            child: Image.memory(
              base64Decode(preview.contains(',') ? preview.split(',').last : preview),
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPickFile,
                icon: Icon(icon, size: 16),
                label: Text(hasFile ? 'Ganti File' : 'Pilih dari File'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  side: BorderSide(
                    color:
                        isDark ? AppTheme.inputBorder : AppTheme.dividerLight,
                  ),
                ),
              ),
            ),
            if (onOpenCamera != null) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onOpenCamera,
                icon: const Icon(Icons.camera_alt_outlined, size: 16),
                label: const Text('Kamera'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  side: BorderSide(
                    color:
                        isDark ? AppTheme.inputBorder : AppTheme.dividerLight,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (hasFile) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF22C55E),
                size: 14,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  fileName ?? label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF22C55E),
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 4),
        Text(
          sublabel,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white30 : Colors.grey.shade400,
          ),
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _ReviewRow({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool ok;
  final bool isDark;
  final bool optional;

  const _StatusChip({
    required this.label,
    required this.ok,
    required this.isDark,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = ok
        ? const Color(0xFF22C55E)
        : (optional ? const Color(0xFFF59E0B) : AppTheme.error);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok
                ? Icons.check_circle_outline
                : (optional ? Icons.info_outline : Icons.cancel_outlined),
            color: color,
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            '$label${ok ? ' \u2713' : (optional ? ' (opsional)' : ' \u2717')}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
