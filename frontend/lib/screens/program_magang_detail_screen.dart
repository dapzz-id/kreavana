import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
        (doc['participant_name'] ?? doc['student_name'] ?? doc['name'] ?? '').toString().trim();
    String majorClass = (doc['major_class'] ?? doc['student_class'] ?? doc['major'] ?? '').toString().trim();
    String role = (doc['role'] ?? '').toString().trim();
    String portfolioUrl = (doc['portfolio_url'] ?? doc['student_portfolio'] ?? '').toString().trim();
    String note = (doc['note'] ?? '').toString().trim();
    bool isAdditional = doc['is_additional'] == true || doc['submission_type'] == 'additional';
    bool isReplacement = doc['is_replacement'] == true;
    String? replacedName = doc['replaced_student_name']?.toString();

    // Parse fallback from legacy pitch_message format when submitted_documents is absent
    if (studentName.isEmpty &&
        (app.pitchMessage.startsWith('Peserta:') || app.pitchMessage.startsWith('Siswa:'))) {
      final parts = app.pitchMessage.split('|').map((p) => p.trim()).toList();
      final rawPrefix = parts.first.startsWith('Peserta:') ? 'Peserta:' : 'Siswa:';
      final head = parts.first.replaceFirst(rawPrefix, '').trim();
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
      studentName = app.creator?.name ?? 'Peserta Magang';
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

class _ParticipantDraftForm {
  final TextEditingController nameCtrl;
  final TextEditingController majorCtrl;
  final TextEditingController roleCtrl;
  final TextEditingController portfolioCtrl;
  final TextEditingController noteCtrl;
  bool isExpanded;

  _ParticipantDraftForm({String initialRole = 'Peserta Magang'})
      : nameCtrl = TextEditingController(),
        majorCtrl = TextEditingController(),
        roleCtrl = TextEditingController(text: initialRole),
        portfolioCtrl = TextEditingController(),
        noteCtrl = TextEditingController(),
        isExpanded = true;

  void dispose() {
    nameCtrl.dispose();
    majorCtrl.dispose();
    roleCtrl.dispose();
    portfolioCtrl.dispose();
    noteCtrl.dispose();
  }
}

class ProgramMagangDetailScreen extends StatefulWidget {
  final OpportunityModel opportunity;
  final UserModel? user;
  final ValueChanged<UserModel>? onUserUpdated;
  final bool isAppliedPartnership;
  final String? initialPartnershipStatus;

  const ProgramMagangDetailScreen({
    super.key,
    required this.opportunity,
    this.user,
    this.onUserUpdated,
    this.isAppliedPartnership = false,
    this.initialPartnershipStatus,
  });

  @override
  State<ProgramMagangDetailScreen> createState() => _ProgramMagangDetailScreenState();
}

class _ProgramMagangDetailScreenState extends State<ProgramMagangDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late OpportunityModel _opportunity;
  OpportunityModel get effectiveOpportunity => _opportunity;
  bool _isLoading = false;
  String _selectedStudentFilter = 'Semua';
  final TextEditingController _searchController = TextEditingController();
  int _studentPage = 1;
  static const int _studentPageSize = 6;

  // Status institusi pada program ini: 'approved', 'rejected', 'pending', 'not_applied'
  late String _schoolPartnershipStatus;
  // Apakah corporate meminta tambahan peserta
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
  void didUpdateWidget(ProgramMagangDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.opportunity != oldWidget.opportunity ||
        widget.initialPartnershipStatus != oldWidget.initialPartnershipStatus) {
      _initDefaultState();
      _loadServerData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _initDefaultState() {
    _opportunity = widget.opportunity;
    final myId = _currentUser?.id ?? '';
    final myName = (_currentUser?.name ?? '').toLowerCase();
    final isThisSchoolInApproved = widget.opportunity.approvedCreators.any(
      (c) =>
          (myId.isNotEmpty && c.id == myId) ||
          (myName.isNotEmpty && c.name.toLowerCase() == myName),
    );
    final isApplied = widget.isAppliedPartnership ||
        widget.opportunity.hasApplied ||
        isThisSchoolInApproved;

    if (widget.initialPartnershipStatus != null) {
      _schoolPartnershipStatus = widget.initialPartnershipStatus!;
    } else if (isThisSchoolInApproved) {
      _schoolPartnershipStatus = 'approved';
    } else if (isApplied) {
      _schoolPartnershipStatus = 'pending';
    } else {
      _schoolPartnershipStatus = 'not_applied';
    }
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
        (c) =>
            (currentSchoolId != null &&
                currentSchoolId.isNotEmpty &&
                c.id == currentSchoolId) ||
            (_currentUser?.name.isNotEmpty == true &&
                c.name.toLowerCase() == _currentUser!.name.toLowerCase()),
      );

      final hasUnderReview = schoolApps.any((a) {
        final st = a.status.toLowerCase();
        return st == 'under_consideration' ||
            st == 'review' ||
            st == 'in_review' ||
            st == 'interview';
      });

      final hasActivePending = schoolApps.any((a) {
        final st = a.status.toLowerCase();
        return st == 'pending' || st == 'submitted';
      });

      final allAppsRejected = schoolApps.isNotEmpty &&
          schoolApps.every((a) => a.status.toLowerCase() == 'rejected');

      final isSchoolApproved =
          hasApprovedStudent || isSchoolApprovedByOpp || hasUnderReview;
      final isSchoolRejected =
          !isSchoolApproved && !hasActivePending && allAppsRejected;

      // Check real DB terms or notes for explicit corporate additional participant request
      bool corporateRequestsAdditional = false;
      String corporateNote = '';
      for (final term in effectiveOpp.dynamicTerms) {
        final low = term.toLowerCase();
        if (low.contains('tambahan siswa') ||
            low.contains('tambahan peserta') ||
            low.contains('request_additional')) {
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
        if (freshOpp != null) {
          _opportunity = freshOpp;
        }
        if (isSchoolApproved) {
          _schoolPartnershipStatus = 'approved';
        } else if (isSchoolRejected) {
          _schoolPartnershipStatus = 'rejected';
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
            : (widget.opportunity.isMagang ? 'Peserta Magang' : 'Kandidat Program'));

    final List<_ParticipantDraftForm> drafts = [
      _ParticipantDraftForm(initialRole: initialRole),
    ];
    bool isGeneralInfoExpanded = false;
    bool isSubmitting = false;
    int submittedCount = 0;

    Widget buildParticipantCard({
      required int index,
      required _ParticipantDraftForm draft,
      required bool isDark,
      required Color accentColor,
      required StateSetter setDialogState,
    }) {
      final summaryName = draft.nameCtrl.text.trim();
      final summaryRole = draft.roleCtrl.text.trim();
      final headerSummary = summaryName.isNotEmpty
          ? '$summaryName${summaryRole.isNotEmpty ? ' • $summaryRole' : ''}'
          : 'Lengkapi data peserta #${index + 1}';

      return Container(
        key: ValueKey('participant_draft_card_$index'),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: draft.isExpanded
                ? accentColor.withValues(alpha: 0.45)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                setDialogState(() {
                  draft.isExpanded = !draft.isExpanded;
                });
              },
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#${index + 1}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Peserta #${index + 1}',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            headerSummary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (drafts.length > 1)
                      IconButton(
                        tooltip: 'Hapus baris peserta #${index + 1}',
                        visualDensity: VisualDensity.compact,
                        onPressed: isSubmitting
                            ? null
                            : () {
                                setDialogState(() {
                                  final removed = drafts.removeAt(index);
                                  removed.dispose();
                                });
                              },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    Icon(
                      draft.isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ],
                ),
              ),
            ),
            if (draft.isExpanded) ...[
              Divider(
                height: 1,
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      key: ValueKey('participant_name_field_$index'),
                      controller: draft.nameCtrl,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Nama Lengkap Peserta *',
                        hintText: 'Contoh: Ahmad Fauzan',
                        prefixIcon: Icon(Icons.person_outline_rounded, size: 20, color: accentColor),
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
                          (v == null || v.trim().isEmpty) ? 'Nama peserta wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: ValueKey('participant_major_field_$index'),
                      controller: draft.majorCtrl,
                      decoration: InputDecoration(
                        labelText: 'Program Studi / Kelas / Jurusan *',
                        hintText: 'Contoh: XII RPL 1 / S1 Desain Komunikasi Visual',
                        prefixIcon: Icon(Icons.school_outlined, size: 20, color: accentColor),
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
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Program studi / kelas / jurusan wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    if (availableRoles.isNotEmpty) ...[
                      Text(
                        'Pilih Posisi / Bidang Terbuka:',
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
                          final isSelected = draft.roleCtrl.text.trim().toLowerCase() ==
                              roleOpt.trim().toLowerCase();
                          return InkWell(
                            onTap: () {
                              setDialogState(() {
                                draft.roleCtrl.text = roleOpt;
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
                      const SizedBox(height: 10),
                    ],
                    TextFormField(
                      key: ValueKey('participant_role_field_$index'),
                      controller: draft.roleCtrl,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Posisi / Spesialisasi yang Dilamar *',
                        hintText: 'Contoh: Videographer / UI UX Intern / Electrician',
                        prefixIcon: Icon(Icons.workspace_premium_outlined, size: 20, color: accentColor),
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
                    const SizedBox(height: 12),
                    TextFormField(
                      key: ValueKey('participant_portfolio_field_$index'),
                      controller: draft.portfolioCtrl,
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
                      key: ValueKey('participant_note_field_$index'),
                      controller: draft.noteCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Catatan Rekomendasi untuk Corporate (Opsional)',
                        hintText: 'Tuliskan kompetensi unggulan, karakter kerja, atau rekomendasi pembimbing / koordinator institusi...',
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
              ),
            ],
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
        title = 'Ajukan Peserta Pengganti';
        badgeText = 'Penggantian Peserta';
        subtitle = 'Gantikan peserta yang ditolak dengan kandidat lain yang memenuhi kualifikasi.';
      } else if (isAdditionalStudent) {
        title = 'Tambah Peserta Tambahan';
        badgeText = 'Kemitraan Resmi';
        subtitle = 'Daftarkan satu atau beberapa peserta tambahan dari institusi Anda.';
      } else {
        title = isMagang ? 'Tambah Peserta Program Magang' : 'Tambah Peserta Lowongan';
        badgeText = 'Pendaftaran Resmi';
        subtitle = 'Daftarkan satu atau beberapa peserta institusi untuk seleksi program ini.';
      }

      final corpName = widget.opportunity.poster?.name.isNotEmpty == true
          ? widget.opportunity.poster!.name
          : 'Mitra Corporate';

      return Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP HEADER
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
                    child: const Icon(Icons.groups_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
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
              const SizedBox(height: 14),

              // 2. COLLAPSIBLE DROPDOWN: INFORMASI UMUM & PANDUAN PENGAJUAN
              Container(
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
                    color: isDark
                        ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
                        : const Color(0xFFBFDBFE),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      key: const Key('general_info_dropdown_toggle'),
                      onTap: () {
                        setDialogState(() {
                          isGeneralInfoExpanded = !isGeneralInfoExpanded;
                        });
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.info_outline_rounded,
                                size: 17,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Informasi Umum & Panduan Pengajuan',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? const Color(0xFF93C5FD)
                                          : const Color(0xFF1E3A8A),
                                    ),
                                  ),
                                  Text(
                                    isGeneralInfoExpanded
                                        ? 'Ketuk untuk menyembunyikan informasi umum'
                                        : 'Ketuk untuk melihat ringkasan program & panduan pengajuan',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white60 : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isGeneralInfoExpanded ? 'Tutup' : 'Buka',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    isGeneralInfoExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    size: 16,
                                    color: const Color(0xFF2563EB),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isGeneralInfoExpanded) ...[
                      Divider(
                        height: 1,
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFBFDBFE).withValues(alpha: 0.7),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Program: ${widget.opportunity.title} ($corpName)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            if (widget.opportunity.totalQuota > 0) ...[
                              const SizedBox(height: 3),
                              Text(
                                'Sisa Kuota Tersedia: ${widget.opportunity.remainingQuota} dari ${widget.opportunity.totalQuota} posisi',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              'Panduan Pengajuan Peserta & Seleksi Kemitraan:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? const Color(0xFF93C5FD)
                                    : const Color(0xFF1E3A8A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              replacedStudent != null
                                  ? '• Pengajuan ini menggantikan berkas peserta ${replacedStudent.name} (${replacedStudent.role}) yang sebelumnya ditolak.\n'
                                    '• Pastikan data identitas peserta lengkap dan relevan dengan kriteria mitra.\n'
                                    '• Pengajuan pengganti langsung tersimpan ke database untuk ditinjau Corporate.'
                                  : '• Pastikan data identitas peserta (Nama Lengkap, Program Studi / Kelas / Jurusan) sesuai data administrasi institusi.\n'
                                    '• Anda dapat menambahkan beberapa peserta sekaligus dalam satu pengajuan melalui tombol "+ Tambah Peserta Lain".\n'
                                    '• Seluruh peserta yang diajukan otomatis tercatat di database dan diverifikasi oleh tim Corporate.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF1E293B).withValues(alpha: 0.85),
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. HEADER BAR MULTI-PESERTA + TOMBOL TAMBAH BARIS
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Daftar Peserta yang Diajukan (${drafts.length} Peserta)',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  if (replacedStudent == null)
                    OutlinedButton.icon(
                      key: const Key('btn_add_another_participant'),
                      onPressed: isSubmitting
                          ? null
                          : () {
                              setDialogState(() {
                                for (final d in drafts) {
                                  if (d.nameCtrl.text.trim().isNotEmpty &&
                                      d.majorCtrl.text.trim().isNotEmpty) {
                                    d.isExpanded = false;
                                  }
                                }
                                drafts.add(_ParticipantDraftForm(initialRole: initialRole));
                              });
                            },
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                      label: const Text(
                        '+ Tambah Peserta Lain',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accentColor,
                        side: BorderSide(color: accentColor.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // 4. LIST KARTU FORM PESERTA (MULTIPLE PESERTA)
              ...drafts.asMap().entries.map(
                (entry) => buildParticipantCard(
                  index: entry.key,
                  draft: entry.value,
                  isDark: isDark,
                  accentColor: accentColor,
                  setDialogState: setDialogState,
                ),
              ),
              const SizedBox(height: 16),

              // 5. FOOTER ACTIONS
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
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
                    mainAxisSize: MainAxisSize.min,
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
                          isSubmitting
                              ? 'Mengirim ($submittedCount/${drafts.length})...'
                              : (drafts.length > 1
                                  ? 'Kirim Pengajuan (${drafts.length} Peserta)'
                                  : 'Kirim Pengajuan'),
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
                                // Expand any draft with empty required fields so validators highlight visibly
                                bool expandedAny = false;
                                for (final d in drafts) {
                                  if (d.nameCtrl.text.trim().isEmpty ||
                                      d.majorCtrl.text.trim().isEmpty ||
                                      d.roleCtrl.text.trim().isEmpty) {
                                    if (!d.isExpanded) {
                                      d.isExpanded = true;
                                      expandedAny = true;
                                    }
                                  }
                                }
                                if (expandedAny) {
                                  setDialogState(() {});
                                  await Future<void>.delayed(const Duration(milliseconds: 50));
                                }

                                if (!(formKey.currentState?.validate() ?? false)) return;

                                // Check duplicate names inside the batch
                                final seenNames = <String>{};
                                for (final d in drafts) {
                                  final norm = d.nameCtrl.text.trim().toLowerCase();
                                  if (!seenNames.add(norm)) {
                                    if (mounted) {
                                      AppSweetAlert.error(
                                        context,
                                        'Terdapat nama peserta duplikat (${d.nameCtrl.text.trim()}) pada daftar pengajuan.',
                                      );
                                    }
                                    return;
                                  }
                                }

                                final oppId = widget.opportunity.id ?? '';
                                if (oppId.isEmpty) {
                                  if (mounted) {
                                    AppSweetAlert.error(
                                      context,
                                      'ID program tidak ditemukan di database.',
                                    );
                                  }
                                  return;
                                }

                                setDialogState(() {
                                  isSubmitting = true;
                                  submittedCount = 0;
                                });

                                final totalToSend = drafts.length;
                                final succeededNames = <String>[];
                                String? failedMessage;

                                // Submit sequentially so every draft saves cleanly to database
                                while (drafts.isNotEmpty) {
                                  final current = drafts.first;
                                  final participantName = current.nameCtrl.text.trim();
                                  final major = current.majorCtrl.text.trim();
                                  final role = current.roleCtrl.text.trim();
                                  final portfolio = current.portfolioCtrl.text.trim();
                                  final note = current.noteCtrl.text.trim().isNotEmpty
                                      ? current.noteCtrl.text.trim()
                                      : (replacedStudent != null
                                          ? 'Peserta pengganti menggantikan ${replacedStudent.name}.'
                                          : 'Peserta diajukan oleh institusi untuk program ini.');

                                  final res = await OpportunityService.applyInstitutionStudent(
                                    opportunityId: oppId,
                                    subRoleSlug: role.toLowerCase().replaceAll(' ', '_'),
                                    pitchMessage:
                                        'Peserta: $participantName ($major)${portfolio.isNotEmpty ? ' | Portofolio: $portfolio' : ''} | $note',
                                    studentDocument: {
                                      'participant_name': participantName,
                                      'student_name': participantName,
                                      'major_class': major,
                                      'role': role,
                                      'portfolio_url': portfolio,
                                      'note': note,
                                      'is_additional': isAdditionalStudent,
                                      'is_replacement': replacedStudent != null,
                                      if (replacedStudent != null)
                                        'replaced_student_name': replacedStudent.name,
                                    },
                                  );

                                  if (res['status'] != true) {
                                    failedMessage = res['message']?.toString() ??
                                        'Gagal menyimpan pengajuan peserta $participantName ke database.';
                                    break;
                                  }

                                  succeededNames.add(participantName);
                                  if (ctx.mounted) {
                                    setDialogState(() {
                                      submittedCount++;
                                      final done = drafts.removeAt(0);
                                      done.dispose();
                                    });
                                  } else {
                                    drafts.removeAt(0).dispose();
                                  }
                                }

                                if (ctx.mounted) {
                                  setDialogState(() => isSubmitting = false);
                                }

                                if (failedMessage != null) {
                                  if (succeededNames.isNotEmpty) {
                                    await _loadServerData();
                                  }
                                  if (mounted) {
                                    AppSweetAlert.error(
                                      context,
                                      succeededNames.isNotEmpty
                                          ? '${succeededNames.length} peserta berhasil diajukan, namun terhenti: $failedMessage'
                                          : failedMessage,
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
                                  final namesPreview = succeededNames.take(3).join(', ');
                                  final moreCount = succeededNames.length > 3
                                      ? ' dan ${succeededNames.length - 3} peserta lainnya'
                                      : '';
                                  AppSweetAlert.success(
                                    context,
                                    totalToSend > 1
                                        ? 'Sebanyak $totalToSend peserta ($namesPreview$moreCount) berhasil dikirim ke Corporate.'
                                        : 'Pengajuan peserta ${succeededNames.first} berhasil dikirim ke Corporate.',
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
    try {
      if (isDesktop) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700, maxHeight: 860),
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
    } finally {
      for (final d in drafts) {
        d.dispose();
      }
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

              // Official Acceptance Letter Banner (for approved institutions)
              _buildOfficialAcceptanceLetterBanner(isDark, isDesktop, accentColor),
              if (_schoolPartnershipStatus == 'approved') const SizedBox(height: 14),

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
                          text: 'Daftar Peserta (${_students.length})',
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
    final bool isRejected = _schoolPartnershipStatus == 'rejected';
    final bool isPending = _schoolPartnershipStatus == 'pending';

    final Color bg = isApproved
        ? const Color(0xFFECFDF5)
        : (isRejected
            ? const Color(0xFFFEF2F2)
            : (isPending ? const Color(0xFFFFFBEB) : const Color(0xFFF1F5F9)));
    final Color border = isApproved
        ? const Color(0xFFA7F3D0)
        : (isRejected
            ? const Color(0xFFFECACA)
            : (isPending ? const Color(0xFFFDE68A) : const Color(0xFFCBD5E1)));
    final Color iconColor = isApproved
        ? const Color(0xFF059669)
        : (isRejected
            ? const Color(0xFFDC2626)
            : (isPending ? const Color(0xFFD97706) : const Color(0xFF475569)));
    final IconData icon = isApproved
        ? Icons.verified_rounded
        : (isRejected
            ? Icons.cancel_rounded
            : (isPending ? Icons.hourglass_top_rounded : Icons.info_outline_rounded));

    final String titleText = isApproved
        ? 'Status Institusi: Disetujui / Bermitra (Approved)'
        : (isRejected
            ? 'Status Institusi: Ditolak oleh Corporate (Rejected)'
            : (isPending
                ? 'Status Institusi: Menunggu Persetujuan Corporate (Pending)'
                : 'Status Institusi: Belum Mengajukan Lamaran'));

    final acceptedCount = _students
        .where((s) => s.status == 'Diterima' || s.status.toLowerCase().contains('diterima'))
        .length;
    final reviewCount = _students
        .where((s) =>
            s.status == 'Review' ||
            s.status == 'Pending' ||
            s.status.toLowerCase().contains('menunggu'))
        .length;

    final String subText = isApproved
        ? 'Institusi Anda telah disetujui pada ${widget.opportunity.isMagang ? 'program magang ini' : 'lowongan ini'}${acceptedCount > 0 ? ' ($acceptedCount peserta diterima' : ''}${reviewCount > 0 ? (acceptedCount > 0 ? ', $reviewCount dalam review' : ' ($reviewCount peserta dalam review') : ''}${acceptedCount > 0 || reviewCount > 0 ? ')' : ''}. Penambahan peserta baru sudah ditutup.'
        : (isRejected
            ? 'Pengajuan kemitraan institusi Anda pada program ini telah ditolak oleh pihak Corporate. Penambahan peserta baru tidak lagi tersedia.'
            : (isPending
                ? 'Pengajuan kemitraan ${widget.opportunity.isMagang ? 'magang' : 'rekrutmen'} institusi Anda sedang ditinjau oleh pihak Corporate.'
                : 'Institusi Anda belum mendaftarkan peserta pada ${widget.opportunity.isMagang ? 'program magang ini' : 'lowongan ini'}. Buka tab "Daftar Peserta" lalu klik "+ Tambah Peserta" untuk mendaftarkan peserta.'));

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
    if (_schoolPartnershipStatus == 'not_applied' ||
        _schoolPartnershipStatus == 'rejected') {
      return const SizedBox.shrink();
    }

    final bool isPartnershipLocked = _schoolPartnershipStatus == 'approved' ||
        _schoolPartnershipStatus == 'rejected' ||
        widget.opportunity.isClosed;

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
                    ? 'Permintaan Tambahan Peserta dari Corporate ($_corporateRequestedCount Peserta)'
                    : 'Permintaan Tambahan Peserta: Tidak Ada Permintaan Khusus',
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
                    ? '$_corporateRequestNote Peserta baru yang diajukan akan masuk dalam status Pending.'
                    : (isPartnershipLocked
                        ? 'Status kemitraan institusi Anda telah Disetujui oleh Corporate. Pengajuan peserta baru sudah dikunci.'
                        : 'Saat ini Corporate belum meminta tambahan peserta baru. Anda masih dapat menambah peserta sebelum kemitraan diproses.'),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
            ],
          );
          final Widget? actionButton = (_corporateRequestsAdditional && !isPartnershipLocked)
              ? ElevatedButton(
                  onPressed: () =>
                      _openSubmitStudentDialog(isAdditionalStudent: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Tambah Peserta',
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
                'Kerja sama penempatan peserta magang pada industri kreatif mitra.',
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
          if (_schoolPartnershipStatus == 'approved') ...[
            const SizedBox(height: 24),
            _buildOfficialAcceptanceLetterBanner(isDark, isDesktop, accentColor),
          ],
        ],
      ),
    );
  }

  Widget _buildOfficialAcceptanceLetterBanner(bool isDark, bool isDesktop, Color accentColor) {
    if (_schoolPartnershipStatus != 'approved') {
      return const SizedBox.shrink();
    }

    final opp = effectiveOpportunity;
    final bool hasLetter = opp.hasOfficialAcceptanceLetter;
    final String letterName = opp.officialAcceptanceLetterName?.isNotEmpty == true
        ? opp.officialAcceptanceLetterName!
        : 'Surat_Resmi_Penerimaan.pdf';

    final Color bg = hasLetter
        ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4))
        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC));
    final Color border = hasLetter
        ? (isDark ? const Color(0xFF059669).withValues(alpha: 0.4) : const Color(0xFFA7F3D0))
        : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1));
    final Color iconColor = hasLetter ? const Color(0xFF059669) : const Color(0xFF94A3B8);

    return Container(
      key: const Key('official_acceptance_letter_banner'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 680;
          final iconBox = Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              hasLetter ? Icons.verified_user_rounded : Icons.pending_actions_rounded,
              color: iconColor,
              size: 22,
            ),
          );

          final textContent = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      opp.isMagang
                          ? 'Surat Resmi Penerimaan Peserta Magang'
                          : 'Surat Resmi Penerimaan Pelamar Kerja',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: hasLetter
                          ? const Color(0xFFDCFCE7)
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      hasLetter ? 'Surat Tersedia' : 'Belum Diunggah',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: hasLetter ? const Color(0xFF15803D) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                hasLetter
                    ? 'Pihak Corporate telah menerbitkan surat resmi penerimaan ($letterName). Anda dapat mengunduh berkas resmi ini sebagai bukti penerimaan magang/kerja siswa institusi Anda.'
                    : 'Pihak Corporate belum mengunggah Surat Resmi Penerimaan. Tombol unduh akan aktif secara otomatis setelah berkas pernyataan resmi diunggah oleh pihak Corporate.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                  height: 1.4,
                ),
              ),
            ],
          );

          final Widget downloadButton = ElevatedButton.icon(
            key: Key(hasLetter ? 'btn_download_official_letter' : 'btn_download_official_letter_disabled'),
            onPressed: hasLetter
                ? () {
                    final url = opp.officialAcceptanceLetterUrl;
                    if (url != null && url.isNotEmpty) {
                      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    }
                  }
                : null,
            icon: Icon(
              hasLetter ? Icons.download_rounded : Icons.file_download_off_rounded,
              size: 16,
              color: hasLetter ? Colors.white : const Color(0xFF94A3B8),
            ),
            label: Text(
              'Unduh Surat Resmi Penerimaan',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: hasLetter ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasLetter ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
              disabledBackgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              foregroundColor: Colors.white,
              disabledForegroundColor: const Color(0xFF94A3B8),
              elevation: hasLetter ? 1 : 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );

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
                 const SizedBox(height: 12),
                 SizedBox(width: double.infinity, child: downloadButton),
               ],
             );
           }

           return Row(
             children: [
               iconBox,
               const SizedBox(width: 14),
               Expanded(child: textContent),
               const SizedBox(width: 16),
               downloadButton,
             ],
           );
         },
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

          // Closed / Approved / Rejected info banner (disables adding more participants)
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
                      'Pendaftaran program ini telah ditutup karena kuota posisi telah terpenuhi atau periode pendaftaran telah berakhir. Penambahan peserta baru dinonaktifkan.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_schoolPartnershipStatus == 'approved') ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_outlined, size: 18, color: Color(0xFF059669)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Status kemitraan institusi pada program ini telah Disetujui oleh Corporate. Penambahan peserta baru sudah ditutup.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF065F46), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_schoolPartnershipStatus == 'rejected') ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.cancel_outlined, size: 18, color: Color(0xFFDC2626)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pengajuan institusi pada program ini telah Ditolak oleh Corporate. Penambahan peserta baru dinonaktifkan.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontWeight: FontWeight.w500),
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
                  hintText: 'Cari nama peserta, jurusan/kelas, atau posisi...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
              // Pastikan button Tambah Peserta tidak muncul saat program ditutup ATAU status institusi di-approve / di-reject oleh Corporate
              final bool canAddParticipant = !widget.opportunity.isClosed &&
                  _schoolPartnershipStatus != 'approved' &&
                  _schoolPartnershipStatus != 'rejected';
              final addButton = canAddParticipant
                  ? ElevatedButton.icon(
                      key: const Key('btn_tambah_peserta'),
                      onPressed: () => _openSubmitStudentDialog(
                        isAdditionalStudent: false,
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                      label: const Text(
                        'Tambah Peserta',
                        style: TextStyle(
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
                  const Text(
                    'Belum Ada Peserta yang Diajukan',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.opportunity.isMagang
                        ? 'Daftarkan peserta institusi Anda untuk mengikuti program magang industri ini.'
                        : 'Daftarkan peserta institusi Anda untuk melamar lowongan ini.',
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
              itemLabel: 'peserta',
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
                              s.isReplacement ? 'Peserta Pengganti' : 'Peserta Tambahan',
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
                        ? 'Peserta resmi diterima mengikuti program magang industri ini'
                        : 'Peserta resmi diterima pada lowongan ini',
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
