import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../services/ktp_ocr_service.dart';
import '../utils/form_validators.dart';

class CreatorApplicationCard extends StatefulWidget {
  final UserModel user;
  final CreatorApplication? application;
  final Function({
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
  String _selectedCategory = 'kreator';
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

  String? _ktpPhotoBase64;
  Uint8List? _ktpPreviewBytes;
  String? _selfiePhotoBase64;
  Uint8List? _selfiePreviewBytes;
  bool _isScanning = false;
  String? _birthDateError;

  static final List<TextInputFormatter> _digitsOnly = [
    FilteringTextInputFormatter.digitsOnly,
  ];

  static final List<TextInputFormatter> _nameFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r"[A-Za-z\s\.',-]")),
  ];

  final List<Map<String, String>> _categories = [
    {'slug': 'kreator', 'name': 'Kreator / Pekerja Seni'},
    {'slug': 'eo', 'name': 'Event Organizer (EO)'},
    {'slug': 'wo', 'name': 'Wedding Organizer (WO)'},
    {'slug': 'sekolah', 'name': 'Sekolah / Kampus'},
    {'slug': 'umkm', 'name': 'Perusahaan / UMKM'},
    {'slug': 'pemerintah', 'name': 'Pemerintah / Instansi'},
    {'slug': 'komunitas', 'name': 'Komunitas Sosial'},
    {'slug': 'organisasi', 'name': 'Organisasi / Yayasan'},
  ];

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
    super.dispose();
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
      _ktpPreviewBytes = file.bytes;
      _ktpPhotoBase64 =
          'data:image/jpeg;base64,${base64Encode(file.bytes!)}';
    });

    if (!kIsWeb && file.path != null) {
      setState(() => _isScanning = true);
      final ocr = await KtpOcrService.scanFromFile(file.path!);
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
        }
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
    setState(() => _birthDateError = FormValidators.birthDateCombined(
          _birthDayController.text.trim(),
          _birthMonthController.text.trim(),
          _birthYearController.text.trim(),
        ));

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
    if (_ktpPhotoBase64 == null) return;
    if (_selfiePhotoBase64 == null) return;

    widget.onApply(
      category: _selectedCategory,
      skills: _skillsController.text.trim(),
      portfolio: _portfolioController.text.trim(),
      experience: _experienceController.text.trim(),
      nik: _nikController.text.trim(),
      fullNameKtp: _nameKtpController.text.trim(),
      addressKtp: _addressKtpController.text.trim(),
      ktpPhotoBase64: _ktpPhotoBase64!,
      selfiePhotoBase64: _selfiePhotoBase64!,
      birthPlace: _birthPlaceController.text.trim(),
      birthDate: FormValidators.toIsoDate(
        _birthDayController.text.trim(),
        _birthMonthController.text.trim(),
        _birthYearController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (widget.user.role == 'creator' && widget.user.isCreatorApproved) {
      return _buildApprovedCard(isDark);
    }

    if (widget.application != null &&
        widget.application!.status == 'pending') {
      return _buildPendingCard(isDark);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upgrade ke Akun Kreator',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Verifikasi identitas KTP wajib. Isi data sesuai KTP asli — tidak boleh asal-asalan.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          Stepper(
            type: StepperType.vertical,
            currentStep: _currentStep,
            onStepContinue: () {
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
            onStepCancel: () {
              if (_currentStep > 0) {
                setState(() => _currentStep -= 1);
              }
            },
            controlsBuilder: (context, details) {
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    ElevatedButton(
                      onPressed: details.onStepContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        _currentStep < 2 ? 'Lanjut' : 'Kirim Pengajuan',
                      ),
                    ),
                    if (_currentStep > 0) ...[
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: details.onStepCancel,
                        child: const Text('Kembali'),
                      ),
                    ],
                  ],
                ),
              );
            },
            steps: [
              Step(
                title: const Text('Verifikasi KTP'),
                subtitle: const Text('Upload & isi identitas'),
                isActive: _currentStep >= 0,
                state: _currentStep > 0
                    ? StepState.complete
                    : StepState.indexed,
                content: _buildKtpStep(isDark),
              ),
              Step(
                title: const Text('Verifikasi Wajah / Selfie'),
                subtitle: const Text('Upload foto selfie Anda'),
                isActive: _currentStep >= 1,
                state: _currentStep > 1
                    ? StepState.complete
                    : (_currentStep == 1 ? StepState.editing : StepState.indexed),
                content: _buildSelfieStep(isDark),
              ),
              Step(
                title: const Text('Profil Kreator'),
                subtitle: const Text('Keahlian & portfolio'),
                isActive: _currentStep >= 2,
                state: _currentStep == 2
                    ? StepState.editing
                    : StepState.indexed,
                content: _buildProfileStep(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelfieStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ambil atau unggah foto selfie Anda memegang KTP. Pastikan wajah Anda dan kartu KTP Anda terlihat jelas di dalam foto.',
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
          ),
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
                      Icon(Icons.face_retouching_natural,
                          size: 40, color: Colors.grey.shade500),
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

  Widget _buildKtpStep(bool isDark) {
    return Form(
      key: _ktpFormKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
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
                            Icon(Icons.badge_outlined,
                                size: 40, color: Colors.grey.shade500),
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
          TextFormField(
            controller: _nikController,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              ..._digitsOnly,
              LengthLimitingTextInputFormatter(16),
            ],
            decoration: InputDecoration(
              labelText: 'NIK (16 digit) *',
              hintText: '3201234567890001',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: FormValidators.nik,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nameKtpController,
            textCapitalization: TextCapitalization.words,
            inputFormatters: _nameFormatters,
            decoration: InputDecoration(
              labelText: 'Nama Lengkap (sesuai KTP) *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: FormValidators.ktpName,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _birthPlaceController,
            textCapitalization: TextCapitalization.words,
            inputFormatters: _nameFormatters,
            decoration: InputDecoration(
              labelText: 'Tempat Lahir *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: FormValidators.birthPlace,
          ),
          const SizedBox(height: 12),
          const Text(
            'Tanggal Lahir *',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _birthDayController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    ..._digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Tgl',
                    hintText: 'DD',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: FormValidators.birthDay,
                  onChanged: (_) => setState(() => _birthDateError = null),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _birthMonthController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    ..._digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Bln',
                    hintText: 'MM',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: FormValidators.birthMonth,
                  onChanged: (_) => setState(() => _birthDateError = null),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _birthYearController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    ..._digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Thn',
                    hintText: 'YYYY',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: FormValidators.birthYear,
                  onChanged: (_) => setState(() => _birthDateError = null),
                ),
              ),
            ],
          ),
          if (_birthDateError != null) ...[
            const SizedBox(height: 6),
            Text(
              _birthDateError!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _addressKtpController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Alamat (sesuai KTP) *',
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: FormValidators.address,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStep() {
    return Form(
      key: _profileFormKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: InputDecoration(
              labelText: 'Kategori Pihak *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
          const SizedBox(height: 16),
          TextFormField(
            controller: _skillsController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Deskripsi Keahlian *',
              hintText: 'Min. 20 karakter — jelaskan keahlian utama Anda',
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: FormValidators.skills,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _portfolioController,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: 'Link Portfolio *',
              hintText: 'https://behance.net/username',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: FormValidators.portfolioUrl,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _experienceController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Pengalaman (Opsional)',
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
              Icon(Icons.check_circle, color: Colors.green.shade700, size: 28),
              const SizedBox(width: 10),
              Text(
                'Kreator Aktif',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Akun Anda telah diverifikasi sebagai Creator.',
            style: TextStyle(
              fontSize: 14,
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
