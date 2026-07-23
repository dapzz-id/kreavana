import 'package:flutter/material.dart';
import '../app/theme.dart';

class BuatKebutuhanScreen extends StatefulWidget {
  const BuatKebutuhanScreen({super.key});

  @override
  State<BuatKebutuhanScreen> createState() => _BuatKebutuhanScreenState();
}

class _BuatKebutuhanScreenState extends State<BuatKebutuhanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _judulController = TextEditingController();
  final _deskripsiController = TextEditingController();
  String _selectedKategori = 'Fotografi';
  String _selectedBudget = '< Rp 500.000';
  String _selectedDeadline = '1 Minggu';

  @override
  void dispose() {
    _judulController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: const Text('Buat Kebutuhan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.primaryPurple, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Jelaskan kebutuhan Anda agar kreator bisa memberikan proposal yang tepat.',
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildLabel('Judul Kebutuhan'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _judulController,
                decoration: _inputDecoration('Contoh: Foto Katalog Produk Fashion', isDark),
                validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 20),
              _buildLabel('Kategori'),
              const SizedBox(height: 8),
              _buildDropdown(_selectedKategori, ['Fotografi', 'Videografi', 'Desain Grafis', 'Konten Kreator', 'Lainnya'], (v) => setState(() => _selectedKategori = v!), isDark),
              const SizedBox(height: 20),
              _buildLabel('Deskripsi Kebutuhan'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _deskripsiController,
                maxLines: 5,
                decoration: _inputDecoration('Jelaskan detail kebutuhan Anda...', isDark),
                validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 20),
              _buildLabel('Budget Estimasi'),
              const SizedBox(height: 8),
              _buildDropdown(_selectedBudget, ['< Rp 500.000', 'Rp 500.000 - 1.000.000', 'Rp 1.000.000 - 5.000.000', '> Rp 5.000.000'], (v) => setState(() => _selectedBudget = v!), isDark),
              const SizedBox(height: 20),
              _buildLabel('Deadline'),
              const SizedBox(height: 8),
              _buildDropdown(_selectedDeadline, ['1 Minggu', '2 Minggu', '1 Bulan', 'Fleksibel'], (v) => setState(() => _selectedDeadline = v!), isDark),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Kebutuhan berhasil dibuat!'),
                          backgroundColor: AppTheme.primaryPurple,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Kirim Kebutuhan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600));
  }

  InputDecoration _inputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade400),
      filled: true,
      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryPurple, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildDropdown(String value, List<String> items, ValueChanged<String?> onChanged, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
