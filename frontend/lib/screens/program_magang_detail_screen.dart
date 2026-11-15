import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/opportunity_application_model.dart';
import '../models/opportunity_model.dart';
import '../models/user_model.dart';
import '../services/opportunity_service.dart';
import '../services/user_store.dart';
import '../widgets/app_breadcrumbs.dart';
import '../widgets/app_pagination_bar.dart';
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
    this.portfolioUrl = '',
    this.note = '',
    this.isAdditional = false,
    this.isReplacement = false,
    this.replacedStudentName,
  });

  factory SchoolMagangStudent.fromApplication(
    OpportunityApplicationModel app, {
    required bool schoolHasApprovedStudent,
  }) {
    final s = app.status.toLowerCase();
    String label = 'Pending';
    if (s == 'approved') label = 'Diterima';
    if (s == 'rejected') label = 'Ditolak';
    if (s == 'interview' || s == 'under_consideration') label = 'Interview';

    Map<String, dynamic> doc = {};
    if (app.submittedDocuments.isNotEmpty) {
      doc = app.submittedDocuments.first;
    }

    String studentName =
        (doc['student_name'] ?? doc['name'] ?? '').toString().trim();
    String majorClass = (doc['major_class'] ?? doc['student_class'] ?? doc['major'] ?? '').toString().trim();
    String role = (doc['role'] ?? '').toString().trim();
    String portfolioUrl = (doc['portfolio_url'] ?? doc['student_portfolio'] ?? '').toString().trim();
    String note = (doc['note'] ?? '').toString().trim();
    bool isAdditional = doc['is_additional'] == true || doc['submission_type'] == 'additional';
    bool isReplacement = doc['is_replacement'] == true;
    String? replacedName = doc['replaced_student_name']?.toString();

    // Parse fallback from legacy pitch_message format when submitted_documents is absent
    if (studentName.isEmpty && app.pitchMessage.startsWith('Siswa:')) {
      final parts = app.pitchMessage.split('|').map((p) => p.trim()).toList();
      final head = parts.first.replaceFirst('Siswa:', '').trim();
      final parenStart = head.lastIndexOf('(');
      final parenEnd = head.lastIndexOf(')');
      if (parenStart > 0 && parenEnd > parenStart) {
        studentName = head.substring(0, parenStart).trim();
        if (majorClass.isEmpty) {
          majorClass = head.substring(parenStart + 1, parenEnd).trim();
        }
      } else {
        studentName = head;
      }
      for (final part in parts.skip(1)) {
        if (part.startsWith('Portofolio:')) {
          if (portfolioUrl.isEmpty) {
            portfolioUrl = part.replaceFirst('Portofolio:', '').trim();
          }
        } else if (note.isEmpty) {
          note = part;
        }
      }
    }

    if (studentName.isEmpty) {
      studentName = app.creator?.name ?? 'Siswa Magang';
    }
    if (majorClass.isEmpty) {
      majorClass = app.subRoleSlug.replaceAll('_', ' ');
    }
    if (role.isEmpty) {
      role = app.subRoleSlug.replaceAll('_', ' ').toUpperCase();
    }
    if (note.isEmpty) {
      note = app.pitchMessage;
    }

    return SchoolMagangStudent(
      id: app.id,
      name: studentName,
      majorClass: majorClass,
      role: role,
      appliedDate: app.createdAt != null
          ? ProgramMagangCard.formatDateDisplay(app.createdAt)
          : '-',
      status: label,
      portfolioUrl: portfolioUrl,
      note: note,
      isAdditional: isAdditional ||
          (schoolHasApprovedStudent && (s == 'pending' || s == 'submitted')),
      isReplacement: isReplacement,
      replacedStudentName: replacedName,
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
  int _studentPage = 1;
  static const int _studentPageSize = 6;

  // Status institusi pada event magang ini: 'approved', 'pending', 'not_applied'
  late String _schoolPartnershipStatus;
  // Apakah corporate meminta tambahan siswa
  bool _corporateRequestsAdditional = false;
  int _corporateRequestedCount = 0;
  String _corporateRequestNote = '';

  List<SchoolMagangStudent> _students = [];

  UserModel? get _currentUser => widget.user ?? currentUserNotifier.value;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initDefaultState();
    _loadServerData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _initDefaultState() {
    final isApplied = widget.isAppliedPartnership ||
        widget.opportunity.hasApplied ||
        widget.opportunity.approvedCreators.isNotEmpty;

    _schoolPartnershipStatus = isApplied
        ? (widget.opportunity.approvedCreators.isNotEmpty ? 'approved' : 'pending')
        : 'not_applied';
    _corporateRequestsAdditional = false;
    _corporateRequestedCount = 0;
    _corporateRequestNote = '';
    _students = [];
  }

  Future<void> _loadServerData() async {
    setState(() => _isLoading = true);

    try {
      final oppId = widget.opportunity.id ?? '';
      if (oppId.isEmpty) return;

      final results = await Future.wait([
        OpportunityService.getDetail(oppId).catchError((_) => null),
        OpportunityService.getOpportunityApplications(oppId)
            .catchError((_) => <OpportunityApplicationModel>[]),
      ]);

      if (!mounted) return;

      final freshOpp = results[0] as OpportunityModel?;
      final apps = results[1] as List<OpportunityApplicationModel>;
      final effectiveOpp = freshOpp ?? widget.opportunity;

      final currentSchoolId = _currentUser?.id;
      final schoolApps = currentSchoolId != null && currentSchoolId.isNotEmpty
          ? apps.where((a) => a.creatorId == currentSchoolId).toList()
          : apps;

      final hasApproved =
          schoolApps.any((a) => a.status.toLowerCase() == 'approved');

      // Check real DB terms or notes for explicit corporate additional student request
      bool corporateRequestsAdditional = false;
      String corporateNote = '';
      for (final term in effectiveOpp.dynamicTerms) {
        if (term.toLowerCase().contains('tambahan siswa') ||
            term.toLowerCase().contains('request_additional')) {
          corporateRequestsAdditional = true;
          corporateNote = term;
          break;
        }
      }

      final mappedStudents = schoolApps
          .map(
            (a) => SchoolMagangStudent.fromApplication(
              a,
              schoolHasApprovedStudent: hasApproved,
            ),
          )
          .toList();

      setState(() {
        if (hasApproved) {
          _schoolPartnershipStatus = 'approved';
        } else if (schoolApps.isNotEmpty || effectiveOpp.hasApplied) {
          _schoolPartnershipStatus = 'pending';
        } else {
          _schoolPartnershipStatus = 'not_applied';
        }
        _corporateRequestsAdditional = corporateRequestsAdditional;
        _corporateRequestedCount = corporateRequestsAdditional ? 1 : 0;
        _corporateRequestNote = corporateNote;
        _students = mappedStudents;
      });
    } catch (e) {
      debugPrint('Error loading magang detail: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    final majorCtrl = TextEditingController();
    final roleCtrl = TextEditingController(
      text: replacedStudent?.role ??
          (widget.opportunity.requirements.isNotEmpty
              ? widget.opportunity.requirements.first.subRoleSlug.replaceAll('_', ' ').toUpperCase()
              : 'Peserta Magang'),
    );
    final portfolioCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final isMagang = widget.opportunity.isMagang;
            final title = replacedStudent != null
                ? (isMagang ? 'Ajukan Siswa Pengganti' : 'Ajukan Kandidat Pengganti')
                : (isAdditionalStudent
                    ? (isMagang ? 'Ajukan Siswa Tambahan' : 'Ajukan Kandidat Tambahan')
                    : (isMagang ? 'Ajukan Lamaran Magang Sekolah' : 'Ajukan Lamaran Pekerjaan'));

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
                            hintText: 'Contoh: 3D Modeler / UI UX Intern',
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
                            hintText: 'https://...',
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
                  onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Batal'),
                ),
                FilledButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) return;

                          final oppId = widget.opportunity.id ?? '';
                          if (oppId.isEmpty) {
                            AppSweetAlert.error(
                              context,
                              'ID lowongan magang tidak ditemukan di database.',
                            );
                            return;
                          }

                          final studentName = nameCtrl.text.trim();
                          final major = majorCtrl.text.trim();
                          final role = roleCtrl.text.trim();
                          final portfolio = portfolioCtrl.text.trim();
                          final note = noteCtrl.text.trim().isNotEmpty
                              ? noteCtrl.text.trim()
                              : (replacedStudent != null
                                  ? 'Siswa pengganti menggantikan ${replacedStudent.name}.'
                                  : 'Siswa diajukan oleh institusi untuk program magang.');
                          final additionalFlag =
                              isAdditionalStudent || _schoolPartnershipStatus == 'approved';

                          setDialogState(() => isSubmitting = true);

                          final res = await OpportunityService.applyInstitutionStudent(
                            opportunityId: oppId,
                            subRoleSlug: role.toLowerCase().replaceAll(' ', '_'),
                            pitchMessage:
                                'Siswa: $studentName ($major)${portfolio.isNotEmpty ? ' | Portofolio: $portfolio' : ''} | $note',
                            studentDocument: {
                              'student_name': studentName,
                              'major_class': major,
                              'role': role,
                              'portfolio_url': portfolio,
                              'note': note,
                              'is_additional': additionalFlag,
                              'is_replacement': replacedStudent != null,
                              if (replacedStudent != null)
                                'replaced_student_name': replacedStudent.name,
                            },
                          );

                          if (ctx.mounted) {
                            setDialogState(() => isSubmitting = false);
                          }

                          if (res['status'] != true) {
                            if (mounted) {
                              AppSweetAlert.error(
                                context,
                                res['message']?.toString() ??
                                    'Gagal menyimpan pengajuan siswa ke database.',
                              );
                            }
                            return;
                          }

                          if (ctx.mounted) Navigator.of(ctx).pop();
                          await _loadServerData();

                          if (mounted) {
                            setState(() {
                              _selectedStudentFilter = 'Semua';
                              _searchController.clear();
                              _studentPage = 1;
                            });
                            AppSweetAlert.success(
                              context,
                              additionalFlag
                                  ? 'Siswa tambahan $studentName berhasil diajukan dengan status Pending. Status kemitraan sekolah tetap Disetujui.'
                                  : 'Lamaran siswa $studentName berhasil dikirim ke Corporate.',
                              title: 'Pengajuan Berhasil',
                            );
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 16),
                  label: Text(isSubmitting ? 'Mengirim...' : 'Kirim Pengajuan'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                  ),
                ),
          ],
        );
      },
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
              AppBreadcrumbs(
                items: [
                  const BreadcrumbItem(label: 'Beranda', icon: Icons.home_outlined),
                  const BreadcrumbItem(label: 'Program & Magang', icon: Icons.work_outline_rounded),
                  BreadcrumbItem(
                    label: widget.opportunity.isMagang ? 'Detail Program Magang' : 'Detail Lowongan Pekerjaan',
                    icon: Icons.info_outline_rounded,
                  ),
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
                      color: opp.isMagang ? const Color(0xFFE0F2FE) : const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      opp.isMagang ? 'Program Magang' : 'Lowongan Pekerjaan',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: opp.isMagang ? const Color(0xFF0284C7) : const Color(0xFF7E22CE),
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
                  ? (opp.isMagang ? 'Ajukan Lamaran Magang' : 'Ajukan Lamaran Pekerjaan')
                  : (opp.isMagang ? 'Ajukan Siswa Tambahan' : 'Ajukan Kandidat Tambahan'),
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
        ? 'Institusi Anda telah disetujui pada ${widget.opportunity.isMagang ? 'program magang ini' : 'lowongan pekerjaan ini'} ($acceptedCount ${widget.opportunity.isMagang ? 'siswa' : 'kandidat'} diterima${pendingCount > 0 ? ', $pendingCount ${widget.opportunity.isMagang ? 'siswa' : 'kandidat'} tambahan menunggu review' : ''}). Penambahan kandidat baru tidak mengubah status persetujuan sekolah Anda.'
        : (isPending
            ? 'Pengajuan kemitraan ${widget.opportunity.isMagang ? 'magang' : 'rekrutmen'} sekolah Anda sedang ditinjau oleh pihak Corporate.'
            : 'Sekolah Anda belum mendaftarkan ${widget.opportunity.isMagang ? 'siswa pada program magang ini' : 'kandidat pada lowongan pekerjaan ini'}. Klik tombol ${widget.opportunity.isMagang ? 'Ajukan Lamaran Magang' : 'Ajukan Lamaran Pekerjaan'} untuk mendaftarkan.');

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          final iconBox = Container(
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
          );
          final textContent = Column(
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
                      ? (isDark
                          ? const Color(0xFFC4B5FD)
                          : const Color(0xFF5B21B6))
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
          );
          final actionButton = _corporateRequestsAdditional
              ? ElevatedButton(
                  onPressed: () =>
                      _openSubmitStudentDialog(isAdditionalStudent: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Kirim Siswa Tambahan',
                      style: TextStyle(fontSize: 12)),
                )
              : null;

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    iconBox,
                    const SizedBox(width: 12),
                    Expanded(child: textContent),
                  ],
                ),
                if (actionButton != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: actionButton),
                ],
              ],
            );
          }

          return Row(
            children: [
              iconBox,
              const SizedBox(width: 14),
              Expanded(child: textContent),
              if (actionButton != null) ...[
                const SizedBox(width: 12),
                actionButton,
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverviewTab(bool isDark, bool isDesktop, Color accentColor) {
    final opp = widget.opportunity;
    final rawDate = opp.deadline ?? opp.eventDate ?? opp.eventStartDate;
    final period = ProgramMagangCard.formatDateDisplay(rawDate, defaultFallback: '-');

    int totalQuota = 0;
    for (final r in opp.requirements) {
      totalQuota += r.quantity;
    }
    final int filled = opp.approvedCreators.isNotEmpty
        ? opp.approvedCreators.length
        : _students.where((s) => s.status == 'Diterima').length;
    final int remaining = totalQuota > 0 ? (totalQuota - filled).clamp(0, totalQuota) : 0;
    final String quotaLabel = totalQuota > 0
        ? '$remaining dari $totalQuota posisi'
        : 'Sesuai kuota Corporate';

    final reqs = <String>[];
    for (final r in opp.requirements) {
      if (r.tags.isNotEmpty) {
        reqs.addAll(r.tags);
      } else if (r.notes != null && r.notes!.trim().isNotEmpty) {
        reqs.add(r.notes!.trim());
      }
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            opp.isMagang ? 'Deskripsi Program Magang' : 'Deskripsi Lowongan Pekerjaan',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
                value: quotaLabel,
                isDark: isDark,
              ),
              _buildInfoTile(
                icon: Icons.payments_outlined,
                label: 'Uang Saku / Tunjangan',
                value: opp.budgetRange?.isNotEmpty == true
                    ? opp.budgetRange!
                    : 'Sesuai ketentuan Corporate',
                isDark: isDark,
              ),
            ],
          ),
          if (reqs.isNotEmpty) ...[
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 165, maxWidth: 240),
      child: Container(
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
      ),
    );
  }

  Widget _buildStudentsTab(bool isDark, bool isDesktop, Color accentColor) {
    final accepted = _students.where((s) => s.status == 'Diterima').length;
    final pending = _students.where((s) => s.status == 'Pending').length;
    final interview = _students.where((s) => s.status == 'Interview').length;
    final rejected = _students.where((s) => s.status == 'Ditolak').length;

    final filtered = _filteredStudents;
    final totalItems = filtered.length;
    final totalPages =
        totalItems == 0 ? 1 : (totalItems / _studentPageSize).ceil();
    final safePage = _studentPage.clamp(1, totalPages);
    final startIdx = (safePage - 1) * _studentPageSize;
    final endIdx = (startIdx + _studentPageSize).clamp(0, totalItems);
    final pagedStudents =
        totalItems == 0 ? <SchoolMagangStudent>[] : filtered.sublist(startIdx, endIdx);

    return Padding(
      padding: EdgeInsets.all(isDesktop ? 20 : 14),
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
          LayoutBuilder(
            builder: (context, constraints) {
              final searchField = TextField(
                controller: _searchController,
                onChanged: (_) => setState(() => _studentPage = 1),
                decoration: InputDecoration(
                  hintText: 'Cari nama siswa, kelas, atau posisi...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
              final addButton = ElevatedButton.icon(
                onPressed: () => _openSubmitStudentDialog(
                  isAdditionalStudent: _schoolPartnershipStatus == 'approved',
                ),
                icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                label: Text(
                  _schoolPartnershipStatus == 'approved'
                      ? 'Tambah Siswa'
                      : 'Ajukan Siswa',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );

              if (constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: 10),
                    addButton,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 12),
                  addButton,
                ],
              );
            },
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
                    onSelected: (_) => setState(() {
                      _selectedStudentFilter = f;
                      _studentPage = 1;
                    }),
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

          if (pagedStudents.isEmpty)
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
                  Text(
                    widget.opportunity.isMagang ? 'Belum Ada Siswa yang Diajukan' : 'Belum Ada Kandidat yang Diajukan',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.opportunity.isMagang
                        ? 'Daftarkan siswa sekolah Anda untuk mengikuti program magang industri ini.'
                        : 'Daftarkan talenta institusi Anda untuk melamar lowongan pekerjaan ini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            ...pagedStudents.map((s) => _buildStudentCard(s, isDark)),
            const SizedBox(height: 12),
            AppPaginationBar(
              totalItems: totalItems,
              currentPage: safePage,
              pageSize: _studentPageSize,
              accentColor: accentColor,
              itemLabel: 'siswa',
              onPageChanged: (page) => setState(() => _studentPage = page),
            ),
          ],
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          s.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        if (s.isAdditional)
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    const SizedBox(height: 4),
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
