import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../services/admin_service.dart';

class AdminVerificationScreen extends StatefulWidget {
  const AdminVerificationScreen({super.key});

  @override
  State<AdminVerificationScreen> createState() => _AdminVerificationScreenState();
}

class _AdminVerificationScreenState extends State<AdminVerificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<CreatorApplication> _pendingApps = [];
  List<CreatorApplication> _approvedApps = [];
  List<CreatorApplication> _rejectedApps = [];

  final _rejectNoteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadApplications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _rejectNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadApplications() async {
    setState(() => _isLoading = true);
    try {
      final pApps = await AdminService.getApplications(status: 'pending');
      final aApps = await AdminService.getApplications(status: 'approved');
      final rApps = await AdminService.getApplications(status: 'rejected');

      if (mounted) {
        setState(() {
          _pendingApps = pApps;
          _approvedApps = aApps;
          _rejectedApps = rApps;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleApprove(int id) async {
    setState(() => _isLoading = true);
    final result = await AdminService.approveApplication(id);
    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengajuan kreator berhasil disetujui.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadApplications();
      } else {
        _showError(result['message'] ?? 'Gagal menyetujui pengajuan.');
      }
    }
  }

  void _showRejectDialog(int id) {
    _rejectNoteController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak Pengajuan Kreator'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Berikan alasan mengapa pengajuan ini ditolak:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rejectNoteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Misal: Link portofolio tidak aktif atau data tidak valid...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              final note = _rejectNoteController.text.trim();
              if (note.isEmpty) {
                _showError('Alasan penolakan wajib diisi!');
                return;
              }
              Navigator.pop(context);
              _handleReject(id, note);
            },
            child: const Text('Tolak', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _handleReject(int id, String note) async {
    setState(() => _isLoading = true);
    final result = await AdminService.rejectApplication(id, note);
    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengajuan kreator berhasil ditolak.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadApplications();
      } else {
        _showError(result['message'] ?? 'Gagal menolak pengajuan.');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildApplicationCard(CreatorApplication app, {bool showActions = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
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
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
                child: const Icon(Icons.person, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.pihakCategory.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.secondary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Nama Pemohon: (ID ${app.userId})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: app.status == 'approved'
                      ? Colors.green.shade100.withOpacity(0.8)
                      : (app.status == 'rejected' ? Colors.red.shade100.withOpacity(0.8) : Colors.orange.shade100.withOpacity(0.8)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  app.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: app.status == 'approved'
                        ? Colors.green.shade800
                        : (app.status == 'rejected' ? Colors.red.shade800 : Colors.orange.shade800),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Text(
            'Keahlian & Deskripsi:',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            app.skillDescription,
            style: const TextStyle(fontSize: 13, height: 1.3),
          ),
          const SizedBox(height: 12),
          Text(
            'Link Portofolio:',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            app.portfolioLink ?? 'Tidak dicantumkan',
            style: TextStyle(
              fontSize: 12,
              color: app.portfolioLink != null ? Colors.blue.shade600 : Colors.grey,
              decoration: app.portfolioLink != null ? TextDecoration.underline : null,
            ),
          ),
          if (app.experience != null && app.experience!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Pengalaman Kerja:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              app.experience!,
              style: const TextStyle(fontSize: 12, height: 1.3),
            ),
          ],
          if (app.nik != null || app.fullNameKtp != null) ...[
            const Divider(height: 24),
            Row(
              children: [
                Icon(Icons.badge, size: 18, color: Colors.teal.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Verifikasi KTP',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (app.fullNameKtp != null)
              Text('Nama: ${app.fullNameKtp}', style: const TextStyle(fontSize: 12)),
            if (app.nik != null)
              Text('NIK: ${app.nik}', style: const TextStyle(fontSize: 12)),
            if (app.birthPlace != null || app.birthDate != null)
              Text(
                'Lahir: ${app.birthPlace ?? ''}${app.birthDate != null ? ', ${app.birthDate}' : ''}',
                style: const TextStyle(fontSize: 12),
              ),
            if (app.addressKtp != null)
              Text('Alamat: ${app.addressKtp}', style: const TextStyle(fontSize: 12)),
            if (app.ktpPhotoUrl != null && app.ktpPhotoUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Foto KTP:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  app.ktpPhotoUrl!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 80,
                    color: Colors.grey.shade200,
                    child: const Center(child: Text('Foto KTP tidak dapat dimuat')),
                  ),
                ),
              ),
            ],
            if (app.selfiePhotoUrl != null && app.selfiePhotoUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Foto Selfie + KTP:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  app.selfiePhotoUrl!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 80,
                    color: Colors.grey.shade200,
                    child: const Center(child: Text('Foto Selfie tidak dapat dimuat')),
                  ),
                ),
              ),
            ],
          ],
          if (app.adminNote != null && app.adminNote!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Catatan Admin: ${app.adminNote}',
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ),
          ],
          if (showActions) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _showRejectDialog(app.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Tolak'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _handleApprove(app.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Setujui'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAppList(List<CreatorApplication> apps, {bool showActions = false}) {
    if (apps.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined, color: Colors.grey.shade400, size: 64),
              const SizedBox(height: 12),
              const Text(
                'Tidak ada pengajuan dalam daftar ini.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: apps.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _buildApplicationCard(apps[index], showActions: showActions),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 65,
        title: const Text(
          'Verifikasi Akun Kreator',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Pending'),
                  if (_pendingApps.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Badge.count(count: _pendingApps.length),
                  ]
                ],
              ),
            ),
            const Tab(text: 'Disetujui'),
            const Tab(text: 'Ditolak'),
          ],
        ),
      ),
      body: _isLoading && _pendingApps.isEmpty && _approvedApps.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAppList(_pendingApps, showActions: true),
                _buildAppList(_approvedApps),
                _buildAppList(_rejectedApps),
              ],
            ),
    );
  }
}
