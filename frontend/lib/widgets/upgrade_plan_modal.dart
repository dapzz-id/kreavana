import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/theme.dart';
import '../features/auth/services/auth_service.dart';
import '../models/user_model.dart';
import '../services/subscription_service.dart';
import '../services/user_store.dart';
import '../widgets/auth_guard_dialog.dart';
import '../widgets/wallet_pin_dialog.dart';

int _tierRank(String? tier) {
  final t = (tier ?? '').trim().toLowerCase();
  switch (t) {
    case 'super':
      return 3;
    case 'pro':
      return 2;
    case 'plus':
      return 1;
    case 'basic':
    case 'free':
    default:
      return 0;
  }
}

// ─── Responsive breakpoints ───────────────────────────────────────────────────
// mobile  : < 600
// tablet  : 600 – 960
// desktop : 960 – 1400
// tv/wide : ≥ 1400
// ─────────────────────────────────────────────────────────────────────────────

class UpgradePlanModal extends StatelessWidget {
  final UserModel? user;
  const UpgradePlanModal({super.key, this.user});

  // ── Static show helper ─────────────────────────────────────────────────────
  static void show(BuildContext context, {UserModel? user}) {
    final mq = MediaQuery.of(context);
    final sw = mq.size.width;
    final isMobile = sw < 600;

    if (isMobile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        useSafeArea: true,
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.5,
          maxChildSize: 0.97,
          expand: false,
          builder: (_, scrollController) =>
              _ModalBody(user: user, scrollController: scrollController),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) {
          final dialogMaxWidth = sw >= 1400
              ? 1360.0
              : (sw >= 960 ? 1060.0 : 780.0);
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(
              horizontal: sw >= 960 ? 32 : 20,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: dialogMaxWidth,
                maxHeight: mq.size.height * 0.92,
              ),
              child: _ModalBody(user: user),
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) => _ModalBody(user: user);
}

// ─── Internal modal body (stateful — loads plans from backend) ────────────────
class _ModalBody extends StatefulWidget {
  final UserModel? user;
  final ScrollController? scrollController;
  const _ModalBody({this.user, this.scrollController});

  @override
  State<_ModalBody> createState() => _ModalBodyState();
}

class _ModalBodyState extends State<_ModalBody> {
  late List<SubscriptionPlan> _plans;
  Map<String, dynamic>? _subscriptionDetails;
  bool _isLoading = false;
  bool _isTogglingAutoRenew = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final currentUser = widget.user ?? currentUserNotifier.value;
    final role = currentUser?.role.toLowerCase();
    _plans = SubscriptionService.fallbackPlans(role: role);
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final currentUser = widget.user ?? currentUserNotifier.value;
      final role = currentUser?.role.toLowerCase();
      final isCreator = role == 'creator' || (currentUser?.isCreator ?? false);

      // Sinkronkan tier terbaru dan rincian langganan dari backend jika sudah login
      if (currentUser != null && !currentUser.isGuest) {
        SubscriptionService.getCurrentSubscriptionDetails().then((details) async {
          if (details != null && mounted) {
            setState(() {
              _subscriptionDetails = details;
            });
            final remoteTier = details['tier']?.toString();
            if (remoteTier != null) {
              final live = currentUserNotifier.value ?? currentUser;
              if (live.subscriptionTier.toLowerCase() != remoteTier.toLowerCase()) {
                final updated = live.copyWith(subscriptionTier: remoteTier);
                currentUserNotifier.value = updated;
                await AuthService.updateLocalUser(updated);
              }
            }
          }
        }).catchError((_) {});
      }

      final plans = await SubscriptionService.getPlans(
        role: isCreator ? 'creator' : 'user',
      );
      if (mounted) {
        setState(() {
          final loadedPlans = plans.map((plan) {
            // Sembunyikan teks boost akun sementara di Pilih Paket Upgrade
            // karena fitur belum siap utuh untuk institusi; logika fitur boost tetap aktif.
            return plan.copyWith(
              features: plan.features
                  .where((f) => !f.toLowerCase().contains('boost'))
                  .toList(),
            );
          }).toList();
          if (loadedPlans.isNotEmpty) {
            _plans = loadedPlans;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal memuat paket. Coba lagi.';
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildActiveSubscriptionBanner(bool isDark, String currentTier) {
    if (_tierRank(currentTier) == 0) return const SizedBox.shrink();

    final formattedDate = _subscriptionDetails?['expires_at_formatted'] ?? '1 Bulan';
    final daysLeft = _subscriptionDetails?['days_remaining'];
    final autoRenew = _subscriptionDetails?['auto_renew'] == true;

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B2E) : const Color(0xFFF3F0FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium_rounded, size: 20, color: AppTheme.primaryPurple),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paket ${currentTier.toUpperCase()} Aktif',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  'Masa aktif: $formattedDate${daysLeft != null ? ' ($daysLeft hari lagi)' : ''}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Auto-Renew',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    height: 24,
                    width: 38,
                    child: Switch(
                      value: autoRenew,
                      activeTrackColor: AppTheme.primaryPurple.withValues(alpha: 0.5),
                      activeThumbColor: AppTheme.primaryPurple,
                      onChanged: _isTogglingAutoRenew
                          ? null
                          : (val) async {
                              setState(() => _isTogglingAutoRenew = true);
                              final res = await SubscriptionService.toggleAutoRenew(autoRenew: val);
                              if (mounted) {
                                setState(() {
                                  _isTogglingAutoRenew = false;
                                  if (res != null) {
                                    _subscriptionDetails = {
                                      ...?_subscriptionDetails,
                                      'auto_renew': res['auto_renew'] ?? val,
                                    };
                                  }
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(res?['message'] ?? 'Pengaturan perpanjangan otomatis disimpan.'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<UserModel?>(
      valueListenable: currentUserNotifier,
      builder: (context, liveUser, _) {
        final effectiveUser = liveUser ?? widget.user;
        final currentTier = effectiveUser?.subscriptionTier.toLowerCase() ?? 'free';
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardBg : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Header(),
              _buildActiveSubscriptionBanner(isDark, currentTier),
              Flexible(child: _buildBody(effectiveUser)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(UserModel? effectiveUser) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadPlans();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_plans.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: AppTheme.primaryPurple,
            ),
            const SizedBox(height: 12),
            const Text(
              'Paket upgrade belum tersedia.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _isLoading = true);
                _loadPlans();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Muat Ulang'),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final isMobile = w < 600;
        final isTablet = w >= 600 && w < 960;
        final isTV = w >= 1400;

        final padding = isTV
            ? 32.0
            : (isTablet ? 20.0 : (isMobile ? 16.0 : 24.0));
        final gap = isTV ? 20.0 : (isTablet ? 14.0 : 12.0);

        return SingleChildScrollView(
          controller: widget.scrollController,
          padding: EdgeInsets.all(padding),
          child: isMobile
              ? _buildSingleColumn(gap, effectiveUser)
              : isTablet
              ? _buildTwoColumnGrid(gap, effectiveUser)
              : _buildFourColumnRow(gap, effectiveUser),
        );
      },
    );
  }

  Widget _buildSingleColumn(double gap, UserModel? effectiveUser) {
    return Column(
      children: [
        for (int i = 0; i < _plans.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          _PlanCard(
            plan: _plans[i],
            currentUser: effectiveUser,
            subscriptionDetails: _subscriptionDetails,
            onPurchase: _handlePurchase,
          ),
        ],
      ],
    );
  }

  Widget _buildTwoColumnGrid(double gap, UserModel? effectiveUser) {
    if (_plans.length < 4) return _buildSingleColumn(gap, effectiveUser);
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _PlanCard(
                  plan: _plans[0],
                  currentUser: effectiveUser,
                  subscriptionDetails: _subscriptionDetails,
                  onPurchase: _handlePurchase,
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: _PlanCard(
                  plan: _plans[1],
                  currentUser: effectiveUser,
                  subscriptionDetails: _subscriptionDetails,
                  onPurchase: _handlePurchase,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: gap),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _PlanCard(
                  plan: _plans[2],
                  currentUser: effectiveUser,
                  subscriptionDetails: _subscriptionDetails,
                  onPurchase: _handlePurchase,
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: _PlanCard(
                  plan: _plans[3],
                  currentUser: effectiveUser,
                  subscriptionDetails: _subscriptionDetails,
                  onPurchase: _handlePurchase,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFourColumnRow(double gap, UserModel? effectiveUser) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < _plans.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(
              child: _PlanCard(
                plan: _plans[i],
                currentUser: effectiveUser,
                subscriptionDetails: _subscriptionDetails,
                onPurchase: _handlePurchase,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Purchase / Renewal handler ─────────────────────────────────────────────
  Future<void> _handlePurchase(SubscriptionPlan plan) async {
    final currentUser = widget.user ?? currentUserNotifier.value;
    if (currentUser == null || currentUser.isGuest) {
      AuthGuardDialog.show(
        context,
        actionName: 'berlangganan Paket ${plan.name}',
      );
      return;
    }

    if (plan.isFree) {
      Navigator.pop(context);
      return;
    }

    final userRank = _tierRank(currentUser.subscriptionTier);
    final planRank = _tierRank(plan.tier);
    if (planRank < userRank) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat memilih paket yang lebih rendah dari paket aktif Anda.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final isRenewal = (planRank == userRank && planRank > 0);

    // Step 1: Show wallet PIN dialog.
    // - If wallet not activated → shows activation prompt → returns null.
    // - If user cancels → returns null.
    // - If PIN entered → returns the 6-digit PIN string.
    final pin = await WalletPinDialog.show(
      context,
      title: isRenewal ? 'Konfirmasi Perpanjangan' : 'Konfirmasi Pembelian',
      subtitle: isRenewal
          ? 'Masukkan PIN wallet untuk memperpanjang Paket ${plan.name} (+1 Bulan) seharga ${plan.label}.'
          : 'Masukkan PIN wallet untuk membeli Paket ${plan.name} (${plan.label}).',
    );

    if (pin == 'GO_WALLET') {
      if (!mounted) return;
      Navigator.pop(context); // Close the UpgradePlanModal
      context.go('/wallet');
      return;
    }

    if (pin == null || !mounted) return;

    // Step 2: Show loading overlay while calling backend.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // PIN + tier sent — backend verifies PIN and resolves price.
      final result = await SubscriptionService.purchase(plan.tier, pin: pin);
      if (!mounted) return;
      Navigator.pop(context); // close loading

      if (result != null && result['subscription'] != null) {
        // Update user state di frontend agar UI langsung merefleksikan paket baru
        final current = currentUserNotifier.value ?? widget.user;
        if (current != null) {
          final newBalance = (result['new_balance'] as num?)?.toDouble() ??
              (current.balance - plan.price);
          final updatedUser = current.copyWith(
            subscriptionTier: plan.tier,
            balance: newBalance,
          );
          currentUserNotifier.value = updatedUser;
          await AuthService.updateLocalUser(updatedUser);
        }

        if (!mounted) return;
        Navigator.pop(context); // close upgrade modal
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? (isRenewal
                  ? 'Paket ${plan.name} berhasil diperpanjang 1 bulan!'
                  : 'Paket ${plan.name} berhasil diaktifkan!'),
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // Backend returned an error (wrong PIN, insufficient balance, etc.)
        final msg = result?['message'] ??
            result?['error'] ??
            'Pembelian gagal. Coba lagi.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ─── Header widget ────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryPurple, AppTheme.accentPink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Pilih Paket Upgrade',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Tingkatkan pengalaman dan maksimalkan peluangmu di Kreavana dengan fitur premium.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 22,
            ),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Tutup',
          ),
        ],
      ),
    );
  }
}

// ─── Plan card ────────────────────────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final UserModel? currentUser;
  final Map<String, dynamic>? subscriptionDetails;
  final Future<void> Function(SubscriptionPlan) onPurchase;

  const _PlanCard({
    required this.plan,
    required this.currentUser,
    this.subscriptionDetails,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final w = MediaQuery.of(context).size.width;
    final isTV = w >= 1400;
    final isMobile = w < 600;

    final titleSize = isTV ? 20.0 : 17.0;
    final priceSize = isTV ? 22.0 : 18.0;
    final featureSize = isTV ? 14.0 : 12.5;
    final cardPadding = isTV ? 24.0 : (isMobile ? 16.0 : 18.0);

    final userRank = _tierRank(currentUser?.subscriptionTier);
    final planRank = _tierRank(plan.tier);

    final bool isCurrentPlan = (userRank == planRank);
    final bool isLowerPlan = (planRank < userRank);
    final bool isHigherPlan = (planRank > userRank);

    // Can renew current plan if paid tier (rank > 0), or upgrade to higher plan
    final bool canRenew = isCurrentPlan && planRank > 0;
    final bool canPurchase = isHigherPlan || canRenew;

    final String buttonText;
    if (isCurrentPlan) {
      buttonText = planRank > 0 ? 'Perpanjang (+1 Bln)' : 'Paket Aktif';
    } else if (isLowerPlan) {
      buttonText = 'Paket Sebelumnya';
    } else {
      buttonText = planRank > 0 && userRank > 0
          ? 'Upgrade ke ${plan.name}'
          : 'Pilih Paket';
    }

    return Container(
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentPlan
              ? Colors.green.shade600
              : plan.isPopular
                  ? AppTheme.primaryPurple
                  : (isDark ? AppTheme.inputBorder : Colors.grey.shade200),
          width: (isCurrentPlan || plan.isPopular) ? 2 : 1,
        ),
        boxShadow: (isCurrentPlan || plan.isPopular)
            ? [
                BoxShadow(
                  color: (isCurrentPlan ? Colors.green : AppTheme.primaryPurple)
                      .withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top badge
          if (isCurrentPlan)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.green.shade600.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, size: 12, color: Colors.green.shade600),
                  const SizedBox(width: 4),
                  Text(
                    planRank > 0 && subscriptionDetails?['expires_at_formatted'] != null
                        ? 'Paket Aktif (s/d ${subscriptionDetails!['expires_at_formatted']})'
                        : 'Paket Aktif',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          else if (plan.isPopular)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Paling Populer',
                style: TextStyle(
                  color: AppTheme.primaryPurple,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            const SizedBox(height: 28),

          // Title
          Text(
            plan.name,
            style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),

          // Price label
          Text(
            plan.label,
            style: TextStyle(
              fontSize: priceSize,
              fontWeight: FontWeight.w800,
              color: plan.isFree
                  ? (isDark ? Colors.grey.shade400 : Colors.grey.shade600)
                  : isLowerPlan
                      ? (isDark ? Colors.grey.shade500 : Colors.grey.shade500)
                      : AppTheme.accentPink,
            ),
          ),
          const SizedBox(height: 14),

          // Features list
          ...plan.features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 15,
                    color: isLowerPlan ? Colors.grey.shade400 : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f,
                      style: TextStyle(
                        fontSize: featureSize,
                        height: 1.4,
                        color: isLowerPlan
                            ? (isDark ? Colors.grey.shade400 : Colors.grey.shade600)
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Spacer pins button to the bottom
          const Spacer(),
          const SizedBox(height: 16),

          // CTA Button
          SizedBox(
            width: double.infinity,
            height: isTV ? 50 : 44,
            child: ElevatedButton(
              onPressed: canPurchase ? () => onPurchase(plan) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canPurchase
                    ? (isCurrentPlan
                        ? const Color(0xFF059669) // Emerald green for renewal
                        : (plan.isPopular ? AppTheme.primaryPurple : (isDark ? Colors.grey.shade800 : Colors.grey.shade200)))
                    : (isDark ? Colors.grey.shade900 : Colors.grey.shade200),
                foregroundColor: canPurchase
                    ? (isCurrentPlan || plan.isPopular ? Colors.white : (isDark ? Colors.white : Colors.black87))
                    : (isDark ? Colors.grey.shade600 : Colors.grey.shade500),
                disabledBackgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                disabledForegroundColor: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
                elevation: canPurchase ? 3 : 0,
                shadowColor: canPurchase
                    ? (isCurrentPlan
                        ? Colors.green.withValues(alpha: 0.4)
                        : (plan.isPopular ? AppTheme.primaryPurple.withValues(alpha: 0.4) : null))
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isCurrentPlan
                      ? BorderSide(
                          color: Colors.green.shade600.withValues(alpha: 0.5),
                          width: 1.5,
                        )
                      : BorderSide.none,
                ),
              ),
              child: Text(
                buttonText,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isTV ? 15 : 13.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
