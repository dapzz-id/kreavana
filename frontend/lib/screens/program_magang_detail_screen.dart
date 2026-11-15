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
    bool isSchoolApproved = false,
  }) {
    final s = app.status.toLowerCase();
    String label = 'Pending';
    if (s == 'approved') {
      label = 'Diterima';
    } else if (s == 'rejected') {
      label = 'Ditolak';
    } else if (s == 'interview') {
      label = 'Interview';
    } else if (isSchoolApproved ||
        schoolHasApprovedStudent ||
        s == 'review' ||
        s == 'in_review' ||
        s == 'under_consideration') {
      label = 'Review';
    } else {
      label = 'Pending';
    }

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
      isAdditional: isAdditional,
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
      if (oppId.isEmpty || oppId.startsWith('test_')) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

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

      final hasApprovedStudent =
          schoolApps.any((a) => a.status.toLowerCase() == 'approved');

      final isSchoolApprovedByOpp = effectiveOpp.approvedCreators.any(
        (c) => c.id == currentSchoolId || c.name.toLowerCase() == _currentUser?.name.toLowerCase(),
      ) || (effectiveOpp.approvedCreators.isNotEmpty && (widget.isAppliedPartnership || effectiveOpp.hasApplied));

      final hasUnderReview = schoolApps.any((a) {
        final st = a.status.toLowerCase();
        return st == 'under_consideration' || st == 'review' || st == 'in_review';
      });

      final isSchoolApproved = hasApprovedStudent ||
          isSchoolApprovedByOpp ||
          _schoolPartnershipStatus == 'approved' ||
          hasUnderReview;

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
              schoolHasApprovedStudent: hasApprovedStudent,
              isSchoolApproved: isSchoolApproved,
            ),
          )
          .toList();

      setState(() {
        if (isSchoolApproved) {
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
        if (_selectedStudentFilter == 'Pending' || _selectedStudentFilter == 'Review') {
          if (s.status != 'Pending' &&
              s.status != 'Review' &&
              !s.status.toLowerCase().contains('menunggu') &&
              !s.status.toLowerCase().contains('review')) {
            return false;
          }
        } else if (_selectedStudentFilter == 'Diterima') {
          if (s.status != 'Diterima' && !s.status.toLowerCase().contains('diterima')) {
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

    // Extract available specialization roles from requirements
    final availableRoles = <String>[];
    for (final r in widget.opportunity.requirements) {
      final sub = r.subRoleSlug.trim().toLowerCase();
      if (sub == 'kualifikasi' || sub == 'qualification' || sub == 'syarat') continue;
      final notes = (r.notes ?? '').trim();
      if (notes.isNotEmpty &&
          !notes.toLowerCase().startsWith('spesialisasi') &&
          (notes.startsWith('Memiliki') ||
           notes.startsWith('Mampu') ||
           notes.startsWith('Siswa') ||
           notes.startsWith('Mahasiswa') ||
           notes.startsWith('Disiplin') ||
           notes.startsWith('Menguasai') ||
           notes.startsWith('Siap'))) {
        continue;
      }
      if (notes.isNotEmpty && notes.toLowerCase().startsWith('spesialisasi')) {
        final clean = notes.replaceFirst(RegExp(r'^spesialisasi\s+', caseSensitive: false), '');
        final roleOnly = clean.split('(').first.trim();
        if (roleOnly.isNotEmpty && !availableRoles.contains(roleOnly)) {
          availableRoles.add(roleOnly);
        }
      } else {
        final roleOnly = r.subRoleSlug.replaceAll('_', ' ').trim();
        if (roleOnly.isNotEmpty && !availableRoles.contains(roleOnly)) {
          availableRoles.add(roleOnly);
        }
      }
    }
    if (availableRoles.isEmpty && widget.opportunity.subRoleSlug.isNotEmpty) {
      final cleanSub = widget.opportunity.subRoleSlug.replaceAll('_', ' ').trim();
      if (cleanSub.isNotEmpty && cleanSub.toLowerCase() != 'kualifikasi') {
        availableRoles.add(cleanSub);
      }
    }

    final initialRole = replacedStudent?.role ??
        (availableRoles.isNotEmpty
            ? availableRoles.first
            : (widget.opportunity.isMagang ? 'Peserta Magang' : 'Kandidat Lowongan'));

    final roleCtrl = TextEditingController(text: initialRole);
    final portfolioCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    bool isSubmitting = false;

    Widget buildSectionCard({
      required bool isDark,
      required Color accentColor,
      required String title,
      required IconData icon,
      required List<Widget> children,
    }) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: accentColor),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );
    }

    Widget buildFormContent(StateSetter setDialogState, BuildContext ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final isMagang = widget.opportunity.isMagang;
      const accentColor = Color(0xFF6366F1);

      final String title;
      final String badgeText;
      final String subtitle;

      if (replacedStudent != null) {
        title = isMagang ? 'Ajukan Siswa Pengganti' : 'Ajukan Kandidat Pengganti';
        badgeText = 'Penggantian Siswa';
        subtitle = 'Gantikan kandidat yang ditolak dengan kandidat lain yang memenuhi kualifikasi.';
      } else if (isAdditionalStudent) {
        title = isMagang ? 'Ajukan Siswa Tambahan' : 'Ajukan Kandidat Tambahan';
        badgeText = 'Kemitraan Resmi';
        subtitle = 'Daftarkan siswa tambahan untuk memperkuat alokasi talenta institusi sekolah.';
      } else {
        title = isMagang ? 'Ajukan Kandidat Siswa Magang' : 'Ajukan Kandidat Pekerjaan';
        badgeText = 'Pendaftaran Resmi';
        subtitle = 'Daftarkan data siswa berprestasi untuk seleksi dan penempatan pada lowongan ini.';
      }

      return Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP HEADER (Icon box, title, badge, subtitle, close button)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor,
                          HSLColor.fromColor(accentColor).withLightness(0.35).toColor(),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badgeText,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. GUIDANCE BANNER
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [const Color(0xFFEFF6FF), const Color(0xFFF0FDF4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.3) : const Color(0xFFBFDBFE),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.lightbulb_rounded, size: 18, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Panduan Pengajuan Siswa & Seleksi Kemitraan:',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            replacedStudent != null
                                ? '• Pengajuan ini menggantikan berkas kandidat ${replacedStudent.name} (${replacedStudent.role}) yang sebelumnya ditolak.\n'
                                  '• Pastikan data identitas siswa lengkap dan berkas portofolio relevan dengan kriteria industri.\n'
                                  '• Pengajuan pengganti akan langsung tersimpan dan diverifikasi oleh pihak Corporate industri.'
                                : (isAdditionalStudent && _schoolPartnershipStatus == 'approved')
                                    ? '• Status kemitraan sekolah tetap Disetujui (Approved). Siswa tambahan akan masuk dalam status Pending.\n'
                                      '• Masukkan identitas siswa dan pilih posisi spesialisasi yang diinginkan sesuai kebutuhan kuota.\n'
                                      '• Corporate akan meninjau kualifikasi berkas siswa tambahan secara terintegrasi.'
                                    : '• Pastikan data identitas siswa (Nama Lengkap, Kelas / Jurusan) sesuai dengan data administrasi sekolah.\n'
                                      '• Pilih posisi spesialisasi yang sesuai dengan keahlian dan kompetensi portofolio siswa.\n'
                                      '• Pengajuan yang dikirim akan otomatis tercatat di database dan diverifikasi oleh tim Corporate.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? Colors.white70 : const Color(0xFF1E293B).withValues(alpha: 0.85),
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. GROUP 1: INFORMASI POKOK SISWA / KANDIDAT
              buildSectionCard(
                isDark: isDark,
                accentColor: accentColor,
                title: 'Informasi Pokok Kandidat / Siswa',
                icon: Icons.badge_outlined,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: isMagang ? 'Nama Lengkap Siswa *' : 'Nama Lengkap Kandidat *',
                      hintText: 'Contoh: Ahmad Fauzan',
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 20, color: accentColor),
                      filled: true,
                      fillColor: isDark ? AppTheme.cardBg : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Nama siswa wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: majorCtrl,
                    decoration: InputDecoration(
                      labelText: isMagang ? 'Kelas & Jurusan Siswa *' : 'Jurusan / Pendidikan Terakhir *',
                      hintText: isMagang ? 'Contoh: XII Rekayasa Perangkat Lunak 1' : 'Contoh: D4 Teknik Elektro',
                      prefixIcon: const Icon(Icons.school_outlined, size: 20, color: accentColor),
                      filled: true,
                      fillColor: isDark ? AppTheme.cardBg : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Kelas/jurusan wajib diisi' : null,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 4. GROUP 2: POSISI & SPESIALISASI
              buildSectionCard(
                isDark: isDark,
                accentColor: accentColor,
                title: 'Pilihan Posisi & Spesialisasi',
                icon: Icons.work_outline_rounded,
                children: [
                  if (availableRoles.isNotEmpty) ...[
                    Text(
                      'Pilih Posisi / Sub-Role Terbuka:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableRoles.map((roleOpt) {
                        final isSelected =
                            roleCtrl.text.trim().toLowerCase() == roleOpt.trim().toLowerCase();
                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              roleCtrl.text = roleOpt;
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accentColor.withValues(alpha: 0.15)
                                  : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? accentColor
                                    : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 14,
                                  color: isSelected ? accentColor : Colors.grey.shade400,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  roleOpt,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected
                                        ? accentColor
                                        : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: roleCtrl,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Posisi / Spesialisasi yang Dilamar *',
                      hintText: 'Contoh: Electrician / Videographer / UI UX Intern',
                      prefixIcon: const Icon(Icons.workspace_premium_outlined, size: 20, color: accentColor),
                      filled: true,
                      fillColor: isDark ? AppTheme.cardBg : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Posisi spesialisasi wajib diisi' : null,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 5. GROUP 3: PORTOFOLIO & CATATAN INSTITUSI
              buildSectionCard(
                isDark: isDark,
                accentColor: accentColor,
                title: 'Portofolio & Rekomendasi Institusi',
                icon: Icons.folder_shared_outlined,
                children: [
                  TextFormField(
                    controller: portfolioCtrl,
                    decoration: InputDecoration(
                      labelText: 'Tautan Portofolio / CV / LinkedIn (Opsional)',
                      hintText: 'https://behance.net/... atau link Google Drive',
                      prefixIcon: const Icon(Icons.link_rounded, size: 20, color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: isDark ? AppTheme.cardBg : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: noteCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Catatan Rekomendasi untuk Corporate (Opsional)',
                      hintText: 'Tuliskan kompetensi unggulan, karakter kerja, atau rekomendasi khusus guru pembimbing...',
                      prefixIcon: const Icon(Icons.rate_review_outlined, size: 20, color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: isDark ? AppTheme.cardBg : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 6. FOOTER ACTIONS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        'Tersimpan Langsung ke Database',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(
                          isSubmitting ? 'Mengirim...' : 'Kirim Pengajuan',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
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
                                final additionalFlag = isAdditionalStudent;

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
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width > 700;
    if (isDesktop) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 850),
            child: StatefulBuilder(
              builder: (ctx, setDialogState) {
                final isDark = Theme.of(ctx).brightness == Brightness.dark;
                return Container(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
                  child: buildFormContent(setDialogState, ctx),
                );
              },
            ),
          ),
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final isDark = Theme.of(ctx).brightness == Brightness.dark;
              return Container(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                child: buildFormContent(setDialogState, ctx),
              );
            },
          );
        },
      );
    }
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
                      color: opp.isClosed ? const Color(0xFFF1F5F9) : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: opp.isClosed ? const Color(0xFFCBD5E1) : const Color(0xFFA7F3D0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: opp.isClosed ? const Color(0xFF64748B) : const Color(0xFF16A34A),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          opp.isClosed ? 'Pendaftaran Ditutup' : 'Pendaftaran Dibuka',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: opp.isClosed ? const Color(0xFF64748B) : const Color(0xFF16A34A),
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

    final acceptedCount = _students.where((s) => s.status == 'Diterima' || s.status.toLowerCase().contains('diterima')).length;
    final reviewCount = _students.where((s) => s.status == 'Review' || s.status == 'Pending' || s.status.toLowerCase().contains('menunggu')).length;

    final String subText = isApproved
        ? 'Institusi Anda telah disetujui pada ${widget.opportunity.isMagang ? 'program magang ini' : 'lowongan pekerjaan ini'}${acceptedCount > 0 ? ' ($acceptedCount ${widget.opportunity.isMagang ? 'siswa' : 'kandidat'} diterima' : ''}${reviewCount > 0 ? (acceptedCount > 0 ? ', $reviewCount dalam review' : ' ($reviewCount ${widget.opportunity.isMagang ? 'siswa' : 'kandidat'} dalam review') : ''}${acceptedCount > 0 || reviewCount > 0 ? ')' : ''}. Penambahan kandidat baru tidak mengubah status persetujuan sekolah Anda.'
        : (isPending
            ? 'Pengajuan kemitraan ${widget.opportunity.isMagang ? 'magang' : 'rekrutmen'} sekolah Anda sedang ditinjau oleh pihak Corporate.'
            : 'Sekolah Anda belum mendaftarkan ${widget.opportunity.isMagang ? 'siswa pada program magang ini' : 'kandidat pada lowongan pekerjaan ini'}. Buka tab "Daftar Siswa" lalu klik "+ Ajukan Siswa" untuk mendaftarkan kandidat.');

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

    final totalQuota = opp.totalQuota;
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
    final accepted = _students.where((s) => s.status == 'Diterima' || s.status.toLowerCase().contains('diterima')).length;
    final reviewOrPending = _students.where((s) => s.status == 'Review' || s.status == 'Pending' || s.status.toLowerCase().contains('menunggu')).length;
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
              _buildStudentStatBadge(_schoolPartnershipStatus == 'approved' ? 'Dalam Review' : 'Pending', reviewOrPending, const Color(0xFFD97706)),
              _buildStudentStatBadge('Interview', interview, const Color(0xFF2563EB)),
              _buildStudentStatBadge('Ditolak', rejected, const Color(0xFFDC2626)),
            ],
          ),
          const SizedBox(height: 16),

          // Closed info banner
          if (widget.opportunity.isClosed) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF64748B)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pendaftaran program ini telah ditutup karena kuota posisi telah terpenuhi atau periode pendaftaran telah berakhir. Penambahan siswa baru dinonaktifkan.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],

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
              final canAddStudent = !widget.opportunity.isClosed;
              final addButton = canAddStudent
                  ? ElevatedButton.icon(
                      onPressed: () => _openSubmitStudentDialog(
                        isAdditionalStudent: false,
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
                    )
                  : null;

              if (constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    if (addButton != null) ...[
                      const SizedBox(height: 10),
                      addButton,
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: searchField),
                  if (addButton != null) ...[
                    const SizedBox(width: 12),
                    addButton,
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 12),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                'Semua',
                'Diterima',
                _schoolPartnershipStatus == 'approved' ? 'Review' : 'Pending',
                'Interview',
                'Ditolak',
              ].map((f) {
                final sel = _selectedStudentFilter == f ||
                    (f == 'Review' && _selectedStudentFilter == 'Pending') ||
                    (f == 'Pending' && _selectedStudentFilter == 'Review');
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
    IconData statusIcon = Icons.hourglass_top_rounded;

    if (s.status == 'Diterima' || s.status.toLowerCase().contains('diterima')) {
      statusColor = const Color(0xFF16A34A);
      statusBg = const Color(0xFFDCFCE7);
      statusIcon = Icons.check_circle_rounded;
    } else if (s.status == 'Interview') {
      statusColor = const Color(0xFF2563EB);
      statusBg = const Color(0xFFDBEAFE);
      statusIcon = Icons.event_available_rounded;
    } else if (s.status == 'Ditolak') {
      statusColor = const Color(0xFFDC2626);
      statusBg = const Color(0xFFFEE2E2);
      statusIcon = Icons.cancel_rounded;
    } else if (s.status == 'Review' || s.status.toLowerCase().contains('review')) {
      statusColor = const Color(0xFFD97706);
      statusBg = const Color(0xFFFEF3C7);
      statusIcon = Icons.rate_review_outlined;
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 12, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                s.status == 'Pending' && s.isAdditional
                                    ? 'Pending (Menunggu Corporate)'
                                    : (s.status == 'Diterima'
                                        ? (widget.opportunity.isMagang ? 'Diterima Magang' : 'Diterima Kerja')
                                        : s.status),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ],
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
          if (s.status == 'Diterima' || s.status.toLowerCase().contains('diterima')) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF16A34A)),
                  const SizedBox(width: 6),
                  Text(
                    widget.opportunity.isMagang
                        ? 'Siswa resmi diterima mengikuti program magang industri ini'
                        : 'Kandidat resmi diterima pada lowongan pekerjaan ini',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
