import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/user_model.dart';
import '../services/app_router.dart';
import '../widgets/user_profile_modal.dart';

class PublicProfileScreen extends StatelessWidget {
  final String userId;
  final UserModel? currentUser;
  final String? initialName;
  final String? initialAvatarUrl;

  const PublicProfileScreen({
    super.key,
    required this.userId,
    this.currentUser,
    this.initialName,
    this.initialAvatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0D17) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Profil Pengguna',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go(AppRoutes.beranda);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680, maxHeight: 820),
              child: UserProfileModal(
                userId: userId,
                currentUser: currentUser,
                initialName: initialName,
                initialAvatarUrl: initialAvatarUrl,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
