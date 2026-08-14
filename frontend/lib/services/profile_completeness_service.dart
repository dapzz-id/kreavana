import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../app/theme.dart';
import '../widgets/upgrade_plan_modal.dart';
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
    final items = <ProfileCheckItem>[];
    int score = 0;

    // 1. Avatar (20 points)
    final hasAvatar = user.avatarUrl != null && user.avatarUrl!.trim().isNotEmpty;
    if (hasAvatar) score += 20;
    items.add(ProfileCheckItem(
      key: 'avatar',
      title: 'Foto Profil',
      description: 'Unggah foto profil resmi agar akun terpercaya',
      points: 20,
      isCompleted: hasAvatar,
      icon: Icons.account_circle_outlined,
    ));

    // 2. Nama Lengkap & Username (20 points)
    final hasBasic = user.name.trim().isNotEmpty && user.username.trim().isNotEmpty;
    if (hasBasic) score += 20;
    items.add(ProfileCheckItem(
      key: 'name',
      title: 'Nama & Username',
      description: 'Lengkapi nama lengkap dan identitas username',
      points: 20,
      isCompleted: hasBasic,
      icon: Icons.badge_outlined,
    ));

    // 3. Email Terverifikasi (20 points)
    final hasEmail = user.email.trim().isNotEmpty;
    if (hasEmail) score += 20;
    items.add(ProfileCheckItem(
      key: 'email',
      title: 'Email Terverifikasi',
      description: 'Gunakan email aktif untuk keamanan akun',
      points: 20,
      isCompleted: hasEmail,
      icon: Icons.email_outlined,
    ));

    // 4. Nomor Telepon / kontak (20 points)
    final hasPhone = user.phone != null && user.phone!.trim().isNotEmpty;
    if (hasPhone) score += 20;
    items.add(ProfileCheckItem(
      key: 'phone',
      title: 'Nomor Telepon & WhatsApp',
      description: 'Tambahkan nomor WhatsApp untuk komunikasi instan',
      points: 20,
      isCompleted: hasPhone,
      icon: Icons.phone_android_outlined,
    ));

    // 5. Registrasi Kreator / SubRole (20 points)
    final isCreator = user.role == 'creator' ||
        (user.subRole != null && user.subRole!.trim().isNotEmpty) ||
        user.isCreatorApproved;
    if (isCreator) score += 20;
    items.add(ProfileCheckItem(
      key: 'creator',
      title: 'Daftar Sebagai Kreator',
      description: 'Pilih bidang keahlian kreator untuk mulai terima proyek',
      points: 20,
      isCompleted: isCreator,
      icon: Icons.workspace_premium_outlined,
    ));

    return ProfileCompleteness(
      percentage: score.clamp(0, 100),
      items: items,
    );
  }

  static void showChecklistModal(BuildContext context, UserModel user, {VoidCallback? onRefresh}) {
    final completeness = calculate(user);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF181528) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kelengkapan Profil Anda',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Lengkapi indikator di bawah untuk performa maksimal',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${completeness.percentage}%',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryPurple,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: completeness.percentage / 100.0,
                  minHeight: 10,
                  backgroundColor: isDark ? const Color(0xFF2B2844) : Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
                ),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: completeness.items.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = completeness.items[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? (item.isCompleted ? const Color(0xFF221F3A) : const Color(0xFF1E1B32))
                            : (item.isCompleted ? const Color(0xFFF7F5FF) : Colors.grey.shade50),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: item.isCompleted
                              ? AppTheme.primaryPurple.withValues(alpha: 0.3)
                              : (isDark ? Colors.white10 : Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.isCompleted ? Icons.check_circle_rounded : item.icon,
                            color: item.isCompleted ? AppTheme.primaryPurple : Colors.grey,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      item.title,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '+${item.points}%',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: item.isCompleted ? AppTheme.primaryPurple : Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.description,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!item.isCompleted)
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
                                        onUserUpdated: (_) => onRefresh?.call(),
                                        onLogout: () {},
                                      ),
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryPurple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Lengkapi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
