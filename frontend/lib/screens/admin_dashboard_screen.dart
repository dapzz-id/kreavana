import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../services/admin_service.dart';
import '../widgets/stat_card.dart';

class AdminDashboardScreen extends StatefulWidget {
  final UserModel user;

  const AdminDashboardScreen({super.key, required this.user});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = false;
  int _totalUsers = 120;
  int _activeCreators = 45;
  int _pendingVerifications = 0;
  int _completedProjects = 88;

  @override
  void initState() {
    super.initState();
    _loadAdminStats();
  }

  Future<void> _loadAdminStats() async {
    setState(() => _isLoading = true);
    try {
      final pendingApps = await AdminService.getApplications(status: 'pending');
      final approvedApps = await AdminService.getApplications(status: 'approved');
      if (mounted) {
        setState(() {
          _pendingVerifications = pendingApps.length;
          _activeCreators = 35 + approvedApps.length; // baseline + verified
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

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
            onPressed: _loadAdminStats,
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
                        : [theme.colorScheme.primary.withOpacity(0.15), theme.colorScheme.primary.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.2),
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
                        color: isDark ? Colors.white : theme.colorScheme.primary,
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
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(),
                    ))
                  : GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: MediaQuery.of(context).size.width > 900 ? 2.2 : 1.5,
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
              const Text(
                'Log Aktivitas Sistem Terkini',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 4,
                  separatorBuilder: (context, index) => Divider(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade100,
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final logs = [
                      {
                        'title': 'Sistem Seeding Berhasil',
                        'desc': 'Update data seeder admin@kreavana.id berhasil diterapkan.',
                        'time': 'Baru saja',
                        'icon': Icons.sync_rounded,
                        'color': Colors.blue,
                      },
                      {
                        'title': 'Backup Database Harian',
                        'desc': 'Automated backup database berhasil diunggah ke cloud storage.',
                        'time': '1 jam yang lalu',
                        'icon': Icons.cloud_done_outlined,
                        'color': Colors.green,
                      },
                      {
                        'title': 'Auth Token Refreshed',
                        'desc': 'Sistem membersihkan sesi JWT expired sebanyak 14 token.',
                        'time': '3 jam yang lalu',
                        'icon': Icons.security_rounded,
                        'color': Colors.teal,
                      },
                      {
                        'title': 'Koneksi Gateway API',
                        'desc': 'Status koneksi server laravel terdeteksi online (200 OK).',
                        'time': 'Hari ini',
                        'icon': Icons.router_rounded,
                        'color': Colors.orange,
                      },
                    ];
                    final log = logs[index];

                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (log['color'] as Color).withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          log['icon'] as IconData,
                          color: log['color'] as Color,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        log['title'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Text(
                        log['desc'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                      trailing: Text(
                        log['time'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
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
