import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../models/user_model.dart';
import '../widgets/desktop_sidebar_layout.dart';

class PengumumanPublikScreen extends StatelessWidget {
  final UserModel? user;
  final ValueChanged<UserModel>? onUserUpdated;

  const PengumumanPublikScreen({super.key, this.user, this.onUserUpdated});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final List<Map<String, dynamic>> pengumuman = [];

    final content = Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: const Text(
          'Pengumuman Publik',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: pengumuman.length,
        itemBuilder: (context, index) {
          final p = pengumuman[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
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
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (p['type_color'] as Color).withValues(
                          alpha: 0.1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        (p['icon'] as IconData?) ?? Icons.image_outlined,
                        color: p['type_color'] as Color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['title'] as String,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 10,
                                color: isDark
                                    ? AppTheme.textMuted
                                    : Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                p['date'] as String,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppTheme.textMuted
                                      : Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: (p['type_color'] as Color).withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  p['type'] as String,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: p['type_color'] as Color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  p['description'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Baca Selengkapnya',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (user != null) {
      return DesktopSidebarLayout(
        user: user!,
        activeRoute: 'pengumuman_publik',
        onUserUpdated: onUserUpdated,
        child: content,
      );
    }

    return content;
  }
}
