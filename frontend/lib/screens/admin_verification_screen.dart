import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../services/admin_service.dart';
import '../widgets/skeleton_box.dart';

class AdminVerificationScreen extends StatefulWidget {
  const AdminVerificationScreen({super.key});

  @override
  State<AdminVerificationScreen> createState() =>
      _AdminVerificationScreenState();
}

class _AdminVerificationScreenState extends State<AdminVerificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<CreatorApplication> _pendingApps = [];
  List<CreatorApplication> _approvedApps = [];
  List<CreatorApplication> _rejectedApps = [];
  String _typeFilter = 'all'; // 'all', 'client', 'creator'

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

  List<CreatorApplication> _filterApps(List<CreatorApplication> apps) {
    if (_typeFilter == 'client') {
      return apps.where((a) => a.type == 'client_verification').toList();
    } else if (_typeFilter == 'creator') {
      return apps.where((a) => a.type != 'client_verification').toList();
    }
    return apps;
  }

  void _handleApprove(CreatorApplication app) async {
    final id = app.id;
    if (id == null) return;
    setState(() => _isLoading = true);
    final result = await AdminService.approveApplication(id);
    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        final successMsg = app.type == 'client_verification'
            ? 'Verifikasi KTP Klien berhasil disetujui. Akun kini memiliki Centang Biru!'
            : 'Pengajuan kreator berhasil disetujui. Akun telah ditingkatkan ke status Kreator!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMsg),
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

  void _showRejectDialog(CreatorApplication app) {
    final id = app.id;
    if (id == null) return;
    _rejectNoteController.clear();
    final isClient = app.type == 'client_verification';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isClient ? 'Tolak Verifikasi KTP Klien' : 'Tolak Pengajuan Kreator'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isClient
                  ? 'Berikan alasan mengapa verifikasi KTP ini ditolak (misal: foto buram, NIK tidak sesuai):'
                  : 'Berikan alasan mengapa pengajuan kreator ini ditolak:',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rejectNoteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: isClient
                    ? 'Misal: Foto KTP terpotong atau teks NIK tidak terbaca jelas...'
                    : 'Misal: Link portofolio tidak aktif atau data tidak valid...',
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
              _handleReject(app, note);
            },
            child: const Text('Tolak', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _handleReject(CreatorApplication app, String note) async {
    final id = app.id;
    if (id == null) return;
    setState(() => _isLoading = true);
    final result = await AdminService.rejectApplication(id, note);
    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        final rejectMsg = app.type == 'client_verification'
            ? 'Verifikasi KTP Klien berhasil ditolak.'
            : 'Pengajuan kreator berhasil ditolak.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(rejectMsg),
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

  Widget _buildApplicationCard(
    CreatorApplication app, {
    bool showActions = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isClient = app.type == 'client_verification';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isClient
              ? Colors.blue.withValues(alpha: 0.3)
              : (isDark ? AppTheme.inputBorder : Colors.grey.shade200),
          width: isClient ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: (isClient
                        ? Colors.blue
                        : theme.colorScheme.primary)
                    .withValues(alpha: 0.12),
                child: Icon(
                  isClient
                      ? Icons.verified_user_rounded
                      : Icons.palette_rounded,
                  color: isClient
                      ? Colors.blue.shade700
                      : Colors.teal.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isClient
                                ? Colors.blue.shade50
                                : Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isClient
                                  ? Colors.blue.shade300
                                  : Colors.teal.shade300,
                            ),
                          ),
                          child: Text(
                            isClient
                                ? '🔵 VERIFIKASI KLIEN (KTP)'
                                : '🟢 UPGRADE KREATOR (${app.subRoleCategory.toUpperCase()})',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isClient
                                  ? Colors.blue.shade800
                                  : Colors.teal.shade800,
                            ),
                          ),
                        ),
                        if (app.reusedKtp) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.purple.shade200),
                            ),
                            child: Text(
                              'KTP TERSIMPAN',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      app.fullNameKtp ?? app.userName ?? 'Pengguna (ID: ${app.userId?.substring(0, 8) ?? '-'})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (app.userEmail != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        app.userEmail!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: app.status == 'approved'
                      ? Colors.green.shade100.withValues(alpha: 0.8)
                      : (app.status == 'rejected'
                            ? Colors.red.shade100.withValues(alpha: 0.8)
                            : Colors.orange.shade100.withValues(alpha: 0.8)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  app.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: app.status == 'approved'
                        ? Colors.green.shade800
                        : (app.status == 'rejected'
                              ? Colors.red.shade800
                              : Colors.orange.shade800),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          if (isClient) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.blue.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Permohonan verifikasi KTP Klien. Setelah disetujui, akun tetap berstatus Klien (User) dengan centang biru 🔵 dan dapat membuat kebutuhan proyek baru.',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              'Keahlian & Deskripsi:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              app.skillDescription,
              style: const TextStyle(fontSize: 13, height: 1.3),
            ),
            const SizedBox(height: 12),
            Text(
              'Link Portofolio:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              app.portfolioLink ?? 'Tidak dicantumkan',
              style: TextStyle(
                fontSize: 12,
                color: app.portfolioLink != null
                    ? Colors.blue.shade600
                    : Colors.grey,
                decoration: app.portfolioLink != null
                    ? TextDecoration.underline
                    : null,
              ),
            ),
            if (app.experience != null && app.experience!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Pengalaman Kerja:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                app.experience!,
                style: const TextStyle(fontSize: 12, height: 1.3),
              ),
            ],
          ],
          if (app.nibNumber != null && app.nibNumber!.isNotEmpty) ...[
            const Divider(height: 24),
            Row(
              children: [
                Icon(Icons.business, size: 18, color: Colors.indigo.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Dokumen Legalitas Usaha (NIB)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Nomor Induk Berusaha (NIB): ${app.nibNumber}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            if (app.nibFileUrl != null && app.nibFileUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  app.nibFileUrl!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 60,
                    color: Colors.grey.shade200,
                    child: Center(
                      child: Text(
                        'Gagal memuat dokumen NIB',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
          if (app.nik != null && app.nik!.isNotEmpty) ...[
            const Divider(height: 24),
            Text(
              'Data Identitas KTP Pemohon:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                ),
              ),
              child: Column(
                children: [
                  _buildDataRow('NIK', app.nik!),
                  _buildDataRow('Nama Lengkap', app.fullNameKtp ?? '-'),
                  if (app.birthPlace != null || app.birthDate != null)
                    _buildDataRow(
                      'Tempat, Tgl Lahir',
                      '${app.birthPlace ?? '-'}, ${app.birthDate ?? '-'}',
                    ),
                  if (app.addressKtp != null)
                    _buildDataRow('Alamat KTP', app.addressKtp!),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (app.ktpPhotoUrl != null && app.ktpPhotoUrl!.isNotEmpty)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Foto KTP:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => _showImageDialog(app.ktpPhotoUrl!, 'Foto KTP'),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              app.ktpPhotoUrl!,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                height: 120,
                                color: Colors.grey.shade200,
                                child: Center(
                                  child: Text(
                                    'Gagal memuat foto',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (app.ktpPhotoUrl != null &&
                    app.selfiePhotoUrl != null &&
                    app.selfiePhotoUrl!.isNotEmpty)
                  const SizedBox(width: 12),
                if (app.selfiePhotoUrl != null &&
                    app.selfiePhotoUrl!.isNotEmpty)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Foto Selfie + KTP:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => _showImageDialog(
                            app.selfiePhotoUrl!,
                            'Foto Selfie + KTP',
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              app.selfiePhotoUrl!,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                height: 120,
                                color: Colors.grey.shade200,
                                child: Center(
                                  child: Text(
                                    'Gagal memuat foto',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
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
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          if (showActions) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _showRejectDialog(app),
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
                  onPressed: () => _handleApprove(app),
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

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showImageDialog(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    padding: const EdgeInsets.all(24),
                    color: Colors.black,
                    child: const Text(
                      'Gagal memuat gambar',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(List<CreatorApplication> apps) {
    final clientCount = apps.where((a) => a.type == 'client_verification').length;
    final creatorCount = apps.where((a) => a.type != 'client_verification').length;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              label: 'Semua (${apps.length})',
              isSelected: _typeFilter == 'all',
              isDark: isDark,
              onTap: () => setState(() => _typeFilter = 'all'),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: '🔵 Verifikasi Klien ($clientCount)',
              isSelected: _typeFilter == 'client',
              isDark: isDark,
              onTap: () => setState(() => _typeFilter = 'client'),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: '🟢 Upgrade Kreator ($creatorCount)',
              isSelected: _typeFilter == 'creator',
              isDark: isDark,
              onTap: () => setState(() => _typeFilter = 'creator'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryPurple
              : (isDark ? const Color(0xFF1E1C2B) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryPurple
                : (isDark ? AppTheme.inputBorder : Colors.grey.shade300),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.grey.shade800),
          ),
        ),
      ),
    );
  }

  Widget _buildAppList(
    List<CreatorApplication> apps, {
    bool showActions = false,
  }) {
    final filtered = _filterApps(apps);

    return Column(
      children: [
        _buildFilterChips(apps),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, color: Colors.grey.shade400, size: 64),
                        const SizedBox(height: 12),
                        Text(
                          _typeFilter == 'all'
                              ? 'Tidak ada pengajuan dalam daftar ini.'
                              : 'Tidak ada pengajuan untuk kategori ini.',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) =>
                      _buildApplicationCard(filtered[index], showActions: showActions),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: Navigator.canPop(context),
        toolbarHeight: 80,
        titleSpacing: isDesktop ? 32 : 16,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verifikasi Akun & Identitas',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 2),
            Text(
              'Kelola verifikasi KTP Klien (Centang Biru) dan Upgrade Kreator (Centang Hijau)',
              style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Pending'),
                  if (_pendingApps.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Badge.count(count: _pendingApps.length),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Disetujui'),
            const Tab(text: 'Ditolak'),
          ],
        ),
      ),
      body: _isLoading && _pendingApps.isEmpty && _approvedApps.isEmpty
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 4,
              itemBuilder: (context, index) => const AdminAppSkeleton(),
            )
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
