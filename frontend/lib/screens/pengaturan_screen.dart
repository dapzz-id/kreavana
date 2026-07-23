import 'package:flutter/material.dart';
import '../app/theme.dart';

class PengaturanScreen extends StatefulWidget {
  const PengaturanScreen({super.key});

  @override
  State<PengaturanScreen> createState() => _PengaturanScreenState();
}

class _PengaturanScreenState extends State<PengaturanScreen> {
  bool _notifEmail = true;
  bool _notifPush = true;
  bool _notifProyek = true;
  bool _darkMode = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: const Text('Pengaturan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('Akun', [
            _buildTile(Icons.person_outline, 'Profil Saya', 'Edit nama, foto, bio', isDark),
            _buildTile(Icons.lock_outline, 'Keamanan', 'Ubah kata sandi, 2FA', isDark),
            _buildTile(Icons.payment_outlined, 'Metode Pembayaran', 'Kelola kartu & rekening', isDark),
            _buildTile(Icons.location_on_outlined, 'Alamat', 'Kelola alamat pengiriman', isDark),
          ], isDark),
          const SizedBox(height: 20),
          _buildSection('Notifikasi', [
            _buildSwitchTile(Icons.email_outlined, 'Notifikasi Email', 'Terima notifikasi via email', _notifEmail, (v) => setState(() => _notifEmail = v), isDark),
            _buildSwitchTile(Icons.notifications_outlined, 'Notifikasi Push', 'Terima notifikasi push', _notifPush, (v) => setState(() => _notifPush = v), isDark),
            _buildSwitchTile(Icons.folder_outlined, 'Update Proyek', 'Notifikasi status proyek', _notifProyek, (v) => setState(() => _notifProyek = v), isDark),
          ], isDark),
          const SizedBox(height: 20),
          _buildSection('Umum', [
            _buildSwitchTile(Icons.dark_mode_outlined, 'Mode Gelap', 'Gunakan tema gelap', _darkMode, (v) => setState(() => _darkMode = v), isDark),
            _buildTile(Icons.language, 'Bahasa', 'Indonesia', isDark),
            _buildTile(Icons.help_outline, 'Bantuan & Dukungan', 'FAQ, hubungi support', isDark),
            _buildTile(Icons.info_outline, 'Tentang Kreavana', 'Versi 1.0.0', isDark),
          ], isDark),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Keluar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppTheme.textMuted : Colors.grey.shade500)),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTile(IconData icon, String title, String subtitle, bool isDark) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryPurple, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : Colors.grey.shade500)),
      trailing: Icon(Icons.chevron_right, color: isDark ? AppTheme.textMuted : Colors.grey.shade400, size: 20),
      onTap: () {},
    );
  }

  Widget _buildSwitchTile(IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged, bool isDark) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryPurple, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : Colors.grey.shade500)),
      trailing: Switch(value: value, onChanged: onChanged, activeThumbColor: AppTheme.primaryPurple),
    );
  }
}
