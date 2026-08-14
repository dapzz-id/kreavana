import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app/theme.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../services/chat_service.dart';
import '../services/badge_service.dart';
import '../utils/app_errors.dart';
import '../widgets/app_empty_state.dart';

import '../widgets/skeleton/skeleton_list.dart';

class NotificationsScreen extends StatefulWidget {
  final String userId;

  const NotificationsScreen({super.key, required this.userId});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String _filter = 'all'; // all, unread, read

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    BadgeService().markNotificationsRead();
    _loadNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final result = await NotificationService.getNotifications(widget.userId);
      if (mounted && result.success == true && result.notifications != null) {
        setState(() {
          _notifications = result.notifications!;
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllAsRead() async {
    final ok = await NotificationService.markAsRead(widget.userId);
    if (!mounted) return;
    if (!ok) {
      AppSnackbar.error(context, 'Gagal menandai notifikasi. Coba lagi.');
      return;
    }
    setState(() {
      for (var n in _notifications) {
        n.isRead = true;
      }
    });
    AppSnackbar.success(context, 'Semua notifikasi ditandai dibaca');
  }

  Future<void> _deleteNotification(NotificationModel notif) async {
    final ok = await NotificationService.deleteNotification(notif.id);
    if (!mounted) return;
    if (!ok) {
      AppSnackbar.error(context, 'Gagal menghapus notifikasi.');
      return;
    }
    setState(() => _notifications.removeWhere((n) => n.id == notif.id));
    AppSnackbar.success(context, 'Notifikasi dihapus');
  }

  Future<void> _deleteAllNotifications() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Semua Notifikasi?'),
        content: const Text('Semua notifikasi akan dihapus permanen. Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final ok = await NotificationService.deleteAllNotifications();
    if (!mounted) return;
    if (!ok) {
      AppSnackbar.error(context, 'Gagal menghapus notifikasi.');
      return;
    }
    setState(() => _notifications.clear());
    AppSnackbar.success(context, 'Semua notifikasi dihapus');
  }

  List<NotificationModel> get _filteredNotifications {
    final tabFilter = ['all', 'project', 'message', 'transaction'];
    final currentTab = tabFilter[_tabController.index];

    List<NotificationModel> list;
    if (currentTab == 'project') {
      list = _notifications.where((n) => n.type == 'project' || n.type == 'opportunity' || n.type == 'creator_applied' || n.type == 'creator_approved' || n.type == 'creator_rejected').toList();
    } else if (currentTab == 'message') {
      list = _notifications.where((n) => n.type == 'message' || n.type == 'chat').toList();
    } else if (currentTab == 'transaction') {
      list = _notifications.where((n) => n.type == 'payment' || n.type == 'transaction' || n.type == 'wallet').toList();
    } else {
      list = _notifications;
    }

    switch (_filter) {
      case 'unread':
        return list.where((n) => !n.isRead).toList();
      case 'read':
        return list.where((n) => n.isRead).toList();
      default:
        return list;
    }
  }

  Map<String, List<NotificationModel>> get _groupedNotifications {
    final Map<String, List<NotificationModel>> grouped = {
      'Hari Ini': [],
      'Kemarin': [],
      'Minggu Ini': [],
      'Lebih Lama': [],
    };
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    for (var notif in _filteredNotifications) {
      final dt = DateTime.tryParse(notif.createdAt) ?? now;
      if (dt.isAfter(today)) {
        grouped['Hari Ini']!.add(notif);
      } else if (dt.isAfter(yesterday)) {
        grouped['Kemarin']!.add(notif);
      } else if (dt.isAfter(weekAgo)) {
        grouped['Minggu Ini']!.add(notif);
      } else {
        grouped['Lebih Lama']!.add(notif);
      }
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Notifikasi', style: TextStyle(fontWeight: FontWeight.bold)),
            if (unreadCount > 0)
              Text('$unreadCount belum dibaca',
                  style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter notifikasi',
            onSelected: (value) {
              if (value == 'delete_all') {
                _deleteAllNotifications();
              } else {
                setState(() => _filter = value);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'all', child: Row(children: [
                Icon(_filter == 'all' ? Icons.check : Icons.circle_outlined, size: 18, color: AppTheme.primaryPurple),
                const SizedBox(width: 10),
                const Text('Semua'),
              ])),
              PopupMenuItem(value: 'unread', child: Row(children: [
                Icon(_filter == 'unread' ? Icons.check : Icons.circle_outlined, size: 18, color: AppTheme.primaryPurple),
                const SizedBox(width: 10),
                const Text('Belum Dibaca'),
              ])),
              PopupMenuItem(value: 'read', child: Row(children: [
                Icon(_filter == 'read' ? Icons.check : Icons.circle_outlined, size: 18, color: AppTheme.primaryPurple),
                const SizedBox(width: 10),
                const Text('Sudah Dibaca'),
              ])),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'delete_all', child: Row(children: [
                const Icon(Icons.delete_sweep_outlined, size: 18, color: Colors.red),
                const SizedBox(width: 10),
                const Text('Hapus Semua', style: TextStyle(color: Colors.red)),
              ])),
            ],
          ),
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Tandai Semua'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.primaryPurple),
            ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            onTap: (_) => setState(() {}),
            tabs: const [
              Tab(icon: Icon(Icons.notifications_active_outlined, size: 18), text: 'Semua'),
              Tab(icon: Icon(Icons.work_outline, size: 18), text: 'Proyek'),
              Tab(icon: Icon(Icons.chat_bubble_outline, size: 18), text: 'Pesan'),
              Tab(icon: Icon(Icons.payments_outlined, size: 18), text: 'Transaksi'),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const SkeletonList()
          : _filteredNotifications.isEmpty
              ? AppEmptyState(
                  icon: _filter == 'unread' ? Icons.mark_email_read_outlined : Icons.notifications_none,
                  title: _filter == 'unread' ? 'Semua Sudah Dibaca!' : 'Belum Ada Notifikasi',
                  subtitle: _filter == 'unread'
                      ? 'Anda sudah membaca semua notifikasi.'
                      : 'Notifikasi akan muncul di sini ketika ada aktivitas baru.',
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                    itemCount: _groupedNotifications.entries.where((e) => e.value.isNotEmpty).length,
                    itemBuilder: (context, sectionIndex) {
                      final entries = _groupedNotifications.entries.where((e) => e.value.isNotEmpty).toList();
                      final entry = entries[sectionIndex];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, top: 8, bottom: 10),
                            child: Text(
                              entry.key.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          ...entry.value.map((notif) => _buildNotificationCard(notif, isDark)),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notif, bool isDark) {
    final icon = _getIconForType(notif.type);
    final iconColor = _getColorForType(notif.type);
    final formattedDate = _formatFullDate(notif.createdAt);

    return Dismissible(
      key: Key(notif.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Hapus Notifikasi?'),
            content: const Text('Notifikasi ini akan dihapus permanen.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text('Hapus'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) => _deleteNotification(notif),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: notif.isRead
              ? (isDark ? AppTheme.cardDark : Colors.white)
              : (isDark ? AppTheme.cardDark2 : const Color(0xFFF5F3FF)),
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(
            color: notif.isRead
                ? (isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight)
                : AppTheme.primaryPurple.withValues(alpha: 0.25),
            width: notif.isRead ? 1 : 1.5,
          ),
          boxShadow: isDark ? null : AppTheme.cardShadowLight,
        ),
        child: InkWell(
          onTap: () {
            if (!notif.isRead) {
              setState(() => notif.isRead = true);
            }
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notif.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!notif.isRead) const AppDot(size: 8),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notif.body,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppTheme.textMuted.withValues(alpha: 0.7) : AppTheme.textMutedLight.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (notif.type == 'group_invite' || notif.type == 'group') ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () async {
                                final chatId = notif.data != null ? notif.data!['chat_id']?.toString() : null;
                                if (chatId != null && chatId.isNotEmpty) {
                                  try {
                                    await ChatService.respondInvitation(chatId, true);
                                    if (context.mounted) {
                                      AppSnackbar.success(context, 'Berhasil bergabung dengan grup!');
                                      _loadNotifications();
                                    }
                                  } catch (_) {}
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryPurple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Setujui', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () async {
                                final chatId = notif.data != null ? notif.data!['chat_id']?.toString() : null;
                                if (chatId != null && chatId.isNotEmpty) {
                                  try {
                                    await ChatService.respondInvitation(chatId, false);
                                    if (context.mounted) {
                                      AppSnackbar.info(context, 'Undangan grup ditolak');
                                      _loadNotifications();
                                    }
                                  } catch (_) {}
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Tolak', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'project':
      case 'opportunity':
        return Icons.work_outline;
      case 'message':
      case 'chat':
        return Icons.chat_bubble_outline;
      case 'payment':
      case 'transaction':
      case 'wallet':
        return Icons.payments_outlined;
      case 'system':
        return Icons.settings_outlined;
      case 'alert':
        return Icons.warning_amber_outlined;
      case 'creator_applied':
      case 'creator_approved':
      case 'creator_rejected':
        return Icons.person_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'project':
      case 'opportunity':
        return const Color(0xFF10B981);
      case 'message':
      case 'chat':
        return const Color(0xFF3B82F6);
      case 'payment':
      case 'transaction':
      case 'wallet':
        return const Color(0xFFF59E0B);
      case 'system':
        return const Color(0xFF6366F1);
      case 'alert':
        return AppTheme.error;
      case 'creator_applied':
      case 'creator_approved':
        return const Color(0xFF10B981);
      case 'creator_rejected':
        return const Color(0xFFEF4444);
      default:
        return AppTheme.primaryPurple;
    }
  }

  String _formatFullDate(String? createdAt) {
    if (createdAt == null) return '';
    try {
      final dt = DateTime.parse(createdAt);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final notifDate = DateTime(dt.year, dt.month, dt.day);
      final diff = today.difference(notifDate).inDays;

      final timeStr = DateFormat('HH:mm').format(dt);

      if (diff == 0) {
        return 'Hari ini, $timeStr';
      } else if (diff == 1) {
        return 'Kemarin, $timeStr';
      } else if (diff < 7) {
        final dayName = DateFormat('EEEE', 'id_ID').format(dt);
        return '$dayName, $timeStr';
      } else {
        return DateFormat('d MMMM yyyy, HH:mm', 'id_ID').format(dt);
      }
    } catch (_) {
      return '';
    }
  }
}
