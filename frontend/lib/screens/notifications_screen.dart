import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../app/subrole_theme_engine.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';
import '../services/chat_service.dart';
import '../services/badge_service.dart';
import '../services/user_store.dart';
import '../utils/app_errors.dart';
import '../widgets/desktop_sidebar_layout.dart';
import '../widgets/skeleton/skeleton_list.dart';
import 'direct_message_screen.dart';
import 'proyek_saya_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final String userId;
  final UserModel? user;

  const NotificationsScreen({
    super.key,
    required this.userId,
    this.user,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
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
    } catch (_) {
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
    BadgeService().markNotificationsRead();
    AppSnackbar.success(context, 'Semua notifikasi ditandai sudah dibaca');
  }

  Future<void> _deleteNotification(NotificationModel notif) async {
    final ok = await NotificationService.deleteNotification(notif.id);
    if (!mounted) return;
    if (!ok) {
      AppSnackbar.error(context, 'Gagal menghapus notifikasi.');
      return;
    }
    setState(() => _notifications.removeWhere((n) => n.id == notif.id));
    AppSnackbar.success(context, 'Notifikasi berhasil dihapus');
  }

  Future<void> _deleteAllNotifications() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Semua Notifikasi?'),
        content: const Text(
          'Semua notifikasi akan dihapus permanen dari sistem. Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
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
    AppSnackbar.success(context, 'Seluruh notifikasi berhasil dibersihkan');
  }

  List<NotificationModel> get _filteredNotifications {
    final tabFilter = ['all', 'project', 'message', 'transaction'];
    final currentTab = tabFilter[_tabController.index];

    List<NotificationModel> list;
    if (currentTab == 'project') {
      list = _notifications
          .where(
            (n) =>
                n.type == 'project' ||
                n.type == 'opportunity' ||
                n.type == 'contract' ||
                n.type == 'creator_applied' ||
                n.type == 'creator_approved' ||
                n.type == 'creator_rejected',
          )
          .toList();
    } else if (currentTab == 'message') {
      list = _notifications
          .where((n) => n.type == 'message' || n.type == 'chat')
          .toList();
    } else if (currentTab == 'transaction') {
      list = _notifications
          .where(
            (n) =>
                n.type == 'payment' ||
                n.type == 'transaction' ||
                n.type == 'wallet',
          )
          .toList();
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
      final dt = DateTime.tryParse(notif.createdAt)?.toLocal() ?? now;
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

  String _formatRelativeTime(String? createdAt) {
    if (createdAt == null || createdAt.isEmpty) return 'Baru saja';
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inSeconds < 60) return 'Baru saja';
      if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
      if (diff.inHours < 24) return '${diff.inHours} jam lalu';
      if (diff.inDays == 1) {
        final h = dt.hour.toString().padLeft(2, '0');
        final m = dt.minute.toString().padLeft(2, '0');
        return 'Kemarin, $h:$m';
      }
      if (diff.inDays < 7) return '${diff.inDays} hari lalu';

      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m';
    } catch (_) {
      return 'Baru saja';
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'project':
      case 'contract':
        return Icons.business_center_rounded;
      case 'opportunity':
        return Icons.campaign_rounded;
      case 'message':
      case 'chat':
        return Icons.chat_bubble_rounded;
      case 'payment':
      case 'transaction':
      case 'wallet':
        return Icons.account_balance_wallet_rounded;
      case 'system':
        return Icons.notifications_active_rounded;
      case 'alert':
        return Icons.warning_amber_rounded;
      case 'creator_applied':
      case 'creator_approved':
      case 'client_verified':
        return Icons.verified_user_rounded;
      case 'creator_rejected':
      case 'client_rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'project':
      case 'contract':
        return const Color(0xFF10B981);
      case 'opportunity':
        return const Color(0xFF2563EB);
      case 'message':
      case 'chat':
        return const Color(0xFF0284C7);
      case 'payment':
      case 'transaction':
      case 'wallet':
        return const Color(0xFFF59E0B);
      case 'system':
        return const Color(0xFF1D4ED8);
      case 'alert':
      case 'creator_rejected':
      case 'client_rejected':
        return const Color(0xFFEF4444);
      case 'creator_applied':
      case 'creator_approved':
      case 'client_verified':
        return const Color(0xFF0D9488);
      default:
        return const Color(0xFF2563EB);
    }
  }

  String _getCategoryLabel(String type) {
    switch (type) {
      case 'project':
      case 'contract':
        return 'Proyek & Kontrak';
      case 'opportunity':
        return 'Tender & Peluang';
      case 'message':
      case 'chat':
        return 'Pesan Masuk';
      case 'payment':
      case 'transaction':
      case 'wallet':
        return 'Transaksi & Escrow';
      case 'system':
        return 'Info Sistem';
      case 'alert':
        return 'Peringatan Akun';
      case 'creator_applied':
      case 'creator_approved':
      case 'client_verified':
        return 'Verifikasi Resmi';
      default:
        return 'Aktivitas Ekosistem';
    }
  }

  void _handleNotificationAction(NotificationModel notif) {
    if (!notif.isRead) {
      setState(() => notif.isRead = true);
      NotificationService.markAsRead(widget.userId);
      BadgeService().markNotificationsRead();
    }

    if (notif.type == 'message' || notif.type == 'chat') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DirectMessageScreen()),
      );
    } else if (notif.type == 'project' || notif.type == 'contract' || notif.type == 'opportunity') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProyekSayaScreen(user: widget.user),
        ),
      );
    }
  }

  // ── EXECUTIVE HERO BANNER ──────────────────────────────────────────────────
  Widget _buildHeaderHero(bool isDark) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : [const Color(0xFF1E3A8A), const Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 620;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bolt_rounded, color: Colors.amberAccent, size: 14),
                                  SizedBox(width: 6),
                                  Text(
                                    'Pusat Aktivitas & Notifikasi Terpadu',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (unreadCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$unreadCount Belum Dibaca',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Pusat Notifikasi',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pantau seluruh aktivitas proyek, komunikasi pesan masuk, transaksi escrow, dan pengumuman sistem secara real-time.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isCompact) ...[
                    const SizedBox(width: 16),
                    Row(
                      children: [
                        if (unreadCount > 0) ...[
                          ElevatedButton.icon(
                            onPressed: _markAllAsRead,
                            icon: const Icon(Icons.done_all_rounded, size: 16, color: Color(0xFF1E3A8A)),
                            label: const Text('Tandai Dibaca', style: TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold, fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        OutlinedButton.icon(
                          onPressed: _deleteAllNotifications,
                          icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: Colors.white),
                          label: const Text('Hapus Semua', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white38),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              if (isCompact) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (unreadCount > 0)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _markAllAsRead,
                          icon: const Icon(Icons.done_all_rounded, size: 16, color: Color(0xFF1E3A8A)),
                          label: const Text('Tandai Dibaca', style: TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold, fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    if (unreadCount > 0) const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _deleteAllNotifications,
                      icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: Colors.white),
                      label: const Text('Hapus Semua', style: TextStyle(color: Colors.white, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // ── KPI SUMMARY CARDS ──────────────────────────────────────────────────────
  Widget _buildKpiRow(bool isDark) {
    final total = _notifications.length;
    final unread = _notifications.where((n) => !n.isRead).length;
    final msgCount = _notifications.where((n) => n.type == 'message' || n.type == 'chat').length;
    final projCount = _notifications.where((n) => n.type == 'project' || n.type == 'contract' || n.type == 'opportunity' || n.type == 'payment').length;

    final kpis = [
      {'title': 'Total Notifikasi', 'value': total.toString(), 'icon': Icons.notifications_none_rounded, 'color': const Color(0xFF2563EB)},
      {'title': 'Belum Dibaca', 'value': unread.toString(), 'icon': Icons.mark_email_unread_outlined, 'color': unread > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)},
      {'title': 'Pesan & Diskusi', 'value': msgCount.toString(), 'icon': Icons.chat_bubble_outline_rounded, 'color': const Color(0xFF3B82F6)},
      {'title': 'Proyek & Transaksi', 'value': projCount.toString(), 'icon': Icons.assignment_outlined, 'color': const Color(0xFF0284C7)},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: kpis.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isWide ? 4 : 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: isWide ? 2.5 : 2.0,
            ),
            itemBuilder: (context, i) {
              final k = kpis[i];
              final col = k['color'] as Color;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardBg : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: col.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(k['icon'] as IconData, size: 20, color: col),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            k['title'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            k['value'] as String,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── NOTIFICATION CARD BUILDER ──────────────────────────────────────────────
  Widget _buildNotificationCard(NotificationModel notif, bool isDark) {
    final icon = _getIconForType(notif.type);
    final iconColor = _getColorForType(notif.type);
    final categoryLabel = _getCategoryLabel(notif.type);
    final timeFormatted = _formatRelativeTime(notif.createdAt);
    final isMessage = notif.type == 'message' || notif.type == 'chat';
    final isProject = notif.type == 'project' || notif.type == 'contract' || notif.type == 'opportunity';

    return Dismissible(
      key: Key(notif.id?.toString() ?? UniqueKey().toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      onDismissed: (_) => _deleteNotification(notif),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: notif.isRead
              ? (isDark ? AppTheme.cardBg : Colors.white)
              : (isDark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFF0F7FF)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notif.isRead
                ? (isDark ? AppTheme.inputBorder : Colors.grey.shade200)
                : const Color(0xFF2563EB).withValues(alpha: 0.35),
            width: notif.isRead ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: notif.isRead
                  ? Colors.black.withValues(alpha: 0.02)
                  : const Color(0xFF2563EB).withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _handleNotificationAction(notif),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Icon Avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Meta Row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                categoryLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: iconColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                timeFormatted,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Spacer(),
                            if (!notif.isRead) ...[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2563EB),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              iconSize: 18,
                              icon: Icon(Icons.more_vert, color: Colors.grey.shade500),
                              onSelected: (val) {
                                if (val == 'toggle_read') {
                                  setState(() => notif.isRead = !notif.isRead);
                                  if (notif.isRead) {
                                    NotificationService.markAsRead(widget.userId);
                                  }
                                } else if (val == 'delete') {
                                  _deleteNotification(notif);
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'toggle_read',
                                  child: Text(notif.isRead ? 'Tandai Belum Dibaca' : 'Tandai Sudah Dibaca'),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Hapus Notifikasi', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          notif.title,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notif.body,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
                          ),
                        ),
                        // Action row if applicable
                        if (isMessage || isProject || (notif.type == 'group_invite')) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              if (isMessage)
                                ElevatedButton.icon(
                                  onPressed: () => _handleNotificationAction(notif),
                                  icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                                  label: const Text('Buka Obrolan', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                ),
                              if (isProject)
                                ElevatedButton.icon(
                                  onPressed: () => _handleNotificationAction(notif),
                                  icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                                  label: const Text('Lihat Proyek', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                ),
                              if (notif.type == 'group_invite') ...[
                                ElevatedButton(
                                  onPressed: () async {
                                    final chatId = notif.data != null
                                        ? notif.data!['chat_id']?.toString()
                                        : null;
                                    if (chatId != null && chatId.isNotEmpty) {
                                      try {
                                        await ChatService.respondInvitation(chatId, true);
                                        if (mounted) {
                                          AppSnackbar.success(context, 'Berhasil bergabung dengan grup!');
                                          _loadNotifications();
                                        }
                                      } catch (_) {}
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Setujui', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () async {
                                    final chatId = notif.data != null
                                        ? notif.data!['chat_id']?.toString()
                                        : null;
                                    if (chatId != null && chatId.isNotEmpty) {
                                      try {
                                        await ChatService.respondInvitation(chatId, false);
                                        if (mounted) {
                                          AppSnackbar.info(context, 'Undangan grup ditolak');
                                          _loadNotifications();
                                        }
                                      } catch (_) {}
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: const BorderSide(color: Colors.redAccent),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Tolak', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                ),
                              ],
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    final effectiveUser = widget.user ?? currentUserNotifier.value;
    final isCorporate = effectiveUser != null &&
        ['corporate', 'company', 'business', 'perusahaan', 'bisnis']
            .contains(effectiveUser.subRole?.toLowerCase());
    final corporateColor = isCorporate
        ? const Color(0xFF2563EB)
        : SubRoleThemeEngine.getAccentColor(
            effectiveUser?.role,
            effectiveUser?.subRole,
          );

    final projCount = _notifications
        .where(
          (n) =>
              n.type == 'project' ||
              n.type == 'opportunity' ||
              n.type == 'contract' ||
              n.type == 'creator_applied',
        )
        .length;
    final msgCount = _notifications.where((n) => n.type == 'message' || n.type == 'chat').length;
    final transCount = _notifications.where((n) => n.type == 'payment' || n.type == 'transaction' || n.type == 'wallet').length;

    final scaffold = Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !isDesktop && Navigator.canPop(context),
        toolbarHeight: 70,
        titleSpacing: isDesktop ? 24 : 16,
        elevation: 0,
        title: Row(
          children: [
            const Text(
              'Notifikasi',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount Baru',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_rounded),
            tooltip: 'Filter Notifikasi',
            onSelected: (value) {
              if (value == 'delete_all') {
                _deleteAllNotifications();
              } else {
                setState(() => _filter = value);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(
                      _filter == 'all' ? Icons.radio_button_checked : Icons.radio_button_off,
                      size: 18,
                      color: const Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 10),
                    const Text('Semua Notifikasi'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'unread',
                child: Row(
                  children: [
                    Icon(
                      _filter == 'unread' ? Icons.radio_button_checked : Icons.radio_button_off,
                      size: 18,
                      color: const Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 10),
                    const Text('Hanya Belum Dibaca'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'read',
                child: Row(
                  children: [
                    Icon(
                      _filter == 'read' ? Icons.radio_button_checked : Icons.radio_button_off,
                      size: 18,
                      color: const Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 10),
                    const Text('Sudah Dibaca'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_outlined, size: 18, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Bersihkan Semua', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all, size: 16),
              label: const Text('Tandai Dibaca'),
            ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: corporateColor,
            indicatorWeight: 3,
            labelColor: corporateColor,
            unselectedLabelColor: isDark ? Colors.white60 : Colors.grey.shade600,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            onTap: (_) => setState(() {}),
            tabs: [
              Tab(
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined, size: 17),
                    const SizedBox(width: 6),
                    Text('Semua (${_notifications.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  children: [
                    const Icon(Icons.business_center_outlined, size: 17),
                    const SizedBox(width: 6),
                    Text('Proyek ($projCount)'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                    const SizedBox(width: 6),
                    Text('Pesan ($msgCount)'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  children: [
                    const Icon(Icons.payments_outlined, size: 17),
                    const SizedBox(width: 6),
                    Text('Transaksi ($transCount)'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const SkeletonList()
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1350),
                child: RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 20 : 16,
                      vertical: 8,
                    ).copyWith(bottom: 120),
                    children: [
                      _buildHeaderHero(isDark),
                      _buildKpiRow(isDark),
                      if (_filteredNotifications.isEmpty)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 30),
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.cardBg : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.notifications_none_rounded,
                                  size: 32,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _filter == 'unread'
                                    ? 'Semua Notifikasi Sudah Dibaca!'
                                    : 'Belum Ada Notifikasi di Kategori Ini',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _filter == 'unread'
                                    ? 'Tidak ada notifikasi baru yang memerlukan perhatian Anda saat ini.'
                                    : 'Aktivitas pesan, pembaruan proyek, dan transaksi akan muncul otomatis di sini.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 18),
                              ElevatedButton.icon(
                                onPressed: _loadNotifications,
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('Muat Ulang'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final entry in _groupedNotifications.entries.where((e) => e.value.isNotEmpty)) ...[
                                Padding(
                                  padding: const EdgeInsets.only(left: 4, top: 12, bottom: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 4,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2563EB),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        entry.key.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                for (final notif in entry.value)
                                  _buildNotificationCard(notif, isDark),
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

    if (isDesktop && effectiveUser != null) {
      return DesktopSidebarLayout(
        user: effectiveUser,
        activeRoute: 'notifikasi',
        child: scaffold,
      );
    }

    return scaffold;
  }
}
