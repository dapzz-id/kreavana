import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/user_model.dart';

class CreatorApplicationCard extends StatefulWidget {
  final UserModel user;
  final CreatorApplication? application;
  final Function({
    required String category,
    required String skills,
    required String portfolio,
    required String experience,
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
  final _formKey = GlobalKey<FormState>();
  String _selectedCategory = 'kreator';
  final _skillsController = TextEditingController();
  final _portfolioController = TextEditingController();
  final _experienceController = TextEditingController();

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
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onApply(
        category: _selectedCategory,
        skills: _skillsController.text.trim(),
        portfolio: _portfolioController.text.trim(),
        experience: _experienceController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Case 1: User is already a creator
    if (widget.user.role == 'creator' && widget.user.isCreatorApproved) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.shade50.withValues(alpha: isDark ? 0.1 : 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.shade300, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade700,
                  size: 28,
                ),
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
              'Selamat! Akun Anda telah disetujui sebagai Creator untuk kategori: ${widget.user.selectedPihak.toUpperCase()}.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.green.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Anda sekarang dapat beralih ke mode Creator di halaman Dashboard untuk melihat statistik proyek, mengelola portofolio, dan menerima tawaran kolaborasi.',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? Colors.white60
                    : Colors.green.shade800.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      );
    }

    // Case 2: Application is pending
    if (widget.application != null && widget.application!.status == 'pending') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.amber.shade50.withValues(alpha: isDark ? 0.1 : 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.shade300, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.hourglass_empty,
                  color: Colors.amber.shade700,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Text(
                  'Pengajuan Diproses',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Pengajuan Anda untuk kategori ${widget.application!.pihakCategory.toUpperCase()} sedang direview oleh admin.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.amber.shade900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Keahlian: ${widget.application!.skillDescription}',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Case 3: Show Application Form (no app, or rejected)
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: !isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ajukan Sebagai Creator',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Tawarkan keahlian Anda ke partner kolaborasi dan mulailah menghasilkan.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),

            // Dropdown Kategori Pihak
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Kategori Pihak',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              items: _categories.map((cat) {
                return DropdownMenuItem<String>(
                  value: cat['slug'],
                  child: Text(cat['name']!),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedCategory = val);
                }
              },
            ),
            const SizedBox(height: 16),

            // Deskripsi Keahlian
            TextFormField(
              controller: _skillsController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Deskripsi Keahlian',
                hintText: 'Jelaskan keahlian utama Anda...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Keahlian wajib diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Link Portfolio
            TextFormField(
              controller: _portfolioController,
              decoration: InputDecoration(
                labelText: 'Link Portfolio',
                hintText: 'Google Drive, Behance, Website, dll...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Link portfolio wajib diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Pengalaman Kerja
            TextFormField(
              controller: _experienceController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Pengalaman (Opsional)',
                hintText:
                    'Sebutkan beberapa proyek atau pekerjaan sebelumnya...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Kirim Pengajuan',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
