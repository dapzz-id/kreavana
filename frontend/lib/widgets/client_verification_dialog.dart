import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../app/theme.dart';
import '../services/verification_service.dart';
import '../utils/app_errors.dart';

class ClientVerificationDialog extends StatefulWidget {
  final VoidCallback? onSuccess;

  const ClientVerificationDialog({super.key, this.onSuccess});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: const ClientVerificationDialog(),
        ),
      ),
    );
  }

  @override
  State<ClientVerificationDialog> createState() =>
      _ClientVerificationDialogState();
}

class _ClientVerificationDialogState extends State<ClientVerificationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nikController = TextEditingController();
  final _nameController = TextEditingController();
  final _birthPlaceController = TextEditingController();
  final _addressController = TextEditingController();

  DateTime? _selectedBirthDate;
  PlatformFile? _ktpFile;
  String? _ktpBase64;
  PlatformFile? _selfieFile;
  String? _selfieBase64;
  bool _isSubmitting = false;

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
        final b64 = 'data:image/${file.extension ?? 'jpg'};base64,${base64Encode(file.bytes!)}';
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
        final b64 = 'data:image/${file.extension ?? 'jpg'};base64,${base64Encode(file.bytes!)}';
        setState(() {
          _selfieFile = file;
          _selfieBase64 = b64;
        });
      }
    }
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
    if (!_formKey.currentState!.validate()) return;
    if (_ktpBase64 == null) {
      AppSnackbar.error(context, 'Wajib mengunggah foto KTP asli.');
      return;
    }
    if (_selfieBase64 == null) {
      AppSnackbar.error(context, 'Wajib mengunggah foto selfie.');
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
          ? "${_selectedBirthDate!.year.toString().padLeft(4, '0')}-${_selectedBirthDate!.month.toString().padLeft(2, '0')}-${_selectedBirthDate!.day.toString().padLeft(2, '0')}"
          : null,
      addressKtp: _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : null,
      ktpPhotoBase64: _ktpBase64!,
      selfiePhotoBase64: _selfieBase64,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (res['status'] == true) {
        AppSnackbar.success(
          context,
          'Pengajuan verifikasi KTP berhasil dikirim ke Admin.',
        );
        widget.onSuccess?.call();
        Navigator.pop(context, true);
      } else {
        AppSnackbar.error(
          context,
          res['message'] ?? 'Gagal mengirim pengajuan verifikasi.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13111E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.verified_rounded,
                            color: Color(0xFF2563EB),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verifikasi KTP Klien',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Dapatkan Badge Centang Biru Resmi',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 18, color: Color(0xFF2563EB)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Klien wajib memverifikasi KTP sebelum mempublikasikan kebutuhan proyek. Anda tetap berstatus Klien (tidak diubah menjadi kreator) dan akan mendapatkan centang biru.',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            color: isDark ? Colors.white70 : const Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // NIK Field
                const Text('Nomor Induk Kependudukan (NIK)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nikController,
                  keyboardType: TextInputType.number,
                  maxLength: 16,
                  decoration: InputDecoration(
                    hintText: '16 digit NIK sesuai KTP',
                    counterText: '',
                    prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length != 16) {
                      return 'NIK harus terdiri dari 16 digit angka';
                    }
                    if (!RegExp(r'^\d+$').hasMatch(v.trim())) {
                      return 'NIK hanya boleh berupa angka';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Nama Sesuai KTP
                const Text('Nama Lengkap (Sesuai KTP)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Ahmad Fauzi',
                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length < 3) {
                      return 'Nama lengkap KTP wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Tanggal & Tempat Lahir
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tempat Lahir',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _birthPlaceController,
                            decoration: InputDecoration(
                              hintText: 'Kota kelahiran',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tanggal Lahir',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: _pickBirthDate,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isDark ? AppTheme.inputBorder : Colors.grey.shade400,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _selectedBirthDate != null
                                        ? '${_selectedBirthDate!.day}/${_selectedBirthDate!.month}/${_selectedBirthDate!.year}'
                                        : 'Pilih Tanggal',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _selectedBirthDate != null
                                          ? (isDark ? Colors.white : Colors.black87)
                                          : Colors.grey,
                                    ),
                                  ),
                                  const Icon(Icons.calendar_today_outlined, size: 16),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Alamat KTP
                const Text('Alamat Lengkap KTP',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Jalan, RT/RW, Kelurahan, Kecamatan, Kota',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),

                // Upload Foto KTP
                const Text('Unggah Foto KTP Asli',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickKtp,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.cardBg : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _ktpFile != null
                            ? const Color(0xFF10B981)
                            : (isDark ? AppTheme.inputBorder : Colors.grey.shade300),
                        width: _ktpFile != null ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (_ktpFile != null
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF2563EB))
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _ktpFile != null ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
                            color: _ktpFile != null
                                ? const Color(0xFF10B981)
                                : const Color(0xFF2563EB),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _ktpFile != null ? _ktpFile!.name : 'Pilih file KTP (JPG / PNG)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _ktpFile != null ? const Color(0xFF10B981) : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _ktpFile != null ? 'KTP siap diunggah' : 'Pastikan NIK dan nama terbaca jelas',
                                style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _pickKtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _ktpFile != null
                                ? Colors.grey.shade200
                                : const Color(0xFF2563EB),
                            foregroundColor: _ktpFile != null ? Colors.black87 : Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(_ktpFile != null ? 'Ganti' : 'Pilih'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Upload Foto Selfie
                const Text('Unggah Foto Selfie',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickSelfie,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.cardBg : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _selfieFile != null
                            ? const Color(0xFF10B981)
                            : (isDark ? AppTheme.inputBorder : Colors.grey.shade300),
                        width: _selfieFile != null ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (_selfieFile != null
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF8B5CF6))
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _selfieFile != null ? Icons.check_circle_rounded : Icons.face_rounded,
                            color: _selfieFile != null
                                ? const Color(0xFF10B981)
                                : const Color(0xFF8B5CF6),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selfieFile != null ? _selfieFile!.name : 'Pilih file Foto Selfie (JPG / PNG)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _selfieFile != null ? const Color(0xFF10B981) : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _selfieFile != null ? 'Selfie siap diunggah' : 'Pastikan wajah terlihat jelas tanpa masker/kacamata hitam',
                                style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _pickSelfie,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selfieFile != null
                                ? Colors.grey.shade200
                                : const Color(0xFF8B5CF6),
                            foregroundColor: _selfieFile != null ? Colors.black87 : Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(_selfieFile != null ? 'Ganti' : 'Pilih'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Ajukan Verifikasi Klien',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
