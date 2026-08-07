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
import '../screens/profile_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final accentColor = SubRoleThemeEngine.getAccentColor(user.role, user.subRole);

    return Column(
      children: [
        _buildProfileCard(context, accentColor),
        const SizedBox(height: 16),
        _buildQuickActionsCard(context, accentColor),
        const SizedBox(height: 16),
        _buildAiTipsCard(context, accentColor),
      ],
    );
  }

  Widget _buildProfileCard(BuildContext context, Color accentColor) {
    final isCreator = user.role == 'creator' || user.isCreator;
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
                backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
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
                      subRoleLabel,
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(
                        user: user,
                        onUserUpdated: onUserUpdated ?? (_) {},
                        onLogout: onLogout ?? () => Navigator.of(context).popUntil((r) => r.isFirst),
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: accentColor,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                child: const Text('Profil', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: isCreator ? 0.85 : 0.68,
              minHeight: 7,
              backgroundColor: accentColor.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
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
                  color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                ),
              ),
              Text(
                isCreator ? '85%' : '68%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(
                      user: user,
                      onUserUpdated: onUserUpdated ?? (_) {},
                      onLogout: onLogout ?? () => Navigator.of(context).popUntil((r) => r.isFirst),
                    ),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                side: BorderSide(color: accentColor, width: 1.5),
                foregroundColor: accentColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Lengkapi Profil',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(BuildContext context, Color accentColor) {
    final isCreator = user.role == 'creator' || user.isCreator;

    final actions = isCreator
        ? [
            {'icon': Icons.add_circle_outline, 'label': 'Cari Peluang'},
            {'icon': Icons.search, 'label': 'Kirim Proposal'},
            {'icon': Icons.compare_arrows, 'label': 'Tambah Karya'},
            {'icon': Icons.check_circle_outline, 'label': 'Atur Jadwal'},
            {'icon': Icons.payment, 'label': 'Tarik Dana'},
            {'icon': Icons.analytics_outlined, 'label': 'Komunitas'},
          ]
        : [
            {'icon': Icons.add_circle_outline, 'label': 'Buat Kebutuhan'},
            {'icon': Icons.search, 'label': 'Cari Kreator'},
            {'icon': Icons.compare_arrows, 'label': 'Bandingkan'},
            {'icon': Icons.check_circle_outline, 'label': 'Setujui Proyek'},
            {'icon': Icons.payment, 'label': 'Bayar DP'},
            {'icon': Icons.analytics_outlined, 'label': 'Laporan'},
          ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
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
                onTap: () {
                  final label = action['label'] as String;
                  if (label == 'Buat Kebutuhan') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const BuatKebutuhanScreen()));
                  } else if (label == 'Cari Kreator' || label == 'Cari Peluang') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ExploreScreen(user: user)));
                  } else if (label == 'Bandingkan' || label == 'Setujui Proyek' || label == 'Kirim Proposal') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ProyekSayaScreen(user: user)));
                  } else if (label == 'Bayar DP' || label == 'Tarik Dana') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => WalletScreen(user: user, onUserUpdated: onUserUpdated ?? (_) {})));
                  } else if (label == 'Laporan') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => LaporanScreen(user: user, onUserUpdated: onUserUpdated ?? (_) {})));
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: isDark ? 0.12 : 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentColor.withValues(alpha: isDark ? 0.25 : 0.15)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon((action['icon'] as IconData?) ?? Icons.image_outlined, color: accentColor, size: 22),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          action['label'] as String,
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

  Widget _buildAiTipsCard(BuildContext context, Color accentColor) {
    final tips = user.role == 'creator' || user.isCreator
        ? [
            'Buat brief lebih detail agar proposal lebih tepat',
            'Simpan kreator favorit untuk proyek berikutnya',
            'Gunakan agenda untuk memantau deadline',
          ]
        : [
            'Buat brief lebih detail agar proposal lebih tepat',
            'Simpan kreator favorit untuk proyek berikutnya',
            'Gunakan agenda untuk memantau deadline',
          ];

    return Container(
      padding: const EdgeInsets.all(20),
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
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
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
                          fontSize: 12,
                          color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
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
}
