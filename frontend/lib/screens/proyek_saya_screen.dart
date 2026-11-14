import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/debouncer.dart';
import '../app/theme.dart';
import '../app/subrole_theme_engine.dart';
import '../models/user_model.dart';
import '../services/job_contract_service.dart';
import '../services/opportunity_service.dart';
import '../models/job_contract.dart';
import '../models/opportunity_model.dart';
import 'direct_message_screen.dart';
import '../services/chat_service.dart';
import '../services/user_store.dart';
import '../widgets/desktop_sidebar_layout.dart';
import 'buat_kebutuhan_screen.dart';
import 'detail_kebutuhan_screen.dart';
import '../widgets/app_breadcrumbs.dart';
import '../widgets/skeleton/skeleton_list.dart';
import 'main_navigation.dart';
import '../services/verification_service.dart';
import 'client_verification_page.dart';
import '../widgets/user_profile_modal.dart';
import '../widgets/opportunity_review_dialog.dart';
import '../widgets/repeat_order_dialog.dart';
import '../widgets/app_sweet_alert.dart';
import '../widgets/program_magang_card.dart';

enum ProjectItemType {
  opportunity,
  contract,
}

class UnifiedProjectItem {
  final String id;
  final String title;
  final String? description;
  final String category;
  final String statusCategory; // 'Mencari Kreator', 'Berjalan', 'Menunggu', 'Selesai'
  final String statusLabel;
  final Color statusColor;
  final String priceOrBudget;
  final String? deadline;
  final String? partnerOrApplicants;
  final int applicationsCount;
  final double progress;
  final ProjectItemType type;
  final JobContract? contract;
  final OpportunityModel? opportunity;
  final DateTime? createdAt;

  UnifiedProjectItem({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.statusCategory,
    required this.statusLabel,
    required this.statusColor,
    required this.priceOrBudget,
    this.deadline,
    this.partnerOrApplicants,
    this.applicationsCount = 0,
    this.progress = 0.0,
    required this.type,
    this.contract,
    this.opportunity,
    this.createdAt,
  });

  factory UnifiedProjectItem.fromOpportunity(OpportunityModel opp) {
    final statusLower = opp.status.toLowerCase();
    final isOpen = statusLower == 'open';
    final isClosed = statusLower == 'closed' || statusLower == 'completed';
    final isInProgress = statusLower == 'in_progress' || statusLower == 'active';

    final statusCategory = isOpen
        ? 'Mencari Kreator'
        : (isInProgress
            ? 'Berjalan'
            : (isClosed ? 'Selesai' : 'Menunggu'));

    final statusLabel = isOpen
        ? 'Mencari Kreator'
        : (isInProgress
            ? 'Acara Berlangsung'
            : (isClosed ? 'Kebutuhan Selesai' : 'Menunggu Konfirmasi'));

    final statusColor = isOpen
        ? const Color(0xFF8B5CF6)
        : (isInProgress
            ? const Color(0xFF10B981)
            : (isClosed ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B)));

    final count = opp.applicationsCount;
    final partnerText = count > 0
        ? '$count Pelamar Terdaftar'
        : 'Menunggu Pelamar';

    DateTime? created;
    if (opp.createdAt != null) {
      created = DateTime.tryParse(opp.createdAt!);
    }

    String categoryFormatted = opp.subRoleSlug.replaceAll('_', ' ');
    if (categoryFormatted.isNotEmpty) {
      categoryFormatted = categoryFormatted[0].toUpperCase() +
          categoryFormatted.substring(1);
    } else {
      categoryFormatted = 'Kreatif';
    }

    return UnifiedProjectItem(
      id: opp.id ?? '',
      title: opp.title,
      description: opp.description,
      category: categoryFormatted,
      statusCategory: statusCategory,
      statusLabel: statusLabel,
      statusColor: statusColor,
      priceOrBudget: opp.budgetRange != null && opp.budgetRange!.isNotEmpty
          ? opp.budgetRange!
          : 'Budget Fleksibel',
      deadline: opp.deadline,
      partnerOrApplicants: partnerText,
      applicationsCount: count,
      progress: isClosed ? 1.0 : (count > 0 ? 0.35 : 0.1),
      type: ProjectItemType.opportunity,
      opportunity: opp,
      createdAt: created,
    );
  }

  factory UnifiedProjectItem.fromContract(JobContract c, {String? currentUserId}) {
    final cs = c.contractStatus.toLowerCase();
    String statusCategory;
    Color statusColor;
    String statusLabel;

    if (cs == 'active' || cs == 'approved' || cs == 'escrow_paid') {
      statusCategory = 'Berjalan';
      statusColor = const Color(0xFF10B981);
      statusLabel = 'Kontrak Aktif';
    } else if (cs == 'completed') {
      statusCategory = 'Selesai';
      statusColor = const Color(0xFF3B82F6);
      statusLabel = 'Pekerjaan Selesai';
    } else if (cs == 'cancelled' || cs == 'disputed' || cs == 'cancel_requested') {
      statusCategory = 'Menunggu';
      statusColor = const Color(0xFFEF4444);
      statusLabel = cs == 'disputed' ? 'Sengketa' : 'Dibatalkan';
    } else {
      statusCategory = 'Menunggu';
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'Menunggu Persetujuan';
    }

    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    int progressPct = 0;
    switch (c.workStatus.toLowerCase()) {
      case 'completed':
      case 'done':
        progressPct = 100;
        break;
      case 'submitted':
        progressPct = 85;
        break;
      case 'review':
        progressPct = 75;
        break;
      case 'revision':
        progressPct = 50;
        break;
      case 'in_progress':
        progressPct = 40;
        break;
      case 'scheduled':
        progressPct = 15;
        break;
      default:
        progressPct = 5;
    }

    String formattedDeadline = '-';
    if (c.deadline != null) {
      formattedDeadline = DateFormat('dd MMM yyyy').format(c.deadline!);
    } else if (c.scheduledEndDate != null) {
      formattedDeadline = DateFormat('dd MMM yyyy').format(c.scheduledEndDate!);
    }

    final currentUserIdStr = currentUserId ?? '';
    final isCreator = currentUserIdStr.isNotEmpty && c.creatorId == currentUserIdStr;
    final partnerDisplay = isCreator ? 'Klien: ${c.clientName}' : 'Kreator: ${c.creatorName}';

    return UnifiedProjectItem(
      id: c.id,
      title: c.title,
      description: c.description,
      category: c.creatorServiceId != null ? 'Layanan Kreator' : 'Kontrak Proyek',
      statusCategory: statusCategory,
      statusLabel: statusLabel,
      statusColor: statusColor,
      priceOrBudget: currencyFormat.format(c.agreedPrice),
      deadline: formattedDeadline,
      partnerOrApplicants: partnerDisplay,
      applicationsCount: 0,
      progress: progressPct / 100.0,
      type: ProjectItemType.contract,
      contract: c,
      createdAt: c.createdAt,
    );
  }
}

class ProyekSayaScreen extends StatefulWidget {
  final UserModel? user;
  final ValueChanged<UserModel>? onUserUpdated;
  final String? initialOpportunityId;
  final String? initialContractId;
  final String? initialTitle;
  final OpportunityModel? initialOpportunity;
  final JobContract? initialContract;

  const ProyekSayaScreen({
    super.key,
    this.user,
    this.onUserUpdated,
    this.initialOpportunityId,
    this.initialContractId,
    this.initialTitle,
    this.initialOpportunity,
    this.initialContract,
  });

  @override
  State<ProyekSayaScreen> createState() => _ProyekSayaScreenState();
}

class _ProyekSayaScreenState extends State<ProyekSayaScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedStatus = 'Semua';
  String _searchQuery = '';
  bool _handledInitialTarget = false;
  final _debouncer = Debouncer(milliseconds: 300);
  final TextEditingController _searchController = TextEditingController();

  List<UnifiedProjectItem> _allItems = [];

  UserModel? get _currentUser => widget.user ?? currentUserNotifier.value;

  bool get _isCorporate {
    final u = _currentUser;
    if (u == null) return false;
    if (u.isCorporate) return true;
    final sub = (u.subRole ?? '').toLowerCase().trim();
    final role = u.role.toLowerCase().trim();
    const corporateKeywords = [
      'corporate',
      'company',
      'enterprise',
      'business',
      'perusahaan',
      'bisnis',
      'b2b',
      'agency',
      'industri',
      'mitra_industri',
    ];
    return corporateKeywords.contains(sub) ||
        corporateKeywords.contains(role) ||
        u.username.toLowerCase() == 'corporate_demo' ||
        u.email.toLowerCase().startsWith('corporate@');
  }

  bool get _isSchool {
    final sub = (_currentUser?.subRole ?? '').toLowerCase().trim();
    return sub == 'institution' ||
        sub == 'institusi' ||
        sub == 'school' ||
        sub == 'education' ||
        sub == 'campus' ||
        sub == 'sekolah' ||
        sub == 'kampus';
  }

  List<OpportunityModel> _getSampleMagangOpportunities() {
    return [
      OpportunityModel(
        id: 'sch_opp_magang_1',
        title: 'Program Magang MBKM 3D Modeler Batch I 2026',
        description:
            'Kerja sama penempatan 10 siswa vokasi magang pada produksi serial animasi nusantara.',
        subRoleSlug: 'animator',
        type: 'project',
        status: 'open',
        deadline: '2026-09-21',
        eventStartDate: '2026-09-21',
        eventEndDate: '2027-02-23',
        budgetRange: 'Rp 3.500.000 / bulan',
        requirements: [
          OpportunityRequirementModel(
            subRoleSlug: 'animator',
            quantity: 10,
            notes:
                'Siswa SMK jurusan terkait, Menguasai dasar 3D Modeling, Memiliki portofolio karya',
          ),
        ],
      ),
      OpportunityModel(
        id: 'sch_opp_magang_2',
        title: 'Program Magang MBKM UI/UX & Digital Product Design',
        description:
            'Kerja sama penempatan 8 siswa vokasi magang pada perancangan produk digital kreatif.',
        subRoleSlug: 'desainer',
        type: 'project',
        status: 'open',
        eventStartDate: '2027-02-01',
        eventEndDate: '2027-03-01',
        budgetRange: 'Rp 3.000.000 / bulan',
        requirements: [
          OpportunityRequirementModel(
            subRoleSlug: 'desainer',
            quantity: 8,
            notes:
                'Siswa SMK / Mahasiswa DKV & RPL, Menguasai Figma & Design System, Memiliki portofolio studi kasus',
          ),
        ],
      ),
      OpportunityModel(
        id: 'sch_opp_magang_3',
        title: 'Program Magang Post-Production & Motion Graphics',
        description:
            'Kerja sama penempatan 6 siswa magang post-production video komersial dan animasi nusantara.',
        subRoleSlug: 'editor',
        type: 'project',
        status: 'open',
        eventStartDate: '2027-02-15',
        eventEndDate: '2027-03-15',
        budgetRange: 'Rp 3.200.000 / bulan',
        requirements: [
          OpportunityRequirementModel(
            subRoleSlug: 'editor',
            quantity: 6,
            notes:
                'Siswa SMK Multimedia / Animasi, Mahir Premiere Pro & After Effects, Menyertakan showreel karya video',
          ),
        ],
      ),
    ];
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchRealtimeProjects();
  }

  Future<void> _fetchRealtimeProjects() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        JobContractService.getUserContracts().catchError((e) {
          debugPrint('Error fetching contracts: $e');
          return <JobContract>[];
        }),
        (_isSchool
                ? OpportunityService.getOpportunities(limit: 50)
                : OpportunityService.getMyOpportunities())
            .catchError((e) {
          debugPrint('Error fetching opportunities: $e');
          return <OpportunityModel>[];
        }),
      ]);

      final contracts = results[0] as List<JobContract>;
      final opportunities = List<OpportunityModel>.from(results[1] as List<OpportunityModel>);

      if (_isSchool && opportunities.isEmpty) {
        opportunities.addAll(_getSampleMagangOpportunities());
      }

      final unified = <UnifiedProjectItem>[];

      for (final opp in opportunities) {
        unified.add(UnifiedProjectItem.fromOpportunity(opp));
      }

      for (final contract in contracts) {
        unified.add(UnifiedProjectItem.fromContract(
          contract,
          currentUserId: widget.user?.id,
        ));
      }

      // Sort by creation date descending
      unified.sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });

      if (mounted) {
        setState(() {
          _allItems = unified;
          _errorMessage = null;
        });

        if (!_handledInitialTarget) {
          _handledInitialTarget = true;

          if (widget.initialTitle != null && widget.initialTitle!.isNotEmpty) {
            _searchController.text = widget.initialTitle!;
            _searchQuery = widget.initialTitle!.toLowerCase().trim();
          }

          if ((widget.initialOpportunityId != null && widget.initialOpportunityId!.isNotEmpty) ||
              (widget.initialTitle != null && widget.initialTitle!.isNotEmpty) ||
              widget.initialOpportunity != null) {
            UnifiedProjectItem? target;
            for (final item in _allItems) {
              if (item.type == ProjectItemType.opportunity) {
                if (widget.initialOpportunityId != null && item.id == widget.initialOpportunityId) {
                  target = item;
                  break;
                }
                if (widget.initialTitle != null &&
                    widget.initialTitle!.isNotEmpty &&
                    item.title.toLowerCase().contains(widget.initialTitle!.toLowerCase())) {
                  target = item;
                  break;
                }
              }
            }

            if (target?.opportunity != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _openOpportunityDetail(target!.opportunity!);
              });
            } else if (widget.initialOpportunity != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _openOpportunityDetail(widget.initialOpportunity!);
              });
            } else if (widget.initialOpportunityId != null &&
                !widget.initialOpportunityId!.startsWith('eo_') &&
                !widget.initialOpportunityId!.startsWith('wo_') &&
                !widget.initialOpportunityId!.startsWith('sch_') &&
                !widget.initialOpportunityId!.startsWith('gen_')) {
              OpportunityService.getOpportunityById(widget.initialOpportunityId!).then((opp) {
                if (opp != null && mounted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _openOpportunityDetail(opp);
                  });
                } else if (widget.initialTitle != null && widget.initialTitle!.isNotEmpty && mounted) {
                  final fallbackOpp = OpportunityModel(
                    id: widget.initialOpportunityId ?? 'opp_${DateTime.now().millisecondsSinceEpoch}',
                    title: widget.initialTitle!,
                    description: 'Kebutuhan dan aktivitas proyek ${widget.initialTitle}.',
                    budgetRange: 'Sesuai Kesepakatan',
                    subRoleSlug: widget.user?.subRole ?? 'event_organizer',
                    type: 'project',
                    status: 'open',
                    postedBy: widget.user?.id,
                  );
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _openOpportunityDetail(fallbackOpp);
                  });
                }
              }).catchError((_) {});
            } else if (widget.initialTitle != null && widget.initialTitle!.isNotEmpty) {
              final fallbackOpp = OpportunityModel(
                id: widget.initialOpportunityId ?? 'opp_${DateTime.now().millisecondsSinceEpoch}',
                title: widget.initialTitle!,
                description: 'Kebutuhan dan aktivitas proyek ${widget.initialTitle}.',
                budgetRange: 'Sesuai Kesepakatan',
                subRoleSlug: widget.user?.subRole ?? 'event_organizer',
                type: 'project',
                status: 'open',
                postedBy: widget.user?.id,
              );
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _openOpportunityDetail(fallbackOpp);
              });
            }
          } else if ((widget.initialContractId != null && widget.initialContractId!.isNotEmpty) ||
              (widget.initialTitle != null && widget.initialTitle!.isNotEmpty) ||
              widget.initialContract != null) {
            UnifiedProjectItem? target;
            for (final item in _allItems) {
              if (item.type == ProjectItemType.contract) {
                if (widget.initialContractId != null && item.id == widget.initialContractId) {
                  target = item;
                  break;
                }
                if (widget.initialTitle != null &&
                    widget.initialTitle!.isNotEmpty &&
                    item.title.toLowerCase().contains(widget.initialTitle!.toLowerCase())) {
                  target = item;
                  break;
                }
              }
            }
            if (target != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _openContractOpportunity(target!);
              });
            } else if (widget.initialContract != null) {
              final item = UnifiedProjectItem.fromContract(widget.initialContract!, currentUserId: widget.user?.id);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _openContractOpportunity(item);
              });
            } else if (widget.initialTitle != null && widget.initialTitle!.isNotEmpty) {
              final dummyContract = JobContract(
                id: widget.initialContractId ?? 'ctr_${DateTime.now().millisecondsSinceEpoch}',
                title: widget.initialTitle!,
                description: 'Kontrak aktif proyek ${widget.initialTitle}.',
                clientId: widget.user?.id ?? 'client_id',
                creatorId: 'creator_id',
                contractStatus: 'active',
                workStatus: 'in_progress',
                agreedPrice: 20000000,
                escrowAmount: 20000000,
                escrowPaid: true,
                createdAt: DateTime.now(),
                creator: {'name': 'Kreator Partner'},
                client: {'name': widget.user?.name ?? 'Klien'},
              );
              final item = UnifiedProjectItem.fromContract(dummyContract, currentUserId: widget.user?.id);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _openContractOpportunity(item);
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching projects: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat proyek. Periksa koneksi internet Anda.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openBuatKebutuhan() async {
    if (_isSchool) {
      AppSweetAlert.error(
        context,
        'Fitur Buka Program Magang khusus untuk akun Corporate / Mitra Industri. Institusi Pendidikan tidak dapat membuka lowongan magang.',
        title: 'Akses Ditolak (403)',
      );
      return;
    }

    // Akun corporate tidak memerlukan verifikasi KTP sama sekali
    if (_isCorporate) {
      if (!mounted) return;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BuatKebutuhanScreen(user: _currentUser)),
      );

      if (result == true) {
        _fetchRealtimeProjects();
      }
      return;
    }

    // Check if client is verified
    final u = _currentUser;
    final isClient = u?.role == 'user' || u?.isClient == true;
    if (isClient) {
      bool isVerified = u?.isVerified == true || u?.isClientVerified == true;
      if (!isVerified) {
        // Double check latest status from server
        try {
          final status = await VerificationService.getStatus();
          if (status != null && status.isVerified) {
            isVerified = true;
          }
        } catch (_) {}
      }

      if (!isVerified && mounted) {
        final shouldVerify = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.verified_user_outlined, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Verifikasi KTP Diperlukan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: const Text(
              'Untuk menjaga keamanan komunitas dan kepercayaan di platform Kreavana, akun Klien wajib melakukan verifikasi KTP terlebih dahulu sebelum menambahkan kebutuhan proyek baru.\n\nVerifikasi ini tidak mengubah akun Anda menjadi Kreator.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Batal'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                icon: const Icon(Icons.shield_rounded, size: 16),
                label: const Text('Verifikasi Sekarang'),
              ),
            ],
          ),
        );

        if (shouldVerify == true && mounted) {
          final res = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => ClientVerificationPage(user: _currentUser),
            ),
          );
          if (res == true && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Verifikasi KTP berhasil dikirim! Menunggu persetujuan admin.',
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
        return;
      }
    }

    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BuatKebutuhanScreen(user: _currentUser)),
    );

    if (result == true) {
      _fetchRealtimeProjects();
    }
  }

  void _openOpportunityDetail(OpportunityModel opp, {JobContract? contract}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailKebutuhanScreen(
          opportunity: opp,
          user: widget.user ?? currentUserNotifier.value,
          initialContract: contract,
        ),
      ),
    ).then((_) => _fetchRealtimeProjects());
  }

  Future<void> _openContractOpportunity(UnifiedProjectItem item) async {
    final c = item.contract;
    if (c == null) {
      if (item.opportunity != null) {
        _openOpportunityDetail(item.opportunity!);
      }
      return;
    }

    final oppId = c.opportunityId;
    if (oppId != null && oppId.isNotEmpty) {
      // 1. Cek apakah model opportunity sudah ada di list realtime saat ini
      for (final it in _allItems) {
        if (it.opportunity != null && it.opportunity!.id == oppId) {
          _openOpportunityDetail(it.opportunity!, contract: c);
          return;
        }
      }

      // 2. Jika belum ada di list, tampilkan loader lalu ambil via API
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Membuka detail proyek...', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      );

      try {
        final opp = await OpportunityService.getOpportunityById(oppId);
        if (mounted) {
          Navigator.pop(context); // Tutup loader
          if (opp != null) {
            _openOpportunityDetail(opp, contract: c);
            return;
          }
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
        }
      }
    }

    // Bangun model OpportunityModel dari data kontrak lengkap agar tampil persis seperti halaman Detail Kebutuhan
    final currencyFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final deadlineStr = c.deadline != null
        ? DateFormat('yyyy-MM-dd').format(c.deadline!)
        : (c.scheduledEndDate != null ? DateFormat('yyyy-MM-dd').format(c.scheduledEndDate!) : null);
    final deadlineFormatted = c.deadline != null
        ? DateFormat('dd MMM yyyy').format(c.deadline!)
        : (c.scheduledEndDate != null ? DateFormat('dd MMM yyyy').format(c.scheduledEndDate!) : null);

    final partnerRole = _getPartnerRole(c);
    final approvedCreator = OpportunityApprovedCreatorModel(
      id: c.creatorId,
      name: c.creatorName.isNotEmpty ? c.creatorName : 'Kreator Partner',
      username: c.creator?['username'] ?? c.creatorName.toLowerCase().replaceAll(' ', '_'),
      avatarUrl: c.creator?['avatar_url'] ?? c.creator?['profile_photo_url'],
      subRole: partnerRole.isNotEmpty ? partnerRole : 'creator',
      creatorSignature: c.creatorSignature,
      creatorSignedAt: c.creatorSignedAt?.toIso8601String() ??
          (c.creatorApproved ? (c.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String()) : null),
    );

    final poster = OpportunityPoster(
      id: c.clientId,
      name: c.clientName.isNotEmpty ? c.clientName : (widget.user?.name ?? 'Klien'),
      username: c.client?['username'] ?? (widget.user?.username ?? 'klien'),
      avatarUrl: c.client?['avatar_url'] ?? c.client?['profile_photo_url'],
      role: 'client',
    );

    final defaultDynamicTerms = [
      'Penyelenggara (Pihak Pertama) wajib menyediakan akses lokasi, jadwal rundown yang jelas, dan koordinasi teknis di venue.',
      'Penyediaan fasilitas dan alat kerja utama (seperti kamera, lensa, instrumen, dll) disepakati tertulis antara pembuat event dan pekerja.',
      'Pekerja (Pihak Kedua) berkewajiban hadir tepat waktu dan menyerahkan hasil kerja sesuai standar profesional yang disepakati.',
      'Honorarium kerja diamankan 100% pada sistem Escrow Rekber Kreavana (Pihak Ketiga) dan hanya dicairkan setelah hasil pekerjaan disetujui.',
    ];

    final dynamicTerms = c.dynamicTerms.isNotEmpty
        ? c.dynamicTerms
        : (c.terms != null && c.terms!.isNotEmpty ? [c.terms!] : defaultDynamicTerms);

    final fallbackOpp = OpportunityModel(
      id: (c.opportunityId != null && c.opportunityId!.isNotEmpty) ? c.opportunityId : c.id,
      title: c.title,
      description: c.description ?? 'Aktivitas dan pengerjaan proyek ${c.title}.',
      budgetRange: currencyFmt.format(c.agreedPrice),
      subRoleSlug: partnerRole.isNotEmpty ? partnerRole : (widget.user?.subRole ?? 'creator'),
      type: 'project',
      location: 'Indonesia',
      deadline: deadlineStr ?? deadlineFormatted,
      status: c.contractStatus == 'active' ? 'in_progress' : c.contractStatus,
      postedBy: c.clientId,
      poster: poster,
      approvedCreators: [approvedCreator],
      applicationsCount: 1,
      escrowStatus: c.escrowPaid ? 'held_in_escrow' : 'none',
      escrowAmount: c.escrowAmount > 0 ? c.escrowAmount : c.agreedPrice,
      dynamicTerms: dynamicTerms,
      signatureType: 'dynamic_electronic',
      clientSignature: c.clientSignature,
      clientSignedAt: c.clientSignedAt?.toIso8601String(),
      adminName: c.adminName ?? 'Admin Kreavana',
      adminSignatureUrl: c.adminSignatureUrl,
      adminSignedAt: c.adminSignedAt?.toIso8601String(),
      eventProgress: c.workerProgress,
      createdAt: c.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    );

    if (mounted) {
      _openOpportunityDetail(fallbackOpp, contract: c);
    }
  }

  String _getPartnerId(JobContract contract) {
    final currentUserId = widget.user?.id ?? '';
    if (currentUserId.isNotEmpty && contract.creatorId == currentUserId) {
      return contract.clientId;
    }
    return contract.creatorId;
  }

  String _getPartnerName(JobContract contract) {
    final currentUserId = widget.user?.id ?? '';
    if (currentUserId.isNotEmpty && contract.creatorId == currentUserId) {
      return contract.clientName;
    }
    return contract.creatorName;
  }

  String _getPartnerRole(JobContract contract) {
    final currentUserId = widget.user?.id ?? '';
    if (currentUserId.isNotEmpty && contract.creatorId == currentUserId) {
      return 'client';
    }
    return 'creator';
  }

  Future<void> _openChatWithPartner(String targetUserId, String? targetUserName) async {
    final cleanId = targetUserId.trim();
    if (cleanId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID partner tidak ditemukan pada kontrak ini.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (widget.user?.id != null && widget.user!.id == cleanId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat mengirim pesan ke akun sendiri.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    // Tampilkan loading modal dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.primaryPurple),
              const SizedBox(height: 16),
              Text(
                targetUserName != null && targetUserName.isNotEmpty
                    ? 'Membuka obrolan dengan $targetUserName...'
                    : 'Membuka obrolan...',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final res = await ChatService.startPersonalChat(cleanId);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Tutup dialog loading

      if (res['status'] == true && res['data'] != null) {
        final chatData = Map<String, dynamic>.from(res['data']);
        final isDesktop = MediaQuery.of(context).size.width > 800;

        if (isDesktop) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DirectMessageScreen(
                currentUser: widget.user,
                initialChat: chatData,
                chatId: chatData['id']?.toString(),
                targetUserId: cleanId,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Scaffold(
                body: ChatDetailSection(
                  chat: chatData,
                  isMobile: true,
                  currentUser: widget.user,
                ),
              ),
            ),
          );
        }
      } else {
        // Fallback navigasi langsung ke DirectMessageScreen dengan targetUserId
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DirectMessageScreen(
              currentUser: widget.user,
              targetUserId: cleanId,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error starting personal chat: $e');
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Tutup dialog jika error
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DirectMessageScreen(
              currentUser: widget.user,
              targetUserId: cleanId,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final role = widget.user?.role ?? 'user';
    final subRole = widget.user?.subRole ?? 'general';
    final accentColor = SubRoleThemeEngine.getAccentColor(role, subRole);

    final isDesktop = MediaQuery.of(context).size.width > 900;
    final screenWidth = MediaQuery.of(context).size.width;

    // Filter by status category
    final filtered = _allItems.where((item) {
      if (_selectedStatus != 'Semua' && item.statusCategory != _selectedStatus) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = item.title.toLowerCase().contains(q);
        final matchCat = item.category.toLowerCase().contains(q);
        final matchPartner = (item.partnerOrApplicants ?? '').toLowerCase().contains(q);
        final matchDesc = (item.description ?? '').toLowerCase().contains(q);
        return matchTitle || matchCat || matchPartner || matchDesc;
      }
      return true;
    }).toList();

    // Counts
    final totalCount = _allItems.length;
    final mencariKreatorCount = _allItems.where((i) => i.statusCategory == 'Mencari Kreator').length;
    final berjalanCount = _allItems.where((i) => i.statusCategory == 'Berjalan').length;
    final menungguCount = _allItems.where((i) => i.statusCategory == 'Menunggu').length;
    final selesaiCount = _allItems.where((i) => i.statusCategory == 'Selesai').length;

    final scaffold = Scaffold(
      backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFF7F8FC),
      body: RefreshIndicator(
        onRefresh: _fetchRealtimeProjects,
        color: accentColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 32 : 16,
              isDesktop ? 32 : 16,
              isDesktop ? 32 : 16,
              isDesktop ? 60 : 100,
            ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Breadcrumbs ──
                    AppBreadcrumbs(
                      items: [
                        BreadcrumbItem(
                          label: 'Beranda',
                          icon: Icons.home_rounded,
                          onTap: () {
                            if (widget.user != null) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MainNavigation(
                                    initialUser: widget.user!,
                                    initialIndex: 0,
                                  ),
                                ),
                                (r) => false,
                              );
                            }
                          },
                        ),
                        BreadcrumbItem(
                          label: _isSchool ? 'Program & Magang' : 'Proyek Saya',
                          icon: _isSchool ? Icons.work_outline_rounded : Icons.folder_rounded,
                        ),
                      ],
                    ),

                    // ── Header Desktop & Mobile ──
                    _buildHeader(isDark, isDesktop, accentColor),
                    const SizedBox(height: 24),

                    // ── KPI Summary Cards ──
                    _buildSummaryMetrics(
                      total: totalCount,
                      mencariKreator: mencariKreatorCount,
                      berjalan: berjalanCount,
                      menunggu: menungguCount,
                      selesai: selesaiCount,
                      isDark: isDark,
                      isDesktop: isDesktop,
                    ),
                    const SizedBox(height: 24),

                    // ── Search & Filter Controls ──
                    _buildSearchAndFilters(
                      isDark: isDark,
                      isDesktop: isDesktop,
                      accentColor: accentColor,
                      total: totalCount,
                      mencariKreator: mencariKreatorCount,
                      berjalan: berjalanCount,
                      menunggu: menungguCount,
                      selesai: selesaiCount,
                    ),
                    const SizedBox(height: 20),

                    // ── Projects Content ──
                    if (_isLoading)
                      const SkeletonList()
                    else if (_errorMessage != null)
                      _buildErrorState(accentColor, isDark)
                    else if (filtered.isEmpty)
                      _buildEmptyState(isDark)
                    else
                      _buildProjectsGrid(filtered, isDark, isDesktop, screenWidth, accentColor),
                  ],
                ),
              ),
        ),
      ),
      floatingActionButton: (!isDesktop && !_isSchool)
          ? FloatingActionButton.extended(
              heroTag: 'proyek_saya_fab_mobile',
              onPressed: _openBuatKebutuhan,
              backgroundColor: accentColor,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'Buat Kebutuhan',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );

    final effectiveUser = widget.user ?? currentUserNotifier.value;
    if (isDesktop && effectiveUser != null) {
      return DesktopSidebarLayout(
        user: effectiveUser,
        activeRoute: 'proyek_saya',
        onUserUpdated: widget.onUserUpdated,
        child: scaffold,
      );
    }

    return scaffold;
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isDark, bool isDesktop, Color accentColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (Navigator.canPop(context))
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardBg : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isSchool ? 'Program & Magang' : 'Proyek Saya',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isSchool
                    ? 'Pantau program magang industri dan kemitraan siswa bersama studio mitra.'
                    : 'Pantau kebutuhan terbuka, proposal kreator, dan progres kontrak kerja Anda.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _fetchRealtimeProjects,
          tooltip: 'Segarkan data realtime',
          style: IconButton.styleFrom(
            backgroundColor: isDark ? AppTheme.cardBg : Colors.white,
            side: BorderSide(
              color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        if (isDesktop && !_isSchool) ...[
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _openBuatKebutuhan,
            icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
            label: const Text(
              'Buat Proyek Baru',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── KPI Summary Metrics ────────────────────────────────────────────────────
  Widget _buildSummaryMetrics({
    required int total,
    required int mencariKreator,
    required int berjalan,
    required int menunggu,
    required int selesai,
    required bool isDark,
    required bool isDesktop,
  }) {
    final List<Map<String, dynamic>> metricData = [
      {
        'status': 'Semua',
        'label': _isSchool ? 'Total Program' : 'Total Proyek',
        'value': total.toString(),
        'icon': _isSchool ? Icons.work_outline_rounded : Icons.folder_special_rounded,
        'color': const Color(0xFF6366F1),
      },
      {
        'status': 'Mencari Kreator',
        'label': _isSchool ? 'Buka Pendaftaran' : 'Mencari Kreator',
        'value': mencariKreator.toString(),
        'icon': Icons.campaign_rounded,
        'color': const Color(0xFF8B5CF6),
      },
      {
        'status': 'Berjalan',
        'label': _isSchool ? 'Magang Berjalan' : 'Kontrak Berjalan',
        'value': berjalan.toString(),
        'icon': Icons.trending_up_rounded,
        'color': const Color(0xFF10B981),
      },
      {
        'status': 'Menunggu',
        'label': 'Menunggu Konfirmasi',
        'value': menunggu.toString(),
        'icon': Icons.hourglass_top_rounded,
        'color': const Color(0xFFF59E0B),
      },
      {
        'status': 'Selesai',
        'label': 'Selesai',
        'value': selesai.toString(),
        'icon': Icons.check_circle_rounded,
        'color': const Color(0xFF3B82F6),
      },
    ];

    if (isDesktop) {
      return Row(
        children: metricData.map((m) {
          final isSelected = _selectedStatus == m['status'];
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: _buildMetricCard(m, isSelected, isDark),
            ),
          );
        }).toList(),
      );
    }

    // Mobile: 2 rows or scrollable
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: metricData.length,
        separatorBuilder: (ctx, i) => const SizedBox(width: 10),
        itemBuilder: (context, idx) {
          final m = metricData[idx];
          final isSelected = _selectedStatus == m['status'];
          return SizedBox(
            width: 150,
            child: _buildMetricCard(m, isSelected, isDark),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(Map<String, dynamic> m, bool isSelected, bool isDark) {
    final color = m['color'] as Color;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() => _selectedStatus = m['status'] as String);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardBg : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? AppTheme.inputBorder : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? color.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(m['icon'] as IconData, size: 18, color: color),
                ),
                Text(
                  m['value'] as String,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              m['label'] as String,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? color
                    : (isDark ? AppTheme.textMuted : Colors.grey.shade600),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── Search & Filter Bar ────────────────────────────────────────────────────
  Widget _buildSearchAndFilters({
    required bool isDark,
    required bool isDesktop,
    required Color accentColor,
    required int total,
    required int mencariKreator,
    required int berjalan,
    required int menunggu,
    required int selesai,
  }) {
    final statusOptions = [
      {'key': 'Semua', 'label': 'Semua', 'count': total},
      {
        'key': 'Mencari Kreator',
        'label': _isSchool ? 'Buka Pendaftaran' : 'Mencari Kreator',
        'count': mencariKreator,
      },
      {
        'key': 'Berjalan',
        'label': _isSchool ? 'Magang Berjalan' : 'Berjalan',
        'count': berjalan,
      },
      {'key': 'Menunggu', 'label': 'Menunggu', 'count': menunggu},
      {'key': 'Selesai', 'label': 'Selesai', 'count': selesai},
    ];

    final searchField = TextField(
      controller: _searchController,
      onChanged: (v) {
        _debouncer.run(() {
          setState(() => _searchQuery = v);
        });
      },
      decoration: InputDecoration(
        hintText: _isSchool
            ? 'Cari program, lowongan magang, atau nama industri mitra...'
            : 'Cari proyek, kebutuhan, atau nama kreator...',
        hintStyle: TextStyle(
          fontSize: 13,
          color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
        ),
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: isDark ? AppTheme.cardBg : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryPurple, width: 1.6),
        ),
      ),
    );

    final filterChips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: statusOptions.map((opt) {
          final key = opt['key'] as String;
          final label = opt['label'] as String;
          final count = opt['count'] as int;
          final isSel = _selectedStatus == key;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSel
                          ? Colors.white.withValues(alpha: 0.25)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                ],
              ),
              selected: isSel,
              selectedColor: AppTheme.primaryPurple,
              backgroundColor: isDark ? AppTheme.cardBg : Colors.white,
              side: BorderSide(
                color: isSel
                    ? AppTheme.primaryPurple
                    : (isDark ? AppTheme.inputBorder : Colors.grey.shade200),
              ),
              labelStyle: TextStyle(
                color: isSel
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.grey.shade800),
                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
              onSelected: (val) {
                if (val) setState(() => _selectedStatus = key);
              },
            ),
          );
        }).toList(),
      ),
    );

    if (isDesktop) {
      return Row(
        children: [
          Expanded(flex: 3, child: searchField),
          const SizedBox(width: 16),
          Expanded(flex: 4, child: filterChips),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        searchField,
        const SizedBox(height: 12),
        filterChips,
      ],
    );
  }

  // ── Projects Grid Layout ───────────────────────────────────────────────────
  Widget _buildProjectsGrid(
    List<UnifiedProjectItem> items,
    bool isDark,
    bool isDesktop,
    double screenWidth,
    Color accentColor,
  ) {
    if (isDesktop) {
      // 2-column responsive layout for clean desktop readability
      return LayoutBuilder(
        builder: (context, constraints) {
          const double spacing = 16.0;
          final bool isTwoCol = constraints.maxWidth >= 680;
          final double cardWidth = isTwoCol
              ? (constraints.maxWidth - spacing) / 2 - 0.5
              : constraints.maxWidth;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: items.map((item) {
              return SizedBox(
                width: cardWidth,
                child: _buildUnifiedCard(item, isDark, accentColor),
              );
            }).toList(),
          );
        },
      );
    }

    // Mobile: vertical column
    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _buildUnifiedCard(item, isDark, accentColor),
        );
      }).toList(),
    );
  }

  // ── Unified Project Card ───────────────────────────────────────────────────
  Widget _buildUnifiedCard(
    UnifiedProjectItem item,
    bool isDark,
    Color accentColor,
  ) {
    final isOpportunity = item.type == ProjectItemType.opportunity;

    final isMagang = _isSchool ||
        item.category.toLowerCase().contains('magang') ||
        item.title.toLowerCase().contains('magang') ||
        (item.opportunity != null &&
            (item.opportunity!.subRoleSlug.toLowerCase() == 'magang' ||
                item.opportunity!.title.toLowerCase().contains('magang')));

    if (isMagang) {
      if (item.opportunity != null) {
        return ProgramMagangCard.fromOpportunity(
          item.opportunity!,
          onTap: () => _openOpportunityDetail(item.opportunity!),
          onDetailPressed: () => _openOpportunityDetail(item.opportunity!),
        );
      } else {
        return ProgramMagangCard(
          title: item.title,
          description: item.description,
          categoryBadge: 'Magang',
          statusBadge: item.statusCategory == 'Mencari Kreator'
              ? 'Pendaftaran Dibuka'
              : (item.statusCategory == 'Berjalan'
                  ? 'Sedang Berjalan'
                  : (item.statusCategory == 'Selesai'
                      ? 'Pendaftaran Ditutup'
                      : item.statusLabel)),
          statusBadgeColor: item.statusColor,
          registrationPeriod: ProgramMagangCard.formatDateDisplay(
            item.deadline != '-' ? item.deadline : null,
            defaultFallback: '21 Sep 2026',
          ),
          quotaText: '4 dari 10 posisi',
          requirements: const [
            'Siswa SMK jurusan terkait',
            'Menguasai dasar 3D Modeling',
            'Memiliki portofolio karya',
          ],
          requirementsCountLabel: '3 Persyaratan',
          onTap: () {
            if (item.contract != null) {
              _openContractOpportunity(item);
            }
          },
          onDetailPressed: () {
            if (item.contract != null) {
              _openContractOpportunity(item);
            }
          },
        );
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          if (isOpportunity && item.opportunity != null) {
            _openOpportunityDetail(item.opportunity!);
          } else if (!isOpportunity) {
            _openContractOpportunity(item);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardBg : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
            ),
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
          // ── Top Type Pill & Status Badge ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOpportunity
                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.1)
                      : const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOpportunity
                          ? Icons.campaign_rounded
                          : Icons.handshake_rounded,
                      size: 14,
                      color: isOpportunity
                          ? const Color(0xFF8B5CF6)
                          : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOpportunity ? 'Kebutuhan Proyek' : 'Kontrak Kerja',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isOpportunity
                            ? const Color(0xFF8B5CF6)
                            : const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: item.statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: item.statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: item.statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Title ──
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (item.description != null && item.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.description!,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 14),

          // ── Metadata Pills (Category, Budget, Deadline) ──
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMetaChip(
                Icons.category_rounded,
                item.category,
                isDark,
              ),
              _buildMetaChip(
                Icons.payments_rounded,
                item.priceOrBudget,
                isDark,
                highlight: true,
              ),
              if (item.deadline != null && item.deadline != '-')
                _buildMetaChip(
                  Icons.event_rounded,
                  item.deadline!,
                  isDark,
                ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Partner / Pelamar Info & Progress ──
          if (isOpportunity) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : const Color(0xFFF9FAFD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    item.applicationsCount > 0
                        ? Icons.people_alt_rounded
                        : Icons.person_search_rounded,
                    size: 16,
                    color: item.applicationsCount > 0
                        ? AppTheme.primaryPurple
                        : Colors.grey.shade500,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.partnerOrApplicants ?? 'Menunggu Pelamar',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: item.applicationsCount > 0
                            ? (isDark ? Colors.white : Colors.black87)
                            : (isDark ? AppTheme.textMuted : Colors.grey.shade600),
                      ),
                    ),
                  ),
                  if (item.applicationsCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Ada Proposal Masuk',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ] else ...[
            // Contract Progress
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    final c = item.contract;
                    if (c != null) {
                      final partnerId = _getPartnerId(c);
                      final partnerName = _getPartnerName(c);
                      final partnerRole = _getPartnerRole(c);
                      if (partnerId.isNotEmpty) {
                        UserProfileModal.show(
                          context,
                          userId: partnerId,
                          initialName: partnerName,
                          initialRole: partnerRole,
                          currentUser: widget.user,
                        );
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_rounded,
                          size: 15,
                          color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Builder(
                          builder: (context) {
                            final c = item.contract;
                            final partnerId = c != null ? _getPartnerId(c) : '';
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.partnerOrApplicants ?? '-',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : Colors.grey.shade800,
                                    decoration: partnerId.isNotEmpty
                                        ? TextDecoration.underline
                                        : null,
                                  ),
                                ),
                                if (partnerId.isNotEmpty) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.open_in_new_rounded,
                                    size: 11,
                                    color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  '${(item.progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: item.statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: item.progress,
                minHeight: 6,
                backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(item.statusColor),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // ── Action Buttons ──
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isOpportunity) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    if (item.opportunity != null) {
                      _openOpportunityDetail(item.opportunity!);
                    }
                  },
                  icon: const Icon(Icons.how_to_reg_rounded, size: 15),
                  label: Text(
                    item.applicationsCount > 0
                        ? 'Kelola Pelamar (${item.applicationsCount})'
                        : 'Lihat Detail Kebutuhan',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryPurple,
                    side: BorderSide(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
                if (item.opportunity != null && item.opportunity!.isClosed)
                  ..._buildOpportunityCompletedActions(item.opportunity!, item),
              ] else ...[
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  tooltip: 'Chat Partner',
                  onPressed: () {
                    final c = item.contract;
                    if (c != null) {
                      final partnerId = _getPartnerId(c);
                      final partnerName = _getPartnerName(c);
                      _openChatWithPartner(partnerId, partnerName);
                    } else if (item.opportunity != null) {
                      final opp = item.opportunity!;
                      final targetId = opp.postedBy ?? '';
                      _openChatWithPartner(targetId, opp.poster?.name);
                    }
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (item.contract?.opportunityId != null && item.contract!.opportunityId!.isNotEmpty) ...[
                  ElevatedButton.icon(
                    onPressed: () => _openContractOpportunity(item),
                    icon: const Icon(Icons.dashboard_customize_rounded, size: 14),
                    label: const Text('Workspace Proyek', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                OutlinedButton(
                  onPressed: () {
                    _openContractOpportunity(item);
                  },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  child: const Text(
                    'Detail Kontrak',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                if (item.contract != null &&
                    (item.contract!.isCompleted || item.progress >= 1.0))
                  ..._buildContractCompletedActions(item.contract!, item),
              ],
            ],
          ),
        ],
      ),
    ),
  ),
);
  }

  List<Widget> _buildOpportunityCompletedActions(OpportunityModel opp, UnifiedProjectItem item) {
    final widgets = <Widget>[];
    final approvedCreator = opp.approvedCreators.isNotEmpty ? opp.approvedCreators.first : null;
    if (approvedCreator != null && (widget.user?.isClient == true || opp.postedBy == widget.user?.id)) {
      widgets.add(const SizedBox(width: 8));
      widgets.add(
        ElevatedButton.icon(
          onPressed: () {
            RepeatOrderDialog.show(
              context,
              creatorId: approvedCreator.id,
              creatorName: approvedCreator.name,
              creatorAvatar: approvedCreator.avatarUrl,
              originalTitle: item.title,
              originalPrice: double.tryParse(opp.budgetRange?.replaceAll(RegExp(r'[^0-9]'), '') ?? '') ?? 0.0,
              onSuccess: _fetchRealtimeProjects,
            );
          },
          icon: const Icon(Icons.replay_rounded, size: 15, color: Colors.white),
          label: const Text('Repeat Order', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
        ),
      );
    }

    widgets.add(const SizedBox(width: 8));
    widgets.add(
      ElevatedButton.icon(
        onPressed: () {
          OpportunityReviewDialog.show(
            context,
            opportunityId: opp.id ?? '',
            projectTitle: opp.title,
            targetUserId: approvedCreator?.id ?? opp.postedBy ?? '',
            targetUserName: approvedCreator?.name ?? 'Kreator Terkait',
            targetUserAvatar: approvedCreator?.avatarUrl,
            targetUserSubRole: approvedCreator?.capability ?? approvedCreator?.subRole,
            onReviewSubmitted: _fetchRealtimeProjects,
          );
        },
        icon: const Icon(Icons.star_rounded, size: 16, color: Color(0xFFD97706)),
        label: const Text('Beri Ulasan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.15),
          foregroundColor: const Color(0xFFD97706),
          elevation: 0,
          side: const BorderSide(color: Color(0xFFF59E0B), width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
      ),
    );

    return widgets;
  }

  List<Widget> _buildContractCompletedActions(JobContract c, UnifiedProjectItem item) {
    final widgets = <Widget>[];
    if (c.clientId == widget.user?.id || widget.user?.isClient == true) {
      widgets.add(const SizedBox(width: 8));
      widgets.add(
        ElevatedButton.icon(
          onPressed: () {
            RepeatOrderDialog.show(
              context,
              contractId: c.id,
              creatorId: c.creatorId,
              creatorName: c.creatorName.isNotEmpty ? c.creatorName : 'Kreator',
              creatorAvatar: c.creator?['avatar_url'] ?? c.creator?['profile_photo_url'],
              originalTitle: item.title,
              originalPrice: c.agreedPrice,
              defaultTerms: c.terms,
              onSuccess: _fetchRealtimeProjects,
            );
          },
          icon: const Icon(Icons.replay_rounded, size: 15, color: Colors.white),
          label: const Text('Repeat Order', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
        ),
      );
    }

    final partnerId = _getPartnerId(c);
    final partnerName = _getPartnerName(c);
    widgets.add(const SizedBox(width: 8));
    widgets.add(
      ElevatedButton.icon(
        onPressed: () {
          OpportunityReviewDialog.show(
            context,
            opportunityId: c.opportunityId ?? '',
            projectTitle: item.title,
            targetUserId: partnerId,
            targetUserName: partnerName,
            onReviewSubmitted: _fetchRealtimeProjects,
          );
        },
        icon: const Icon(Icons.star_rounded, size: 16, color: Color(0xFFD97706)),
        label: const Text('Beri Ulasan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.15),
          foregroundColor: const Color(0xFFD97706),
          elevation: 0,
          side: const BorderSide(color: Color(0xFFF59E0B), width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
      ),
    );

    return widgets;
  }

  Widget _buildMetaChip(
    IconData icon,
    String text,
    bool isDark, {
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.primaryPurple.withValues(alpha: 0.08)
            : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight
              ? AppTheme.primaryPurple.withValues(alpha: 0.2)
              : (isDark ? AppTheme.inputBorder : Colors.grey.shade200),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: highlight
                ? AppTheme.primaryPurple
                : (isDark ? AppTheme.textMuted : Colors.grey.shade600),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
              color: highlight
                  ? AppTheme.primaryPurple
                  : (isDark ? Colors.white70 : Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }



  // ── Empty State ────────────────────────────────────────────────────────────
  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_open_rounded,
                size: 48,
                color: AppTheme.primaryPurple,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _selectedStatus == 'Semua'
                  ? (_isSchool
                      ? 'Belum Ada Program & Magang Aktif'
                      : 'Belum Ada Proyek yang Dibuat')
                  : (_isSchool
                      ? 'Tidak Ada Program pada Status "$_selectedStatus"'
                      : 'Tidak Ada Proyek pada Status "$_selectedStatus"'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isSchool
                  ? 'Program magang dibuka langsung oleh mitra korporat dan industri. Pantau program dan pelamar magang dari mitra industri di sini.'
                  : 'Publikasikan kebutuhan proyek Anda sekarang untuk menerima proposal dari kreator terverifikasi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
              ),
            ),
            if (!_isSchool) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _openBuatKebutuhan,
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                label: const Text(
                  'Buat Kebutuhan Baru',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Error State ────────────────────────────────────────────────────────────
  Widget _buildErrorState(Color accentColor, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppTheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Terjadi kesalahan saat memuat data',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchRealtimeProjects,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
