import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'ktp_camera_view.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../services/ktp_ocr_service_io.dart' as ktp_ocr;
import '../utils/form_validators.dart';
import '../utils/image_compressor.dart';

class CreatorApplicationCard extends StatefulWidget {
  final UserModel user;
  final CreatorApplication? application;
  final Function({
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
    bool reuseKtp,
    String? nibNumber,
    String? nibFileBase64,
  })
  onApply;

  const CreatorApplicationCard({
    super.key,
    required this.user,
    required this.application,
    required this.onApply,
  });

  @override
  State<CreatorApplicationCard> createState() => _CreatorApplicationCardState();
}

class _CreatorApplicationCardState extends State<CreatorApplicationCard> {
  final _ktpFormKey = GlobalKey<FormState>();
  final _profileFormKey = GlobalKey<FormState>();
  int _currentStep = 0;
  String _selectedCategory = 'institution';
  final _skillsController = TextEditingController();
  final _portfolioController = TextEditingController();
  final _experienceController = TextEditingController();
  final _nikController = TextEditingController();
  final _nameKtpController = TextEditingController();
  final _birthPlaceController = TextEditingController();
  final _birthDayController = TextEditingController();
  final _birthMonthController = TextEditingController();
  final _birthYearController = TextEditingController();
  final _addressKtpController = TextEditingController();

  // NIB controllers
  final _nibNumberController = TextEditingController();
  String? _nibFileBase64;
  String? _nibFileName;

  // Stored KTP reuse state
  bool _useSavedKtp = false;

  String? _ktpPhotoBase64;
  Uint8List? _ktpPreviewBytes;
  String? _selfiePhotoBase64;
  Uint8List? _selfiePreviewBytes;
  bool _isScanning = false;
  String? _birthDateError;

  bool get _categoryRequiresNib => [
        'institution',
        'government',
        'wedding_organizer',
        'event_organizer',
        'community',
      ].contains(_selectedCategory);

  static final List<TextInputFormatter> _digitsOnly = [
    FilteringTextInputFormatter.digitsOnly,
  ];

  static final List<TextInputFormatter> _nameFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r"[A-Za-z\s\.',-]")),
  ];

  final List<Map<String, String>> _categories = [
    {'slug': 'institution', 'name': 'Institution'},
    {'slug': 'government', 'name': 'Government'},
    {'slug': 'mc', 'name': 'MC'},
    {'slug': 'singer', 'name': 'Singer'},
    {'slug': 'wedding_organizer', 'name': 'Wedding Organizer'},
    {'slug': 'event_organizer', 'name': 'Event Organizer'},
    {'slug': 'community', 'name': 'Community'},
    {'slug': 'makeup_artist', 'name': 'Makeup Artist'},
    {'slug': 'photographer', 'name': 'Photographer'},
    {'slug': 'editor', 'name': 'Editor'},
    {'slug': 'videographer', 'name': 'Videographer'},
  ];

  @override
  void initState() {
    super.initState();
    final hasVerifiedKtp = widget.user.isVerified ||
        (widget.user.nik != null && widget.user.nik!.isNotEmpty);
    _useSavedKtp = hasVerifiedKtp;
    if (_useSavedKtp) {
      if (widget.user.nik != null) _nikController.text = widget.user.nik!;
      if (widget.user.fullNameKtp != null) {
        _nameKtpController.text = widget.user.fullNameKtp!;
      }
    }
  }

  @override
  void dispose() {
    _skillsController.dispose();
    _portfolioController.dispose();
    _experienceController.dispose();
    _nikController.dispose();
    _nameKtpController.dispose();
    _birthPlaceController.dispose();
    _birthDayController.dispose();
    _birthMonthController.dispose();
    _birthYearController.dispose();
    _addressKtpController.dispose();
    _nibNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    int initialYear = now.year - 25;
    int initialMonth = 1;
    int initialDay = 1;
    if (_birthYearController.text.isNotEmpty &&
        _birthMonthController.text.isNotEmpty &&
        _birthDayController.text.isNotEmpty) {
      initialYear = int.tryParse(_birthYearController.text) ?? initialYear;
      initialMonth = int.tryParse(_birthMonthController.text) ?? initialMonth;
      initialDay = int.tryParse(_birthDayController.text) ?? initialDay;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(
        initialYear,
        initialMonth.clamp(1, 12),
        initialDay.clamp(1, 31),
      ),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 17, now.month, now.day),
    );
    if (picked != null) {
      setState(() {
        _birthDayController.text = picked.day.toString().padLeft(2, '0');
        _birthMonthController.text = picked.month.toString().padLeft(2, '0');
        _birthYearController.text = picked.year.toString();
        _birthDateError = null;
      });
    }
  }

  Widget _buildBirthDateField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 58,
              child: TextFormField(
                controller: _birthDayController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                inputFormatters: [
                  ..._digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
                  hintText: 'DD',
                  hintStyle: TextStyle(
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade400,
                    fontSize: 13,
                  ),
                  errorStyle: const TextStyle(fontSize: 0, height: 0),
                  filled: true,
                  fillColor: isDark
                      ? AppTheme.inputBorder.withValues(alpha: 0.3)
                      : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryPurple,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red, width: 1.5),
                  ),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? '' : null,
                onChanged: (_) => setState(() => _birthDateError = null),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '/',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white38 : Colors.grey.shade400,
                ),
              ),
            ),
            SizedBox(
              width: 58,
              child: TextFormField(
                controller: _birthMonthController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                inputFormatters: [
                  ..._digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
                  hintText: 'MM',
                  hintStyle: TextStyle(
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade400,
                    fontSize: 13,
                  ),
                  errorStyle: const TextStyle(fontSize: 0, height: 0),
                  filled: true,
                  fillColor: isDark
                      ? AppTheme.inputBorder.withValues(alpha: 0.3)
                      : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryPurple,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red, width: 1.5),
                  ),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? '' : null,
                onChanged: (_) => setState(() => _birthDateError = null),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '/',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white38 : Colors.grey.shade400,
                ),
              ),
            ),
            SizedBox(
              width: 86,
              child: TextFormField(
                controller: _birthYearController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                inputFormatters: [
                  ..._digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
                  hintText: 'YYYY',
                  hintStyle: TextStyle(
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade400,
                    fontSize: 13,
                  ),
                  errorStyle: const TextStyle(fontSize: 0, height: 0),
                  filled: true,
                  fillColor: isDark
                      ? AppTheme.inputBorder.withValues(alpha: 0.3)
                      : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryPurple,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red, width: 1.5),
                  ),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? '' : null,
                onChanged: (_) => setState(() => _birthDateError = null),
              ),
            ),
            const SizedBox(width: 10),
            Tooltip(
              message: 'Pilih dari kalender',
              child: InkWell(
                onTap: _pickBirthDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: AppTheme.primaryPurple,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_birthDateError != null) ...[
          const SizedBox(height: 6),
          Text(
            _birthDateError!,
            style: TextStyle(
              color: Colors.red.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickNibFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    if (file.bytes!.length > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ukuran dokumen NIB maksimal 5 MB.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final isPdf = file.extension?.toLowerCase() == 'pdf';
    final mime = isPdf ? 'application/pdf' : 'image/jpeg';
    setState(() {
      _nibFileName = file.name;
      _nibFileBase64 = 'data:$mime;base64,${base64Encode(file.bytes!)}';
    });
  }

  void _parseOcrBirthDate(String? raw) {
    if (raw == null || raw.isEmpty) return;
    final match = RegExp(r'(\d{2})[-/](\d{2})[-/](\d{4})').firstMatch(raw);
    if (match != null) {
      _birthDayController.text = match.group(1)!;
      _birthMonthController.text = match.group(2)!;
      _birthYearController.text = match.group(3)!;
    }
  }

  Future<void> _pickKtpPhoto() async {
    // Use camera on mobile, file picker on web/desktop
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => KtpCameraView(
            onImageCaptured: (imagePath) async {
              Navigator.of(context).pop();
              await _processKtpImage(imagePath);
            },
            onCancel: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      );
    } else {
      // Fallback to file picker for web/desktop
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) return;

      if (file.bytes!.length > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ukuran foto maksimal 5 MB.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final b64 = await ImageCompressor.compressToBase64(file.bytes!);
      if (mounted) {
        setState(() {
          _ktpPreviewBytes = file.bytes;
          _ktpPhotoBase64 = b64;
        });
      }

      if (!kIsWeb && file.path != null) {
        await _processKtpImage(file.path!);
      }
    }
  }

  Future<void> _processKtpImage(String imagePath) async {
    setState(() => _isScanning = true);

    // Read image file and convert to compressed base64
    final imageFile = File(imagePath);
    final imageBytes = await imageFile.readAsBytes();
    final b64 = await ImageCompressor.compressToBase64(imageBytes);

    if (mounted) {
      setState(() {
        _ktpPreviewBytes = imageBytes;
        _ktpPhotoBase64 = b64;
      });
    }

    final ocr = await ktp_ocr.KtpOcrService.scanFromFile(imagePath);
    if (mounted) {
      setState(() => _isScanning = false);
      if (ocr.hasData) {
        if (ocr.nik != null) _nikController.text = ocr.nik!;
        if (ocr.fullName != null) _nameKtpController.text = ocr.fullName!;
        if (ocr.birthPlace != null) {
          _birthPlaceController.text = ocr.birthPlace!;
        }
        _parseOcrBirthDate(ocr.birthDate);
        if (ocr.address != null) _addressKtpController.text = ocr.address!;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Data KTP terdeteksi! Periksa dan koreksi jika perlu.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal membaca data KTP. Silakan isi manual.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickSelfiePhoto() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    if (file.bytes!.length > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ukuran foto maksimal 5 MB.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() {
      _selfiePreviewBytes = file.bytes;
      _selfiePhotoBase64 =
          'data:image/jpeg;base64,${base64Encode(file.bytes!)}';
    });
  }

  bool _validateKtpStep() {
    if (_useSavedKtp) return true;

    setState(
      () => _birthDateError = FormValidators.birthDateCombined(
        _birthDayController.text.trim(),
        _birthMonthController.text.trim(),
        _birthYearController.text.trim(),
      ),
    );

    if (_ktpPhotoBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload foto KTP terlebih dahulu.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    final ktpValid = _ktpFormKey.currentState?.validate() ?? false;
    return ktpValid && _birthDateError == null;
  }

  bool _validateSelfieStep() {
    if (_useSavedKtp) return true;

    if (_selfiePhotoBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload foto selfie terlebih dahulu.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    return true;
  }

  void _submit() {
    if (!_validateKtpStep()) return;
    if (!_validateSelfieStep()) return;
    if (_profileFormKey.currentState?.validate() != true) return;

    if (_categoryRequiresNib) {
      if (_nibNumberController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nomor Induk Berusaha (NIB) wajib diisi untuk kategori ini.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (_nibFileBase64 == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unggah dokumen/foto bukti NIB untuk kategori ini.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    if (!_useSavedKtp) {
      if (_ktpPhotoBase64 == null) return;
      if (_selfiePhotoBase64 == null) return;
    }

    widget.onApply(
      category: _selectedCategory,
      skills: _skillsController.text.trim(),
      portfolio: _portfolioController.text.trim(),
      experience: _experienceController.text.trim(),
      nik: _useSavedKtp ? widget.user.nik : _nikController.text.trim(),
      fullNameKtp: _useSavedKtp
          ? (widget.user.fullNameKtp ?? widget.user.name)
          : _nameKtpController.text.trim(),
      addressKtp: _useSavedKtp ? null : _addressKtpController.text.trim(),
      ktpPhotoBase64: _useSavedKtp ? null : _ktpPhotoBase64,
      selfiePhotoBase64: _useSavedKtp ? null : _selfiePhotoBase64,
      birthPlace: _useSavedKtp ? null : _birthPlaceController.text.trim(),
      birthDate: _useSavedKtp
          ? null
          : FormValidators.toIsoDate(
              _birthDayController.text.trim(),
              _birthMonthController.text.trim(),
              _birthYearController.text.trim(),
            ),
      reuseKtp: _useSavedKtp,
      nibNumber: _categoryRequiresNib ? _nibNumberController.text.trim() : null,
      nibFileBase64: _categoryRequiresNib ? _nibFileBase64 : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    if (widget.user.role == 'creator' && widget.user.isCreatorApproved) {
      return _buildApprovedCard(isDark);
    }

    if (widget.application != null && widget.application!.status == 'pending') {
      return _buildPendingCard(isDark);
    }

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
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upgrade ke Akun Kreator',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Verifikasi identitas KTP wajib. Isi data sesuai KTP asli — tidak boleh asal-asalan.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          // Step indicators
          Row(
            children: [
              _buildStepIndicator(0, 'Verifikasi KTP', theme, isDark),
              if (!isDesktop) const SizedBox(height: 16),
              if (isDesktop)
                Expanded(child: _buildStepLine(_currentStep > 0, isDark)),
              if (isDesktop) const SizedBox(width: 16),
              _buildStepIndicator(1, 'Verifikasi Selfie', theme, isDark),
              if (!isDesktop) const SizedBox(height: 16),
              if (isDesktop)
                Expanded(child: _buildStepLine(_currentStep > 1, isDark)),
              if (isDesktop) const SizedBox(width: 16),
              _buildStepIndicator(2, 'Profil Kreator', theme, isDark),
            ],
          ),
          const SizedBox(height: 32),
          // Step content
          if (_currentStep == 0) _buildKtpStep(isDark, isDesktop),
          if (_currentStep == 1) _buildSelfieStep(isDark),
          if (_currentStep == 2) _buildProfileStep(isDesktop),
          const SizedBox(height: 24),
          // Navigation buttons
          Row(
            children: [
              ElevatedButton(
                onPressed: () {
                  if (_currentStep == 0) {
                    if (_validateKtpStep()) {
                      setState(() => _currentStep = 1);
                    }
                  } else if (_currentStep == 1) {
                    if (_validateSelfieStep()) {
                      setState(() => _currentStep = 2);
                    }
                  } else {
                    _submit();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _currentStep < 2 ? 'Lanjut' : 'Kirim Pengajuan',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_currentStep > 0) ...[
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () {
                    setState(() => _currentStep -= 1);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                  child: const Text(
                    'Kembali',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(
    int step,
    String label,
    ThemeData theme,
    bool isDark,
  ) {
    final isActive = _currentStep >= step;
    final isCompleted = _currentStep > step;
    final isCurrent = _currentStep == step;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? Colors.green
                  : isCurrent
                  ? theme.colorScheme.primary
                  : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
              border: Border.all(
                color: isCurrent
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                width: 3,
              ),
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 24)
                  : Text(
                      '${step + 1}',
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isCurrent
                  ? theme.colorScheme.primary
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStepLine(bool isActive, bool isDark) {
    return Container(
      height: 2,
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green
            : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
      ),
    );
  }

  Widget _buildSelfieStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ambil atau unggah foto selfie Anda memegang KTP. Pastikan wajah Anda dan kartu KTP Anda terlihat jelas di dalam foto.',
          style: TextStyle(fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickSelfiePhoto,
          child: Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.inputDark : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selfiePreviewBytes != null
                    ? Colors.green
                    : (isDark ? AppTheme.inputBorder : Colors.grey.shade300),
                width: 2,
              ),
            ),
            child: _selfiePreviewBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      _selfiePreviewBytes!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.face_retouching_natural,
                        size: 40,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Upload Foto Selfie + KTP *',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'JPG/PNG, maks. 5 MB',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildKtpStep(bool isDark, bool isDesktop) {
    return Form(
      key: _ktpFormKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.user.isVerified ||
              (widget.user.nik != null && widget.user.nik!.isNotEmpty))
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    color: Colors.blue.shade700,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Gunakan Riwayat Verifikasi KTP',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'NIK: ${widget.user.nik ?? '-'} | Nama: ${widget.user.fullNameKtp ?? widget.user.name}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Data identitas KTP Anda sudah diverifikasi sebelumnya. Anda dapat langsung menggunakannya tanpa upload KTP baru.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _useSavedKtp,
                    onChanged: (val) {
                      setState(() => _useSavedKtp = val);
                    },
                  ),
                ],
              ),
            ),
          if (_useSavedKtp)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Identitas KTP dari riwayat verifikasi Anda siap digunakan. Silakan klik tombol "Lanjut" untuk melanjutkan.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: _pickKtpPhoto,
                        child: Container(
                          width: double.infinity,
                          height: 180,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.inputDark
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _ktpPreviewBytes != null
                                  ? Colors.green
                                  : (isDark
                                        ? AppTheme.inputBorder
                                        : Colors.grey.shade300),
                              width: 2,
                            ),
                          ),
                          child: _isScanning
                              ? const Center(child: CircularProgressIndicator())
                              : _ktpPreviewBytes != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.memory(
                                    _ktpPreviewBytes!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.badge_outlined,
                                      size: 38,
                                      color: Colors.grey.shade500,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Upload Foto KTP *',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      'JPG/PNG, maks. 5 MB',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tempat Lahir *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _birthPlaceController,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: _nameFormatters,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          hintText: 'Kota kelahiran sesuai KTP',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: FormValidators.birthPlace,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tanggal Lahir *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildBirthDateField(isDark),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NIK (16 digit) *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nikController,
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          ..._digitsOnly,
                          LengthLimitingTextInputFormatter(16),
                        ],
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          hintText: 'Masukkan 16 digit NIK sesuai KTP',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: FormValidators.nik,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Nama Lengkap (sesuai KTP) *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameKtpController,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: _nameFormatters,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          hintText: 'Nama lengkap sesuai KTP',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: FormValidators.ktpName,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Alamat (sesuai KTP) *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _addressKtpController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          hintText: 'Jalan, RT/RW, Kelurahan, Kecamatan, Kota',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: FormValidators.address,
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            _buildMobileKtpForm(isDark),
        ],
      ),
    );
  }

  Widget _buildMobileKtpForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _pickKtpPhoto,
          child: Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.inputDark : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _ktpPreviewBytes != null
                    ? Colors.green
                    : (isDark ? AppTheme.inputBorder : Colors.grey.shade300),
                width: 2,
              ),
            ),
            child: _isScanning
                ? const Center(child: CircularProgressIndicator())
                : _ktpPreviewBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      _ktpPreviewBytes!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.badge_outlined,
                        size: 40,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Upload Foto KTP *',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'JPG/PNG, maks. 5 MB',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'NIK (16 digit) *',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _nikController,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            ..._digitsOnly,
            LengthLimitingTextInputFormatter(16),
          ],
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            hintText: 'Masukkan 16 digit NIK sesuai KTP',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: FormValidators.nik,
        ),
        const SizedBox(height: 14),
        const Text(
          'Nama Lengkap (sesuai KTP) *',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _nameKtpController,
          textCapitalization: TextCapitalization.words,
          inputFormatters: _nameFormatters,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            hintText: 'Nama lengkap sesuai KTP',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: FormValidators.ktpName,
        ),
        const SizedBox(height: 14),
        const Text(
          'Tempat Lahir *',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _birthPlaceController,
          textCapitalization: TextCapitalization.words,
          inputFormatters: _nameFormatters,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            hintText: 'Kota kelahiran',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: FormValidators.birthPlace,
        ),
        const SizedBox(height: 14),
        const Text(
          'Tanggal Lahir *',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        _buildBirthDateField(isDark),
        const SizedBox(height: 14),
        const Text(
          'Alamat (sesuai KTP) *',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _addressKtpController,
          maxLines: 2,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            hintText: 'Jalan, RT/RW, Kelurahan, Kecamatan, Kota',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: FormValidators.address,
        ),
      ],
    );
  }

  Widget _buildProfileStep(bool isDesktop) {
    return Form(
      key: _profileFormKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: isDesktop
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kategori SubRole *',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedCategory,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: _categories
                                .map(
                                  (cat) => DropdownMenuItem(
                                    value: cat['slug'],
                                    child: Text(cat['name']!),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedCategory = val);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Link Portfolio *',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _portfolioController,
                            keyboardType: TextInputType.url,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              hintText: 'https://behance.net/username',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: FormValidators.portfolioUrl,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Deskripsi Keahlian *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _skillsController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    hintText: 'Min. 20 karakter — jelaskan keahlian utama Anda',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: FormValidators.skills,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pengalaman (Opsional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _experienceController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    hintText: 'Ceritakan pengalaman proyek terkait (opsional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                _buildNibSection(),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kategori SubRole *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _categories
                      .map(
                        (cat) => DropdownMenuItem(
                          value: cat['slug'],
                          child: Text(cat['name']!),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
                const SizedBox(height: 14),
                const Text(
                  'Link Portfolio *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _portfolioController,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    hintText: 'https://behance.net/username',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: FormValidators.portfolioUrl,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Deskripsi Keahlian *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _skillsController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    hintText: 'Min. 20 karakter — jelaskan keahlian utama Anda',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: FormValidators.skills,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Pengalaman (Opsional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _experienceController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    hintText: 'Ceritakan pengalaman proyek terkait (opsional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                _buildNibSection(),
              ],
            ),
    );
  }

  Widget _buildNibSection() {
    if (!_categoryRequiresNib) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.business_rounded,
                color: Colors.indigo.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Legalitas Usaha / NIB (Wajib untuk Kategori ini)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.indigo.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Nomor Induk Berusaha (NIB) *',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nibNumberController,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              hintText: 'Contoh: 1234567890123',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            validator: (val) {
              if (_categoryRequiresNib && (val == null || val.trim().isEmpty)) {
                return 'NIB wajib diisi untuk kategori ini';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickNibFile,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _nibFileBase64 != null
                      ? Colors.green
                      : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _nibFileBase64 != null
                        ? Icons.check_circle
                        : Icons.upload_file,
                    color: _nibFileBase64 != null
                        ? Colors.green
                        : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _nibFileName ??
                          'Unggah Berkas NIB (PDF/JPG/PNG, maks. 5 MB) *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _nibFileName != null
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _nibFileName != null
                            ? Colors.green.shade800
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _pickNibFile,
                    child: Text(
                      _nibFileName != null ? 'Ganti' : 'Pilih Berkas',
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

  Widget _buildApprovedCard(bool isDark) {
    final isCompact = MediaQuery.of(context).size.width < 600;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.green.shade50.withValues(alpha: isDark ? 0.1 : 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green.shade700,
                size: isCompact ? 24 : 28,
              ),
              SizedBox(width: isCompact ? 8 : 10),
              Expanded(
                child: Text(
                  'Kreator Aktif',
                  style: TextStyle(
                    fontSize: isCompact ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 8 : 10),
          Text(
            'Akun Anda telah diverifikasi sebagai Creator.',
            style: TextStyle(
              fontSize: isCompact ? 12.5 : 14,
              color: isDark ? Colors.white70 : Colors.green.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.amber.shade50.withValues(alpha: isDark ? 0.1 : 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pengajuan Diproses',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Verifikasi KTP sedang direview admin.',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
