import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/opportunity_model.dart';
import '../models/opportunity_application_model.dart';
import '../models/user_model.dart';
import '../services/opportunity_service.dart';
import '../services/chat_service.dart';
import '../screens/direct_message_screen.dart';
import '../app/theme.dart';
import '../utils/app_errors.dart';
import '../widgets/desktop_sidebar_layout.dart';
import '../widgets/app_breadcrumbs.dart';
import '../widgets/user_profile_modal.dart';
import '../widgets/verification_badge.dart';
import '../widgets/upgrade_plan_modal.dart';
import 'proyek_saya_screen.dart';

class DetailKebutuhanScreen extends StatefulWidget {
  final OpportunityModel opportunity;
  final UserModel? user;

  const DetailKebutuhanScreen({
    super.key,
    required this.opportunity,
    this.user,
  });

  @override
  State<DetailKebutuhanScreen> createState() => _DetailKebutuhanScreenState();
}

class _DetailKebutuhanScreenState extends State<DetailKebutuhanScreen> {
  late OpportunityModel _opp;
  List<OpportunityApplicationModel> _applications = [];
  bool _loadingApps = true;
  String _selectedFilter = 'Semua'; // 'Semua', 'pending', 'approved', 'rejected'
  String _aiFilterSubRole = 'Semua';
  bool _actionLoading = false;

  bool get _isOwner {
    final myId = widget.user?.id ?? '';
    return myId.isNotEmpty && _opp.postedBy != null && _opp.postedBy == myId;
  }

  bool get _isSubscriber {
    final t = (widget.user?.subscriptionTier ?? '').toLowerCase();
    return t == 'plus' || t == 'pro' || t == 'super';
  }

  bool get _isMarketingOrAdmin {
    final role = (widget.user?.role ?? '').toLowerCase();
    return role == 'marketing' || role == 'admin';
  }

  @override
  void initState() {
    super.initState();
    _opp = widget.opportunity;
    _fetchApplications();
  }

  Future<void> _fetchApplications() async {
    setState(() => _loadingApps = true);
    try {
      final apps = await OpportunityService.getOpportunityApplications(_opp.id ?? '');
      if (mounted) {
        setState(() {
          _applications = apps;
          _loadingApps = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingApps = false);
    }
  }

  Future<void> _handleReview(OpportunityApplicationModel app, String decision) async {
    final isApprove = decision == 'approve';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isApprove ? 'Setujui Pelamar?' : 'Tolak Pelamar?'),
        content: Text(
          isApprove
              ? 'Anda akan menyetujui ${app.creator?.name ?? "kreator"} untuk proyek ini.'
              : 'Anda akan menolak lamaran dari ${app.creator?.name ?? "kreator"}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isApprove ? Colors.green.shade700 : Colors.red.shade700,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isApprove ? 'Ya, Setujui' : 'Ya, Tolak',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _actionLoading = true);
    try {
      final res = await OpportunityService.reviewApplication(
        applicationId: app.id,
        decision: decision,
        reason: isApprove ? null : 'Kuota belum sesuai atau profil belum memenuhi syarat.',
      );

      if (mounted) {
        if (res['status'] == true) {
          AppSnackbar.success(
            context,
            isApprove
                ? '${app.creator?.name ?? "Pelamar"} berhasil disetujui!'
                : 'Lamaran telah ditolak.',
          );
          await _fetchApplications();
        } else {
          AppSnackbar.error(context, res['message'] ?? 'Gagal memproses lamaran.');
        }
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _openChatWithUser(String userId, String? name) async {
    try {
      final result = await ChatService.startPersonalChat(userId);
      if (!mounted) return;
      final chatData = result['data'];
      if (chatData != null && chatData['id'] != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DirectMessageScreen(chatId: chatData['id'].toString()),
          ),
        );
      } else {
        AppSnackbar.info(context, 'Membuka chat...');
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DirectMessageScreen()),
        );
      }
    } catch (_) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DirectMessageScreen()),
        );
      }
    }
  }

  Future<void> _handleStartEvent() async {
    final approvedCount = _applications.where((a) => a.isApproved).length;
    if (approvedCount == 0 && _opp.approvedCreators.isEmpty) {
      AppSnackbar.warning(
        context,
        'Belum ada kreator yang disetujui! Setujui minimal 1 pelamar sebelum memulai acara.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.play_circle_fill_rounded, color: Colors.green),
            SizedBox(width: 8),
            Text('Mulai Acara Sekarang?'),
          ],
        ),
        content: const Text(
          'Status proyek akan diubah menjadi "Sedang Berlangsung".\n\n'
          '• Pendaftaran bagi kreator lain akan ditutup secara otomatis.\n'
          '• Proyek tetap dapat dilihat oleh kreator lain di feed eksplorasi.\n'
          '• Nama-nama kreator yang diterima dan berpartisipasi akan ditampilkan secara publik.\n'
          '• Anda dapat memantau dan memperbarui progress acara.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Mulai Acara', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _actionLoading = true);
    try {
      final res = await OpportunityService.startEvent(_opp.id ?? '');
      if (mounted) {
        if (res['status'] == true && res['data'] != null) {
          setState(() {
            _opp = res['data'] as OpportunityModel;
          });
          AppSnackbar.success(context, 'Acara resmi dimulai! Pendaftaran pelamar baru ditutup.');
          await _fetchApplications();
        } else {
          AppSnackbar.error(context, res['message'] ?? 'Gagal memulai acara.');
        }
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _handleUpdateProgress(int progress) async {
    setState(() => _actionLoading = true);
    try {
      final res = await OpportunityService.updateProgress(_opp.id ?? '', progress);
      if (mounted) {
        if (res['status'] == true && res['data'] != null) {
          setState(() {
            _opp = res['data'] as OpportunityModel;
          });
          AppSnackbar.success(context, 'Progress acara berhasil diperbarui ke $progress%!');
        } else {
          AppSnackbar.error(context, res['message'] ?? 'Gagal memperbarui progress.');
        }
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _handleMarketingConfirm() async {
    final notesCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Konfirmasi MoU & Dana Diterima'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sebagai Tim Marketing / Admin Kreavana, konfirmasikan bahwa dokumen MoU hitam di atas putih telah ditandatangani dan dana proyek (>= 20 Jt) telah diterima secara sah.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Catatan Verifikasi Marketing',
                hintText: 'Misal: Dokumen MoU No. 042/MoU/2026 telah ditandatangani di Kantor Sudirman.',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Konfirmasi & Setujui', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _actionLoading = true);
    try {
      final res = await OpportunityService.confirmOpportunityPayment(
        opportunityId: _opp.id ?? '',
        notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
      );
      if (mounted) {
        if (res['status'] == true) {
          AppSnackbar.success(context, 'Status MoU dan penerimaan dana telah diverifikasi oleh Marketing!');
          final oppRes = await OpportunityService.getOpportunityById(_opp.id ?? '');
          if (oppRes != null) {
            setState(() => _opp = oppRes);
          }
        } else {
          AppSnackbar.error(context, res['message'] ?? 'Gagal konfirmasi.');
        }
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _handleSubmitDeliverable(OpportunityApplicationModel app) async {
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kirim Dokumen / Link Kerja'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Judul Dokumen / File',
                hintText: 'Misal: Draft Foto High-Res / Rundown Acara',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'Link / URL (Google Drive, Figma, Dropbox)',
                hintText: 'https://drive.google.com/...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Catatan Tambahan (Opsional)',
                hintText: 'Akses link telah dibuka untuk siapa saja yang memiliki tautan...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty || urlCtrl.text.trim().isEmpty) {
                AppSnackbar.error(ctx, 'Judul dan URL link wajib diisi.');
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Kirim', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result != true) return;

    setState(() => _actionLoading = true);
    try {
      final res = await OpportunityService.submitDocuments(
        applicationId: app.id,
        documents: [
          {
            'title': titleCtrl.text.trim(),
            'url': urlCtrl.text.trim(),
            'notes': notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
          }
        ],
      );

      if (mounted) {
        if (res['status'] == true) {
          AppSnackbar.success(context, 'Dokumen / link berhasil dikirimkan!');
          await _fetchApplications();
        } else {
          AppSnackbar.error(context, res['message'] ?? 'Gagal mengirimkan dokumen.');
        }
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  int _computeAiScore(OpportunityApplicationModel app) {
    int score = 65;
    final rating = app.creator?.rating ?? 4.5;
    score += ((rating / 5.0) * 18).round();
    if (app.creator?.isUpgraded == true) score += 10;
    if (app.creator?.isVerified == true) score += 5;
    final completed = app.creator?.completedProjectsCount ?? 0;
    if (completed >= 5) score += 2;
    return score.clamp(50, 99);
  }

  Future<void> _handleScheduleMeeting() async {
    final dateCtrl = TextEditingController(text: _opp.meetingDate ?? '');
    final timeCtrl = TextEditingController(text: _opp.meetingTime ?? '14:00 WIB');
    final locCtrl = TextEditingController(text: _opp.meetingLocation ?? 'Kantor Kreavana Creative Hub');
    final notesCtrl = TextEditingController(text: _opp.meetingNotes ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.handshake_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Atur Jadwal Pertemuan MoU'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pertemuan tatap muka bersama perwakilan Kreavana untuk penandatanganan berkas MoU hitam di atas putih proyek >= Rp 20.000.000.',
                style: TextStyle(fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: dateCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tanggal Pertemuan (YYYY-MM-DD)',
                  hintText: '2026-10-05',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: timeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Waktu Pertemuan',
                  hintText: '14:00 WIB',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.access_time_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locCtrl,
                decoration: const InputDecoration(
                  labelText: 'Lokasi Pertemuan (Kantor / Pick Map)',
                  hintText: 'Kreavana Creative Hub, Jakarta Selatan',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.place_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Catatan Khusus (Opsional)',
                  hintText: 'Membawa draft dokumen pengadaan fisik...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
            onPressed: () {
              if (dateCtrl.text.trim().isEmpty) {
                AppSnackbar.error(ctx, 'Tanggal pertemuan wajib diisi.');
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Simpan Jadwal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result != true) return;

    setState(() => _actionLoading = true);
    try {
      final res = await OpportunityService.scheduleMeeting(
        opportunityId: _opp.id ?? '',
        meetingDate: dateCtrl.text.trim(),
        meetingTime: timeCtrl.text.trim().isNotEmpty ? timeCtrl.text.trim() : '14:00 WIB',
        meetingLocation: locCtrl.text.trim().isNotEmpty ? locCtrl.text.trim() : 'Kantor Kreavana Creative Hub',
        meetingNotes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
      );
      if (mounted) {
        if (res['status'] == true && res['data'] != null) {
          setState(() {
            _opp = res['data'] as OpportunityModel;
          });
          AppSnackbar.success(context, 'Jadwal pertemuan MoU berhasil diagendakan!');
        } else {
          AppSnackbar.error(context, res['message'] ?? 'Gagal menjadwalkan pertemuan.');
        }
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _handleUpdateBanner() async {
    final urlCtrl = TextEditingController(text: _opp.bannerUrl ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ganti / Pasang Banner Acara'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Masukkan tautan gambar URL banner acara atau pilih salah satu preset resmi.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'URL Gambar Banner',
                  hintText: 'https://images.unsplash.com/...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Preset Banner Cepat:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ActionChip(
                    label: const Text('Konser Musik'),
                    onPressed: () => urlCtrl.text = 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=1200&q=80',
                  ),
                  ActionChip(
                    label: const Text('Marathon 10Km'),
                    onPressed: () => urlCtrl.text = 'https://images.unsplash.com/photo-1452626038306-9aae5e071dd3?w=1200&q=80',
                  ),
                  ActionChip(
                    label: const Text('Pameran Kreatif'),
                    onPressed: () => urlCtrl.text = 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=1200&q=80',
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
            child: const Text('Simpan Banner', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result != true || urlCtrl.text.trim().isEmpty) return;

    setState(() {
      _opp = _opp.copyWith(bannerUrl: urlCtrl.text.trim());
    });
    if (mounted) {
      AppSnackbar.success(context, 'Banner acara berhasil diperbarui!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 960;

    final filteredApps = _applications.where((a) {
      if (_selectedFilter == 'Semua') return true;
      return a.status.toLowerCase() == _selectedFilter.toLowerCase();
    }).toList();

    final content = Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0D15) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Detail Kebutuhan Proyek',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF14121F) : Colors.white,
        foregroundColor: theme.colorScheme.onSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Kembali',
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Muat Ulang Pelamar',
            onPressed: _loadingApps ? null : _fetchApplications,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32 : 16,
              vertical: isDesktop ? 28 : 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Breadcrumbs ──
                AppBreadcrumbs(
                  items: [
                    BreadcrumbItem(
                      label: 'Proyek Saya',
                      icon: Icons.folder_outlined,
                      onTap: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProyekSayaScreen(user: widget.user),
                            ),
                          );
                        }
                      },
                    ),
                    const BreadcrumbItem(
                      label: 'Detail Kebutuhan',
                      icon: Icons.assignment_outlined,
                    ),
                    BreadcrumbItem(
                      label: _opp.title,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ── Hero Header Card ──
                _buildHeroHeader(isDark),
                const SizedBox(height: 24),

                // ── Event Progress Milestone Tracker (if in progress or completed) ──
                if (_opp.isOngoing || _opp.eventProgress > 0) ...[
                  _buildEventProgressCard(isDark),
                  const SizedBox(height: 24),
                ],

                // ── Escrow (<20 Jt) or Legal MoU Meeting (>=20 Jt) Card ──
                _buildHighValueMoUCard(isDark),
                const SizedBox(height: 24),

                // ── 2-Column Responsive Layout on Desktop ──
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: AI Recommendations + Applications + Description (62%)
                      Expanded(
                        flex: 62,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isOwner) ...[
                              _buildAiRecommendationsSection(isDark),
                              const SizedBox(height: 24),
                              _buildApplicationsSection(filteredApps, isDark),
                              const SizedBox(height: 24),
                            ],
                            _buildDescriptionSection(isDark),
                            const SizedBox(height: 24),
                            _buildRequirementsSection(isDark),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),

                      // Right Column: Project Info & Summary (38%)
                      Expanded(
                        flex: 38,
                        child: Column(
                          children: [
                            _buildProjectInfoCard(isDark),
                            const SizedBox(height: 20),
                            _buildOwnerCard(isDark),
                            if (_opp.approvedCreators.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              _buildApprovedCreatorsCard(isDark),
                            ],
                          ],
                        ),
                      ),
                    ],
                  )
                else ...[
                  // Mobile Single Column
                  if (_isOwner) ...[
                    _buildAiRecommendationsSection(isDark),
                    const SizedBox(height: 20),
                    _buildApplicationsSection(filteredApps, isDark),
                    const SizedBox(height: 20),
                  ],
                  _buildProjectInfoCard(isDark),
                  const SizedBox(height: 20),
                  _buildDescriptionSection(isDark),
                  const SizedBox(height: 20),
                  _buildRequirementsSection(isDark),
                  const SizedBox(height: 20),
                  _buildOwnerCard(isDark),
                  if (_opp.approvedCreators.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildApprovedCreatorsCard(isDark),
                  ],
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );

    if (isDesktop && widget.user != null) {
      return DesktopSidebarLayout(
        user: widget.user!,
        activeRoute: 'proyek_saya',
        child: content,
      );
    }

    return content;
  }

  // ── Hero Header ─────────────────────────────────────────────────────────────
  Widget _buildHeroHeader(bool isDark) {
    final hasBanner = _opp.effectiveBannerUrl.isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161426) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Optional Banner Image ──
          if (hasBanner)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
              child: Stack(
                children: [
                  Image.network(
                    _opp.effectiveBannerUrl,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.photo_size_select_actual_rounded, size: 13, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                'Banner Acara Resmi',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (_isOwner)
                          TextButton.icon(
                            onPressed: _handleUpdateBanner,
                            icon: const Icon(Icons.edit_outlined, size: 14, color: Colors.white),
                            label: const Text('Ganti Banner', style: TextStyle(color: Colors.white, fontSize: 11)),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.black.withValues(alpha: 0.5),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Status Badge
                    if (_opp.isOngoing)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_circle_fill_rounded, size: 12, color: Color(0xFF059669)),
                            SizedBox(width: 5),
                            Text(
                              'SEDANG BERLANGSUNG',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF059669),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _opp.status == 'open'
                              ? const Color(0xFF10B981).withValues(alpha: 0.12)
                              : Colors.grey.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _opp.status == 'open' ? 'MENCARI KREATOR' : _opp.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _opp.status == 'open'
                                ? const Color(0xFF059669)
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),

                    // SubRole Category Chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.category_rounded, size: 13, color: AppTheme.primaryPurple),
                          const SizedBox(width: 5),
                          Text(
                            _opp.subRoleLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryPurple,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Duration Display Chip
                    if (_opp.durationDisplay.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.date_range_rounded, size: 13, color: Colors.blue),
                            const SizedBox(width: 5),
                            Text(
                              _opp.durationDisplay,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const Spacer(),
                    if (_opp.createdAt != null && _opp.createdAt!.isNotEmpty)
                      Text(
                        'Dibuat: ${_opp.createdAt!.substring(0, 10)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Title & Action Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _opp.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (_isOwner && !_opp.isOngoing && _opp.status == 'open')
                      ElevatedButton.icon(
                        onPressed: _actionLoading ? null : _handleStartEvent,
                        icon: const Icon(Icons.play_arrow_rounded, size: 18, color: Colors.white),
                        label: const Text(
                          'Mulai Acara',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                  ],
                ),

                if (_opp.isOngoing) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_clock_rounded, size: 16, color: Color(0xFF059669)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Acara sedang berlangsung. Pendaftaran pelamar baru telah ditutup, namun proyek tetap dapat dilihat publik beserta tim kreator yang berpartisipasi.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Applications Manager Section (In-Place!) ───────────────────────────────
  Widget _buildApplicationsSection(
    List<OpportunityApplicationModel> apps,
    bool isDark,
  ) {
    final total = _applications.length;
    final pendingCount = _applications.where((a) => a.isPending).length;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161426) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.people_alt_rounded,
                  color: AppTheme.primaryPurple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kelola & Persetujuan Pelamar',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      pendingCount > 0
                          ? '$pendingCount proposal menunggu persetujuan Anda'
                          : 'Total $total pelamar telah mengajukan proposal',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$total Pelamar',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('Semua', total),
                const SizedBox(width: 8),
                _filterChip('Menunggu', _applications.where((a) => a.isPending).length, filterKey: 'pending'),
                const SizedBox(width: 8),
                _filterChip('Disetujui', _applications.where((a) => a.isApproved).length, filterKey: 'approved'),
                const SizedBox(width: 8),
                _filterChip('Ditolak', _applications.where((a) => a.isRejected).length, filterKey: 'rejected'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Applications List
          if (_loadingApps)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (apps.isEmpty)
            _buildEmptyApplicationsState(isDark)
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: apps.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                return _buildApplicationCard(apps[index], isDark);
              },
            ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, int count, {String? filterKey}) {
    final key = filterKey ?? label;
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      selectedColor: AppTheme.primaryPurple.withValues(alpha: 0.16),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? AppTheme.primaryPurple : null,
      ),
      onSelected: (_) => setState(() => _selectedFilter = key),
    );
  }

  Widget _buildEmptyApplicationsState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF9FAFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_search_rounded,
              size: 28,
              color: AppTheme.primaryPurple,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Belum Ada Pelamar Masuk',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              'Kebutuhan proyek Anda sedang dipublikasikan di feed Kreavana. Begitu ada kreator yang mengajukan proposal, Anda dapat mereview dan memilihnya langsung di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationCard(OpportunityApplicationModel app, bool isDark) {
    Color statusBg;
    Color statusColor;
    String statusText;

    if (app.isApproved) {
      statusBg = const Color(0xFF10B981).withValues(alpha: 0.12);
      statusColor = const Color(0xFF059669);
      statusText = 'DISETUJUI';
    } else if (app.isRejected) {
      statusBg = Colors.red.withValues(alpha: 0.12);
      statusColor = Colors.red.shade700;
      statusText = 'DITOLAK';
    } else {
      statusBg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
      statusColor = const Color(0xFFD97706);
      statusText = 'MENUNGGU REVIEW';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B192A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: app.isApproved
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : (isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    if (app.creator?.id.isNotEmpty == true) {
                      UserProfileModal.show(
                        context,
                        userId: app.creator!.id,
                        initialName: app.creator!.name,
                        initialUsername: app.creator!.username,
                        initialAvatarUrl: app.creator!.avatarUrl,
                        initialRole: 'creator',
                        currentUser: widget.user,
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.15),
                          backgroundImage: app.creator?.avatarUrl != null
                              ? CachedNetworkImageProvider(app.creator!.avatarUrl!)
                              : null,
                          child: app.creator?.avatarUrl == null
                              ? Text(
                                  (app.creator?.name.isNotEmpty == true)
                                      ? app.creator!.name[0].toUpperCase()
                                      : 'K',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      app.creator?.name ?? 'Kreator',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.open_in_new_rounded, size: 12, color: AppTheme.primaryPurple),
                                ],
                              ),
                              Row(
                                children: [
                                  if (app.creator?.username.isNotEmpty == true)
                                    Text(
                                      '@${app.creator!.username} • ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                                      ),
                                    ),
                                  if (app.creator?.isUpgraded == true) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        (app.creator?.subscriptionTier ?? 'PRO').toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.amber,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  if (app.creator?.isVerified == true) ...[
                                    const Icon(Icons.verified_rounded, size: 13, color: Color(0xFF06B6D4)),
                                    const SizedBox(width: 4),
                                  ],
                                  Flexible(
                                    child: Text(
                                      app.subRoleSlug.replaceAll('_', ' '),
                                      style: const TextStyle(fontSize: 12, color: AppTheme.primaryPurple, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Proposal Pitch Message
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13111E) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Proposal Pelamar:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  app.pitchMessage.isNotEmpty ? app.pitchMessage : 'Tidak ada pesan pengantar.',
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                if (app.questionsNotes != null && app.questionsNotes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Catatan / Pertanyaan: ${app.questionsNotes}',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.blue.shade300 : Colors.blue.shade800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Bid Price & Action Buttons Row
          Row(
            children: [
              if (app.bidPrice != null && app.bidPrice! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.payments_rounded, size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      Text(
                        'Tawaran: Rp ${app.bidPrice!.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),

              // Portofolio button
              if (app.creator?.id.isNotEmpty == true) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    UserProfileModal.show(
                      context,
                      userId: app.creator!.id,
                      initialName: app.creator!.name,
                      initialUsername: app.creator!.username,
                      initialAvatarUrl: app.creator!.avatarUrl,
                      initialRole: 'creator',
                      currentUser: widget.user,
                    );
                  },
                  icon: const Icon(Icons.person_search_rounded, size: 14),
                  label: const Text('Portofolio'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    foregroundColor: AppTheme.primaryPurple,
                    side: BorderSide(color: AppTheme.primaryPurple.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Chat button
              if (app.creator?.id.isNotEmpty == true)
                OutlinedButton.icon(
                  onPressed: () => _openChatWithUser(app.creator!.id, app.creator?.name),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                  label: const Text('Chat'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),

              // Action buttons if pending
              if (app.isPending) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _actionLoading ? null : () => _handleReview(app, 'reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Tolak'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _actionLoading ? null : () => _handleReview(app, 'approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'Setujui Pelamar',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),

          // Submitted Documents / Deliverables Section (for approved applicants)
          if (app.isApproved) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13111E) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.folder_shared_rounded, size: 16, color: AppTheme.primaryPurple),
                      const SizedBox(width: 6),
                      const Text(
                        'Dokumen & Link Hasil Kerja Pelamar:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (widget.user?.id == app.creatorId || _isOwner)
                        TextButton.icon(
                          onPressed: () => _handleSubmitDeliverable(app),
                          icon: const Icon(Icons.add_link_rounded, size: 14),
                          label: const Text('Kirim Dokumen / Link', style: TextStyle(fontSize: 11)),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primaryPurple,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                        ),
                    ],
                  ),
                  if (app.submittedDocuments.isEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Belum ada link atau dokumen yang diunggah oleh pelamar.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    ...app.submittedDocuments.map((doc) {
                      final title = doc['title'] ?? 'Dokumen / Tautan';
                      final url = doc['url'] ?? '';
                      final notes = doc['notes'] ?? '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1B33) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.link_rounded, size: 16, color: Color(0xFF06B6D4)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  if (url.isNotEmpty)
                                    InkWell(
                                      onTap: () async {
                                        final uri = Uri.tryParse(url);
                                        if (uri != null && await canLaunchUrl(uri)) {
                                          await launchUrl(uri);
                                        } else if (context.mounted) {
                                          AppSnackbar.info(context, 'Tautan: $url');
                                        }
                                      },
                                      child: Text(
                                        url,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF2563EB),
                                          decoration: TextDecoration.underline,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  if (notes.isNotEmpty)
                                    Text(
                                      'Catatan: $notes',
                                      style: TextStyle(fontSize: 10.5, color: isDark ? AppTheme.textMuted : Colors.grey.shade600),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Description Section ─────────────────────────────────────────────────────
  Widget _buildDescriptionSection(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161426) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Deskripsi Kebutuhan & Ruang Lingkup',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            _opp.description != null && _opp.description!.trim().isNotEmpty
                ? _opp.description!
                : 'Tidak ada rincian deskripsi tambahan yang dicantumkan.',
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDark ? Colors.white70 : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  // ── Requirements Chips ──────────────────────────────────────────────────────
  Widget _buildRequirementsSection(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161426) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Peran & Spesialisasi yang Dibutuhkan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_opp.requirements.isNotEmpty)
            Column(
              children: _opp.requirements.map((r) {
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1B192A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 18, color: AppTheme.primaryPurple),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              r.label,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      if (r.tags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: r.tags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#$tag',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryPurple,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            )
          else
            Chip(
              avatar: const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.primaryPurple),
              label: Text(_opp.subRoleLabel),
              backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.08),
            ),
        ],
      ),
    );
  }

  // ── Sidebar: Project Info Card ──────────────────────────────────────────────
  Widget _buildProjectInfoCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161426) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ringkasan Proyek',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _infoItem(
            icon: Icons.calendar_today_rounded,
            iconColor: const Color(0xFFF59E0B),
            label: 'Jadwal & Batas Waktu',
            value: _opp.eventDate != null
                ? '${_opp.eventDate} ${_opp.eventStartTime != null ? "(${_opp.eventStartTime} - ${_opp.eventEndTime ?? ''})" : ""}'
                : (_opp.deadline ?? 'Fleksibel'),
            isDark: isDark,
          ),
          const Divider(height: 20),
          _infoItem(
            icon: Icons.place_rounded,
            iconColor: const Color(0xFF06B6D4),
            label: 'Lokasi Event / Eksekusi',
            value: _opp.address ?? _opp.location ?? 'Indonesia (Online / Fleksibel)',
            isDark: isDark,
          ),
          const Divider(height: 20),
          _infoItem(
            icon: Icons.payments_rounded,
            iconColor: const Color(0xFF10B981),
            label: 'Perkiraan Budget',
            value: _opp.budgetRange ?? 'Sesuai Kesepakatan',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _infoItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Sidebar: Owner Card ─────────────────────────────────────────────────────
  Widget _buildOwnerCard(bool isDark) {
    final poster = _opp.poster;
    final name = poster?.name.isNotEmpty == true ? poster!.name : (widget.user?.name ?? 'Pembuat Proyek');
    final username = poster?.username.isNotEmpty == true ? poster!.username : (widget.user?.username ?? 'client');
    final userId = poster?.id ?? _opp.postedBy ?? widget.user?.id ?? '';
    final role = poster?.role ?? (widget.user?.id == userId ? widget.user?.role ?? 'user' : 'user');
    final isVerified = poster?.isVerified == true ||
        (widget.user?.id == userId && widget.user?.isVerified == true);
    final avatarUrl = poster?.avatarUrl ?? (widget.user?.id == userId ? widget.user?.avatarUrl : null);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (userId.isNotEmpty) {
            UserProfileModal.show(
              context,
              userId: userId,
              initialName: name,
              initialUsername: username,
              initialAvatarUrl: avatarUrl,
              initialRole: role,
              currentUser: widget.user,
            );
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161426) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    role == 'creator' ? 'Pemilik Proyek (Kreator)' : 'Pemilik Proyek (Klien)',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Lihat Profil',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 15,
                        color: AppTheme.primaryPurple,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: (role == 'creator'
                                ? const Color(0xFF10B981)
                                : const Color(0xFF2563EB))
                            .withValues(alpha: 0.15),
                        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: (avatarUrl == null || avatarUrl.isEmpty)
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'K',
                                style: TextStyle(
                                  color: role == 'creator'
                                      ? const Color(0xFF059669)
                                      : const Color(0xFF1D4ED8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              )
                            : null,
                      ),
                      if (isVerified)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: VerificationBadge(
                            role: role,
                            isVerified: isVerified,
                            size: VerificationBadgeSize.small,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            VerificationBadge(
                              role: role,
                              isVerified: isVerified,
                              size: VerificationBadgeSize.small,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '@$username',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: (role == 'creator'
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF2563EB))
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                role == 'creator' ? 'Kreator' : 'Klien',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: role == 'creator'
                                      ? const Color(0xFF059669)
                                      : const Color(0xFF1D4ED8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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

  // ── Sidebar: Approved Creators ──────────────────────────────────────────────
  Widget _buildApprovedCreatorsCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_rounded, size: 18, color: Color(0xFF059669)),
              SizedBox(width: 8),
              Text(
                'Kreator Terpilih & Diterima',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF059669),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._opp.approvedCreators.map((c) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundImage: c.avatarUrl != null ? CachedNetworkImageProvider(c.avatarUrl!) : null,
                    child: c.avatarUrl == null
                        ? Text(
                            c.name.isNotEmpty ? c.name[0].toUpperCase() : 'K',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      c.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  Text(
                    c.subRole ?? 'Kreator',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey.shade700),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── AI Recommendations Section ─────────────────────────────────────────────
  Widget _buildAiRecommendationsSection(bool isDark) {
    final subRoles = <String>{'Semua'};
    for (final req in _opp.requirements) {
      if (req.subRoleSlug.isNotEmpty) subRoles.add(req.subRoleSlug);
    }
    for (final app in _applications) {
      if (app.subRoleSlug.isNotEmpty) subRoles.add(app.subRoleSlug);
    }

    final candidateApps = _applications.where((a) {
      if (a.isRejected) return false;
      if (_aiFilterSubRole == 'Semua') return true;
      return a.subRoleSlug.toLowerCase() == _aiFilterSubRole.toLowerCase();
    }).toList();

    candidateApps.sort((a, b) => _computeAiScore(b).compareTo(_computeAiScore(a)));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161426) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Rekomendasi AI Pelamar',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'AI MATCHMAKER',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF8B5CF6),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Peringkat kecocokan berdasarkan ulasan/rating, reputasi portfolio, & status langganan kreator.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // SubRole Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: subRoles.map((role) {
                final isSelected = _aiFilterSubRole == role;
                final label = role == 'Semua' ? 'Semua Kategori' : role.replaceAll('_', ' ').toUpperCase();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        _aiFilterSubRole = role;
                      });
                    },
                    selectedColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                    backgroundColor: isDark ? const Color(0xFF1E1B33) : const Color(0xFFF1F5F9),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? const Color(0xFF8B5CF6) : (isDark ? Colors.white70 : Colors.black87),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF8B5CF6) : Colors.transparent,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          if (!_isSubscriber) ...[
            // Upsell card for non-subscribers
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                    const Color(0xFFEC4899).withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.lock_person_rounded, size: 36, color: Color(0xFF8B5CF6)),
                  const SizedBox(height: 10),
                  const Text(
                    'Buka Rekomendasi Pelamar by AI',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Upgrade akun Anda ke Plus, Pro, atau Super untuk membuka sistem kecocokan AI otomatis yang menyaring dan merekomendasikan pelamar terbaik berdasarkan rating, portofolio, dan rekam jejak.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () => UpgradePlanModal.show(context, user: widget.user),
                    icon: const Icon(Icons.star_rounded, size: 16, color: Colors.white),
                    label: const Text(
                      'Upgrade ke Plus / Pro / Super',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (candidateApps.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF9FAFD),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  'Belum ada pelamar untuk kategori "$_aiFilterSubRole" saat ini.',
                  style: TextStyle(fontSize: 13, color: isDark ? AppTheme.textMuted : Colors.grey.shade600),
                ),
              ),
            ),
          ] else ...[
            // Ranked Applicants List
            Column(
              children: candidateApps.take(3).map((app) {
                final score = _computeAiScore(app);
                final creator = app.creator;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1B192A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: score >= 85
                          ? const Color(0xFF8B5CF6).withValues(alpha: 0.35)
                          : (isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundImage: creator?.avatarUrl != null
                                ? CachedNetworkImageProvider(creator!.avatarUrl!)
                                : null,
                            child: creator?.avatarUrl == null
                                ? Text(
                                    creator?.name.isNotEmpty == true ? creator!.name[0].toUpperCase() : 'K',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        creator?.name ?? 'Kreator',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    if (creator?.isUpgraded == true)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          (creator?.subscriptionTier ?? 'PRO').toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.amber,
                                          ),
                                        ),
                                      ),
                                    if (creator?.isVerified == true) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF06B6D4)),
                                    ],
                                  ],
                                ),
                                Text(
                                  app.subRoleSlug.replaceAll('_', ' '),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryPurple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome, size: 11, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  '$score% Cocok',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // AI Highlights
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _aiHighlightChip(
                            icon: Icons.star_rounded,
                            label: 'Rating ${creator?.rating ?? 4.8} / 5.0',
                            color: Colors.amber,
                          ),
                          if (creator?.isUpgraded == true)
                            _aiHighlightChip(
                              icon: Icons.workspace_premium_rounded,
                              label: 'Member Prioritas Kreavana',
                              color: const Color(0xFF8B5CF6),
                            ),
                          if (creator?.isVerified == true)
                            _aiHighlightChip(
                              icon: Icons.shield_rounded,
                              label: 'Terverifikasi KTP & Portofolio',
                              color: const Color(0xFF10B981),
                            ),
                          if (app.bidPrice != null && app.bidPrice! > 0)
                            _aiHighlightChip(
                              icon: Icons.payments_outlined,
                              label: 'Tawaran: Rp ${app.bidPrice!.toStringAsFixed(0)}',
                              color: const Color(0xFF059669),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (creator?.id.isNotEmpty == true) ...[
                            TextButton.icon(
                              onPressed: () {
                                UserProfileModal.show(
                                  context,
                                  userId: creator!.id,
                                  initialName: creator.name,
                                  initialUsername: creator.username,
                                  initialAvatarUrl: creator.avatarUrl,
                                  initialRole: 'creator',
                                  currentUser: widget.user,
                                );
                              },
                              icon: const Icon(Icons.person_search_rounded, size: 14),
                              label: const Text('Portofolio'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primaryPurple,
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (app.isPending)
                            ElevatedButton(
                              onPressed: _actionLoading ? null : () => _handleReview(app, 'approve'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text(
                                'Setujui',
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _aiHighlightChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Event Progress Milestone Tracker ───────────────────────────────────────
  Widget _buildEventProgressCard(bool isDark) {
    final progress = _opp.eventProgress;
    final approvedList = _applications.where((a) => a.isApproved).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161426) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: Color(0xFF059669),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Progress & Pelaksanaan Acara',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _opp.isOngoing
                          ? 'Acara sedang berlangsung • Pendaftaran kreator baru telah ditutup.'
                          : 'Proyek dalam status: ${_opp.status.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$progress% Selesai',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Milestone Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (progress / 100.0).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: isDark ? const Color(0xFF252238) : const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
            ),
          ),
          const SizedBox(height: 12),

          // Milestones Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _milestoneStep('Persiapan (30%)', progress >= 30, isDark),
              _milestoneStep('Pelaksanaan (70%)', progress >= 70, isDark),
              _milestoneStep('Selesai (100%)', progress >= 100, isDark),
            ],
          ),

          if (_isOwner) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Perbarui Tahapan Progress:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
                  ),
                ),
                const Spacer(),
                Wrap(
                  spacing: 6,
                  children: [
                    _progressUpdateBtn(30, '30% Briefing'),
                    _progressUpdateBtn(70, '70% Event'),
                    _progressUpdateBtn(100, '100% Selesai'),
                  ],
                ),
              ],
            ),
          ],

          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 12),

          // Participating Creators
          Row(
            children: [
              const Icon(Icons.groups_rounded, size: 18, color: Color(0xFF059669)),
              const SizedBox(width: 8),
              Text(
                'Kreator yang Berpartisipasi (${approvedList.length + _opp.approvedCreators.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (approvedList.isEmpty && _opp.approvedCreators.isEmpty)
            Text(
              'Belum ada nama kreator yang disetujui.',
              style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMuted : Colors.grey.shade600),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...approvedList.map((app) {
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundImage: app.creator?.avatarUrl != null
                          ? CachedNetworkImageProvider(app.creator!.avatarUrl!)
                          : null,
                      child: app.creator?.avatarUrl == null
                          ? Text(
                              app.creator?.name.isNotEmpty == true ? app.creator!.name[0].toUpperCase() : 'K',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    label: Text('${app.creator?.name ?? "Kreator"} (${app.subRoleSlug.replaceAll('_', ' ')})'),
                    backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                    side: const BorderSide(color: Color(0xFF10B981), width: 0.5),
                  );
                }),
                ..._opp.approvedCreators.map((c) {
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundImage: c.avatarUrl != null ? CachedNetworkImageProvider(c.avatarUrl!) : null,
                      child: c.avatarUrl == null
                          ? Text(
                              c.name.isNotEmpty ? c.name[0].toUpperCase() : 'K',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    label: Text('${c.name} (${c.subRole ?? "Kreator"})'),
                    backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                    side: const BorderSide(color: Color(0xFF10B981), width: 0.5),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  Widget _milestoneStep(String label, bool reached, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          reached ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 14,
          color: reached ? const Color(0xFF059669) : (isDark ? Colors.white30 : Colors.grey.shade400),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: reached ? FontWeight.bold : FontWeight.normal,
            color: reached
                ? (isDark ? Colors.white : Colors.black87)
                : (isDark ? AppTheme.textMuted : Colors.grey.shade600),
          ),
        ),
      ],
    );
  }

  Widget _progressUpdateBtn(int target, String label) {
    return OutlinedButton(
      onPressed: _actionLoading ? null : () => _handleUpdateProgress(target),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        side: const BorderSide(color: Color(0xFF059669)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
      ),
    );
  }

  // ── High-Value MoU & Escrow Protocol Card ──────────────────────────────────
  Widget _buildHighValueMoUCard(bool isDark) {
    final isLarge = _opp.isLargeTransaction;

    if (!isLarge) {
      // Standard Escrow Protection Card (< 20 Jt)
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161426) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF06B6D4).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.security_rounded,
                color: Color(0xFF06B6D4),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text(
                        'Escrow Rekening Bersama Kreavana',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.verified_user_rounded, size: 14, color: Color(0xFF06B6D4)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Budget proyek < Rp 20.000.000 dilindungi sistem transfer escrow otomatis. Dana tersimpan aman di rekening penampung bersama dan hanya diteruskan ke kreator setelah hasil pekerjaan Anda setujui.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
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

    // High Value MoU Card (>= 20 Jt)
    final hasMeeting = _opp.meetingDate != null && _opp.meetingDate!.isNotEmpty;
    final isMoUConfirmed = _opp.escrowStatus == 'completed';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1A2A) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.gavel_rounded,
                  color: Color(0xFFD97706),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text(
                          'Protokol Transaksi Skala Besar (>= Rp 20.000.000)',
                          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Text(
                      'Kepatuhan Hukum & Kontrak Hitam di Atas Putih Resmi Kreavana',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isMoUConfirmed ? const Color(0xFF059669) : const Color(0xFFD97706),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isMoUConfirmed ? 'MoU & DANA SAH' : 'PERLU MoU FISIK',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF171322) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppTheme.inputBorder : const Color(0xFFFDE68A),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFD97706)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Untuk mencegah sengketa hukum dan mematuhi regulasi perbankan, transaksi bernilai Rp 20 Juta ke atas tidak ditransfer langsung ke rekening biasa. Pembuat event dan tim Kreavana wajib menandatangani dokumen hitam di atas putih serta bertemu secara tatap muka.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.grey.shade800,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Meeting Details or Schedule Button
          if (hasMeeting) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13111E) : const Color(0xFFFEF3C7).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Jadwal Pertemuan MoU Terjadwal:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 15, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      Text(
                        'Tanggal: ${_opp.meetingDate}  •  Waktu: ${_opp.meetingTime ?? "14:00 WIB"}',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.place_rounded, size: 15, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Lokasi: ${_opp.meetingLocation ?? "Kantor Kreavana (Pick by Map)"}',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  if (_opp.meetingNotes != null && _opp.meetingNotes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Catatan: ${_opp.meetingNotes}',
                      style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.textMuted : Colors.grey.shade700),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Jadwal pertemuan tatap muka belum diatur oleh pembuat event.',
                    style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMuted : Colors.grey.shade700),
                  ),
                ),
                if (_isOwner)
                  ElevatedButton.icon(
                    onPressed: _actionLoading ? null : _handleScheduleMeeting,
                    icon: const Icon(Icons.edit_calendar_rounded, size: 15, color: Colors.white),
                    label: const Text('Atur Jadwal & Lokasi (Map)', style: TextStyle(color: Colors.white, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
              ],
            ),
          ],

          // Marketing Confirmation Section
          if (_isMarketingOrAdmin) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.admin_panel_settings_rounded, size: 20, color: Color(0xFFD97706)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Otorisasi Tim Marketing / Legal Kreavana',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          isMoUConfirmed
                              ? 'MoU telah sah dan uang telah diterima oleh Kreavana.'
                              : 'Klik tombol untuk mengonfirmasi penerimaan berkas MoU dan dana.',
                          style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.textMuted : Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  if (!isMoUConfirmed)
                    ElevatedButton(
                      onPressed: _actionLoading ? null : _handleMarketingConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      child: const Text(
                        'Konfirmasi Uang & MoU',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
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
