import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app/theme.dart';
import '../models/opportunity_model.dart';
import '../models/user_model.dart';
import '../services/opportunity_service.dart';
import '../services/user_store.dart';
import '../widgets/app_breadcrumbs.dart';
import '../widgets/app_sweet_alert.dart';
import '../widgets/desktop_sidebar_layout.dart';
import '../widgets/program_magang_card.dart';

class SchoolMagangStudent {
  final String id;
  final String name;
  final String majorClass;
  final String role;
  final String appliedDate;
  final String status; // 'Diterima', 'Pending', 'Interview', 'Ditolak'
  final String portfolioUrl;
  final String note;
  final bool isAdditional;
  final bool isReplacement;
  final String? replacedStudentName;

  const SchoolMagangStudent({
    required this.id,
    required this.name,
    required this.majorClass,
    required this.role,
    required this.appliedDate,
    required this.status,
    this.portfolioUrl = 'https://kreavana.id/portfolio',
    this.note = '',
    this.isAdditional = false,
    this.isReplacement = false,
    this.replacedStudentName,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'majorClass': majorClass,
        'role': role,
        'appliedDate': appliedDate,
        'status': status,
        'portfolioUrl': portfolioUrl,
        'note': note,
        'isAdditional': isAdditional,
        'isReplacement': isReplacement,
        'replacedStudentName': replacedStudentName,
      };

  factory SchoolMagangStudent.fromJson(Map<String, dynamic> json) {
    return SchoolMagangStudent(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      majorClass: (json['majorClass'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      appliedDate: (json['appliedDate'] ?? 'Hari ini').toString(),
      status: (json['status'] ?? 'Pending').toString(),
      portfolioUrl: (json['portfolioUrl'] ?? 'https://kreavana.id/portfolio').toString(),
      note: (json['note'] ?? '').toString(),
      isAdditional: json['isAdditional'] == true,
      isReplacement: json['isReplacement'] == true,
      replacedStudentName: json['replacedStudentName']?.toString(),
    );
  }
}

class ProgramMagangDetailScreen extends StatefulWidget {
  final OpportunityModel opportunity;
  final UserModel? user;
  final ValueChanged<UserModel>? onUserUpdated;
  final bool isAppliedPartnership;

  const ProgramMagangDetailScreen({
    super.key,
    required this.opportunity,
    this.user,
    this.onUserUpdated,
    this.isAppliedPartnership = false,
  });

  @override
  State<ProgramMagangDetailScreen> createState() => _ProgramMagangDetailScreenState();
}

class _ProgramMagangDetailScreenState extends State<ProgramMagangDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String _selectedStudentFilter = 'Semua';
  final TextEditingController _searchController = TextEditingController();

  // Status institusi pada event magang ini: 'approved', 'pending', 'not_applied'
  late String _schoolPartnershipStatus;
  // Apakah corporate meminta tambahan siswa
  bool _corporateRequestsAdditional = false;
  int _corporateRequestedCount = 0;
  String _corporateRequestNote = '';

  List<SchoolMagangStudent> _students = [];

  UserModel? get _currentUser => widget.user ?? currentUserNotifier.value;

  String get _storageKey => 'school_magang_detail_${widget.opportunity.id}';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initDefaultState();
    _loadPersistedAndServerData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _initDefaultState() {
    final oppId = widget.opportunity.id ?? '';
    final isApplied = widget.isAppliedPartnership ||
        oppId.startsWith('sch_opp_magang_') ||
        widget.opportunity.applicationsCount > 0 ||
        widget.opportunity.approvedCreators.isNotEmpty;

    if (oppId == 'sch_opp_magang_1') {
      _schoolPartnershipStatus = 'approved';
      _corporateRequestsAdditional = true;
      _corporateRequestedCount = 1;
      _corporateRequestNote =
          'Corporate meminta 1 siswa tambahan untuk posisi Junior 3D Modeler karena perluasan divisi produksi aset.';
      _students = const [
        SchoolMagangStudent(
          id: 'std_1',
          name: 'Dimas Aditya',
          majorClass: 'XII Animasi 1',
          role: 'Junior 3D Modeler',
          appliedDate: '10 Feb 2026',
          status: 'Diterima',
          note: 'Portofolio hard-surface 3D modeling sangat rapi dan memenuhi standar studio.',
        ),
        SchoolMagangStudent(
          id: 'std_2',
          name: 'Siti Nurhaliza',
          majorClass: 'XII Animasi 2',
          role: '3D Texture & Shading',
          appliedDate: '10 Feb 2026',
          status: 'Diterima',
          note: 'Lolos seleksi tahap akhir dan siap penempatan batch I.',
        ),
        SchoolMagangStudent(
          id: 'std_3',
          name: 'Raka Pratama',
          majorClass: 'XII Multimedia 1',
          role: 'Junior 3D Modeler',
          appliedDate: '12 Feb 2026',
          status: 'Ditolak',
          note: 'Belum memenuhi kriteria portofolio UV mapping.',
        ),
      ];
    } else if (oppId == 'sch_opp_magang_2') {
      _schoolPartnershipStatus = 'approved';
      _corporateRequestsAdditional = false;
      _corporateRequestedCount = 0;
      _corporateRequestNote = '';
      _students = const [
        SchoolMagangStudent(
          id: 'std_21',
          name: 'Nadia Putri',
          majorClass: 'XII RPL 1',
          role: 'UI/UX Designer Intern',
          appliedDate: '14 Feb 2026',
          status: 'Diterima',
          note: 'Desain sistem Figma sangat terstruktur.',
        ),
        SchoolMagangStudent(
          id: 'std_22',
          name: 'Fajar Nugroho',
          majorClass: 'XII DKV 2',
          role: 'Product Design Intern',
          appliedDate: '15 Feb 2026',
          status: 'Interview',
          note: 'Menunggu jadwal wawancara teknis bersama Lead Designer.',
        ),
      ];
    } else if (isApplied) {
      _schoolPartnershipStatus =
          widget.opportunity.approvedCreators.isNotEmpty ? 'approved' : 'pending';
      _corporateRequestsAdditional = false;
      _students = [];
    } else {
      _schoolPartnershipStatus = 'not_applied';
      _corporateRequestsAdditional = false;
      _students = [];
    }
  }

  Future<void> _loadPersistedAndServerData() async {
    setState(() => _isLoading = true);

    try {
      // 1. Load locally persisted student additions / partnership state
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(_storageKey);
      if (savedJson != null && savedJson.isNotEmpty) {
        final decoded = jsonDecode(savedJson) as Map<String, dynamic>;
        if (decoded['schoolStatus'] is String) {
          _schoolPartnershipStatus = decoded['schoolStatus'] as String;
        }
        if (decoded['students'] is List) {
          final loadedStudents = (decoded['students'] as List)
              .whereType<Map<String, dynamic>>()
              .map((e) => SchoolMagangStudent.fromJson(e))
              .toList();
          if (loadedStudents.isNotEmpty) {
            _students = loadedStudents;
          }
        }
      }

      // 2. Fetch real server applications if opportunity ID is a real backend ID
      final oppId = widget.opportunity.id ?? '';
      if (oppId.isNotEmpty && !oppId.startsWith('sch_opp_')) {
        final apps = await OpportunityService.getOpportunityApplications(oppId);
        if (apps.isNotEmpty && mounted) {
          final currentSchoolId = _currentUser?.id;
          final schoolApps = currentSchoolId != null
              ? apps.where((a) => a.creatorId == currentSchoolId).toList()
              : apps;

          if (schoolApps.isNotEmpty) {
            final hasApproved =
                schoolApps.any((a) => a.status.toLowerCase() == 'approved');
            if (hasApproved) {
              _schoolPartnershipStatus = 'approved';
            } else if (_schoolPartnershipStatus == 'not_applied') {
              _schoolPartnershipStatus = 'pending';
            }

            final mapped = schoolApps.map((a) {
              final s = a.status.toLowerCase();
              String label = 'Pending';
              if (s == 'approved') label = 'Diterima';
              if (s == 'rejected') label = 'Ditolak';
              if (s == 'interview') label = 'Interview';

              return SchoolMagangStudent(
                id: a.id,
                name: a.creator?.name ?? 'Siswa Magang',
                majorClass: a.subRoleSlug.replaceAll('_', ' '),
                role: a.subRoleSlug.replaceAll('_', ' ').toUpperCase(),
                appliedDate: a.createdAt != null
                    ? ProgramMagangCard.formatDateDisplay(a.createdAt)
                    : 'Hari ini',
                status: label,
                note: a.pitchMessage,
                isAdditional: hasApproved && s == 'pending',
              );
            }).toList();

            // Merge server apps with any local pending additions
            final serverIds = mapped.map((e) => e.id).toSet();
            final localExtra =
                _students.where((s) => !serverIds.contains(s.id) && s.isAdditional).toList();
            _students = [...mapped, ...localExtra];
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading magang detail: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveLocalState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode({
          'schoolStatus': _schoolPartnershipStatus,
          'students': _students.map((s) => s.toJson()).toList(),
        }),
      );
    } catch (e) {
      debugPrint('Error saving magang detail locally: $e');
    }
  }

  List<SchoolMagangStudent> get _filteredStudents {
    return _students.where((s) {
      if (_selectedStudentFilter != 'Semua') {
        if (_selectedStudentFilter == 'Pending') {
          if (s.status != 'Pending' && !s.status.toLowerCase().contains('menunggu')) {
            return false;
          }
        } else if (s.status != _selectedStudentFilter) {
          return false;
        }
      }

      final q = _searchController.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        return s.name.toLowerCase().contains(q) ||
            s.majorClass.toLowerCase().contains(q) ||
            s.role.toLowerCase().contains(q);
      }

      return true;
    }).toList();
  }

  Future<void> _openSubmitStudentDialog({
    bool isAdditionalStudent = false,
    SchoolMagangStudent? replacedStudent,
  }) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final majorCtrl = TextEditingController(text: 'XII RPL / Animasi');
    final roleCtrl = TextEditingController(
      text: replacedStudent?.role ??
          (widget.opportunity.requirements.isNotEmpty
              ? widget.opportunity.requirements.first.subRoleSlug.replaceAll('_', ' ').toUpperCase()
              : 'Peserta Magang'),
    );
    final portfolioCtrl = TextEditingController(text: 'https://kreavana.id/portfolio');
    final noteCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final title = replacedStudent != null
            ? 'Ajukan Siswa Pengganti'
            : (isAdditionalStudent
                ? 'Ajukan Siswa Tambahan'
                : 'Ajukan Lamaran Magang Sekolah');

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF6366F1), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isAdditionalStudent && _schoolPartnershipStatus == 'approved')
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Status kemitraan sekolah Anda tetap Disetujui (Approved). Hanya siswa baru ini yang akan berstatus Pending menunggu persetujuan Corporate.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nama Lengkap Siswa *',
                        hintText: 'Contoh: Ahmad Fauzan',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Nama siswa wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: majorCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Kelas & Jurusan *',
                        hintText: 'Contoh: XII Animasi 1',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Kelas/jurusan wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: roleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Posisi / Spesialisasi yang Dilamar *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Posisi wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: portfolioCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tautan Portofolio / CV',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: noteCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Catatan Pengajuan untuk Corporate',
                        hintText: 'Jelaskan kompetensi siswa atau keterangan tambahan...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            FilledButton.icon(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;

                final studentName = nameCtrl.text.trim();
                final major = majorCtrl.text.trim();
                final role = roleCtrl.text.trim();
                final portfolio = portfolioCtrl.text.trim();
                final note = noteCtrl.text.trim().isNotEmpty
                    ? noteCtrl.text.trim()
                    : (replacedStudent != null
                        ? 'Siswa pengganti menggantikan ${replacedStudent.name}.'
                        : 'Siswa diajukan oleh institusi untuk program magang.');

                // Call backend API if real opportunity
                final oppId = widget.opportunity.id ?? '';
                if (oppId.isNotEmpty && !oppId.startsWith('sch_opp_')) {
                  await OpportunityService.applyToOpportunity(
                    opportunityId: oppId,
                    subRoleSlug: role.toLowerCase().replaceAll(' ', '_'),
                    pitchMessage:
                        'Siswa: $studentName ($major) | Portofolio: $portfolio | $note',
                  );
                }

                final newStudent = SchoolMagangStudent(
                  id: 'std_${DateTime.now().millisecondsSinceEpoch}',
                  name: studentName,
                  majorClass: major,
                  role: role,
                  appliedDate: 'Hari ini',
                  status: 'Pending',
                  portfolioUrl: portfolio,
                  note: note,
                  isAdditional: isAdditionalStudent || _schoolPartnershipStatus == 'approved',
                  isReplacement: replacedStudent != null,
                  replacedStudentName: replacedStudent?.name,
                );

                setState(() {
                  _students.add(newStudent);
                  // IMPORTANT: Jika sekolah sudah approved, status sekolah TETAP approved!
                  // Hanya jika sekolah belum melamar sama sekali, baru menjadi 'pending'.
                  if (_schoolPartnershipStatus == 'not_applied') {
                    _schoolPartnershipStatus = 'pending';
                  }
                });

                await _saveLocalState();

                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  AppSweetAlert.success(
                    context,
                    isAdditionalStudent && _schoolPartnershipStatus == 'approved'
                        ? 'Siswa tambahan $studentName berhasil diajukan dengan status Pending. Status kemitraan sekolah tetap Disetujui.'
                        : 'Lamaran siswa $studentName berhasil dikirim ke Corporate.',
                    title: 'Pengajuan Berhasil',
                  );
                }
              },
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Kirim Pengajuan'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentColor = Color(0xFF6366F1);
    final effectiveUser = _currentUser ?? UserModel.guest();

    final content = Scaffold(
      backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 28.0 : 16.0,
            vertical: 20.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Breadcrumbs
              const AppBreadcrumbs(
                items: [
                  BreadcrumbItem(label: 'Beranda', icon: Icons.home_outlined),
                  BreadcrumbItem(label: 'Program & Magang', icon: Icons.work_outline_rounded),
                  BreadcrumbItem(label: 'Detail Program Magang', icon: Icons.info_outline_rounded),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Back button + Header
              _buildHeader(isDark, isDesktop, accentColor),
              const SizedBox(height: 20),

              // 3. School Partnership Status Banner
              _buildSchoolStatusBanner(isDark, isDesktop, accentColor),
              const SizedBox(height: 14),

              // 4. Corporate Additional Student Request Banner
              _buildCorporateRequestBanner(isDark, isDesktop),
              const SizedBox(height: 20),

              // 5. Tabs
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      labelColor: accentColor,
                      unselectedLabelColor:
                          isDark ? Colors.white60 : Colors.grey.shade600,
                      indicatorColor: accentColor,
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      tabs: [
                        const Tab(text: 'Ringkasan & Detail Program'),
                        Tab(
                          text: 'Daftar Siswa (${_students.length})',
                        ),
                      ],
                    ),
                    const Divider(height: 1),
                    AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, _) {
                        if (_isLoading) {
                          return const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (_tabController.index == 0) {
                          return _buildOverviewTab(isDark, isDesktop, accentColor);
                        }
                        return _buildStudentsTab(isDark, isDesktop, accentColor);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (isDesktop) {
      return DesktopSidebarLayout(
        user: effectiveUser,
        activeRoute: 'program_magang',
        onUserUpdated: widget.onUserUpdated,
        child: content,
      );
    }

    return content;
  }

  Widget _buildHeader(bool isDark, bool isDesktop, Color accentColor) {
    final opp = widget.opportunity;
    final corporateName = opp.poster?.name.isNotEmpty == true
        ? opp.poster!.name
        : 'Mitra Industri Corporate';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          tooltip: 'Kembali ke Program & Magang',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          style: IconButton.styleFrom(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            side: BorderSide(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Program Magang',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF16A34A),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          opp.isClosed ? 'Pendaftaran Ditutup' : 'Pendaftaran Dibuka',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                opp.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.business_rounded,
                      size: 16, color: isDark ? Colors.white60 : Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    corporateName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (isDesktop) ...[
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _openSubmitStudentDialog(
              isAdditionalStudent: _schoolPartnershipStatus == 'approved',
            ),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: Colors.white),
            label: Text(
              _schoolPartnershipStatus == 'not_applied'
                  ? 'Ajukan Lamaran Magang'
                  : 'Ajukan Siswa Tambahan',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSchoolStatusBanner(bool isDark, bool isDesktop, Color accentColor) {
    final bool isApproved = _schoolPartnershipStatus == 'approved';
    final bool isPending = _schoolPartnershipStatus == 'pending';

    final Color bg = isApproved
        ? const Color(0xFFECFDF5)
        : (isPending ? const Color(0xFFFFFBEB) : const Color(0xFFF1F5F9));
    final Color border = isApproved
        ? const Color(0xFFA7F3D0)
        : (isPending ? const Color(0xFFFDE68A) : const Color(0xFFCBD5E1));
    final Color iconColor = isApproved
        ? const Color(0xFF059669)
        : (isPending ? const Color(0xFFD97706) : const Color(0xFF475569));
    final IconData icon = isApproved
        ? Icons.verified_rounded
        : (isPending ? Icons.hourglass_top_rounded : Icons.info_outline_rounded);

    final String titleText = isApproved
        ? 'Status Sekolah: Disetujui / Bermitra (Approved)'
        : (isPending
            ? 'Status Sekolah: Menunggu Persetujuan Corporate (Pending)'
            : 'Status Sekolah: Belum Mengajukan Lamaran');

    final acceptedCount = _students.where((s) => s.status == 'Diterima').length;
    final pendingCount = _students.where((s) => s.status == 'Pending').length;

    final String subText = isApproved
        ? 'Institusi Anda telah disetujui pada program magang ini ($acceptedCount siswa diterima${pendingCount > 0 ? ', $pendingCount siswa tambahan menunggu review' : ''}). Penambahan siswa baru tidak mengubah status persetujuan sekolah Anda.'
        : (isPending
            ? 'Pengajuan kemitraan magang sekolah Anda sedang ditinjau oleh pihak Corporate.'
            : 'Sekolah Anda belum mendaftarkan siswa pada program magang ini. Klik tombol Ajukan Lamaran Magang untuk mendaftarkan siswa.');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? iconColor.withValues(alpha: 0.4) : border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subText,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorporateRequestBanner(bool isDark, bool isDesktop) {
    if (_schoolPartnershipStatus == 'not_applied') {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B)
            : (_corporateRequestsAdditional ? const Color(0xFFF5F3FF) : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _corporateRequestsAdditional
              ? const Color(0xFFC4B5FD)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (_corporateRequestsAdditional
                      ? const Color(0xFF7C3AED)
                      : const Color(0xFF64748B))
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _corporateRequestsAdditional
                  ? Icons.group_add_rounded
                  : Icons.check_circle_outline_rounded,
              color: _corporateRequestsAdditional
                  ? const Color(0xFF7C3AED)
                  : const Color(0xFF64748B),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _corporateRequestsAdditional
                      ? 'Permintaan Tambahan Siswa dari Corporate ($_corporateRequestedCount Siswa)'
                      : 'Permintaan Tambahan Siswa: Tidak Ada Permintaan Khusus',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: _corporateRequestsAdditional
                        ? (isDark ? const Color(0xFFC4B5FD) : const Color(0xFF5B21B6))
                        : (isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _corporateRequestsAdditional
                      ? '$_corporateRequestNote Siswa baru yang diajukan akan masuk dalam status Pending.'
                      : 'Saat ini Corporate belum meminta tambahan siswa baru. Anda tetap dapat mengajukan siswa tambahan jika kuota masih tersedia.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          if (_corporateRequestsAdditional) ...[
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => _openSubmitStudentDialog(isAdditionalStudent: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Kirim Siswa Tambahan', style: TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewTab(bool isDark, bool isDesktop, Color accentColor) {
    final opp = widget.opportunity;
    final rawDate = opp.deadline ?? opp.eventDate ?? opp.eventStartDate;
    final period = ProgramMagangCard.formatDateDisplay(rawDate, defaultFallback: '21 Sep 2026');

    int totalQuota = 0;
    for (final r in opp.requirements) {
      totalQuota += r.quantity;
    }
    if (totalQuota <= 0) totalQuota = 10;
    final int filled = opp.approvedCreators.isNotEmpty
        ? opp.approvedCreators.length
        : _students.where((s) => s.status == 'Diterima').length;
    final int remaining = (totalQuota - filled).clamp(0, totalQuota);

    final reqs = <String>[];
    for (final r in opp.requirements) {
      if (r.tags.isNotEmpty) {
        reqs.addAll(r.tags);
      } else if (r.notes != null && r.notes!.trim().isNotEmpty) {
        reqs.add(r.notes!.trim());
      }
    }
    if (reqs.isEmpty) {
      reqs.addAll([
        'Siswa SMK / Mahasiswa jurusan terkait',
        'Memiliki portofolio karya yang relevan',
        'Disiplin dan komunikatif dalam kerja tim',
      ]);
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Deskripsi Program Magang',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            opp.description ??
                'Kerja sama penempatan siswa vokasi magang pada industri kreatif mitra.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildInfoTile(
                icon: Icons.calendar_today_rounded,
                label: 'Periode Pendaftaran',
                value: period,
                isDark: isDark,
              ),
              _buildInfoTile(
                icon: Icons.people_outline_rounded,
                label: 'Sisa Kuota Posisi',
                value: '$remaining dari $totalQuota posisi',
                isDark: isDark,
              ),
              _buildInfoTile(
                icon: Icons.payments_outlined,
                label: 'Uang Saku / Tunjangan',
                value: opp.budgetRange?.isNotEmpty == true
                    ? opp.budgetRange!
                    : 'Rp 3.000.000 / bulan',
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Syarat & Kualifikasi',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...reqs.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 17, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF6366F1)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsTab(bool isDark, bool isDesktop, Color accentColor) {
    final accepted = _students.where((s) => s.status == 'Diterima').length;
    final pending = _students.where((s) => s.status == 'Pending').length;
    final interview = _students.where((s) => s.status == 'Interview').length;
    final rejected = _students.where((s) => s.status == 'Ditolak').length;

    final filtered = _filteredStudents;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats strip
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildStudentStatBadge('Total Diajukan', _students.length, const Color(0xFF6366F1)),
              _buildStudentStatBadge('Diterima', accepted, const Color(0xFF16A34A)),
              _buildStudentStatBadge('Pending (Baru/Tambahan)', pending, const Color(0xFFD97706)),
              _buildStudentStatBadge('Interview', interview, const Color(0xFF2563EB)),
              _buildStudentStatBadge('Ditolak', rejected, const Color(0xFFDC2626)),
            ],
          ),
          const SizedBox(height: 16),

          // Search + filter + button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Cari nama siswa, kelas, atau posisi...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _openSubmitStudentDialog(
                  isAdditionalStudent: _schoolPartnershipStatus == 'approved',
                ),
                icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                label: Text(
                  _schoolPartnershipStatus == 'approved'
                      ? 'Tambah Siswa'
                      : 'Ajukan Siswa',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Semua', 'Diterima', 'Pending', 'Interview', 'Ditolak'].map((f) {
                final sel = _selectedStudentFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: sel,
                    onSelected: (_) => setState(() => _selectedStudentFilter = f),
                    selectedColor: accentColor,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                      color: sel ? Colors.white : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          if (filtered.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.school_outlined, size: 36, color: Color(0xFF6366F1)),
                  const SizedBox(height: 10),
                  const Text(
                    'Belum Ada Siswa yang Diajukan',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Daftarkan siswa sekolah Anda untuk mengikuti program magang industri ini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          else
            ...filtered.map((s) => _buildStudentCard(s, isDark)),
        ],
      ),
    );
  }

  Widget _buildStudentStatBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(SchoolMagangStudent s, bool isDark) {
    Color statusColor = const Color(0xFFD97706);
    Color statusBg = const Color(0xFFFEF3C7);
    if (s.status == 'Diterima') {
      statusColor = const Color(0xFF16A34A);
      statusBg = const Color(0xFFDCFCE7);
    } else if (s.status == 'Interview') {
      statusColor = const Color(0xFF2563EB);
      statusBg = const Color(0xFFDBEAFE);
    } else if (s.status == 'Ditolak') {
      statusColor = const Color(0xFFDC2626);
      statusBg = const Color(0xFFFEE2E2);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: s.isAdditional
              ? const Color(0xFFC4B5FD)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.14),
                child: Text(
                  s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          s.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        if (s.isAdditional) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE9FE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              s.isReplacement ? 'Siswa Pengganti' : 'Siswa Tambahan',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF7C3AED),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${s.majorClass} • ${s.role} • Diajukan: ${s.appliedDate}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  s.status == 'Pending' && s.isAdditional
                      ? 'Pending (Menunggu Corporate)'
                      : s.status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (s.note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                s.note,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
            ),
          ],
          if (s.status == 'Ditolak') ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _openSubmitStudentDialog(
                  isAdditionalStudent: true,
                  replacedStudent: s,
                ),
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: const Text('Ajukan Siswa Pengganti'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1),
                  side: const BorderSide(color: Color(0xFF6366F1)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
