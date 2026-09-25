import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  bool _actionLoading = false;

  bool get _isOwner {
    final myId = widget.user?.id ?? '';
    return myId.isNotEmpty && _opp.postedBy != null && _opp.postedBy == myId;
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

                // ── 2-Column Responsive Layout on Desktop ──
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Applications + Description (62%)
                      Expanded(
                        flex: 62,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isOwner) ...[
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
          Text(
            _opp.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
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
                    Text(
                      app.creator?.name ?? 'Kreator',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                        Text(
                          app.subRoleSlug.replaceAll('_', ' '),
                          style: const TextStyle(fontSize: 12, color: AppTheme.primaryPurple, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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

    return Container(
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
          const Text(
            'Pemilik Proyek (Klien)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.teal.shade100,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'K',
                  style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      '@$username',
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
        ],
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
}
