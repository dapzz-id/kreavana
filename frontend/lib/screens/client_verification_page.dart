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

class _HistoryRowData {
  final String label;
  final String value;
  const _HistoryRowData(this.label, this.value);
}

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

  bool _loadingStatus = true;
  VerificationStatusData? _statusData;
  bool _isReapplying = false;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _initData();
  }

  Future<void> _initData() async {
    if (_currentUser == null) {
      final u = await AuthService.getCurrentUser();
      if (mounted && u != null) {
        setState(() => _currentUser = u);
      }
    }
    await _loadStatus();
  }

  Future<void> _loadStatus() async {
    if (!mounted) return;
    setState(() => _loadingStatus = true);
    try {
      final status = await VerificationService.getStatus();
      if (mounted) {
        setState(() {
          _statusData = status;
          _loadingStatus = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingStatus = false);
      }
    }
  }

  CreatorApplication? get _pendingApp =>
      _statusData?.pendingApplication ??
      (_statusData?.latestApplication?.status == 'pending'
          ? _statusData?.latestApplication
          : null);

  CreatorApplication? get _latestApp => _statusData?.latestApplication;

  bool get _isCreator {
    final u = _currentUser ?? widget.user;
    if (u == null) return false;
    return u.isCreator || u.role == 'creator';
  }

  bool get _isVerified {
    final u = _currentUser ?? widget.user;
    final userIsClientVerified =
        u?.isVerified == true && u?.verificationType == 'client';
    final statusIsClientVerified =
        _statusData?.isVerified == true &&
        _statusData?.verificationType == 'client';
    final latestApproved = _statusData?.latestApplication?.status == 'approved' &&
        _statusData?.latestApplication?.type == 'client_verification';
    return userIsClientVerified || statusIsClientVerified || latestApproved;
  }

  bool get _hasPending {
    if (_isVerified) return false;
    if (_statusData?.hasPending == true) return true;
    if (_pendingApp != null) return true;
    return false;
  }

  bool get _isRejected {
    if (_hasPending || _isVerified) return false;
    return _latestApp != null && _latestApp!.status == 'rejected';
  }

  String _maskNik(String nik) {
    if (nik.length < 8) return nik;
    return '${nik.substring(0, 4)}********${nik.substring(nik.length - 4)}';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final months = [
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} WIB';
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildBreadcrumbs(BuildContext context) {
    return AppBreadcrumbs(
      items: [
        BreadcrumbItem(
          label: 'Beranda',
          icon: Icons.home_rounded,
          onTap: () {
            if (_currentUser != null || widget.user != null) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => MainNavigation(
                    initialUser: (_currentUser ?? widget.user)!,
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
            } else if (_currentUser != null || widget.user != null) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => MainNavigation(
                    initialUser: (_currentUser ?? widget.user)!,
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
    );
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

  Future<void> _openSelfieCamera() async {
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
                    _selfieBase64 = b64;
                    _selfieFile = null;
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
    if (_selfieBase64 == null) {
      AppSnackbar.error(context, 'Foto selfie sambil memegang KTP wajib diupload untuk membuktikan bahwa KTP adalah hak milik sah Anda.');
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
      await _loadStatus();
      if (mounted) {
        setState(() {
          _isReapplying = false;
        });
      }
    } else {
      AppSnackbar.error(
        context,
        res['message']?.toString() ?? 'Gagal mengirim pengajuan verifikasi.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    Widget body;
    if (_loadingStatus) {
      body = _buildLoadingState(isDark);
    } else if (_isCreator) {
      body = _buildCreatorNoticeState(isDark, isDesktop);
    } else if (_isVerified) {
      body = _buildVerifiedState(isDark, isDesktop);
    } else if (_hasPending) {
      body = _buildPendingState(isDark, isDesktop);
    } else if (_isRejected && !_isReapplying) {
      body = _buildRejectedState(isDark, isDesktop);
    } else {
      body = _buildForm(isDark, isDesktop);
    }

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
      body: body,
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

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Memeriksa status verifikasi...',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatorNoticeState(bool isDark, bool isDesktop) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 40 : 16,
        16,
        isDesktop ? 40 : 16,
        80,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBreadcrumbs(context),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                  boxShadow: isDark ? null : AppTheme.cardShadowLight,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Fitur Khusus Akun Klien',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Akun Anda saat ini terdaftar sebagai Kreator Kreavana. Fitur verifikasi KTP klien ini dinonaktifkan karena verifikasi identitas Anda telah dikelola secara terpisah melalui status kreator.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            color: Color(0xFF10B981),
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Kreator Aktif & Terverifikasi (Centang Hijau)',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Kembali ke Pengaturan'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: isDark ? AppTheme.inputBorder : AppTheme.dividerLight,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                          ),
                        ),
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerifiedState(bool isDark, bool isDesktop) {
    final app = _statusData?.latestApplication;
    final verifiedDate = _statusData?.verifiedAt ?? app?.appliedAt;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 40 : 16,
        16,
        isDesktop ? 40 : 16,
        80,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBreadcrumbs(context),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                  ),
                  boxShadow: isDark ? null : AppTheme.cardShadowLight,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.verified_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Identitas Sudah Terverifikasi',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Akun Klien Anda telah memiliki centang biru resmi dari Kreavana. Anda bebas membuat proyek dan menggunakan seluruh fasilitas klien.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            color: Color(0xFF3B82F6),
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Badge Centang Biru Aktif',
                            style: TextStyle(
                              color: Color(0xFF3B82F6),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    _buildHistoryDetailBox(
                      isDark: isDark,
                      statusBadge: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                            SizedBox(width: 4),
                            Text(
                              'Disetujui Admin',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                      items: [
                        if (app?.fullNameKtp != null || _currentUser?.name != null)
                          _HistoryRowData('Nama Lengkap (KTP)', app?.fullNameKtp ?? _currentUser?.name ?? '-'),
                        if (app?.nik != null)
                          _HistoryRowData('Nomor NIK', _maskNik(app!.nik!)),
                        if (verifiedDate != null)
                          _HistoryRowData('Tanggal Diverifikasi', _formatDate(verifiedDate)),
                      ],
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Kembali ke Pengaturan'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: isDark ? AppTheme.inputBorder : AppTheme.dividerLight,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                          ),
                        ),
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingState(bool isDark, bool isDesktop) {
    final app = _pendingApp ?? _latestApp;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 40 : 16,
        16,
        isDesktop ? 40 : 16,
        80,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBreadcrumbs(context),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                  ),
                  boxShadow: isDark ? null : AppTheme.cardShadowLight,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.hourglass_top_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Verifikasi Sedang Menunggu Tinjauan',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pengajuan verifikasi identitas KTP Anda telah diterima dan saat ini sedang menunggu peninjauan oleh tim Admin Kreavana.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFFF59E0B),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Anda tidak dapat mengajukan verifikasi baru selama pengajuan saat ini masih dalam proses peninjauan (biasanya 1-3 hari kerja). Notifikasi akan dikirimkan segera setelah peninjauan selesai.',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    _buildHistoryDetailBox(
                      isDark: isDark,
                      statusBadge: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule_rounded, size: 14, color: Color(0xFFF59E0B)),
                            SizedBox(width: 4),
                            Text(
                              'Menunggu Review Admin',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      items: [
                        if (app?.appliedAt != null)
                          _HistoryRowData('Waktu Pengajuan', _formatDate(app!.appliedAt)),
                        if (app?.fullNameKtp != null)
                          _HistoryRowData('Nama Lengkap (KTP)', app!.fullNameKtp!),
                        if (app?.nik != null)
                          _HistoryRowData('Nomor NIK', _maskNik(app!.nik!)),
                        if (app?.birthPlace != null || app?.birthDate != null)
                          _HistoryRowData(
                            'Tempat, Tanggal Lahir',
                            '${app?.birthPlace ?? ''}${app?.birthPlace != null && app?.birthDate != null ? ', ' : ''}${app?.birthDate ?? ''}',
                          ),
                        const _HistoryRowData(
                          'Dokumen Dilampirkan',
                          'Foto KTP & Foto Selfie Memegang KTP',
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Periksa Status'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color: isDark ? AppTheme.inputBorder : AppTheme.dividerLight,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                              ),
                            ),
                            onPressed: _loadStatus,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                              ),
                            ),
                            onPressed: () {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              }
                            },
                            child: const Text(
                              'Kembali',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRejectedState(bool isDark, bool isDesktop) {
    final app = _latestApp;
    final reason = app?.adminNote?.isNotEmpty == true
        ? app!.adminNote!
        : 'Dokumen KTP atau foto selfie tidak memenuhi persyaratan keaslian/kejelasan data.';

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 40 : 16,
        16,
        isDesktop ? 40 : 16,
        80,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBreadcrumbs(context),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                  ),
                  boxShadow: isDark ? null : AppTheme.cardShadowLight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.cancel_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Pengajuan Verifikasi Ditolak',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pengajuan verifikasi identitas KTP Anda sebelumnya belum disetujui oleh tim Admin Kreavana.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.report_problem_rounded,
                                color: Color(0xFFEF4444),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Alasan Penolakan dari Admin:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: isDark
                                      ? const Color(0xFFFCA5A5)
                                      : const Color(0xFFB91C1C),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            reason,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildHistoryDetailBox(
                      isDark: isDark,
                      statusBadge: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cancel_rounded, size: 14, color: Color(0xFFEF4444)),
                            SizedBox(width: 4),
                            Text(
                              'Ditolak',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ),
                      items: [
                        if (app?.appliedAt != null)
                          _HistoryRowData('Waktu Pengajuan', _formatDate(app!.appliedAt)),
                        if (app?.fullNameKtp != null)
                          _HistoryRowData('Nama Lengkap (KTP)', app!.fullNameKtp!),
                        if (app?.nik != null)
                          _HistoryRowData('Nomor NIK', _maskNik(app!.nik!)),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color: isDark ? AppTheme.inputBorder : AppTheme.dividerLight,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                              ),
                            ),
                            onPressed: () {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              }
                            },
                            child: const Text('Kembali'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text(
                              'Ajukan Ulang Verifikasi',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                              ),
                            ),
                            onPressed: () {
                              if (app != null) {
                                if (app.nik != null) _nikController.text = app.nik!;
                                if (app.fullNameKtp != null) _nameController.text = app.fullNameKtp!;
                                if (app.birthPlace != null) _birthPlaceController.text = app.birthPlace!;
                                if (app.addressKtp != null) _addressController.text = app.addressKtp!;
                                if (app.birthDate != null) {
                                  try {
                                    _selectedBirthDate = DateTime.parse(app.birthDate!);
                                  } catch (_) {}
                                }
                              }
                              setState(() {
                                _isReapplying = true;
                                _currentStep = 0;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryDetailBox({
    required bool isDark,
    required Widget statusBadge,
    required List<_HistoryRowData> items,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B30) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : AppTheme.dividerLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Riwayat Pengajuan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              statusBadge,
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: isDark ? AppTheme.inputBorder : AppTheme.dividerLight,
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
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
                _buildBreadcrumbs(context),
                if (_isReapplying) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                      border: Border.all(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.replay_rounded,
                          color: Color(0xFF8B5CF6),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Mode Pengajuan Ulang: Periksa kembali data Anda dan upload foto KTP serta selfie baru yang jelas sesuai instruksi.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: isDark ? Colors.white70 : const Color(0xFF4C1D95),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Batal pengajuan ulang',
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => setState(() => _isReapplying = false),
                        ),
                      ],
                    ),
                  ),
                ],
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
                    title: 'Selfie dengan KTP (Wajib)',
                    icon: Icons.face_outlined,
                    children: [
                      Text(
                        'Upload foto selfie sambil memegang KTP Anda. Hal ini wajib untuk membuktikan keaslian dan memastikan bahwa KTP tersebut adalah hak milik sah Anda.',
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
                        onOpenCamera: _openSelfieCamera,
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
                      if (_selfieBase64 == null) {
                        AppSnackbar.error(context, 'Foto selfie sambil memegang KTP wajib diupload untuk membuktikan kepemilikan KTP.');
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
                            optional: false,
                          ),
                          const SizedBox(width: 8),
                          _StatusChip(
                            label: 'Selfie + KTP',
                            ok: _selfieBase64 != null,
                            isDark: isDark,
                            optional: false,
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
