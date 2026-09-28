import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../models/user_model.dart';
import '../../../services/admin_service.dart';
import '../../../widgets/stat_card.dart';
import '../../../widgets/skeleton_box.dart';
import '../../../widgets/app_sweet_alert.dart';

class AdminDashboardScreen extends StatefulWidget {
  final UserModel user;

  const AdminDashboardScreen({super.key, required this.user});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = false;
  int _totalUsers = 0;
  int _activeCreators = 0;
  int _pendingVerifications = 0;
  int _completedProjects = 0;
  int _activeOpportunities = 0;
  int _openDisputes = 0;
  List<Map<String, dynamic>> _systemLogs = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadAdminStats();
    // Auto-refresh setiap 15 detik agar dashboard realtime
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        _loadAdminStats(isSilent: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAdminStats({bool isSilent = false, bool showToast = false}) async {
    if (!isSilent) setState(() => _isLoading = true);
    try {
      final summaryFuture =
          AdminService.getDashboardSummary().catchError((_) => <String, dynamic>{});
      final pendingAppsFuture = AdminService.getApplications(status: 'pending')
          .catchError((_) => <CreatorApplication>[]);
      final logsFuture =
          AdminService.getSystemLogs().catchError((_) => <Map<String, dynamic>>[]);

      final results = await Future.wait([
        summaryFuture,
        pendingAppsFuture,
        logsFuture,
      ]);
      final summary = results[0] as Map<String, dynamic>;
      final pendingApps = results[1] as List;
      final logs = results[2] as List<Map<String, dynamic>>;
      if (mounted) {
        setState(() {
          _totalUsers = (summary['total_users'] as num?)?.toInt() ?? _totalUsers;
          _activeCreators = (summary['active_creators'] as num?)?.toInt() ?? _activeCreators;
          _completedProjects = (summary['completed_projects'] as num?)?.toInt() ?? _completedProjects;
          _activeOpportunities = (summary['active_opportunities'] as num?)?.toInt() ?? _activeOpportunities;
          _openDisputes = (summary['open_disputes'] as num?)?.toInt() ?? _openDisputes;
          _pendingVerifications =
              (summary['pending_applications'] as num?)?.toInt() ?? pendingApps.length;
          _systemLogs = logs;
          _isLoading = false;
        });

        if (showToast) {
          AppSweetAlert.success(
            context,
            'Data dasbor berhasil diperbarui secara realtime.',
            title: 'Dasbor Terkini',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'authentication':
        return Icons.security_rounded;
      case 'backup':
        return Icons.cloud_done_outlined;
      case 'system':
        return Icons.sync_rounded;
      case 'network':
        return Icons.router_rounded;
      case 'payment':
        return Icons.payment;
      case 'dispute':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'authentication':
        return Colors.teal;
      case 'backup':
        return Colors.green;
      case 'system':
        return Colors.blue;
      case 'network':
        return Colors.orange;
      case 'payment':
        return Colors.purple;
      case 'dispute':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'Baru saja';
      if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
      if (diff.inDays < 1) return '${diff.inHours} jam lalu';
      return '${diff.inDays} hari lalu';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: const Text(
          'Dasbor Administrasi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Dasbor',
            onPressed: () => _loadAdminStats(showToast: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAdminStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF312E81), const Color(0xFF1E1B4B)]
                        : [
                            theme.colorScheme.primary.withValues(alpha: 0.15),
                            theme.colorScheme.primary.withValues(alpha: 0.05),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selamat Datang, Admin!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.white
                            : theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Anda login sebagai Admin Utama. Gunakan panel ini untuk mengelola ekosistem peluang, memoderasi platform, dan memverifikasi pengajuan kreator.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Stats Grid title
              const Text(
                'Ecosystem & System Health Overview',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // GridView stats
              _isLoading
                  ? GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: MediaQuery.of(context).size.width > 900
                            ? 4
                            : 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio:
                            MediaQuery.of(context).size.width > 900 ? 2.2 : 1.5,
                      ),
                      itemCount: 4,
                      itemBuilder: (context, index) => const StatCardSkeleton(),
                    )
                  : GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: MediaQuery.of(context).size.width > 900
                          ? 4
                          : 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: MediaQuery.of(context).size.width > 900
                          ? 2.2
                          : 1.5,
                      children: [
                        StatCard(
                          label: 'Pengguna Terdaftar',
                          value: _totalUsers.toString(),
                          iconName: 'people',
                          accentColor: Colors.blue,
                        ),
                        StatCard(
                          label: 'Kreator Aktif',
                          value: _activeCreators.toString(),
                          iconName: 'verified',
                          accentColor: Colors.green,
                        ),
                        StatCard(
                          label: 'Verifikasi Pending',
                          value: _pendingVerifications.toString(),
                          iconName: 'hourglass_empty',
                          accentColor: Colors.orange,
                        ),
                        StatCard(
                          label: 'Proyek Berhasil',
                          value: _completedProjects.toString(),
                          iconName: 'check_circle',
                          accentColor: Colors.purple,
                        ),
                      ],
                    ),
              const SizedBox(height: 28),

              // Action logs / recent activities
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Log Aktivitas Sistem Terkini',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (_isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardBg : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                  ),
                ),
                child: _systemLogs.isEmpty && !_isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(
                          child: Text('Belum ada log aktivitas sistem'),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _systemLogs.length,
                        separatorBuilder: (context, index) => Divider(
                          color: isDark
                              ? AppTheme.inputBorder
                              : Colors.grey.shade100,
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final log = _systemLogs[index];
                          final type = log['type'] ?? 'info';
                          final icon = _getIconForType(type);
                          final color = _getColorForType(type);

                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: color, size: 20),
                            ),
                            title: Text(
                              log['title'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              log['description'] ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                            trailing: Text(
                              _formatTime(log['created_at']),
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade500,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
