import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app/theme.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../utils/app_errors.dart';
import '../widgets/app_empty_state.dart';

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

  List<NotificationModel> get _filteredNotifications {
    switch (_filter) {
      case 'unread':
        return _notifications.where((n) => !n.isRead).toList();
      case 'read':
        return _notifications.where((n) => n.isRead).toList();
      default:
        return _notifications;
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
              setState(() => _filter = value);
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
          ? const Center(child: CircularProgressIndicator())
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
    final timeDiff = _formatTimeDiff(notif.createdAt);

    return Container(
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
              // Icon
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
              // Content
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
                    Text(
                      timeDiff,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppTheme.textMuted.withValues(alpha: 0.7) : AppTheme.textMutedLight.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
        return Icons.payments_outlined;
      case 'system':
        return Icons.settings_outlined;
      case 'alert':
        return Icons.warning_amber_outlined;
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
        return const Color(0xFFF59E0B);
      case 'system':
        return const Color(0xFF6366F1);
      case 'alert':
        return AppTheme.error;
      default:
        return AppTheme.primaryPurple;
    }
  }

  String _formatTimeDiff(String? createdAt) {
    if (createdAt == null) return '';
    try {
      final dt = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Baru saja';
      if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
      if (diff.inHours < 24) return '${diff.inHours} jam lalu';
      if (diff.inDays < 7) return '${diff.inDays} hari lalu';
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt);
    } catch (_) {
      return '';
    }
  }
}
