import 'dart:io';

void main() {
  final dir = Directory('lib/features/dashboard/screens');
  if (!dir.existsSync()) return;

  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.dart'));

  final searchPattern = RegExp(r'Widget _buildAppBarBadge\(IconData icon, String count, bool isDark\) \{.*?\n  \}', dotAll: true);
  
  final replacement = '''Widget _buildAppBarBadge(IconData icon, String count, bool isDark) {
    final isNotification = icon == Icons.notifications_none_outlined;
    return ListenableBuilder(
      listenable: BadgeService(),
      builder: (context, _) {
        final badgeCount = isNotification ? BadgeService().unreadNotificationsText : BadgeService().unreadMessagesText;
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => isNotification
                    ? NotificationsScreen(userId: _currentUser.id ?? '')
                    : const DirectMessageScreen(),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D2A3E) : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 20, color: isDark ? Colors.white : Colors.black87),
                if (badgeCount.isNotEmpty && badgeCount != '0')
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badgeCount,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }''';

  for (final file in files) {
    String content = file.readAsStringSync();
    if (content.contains('Widget _buildAppBarBadge(IconData icon, String count, bool isDark) {')) {
      if (!content.contains("import '../../../services/badge_service.dart';")) {
        content = "import '../../../services/badge_service.dart';\n" + content;
      }
      content = content.replaceFirst(searchPattern, replacement);
      file.writeAsStringSync(content);
      print('Updated ${file.path}');
    }
  }
}
