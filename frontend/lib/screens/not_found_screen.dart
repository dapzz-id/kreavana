import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../services/app_router.dart';
import '../services/user_store.dart';
import '../widgets/desktop_sidebar_layout.dart';

class NotFoundScreen extends StatelessWidget {
  final String? title;
  final String? message;
  final String? path;
  final VoidCallback? onBack;
  final UserModel? user;

  const NotFoundScreen({
    super.key,
    this.title,
    this.message,
    this.path,
    this.onBack,
    this.user,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveUser = user ?? currentUserNotifier.value;

    final body = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardBg : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 404 Badge Icon
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.travel_explore_rounded,
                    size: 46,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // 404 Status Code
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                  ),
                ),
                child: const Text(
                  '404 / AKSES DIBATASI',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title ?? 'Halaman Tidak Tersedia',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message ??
                    'Halaman yang Anda tuju tidak ditemukan, telah dipindahkan, atau peran akun Anda saat ini tidak memiliki hak akses ke fitur ini.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                ),
              ),
              if (path != null && path!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1B38) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    path!,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      if (onBack != null) {
                        onBack!();
                      } else {
                        context.go(AppRoutes.beranda);
                      }
                    },
                    icon: const Icon(Icons.home_outlined, size: 18),
                    label: const Text('Kembali ke Beranda'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                  if (effectiveUser == null || effectiveUser.isGuest) ...[
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => context.go(AppRoutes.login),
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: const Text('Masuk Akun'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4F46E5),
                        side: const BorderSide(color: Color(0xFF4F46E5)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (effectiveUser != null && !effectiveUser.isGuest) {
      return DesktopSidebarLayout(
        user: effectiveUser,
        activeRoute: 'not_found',
        child: Scaffold(
          backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFF8FAFC),
          body: body,
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFF8FAFC),
      body: body,
    );
  }
}
