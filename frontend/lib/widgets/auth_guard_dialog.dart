import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/theme.dart';
import '../services/app_router.dart';
import '../services/user_store.dart';

/// Dialog pop-up ramah pengguna bergaya e-commerce (seperti Shopee / Tokopedia)
/// untuk memberitahu tamu bahwa aksi tertentu memerlukan login / registrasi.
class AuthGuardDialog extends StatelessWidget {
  final String actionName;

  const AuthGuardDialog({
    super.key,
    required this.actionName,
  });

  /// Cek apakah user saat ini sudah login.
  /// Jika belum (tamu/null), otomatis memunculkan dialog dan mengembalikan `false`.
  /// Jika sudah login, langsung mengembalikan `true`.
  static Future<bool> check(
    BuildContext context, {
    required String actionName,
  }) async {
    final user = currentUserNotifier.value;
    if (user != null && !user.isGuest) {
      return true;
    }

    await show(context, actionName: actionName);
    return false;
  }

  /// Tampilkan dialog langsung.
  static Future<bool?> show(
    BuildContext context, {
    required String actionName,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AuthGuardDialog(actionName: actionName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E1B38) : Colors.white,
      elevation: 12,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header Icon Badge ─────────────────────────────────────────
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_person_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),

              // ── Pill Tag ──────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'AKSES PENGGUNA TERDAFTAR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppTheme.accentPink : AppTheme.primaryPurple,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Title ─────────────────────────────────────────────────────
              Text(
                'Yuk, Masuk Terlebih Dahulu!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textDark,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),

              // ── Description ───────────────────────────────────────────────
              Text(
                'Untuk $actionName, silakan masuk ke akun Kreavana Anda atau daftar gratis dalam 1 menit.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                ),
              ),
              const SizedBox(height: 20),

              // ── Benefit Bullets ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF141224)
                      : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2D2A3E)
                        : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  children: [
                    _buildBenefitRow(
                      icon: Icons.chat_bubble_outline_rounded,
                      color: const Color(0xFF8B5CF6),
                      text: 'Chat & negosiasi langsung dengan kreator/klien',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    _buildBenefitRow(
                      icon: Icons.verified_user_outlined,
                      color: const Color(0xFF10B981),
                      text: 'Transaksi aman dengan proteksi garansi proyek',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    _buildBenefitRow(
                      icon: Icons.work_outline_rounded,
                      color: const Color(0xFF3B82F6),
                      text: 'Pasang kebutuhan proyek & pantau kemajuan',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Tombol Masuk Sekarang (Primary) ───────────────────────────
              Container(
                width: double.infinity,
                height: 46,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppTheme.primaryShadow,
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, true);
                    context.go(AppRoutes.login);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Masuk Sekarang',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Tombol Daftar Akun Baru (Outlined) ─────────────────────────
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context, true);
                    context.go(AppRoutes.register);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isDark
                          ? AppTheme.inputBorder
                          : AppTheme.primaryPurple.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    foregroundColor: isDark ? Colors.white : AppTheme.primaryPurple,
                  ),
                  child: const Text(
                    'Belum punya akun? Daftar Baru',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── Tombol Nanti Saja / Batal ──────────────────────────────────
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Lanjutkan Menjelajah Dulu',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitRow({
    required IconData icon,
    required Color color,
    required String text,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.grey.shade800,
            ),
          ),
        ),
      ],
    );
  }
}
