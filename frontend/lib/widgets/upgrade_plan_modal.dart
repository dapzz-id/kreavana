import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/theme.dart';
import '../services/subscription_service.dart';
import '../widgets/wallet_pin_dialog.dart';


// ─── Responsive breakpoints ───────────────────────────────────────────────────
// mobile  : < 600
// tablet  : 600 – 960
// desktop : 960 – 1400
// tv/wide : ≥ 1400
// ─────────────────────────────────────────────────────────────────────────────

class UpgradePlanModal extends StatelessWidget {
  const UpgradePlanModal({super.key});

  // ── Static show helper ─────────────────────────────────────────────────────
  static void show(BuildContext context) {
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
              _ModalBody(scrollController: scrollController),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) {
          final dialogMaxWidth =
              sw >= 1400 ? 1360.0 : (sw >= 960 ? 1060.0 : 780.0);
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
              child: const _ModalBody(),
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) => const _ModalBody();
}

// ─── Internal modal body (stateful — loads plans from backend) ────────────────
class _ModalBody extends StatefulWidget {
  final ScrollController? scrollController;
  const _ModalBody({this.scrollController});

  @override
  State<_ModalBody> createState() => _ModalBodyState();
}

class _ModalBodyState extends State<_ModalBody> {
  List<SubscriptionPlan> _plans = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final plans = await SubscriptionService.getPlans();
      if (mounted) {
        setState(() {
          _plans = plans;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          Flexible(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final isMobile = w < 600;
        final isTablet = w >= 600 && w < 960;
        final isTV = w >= 1400;

        final padding =
            isTV ? 32.0 : (isTablet ? 20.0 : (isMobile ? 16.0 : 24.0));
        final gap = isTV ? 20.0 : (isTablet ? 14.0 : 12.0);

        return SingleChildScrollView(
          controller: widget.scrollController,
          padding: EdgeInsets.all(padding),
          child: isMobile
              ? _buildSingleColumn(gap)
              : isTablet
                  ? _buildTwoColumnGrid(gap)
                  : _buildFourColumnRow(gap),
        );
      },
    );
  }

  Widget _buildSingleColumn(double gap) {
    return Column(
      children: [
        for (int i = 0; i < _plans.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          _PlanCard(plan: _plans[i], onPurchase: _handlePurchase),
        ],
      ],
    );
  }

  Widget _buildTwoColumnGrid(double gap) {
    if (_plans.length < 4) return _buildSingleColumn(gap);
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                  child: _PlanCard(plan: _plans[0], onPurchase: _handlePurchase)),
              SizedBox(width: gap),
              Expanded(
                  child: _PlanCard(plan: _plans[1], onPurchase: _handlePurchase)),
            ],
          ),
        ),
        SizedBox(height: gap),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                  child: _PlanCard(plan: _plans[2], onPurchase: _handlePurchase)),
              SizedBox(width: gap),
              Expanded(
                  child: _PlanCard(plan: _plans[3], onPurchase: _handlePurchase)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFourColumnRow(double gap) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < _plans.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(
                child: _PlanCard(plan: _plans[i], onPurchase: _handlePurchase)),
          ],
        ],
      ),
    );
  }

  // ── Purchase handler ───────────────────────────────────────────────────────
  Future<void> _handlePurchase(SubscriptionPlan plan) async {
    if (plan.isFree) {
      Navigator.pop(context);
      return;
    }

    // Step 1: Show wallet PIN dialog.
    // - If wallet not activated → shows activation prompt → returns null.
    // - If user cancels → returns null.
    // - If PIN entered → returns the 6-digit PIN string.
    final pin = await WalletPinDialog.show(
      context,
      title: 'Konfirmasi Pembelian',
      subtitle: 'Masukkan PIN wallet untuk membeli Paket ${plan.name} (${plan.label}).',
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
      final result = await SubscriptionService.purchase(
        plan.tier,
        pin: pin,
      );
      if (!mounted) return;
      Navigator.pop(context); // close loading

      if (result != null && result['subscription'] != null) {
        Navigator.pop(context); // close upgrade modal
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                result['message'] ?? 'Paket ${plan.name} berhasil diaktifkan!'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // Backend returned an error (wrong PIN, insufficient balance, etc.)
        final msg = result?['message'] ?? 'Pembelian gagal. Coba lagi.';
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
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
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
  final Future<void> Function(SubscriptionPlan) onPurchase;

  const _PlanCard({required this.plan, required this.onPurchase});

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

    return Container(
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: plan.isPopular
              ? AppTheme.primaryPurple
              : (isDark ? AppTheme.inputBorder : Colors.grey.shade200),
          width: plan.isPopular ? 2 : 1,
        ),
        boxShadow: plan.isPopular
            ? [
                BoxShadow(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.15),
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
          // "Paling Populer" badge – placeholder keeps title aligned
          if (plan.isPopular)
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

          // Price label — comes from backend, NOT hardcoded
          Text(
            plan.label,
            style: TextStyle(
              fontSize: priceSize,
              fontWeight: FontWeight.w800,
              color: plan.isFree
                  ? (isDark ? Colors.grey.shade400 : Colors.grey.shade600)
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
                  const Icon(Icons.check_circle,
                      size: 15, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f,
                      style: TextStyle(fontSize: featureSize, height: 1.4),
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
              onPressed: () => onPurchase(plan),
              style: ElevatedButton.styleFrom(
                backgroundColor: plan.isPopular
                    ? AppTheme.primaryPurple
                    : (isDark
                        ? Colors.grey.shade800
                        : Colors.grey.shade200),
                foregroundColor: plan.isPopular
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87),
                elevation: plan.isPopular ? 4 : 0,
                shadowColor: plan.isPopular
                    ? AppTheme.primaryPurple.withValues(alpha: 0.4)
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                plan.isFree ? 'Paket Aktif' : 'Pilih Paket',
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
