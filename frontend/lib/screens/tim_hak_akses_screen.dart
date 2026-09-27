import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../widgets/app_sweet_alert.dart';
import '../widgets/desktop_sidebar_layout.dart';

class TimHakAksesScreen extends StatefulWidget {
  final UserModel? user;
  final ValueChanged<UserModel>? onUserUpdated;

  const TimHakAksesScreen({super.key, this.user, this.onUserUpdated});

  @override
  State<TimHakAksesScreen> createState() => _TimHakAksesScreenState();
}

class _TimHakAksesScreenState extends State<TimHakAksesScreen> {
  List<Map<String, dynamic>> _tim = [];
  bool _isLoading = true;
  String _selectedRoleFilter = 'Semua';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTeamMembers();
    _searchCtrl.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _ownerName => widget.user?.name.trim().isNotEmpty == true
      ? widget.user!.name
      : 'Kreavana Demo Institution';

  String get _ownerEmail => widget.user?.email.trim().isNotEmpty == true
      ? widget.user!.email
      : 'institution@kreavana.id';

  Map<String, dynamic> _getOwnerEntry() {
    return {
      'id': 'member_owner_primary',
      'name': _ownerName,
      'email': _ownerEmail,
      'role': 'Admin',
      'department': 'Pimpinan Lembaga / Kepala Sekolah',
      'isOnline': true,
      'isOwner': true,
      'joinedAt': 'Pemilik Akun',
    };
  }

  Future<void> _fetchTeamMembers() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.get(
        'institution/resources',
        queryParams: {'type': 'members'},
      );

      final List<Map<String, dynamic>> loadedList = [_getOwnerEntry()];

      if (response['status'] == true && response['data'] is List) {
        final List data = response['data'];
        for (final item in data) {
          if (item is Map) {
            final rawMeta = item['metadata'];
            final meta = rawMeta is Map ? Map<String, dynamic>.from(rawMeta) : <String, dynamic>{};
            loadedList.add({
              'id': item['id']?.toString() ?? '',
              'name': item['title']?.toString() ?? 'Staf',
              'email': meta['email']?.toString() ?? '-',
              'role': meta['role']?.toString() ?? 'Viewer',
              'department': item['description']?.toString() ??
                  meta['department']?.toString() ??
                  'Staf Lembaga',
              'isOnline': meta['is_online'] == true,
              'isOwner': false,
              'joinedAt': meta['joined_at']?.toString() ?? 'Terdaftar',
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _tim = loadedList;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (_tim.isEmpty) {
            _tim = [_getOwnerEntry()];
          }
          _isLoading = false;
        });
      }
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Admin':
        return const Color(0xFFEF4444);
      case 'Editor':
        return const Color(0xFF3B82F6);
      case 'Viewer':
        return const Color(0xFF10B981);
      default:
        return AppTheme.primaryPurple;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'Admin':
        return Icons.admin_panel_settings_rounded;
      case 'Editor':
        return Icons.edit_note_rounded;
      case 'Viewer':
        return Icons.visibility_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  List<Map<String, dynamic>> get _filteredTim {
    final query = _searchCtrl.text.trim().toLowerCase();
    return _tim.where((m) {
      final role = m['role'] as String;
      final name = (m['name'] as String).toLowerCase();
      final email = (m['email'] as String).toLowerCase();
      final department = (m['department'] as String).toLowerCase();

      final matchesFilter =
          _selectedRoleFilter == 'Semua' || role == _selectedRoleFilter;
      final matchesQuery = query.isEmpty ||
          name.contains(query) ||
          email.contains(query) ||
          department.contains(query);

      return matchesFilter && matchesQuery;
    }).toList();
  }

  void _openInviteMemberDialog() {
    final isMobile = MediaQuery.of(context).size.width < 640;
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final deptCtrl = TextEditingController();
    String selectedRole = 'Editor';
    bool isSubmitting = false;

    Widget buildForm(BuildContext modalCtx, void Function(void Function()) setModalState) {
      final isDark = Theme.of(modalCtx).brightness == Brightness.dark;

      return StatefulBuilder(
        builder: (ctx, setInnerState) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPurple.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.person_add_alt_1_rounded,
                            color: AppTheme.primaryPurple,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Undang Anggota Tim',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Data tersimpan ke database instansi',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(modalCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Nama Lengkap *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Ahmad Fauzi, S.Pd',
                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Alamat Email *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'nama@sekolah.sch.id',
                    prefixIcon: const Icon(Icons.email_outlined, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Jabatan / Unit Kerja (Opsional)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: deptCtrl,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Waka Kurikulum / Guru Pembimbing',
                    prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Pilih Peran & Wewenang *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                _buildRoleOption(
                  role: 'Admin',
                  title: 'Admin (Akses Penuh)',
                  desc: 'Kelola seluruh data sekolah, tim, verifikasi, dan pengaturan.',
                  color: const Color(0xFFEF4444),
                  icon: Icons.admin_panel_settings_rounded,
                  isSelected: selectedRole == 'Admin',
                  isDark: isDark,
                  onTap: () => setInnerState(() => selectedRole = 'Admin'),
                ),
                const SizedBox(height: 8),
                _buildRoleOption(
                  role: 'Editor',
                  title: 'Editor (Akses Kelola)',
                  desc: 'Dapat membuat program magang, agenda kegiatan, tender, & dokumen MoU.',
                  color: const Color(0xFF3B82F6),
                  icon: Icons.edit_note_rounded,
                  isSelected: selectedRole == 'Editor',
                  isDark: isDark,
                  onTap: () => setInnerState(() => selectedRole = 'Editor'),
                ),
                const SizedBox(height: 8),
                _buildRoleOption(
                  role: 'Viewer',
                  title: 'Viewer (Hanya Tinjau)',
                  desc: 'Hanya dapat melihat data, evaluasi siswa, portofolio & laporan (read-only).',
                  color: const Color(0xFF10B981),
                  icon: Icons.visibility_rounded,
                  isSelected: selectedRole == 'Viewer',
                  isDark: isDark,
                  onTap: () => setInnerState(() => selectedRole = 'Viewer'),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSubmitting ? null : () => Navigator.pop(modalCtx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(isSubmitting ? 'Menyimpan...' : 'Kirim Undangan'),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final name = nameCtrl.text.trim();
                                final email = emailCtrl.text.trim();
                                final dept = deptCtrl.text.trim();

                                if (name.isEmpty || email.isEmpty) {
                                  AppSweetAlert.warning(
                                    modalCtx,
                                    'Nama lengkap dan alamat email wajib diisi.',
                                    title: 'Form Belum Lengkap',
                                  );
                                  return;
                                }

                                if (!email.contains('@') || !email.contains('.')) {
                                  AppSweetAlert.warning(
                                    modalCtx,
                                    'Format alamat email tidak valid.',
                                    title: 'Email Tidak Valid',
                                  );
                                  return;
                                }

                                final emailExists = _tim.any(
                                  (m) =>
                                      (m['email'] as String).toLowerCase() ==
                                      email.toLowerCase(),
                                );
                                if (emailExists) {
                                  AppSweetAlert.warning(
                                    modalCtx,
                                    'Email ini sudah terdaftar dalam tim.',
                                    title: 'Email Duplikat',
                                  );
                                  return;
                                }

                                setInnerState(() => isSubmitting = true);

                                final payload = <String, dynamic>{
                                  'resource_type': 'members',
                                  'title': name,
                                  'description': dept.isNotEmpty
                                      ? dept
                                      : 'Staf Lembaga / Sekolah',
                                  'status': 'published',
                                  'metadata': {
                                    'email': email,
                                    'role': selectedRole,
                                    'department': dept.isNotEmpty
                                        ? dept
                                        : 'Staf Lembaga / Sekolah',
                                    'is_online': false,
                                    'joined_at': 'Baru saja diundang',
                                  },
                                };

                                final res = await ApiService.post(
                                  'institution/resources',
                                  payload,
                                );

                                if (!modalCtx.mounted) return;
                                setInnerState(() => isSubmitting = false);

                                if (res['status'] == true) {
                                  Navigator.pop(modalCtx);
                                  await _fetchTeamMembers();
                                  if (mounted) {
                                    AppSweetAlert.success(
                                      context,
                                      'Undangan akses $selectedRole berhasil disimpan dan dikirim ke $email.',
                                      title: 'Undangan Terkirim',
                                    );
                                  }
                                } else {
                                  AppSweetAlert.error(
                                    modalCtx,
                                    res['message']?.toString() ??
                                        'Gagal menyimpan anggota ke database.',
                                    title: 'Gagal Menyimpan',
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    }

    if (isMobile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.cardDark
            : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (modalCtx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom,
          ),
          child: buildForm(modalCtx, setState),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (modalCtx) => Dialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.cardDark
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: buildForm(modalCtx, setState),
          ),
        ),
      );
    }
  }

  Widget _buildRoleOption({
    required String role,
    required String title,
    required String desc,
    required Color color,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.08)
              : (isDark ? AppTheme.inputDark : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? AppTheme.inputBorder : Colors.grey.shade300),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isSelected ? color : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? color
                      : (isDark ? AppTheme.textMuted : Colors.grey.shade400),
                  width: isSelected ? 6 : 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeMemberRole(Map<String, dynamic> member, String newRole) async {
    if (member['isOwner'] == true) {
      AppSweetAlert.warning(
        context,
        'Peran pemilik akun utama sekolah tidak dapat diubah.',
        title: 'Aksi Dibatasi',
      );
      return;
    }

    final id = member['id']?.toString() ?? '';
    final payload = <String, dynamic>{
      'resource_type': 'members',
      'title': member['name'],
      'description': member['department'],
      'status': 'published',
      'metadata': {
        'email': member['email'],
        'role': newRole,
        'department': member['department'],
        'is_online': member['isOnline'] == true,
        'joined_at': member['joinedAt'],
      },
    };

    final res = await ApiService.put('institution/resources/$id', payload);
    if (!mounted) return;

    if (res['status'] == true) {
      await _fetchTeamMembers();
      if (mounted) {
        AppSweetAlert.success(
          context,
          'Peran ${member['name']} berhasil diubah menjadi $newRole di database.',
          title: 'Peran Diperbarui',
        );
      }
    } else {
      AppSweetAlert.error(
        context,
        res['message']?.toString() ?? 'Gagal memperbarui peran di database.',
        title: 'Gagal Memperbarui',
      );
    }
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    if (member['isOwner'] == true) {
      AppSweetAlert.warning(
        context,
        'Pemilik akun utama sekolah tidak dapat dihapus.',
        title: 'Aksi Dibatasi',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Cabut Hak Akses?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'Apakah Anda yakin ingin menghapus akses untuk "${member['name']}" (${member['role']})?\nData anggota ini akan dihapus permanen dari sistem.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Cabut Akses'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final id = member['id']?.toString() ?? '';
    final res = await ApiService.delete('institution/resources/$id');
    if (!mounted) return;

    if (res['status'] == true) {
      await _fetchTeamMembers();
      if (mounted) {
        AppSweetAlert.success(
          context,
          'Akses untuk ${member['name']} berhasil dicabut dari database.',
          title: 'Akses Dihapus',
        );
      }
    } else {
      AppSweetAlert.error(
        context,
        res['message']?.toString() ?? 'Gagal menghapus anggota dari database.',
        title: 'Gagal Menghapus',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final adminCount = _tim.where((m) => m['role'] == 'Admin').length;
    final editorCount = _tim.where((m) => m['role'] == 'Editor').length;
    final viewerCount = _tim.where((m) => m['role'] == 'Viewer').length;
    final totalCount = _tim.length;

    final filteredList = _filteredTim;

    final content = Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        automaticallyImplyLeading: MediaQuery.of(context).size.width <= 900,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tim & Hak Akses',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 2),
            Text(
              'Kelola wewenang dan staf pengelola instansi sekolah (Tersinkronisasi Database)',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Muat ulang data',
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: _fetchTeamMembers,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _openInviteMemberDialog,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Undang Anggota'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 1,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryPurple),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  children: [
                    // Top Statistics Cards
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.cardBg : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? AppTheme.inputBorder
                              : Colors.grey.shade200,
                        ),
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                      ),
                      child: Row(
                        children: [
                          _buildRoleStatCard(
                            'Total Tim',
                            '$totalCount',
                            AppTheme.primaryPurple,
                            isDark,
                            _selectedRoleFilter == 'Semua',
                            () => setState(() => _selectedRoleFilter = 'Semua'),
                          ),
                          Container(
                            width: 1,
                            height: 38,
                            color: isDark
                                ? AppTheme.inputBorder
                                : Colors.grey.shade200,
                          ),
                          _buildRoleStatCard(
                            'Admin',
                            '$adminCount',
                            const Color(0xFFEF4444),
                            isDark,
                            _selectedRoleFilter == 'Admin',
                            () => setState(() {
                              _selectedRoleFilter =
                                  _selectedRoleFilter == 'Admin'
                                      ? 'Semua'
                                      : 'Admin';
                            }),
                          ),
                          Container(
                            width: 1,
                            height: 38,
                            color: isDark
                                ? AppTheme.inputBorder
                                : Colors.grey.shade200,
                          ),
                          _buildRoleStatCard(
                            'Editor',
                            '$editorCount',
                            const Color(0xFF3B82F6),
                            isDark,
                            _selectedRoleFilter == 'Editor',
                            () => setState(() {
                              _selectedRoleFilter =
                                  _selectedRoleFilter == 'Editor'
                                      ? 'Semua'
                                      : 'Editor';
                            }),
                          ),
                          Container(
                            width: 1,
                            height: 38,
                            color: isDark
                                ? AppTheme.inputBorder
                                : Colors.grey.shade200,
                          ),
                          _buildRoleStatCard(
                            'Viewer',
                            '$viewerCount',
                            const Color(0xFF10B981),
                            isDark,
                            _selectedRoleFilter == 'Viewer',
                            () => setState(() {
                              _selectedRoleFilter =
                                  _selectedRoleFilter == 'Viewer'
                                      ? 'Semua'
                                      : 'Viewer';
                            }),
                          ),
                        ],
                      ),
                    ),

                    // Search & Filter Controls Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.cardBg : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? AppTheme.inputBorder
                                      : Colors.grey.shade200,
                                ),
                              ),
                              child: TextField(
                                controller: _searchCtrl,
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Cari nama, email, atau jabatan...',
                                  hintStyle: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? AppTheme.textMuted
                                        : Colors.grey.shade400,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    size: 20,
                                    color: isDark
                                        ? AppTheme.textMuted
                                        : Colors.grey.shade500,
                                  ),
                                  suffixIcon: _searchCtrl.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.clear,
                                            size: 16,
                                          ),
                                          onPressed: () => _searchCtrl.clear(),
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip('Semua', totalCount, isDark),
                                const SizedBox(width: 6),
                                _buildFilterChip('Admin', adminCount, isDark),
                                const SizedBox(width: 6),
                                _buildFilterChip('Editor', editorCount, isDark),
                                const SizedBox(width: 6),
                                _buildFilterChip('Viewer', viewerCount, isDark),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Team Members List or Empty State
                    Expanded(
                      child: filteredList.isEmpty
                          ? _buildEmptyState(isDark)
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                              itemCount: filteredList.length,
                              itemBuilder: (context, index) {
                                final member = filteredList[index];
                                return _buildMemberCard(member, isDark);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );

    if (widget.user != null) {
      return DesktopSidebarLayout(
        user: widget.user!,
        activeRoute: 'tim_hak_akses',
        onUserUpdated: widget.onUserUpdated,
        child: content,
      );
    }

    return content;
  }

  Widget _buildRoleStatCard(
    String label,
    String count,
    Color color,
    bool isDark,
    bool isActive,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isActive
                ? Border.all(color: color.withValues(alpha: 0.3))
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                count,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? AppTheme.textMuted : Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String role, int count, bool isDark) {
    final isSelected = _selectedRoleFilter == role;
    final color =
        role == 'Semua' ? AppTheme.primaryPurple : _getRoleColor(role);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedRoleFilter = role;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.12)
              : (isDark ? AppTheme.cardBg : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? AppTheme.inputBorder : Colors.grey.shade200),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              role,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? color
                    : (isDark ? AppTheme.textMuted : Colors.grey.shade700),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? color
                    : (isDark ? AppTheme.inputDark : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.grey.shade800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member, bool isDark) {
    final role = member['role'] as String;
    final roleColor = _getRoleColor(role);
    final isOwner = member['isOwner'] == true;
    final isOnline = member['isOnline'] == true;

    final nameParts = (member['name'] as String).trim().split(' ');
    final initials = nameParts.length > 1
        ? '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase()
        : nameParts[0].isNotEmpty
            ? nameParts[0][0].toUpperCase()
            : 'U';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOwner
              ? roleColor.withValues(alpha: 0.4)
              : (isDark ? AppTheme.inputBorder : Colors.grey.shade200),
          width: isOwner ? 1.5 : 1,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          // Avatar with online status
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: roleColor.withValues(alpha: 0.12),
                child: Text(
                  initials,
                  style: TextStyle(
                    color: roleColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              if (isOnline)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppTheme.cardBg : Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // Member Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member['name'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isOwner) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
                          'Pemilik Lembaga',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryPurple,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  member['department'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  member['email'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppTheme.textMuted.withValues(alpha: 0.8)
                        : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),

          // Joined Date
          if (MediaQuery.of(context).size.width >= 700) ...[
            Text(
              member['joinedAt'] as String,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade400,
              ),
            ),
            const SizedBox(width: 14),
          ],

          // Role Badge Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: roleColor.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getRoleIcon(role), size: 14, color: roleColor),
                const SizedBox(width: 5),
                Text(
                  role,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: roleColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Action Menu
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              size: 20,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: isDark ? AppTheme.cardDark2 : Colors.white,
            onSelected: (action) {
              if (action == 'admin') {
                _changeMemberRole(member, 'Admin');
              } else if (action == 'editor') {
                _changeMemberRole(member, 'Editor');
              } else if (action == 'viewer') {
                _changeMemberRole(member, 'Viewer');
              } else if (action == 'resend') {
                AppSweetAlert.info(
                  context,
                  'Info akses dan tautan masuk telah dikirimkan ke ${member['email']}.',
                  title: 'Akses Terkirim',
                );
              } else if (action == 'remove') {
                _removeMember(member);
              }
            },
            itemBuilder: (context) {
              if (isOwner) {
                return [
                  const PopupMenuItem(
                    enabled: false,
                    child: Text(
                      'Akun Utama (Pemilik)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ];
              }

              return [
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    'Ubah Hak Akses:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
                if (role != 'Admin')
                  const PopupMenuItem(
                    value: 'admin',
                    child: Row(
                      children: [
                        Icon(
                          Icons.admin_panel_settings_rounded,
                          size: 16,
                          color: Color(0xFFEF4444),
                        ),
                        SizedBox(width: 8),
                        Text('Jadikan Admin', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                if (role != 'Editor')
                  const PopupMenuItem(
                    value: 'editor',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_note_rounded,
                          size: 16,
                          color: Color(0xFF3B82F6),
                        ),
                        SizedBox(width: 8),
                        Text('Jadikan Editor', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                if (role != 'Viewer')
                  const PopupMenuItem(
                    value: 'viewer',
                    child: Row(
                      children: [
                        Icon(
                          Icons.visibility_rounded,
                          size: 16,
                          color: Color(0xFF10B981),
                        ),
                        SizedBox(width: 8),
                        Text('Jadikan Viewer', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'resend',
                  child: Row(
                    children: [
                      Icon(Icons.forward_to_inbox_rounded, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Kirim Ulang Undangan',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                        color: Colors.red,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Cabut Hak Akses',
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardBg : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.group_off_rounded,
                  size: 36,
                  color: AppTheme.primaryPurple,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Tidak Ada Anggota Ditemukan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchCtrl.text.isNotEmpty
                    ? 'Tidak ada staf atau anggota yang cocok dengan kata kunci "${_searchCtrl.text}".'
                    : 'Belum ada anggota tim dengan peran "$_selectedRoleFilter".',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  if (_searchCtrl.text.isNotEmpty ||
                      _selectedRoleFilter != 'Semua')
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _searchCtrl.clear();
                          _selectedRoleFilter = 'Semua';
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Reset Filter'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ElevatedButton.icon(
                    onPressed: _openInviteMemberDialog,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                    label: const Text('Undang Anggota'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
