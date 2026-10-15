import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../app/theme.dart';
import '../app/subrole_theme_engine.dart';
import '../widgets/upgrade_plan_modal.dart';
import '../widgets/auth_guard_dialog.dart';
import '../screens/profile_screen.dart';

class ProfileCheckItem {
  final String key;
  final String title;
  final String description;
  final int points;
  final bool isCompleted;
  final IconData icon;

  ProfileCheckItem({
    required this.key,
    required this.title,
    required this.description,
    required this.points,
    required this.isCompleted,
    required this.icon,
  });
}

class ProfileCompleteness {
  final int percentage;
  final List<ProfileCheckItem> items;

  ProfileCompleteness({required this.percentage, required this.items});

  static ProfileCompleteness calculate(UserModel user) {
    if (user.isGuest) {
      return ProfileCompleteness(percentage: 0, items: []);
    }

    final items = <ProfileCheckItem>[];
    int score = 0;

    final sub = (user.subRole ?? '').toLowerCase();
    final isCorporate = [
      'corporate',
      'company',
      'business',
      'perusahaan',
      'bisnis',
      'b2b',
    ].contains(sub);
    final isGovernment = [
      'government',
      'pemerintah',
      'instansi',
    ].contains(sub);
    final isSchool = [
      'institution',
      'institusi',
      'school',
      'education',
      'sekolah',
      'kampus',
    ].contains(sub);
    final isInstitutional = isCorporate || isGovernment || isSchool;

    // 1. Avatar (20 points)
    final hasAvatar =
        user.avatarUrl != null && user.avatarUrl!.trim().isNotEmpty;
    if (hasAvatar) score += 20;
    items.add(
      ProfileCheckItem(
        key: 'avatar',
        title: isCorporate
            ? 'Logo Resmi Perusahaan'
            : (isInstitutional ? 'Logo Resmi Instansi' : 'Foto Profil'),
        description: isCorporate
            ? 'Unggah logo resmi perusahaan agar identitas akun terpercaya'
            : (isInstitutional
                ? 'Unggah logo instansi untuk validitas administrasi'
                : 'Unggah foto profil resmi agar akun terpercaya'),
        points: 20,
        isCompleted: hasAvatar,
        icon: isInstitutional
            ? Icons.business_rounded
            : Icons.account_circle_outlined,
      ),
    );

    // 2. Nama Lengkap & Username (20 points)
    final hasBasic =
        user.name.trim().isNotEmpty && user.username.trim().isNotEmpty;
    if (hasBasic) score += 20;
    items.add(
      ProfileCheckItem(
        key: 'name',
        title: isCorporate
            ? 'Nama Perusahaan & Identitas'
            : (isInstitutional ? 'Nama Lembaga & Identitas' : 'Nama & Username'),
        description: isCorporate
            ? 'Lengkapi nama legal perusahaan dan identitas akun B2B'
            : (isInstitutional
                ? 'Lengkapi nama resmi dan identitas lembaga instansi'
                : 'Lengkapi nama lengkap dan identitas username'),
        points: 20,
        isCompleted: hasBasic,
        icon: isInstitutional
            ? Icons.domain_rounded
            : Icons.badge_outlined,
      ),
    );

    // 3. Email Terverifikasi (20 points)
    final hasEmail = user.email.trim().isNotEmpty;
    if (hasEmail) score += 20;
    items.add(
      ProfileCheckItem(
        key: 'email',
        title: isCorporate
            ? 'Email Resmi Perusahaan'
            : (isInstitutional ? 'Email Resmi Kedinasan' : 'Email Terverifikasi'),
        description: isCorporate
            ? 'Gunakan email resmi perusahaan untuk otorisasi tender & SPK'
            : (isInstitutional
                ? 'Gunakan email aktif lembaga untuk keamanan dan arsip'
                : 'Gunakan email aktif untuk keamanan akun'),
        points: 20,
        isCompleted: hasEmail,
        icon: Icons.email_outlined,
      ),
    );

    // 4. Nomor Telepon / kontak (20 points)
    final hasPhone = user.phone != null && user.phone!.trim().isNotEmpty;
    if (hasPhone) score += 20;
    items.add(
      ProfileCheckItem(
        key: 'phone',
        title: isCorporate
            ? 'Kontak PIC / WhatsApp Resmi'
            : 'Nomor Telepon & WhatsApp',
        description: isCorporate
            ? 'Tambahkan kontak PIC untuk koordinasi lelang & kerja sama cepat'
            : 'Tambahkan nomor WhatsApp untuk komunikasi instan',
        points: 20,
        isCompleted: hasPhone,
        icon: Icons.phone_android_outlined,
      ),
    );

    // 5. Registrasi SubRole / Identitas Korporasi (20 points)
    if (isCorporate) {
      final isSubRoleFilled =
          user.subRole != null && user.subRole!.trim().isNotEmpty;
      if (isSubRoleFilled) score += 20;
      items.add(
        ProfileCheckItem(
          key: 'subrole',
          title: 'Kategori Bisnis & Korporasi',
          description: 'Bidang usaha terverifikasi sebagai Perusahaan Korporat',
          points: 20,
          isCompleted: isSubRoleFilled,
          icon: Icons.corporate_fare_rounded,
        ),
      );
    } else if (isGovernment) {
      final isSubRoleFilled =
          user.subRole != null && user.subRole!.trim().isNotEmpty;
      if (isSubRoleFilled) score += 20;
      items.add(
        ProfileCheckItem(
          key: 'subrole',
          title: 'Kategori Instansi Pemerintah',
          description: 'Status akun terverifikasi sebagai Lembaga Pemerintah',
          points: 20,
          isCompleted: isSubRoleFilled,
          icon: Icons.account_balance_rounded,
        ),
      );
    } else if (isSchool) {
      final isSubRoleFilled =
          user.subRole != null && user.subRole!.trim().isNotEmpty;
      if (isSubRoleFilled) score += 20;
      items.add(
        ProfileCheckItem(
          key: 'subrole',
          title: 'Kategori Lembaga Pendidikan',
          description: 'Status akun terverifikasi sebagai Sekolah / Kampus',
          points: 20,
          isCompleted: isSubRoleFilled,
          icon: Icons.school_rounded,
        ),
      );
    } else {
      final isCreator =
          user.role == 'creator' ||
          (user.subRole != null && user.subRole!.trim().isNotEmpty) ||
          user.isCreatorApproved;
      if (isCreator) score += 20;
      items.add(
        ProfileCheckItem(
          key: 'creator',
          title: 'Daftar Sebagai Kreator',
          description: 'Pilih bidang keahlian kreator untuk mulai terima proyek',
          points: 20,
          isCompleted: isCreator,
          icon: Icons.workspace_premium_outlined,
        ),
      );
    }

    return ProfileCompleteness(percentage: score.clamp(0, 100), items: items);
  }

  static void showChecklistModal(
    BuildContext context,
    UserModel user, {
    VoidCallback? onRefresh,
  }) {
    if (user.isGuest) {
      AuthGuardDialog.show(
        context,
        actionName: 'melihat kelengkapan profil akun',
      );
      return;
    }

    final completeness = calculate(user);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = SubRoleThemeEngine.getAccentColorForUser(user);
    final isDesktop = MediaQuery.of(context).size.width > 700;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Container(
              margin: isDesktop ? const EdgeInsets.all(24) : EdgeInsets.zero,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141221) : Colors.white,
                borderRadius: isDesktop
                    ? BorderRadius.circular(28)
                    : const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 28,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.verified_user_rounded,
                          color: accentColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kelengkapan Profil Anda',
                              style: TextStyle(
                                fontSize: 18.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: isDark
                                    ? AppTheme.textWhite
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Lengkapi indikator di bawah untuk performa & kredibilitas maksimal',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppTheme.textMuted
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: isDark ? 0.22 : 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          '${completeness.percentage}%',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: completeness.percentage / 100.0,
                      minHeight: 8,
                      backgroundColor: isDark
                          ? const Color(0xFF262338)
                          : Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Checklist List
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: completeness.items.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = completeness.items[index];
                        final isCompleted = item.isCompleted;

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? (isCompleted
                                    ? accentColor.withValues(alpha: 0.08)
                                    : const Color(0xFF1E1B2E))
                                : (isCompleted
                                    ? accentColor.withValues(alpha: 0.04)
                                    : Colors.grey.shade50),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCompleted
                                  ? accentColor.withValues(alpha: 0.25)
                                  : (isDark
                                      ? Colors.white10
                                      : Colors.grey.shade200),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isCompleted
                                      ? const Color(0xFF10B981)
                                          .withValues(alpha: isDark ? 0.2 : 0.12)
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.06)
                                          : Colors.grey.shade200),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isCompleted
                                      ? Icons.check_circle_rounded
                                      : item.icon,
                                  color: isCompleted
                                      ? const Color(0xFF10B981)
                                      : (isDark
                                          ? Colors.white54
                                          : Colors.grey.shade600),
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
                                        Flexible(
                                          child: Text(
                                            item.title,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: isDark
                                                  ? AppTheme.textWhite
                                                  : const Color(0xFF1E293B),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isCompleted
                                                ? const Color(0xFF10B981)
                                                    .withValues(alpha: 0.12)
                                                : (isDark
                                                    ? Colors.white10
                                                    : Colors.grey.shade200),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            isCompleted
                                                ? '✓ Selesai'
                                                : '+${item.points}%',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: isCompleted
                                                  ? const Color(0xFF10B981)
                                                  : (isDark
                                                      ? Colors.white60
                                                      : Colors.grey.shade600),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      item.description,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        height: 1.35,
                                        color: isDark
                                            ? AppTheme.textMuted
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isCompleted) ...[
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    if (item.key == 'creator') {
                                      UpgradePlanModal.show(context);
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ProfileScreen(
                                            user: user,
                                            onUserUpdated: (_) =>
                                                onRefresh?.call(),
                                            onLogout: () {},
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accentColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    elevation: 0,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Lengkapi',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 13,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
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
