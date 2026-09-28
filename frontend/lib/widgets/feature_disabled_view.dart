import 'package:flutter/material.dart';
import '../app/theme.dart';

class FeatureDisabledView extends StatelessWidget {
  final String featureName;
  final IconData icon;
  final VoidCallback? onBackToHome;

  const FeatureDisabledView({
    super.key,
    required this.featureName,
    this.icon = Icons.lock_outline_rounded,
    this.onBackToHome,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2D2A3E)
                      : const Color(0xFFF3E8FF),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF4C1D95).withValues(alpha: 0.5)
                        : const Color(0xFFDDD6FE),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 40,
                    color: AppTheme.primaryPurple,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Fitur $featureName Dinonaktifkan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Fitur ini sedang dinonaktifkan sementara oleh administrator untuk pemeliharaan sistem atau pembaruan. Silakan kembali lagi nanti.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? AppTheme.textMuted : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              if (onBackToHome != null)
                ElevatedButton.icon(
                  onPressed: onBackToHome,
                  icon: const Icon(Icons.home_outlined, size: 18),
                  label: const Text('Kembali ke Beranda'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
