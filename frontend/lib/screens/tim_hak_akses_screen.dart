import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../widgets/app_sweet_alert.dart';
import '../widgets/desktop_sidebar_layout.dart';
import '../widgets/app_pagination_bar.dart';

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
  int _currentPage = 1;
  static const int _pageSize = 6;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTeamMembers();
    _searchCtrl.addListener(() {
      setState(() {
        _currentPage = 1;
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _ownerName => widget.user?.name.trim().isNotEmpty == true
      ? widget.user!.name
      : 'Institusi';

  String get _ownerEmail => widget.user?.email.trim().isNotEmpty == true
      ? widget.user!.email
      : '';

  Map<String, dynamic> _getOwnerEntry() {
    return {
      'id': 'member_owner_primary',
      'name': _ownerName,
      'email': _ownerEmail,
      'role': 'Admin',
      'permissions': List<String>.from(UserModel.defaultInstitutionPermissions),
      'department': 'Pimpinan Lembaga / Kepala Sekolah',
      'isOnline': true,
      'isOwner': true,
      'joinedAt': 'Pemilik Akun',
    };
  }

  static const List<Map<String, dynamic>> _institutionFeatures = [
    {
      'slug': 'program_magang',
      'name': 'Program & Magang',
      'desc': 'Kelola tawaran program, kuota magang siswa, & pendaftar.',
      'icon': Icons.work_outline,
    },
    {
      'slug': 'kegiatan_event',
      'name': 'Kegiatan & Event',
      'desc': 'Publikasikan workshop, webinar, kompetisi, & agenda sekolah.',
      'icon': Icons.event_outlined,
    },
    {
      'slug': 'mitra_industri',
      'name': 'Mitra Industri & Sanggar',
      'desc': 'Jalin relasi kemitraan DUDI, sanggar kreatif, & pengajuan MoU.',
      'icon': Icons.diversity_3_outlined,
    },
    {
      'slug': 'karya_siswa',
      'name': 'Karya & Portofolio Siswa',
      'desc': 'Kurasi karya unggulan siswa, galeri talenta vokasi, & pameran.',
      'icon': Icons.palette_outlined,
    },
    {
      'slug': 'dokumen_institusi',
      'name': 'Dokumen & MoU',
      'desc': 'Akses berkas legalitas, SK, surat perjanjian, & naskah kerjasama.',
      'icon': Icons.folder_outlined,
    },
  ];

  Future<void> _fetchTeamMembers() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.get(
        'institution/resources',
        queryParams: {'type': 'members'},
      );

      final List<Map<String, dynamic>> loadedList =
          widget.user != null ? [_getOwnerEntry()] : [];

      if (response['status'] == true && response['data'] is List) {
        final List data = response['data'];
        for (final item in data) {
          if (item is Map) {
            final rawMeta = item['metadata'];
            final meta = rawMeta is Map ? Map<String, dynamic>.from(rawMeta) : <String, dynamic>{};
            final rawRole = (meta['role'] ?? 'Karyawan / Staf').toString().trim();
            final normalizedRole = rawRole.toLowerCase() == 'admin' ? 'Admin' : 'Karyawan / Staf';
            List<String> perms = [];
            if (meta['permissions'] is List) {
              perms = (meta['permissions'] as List).map((p) => p.toString()).toList();
            } else if (normalizedRole == 'Admin') {
              perms = List<String>.from(UserModel.defaultInstitutionPermissions);
            } else {
              perms = [
                'program_magang',
                'kegiatan_event',
                'mitra_industri',
                'karya_siswa',
              ];
            }

            loadedList.add({
              'id': item['id']?.toString() ?? '',
              'name': item['title']?.toString() ?? 'Staf',
              'email': meta['email']?.toString() ?? '-',
              'role': normalizedRole,
              'permissions': perms,
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
          _currentPage = 1;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _currentPage = 1;
          _isLoading = false;
        });
      }
    }
  }

  Color _getRoleColor(String role) {
    if (role == 'Admin') {
      return const Color(0xFFEF4444);
    }
    return const Color(0xFF6366F1);
  }

  IconData _getRoleIcon(String role) {
    if (role == 'Admin') {
      return Icons.admin_panel_settings_rounded;
    }
    return Icons.badge_rounded;
  }

  List<Map<String, dynamic>> get _filteredTim {
    final query = _searchCtrl.text.trim().toLowerCase();
    return _tim.where((m) {
      final role = m['role'] as String;
      final name = (m['name'] as String).toLowerCase();
      final email = (m['email'] as String).toLowerCase();
      final department = (m['department'] as String).toLowerCase();

      final matchesFilter = _selectedRoleFilter == 'Semua' ||
          (_selectedRoleFilter == 'Admin' && role == 'Admin') ||
          (_selectedRoleFilter == 'Karyawan / Staf' && role != 'Admin');

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
    final passwordCtrl = TextEditingController(text: 'Kreavana123!');
    String selectedRole = 'Karyawan / Staf';
    bool obscurePassword = true;
    bool isSubmitting = false;
    final Set<String> selectedPermissions = {
      'program_magang',
      'kegiatan_event',
      'mitra_industri',
      'karya_siswa',
    };

    Widget buildForm(BuildContext modalCtx) {
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
                              'Buat Akun Tim & Hak Akses',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Akun karyawan/staf langsung tersinkron ke database',
                              style: TextStyle(
                                fontSize: 11,
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
                const SizedBox(height: 18),
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
                const SizedBox(height: 14),
                const Text(
                  'Alamat Email Login *',
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
                const SizedBox(height: 14),
                const Text(
                  'Kata Sandi Akun Staf *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: passwordCtrl,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Min. 6 karakter (default: Kreavana123!)',
                    helperText: 'Digunakan staf untuk login ke platform Kreavana',
                    helperStyle: const TextStyle(fontSize: 11),
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword ? Icons.visibility_off : Icons.visibility,
                        size: 18,
                      ),
                      onPressed: () => setInnerState(() => obscurePassword = !obscurePassword),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Jabatan / Unit Kerja (Opsional)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: deptCtrl,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Waka Kurikulum / Guru Pembimbing PKL',
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
                const SizedBox(height: 18),
                const Text(
                  'Pilih Peran & Wewenang *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _buildRoleOption(
                  role: 'Admin',
                  title: 'Admin (Akses Penuh)',
                  desc: 'Akses penuh ke seluruh fitur institusi, profil legal, tim & wewenang, serta pengaturan.',
                  color: const Color(0xFFEF4444),
                  icon: Icons.admin_panel_settings_rounded,
                  isSelected: selectedRole == 'Admin',
                  isDark: isDark,
                  onTap: () => setInnerState(() => selectedRole = 'Admin'),
                ),
                const SizedBox(height: 8),
                _buildRoleOption(
                  role: 'Karyawan / Staf',
                  title: 'Karyawan / Staf (Akses Terbatas)',
                  desc: 'Hanya dapat mengakses fitur-fitur yang dicentang di bawah. Fitur lain otomatis hilang dari sidebar.',
                  color: const Color(0xFF6366F1),
                  icon: Icons.badge_rounded,
                  isSelected: selectedRole == 'Karyawan / Staf',
                  isDark: isDark,
                  onTap: () => setInnerState(() => selectedRole = 'Karyawan / Staf'),
                ),
                if (selectedRole == 'Karyawan / Staf') ...[
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Izin Akses Fitur Institusi *',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setInnerState(() {
                                selectedPermissions.clear();
                                for (final f in _institutionFeatures) {
                                  selectedPermissions.add(f['slug'] as String);
                                }
                              });
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Pilih Semua', style: TextStyle(fontSize: 12)),
                          ),
                          const SizedBox(width: 6),
                          TextButton(
                            onPressed: () {
                              setInnerState(() {
                                selectedPermissions.clear();
                              });
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Kosongkan', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.inputDark : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      children: _institutionFeatures.map((f) {
                        final slug = f['slug'] as String;
                        final isChecked = selectedPermissions.contains(slug);
                        return _buildPermissionTile(
                          slug: slug,
                          name: f['name'] as String,
                          desc: f['desc'] as String,
                          icon: f['icon'] as IconData,
                          isChecked: isChecked,
                          isDark: isDark,
                          onChanged: (val) {
                            setInnerState(() {
                              if (val == true) {
                                selectedPermissions.add(slug);
                              } else {
                                selectedPermissions.remove(slug);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.security_rounded, size: 16, color: Color(0xFF6366F1)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Keamanan Data: Fitur yang tidak dicentang otomatis hilang dari sidebar staf dan diblokir dari akses langsung via URL.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF4F46E5), height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                        label: Text(isSubmitting ? 'Menyimpan...' : 'Buat Akun & Simpan'),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final name = nameCtrl.text.trim();
                                final email = emailCtrl.text.trim();
                                final dept = deptCtrl.text.trim();
                                final password = passwordCtrl.text.trim();

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

                                if (password.length < 6) {
                                  AppSweetAlert.warning(
                                    modalCtx,
                                    'Kata sandi minimal 6 karakter.',
                                    title: 'Kata Sandi Lemah',
                                  );
                                  return;
                                }

                                if (selectedRole == 'Karyawan / Staf' && selectedPermissions.isEmpty) {
                                  AppSweetAlert.warning(
                                    modalCtx,
                                    'Pilih minimal 1 fitur yang diizinkan untuk staf.',
                                    title: 'Izin Belum Dipilih',
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
                                    'password': password,
                                    'role': selectedRole,
                                    'permissions': selectedRole == 'Admin'
                                        ? UserModel.defaultInstitutionPermissions
                                        : selectedPermissions.toList(),
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
                                      'Akun $selectedRole untuk $name ($email) berhasil dibuat dan disimpan ke database.',
                                      title: 'Akun Tim Terdaftar',
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
          child: buildForm(modalCtx),
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
            constraints: const BoxConstraints(maxWidth: 540),
            child: buildForm(modalCtx),
          ),
        ),
      );
    }
  }

  void _openEditMemberDialog(Map<String, dynamic> member) {
    if (member['isOwner'] == true) {
      AppSweetAlert.warning(
        context,
        'Wewenang pemilik akun utama sekolah tidak dapat diubah.',
        title: 'Aksi Dibatasi',
      );
      return;
    }

    final isMobile = MediaQuery.of(context).size.width < 640;
    final deptCtrl = TextEditingController(text: member['department']?.toString() ?? '');
    final passwordCtrl = TextEditingController();
    String selectedRole = (member['role']?.toString().toLowerCase() == 'admin') ? 'Admin' : 'Karyawan / Staf';
    bool obscurePassword = true;
    bool isSubmitting = false;

    final initialPerms = member['permissions'] is List
        ? (member['permissions'] as List).map((e) => e.toString()).toSet()
        : <String>{};
    final Set<String> selectedPermissions = Set.from(initialPerms);
    if (selectedPermissions.isEmpty) {
      selectedPermissions.addAll([
        'program_magang',
        'kegiatan_event',
        'mitra_industri',
        'karya_siswa',
      ]);
    }

    Widget buildEditForm(BuildContext modalCtx) {
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
                            color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: Color(0xFF6366F1),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ubah Hak Akses & Wewenang',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              member['name']?.toString() ?? 'Anggota Tim',
                              style: const TextStyle(
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
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.inputDark : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.15),
                        child: Text(
                          (member['name']?.toString() ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.primaryPurple,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member['name']?.toString() ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              member['email']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Jabatan / Unit Kerja',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: deptCtrl,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Waka Kurikulum / Guru Pembimbing PKL',
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
                const SizedBox(height: 14),
                const Text(
                  'Ganti Kata Sandi (Opsional)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: passwordCtrl,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Kosongkan jika tidak ingin mengubah',
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword ? Icons.visibility_off : Icons.visibility,
                        size: 18,
                      ),
                      onPressed: () => setInnerState(() => obscurePassword = !obscurePassword),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Pilih Peran & Wewenang *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _buildRoleOption(
                  role: 'Admin',
                  title: 'Admin (Akses Penuh)',
                  desc: 'Akses penuh ke seluruh fitur institusi, profil legal, tim & wewenang, serta pengaturan.',
                  color: const Color(0xFFEF4444),
                  icon: Icons.admin_panel_settings_rounded,
                  isSelected: selectedRole == 'Admin',
                  isDark: isDark,
                  onTap: () => setInnerState(() => selectedRole = 'Admin'),
                ),
                const SizedBox(height: 8),
                _buildRoleOption(
                  role: 'Karyawan / Staf',
                  title: 'Karyawan / Staf (Akses Terbatas)',
                  desc: 'Hanya dapat mengakses fitur-fitur yang dicentang di bawah. Fitur lain otomatis hilang dari sidebar.',
                  color: const Color(0xFF6366F1),
                  icon: Icons.badge_rounded,
                  isSelected: selectedRole == 'Karyawan / Staf',
                  isDark: isDark,
                  onTap: () => setInnerState(() => selectedRole = 'Karyawan / Staf'),
                ),
                if (selectedRole == 'Karyawan / Staf') ...[
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Izin Akses Fitur Institusi *',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setInnerState(() {
                                selectedPermissions.clear();
                                for (final f in _institutionFeatures) {
                                  selectedPermissions.add(f['slug'] as String);
                                }
                              });
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Pilih Semua', style: TextStyle(fontSize: 12)),
                          ),
                          const SizedBox(width: 6),
                          TextButton(
                            onPressed: () {
                              setInnerState(() {
                                selectedPermissions.clear();
                              });
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Kosongkan', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.inputDark : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      children: _institutionFeatures.map((f) {
                        final slug = f['slug'] as String;
                        final isChecked = selectedPermissions.contains(slug);
                        return _buildPermissionTile(
                          slug: slug,
                          name: f['name'] as String,
                          desc: f['desc'] as String,
                          icon: f['icon'] as IconData,
                          isChecked: isChecked,
                          isDark: isDark,
                          onChanged: (val) {
                            setInnerState(() {
                              if (val == true) {
                                selectedPermissions.add(slug);
                              } else {
                                selectedPermissions.remove(slug);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
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
                            : const Icon(Icons.check_circle_outline_rounded, size: 18),
                        label: Text(isSubmitting ? 'Menyimpan...' : 'Simpan Perubahan'),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final dept = deptCtrl.text.trim();
                                final password = passwordCtrl.text.trim();

                                if (selectedRole == 'Karyawan / Staf' && selectedPermissions.isEmpty) {
                                  AppSweetAlert.warning(
                                    modalCtx,
                                    'Pilih minimal 1 fitur yang diizinkan untuk staf.',
                                    title: 'Izin Belum Dipilih',
                                  );
                                  return;
                                }

                                setInnerState(() => isSubmitting = true);

                                final id = member['id']?.toString() ?? '';
                                final payload = <String, dynamic>{
                                  'resource_type': 'members',
                                  'title': member['name'],
                                  'description': dept.isNotEmpty
                                      ? dept
                                      : 'Staf Lembaga / Sekolah',
                                  'status': 'published',
                                  'metadata': {
                                    'email': member['email'],
                                    'role': selectedRole,
                                    'permissions': selectedRole == 'Admin'
                                        ? UserModel.defaultInstitutionPermissions
                                        : selectedPermissions.toList(),
                                    'department': dept.isNotEmpty
                                        ? dept
                                        : 'Staf Lembaga / Sekolah',
                                    'is_online': member['isOnline'] == true,
                                    'joined_at': member['joinedAt'],
                                    if (password.isNotEmpty) 'password': password,
                                  },
                                };

                                final res = await ApiService.put(
                                  'institution/resources/$id',
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
                                      'Wewenang dan hak akses ${member['name']} berhasil diperbarui.',
                                      title: 'Perubahan Disimpan',
                                    );
                                  }
                                } else {
                                  AppSweetAlert.error(
                                    modalCtx,
                                    res['message']?.toString() ??
                                        'Gagal memperbarui anggota tim.',
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
          child: buildEditForm(modalCtx),
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
            constraints: const BoxConstraints(maxWidth: 540),
            child: buildEditForm(modalCtx),
          ),
        ),
      );
    }
  }

  Widget _buildPermissionTile({
    required String slug,
    required String name,
    required String desc,
    required IconData icon,
    required bool isChecked,
    required bool isDark,
    required ValueChanged<bool?> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!isChecked),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: isChecked,
                onChanged: onChanged,
                activeColor: const Color(0xFF6366F1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              icon,
              size: 18,
              color: isChecked ? const Color(0xFF6366F1) : (isDark ? AppTheme.textMuted : Colors.grey.shade600),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isChecked ? FontWeight.bold : FontWeight.w500,
                      color: isChecked ? (isDark ? Colors.white : Colors.black87) : (isDark ? AppTheme.textMuted : Colors.grey.shade700),
                    ),
                  ),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppTheme.textMuted.withValues(alpha: 0.8) : Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

    final adminCount = _tim.where((m) => (m['role'] as String).toLowerCase() == 'admin').length;
    final staffCount = _tim.where((m) => (m['role'] as String).toLowerCase() != 'admin').length;
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
              label: const Text('Tambah / Undang Staf'),
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
          : Column(
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
                            () => setState(() {
                              _selectedRoleFilter = 'Semua';
                              _currentPage = 1;
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
                              _currentPage = 1;
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
                            'Karyawan / Staf',
                            '$staffCount',
                            const Color(0xFF6366F1),
                            isDark,
                            _selectedRoleFilter == 'Karyawan / Staf',
                            () => setState(() {
                              _selectedRoleFilter =
                                  _selectedRoleFilter == 'Karyawan / Staf'
                                      ? 'Semua'
                                      : 'Karyawan / Staf';
                              _currentPage = 1;
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
                                _buildFilterChip('Karyawan / Staf', staffCount, isDark),
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
                          : Builder(
                              builder: (context) {
                                final safePage = AppPaginationBar.safePage(
                                  _currentPage,
                                  filteredList.length,
                                  pageSize: _pageSize,
                                );
                                final pagedMembers = AppPaginationBar.slicePage(
                                  filteredList,
                                  safePage,
                                  pageSize: _pageSize,
                                );
                                return Column(
                                  children: [
                                    Expanded(
                                      child: ListView.builder(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          6,
                                          16,
                                          12,
                                        ),
                                        itemCount: pagedMembers.length,
                                        itemBuilder: (context, index) {
                                          final member = pagedMembers[index];
                                          return _buildMemberCard(member, isDark);
                                        },
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        4,
                                        16,
                                        16,
                                      ),
                                      child: AppPaginationBar(
                                        totalItems: filteredList.length,
                                        currentPage: safePage,
                                        pageSize: _pageSize,
                                        accentColor: AppTheme.primaryPurple,
                                        itemLabel: 'anggota',
                                        onPageChanged: (page) => setState(
                                          () => _currentPage = page,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                  ],
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
          _currentPage = 1;
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

    final perms = (member['permissions'] is List)
        ? (member['permissions'] as List).map((e) => e.toString()).toList()
        : <String>[];

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
        crossAxisAlignment: CrossAxisAlignment.center,
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
                if (role == 'Karyawan / Staf') ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: perms.isEmpty
                          ? Colors.amber.withValues(alpha: 0.12)
                          : const Color(0xFF6366F1).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: perms.isEmpty
                            ? Colors.amber.withValues(alpha: 0.35)
                            : const Color(0xFF6366F1).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.vpn_key_rounded,
                          size: 11,
                          color: perms.isEmpty ? Colors.amber.shade800 : const Color(0xFF4F46E5),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            perms.isEmpty
                                ? 'Tidak ada izin fitur'
                                : perms.length == _institutionFeatures.length
                                    ? 'Akses Penuh (${perms.length} Fitur)'
                                    : 'Akses ${perms.length} Fitur (${perms.map((slug) {
                                        final f = _institutionFeatures.firstWhere(
                                          (it) => it['slug'] == slug,
                                          orElse: () => {'title': slug},
                                        );
                                        return f['title'];
                                      }).join(", ")})',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: perms.isEmpty
                                  ? Colors.amber.shade900
                                  : const Color(0xFF4338CA),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
              if (action == 'edit') {
                _openEditMemberDialog(member);
              } else if (action == 'resend') {
                AppSweetAlert.info(
                  context,
                  'Info akses dan akun staf telah dikirimkan ke ${member['email']}. Kata sandi default: Kreavana123!',
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
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(
                        Icons.manage_accounts_rounded,
                        size: 16,
                        color: Color(0xFF6366F1),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Ubah Hak Akses & Jabatan',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'resend',
                  child: Row(
                    children: [
                      Icon(Icons.forward_to_inbox_rounded, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Kirim Ulang Info Akun',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
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
                        'Cabut Hak Akses Tim',
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
                          _currentPage = 1;
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
