import 'package:flutter/material.dart';
import '../../app/theme.dart';

class TimHakAksesScreen extends StatelessWidget {
  const TimHakAksesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final tim = [
      {'name': 'Budi Santoso', 'role': 'Administrator', 'email': 'budi@kominfo.go.id', 'role_color': Color(0xFFEF4444), 'isOnline': true},
      {'name': 'Siti Rahayu', 'role': 'Editor', 'email': 'siti@kominfo.go.id', 'role_color': Color(0xFF3B82F6), 'isOnline': true},
      {'name': 'Ahmad Fauzi', 'role': 'Viewer', 'email': 'ahmad@kominfo.go.id', 'role_color': Color(0xFF10B981), 'isOnline': false},
      {'name': 'Dewi Lestari', 'role': 'Editor', 'email': 'dewi@kominfo.go.id', 'role_color': Color(0xFF3B82F6), 'isOnline': true},
      {'name': 'Rizky Pratama', 'role': 'Viewer', 'email': 'rizky@kominfo.go.id', 'role_color': Color(0xFF10B981), 'isOnline': false},
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: const Text('Tim & Hak Akses', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.person_add_outlined, size: 16),
              label: const Text('Undang Anggota'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardBg : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
            ),
            child: Row(
              children: [
                _buildRoleStat('Admin', '1', Color(0xFFEF4444), isDark),
                _buildRoleStat('Editor', '2', Color(0xFF3B82F6), isDark),
                _buildRoleStat('Viewer', '2', Color(0xFF10B981), isDark),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: tim.length,
              itemBuilder: (context, index) {
                final t = tim[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardBg : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: (t['role_color'] as Color).withValues(alpha: 0.1),
                        child: Text(
                          (t['name'] as String).split(' ').map((n) => n[0]).join(),
                          style: TextStyle(color: t['role_color'] as Color, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(t['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(width: 6),
                                if (t['isOnline'] as bool)
                                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(t['email'] as String, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : Colors.grey.shade500)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: (t['role_color'] as Color).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                        child: Text(t['role'] as String, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: t['role_color'] as Color)),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {},
                        icon: Icon(Icons.more_vert, size: 18, color: isDark ? AppTheme.textMuted : Colors.grey.shade500),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleStat(String role, String count, Color color, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Text(count, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(role, style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMuted : Colors.grey.shade600)),
        ],
      ),
    );
  }
}
