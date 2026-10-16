import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../app/subrole_theme_engine.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../screens/buat_kebutuhan_screen.dart';
import '../screens/explore_screen.dart';
import '../screens/proyek_saya_screen.dart';
import '../screens/wallet_screen.dart';
import '../screens/laporan_screen.dart';
import '../screens/institution_workspace_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/agenda_screen.dart';
import '../screens/kolaborasi_screen.dart';
import '../screens/marketplace_karya_screen.dart';
import 'package:go_router/go_router.dart';
import '../services/app_router.dart';
import '../services/profile_completeness_service.dart';
import 'auth_guard_dialog.dart';

class SubRoleRightSidebar extends StatelessWidget {
  final UserModel user;
  final ValueChanged<UserModel>? onUserUpdated;
  final VoidCallback? onLogout;
  final bool isDark;

  const SubRoleRightSidebar({
    super.key,
    required this.user,
    this.onUserUpdated,
    this.onLogout,
    required this.isDark,
  });

  bool get _isGovernment {
    final sub = (user.subRole ?? '').toLowerCase().trim();
    return sub == 'government' ||
        sub == 'pemerintah' ||
        sub == 'instansi' ||
        sub == 'dinas' ||
        user.role == 'government';
  }

  bool get _isSchool {
    final sub = (user.subRole ?? '').toLowerCase().trim();
    return sub == 'institution' ||
        sub == 'institusi' ||
        sub == 'school' ||
        sub == 'education' ||
        sub == 'campus' ||
        sub == 'sekolah' ||
        sub == 'kampus' ||
        user.role == 'institution';
  }

  bool get _isCompany {
    final sub = (user.subRole ?? '').toLowerCase().trim();
    return !user.isAdmin &&
        (sub == 'company' ||
            sub == 'corporate' ||
            sub == 'business' ||
            sub == 'perusahaan' ||
            sub == 'bisnis' ||
            sub == 'b2b' ||
            user.role == 'corporate' ||
            user.role == 'company' ||
            user.username == 'corporate_demo' ||
            user.email.startsWith('corporate@'));
  }

  bool get _isCreator {
    if (_isGovernment || _isSchool || _isCompany) return false;
    return !user.isClient && (user.role == 'creator' || user.isCreator);
  }

  void _guardAndExecute(
    BuildContext context, {
    required String actionName,
    required VoidCallback action,
  }) {
    if (user.isGuest) {
      AuthGuardDialog.show(context, actionName: actionName);
      return;
    }
    action();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = SubRoleThemeEngine.getAccentColor(
      user.role,
      user.subRole,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildProfileCard(context, accentColor),
        const SizedBox(height: 16),
        _buildQuickActionsCard(context, accentColor),
        const SizedBox(height: 16),
        _buildUpcomingAgendaCard(context, accentColor),
        const SizedBox(height: 16),
        _buildAiTipsCard(context, accentColor),
        const SizedBox(height: 16),
        _buildEscrowTrustCard(context, accentColor),
        const SizedBox(height: 16),
        _buildClientHelpCard(context, accentColor),
      ],
    );
  }

  Widget _buildProfileCard(BuildContext context, Color accentColor) {
    final subRoleConfig = SubRoleThemeEngine.getConfig(user.role, user.subRole);
    final subRoleLabel = subRoleConfig.label;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: accentColor.withValues(alpha: 0.12),
                backgroundImage:
                    user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                    ? NetworkImage(ApiService.resolveAssetUrl(user.avatarUrl!))
                    : null,
                child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                    ? Icon(Icons.person, color: accentColor, size: 28)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.isGuest ? 'Mode Tamu' : subRoleLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: accentColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  if (user.isGuest) {
                    AuthGuardDialog.show(
                      context,
                      actionName: 'mengakses profil akun',
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(
                        user: user,
                        onUserUpdated: onUserUpdated ?? (_) {},
                        onLogout:
                            onLogout ??
                            () => Navigator.of(
                              context,
                            ).popUntil((r) => r.isFirst),
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: accentColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                ),
                child: Text(
                  user.isGuest ? 'Masuk' : 'Profil',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (user.isGuest) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 15, color: accentColor),
                      const SizedBox(width: 6),
                      Text(
                        'Akses Tamu Terbatas',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Masuk atau daftar akun untuk membuka profil lengkap, verifikasi identitas, dan transaksi proyek.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go(AppRoutes.login),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Masuk Sekarang',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.go(AppRoutes.register),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  side: BorderSide(
                    color: accentColor.withValues(alpha: 0.4),
                  ),
                  foregroundColor: accentColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Daftar Baru',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final completeness = ProfileCompleteness.calculate(user);
                return Column(
                  children: [
                    GestureDetector(
                      onTap: () => ProfileCompleteness.showChecklistModal(
                        context,
                        user,
                        onRefresh: () => onUserUpdated?.call(user),
                      ),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: completeness.percentage / 100.0,
                              minHeight: 7,
                              backgroundColor: accentColor.withValues(
                                alpha: 0.12,
                              ),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                accentColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Kelengkapan profil',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppTheme.textMuted
                                      : AppTheme.textMutedLight,
                                ),
                              ),
                              Text(
                                '${completeness.percentage}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => ProfileCompleteness.showChecklistModal(
                          context,
                          user,
                          onRefresh: () => onUserUpdated?.call(user),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          side: BorderSide(
                            color: accentColor.withValues(alpha: 0.4),
                          ),
                          foregroundColor: accentColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Lengkapi Profil',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(BuildContext context, Color accentColor) {
    final List<_SidebarQuickAction> actions;

    if (_isGovernment) {
      actions = [
        _SidebarQuickAction(
          icon: Icons.assignment_outlined,
          label: 'Tender LPSE',
          onTap: () => _guardAndExecute(
            context,
            actionName: 'mengakses paket tender LPSE',
            action: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InstitutionWorkspaceScreen(
                  user: user,
                  resourceType: 'tenders',
                  onUserUpdated: onUserUpdated,
                ),
              ),
            ),
          ),
        ),
        _SidebarQuickAction(
          icon: Icons.person_search_outlined,
          label: 'Cari Vendor',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExploreScreen(user: user),
            ),
          ),
        ),
        _SidebarQuickAction(
          icon: Icons.event_outlined,
          label: 'Agenda Acara',
          onTap: () => _guardAndExecute(
            context,
            actionName: 'mengakses agenda kedinasan',
            action: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AgendaScreen(user: user, onUserUpdated: onUserUpdated),
              ),
            ),
          ),
        ),
        _SidebarQuickAction(
          icon: Icons.account_balance_outlined,
          label: 'Realisasi DIPA',
          onTap: () => _guardAndExecute(
            context,
            actionName: 'mengakses realisasi anggaran DIPA',
            action: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InstitutionWorkspaceScreen(
                  user: user,
                  resourceType: 'budgets',
                  onUserUpdated: onUserUpdated,
                ),
              ),
            ),
          ),
        ),
        _SidebarQuickAction(
          icon: Icons.monitor_outlined,
          label: 'Monev Program',
          onTap: () => _guardAndExecute(
            context,
            actionName: 'mengakses monitoring dan evaluasi',
            action: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InstitutionWorkspaceScreen(
                  user: user,
                  resourceType: 'monitoring',
                  onUserUpdated: onUserUpdated,
                ),
              ),
            ),
          ),
        ),
        _SidebarQuickAction(
          icon: Icons.folder_shared_outlined,
          label: 'Dokumen BAST',
          onTap: () => _guardAndExecute(
            context,
            actionName: 'mengakses dokumen instansi & BAST',
            action: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InstitutionWorkspaceScreen(
                  user: user,
                  resourceType: 'documents',
                  onUserUpdated: onUserUpdated,
                ),
              ),
            ),
          ),
        ),
      ];
    } else if (_isSchool) {
      actions = [
        _SidebarQuickAction(
          icon: Icons.school_outlined,
          label: 'Program Magang',
          onTap: () => _guardAndExecute(
            context,
            actionName: 'mengakses program magang siswa',
            action: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProyekSayaScreen(user: user, onUserUpdated: onUserUpdated),
              ),
            ),
          ),
        ),
        _SidebarQuickAction(
          icon: Icons.palette_outlined,
          label: 'Karya Siswa',
          onTap: () => _guardAndExecute(
            context,
            actionName: 'mengakses portofolio karya siswa',
            action: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InstitutionWorkspaceScreen(
                  user: user,
                  resourceType: 'showcases',
                  onUserUpdated: onUserUpdated,
                ),
              ),
            ),
          ),
        ),
        _SidebarQuickAction(
          icon: Icons.event_outlined,
          label: 'Agenda Sekolah',
          onTap: () => _guardAndExecute(
            context,
            actionName: 'mengakses agenda sekolah',
            action: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AgendaScreen(user: user, onUserUpdated: onUserUpdated),
              ),
            ),
          ),
        ),
        _SidebarQuickAction(
          icon: Icons.diversity_3_outlined,
          label: 'Mitra Industri',
          onTap: () => _guardAndExecute(
            context,
            actionName: 'mengakses mitra industri dan sanggar',
            action: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InstitutionWorkspaceScreen(
                  user: user,
                  resourceType: 'partners',
                  onUserUpdated: onUserUpdated,
                ),
              ),
            ),
          ),
        ),
        _SidebarQuickAction(
          icon: Icons.folder_shared_outlined,
          label: 'Dokumen & MoU',
          onTap: () => _guardAndExecute(
            context,
            actionName: 'mengakses arsip dokumen & MoU',
            action: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InstitutionWorkspaceScreen(
                  user: user,
                  resourceType: 'documents',
                  onUserUpdated: onUserUpdated,
                ),
              ),
            ),
          ),
        ),
        _SidebarQuickAction(
          icon: Icons.person_search_outlined,
          label: 'Cari Vendor',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExploreScreen(user: user),
            ),
          ),
        ),
      ];
    } else if (_isCompany) {
      actions = [
        _SidebarQuickAction(
          icon: Icons.assignment_outlined,
          label: 'Tender RFP',
          onTap: () => _guardAndExecute(
            context,
            actionName: 'mengakses pengadaan & tender RFP',
            action: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InstitutionWorkspaceScreen(
                  user: user,
                  resourceType: 'tenders',
                  onUserUpdated: onUserUpdated,
                ),
              ),
            ),
          ),
        ),
        _SidebarQuickAction(
          icon: Icons.storefront_outlined,
          label: 'Cari Vendor B2B',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MarketplaceKaryaScreen(user: user, onUserUpdated: onUserUpdated),
            ),
          ),
        ),
        _SidebarQuickAction(
          icon: Icons.business_center_outlined,
          label: 'Mitra B2B',
          onTap: () => _guardAndExecute(
            context,
            actionName: 'mengakses mitra rekanan B2B',
            action: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InstitutionWorkspaceScreen(
                  user: user,
                  resourceType: 'partners',
                  onUserUpdated: onUserUpdated,
                ),
              ),
            ),
          ),
        ),
        _SidebarQuickAction(
          icon: Icons.account_balance_outlined,
          label: 'Alokasi Dana',
          onTap: () => _guardAndExecute(
            context,
            actionName: 'mengakses alokasi anggaran korporat',
            action: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InstitutionWorkspaceScreen(
                  user: user,
                  resourceType: 'budgets',
                  onUserUpdated: onUserUpdated,
                ),
              ),
            ),
          ),
        ),
        _SidebarQuickAction(
          icon: Icons.verified_outlined,
          label: 'Otorisasi PO',
          onTap: () => _guardAndExecute(
            context,
            actionName: 'mengakses otorisasi PO & MoU',
            action: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InstitutionWorkspaceScreen(
                  user: user,
                  resourceType: 'documents',
                  onUserUpdated: onUserUpdated,
                ),
              ),
            ),
          ),
        ),
        _SidebarQuickAction(
          icon: Icons.summarize_outlined,
          label: 'Laporan Audit',
          onTap: () => _guardAndExecute(
            context,
            actionName: 'mengakses laporan & audit B2B',
            action: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InstitutionWorkspaceScreen(
                  user: user,
                  resourceType: 'reports',
                  onUserUpdated: onUserUpdated,
                ),
              ),
            ),
          ),
        ),
      ];
    } else if (_isCreator) {
      actions = [
        _SidebarQuickAction(
          icon: Icons.explore_outlined,
          label: 'Cari Peluang',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExploreScreen(user: user),
            ),
          ),
        ),
        _SidebarQuickAction(
          icon: Icons.work_outline_rounded,
          label: 'Proyek Aktif',
          onTap: () => _guardAndExecute(
            context,
            actionName: 'mengakses daftar proyek aktif',
            action: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProyekSayaScreen(user: user, onUserUpdated: onUserUpdated),
              ),
            ),
          ),
        ),
        _SidebarQuickAction(
          icon: Icons.storefront_outlined,
          label: 'Jual Karya',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MarketplaceKaryaScreen(user: user, onUserUpdated: onUserUpdated),
            ),
          ),
        ),
        _SidebarQuickAction(
          icon: Icons.calendar_month_outlined,
          label: 'Atur Jadwal',
          onTap: () => _guardAndExecute(
            context,
            actionName: 'mengatur kapasitas & jadwal kerja',
            action: () => context.go(AppRoutes.kapasitasJadwal),
          ),
        ),
        _SidebarQuickAction(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Tarik Dana',
          onTap: () => _guardAndExecute(
            context,
            actionName: 'mengakses dompet & penarikan dana',
            action: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WalletScreen(user: user, onUserUpdated: onUserUpdated ?? (_) {}),
              ),
            ),
          ),
        ),
        _SidebarQuickAction(
          icon: Icons.handshake_outlined,
          label: 'Kolaborasi',
          onTap: () => _guardAndExecute(
            context,
            actionName: 'mengakses ruang kolaborasi kreator',
            action: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => KolaborasiScreen(user: user, onUserUpdated: onUserUpdated),
              ),
            ),
          ),
        ),
      ];
    } else {
      // Default: UMKM / Bisnis / Klien
      actions = [
        _SidebarQuickAction(
          icon: Icons.add_task_rounded,
          label: 'Buat Kebutuhan',
          onTap: () => _guardAndExecute(
            context,
            actionName: 'membuat kebutuhan proyek',
            action: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BuatKebutuhanScreen(user: user),
              ),
            ),
          ),
        ),
        _SidebarQuickAction(
          icon: Icons.person_search_outlined,
          label: 'Cari Kreator',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExploreScreen(user: user),
            ),
          ),
        ),
        _SidebarQuickAction(
          icon: Icons.folder_outlined,
          label: 'Proyek Saya',
          onTap: () => _guardAndExecute(
            context,
            actionName: 'mengakses daftar proyek',
            action: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProyekSayaScreen(user: user, onUserUpdated: onUserUpdated),
              ),
            ),
          ),
        ),
        _SidebarQuickAction(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Bayar DP',
          onTap: () => _guardAndExecute(
            context,
            actionName: 'mengakses dompet & pembayaran',
            action: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WalletScreen(user: user, onUserUpdated: onUserUpdated ?? (_) {}),
              ),
            ),
          ),
        ),
        _SidebarQuickAction(
          icon: Icons.calendar_today_outlined,
          label: 'Agenda Proyek',
          onTap: () => _guardAndExecute(
            context,
            actionName: 'mengakses agenda dan jadwal proyek',
            action: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AgendaScreen(user: user, onUserUpdated: onUserUpdated),
              ),
            ),
          ),
        ),
        _SidebarQuickAction(
          icon: Icons.analytics_outlined,
          label: 'Laporan',
          onTap: () => _guardAndExecute(
            context,
            actionName: 'melihat laporan transaksi & proyek',
            action: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LaporanScreen(user: user, onUserUpdated: onUserUpdated ?? (_) {}),
              ),
            ),
          ),
        ),
      ];
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aksi Cepat',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.95,
            ),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              return InkWell(
                onTap: action.onTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: isDark ? 0.12 : 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accentColor.withValues(
                        alpha: isDark ? 0.25 : 0.15,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        action.icon,
                        color: accentColor,
                        size: 22,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          action.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingAgendaCard(BuildContext context, Color accentColor) {
    final String title;
    final List<Map<String, String>> events;

    if (_isGovernment) {
      title = 'Agenda & Jadwal Kedinasan';
      events = [
        {
          'date': '18 Okt',
          'title': 'Musrenbang Ekraf & Kemitraan',
          'meta': 'R. Rapat Pemda • 09:00 WIB',
        },
        {
          'date': '22 Okt',
          'title': 'Evaluasi Teknis Vendor SPK',
          'meta': 'Tim Pokja PBJ • 13:30 WIB',
        },
        {
          'date': '28 Okt',
          'title': 'Batas Unggah LPJ & BAST',
          'meta': 'Subbag Keuangan & Aset',
        },
      ];
    } else if (_isSchool) {
      title = 'Agenda Akademik & Industri';
      events = [
        {
          'date': '19 Okt',
          'title': 'Sidang Evaluasi Magang Siswa',
          'meta': 'Lab Multimedia • 08:30 WIB',
        },
        {
          'date': '24 Okt',
          'title': 'Kunjungan Industri & Sanggar',
          'meta': 'Mitra Kreatif Daerah • 10:00 WIB',
        },
        {
          'date': '02 Nov',
          'title': 'Gelar Karya Siswa Kreatif',
          'meta': 'Aula Sekolah • Terbuka',
        },
      ];
    } else if (_isCompany) {
      title = 'Jadwal Pengadaan & Review';
      events = [
        {
          'date': '20 Okt',
          'title': 'Review Proposal Vendor RFP Q4',
          'meta': 'Boardroom A • 10:00 WIB',
        },
        {
          'date': '25 Okt',
          'title': 'Finalisasi Kontrak SPK Rekanan',
          'meta': 'Divisi Procurement • 14:00 WIB',
        },
        {
          'date': '30 Okt',
          'title': 'Rekonsiliasi Faktur Pajak B2B',
          'meta': 'Finance & Accounting',
        },
      ];
    } else if (_isCreator) {
      title = 'Agenda Kerja & Deadline';
      events = [
        {
          'date': '19 Okt',
          'title': 'Revisi Tahap II Animasi 3D',
          'meta': 'Proyek Maskot Daerah • 17:00 WIB',
        },
        {
          'date': '21 Okt',
          'title': 'Meeting Brief Klien PT Citra',
          'meta': 'Online Call • 11:00 WIB',
        },
        {
          'date': '27 Okt',
          'title': 'Pengiriman Final Master 4K',
          'meta': 'Serah Terima BAST Proyek',
        },
      ];
    } else {
      title = 'Agenda & Milestone Proyek';
      events = [
        {
          'date': '20 Okt',
          'title': 'Review Konsep & Desain Awal',
          'meta': 'Kreator Terpilih • 14:00 WIB',
        },
        {
          'date': '24 Okt',
          'title': 'Persetujuan Draf Produksi Media',
          'meta': 'Milestone II Escrow',
        },
        {
          'date': '31 Okt',
          'title': 'Serah Terima Hasil Akhir & BAST',
          'meta': 'Pelunasan Pembayaran',
        },
      ];
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.event_note_rounded, color: accentColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _guardAndExecute(
                  context,
                  actionName: 'melihat kalender agenda',
                  action: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AgendaScreen(user: user, onUserUpdated: onUserUpdated),
                    ),
                  ),
                ),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Semua',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: events.map((ev) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isDark ? 0.08 : 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: accentColor.withValues(alpha: isDark ? 0.18 : 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ev['date']!,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
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
                            ev['title']!,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ev['meta']!,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAiTipsCard(BuildContext context, Color accentColor) {
    final List<String> tips;
    if (_isGovernment) {
      tips = [
        'Gunakan e-Katalog & LPSE untuk transparansi pengadaan barang/jasa.',
        'Pastikan Berita Acara Serah Terima (BAST) lengkap sebelum proses SP2D.',
        'Sinkronkan realisasi serapan anggaran DIPA/APBD secara berkala.',
      ];
    } else if (_isSchool) {
      tips = [
        'Tampilkan portofolio karya terbaik siswa untuk menarik mitra industri.',
        'Lakukan evaluasi berkala siswa magang lewat instrumen Monev terpadu.',
        'Arsipkan MoU kemitraan industri & sanggar dalam format digital resmi.',
      ];
    } else if (_isCompany) {
      tips = [
        'Tentukan SLA dan spesifikasi teknis RFP secara rinci sebelum publikasi.',
        'Manfaatkan rekening escrow Kreavana untuk keamanan termin pembayaran vendor.',
        'Gunakan otorisasi digital untuk mempercepat alur persetujuan PO korporat.',
      ];
    } else if (_isCreator) {
      tips = [
        'Perbarui portofolio dan ulasan untuk meningkatkan daya saing proyek.',
        'Atur jadwal & ketersediaan di Kapasitas Kerja agar klien mudah mem-booking.',
        'Gunakan Ruang Kolaborasi untuk menangani paket proyek tim berskala besar.',
      ];
    } else {
      tips = [
        'Buat brief kebutuhan proyek dengan deskripsi referensi visual yang jelas.',
        'Bandingkan portofolio dan rating ulasan kreator sebelum memilih mitra.',
        'Manfaatkan proteksi escrow agar pembayaran Anda 100% aman hingga tuntas.',
      ];
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Tips dari AI',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            children: tips.map((tip) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tip,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark
                              ? AppTheme.textMuted
                              : Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEscrowTrustCard(BuildContext context, Color accentColor) {
    final String title;
    final String badge;
    final List<String> points;

    if (_isGovernment) {
      title = 'Akuntabilitas & Kepatuhan PBJ';
      badge = 'Standar Pengadaan & BAST Digital';
      points = [
        'Berita Acara Serah Terima (BAST) sah & tercatat digital',
        'Kepatuhan regulasi pengadaan barang/jasa publik',
        'Verifikasi rekanan berizin usaha & NPWP aktif',
      ];
    } else if (_isSchool) {
      title = 'Legalitas Kemitraan & Karya';
      badge = 'Perlindungan MoU & Hak Cipta Siswa';
      points = [
        'Dokumen MoU kerja sama industri tersimpan resmi',
        'Hak cipta karya inovasi siswa terlindungi penuh',
        'Rekam jejak program magang & sertifikasi terverifikasi',
      ];
    } else if (_isCompany) {
      title = 'Tata Kelola Pengadaan B2B';
      badge = 'Proteksi Termin & Rekonsiliasi PO';
      points = [
        'Pencairan dana bertahap berbasis milestone & PO resmi',
        'Faktur pajak & invoice komersial terintegrasi otomatis',
        'Otorisasi persetujuan berjenjang aman dan siap audit',
      ];
    } else {
      title = 'Proteksi Transaksi & Escrow';
      badge = 'Dana 100% aman dalam escrow Kreavana.';
      points = [
        'Pembayaran hanya cair setelah hasil karya disetujui',
        'Garansi revisi terjamin sesuai brief proyek',
        'Hak cipta karya 100% milik klien setelah lunas',
      ];
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight,
        ),
        boxShadow: isDark ? null : AppTheme.cardShadowLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  color: Color(0xFF10B981),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF132B22) : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_rounded,
                  color: Color(0xFF10B981),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF059669),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...points.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildTrustItem(p),
          )),
        ],
      ),
    );
  }

  Widget _buildTrustItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF10B981)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClientHelpCard(BuildContext context, Color accentColor) {
    final String title;
    final String desc;
    final String btnLabel;

    if (_isGovernment) {
      title = 'Pusat Tata Kelola & BAST';
      desc = 'Butuh konsultasi regulasi SPK, alur pengadaan barang/jasa, atau panduan BAST digital?';
      btnLabel = 'Konsultasi AI Kedinasan';
    } else if (_isSchool) {
      title = 'Pusat Layanan Vokasi';
      desc = 'Butuh panduan kurasi karya siswa, penyusunan MoU, atau penempatan magang industri?';
      btnLabel = 'Konsultasi AI Pendidikan';
    } else if (_isCompany) {
      title = 'Dukungan Korporat B2B';
      desc = 'Butuh bantuan kurasi talent, RFP kustom, atau penyusunan kontrak enterprise?';
      btnLabel = 'Konsultasi AI Enterprise';
    } else if (_isCreator) {
      title = 'Pusat Bantuan Kreator';
      desc = 'Butuh tips meningkatkan nilai penawaran, memenangkan tender, atau mengelola klien?';
      btnLabel = 'Konsultasi AI Kreator';
    } else {
      title = 'Pusat Bantuan & Panduan';
      desc = 'Butuh panduan membuat brief atau mencari talent yang pas untuk proyek Anda?';
      btnLabel = 'Konsultasi AI Kreavana';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isDark ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            desc,
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.go(AppRoutes.aiAssistant),
              icon: const Icon(Icons.auto_awesome, size: 14),
              label: Text(btnLabel, style: const TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarQuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SidebarQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}
