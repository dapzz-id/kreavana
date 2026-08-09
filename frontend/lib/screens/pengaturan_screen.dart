import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../main.dart' show themeNotifier;
import '../features/auth/services/auth_service.dart';
import '../services/api_service.dart';
import '../utils/app_errors.dart';
import 'profile_screen.dart';
import 'payment_methods_screen.dart';
import 'addresses_screen.dart';
import 'help_screen.dart';
import 'privacy_policy_screen.dart';

class PengaturanScreen extends StatefulWidget {
  final UserModel? user;
  final ValueChanged<UserModel>? onUserUpdated;
  final VoidCallback? onLogout;

  const PengaturanScreen({
    super.key,
    this.user,
    this.onUserUpdated,
    this.onLogout,
  });

  @override
  State<PengaturanScreen> createState() => _PengaturanScreenState();
}

class _PengaturanScreenState extends State<PengaturanScreen> {
  bool _notifEmail = true;
  bool _notifPush = true;
  bool _notifProyek = true;
  bool _notifChat = true;
  String _langCode = 'id';

  static const _langLabels = {
    'id': 'Indonesia',
    'en': 'English',
  };

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notifEmail = prefs.getBool('notif_email') ?? true;
      _notifPush = prefs.getBool('notif_push') ?? true;
      _notifProyek = prefs.getBool('notif_proyek') ?? true;
      _notifChat = prefs.getBool('notif_chat') ?? true;
      _langCode = prefs.getString('lang_code') ?? 'id';
    });
  }

  Future<void> _saveNotif(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _openProfile() {
    if (widget.user == null) {
      AppSnackbar.info(context, 'Silakan login terlebih dahulu.');
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ProfileScreen(
        user: widget.user!,
        onUserUpdated: widget.onUserUpdated ?? (_) {},
        onLogout: widget.onLogout ?? () {},
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 70,
        title: const Text('Pengaturan', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          // ── Profile header ────────────────────────────────────────────────
          if (widget.user != null) ...[
            GestureDetector(
              onTap: _openProfile,
              child: Container(
                padding: const EdgeInsets.all(18),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E1B38), const Color(0xFF13111F)]
                        : [const Color(0xFFEDE9FE), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(
                    color: isDark ? AppTheme.inputBorder : AppTheme.dividerLight,
                  ),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.15),
                    backgroundImage: widget.user!.avatarUrl?.isNotEmpty == true
                        ? NetworkImage(ApiService.resolveAssetUrl(widget.user!.avatarUrl!))
                        : null,
                    child: widget.user!.avatarUrl?.isNotEmpty != true
                        ? Icon(Icons.person, color: AppTheme.primaryPurple, size: 28)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.user!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text('@${widget.user!.username}', style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight)),
                    const SizedBox(height: 4),
                    _RoleBadge(role: widget.user!.role, subRole: widget.user!.subRole),
                  ])),
                  const Icon(Icons.chevron_right, color: AppTheme.primaryPurple),
                ]),
              ),
            ),
          ],

          // ── Akun ─────────────────────────────────────────────────────────
          _buildSection(
            title: 'Akun',
            icon: Icons.person_outline,
            isDark: isDark,
            children: [
              _buildNavTile(
                icon: Icons.person_outline,
                iconColor: AppTheme.primaryPurple,
                title: 'Profil Saya',
                subtitle: 'Edit nama, foto, bio',
                isDark: isDark,
                onTap: _openProfile,
              ),
              _buildNavTile(
                icon: Icons.lock_outline,
                iconColor: const Color(0xFF3B82F6),
                title: 'Keamanan',
                subtitle: 'Ubah kata sandi & verifikasi 2FA',
                isDark: isDark,
                onTap: () => _showChangePasswordDialog(),
              ),
              _buildNavTile(
                icon: Icons.payment_outlined,
                iconColor: const Color(0xFF10B981),
                title: 'Metode Pembayaran',
                subtitle: 'Kelola kartu & rekening bank',
                isDark: isDark,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const PaymentMethodsScreen(),
                )),
              ),
              _buildNavTile(
                icon: Icons.location_on_outlined,
                iconColor: const Color(0xFFF97316),
                title: 'Alamat',
                subtitle: 'Kelola alamat pengiriman',
                isDark: isDark,
                isLast: true,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const AddressesScreen(),
                )),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Notifikasi ───────────────────────────────────────────────────
          _buildSection(
            title: 'Notifikasi',
            icon: Icons.notifications_outlined,
            isDark: isDark,
            children: [
              _buildSwitchTile(
                icon: Icons.email_outlined,
                iconColor: const Color(0xFF6366F1),
                title: 'Notifikasi Email',
                subtitle: 'Terima pembaruan penting via email',
                value: _notifEmail,
                isDark: isDark,
                onChanged: (v) {
                  setState(() => _notifEmail = v);
                  _saveNotif('notif_email', v);
                },
              ),
              _buildSwitchTile(
                icon: Icons.phone_android_outlined,
                iconColor: const Color(0xFF7C3AED),
                title: 'Notifikasi Push',
                subtitle: 'Terima notifikasi di perangkat',
                value: _notifPush,
                isDark: isDark,
                onChanged: (v) {
                  setState(() => _notifPush = v);
                  _saveNotif('notif_push', v);
                },
              ),
              _buildSwitchTile(
                icon: Icons.folder_outlined,
                iconColor: const Color(0xFF10B981),
                title: 'Update Proyek',
                subtitle: 'Notifikasi perubahan status proyek',
                value: _notifProyek,
                isDark: isDark,
                onChanged: (v) {
                  setState(() => _notifProyek = v);
                  _saveNotif('notif_proyek', v);
                },
              ),
              _buildSwitchTile(
                icon: Icons.chat_bubble_outline,
                iconColor: const Color(0xFFF59E0B),
                title: 'Pesan & Chat',
                subtitle: 'Notifikasi pesan baru',
                value: _notifChat,
                isDark: isDark,
                isLast: true,
                onChanged: (v) {
                  setState(() => _notifChat = v);
                  _saveNotif('notif_chat', v);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Tampilan ─────────────────────────────────────────────────────
          _buildSection(
            title: 'Tampilan & Aksesibilitas',
            icon: Icons.palette_outlined,
            isDark: isDark,
            children: [
              _buildSwitchTile(
                icon: isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                iconColor: isDark ? const Color(0xFF8B5CF6) : const Color(0xFFF59E0B),
                title: 'Mode Gelap',
                subtitle: isDark ? 'Aktif — tampilan gelap nyaman di malam hari' : 'Nonaktif — tampilan terang',
                value: isDark,
                isDark: isDark,
                isLast: true,
                onChanged: (v) {
                  themeNotifier.value = v ? ThemeMode.dark : ThemeMode.light;
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Bantuan ──────────────────────────────────────────────────────
          _buildSection(
            title: 'Bantuan & Info',
            icon: Icons.help_outline,
            isDark: isDark,
            children: [
              _buildNavTile(
                icon: Icons.language,
                iconColor: const Color(0xFF3B82F6),
                title: 'Bahasa',
                subtitle: '${_langLabels[_langCode] ?? 'Indonesia'} (${_langCode.toUpperCase()})',
                isDark: isDark,
                trailing: Text(_langCode.toUpperCase(),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryPurple)),
                onTap: _showLanguagePicker,
              ),
              _buildNavTile(
                icon: Icons.help_outline,
                iconColor: const Color(0xFF10B981),
                title: 'Bantuan & Dukungan',
                subtitle: 'FAQ, panduan pengguna, hubungi support',
                isDark: isDark,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const HelpScreen(),
                )),
              ),
              _buildNavTile(
                icon: Icons.privacy_tip_outlined,
                iconColor: const Color(0xFF6366F1),
                title: 'Kebijakan Privasi',
                subtitle: 'Pelajari cara kami melindungi data Anda',
                isDark: isDark,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const PrivacyPolicyScreen(),
                )),
              ),
              _buildNavTile(
                icon: Icons.info_outline,
                iconColor: AppTheme.textMutedLight,
                title: 'Tentang Kreavana',
                subtitle: 'Versi 1.0.0 · Build 2025',
                isDark: isDark,
                isLast: true,
                showArrow: false,
                onTap: () => _showAboutDialog(),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Logout ───────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(color: AppTheme.error.withValues(alpha: 0.25)),
              boxShadow: isDark ? null : AppTheme.cardShadowLight,
            ),
            child: InkWell(
              onTap: _confirmLogout,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.logout_rounded, color: AppTheme.error, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Keluar dari Akun', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.error)),
                    Text('Anda akan keluar dari sesi ini', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight)),
                  ])),
                  Icon(Icons.chevron_right, color: AppTheme.error.withValues(alpha: 0.5), size: 18),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── App version footer ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Text(
                'Kreavana v1.0.0 · © 2025 Kreavana ID',
                style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(children: [
            Icon(icon, size: 14, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight),
            const SizedBox(width: 6),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                letterSpacing: 0.8,
              ),
            ),
          ]),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            border: Border.all(color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight),
            boxShadow: isDark ? null : AppTheme.cardShadowLight,
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildNavTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
    bool isLast = false,
    bool showArrow = true,
    Widget? trailing,
  }) {
    return Column(children: [
      InkWell(
        onTap: onTap,
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusMD))
            : BorderRadius.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 1),
              Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight)),
            ])),
            trailing ?? (showArrow
                ? Icon(Icons.chevron_right, size: 18, color: isDark ? AppTheme.textMuted : Colors.grey.shade400)
                : const SizedBox.shrink()),
          ]),
        ),
      ),
      if (!isLast)
        Divider(height: 1, indent: 66, color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight),
    ]);
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required bool isDark,
    required ValueChanged<bool> onChanged,
    bool isLast = false,
  }) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 1),
            Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight)),
          ])),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.primaryPurple,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ]),
      ),
      if (!isLast)
        Divider(height: 1, indent: 66, color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight),
    ]);
  }

  Future<void> _showLanguagePicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDarkSheet = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: isDarkSheet ? AppTheme.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42, height: 4,
                  decoration: BoxDecoration(
                    color: isDarkSheet ? AppTheme.inputBorder : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Pilih Bahasa', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              for (final entry in _langLabels.entries)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: Icon(
                    Icons.language,
                    color: entry.key == _langCode ? AppTheme.primaryPurple : AppTheme.textMuted,
                  ),
                  title: Text(entry.value,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: entry.key == _langCode ? AppTheme.primaryPurple : null,
                      )),
                  subtitle: Text(entry.key == 'id' ? 'Bahasa Indonesia' : 'English'),
                  trailing: entry.key == _langCode
                      ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryPurple, size: 22)
                      : null,
                  onTap: () => Navigator.pop(ctx, entry.key),
                ),
            ],
          ),
        );
      },
    );

    if (selected != null && selected != _langCode) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lang_code', selected);
      if (mounted) {
        setState(() => _langCode = selected);
        AppSnackbar.success(
          context,
          selected == 'id'
              ? 'Bahasa aplikasi diatur ke Bahasa Indonesia'
              : 'App language set to English',
        );
      }
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar Akun', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Apakah Anda yakin ingin keluar dari Kreavana?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (widget.onLogout != null) {
                widget.onLogout!();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    var isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Ubah Kata Sandi', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: currentCtrl, obscureText: true,
                decoration: const InputDecoration(labelText: 'Kata Sandi Saat Ini', prefixIcon: Icon(Icons.lock_outline))),
            const SizedBox(height: 12),
            TextField(controller: newCtrl, obscureText: true,
                decoration: const InputDecoration(labelText: 'Kata Sandi Baru', prefixIcon: Icon(Icons.lock_outline))),
            const SizedBox(height: 12),
            TextField(controller: confirmCtrl, obscureText: true,
                decoration: const InputDecoration(labelText: 'Konfirmasi Kata Sandi', prefixIcon: Icon(Icons.lock_outline))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final current = currentCtrl.text;
                      final newPass = newCtrl.text;
                      final confirm = confirmCtrl.text;

                      if (newPass.length < 6) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content: Text('Kata sandi baru minimal 6 karakter.')));
                        return;
                      }
                      if (newPass != confirm) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content: Text('Konfirmasi kata sandi tidak cocok.')));
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        final result = await AuthService.changePassword(
                          currentPassword: current,
                          newPassword: newPass,
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (result['status'] == true) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: const Text('Kata sandi berhasil diperbarui!'),
                            backgroundColor: AppTheme.success,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ));
                        } else {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text(AppErrors.messageFromResult(result,
                                fallback: 'Gagal memperbarui kata sandi.')),
                            backgroundColor: AppTheme.error,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ));
                        }
                      } catch (e) {
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text(AppErrors.friendly(e)),
                          backgroundColor: AppTheme.error,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ));
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Kreavana',
      applicationVersion: '1.0.0',
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset('assets/brandlogo.png', width: 48, height: 48,
            errorBuilder: (_, _, _) => const Icon(Icons.auto_awesome, size: 48, color: AppTheme.primaryPurple)),
      ),
      children: const [
        Text('Platform kolaborasi kreatif yang menghubungkan kreator konten dengan klien di seluruh Indonesia.'),
        SizedBox(height: 8),
        Text('© 2025 Kreavana ID. All rights reserved.', style: TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  final String? subRole;
  const _RoleBadge({required this.role, this.subRole});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    if (role == 'admin') {
      color = AppTheme.error;
      label = 'Administrator';
    } else if (role == 'creator') {
      color = AppTheme.success;
      label = subRole ?? 'Kreator';
    } else {
      color = AppTheme.primaryPurple;
      label = subRole ?? 'Klien';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
