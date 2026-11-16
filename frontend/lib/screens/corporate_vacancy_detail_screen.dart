import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../models/user_model.dart';
import '../models/opportunity_model.dart';
import '../models/opportunity_application_model.dart';
import '../services/api_service.dart';
import '../services/app_router.dart';
import '../services/opportunity_service.dart';
import '../widgets/desktop_sidebar_layout.dart';
import '../widgets/app_breadcrumbs.dart';
import '../widgets/app_sweet_alert.dart';
import '../widgets/program_magang_card.dart';
import 'corporate_lowongan_screen.dart';

class CorporateVacancyDetailScreen extends StatefulWidget {
  final CorporateVacancyItem? item;
  final String? vacancyId;
  final UserModel? user;
  final ValueChanged<UserModel>? onUserUpdated;

  const CorporateVacancyDetailScreen({
    super.key,
    this.item,
    this.vacancyId,
    this.user,
    this.onUserUpdated,
  });

  @override
  State<CorporateVacancyDetailScreen> createState() => _CorporateVacancyDetailScreenState();
}

class _CorporateVacancyDetailScreenState extends State<CorporateVacancyDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late CorporateVacancyItem _currentVacancy;
  String _selectedApplicantFilter = 'Semua';
  final TextEditingController _applicantSearchController = TextEditingController();
  late List<CorporateApplicant> _applicants;
  final Map<String, String> _institutionStatuses = {}; // 'approved', 'rejected', 'pending'
  final Set<String> _collapsedInstitutions = {};
  bool _isUploadingOfficialLetter = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initVacancy();
    _fetchRealApplications();
  }

  @override
  void didUpdateWidget(CorporateVacancyDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item != oldWidget.item || widget.vacancyId != oldWidget.vacancyId) {
      _initVacancy();
      _fetchRealApplications();
    }
  }

  Future<void> _fetchRealApplications() async {
    final oppId = _currentVacancy.opportunity?.id ?? _currentVacancy.id;
    if (oppId.isEmpty ||
        oppId.startsWith('corp_magang_') ||
        oppId.startsWith('corp_vac_detail') ||
        oppId.startsWith('test_')) {
      return;
    }

    try {
      final results = await Future.wait([
        OpportunityService.getOpportunityApplications(oppId).catchError((_) => <OpportunityApplicationModel>[]),
        OpportunityService.getDetail(oppId).catchError((_) => null),
      ]);
      final apps = results[0] as List<OpportunityApplicationModel>;
      final freshOpp = results[1] as OpportunityModel?;

      // Fetch showcases from institution resources to cross-reference student portfolios
      List<Map<String, dynamic>> showcases = [];
      try {
        final res = await ApiService.get('institution/resources', queryParams: {'type': 'showcases'});
        if (res['status'] == true && res['data'] is List) {
          showcases = List<Map<String, dynamic>>.from(res['data']);
        }
      } catch (_) {}

      if (mounted) {
        if (freshOpp != null) {
          _currentVacancy = CorporateVacancyItem.fromOpportunity(freshOpp);
        }
        if (apps.isNotEmpty) {
          final mapped = apps.map((a) {
            final statusLower = a.status.toLowerCase();
            String statusLabel = 'Menunggu Review';
            if (statusLower == 'approved') statusLabel = 'Diterima';
            if (statusLower == 'rejected') statusLabel = 'Ditolak';
            if (statusLower == 'interview') statusLabel = 'Interview';

            String studentName = '';
            String studentMajor = '';
            String portfolioUrl = '';
            String noteText = a.pitchMessage;
            bool isReplacement = false;
            String? replacedApplicantName;

            // 1. Check submittedDocuments
            if (a.submittedDocuments.isNotEmpty) {
              final doc = a.submittedDocuments.first;
              studentName = doc['student_name']?.toString().trim() ?? '';
              studentMajor = doc['major_class']?.toString().trim() ?? doc['major']?.toString().trim() ?? '';
              portfolioUrl = doc['portfolio_url']?.toString().trim() ?? doc['portfolio']?.toString().trim() ?? '';
              if (doc['note'] != null && doc['note'].toString().trim().isNotEmpty) {
                noteText = doc['note'].toString().trim();
              }
              isReplacement = doc['is_replacement'] == true;
              replacedApplicantName = doc['replaced_student_name']?.toString().trim();
            }

            // 2. Fallback: Parse pitchMessage if submittedDocuments didn't have student_name
            if (studentName.isEmpty && a.pitchMessage.isNotEmpty) {
              final match = RegExp(r'(?:Siswa|Peserta):\s*([^(|]+)(?:\(([^)]+)\))?', caseSensitive: false).firstMatch(a.pitchMessage);
              if (match != null) {
                studentName = match.group(1)?.trim() ?? '';
                if (studentMajor.isEmpty) {
                  studentMajor = match.group(2)?.trim() ?? '';
                }
              }

              if (portfolioUrl.isEmpty) {
                final portMatch = RegExp(r'Portofolio:\s*([^|]+)', caseSensitive: false).firstMatch(a.pitchMessage);
                if (portMatch != null) {
                  portfolioUrl = portMatch.group(1)?.trim() ?? '';
                }
              }
            }

            final isInstitutionSubmission = studentName.isNotEmpty;
            final resolvedName = isInstitutionSubmission ? studentName : (a.creator?.name ?? 'Pelamar');
            final resolvedInstitution = isInstitutionSubmission
                ? (a.creator?.name.isNotEmpty == true ? a.creator!.name : 'Institusi Mitra')
                : (a.creator?.subRole ?? (_currentVacancy.category == 'magang' ? 'Institusi Vokasi' : 'Umum'));
            final resolvedStudentDesc = isInstitutionSubmission
                ? (studentMajor.isNotEmpty ? studentMajor : (a.creator?.name ?? ''))
                : (a.creator?.subRole ?? 'Pelamar Mandiri');

            // 3. Match with showcases in database
            Map<String, dynamic>? matchingShowcase;
            if (resolvedName.isNotEmpty && showcases.isNotEmpty) {
              final sNameLower = resolvedName.toLowerCase();
              for (final sc in showcases) {
                final meta = sc['metadata'] ?? sc['meta'];
                final metaMap = (meta is Map) ? meta : <String, dynamic>{};
                final creatorName = (metaMap['creator_name'] ?? metaMap['creator'] ?? '').toString().toLowerCase();
                final scTitle = (sc['title'] ?? '').toString().toLowerCase();
                final scDesc = (sc['description'] ?? '').toString().toLowerCase();

                if (creatorName.contains(sNameLower) ||
                    sNameLower.contains(creatorName) ||
                    scTitle.contains(sNameLower) ||
                    scDesc.contains(sNameLower)) {
                  matchingShowcase = sc;
                  if (portfolioUrl.isEmpty) {
                    final scUrl = metaMap['portfolio_url']?.toString() ?? metaMap['url']?.toString() ?? '';
                    if (scUrl.isNotEmpty) {
                      portfolioUrl = scUrl;
                    }
                  }
                  break;
                }
              }
            }

            // Clean up note text so serialized tags aren't redundantly displayed
            var displayNote = noteText;
            final hasPrefix = displayNote.toLowerCase().contains('siswa:') || displayNote.toLowerCase().contains('peserta:');
            if (hasPrefix) {
              final segments = displayNote.split('|').map((s) => s.trim()).toList();
              final cleanSegments = segments.where((s) =>
                !s.toLowerCase().startsWith('siswa:') &&
                !s.toLowerCase().startsWith('peserta:') &&
                !s.toLowerCase().startsWith('portofolio:')
              ).toList();
              displayNote = cleanSegments.join(' • ');
            }

            return CorporateApplicant(
              id: a.id,
              name: resolvedName,
              institution: resolvedInstitution,
              studentDescription: resolvedStudentDesc,
              institutionId: a.creator?.id,
              role: a.subRoleSlug.replaceAll('_', ' ').toUpperCase(),
              appliedDate: a.createdAt != null
                  ? ProgramMagangCard.formatDateDisplay(a.createdAt)
                  : 'Hari ini',
              status: statusLabel,
              portfolioUrl: portfolioUrl,
              note: displayNote,
              isReplacement: isReplacement,
              replacedApplicantName: replacedApplicantName,
              showcaseItem: matchingShowcase,
            );
          }).toList();

          for (final item in mapped) {
            final instBase = _getInstitutionBaseName(item.institution);
            if (item.status == 'Diterima' && !_institutionStatuses.containsKey(instBase)) {
              _institutionStatuses[instBase] = 'approved';
            }
          }

          setState(() {
            _applicants = mapped;
          });
        } else {
          setState(() {
            _applicants = [];
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _pickAndUploadOfficialLetter() async {
    final oppId = _currentVacancy.opportunity?.id ?? _currentVacancy.id;
    if (oppId.isEmpty) return;

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;

      setState(() => _isUploadingOfficialLetter = true);

      final fileBytes = await file.readAsBytes();
      if (fileBytes.isEmpty) {
        if (!mounted) return;
        setState(() => _isUploadingOfficialLetter = false);
        AppSweetAlert.error(context, 'Berkas kosong atau tidak dapat dibaca.');
        return;
      }

      final formData = FormData();
      formData.files.add(
        MapEntry(
          'file',
          MultipartFile.fromBytes(fileBytes, filename: file.name),
        ),
      );

      final res = await ApiService.postFormData(
        'opportunities/$oppId/official-acceptance-letter',
        formData,
      );

      if (!mounted) return;
      setState(() => _isUploadingOfficialLetter = false);

      if (res['status'] == true && res['data'] != null) {
        final data = res['data'];
        final updatedOpp = _currentVacancy.opportunity?.copyWith(
          status: 'closed',
          officialAcceptanceLetterUrl: data['official_acceptance_letter_url']?.toString(),
          officialAcceptanceLetterName: data['official_acceptance_letter_name']?.toString() ?? file.name,
          officialAcceptanceLetterUploadedAt: data['official_acceptance_letter_uploaded_at']?.toString(),
        );

        setState(() {
          if (updatedOpp != null) {
            _currentVacancy = CorporateVacancyItem.fromOpportunity(updatedOpp);
          } else {
            _currentVacancy = CorporateVacancyItem(
              id: _currentVacancy.id,
              title: _currentVacancy.title,
              description: _currentVacancy.description,
              category: _currentVacancy.category,
              categoryLabel: _currentVacancy.categoryLabel,
              status: 'closed',
              statusLabel: 'Pendaftaran Ditutup',
              statusBadgeColor: const Color(0xFF64748B),
              statusBadgeBg: const Color(0xFFF1F5F9),
              registrationPeriod: _currentVacancy.registrationPeriod,
              quotaText: _currentVacancy.quotaText,
              allowance: _currentVacancy.allowance,
              requirements: _currentVacancy.requirements,
              applicantsCount: _currentVacancy.applicantsCount,
              applicants: _currentVacancy.applicants,
              opportunity: _currentVacancy.opportunity,
            );
          }
        });

        AppSweetAlert.success(
          context,
          'Surat resmi penerimaan "${file.name}" berhasil diunggah. Dokumen ini kini dapat diunduh oleh institusi mitra yang telah diapprove.',
          title: 'Surat Resmi Diunggah',
        );
      } else {
        AppSweetAlert.error(
          context,
          res['message']?.toString() ?? 'Gagal mengunggah surat resmi penerimaan.',
          title: 'Gagal Unggah',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingOfficialLetter = false);
      AppSweetAlert.error(context, 'Terjadi kesalahan saat mengunggah surat: $e', title: 'Gagal');
    }
  }

  void _initVacancy() {
    if (widget.item != null) {
      _currentVacancy = widget.item!;
    } else {
      // Fallback default vacancy if opened directly by route
      _currentVacancy = CorporateVacancyItem(
        id: widget.vacancyId ?? 'corp_vac_detail',
        title: 'Program Magang MBKM 3D Modeler Batch I 2026',
        description:
            'Kerja sama penempatan talenta vokasi dan mahasiswa magang pada lini produksi serial animasi nusantara berstandar industri internasional.',
        category: 'magang',
        categoryLabel: 'Magang',
        status: 'open',
        statusLabel: 'Pendaftaran Dibuka',
        statusBadgeColor: const Color(0xFF16A34A),
        statusBadgeBg: const Color(0xFFDCFCE7),
        registrationPeriod: '21 Sep 2026',
        quotaText: '4 dari 10 posisi',
        allowance: 'Rp 2.500.000 - Rp 3.500.000 / bulan',
        requirements: const [
          'Siswa SMK vokasi atau Mahasiswa jurusan Animasi / DKV',
          'Menguasai dasar 3D Modeling (Blender / Maya)',
          'Memiliki portofolio karya modeling atau tekstur aset 3D',
          'Disiplin waktu dan komunikatif dalam koordinasi tim',
        ],
        applicantsCount: 6,
        applicants: const [
          CorporateApplicant(
            name: 'Dimas Aditya',
            institution: 'SMKN 4 Bandung - Animasi',
            role: 'Junior 3D Modeler',
            appliedDate: '10 Feb 2026',
            status: 'Interview',
            note: 'Showreel modeling hard-surface sangat rapi dan proporsional.',
          ),
          CorporateApplicant(
            name: 'Bagas Kurniawan',
            institution: 'SMKN 4 Bandung - Animasi',
            role: '3D Texture Artist',
            appliedDate: '11 Feb 2026',
            status: 'Menunggu Review',
            note: 'Paham UV unwrapping dan texturing di Substance Painter.',
          ),
          CorporateApplicant(
            name: 'Siti Nurhaliza',
            institution: 'Politeknik Negeri Media Kreatif',
            role: '3D Texture & Lookdev',
            appliedDate: '11 Feb 2026',
            status: 'Menunggu Review',
            note: 'Mahir Substance Painter dan render engine Blender Cycles.',
          ),
          CorporateApplicant(
            name: 'Nadya Putri',
            institution: 'Politeknik Negeri Media Kreatif',
            role: 'Concept Artist',
            appliedDate: '13 Feb 2026',
            status: 'Menunggu Review',
            note: 'Portofolio visual development environment nusantara.',
          ),
          CorporateApplicant(
            name: 'Reza Pratama',
            institution: 'SMKN 1 Surabaya - Multimedia',
            role: '3D Environment Artist',
            appliedDate: '12 Feb 2026',
            status: 'Diterima',
            note: 'Telah menandatangani MoU penempatan magang resmi institusi.',
          ),
          CorporateApplicant(
            name: 'Fauzan Hakim',
            institution: 'Institut Teknologi Bandung - DKV',
            role: 'Junior 3D Modeler',
            appliedDate: '14 Feb 2026',
            status: 'Menunggu Review',
            note: 'Fokus pada modeling karakter kartun nusantara.',
          ),
        ],
      );
    }
    _applicants = List<CorporateApplicant>.from(_currentVacancy.applicants);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _applicantSearchController.dispose();
    super.dispose();
  }

  String _getInstitutionBaseName(String fullInstitution) {
    if (fullInstitution.contains(' - ')) {
      return fullInstitution.split(' - ').first.trim();
    }
    return fullInstitution.trim();
  }

  String _getInstitutionStatus(String instName) {
    if (_institutionStatuses.containsKey(instName)) {
      return _institutionStatuses[instName]!;
    }
    final instApps = _applicants
        .where((a) => _getInstitutionBaseName(a.institution) == instName)
        .toList();
    if (instApps.isNotEmpty && instApps.any((a) => a.status == 'Diterima')) {
      return 'approved';
    }
    return 'pending';
  }

  Future<void> _confirmApproveInstitution(String instName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Setujui Kemitraan Institusi?',
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Text(
            'Anda yakin ingin menyetujui kemitraan dengan institusi "$instName"?\n\n'
            'Setelah disetujui, status siswa yang diajukan akan berpindah ke tahap review dan Anda dapat menerima berkas siswa.',
            style: const TextStyle(fontSize: 13.5, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Ya, Setujui Kemitraan'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _approveInstitution(instName);
    }
  }

  Future<void> _approveInstitution(String instName) async {
    setState(() {
      _institutionStatuses[instName] = 'approved';
      for (int i = 0; i < _applicants.length; i++) {
        if (_getInstitutionBaseName(_applicants[i].institution) == instName) {
          if (_applicants[i].status != 'Diterima' && _applicants[i].status != 'Ditolak') {
            _applicants[i] = _applicants[i].copyWith(status: 'Menunggu Review');
          }
        }
      }
    });

    final instApps = _applicants
        .where((a) => _getInstitutionBaseName(a.institution) == instName)
        .toList();
    for (final app in instApps) {
      if (app.id != null &&
          app.id!.isNotEmpty &&
          !app.id!.startsWith('corp_app_') &&
          !app.id!.startsWith('test_')) {
        try {
          await OpportunityService.reviewApplication(
            applicationId: app.id!,
            decision: 'consider',
          );
        } catch (_) {}
      }
    }

    if (!mounted) return;
    AppSweetAlert.success(
      context,
      'Kemitraan institusi $instName berhasil disetujui. Anda dapat meninjau dan menerima berkas peserta dari institusi ini.',
      title: 'Institusi Disetujui',
    );
  }

  void _confirmRejectInstitution(String instName, int count) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Tolak Kemitraan Institusi?',
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Text(
            'Anda yakin ingin menolak institusi "$instName"?\n\n'
            'Perhatian: Menolak institusi akan secara otomatis membatalkan kemitraan, sehingga seluruh ($count) peserta dari institusi ini tidak dapat disetujui dan langsung dihapus dari daftar pelamar program magang.',
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155), height: 1.45),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final instApps = _applicants
                    .where((a) => _getInstitutionBaseName(a.institution) == instName)
                    .toList();
                setState(() {
                  _institutionStatuses[instName] = 'rejected';
                  _applicants.removeWhere((app) => _getInstitutionBaseName(app.institution) == instName);
                  _collapsedInstitutions.remove(instName);
                });
                for (final app in instApps) {
                  if (app.id != null &&
                      app.id!.isNotEmpty &&
                      !app.id!.startsWith('corp_app_') &&
                      !app.id!.startsWith('test_')) {
                    try {
                      await OpportunityService.reviewApplication(
                        applicationId: app.id!,
                        decision: 'reject',
                        reason: 'Institusi ditolak oleh corporate',
                      );
                    } catch (_) {}
                  }
                }
                if (!mounted) return;
                AppSweetAlert.error(
                  context,
                  'Institusi $instName telah ditolak. Seluruh ($count) peserta dari institusi ini otomatis tidak dapat disetujui dan telah dihapus dari daftar.',
                  title: 'Institusi Ditolak & Peserta Dihapus',
                );
              },
              icon: const Icon(Icons.cancel_rounded, size: 16),
              label: const Text('Ya, Tolak Institusi'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  void _toggleInstitutionCollapse(String instName) {
    setState(() {
      if (_collapsedInstitutions.contains(instName)) {
        _collapsedInstitutions.remove(instName);
      } else {
        _collapsedInstitutions.add(instName);
      }
    });
  }



  Future<void> _updateApplicantStatus(int index, String newStatus) async {
    if (index < 0 || index >= _applicants.length) return;
    final app = _applicants[index];
    final inst = _getInstitutionBaseName(app.institution);
    if (_getInstitutionStatus(inst) == 'rejected') {
      AppSweetAlert.error(
        context,
        'Institusi $inst telah ditolak. Peserta dari institusi ini otomatis tidak bisa disetujui untuk masuk program magang.',
        title: 'Institusi Ditolak',
      );
      return;
    }

    if (newStatus == 'Diterima') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Terima Peserta Magang / Kerja?',
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Text(
            'Anda yakin ingin menerima berkas ${app.name} (${app.role}) untuk program magang ini?',
            style: const TextStyle(fontSize: 13.5, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Ya, Terima'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    } else if (newStatus == 'Ditolak') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Tolak Berkas Peserta?',
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Text(
            'Anda yakin ingin menolak berkas pendaftaran ${app.name} (${app.role})?',
            style: const TextStyle(fontSize: 13.5, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Ya, Tolak'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() {
      _applicants[index] = _applicants[index].copyWith(status: newStatus);
      if (newStatus == 'Diterima') {
        _institutionStatuses[inst] = 'approved';
      }
    });

    if (app.id != null &&
        app.id!.isNotEmpty &&
        !app.id!.startsWith('corp_app_') &&
        !app.id!.startsWith('test_')) {
      try {
        if (newStatus == 'Diterima') {
          await OpportunityService.reviewApplication(
            applicationId: app.id!,
            decision: 'approve',
          );
        } else if (newStatus == 'Ditolak') {
          await OpportunityService.reviewApplication(
            applicationId: app.id!,
            decision: 'reject',
          );
        }
      } catch (_) {}
    }

    if (!mounted) return;
    AppSweetAlert.success(
      context,
      'Status pelamar ${_applicants[index].name} diperbarui menjadi "$newStatus".',
      title: 'Status Pelamar Diperbarui',
    );
  }

  Future<void> _toggleVacancyStatus() async {
    final isCurrentlyOpen = _currentVacancy.status.toLowerCase() == 'open';
    final targetStatus = isCurrentlyOpen ? 'closed' : 'open';

    if (isCurrentlyOpen) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.pause_circle_outline_rounded, color: Color(0xFFDC2626), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Tutup Pendaftaran Program?',
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: const Text(
            'Anda yakin ingin menutup pendaftaran untuk program ini?\n\n'
            'Setelah pendaftaran ditutup, institusi dan pelamar tidak dapat lagi mengajukan pendaftaran baru.',
            style: TextStyle(fontSize: 13.5, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.lock_outline_rounded, size: 16),
              label: const Text('Ya, Tutup Pendaftaran'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final oppId = _currentVacancy.opportunity?.id ?? _currentVacancy.id;
    if (oppId.isNotEmpty &&
        !oppId.startsWith('corp_magang_') &&
        !oppId.startsWith('corp_vac_') &&
        !oppId.startsWith('test_vac_')) {
      final res = await OpportunityService.updateStatus(oppId, targetStatus);
      if (res['status'] != true) {
        if (!mounted) return;
        AppSweetAlert.error(
          context,
          res['message']?.toString() ?? 'Gagal memperbarui status lowongan di database server.',
          title: 'Gagal Memperbarui Status',
        );
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _currentVacancy = CorporateVacancyItem(
        id: _currentVacancy.id,
        title: _currentVacancy.title,
        description: _currentVacancy.description,
        category: _currentVacancy.category,
        categoryLabel: _currentVacancy.categoryLabel,
        status: targetStatus,
        statusLabel: isCurrentlyOpen ? 'Pendaftaran Ditutup' : 'Pendaftaran Dibuka',
        statusBadgeColor: isCurrentlyOpen ? const Color(0xFF64748B) : const Color(0xFF16A34A),
        statusBadgeBg: isCurrentlyOpen ? const Color(0xFFF1F5F9) : const Color(0xFFDCFCE7),
        registrationPeriod: _currentVacancy.registrationPeriod,
        quotaText: _currentVacancy.quotaText,
        allowance: _currentVacancy.allowance,
        requirements: _currentVacancy.requirements,
        applicantsCount: _currentVacancy.applicantsCount,
        applicants: _applicants,
        opportunity: _currentVacancy.opportunity?.copyWith(status: targetStatus),
      );
    });
    AppSweetAlert.success(
      context,
      'Status lowongan berhasil diperbarui di database menjadi "${_currentVacancy.statusLabel}".',
      title: 'Status Lowongan Diperbarui',
    );
  }

  List<CorporateApplicant> get _filteredApplicants {
    final query = _applicantSearchController.text.trim().toLowerCase();
    return _applicants.where((app) {
      final inst = _getInstitutionBaseName(app.institution);
      if (_getInstitutionStatus(inst) == 'rejected') {
        return false;
      }
      if (_selectedApplicantFilter != 'Semua' && app.status != _selectedApplicantFilter) {
        return false;
      }
      if (query.isNotEmpty) {
        final matchName = app.name.toLowerCase().contains(query);
        final matchInst = app.institution.toLowerCase().contains(query);
        final matchRole = app.role.toLowerCase().contains(query);
        return matchName || matchInst || matchRole;
      }
      return true;
    }).toList();
  }

  void _navigateBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go(AppRoutes.lowonganCorporate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 960;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: !isDesktop
          ? AppBar(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              elevation: 0,
              title: Text(
                _currentVacancy.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => _navigateBack(context),
              ),
            )
          : null,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 32 : 16,
          vertical: isDesktop ? 24 : 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Breadcrumbs
            AppBreadcrumbs(
              items: [
                BreadcrumbItem(
                  label: 'Beranda',
                  onTap: () => context.go(AppRoutes.beranda),
                ),
                BreadcrumbItem(
                  label: 'Program & Magang Corporate',
                  onTap: () => _navigateBack(context),
                ),
                BreadcrumbItem(
                  label: _currentVacancy.title,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Back button & Actions Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _navigateBack(context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Kembali ke Daftar Lowongan'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                Wrap(
                  spacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        AppSweetAlert.info(
                          context,
                          'Tautan lowongan telah disalin ke papan klip.',
                          title: 'Bagikan Lowongan',
                        );
                      },
                      icon: const Icon(Icons.share_outlined, size: 16),
                      label: const Text('Bagikan'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    if (_currentVacancy.status.toLowerCase() == 'open')
                      FilledButton.icon(
                        onPressed: _toggleVacancyStatus,
                        icon: const Icon(
                          Icons.pause_circle_outline_rounded,
                          size: 16,
                        ),
                        label: const Text('Tutup Pendaftaran'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Hero Detail Card
            _buildHeroDetailCard(isDark),
            const SizedBox(height: 20),

            // 4 Key Stats Cards
            _buildKeyStatsGrid(isDesktop, isDark),
            const SizedBox(height: 24),

            // Tab Bar Navigation
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF2563EB),
                indicatorWeight: 3,
                labelColor: const Color(0xFF2563EB),
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                tabs: [
                  const Tab(
                    icon: Icon(Icons.description_outlined, size: 18),
                    text: 'Rincian & Kualifikasi Program',
                  ),
                  Tab(
                    icon: const Icon(Icons.people_alt_outlined, size: 18),
                    text: 'Daftar Pelamar (${_applicants.length})',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Tab View Body (Fixed height container for tabs)
            AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                return _tabController.index == 0
                    ? _buildProgramDetailsTab(isDesktop, isDark)
                    : _buildApplicantsManagementTab(isDesktop, isDark);
              },
            ),
          ],
        ),
      ),
    );

    if (isDesktop) {
      return DesktopSidebarLayout(
        user: widget.user ?? UserModel.guest(),
        activeRoute: 'lowongan_magang',
        onUserUpdated: widget.onUserUpdated,
        child: content,
      );
    }

    return content;
  }

  // ── Hero Detail Card ────────────────────────────────────────────────────────
  Widget _buildHeroDetailCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badges Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _currentVacancy.category == 'magang'
                      ? const Color(0xFFEFF6FF)
                      : const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _currentVacancy.category == 'magang'
                        ? const Color(0xFFBFDBFE)
                        : const Color(0xFFDDD6FE),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _currentVacancy.category == 'magang'
                          ? Icons.school_rounded
                          : Icons.work_rounded,
                      size: 14,
                      color: _currentVacancy.category == 'magang'
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF7C3AED),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _currentVacancy.categoryLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _currentVacancy.category == 'magang'
                            ? const Color(0xFF1E40AF)
                            : const Color(0xFF5B21B6),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _currentVacancy.statusBadgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentVacancy.statusBadgeColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _currentVacancy.statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _currentVacancy.statusBadgeColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, size: 14, color: Color(0xFF64748B)),
                    SizedBox(width: 5),
                    Text(
                      'Tervalidasi Corporate B2B',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Title
          Text(
            _currentVacancy.title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),

          // Corporate Entity info
          Builder(builder: (context) {
            final posterName = _currentVacancy.opportunity?.poster?.name.trim();
            final companyName = (posterName != null && posterName.isNotEmpty) ? posterName : 'Transforma Alam';
            return Row(
              children: [
                const Icon(Icons.business_rounded, size: 16, color: Color(0xFF2563EB)),
                const SizedBox(width: 6),
                Text(
                  companyName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Text(
                  '• Terverifikasi Resmi',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            );
          }),
          const SizedBox(height: 14),

          // Description
          Text(
            _currentVacancy.description,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  // ── Key Stats Grid ──────────────────────────────────────────────────────────
  Widget _buildKeyStatsGrid(bool isDesktop, bool isDark) {
    final stats = [
      _StatItem(
        icon: Icons.calendar_today_rounded,
        iconColor: const Color(0xFF2563EB),
        bgColor: const Color(0xFFEFF6FF),
        label: 'Periode Pendaftaran',
        value: _currentVacancy.registrationPeriod,
        subtitle: 'Batas akhir penerimaan',
      ),
      _StatItem(
        icon: Icons.groups_rounded,
        iconColor: const Color(0xFF7C3AED),
        bgColor: const Color(0xFFF5F3FF),
        label: 'Alokasi / Sisa Kuota',
        value: _currentVacancy.quotaText,
        subtitle: 'Kapasitas talenta dibuka',
      ),
      _StatItem(
        icon: Icons.payments_rounded,
        iconColor: const Color(0xFF16A34A),
        bgColor: const Color(0xFFDCFCE7),
        label: 'Estimasi Gaji / Uang Saku',
        value: _currentVacancy.allowance.trim().isNotEmpty
            ? _currentVacancy.allowance
            : 'Kompetitif / Sesuai Kesepakatan',
        subtitle: _currentVacancy.allowance.trim().isNotEmpty &&
                !_currentVacancy.allowance.toLowerCase().contains('kompetitif')
            ? 'Standar kompetitif'
            : 'Dapat dinegosiasikan',
      ),
      _StatItem(
        icon: Icons.assignment_ind_rounded,
        iconColor: const Color(0xFFD97706),
        bgColor: const Color(0xFFFEF3C7),
        label: 'Pelamar Terdaftar',
        value: '${_applicants.length} Orang',
        subtitle: 'Berkas masuk sistem',
      ),
    ];

    if (isDesktop) {
      return Row(
        children: stats.map((stat) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: stat.bgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(stat.icon, size: 20, color: stat.iconColor),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    stat.label,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stat.value,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stat.subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    }

    return Column(
      children: stats.map((stat) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: stat.bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(stat.icon, size: 20, color: stat.iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stat.label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    Text(
                      stat.value,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Tab 1: Program Details Tab ──────────────────────────────────────────────
  Widget _buildProgramDetailsTab(bool isDesktop, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section: Syarat & Kualifikasi
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.assignment_turned_in_rounded, size: 20, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Syarat & Kualifikasi Pelamar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16),
              ..._currentVacancy.requirements.map((req) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF16A34A)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          req,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Section: Tata Kelola Kemitraan & B2B Governance
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.handshake_rounded, size: 20, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Tata Kelola & Kemitraan Industri Resmi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 680;
                  final mouItem = _buildGovernanceItem(
                    icon: Icons.description_outlined,
                    title: 'MoU & Perjanjian Penempatan',
                    desc: 'Terintegrasi otomatis dengan pangkalan data institusi mitra Kreavana.',
                  );
                  final letterTile = _buildOfficialAcceptanceLetterTile();

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        mouItem,
                        const SizedBox(height: 14),
                        letterTile,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: mouItem),
                      const SizedBox(width: 16),
                      Expanded(child: letterTile),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOfficialAcceptanceLetterTile() {
    final opp = _currentVacancy.opportunity;
    final bool isClosed = (opp?.isClosed ?? false) ||
        _currentVacancy.status == 'closed' ||
        _currentVacancy.statusLabel.toLowerCase().contains('ditutup');

    final bool hasLetter = opp?.hasOfficialAcceptanceLetter ?? false;
    final String letterName = opp?.officialAcceptanceLetterName?.isNotEmpty == true
        ? opp!.officialAcceptanceLetterName!
        : 'Surat_Resmi_Penerimaan.pdf';

    Color cardBorder;
    Color cardBg;
    Color iconColor;
    Color iconBg;
    IconData icon;
    String badgeText;
    Color badgeColor;
    Color badgeBg;
    String description;

    if (isClosed) {
      if (hasLetter) {
        cardBorder = const Color(0xFFA7F3D0);
        cardBg = const Color(0xFFF0FDF4);
        iconColor = const Color(0xFF059669);
        iconBg = const Color(0xFFDCFCE7);
        icon = Icons.verified_user_rounded;
        badgeText = 'Surat Resmi Diunggah';
        badgeColor = const Color(0xFF15803D);
        badgeBg = const Color(0xFFDCFCE7);
        description = 'Surat resmi pernyataan penerimaan seluruh peserta magang/kerja telah diunggah dan dapat diunduh oleh institusi mitra.';
      } else {
        cardBorder = const Color(0xFFFDE68A);
        cardBg = const Color(0xFFFFFBEB);
        iconColor = const Color(0xFFD97706);
        iconBg = const Color(0xFFFEF3C7);
        icon = Icons.upload_file_rounded;
        badgeText = 'Belum Diunggah';
        badgeColor = const Color(0xFFB45309);
        badgeBg = const Color(0xFFFEF3C7);
        description = 'Pendaftaran ditutup. Silakan unggah surat resmi penerimaan yang mencakup semua data peserta yang diterima sebagai pernyataan resmi.';
      }
    } else {
      cardBorder = const Color(0xFFE2E8F0);
      cardBg = const Color(0xFFF8FAFC);
      iconColor = const Color(0xFF64748B);
      iconBg = const Color(0xFFF1F5F9);
      icon = Icons.description_outlined;
      badgeText = 'Menunggu Pendaftaran Ditutup';
      badgeColor = const Color(0xFF475569);
      badgeBg = const Color(0xFFE2E8F0);
      description = 'Input upload surat resmi penerimaan peserta akan aktif setelah pendaftaran ditutup atau kuota posisi terpenuhi.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Surat Resmi Penerimaan',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isClosed) ...[
            const SizedBox(height: 12),
            if (hasLetter) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Color(0xFFEF4444)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        letterName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final url = opp?.officialAcceptanceLetterUrl;
                        if (url != null && url.isNotEmpty) {
                          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.visibility_outlined, size: 14),
                      label: const Text('Lihat / Unduh', style: TextStyle(fontSize: 11.5)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF059669),
                        side: const BorderSide(color: Color(0xFF10B981)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isUploadingOfficialLetter ? null : _pickAndUploadOfficialLetter,
                      icon: _isUploadingOfficialLetter
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.file_upload_outlined, size: 14),
                      label: Text(
                        _isUploadingOfficialLetter ? 'Mengunggah...' : 'Ganti Surat',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUploadingOfficialLetter ? null : _pickAndUploadOfficialLetter,
                  icon: _isUploadingOfficialLetter
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.upload_file_rounded, size: 16),
                  label: Text(
                    _isUploadingOfficialLetter ? 'Mengunggah...' : 'Unggah Surat Resmi Penerimaan',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildGovernanceItem({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF2563EB)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                const SizedBox(height: 3),
                Text(desc, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Applicants Management Tab ─────────────────────────────────────────
  Widget _buildApplicantsManagementTab(bool isDesktop, bool isDark) {
    final filtered = _filteredApplicants;

    // Group filtered applicants by institution base name (excluding rejected institutions)
    final Map<String, List<CorporateApplicant>> grouped = {};
    for (final app in filtered) {
      final inst = _getInstitutionBaseName(app.institution);
      if (_getInstitutionStatus(inst) == 'rejected') {
        continue;
      }
      grouped.putIfAbsent(inst, () => []).add(app);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter and Search Header Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Field
              TextFormField(
                controller: _applicantSearchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Cari nama pelamar, asal institusi/kampus, atau posisi...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF2563EB)),
                  suffixIcon: _applicantSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _applicantSearchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Filter Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['Semua', 'Menunggu Review', 'Interview', 'Diterima', 'Ditolak'].map((status) {
                  final isSelected = _selectedApplicantFilter == status;
                  return ChoiceChip(
                    label: Text(status),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        _selectedApplicantFilter = status;
                      });
                    },
                    selectedColor: const Color(0xFF2563EB),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                    ),
                    backgroundColor: const Color(0xFFF1F5F9),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // List of applicants grouped by institution
        if (grouped.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Icon(Icons.people_outline_rounded, size: 48, color: Color(0xFF94A3B8)),
                const SizedBox(height: 12),
                const Text(
                  'Tidak ada pelamar ditemukan',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Coba ubah kata kunci pencarian atau filter status pelamar.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: grouped.keys.length,
            itemBuilder: (context, index) {
              final instName = grouped.keys.elementAt(index);
              final instApplicants = grouped[instName]!;
              return _buildInstitutionGroupCard(instName, instApplicants, isDesktop, isDark);
            },
          ),
      ],
    );
  }

  // ── Institution Group Card ──────────────────────────────────────────────────
  Widget _buildInstitutionGroupCard(
    String instName,
    List<CorporateApplicant> instApplicants,
    bool isDesktop,
    bool isDark,
  ) {
    final instStatus = _getInstitutionStatus(instName);
    if (instStatus == 'rejected') {
      return const SizedBox.shrink();
    }
    // If search or filter is active, force expand so matching items are visible
    final hasSearchOrFilter = _applicantSearchController.text.isNotEmpty || _selectedApplicantFilter != 'Semua';
    final isExpanded = hasSearchOrFilter || !_collapsedInstitutions.contains(instName);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: instStatus == 'rejected'
              ? const Color(0xFFFECACA)
              : instStatus == 'approved'
                  ? const Color(0xFFBBF7D0)
                  : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Institution Header Card (Clickable to expand/collapse)
          InkWell(
            onTap: () => _toggleInstitutionCollapse(instName),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  // Institution Icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: instStatus == 'rejected'
                          ? const Color(0xFFFEE2E2)
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.account_balance_rounded,
                      color: instStatus == 'rejected'
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF2563EB),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Institution Name & Badges
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                instName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildInstitutionStatusBadge(instStatus),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${instApplicants.length} Peserta Diajukan',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                            Text(
                              isExpanded ? 'Klik untuk menutup daftar' : 'Klik untuk melihat daftar peserta',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Actions on right: Setujui and Tolak buttons & Chevron
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Tombol Setujui dan Tolak HANYA ditampilkan jika status institusi masih 'pending'
                      if (instStatus == 'pending') ...[
                        OutlinedButton.icon(
                          key: ValueKey('btn_approve_inst_$instName'),
                          onPressed: () => _confirmApproveInstitution(instName),
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                          label: const Text('Setujui'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF16A34A),
                            side: const BorderSide(color: Color(0xFF86EFAC)),
                            backgroundColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        OutlinedButton.icon(
                          key: ValueKey('btn_reject_inst_$instName'),
                          onPressed: () => _confirmRejectInstitution(instName, instApplicants.length),
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          label: const Text('Tolak'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            backgroundColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],

                      // Chevron indicator
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFF64748B),
                        size: 24,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Accordion Body: List of Students
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (instStatus == 'rejected')
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Institusi ini telah ditolak. Seluruh anak magang dari institusi ini otomatis ditolak.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFB91C1C),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Student cards
                  ...instApplicants.map((app) {
                    return _buildApplicantCard(app, isDark);
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Individual Applicant Card ───────────────────────────────────────────────
  Widget _buildApplicantCard(CorporateApplicant app, bool isDark) {
    final inst = _getInstitutionBaseName(app.institution);
    if (_getInstitutionStatus(inst) == 'rejected') {
      return const SizedBox.shrink();
    }
    final rawIdx = _applicants.indexOf(app);
    final isAccepted = app.status == 'Diterima' || app.status.toLowerCase().contains('diterima');
    final isRejected = app.status == 'Ditolak';
    final isReplacement = app.isReplacement;
    final isPendingCorporate = app.status == 'Menunggu Persetujuan Corporate' ||
        (isReplacement && app.status == 'Menunggu Review');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isReplacement
              ? const Color(0xFFDDD6FE)
              : isRejected
                  ? const Color(0xFFFECACA)
                  : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner for Replacement Candidate
          if (isReplacement) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDDD6FE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Peserta Pengganti • Menggantikan ${app.replacedApplicantName ?? "kandidat sebelumnya"} (Wajib Disetujui Corporate)',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6D28D9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isReplacement
                    ? const Color(0xFF7C3AED).withValues(alpha: 0.12)
                    : const Color(0xFF2563EB).withValues(alpha: 0.12),
                child: Text(
                  app.name.isNotEmpty ? app.name[0].toUpperCase() : 'S',
                  style: TextStyle(
                    fontSize: 15,
                    color: isReplacement ? const Color(0xFF7C3AED) : const Color(0xFF2563EB),
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
                      app.name,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      app.studentDescription.isNotEmpty
                          ? app.studentDescription
                          : app.institution,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Text(
                            app.role,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                        Text(
                          'Melamar: ${app.appliedDate}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildApplicantStatusBadge(app.status),
            ],
          ),
          if (app.note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notes_rounded, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      app.note,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 10),

          // Actions Bar for Applicant
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (app.hasPortfolio) ...[
                OutlinedButton.icon(
                  key: ValueKey('btn_portfolio_${app.name}'),
                  onPressed: () => _handleOpenPortfolio(app),
                  icon: const Icon(Icons.launch_rounded, size: 13),
                  label: const Text('Portofolio'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF93C5FD)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],

              // Quick approval buttons for replacement student
              if (isPendingCorporate && rawIdx != -1) ...[
                FilledButton.icon(
                  onPressed: () => _updateApplicantStatus(rawIdx, 'Diterima'),
                  icon: const Icon(Icons.check_rounded, size: 14),
                  label: const Text('Setujui Pengganti'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _updateApplicantStatus(rawIdx, 'Ditolak'),
                  icon: const Icon(Icons.close_rounded, size: 14),
                  label: const Text('Tolak'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],

              // Ubah Status dropdown HANYA muncul jika siswa belum berstatus Diterima dan belum Ditolak
              if (!isAccepted && !isRejected) ...[
                PopupMenuButton<String>(
                  key: ValueKey('popup_status_${app.name}'),
                  onSelected: (val) {
                    if (rawIdx != -1) {
                      _updateApplicantStatus(rawIdx, val);
                    }
                  },
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'Interview', child: Text('Jadwalkan Interview')),
                    PopupMenuItem(
                      value: 'Diterima',
                      child: Text(_currentVacancy.category == 'magang'
                          ? 'Terima Magang'
                          : 'Terima Kerja'),
                    ),
                    const PopupMenuItem(value: 'Ditolak', child: Text('Tolak Berkas')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_note_rounded, size: 14, color: Color(0xFF475569)),
                        SizedBox(width: 4),
                        Text(
                          'Ubah Status',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Color(0xFF475569)),
                      ],
                    ),
                  ),
                ),
              ] else if (isAccepted) ...[
                // Bila siswa sudah diterima, dropdown dihilangkan dan digantikan konfirmasi status resmi
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
                      const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                      const SizedBox(width: 5),
                      Text(
                        _currentVacancy.category == 'magang'
                            ? 'Resmi Diterima Magang'
                            : 'Resmi Diterima Kerja',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstitutionStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status) {
      case 'approved':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        label = 'Disetujui';
        icon = Icons.check_circle_rounded;
        break;
      case 'rejected':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        label = 'Ditolak';
        icon = Icons.cancel_rounded;
        break;
      case 'pending':
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        label = 'Menunggu Keputusan';
        icon = Icons.pending_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicantStatusBadge(String status) {
    Color bg;
    Color fg;
    String displayLabel = status;
    IconData icon;

    switch (status) {
      case 'Diterima':
      case 'Diterima Magang':
      case 'Diterima Kerja':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        displayLabel = _currentVacancy.category == 'magang'
            ? 'Diterima Magang'
            : 'Diterima Kerja';
        icon = Icons.check_circle_rounded;
        break;
      case 'Interview':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF2563EB);
        icon = Icons.event_available_rounded;
        break;
      case 'Ditolak':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        icon = Icons.cancel_rounded;
        break;
      case 'Menunggu Persetujuan Corporate':
        bg = const Color(0xFFEDE9FE);
        fg = const Color(0xFF7C3AED);
        icon = Icons.hourglass_top_rounded;
        break;
      case 'Menunggu Review':
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        icon = Icons.pending_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            displayLabel,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  void _handleOpenPortfolio(CorporateApplicant app) {
    if (app.hasShowcase) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      _showStudentShowcaseDialog(context, app, isDark);
    } else if (app.hasExternalLink) {
      _launchExternalUrl(app.portfolioUrl);
    }
  }

  Future<void> _launchExternalUrl(String rawUrl) async {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return;

    var urlToOpen = trimmed;
    if (!urlToOpen.startsWith('http://') && !urlToOpen.startsWith('https://')) {
      urlToOpen = 'https://$urlToOpen';
    }

    try {
      final uri = Uri.parse(urlToOpen);
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } catch (e) {
      if (mounted) {
        AppSweetAlert.error(
          context,
          'Gagal membuka tautan portofolio: $e',
          title: 'Error Membuka Tautan',
        );
      }
    }
  }

  void _showStudentShowcaseDialog(BuildContext context, CorporateApplicant app, bool isDark) {
    final showcase = app.showcaseItem ?? {};
    final meta = showcase['metadata'] ?? showcase['meta'];
    final metaMap = (meta is Map) ? meta : <String, dynamic>{};

    final title = showcase['title']?.toString() ?? 'Portofolio Peserta';
    final description = showcase['description']?.toString() ?? '';
    final category = metaMap['category']?.toString() ?? 'Karya & Portofolio Peserta';
    final year = metaMap['year']?.toString() ?? '';
    final imageUrl = metaMap['image_url']?.toString() ?? '';
    final portfolioUrl = (app.portfolioUrl.isNotEmpty)
        ? app.portfolioUrl
        : (metaMap['portfolio_url']?.toString() ?? metaMap['url']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final dialogWidth = MediaQuery.of(dialogCtx).size.width;
        final isSmall = dialogWidth < 600;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isSmall ? 16 : 32,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Dialog Header ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.collections_bookmark_rounded,
                            size: 20,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Karya & Portofolio Peserta',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Terdaftar di database karya institusi',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.of(dialogCtx).pop(),
                          tooltip: 'Tutup',
                        ),
                      ],
                    ),
                  ),

                  // ── Dialog Body ──
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Student Identification Row
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                  child: Text(
                                    app.name.isNotEmpty ? app.name[0].toUpperCase() : 'S',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        app.name,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        app.studentDescription.isNotEmpty
                                            ? '${app.studentDescription} • ${app.institution}'
                                            : app.institution,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF86EFAC)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified_rounded, size: 14, color: Color(0xFF16A34A)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Terverifikasi',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF16A34A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Showcase Thumbnail / Image if available
                          if (imageUrl.isNotEmpty) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 200,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                ),
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) {
                                    return Center(
                                      child: Icon(
                                        Icons.image_outlined,
                                        size: 40,
                                        color: isDark ? Colors.white38 : Colors.grey.shade400,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Showcase Title & Tags
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: Text(
                                  category,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                              if (year.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Angkatan / Tahun $year',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.55,
                                color: isDark ? Colors.white70 : const Color(0xFF334155),
                              ),
                            ),
                          ],

                          // External Link / GitHub Box
                          if (portfolioUrl.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        portfolioUrl.contains('github.com')
                                            ? Icons.code_rounded
                                            : Icons.link_rounded,
                                        size: 18,
                                        color: const Color(0xFF2563EB),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        portfolioUrl.contains('github.com')
                                            ? 'Repositori / Portofolio GitHub'
                                            : 'Tautan Portofolio Eksternal',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1E3A8A),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: () => _launchExternalUrl(portfolioUrl),
                                    child: Text(
                                      portfolioUrl,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF2563EB),
                                        decoration: TextDecoration.underline,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: () => _launchExternalUrl(portfolioUrl),
                                      icon: const Icon(Icons.open_in_new_rounded, size: 15),
                                      label: Text(
                                        portfolioUrl.contains('github.com')
                                            ? 'Buka Repositori GitHub (Tab Baru)'
                                            : 'Buka Tautan Portofolio (Tab Baru)',
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                      ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFF2563EB),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
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
                    ),
                  ),

                  // ── Dialog Footer ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      border: Border(
                        top: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogCtx).pop(),
                          child: const Text('Tutup'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatItem {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String label;
  final String value;
  final String subtitle;

  _StatItem({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.label,
    required this.value,
    required this.subtitle,
  });
}
