import 'package:flutter/material.dart';
import '../services/badge_service.dart';
import '../screens/notifications_screen.dart';
import '../screens/direct_message_screen.dart';

class AppBarBadgeWidget extends StatelessWidget {
  final IconData icon;
  final bool isDark;

  const AppBarBadgeWidget({super.key, required this.icon, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isNotification = icon == Icons.notifications_none_outlined || icon == Icons.notifications_outlined;
    
    return ListenableBuilder(
      listenable: BadgeService(),
      builder: (context, _) {
        final countStr = isNotification ? BadgeService().unreadNotificationsText : BadgeService().unreadMessagesText;
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => isNotification
                    ? const NotificationsScreen(userId: 'current') // ID is passed correctly elsewhere usually, or we can handle it
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
                if (countStr.isNotEmpty && countStr != '0')
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
                        countStr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
