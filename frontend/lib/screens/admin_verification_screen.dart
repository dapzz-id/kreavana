import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
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
  List<Map<String, dynamic>> _creatorPackages = [];
  String _packageTypeFilter = 'Semua';
  String _packageStatusFilter = 'Semua';

  final _rejectNoteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
      final creatorPackages = await AdminService.getCreatorServices();

      if (mounted) {
        setState(() {
          _pendingApps = pApps;
          _approvedApps = aApps;
          _rejectedApps = rApps;
          _creatorPackages = creatorPackages;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleApprove(String? id) async {
    if (id == null) return;
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

  void _showRejectDialog(String? id) {
    if (id == null) return;
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
                hintText:
                    'Misal: Link portofolio tidak aktif atau data tidak valid...',
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

  void _handleReject(String id, String note) async {
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

  Widget _buildApplicationCard(
    CreatorApplication app, {
    bool showActions = false,
  }) {
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
                backgroundColor:
                    (app.type == 'client_verification'
                            ? Colors.blue
                            : theme.colorScheme.primary)
                        .withValues(alpha: 0.12),
                child: Icon(
                  app.type == 'client_verification'
                      ? Icons.verified_user_rounded
                      : Icons.palette_rounded,
                  color: app.type == 'client_verification'
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
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: app.type == 'client_verification'
                                ? Colors.blue.shade50
                                : Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: app.type == 'client_verification'
                                  ? Colors.blue.shade300
                                  : Colors.teal.shade300,
                            ),
                          ),
                          child: Text(
                            app.type == 'client_verification'
                                ? 'VERIFIKASI KLIEN (KTP)'
                                : 'UPGRADE KREATOR (${app.subRoleCategory.toUpperCase()})',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: app.type == 'client_verification'
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
                    const SizedBox(height: 4),
                    Text(
                      'Nama Pemohon: (ID ${app.userId})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
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
          if (app.type == 'client_verification') ...[
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
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Colors.blue.shade800,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Permohonan verifikasi KTP Klien. Setelah disetujui, akun tetap berstatus Klien (User) dengan centang biru 🔵 dan dapat membuat kebutuhan proyek baru.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade900,
                      ),
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
                        'Dokumen NIB: ${app.nibFileUrl}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
          if (app.nik != null || app.fullNameKtp != null) ...[
            const Divider(height: 24),
            Row(
              children: [
                Icon(Icons.badge, size: 18, color: Colors.teal.shade700),
                const SizedBox(width: 8),
                Text(
                  app.reusedKtp
                      ? 'Verifikasi KTP (Riwayat Tersimpan)'
                      : 'Verifikasi KTP',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (app.fullNameKtp != null)
              Text(
                'Nama: ${app.fullNameKtp}',
                style: const TextStyle(fontSize: 12),
              ),
            if (app.nik != null)
              Text('NIK: ${app.nik}', style: const TextStyle(fontSize: 12)),
            if (app.birthPlace != null || app.birthDate != null)
              Text(
                'Lahir: ${app.birthPlace ?? ''}${app.birthDate != null ? ', ${app.birthDate}' : ''}',
                style: const TextStyle(fontSize: 12),
              ),
            if (app.addressKtp != null)
              Text(
                'Alamat: ${app.addressKtp}',
                style: const TextStyle(fontSize: 12),
              ),
            if (app.ktpPhotoUrl != null && app.ktpPhotoUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Foto KTP:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
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
                    child: const Center(
                      child: Text('Foto KTP tidak dapat dimuat'),
                    ),
                  ),
                ),
              ),
            ],
            if (app.selfiePhotoUrl != null &&
                app.selfiePhotoUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Foto Selfie + KTP:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
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
                    child: const Center(
                      child: Text('Foto Selfie tidak dapat dimuat'),
                    ),
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

  Widget _buildAppList(
    List<CreatorApplication> apps, {
    bool showActions = false,
    String emptyMessage = 'Tidak ada pengajuan dalam daftar ini.',
  }) {
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
              Text(emptyMessage, style: const TextStyle(color: Colors.grey)),
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
      itemBuilder: (context, index) =>
          _buildApplicationCard(apps[index], showActions: showActions),
    );
  }

  Future<void> _approvePackage(String id) async {
    setState(() => _isLoading = true);
    final result = await AdminService.approveCreatorService(id);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result['status'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paket disetujui dan sekarang tampil di publik.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadApplications();
    } else {
      _showError(result['message']?.toString() ?? 'Gagal menyetujui paket.');
    }
  }

  void _showRejectPackageDialog(String id) {
    _rejectNoteController.clear();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tolak Paket Event'),
        content: TextField(
          controller: _rejectNoteController,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Alasan penolakan',
            hintText: 'Jelaskan perbaikan yang perlu dilakukan EO',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final note = _rejectNoteController.text.trim();
              if (note.length < 3) {
                _showError('Alasan penolakan minimal 3 karakter.');
                return;
              }
              Navigator.pop(dialogContext);
              _rejectPackage(id, note);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Tolak Paket'),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectPackage(String id, String note) async {
    setState(() => _isLoading = true);
    final result = await AdminService.rejectCreatorService(id, note);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result['status'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paket ditolak. Catatan dikirim ke pemilik.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadApplications();
    } else {
      _showError(result['message']?.toString() ?? 'Gagal menolak paket.');
    }
  }

  Widget _buildPackageReviewCard(
    Map<String, dynamic> package, {
    bool showActions = true,
  }) {
    final creator = package['creator'] is Map
        ? Map<String, dynamic>.from(package['creator'] as Map)
        : <String, dynamic>{};
    final imageUrl = package['thumbnail_url']?.toString();
    final status = package['status']?.toString() ?? 'pending';
    final packageType = package['package_type']?.toString() ?? 'Paket Creator';
    final creatorRole = creator['sub_role']?.toString() ?? '';
    final creatorName = creator['name']?.toString() ?? 'Tidak diketahui';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    ApiService.resolveAssetUrl(imageUrl),
                    width: 88,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _packageThumbnailPlaceholder(),
                  ),
                )
              else
                _packageThumbnailPlaceholder(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package['title']?.toString() ?? 'Paket Event',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_packageTypeLabel(packageType)} • ${_creatorRoleLabel(creatorRole)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Creator: $creatorName',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rp ${package['price'] ?? '0'}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              _packageStatusBadge(status),
            ],
          ),
          if ((package['description']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(package['description'].toString()),
          ],
          if ((package['review_note']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Catatan admin: ${package['review_note']}',
              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
            ),
          ],
          if (showActions) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () =>
                      _showRejectPackageDialog(package['id'].toString()),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Tolak'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _approvePackage(package['id'].toString()),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Setujui & Publikasikan'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _packageThumbnailPlaceholder() {
    return Container(
      width: 88,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.image_outlined, color: Colors.grey.shade500),
    );
  }

  String _packageTypeLabel(String type) {
    const labels = {
      'foto_paket': 'Paket Fotografi',
      'video_paket': 'Paket Videografi',
      'mua_paket': 'Paket Makeup Artist',
      'wo_paket': 'Paket Wedding Organizer',
      'eo_paket': 'Paket Event Organizer',
      'desain_paket': 'Paket Desain',
      'drone_paket': 'Paket Drone',
      'konten_paket': 'Paket Konten',
    };
    return labels[type] ?? type.replaceAll('_', ' ');
  }

  static const List<String> _supportedPackageTypes = [
    'foto_paket',
    'video_paket',
    'mua_paket',
    'wo_paket',
    'eo_paket',
    'desain_paket',
    'drone_paket',
    'konten_paket',
  ];

  String _packageTypeFor(Map<String, dynamic> package) {
    final storedType = package['package_type']?.toString().trim() ?? '';
    if (storedType.isNotEmpty) return storedType;

    if (package['category'] == 'eo_event_package') return 'eo_paket';

    final creator = package['creator'] is Map
        ? Map<String, dynamic>.from(package['creator'] as Map)
        : <String, dynamic>{};
    return switch (creator['sub_role']?.toString()) {
      'photographer' || 'fotografer' => 'foto_paket',
      'videographer' || 'videografer' => 'video_paket',
      'makeup_artist' || 'mua' => 'mua_paket',
      'wedding_organizer' || 'wo' => 'wo_paket',
      'event_organizer' || 'eo' => 'eo_paket',
      'desainer' || 'designer' => 'desain_paket',
      'drone_pilot' || 'drone' || 'pilot_drone' => 'drone_paket',
      'content_creator' || 'konten_kreator' || 'ugc' => 'konten_paket',
      _ => '',
    };
  }

  String _creatorRoleLabel(String role) {
    const labels = {
      'photographer': 'Fotografer',
      'videographer': 'Videografer',
      'makeup_artist': 'Makeup Artist',
      'wedding_organizer': 'Wedding Organizer',
      'event_organizer': 'Event Organizer',
      'desainer': 'Desainer',
      'drone_pilot': 'Pilot Drone',
      'content_creator': 'Konten Kreator',
    };
    return labels[role] ?? role.replaceAll('_', ' ');
  }

  Widget _packageStatusBadge(String status) {
    final isApproved = status == 'active';
    final isRejected = status == 'rejected';
    final color = isApproved
        ? Colors.green
        : isRejected
        ? Colors.red
        : Colors.orange;
    final label = isApproved
        ? 'Tayang'
        : isRejected
        ? 'Ditolak'
        : 'Pending';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.shade700,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPackageReviewList() {
    final packageTypes = {
      ..._supportedPackageTypes,
      ..._creatorPackages.map(_packageTypeFor).where((type) => type.isNotEmpty),
    }.toList()..sort();
    final filteredPackages = _creatorPackages.where((package) {
      final type = _packageTypeFor(package);
      final status = package['status']?.toString() ?? 'pending';
      final matchesType =
          _packageTypeFilter == 'Semua' || type == _packageTypeFilter;
      final matchesStatus =
          _packageStatusFilter == 'Semua' || status == _packageStatusFilter;
      return matchesType && matchesStatus;
    }).toList();

    if (_creatorPackages.isEmpty) {
      return const Center(
        child: Text('Belum ada pengajuan paket dari creator.'),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final typeFilter = DropdownButtonFormField<String>(
                initialValue: _packageTypeFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Jenis Paket',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'Semua',
                    child: Text('Semua jenis'),
                  ),
                  ...packageTypes.map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(
                        _packageTypeLabel(type),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _packageTypeFilter = value ?? 'Semua'),
              );
              final statusFilter = DropdownButtonFormField<String>(
                initialValue: _packageStatusFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'Semua', child: Text('Semua status')),
                  DropdownMenuItem(
                    value: 'pending',
                    child: Text('Menunggu Review'),
                  ),
                  DropdownMenuItem(
                    value: 'active',
                    child: Text('Tayang Publik'),
                  ),
                  DropdownMenuItem(value: 'rejected', child: Text('Ditolak')),
                ],
                onChanged: (value) =>
                    setState(() => _packageStatusFilter = value ?? 'Semua'),
              );

              if (constraints.maxWidth < 600) {
                return Column(
                  children: [
                    typeFilter,
                    const SizedBox(height: 8),
                    statusFilter,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: typeFilter),
                  const SizedBox(width: 12),
                  Expanded(child: statusFilter),
                ],
              );
            },
          ),
        ),
        Expanded(
          child: filteredPackages.isEmpty
              ? Center(
                  child: Text(
                    'Tidak ada paket yang cocok dengan filter.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredPackages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final package = filteredPackages[index];
                    return _buildPackageReviewCard(
                      package,
                      showActions: package['status'] == 'pending',
                    );
                  },
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
        title: const Text(
          'Verifikasi Akun Kreator',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
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
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Paket Creator'),
                  if (_creatorPackages
                      .where((package) => package['status'] == 'pending')
                      .isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Badge.count(
                      count: _creatorPackages
                          .where((package) => package['status'] == 'pending')
                          .length,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body:
          _isLoading &&
              _pendingApps.isEmpty &&
              _approvedApps.isEmpty &&
              _creatorPackages.isEmpty
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
                _buildPackageReviewList(),
              ],
            ),
    );
  }
}
