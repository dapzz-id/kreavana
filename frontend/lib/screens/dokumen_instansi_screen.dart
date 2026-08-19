import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../models/user_model.dart';
import '../widgets/desktop_sidebar_layout.dart';

class DokumenInstansiScreen extends StatelessWidget {
  final UserModel? user;
  final ValueChanged<UserModel>? onUserUpdated;

  const DokumenInstansiScreen({super.key, this.user, this.onUserUpdated});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final List<Map<String, dynamic>> dokumen = [];

    final content = Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: const Text(
          'Dokumen Instansi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: dokumen.length,
        itemBuilder: (context, index) {
          final d = dokumen[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardBg : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: (d['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    (d['icon'] as IconData?) ?? Icons.image_outlined,
                    color: d['color'] as Color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d['name'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${d['size']} · ${d['date']}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppTheme.textMuted
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: Icon(
                    Icons.download_outlined,
                    size: 20,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
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
        activeRoute: 'dokumen_instansi',
        onUserUpdated: onUserUpdated,
        child: content,
      );
    }

    return content;
  }
}
