import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../app/theme.dart';
import '../app/app_animations.dart';
import '../models/marketplace_item.dart';
import '../services/marketplace_service.dart';
import '../services/follow_service.dart';
import '../features/auth/services/auth_service.dart';
import '../utils/app_errors.dart';
import '../widgets/wallet_pin_dialog.dart';
import 'package:go_router/go_router.dart';

class MarketplaceDetailScreen extends StatefulWidget {
  final String itemId;
  const MarketplaceDetailScreen({super.key, required this.itemId});

  @override
  State<MarketplaceDetailScreen> createState() =>
      _MarketplaceDetailScreenState();
}

class _MarketplaceDetailScreenState extends State<MarketplaceDetailScreen>
    with TickerProviderStateMixin {
  MarketplaceItem? _item;
  bool _isLoading = true;
  int _selectedRating = 0;
  final _commentCtrl = TextEditingController();
  bool _isSubmitting = false;
  bool _isFavorited = false;
  bool _isFollowing = false;
  bool _followBusy = false;
  String? _currentUserId;

  late final ScrollController _scrollCtrl;
  late final AnimationController _heroShimmerCtrl;
  late final AnimationController _heartCtrl;
  late final AnimationController _bottomBarCtrl;
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController()..addListener(_onScroll);
    _heroShimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _bottomBarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _loadItem();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _heroShimmerCtrl.dispose();
    _heartCtrl.dispose();
    _bottomBarCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    setState(() => _scrollOffset = _scrollCtrl.offset);
  }

  Future<void> _loadItem() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = await AuthService.getCurrentUser();
      final result = await MarketplaceService.getItem(widget.itemId);
      if (mounted && result['status'] == true && result['data'] != null) {
        setState(() {
          _item = MarketplaceItem.fromJson(result['data']);
          _isFollowing = _item!.isFollowing;
          _currentUserId = currentUser?.id;
          _isLoading = false;
        });
        _bottomBarCtrl.forward();
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleFavorite() {
    _heartCtrl.forward(from: 0).then((_) {
      _heartCtrl.reverse();
    });
    setState(() => _isFavorited = !_isFavorited);
  }

  Future<void> _toggleFollow() async {
    if (_followBusy) return;
    final creatorId = _item?.userId;
    if (creatorId == null || creatorId.isEmpty) return;

    setState(() => _followBusy = true);
    try {
      final result = _isFollowing
          ? await FollowService.unfollow(creatorId)
          : await FollowService.follow(creatorId);
      if (!mounted) return;
      if (result['status'] == true) {
        setState(() => _isFollowing = !_isFollowing);
        AppSnackbar.success(
          context,
          _isFollowing
              ? 'Berhasil mengikuti ${_item?.creator?.name ?? 'kreator'}'
              : 'Berhenti mengikuti',
        );
      } else {
        AppSnackbar.error(
          context,
          result['message'] ?? 'Gagal mengikuti kreator.',
        );
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppErrors.friendly(e));
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  Future<void> _purchaseItem() async {
    if (_item == null) return;

    final pin = await WalletPinDialog.show(
      context,
      title: 'Konfirmasi Pembelian',
      subtitle: 'Masukkan PIN wallet untuk membeli "${_item!.title}".',
    );

    if (pin == 'GO_WALLET') {
      if (!mounted) return;
      context.go('/wallet');
      return;
    }

    if (pin == null || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final result = await MarketplaceService.purchaseItem(_item!.id, pin: pin);
      if (mounted) {
        setState(() => _isSubmitting = false);
        if (result['status'] == true) {
          AppSnackbar.success(context, 'Berhasil membeli karya!');
          _loadItem();
        } else {
          AppSnackbar.error(
            context,
            result['message'] ?? 'Gagal membeli karya.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppSnackbar.error(context, 'Terjadi kesalahan saat membeli.');
      }
    }
  }

  Future<void> _submitReview() async {
    if (_selectedRating == 0) {
      AppSnackbar.info(context, 'Pilih rating terlebih dahulu.');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final result = await MarketplaceService.submitReview(
        itemId: widget.itemId,
        rating: _selectedRating,
        comment: _commentCtrl.text.trim().isEmpty
            ? null
            : _commentCtrl.text.trim(),
      );
      if (mounted) {
        setState(() => _isSubmitting = false);
        if (result['status'] == true) {
          _commentCtrl.clear();
          _selectedRating = 0;
          AppSnackbar.success(context, 'Review berhasil dikirim!');
          _loadItem();
        } else {
          AppSnackbar.error(
            context,
            result['message'] ?? 'Gagal mengirim review.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppSnackbar.error(context, 'Terjadi kesalahan.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final heroHeight = 320.0;
    final parallaxOffset = (_scrollOffset * 0.4).clamp(0.0, heroHeight);
    
    final canReview = _item?.canReview ?? false;
    final hasReviewed = _item?.hasReviewed ?? false;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
      body: _isLoading
          ? _buildLoadingState(isDark)
          : _item == null
          ? _buildEmptyState(isDark)
          : CustomScrollView(
              controller: _scrollCtrl,
              slivers: [
                _buildSliverAppBar(isDark, heroHeight, parallaxOffset),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitleSection(isDark),
                      _buildCreatorSection(isDark),
                      _buildStatsSection(isDark),
                      _buildDescriptionSection(isDark),
                      _buildReviewSection(isDark),
                      if (canReview) _buildWriteReviewSection(isDark),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ],
            ),
      bottomSheet: _item == null ? null : _buildBottomBar(isDark),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 320,
          pinned: true,
          backgroundColor: isDark
              ? AppTheme.surfaceDark
              : AppTheme.surfaceLight,
          flexibleSpace: FlexibleSpaceBar(
            background: _buildShimmerBox(isDark, 320),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList.list(
            children: [
              _buildShimmerBox(isDark, 24, width: 100),
              const SizedBox(height: 12),
              _buildShimmerBox(isDark, 28),
              const SizedBox(height: 16),
              _buildShimmerBox(isDark, 56),
              const SizedBox(height: 16),
              _buildShimmerBox(isDark, 40),
              const SizedBox(height: 16),
              _buildShimmerBox(isDark, 100),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerBox(bool isDark, double height, {double? width}) {
    return AnimatedBuilder(
      animation: _heroShimmerCtrl,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [
                (isDark ? AppTheme.cardDark2 : AppTheme.inputLight),
                (isDark ? AppTheme.inputDark : Colors.white),
                (isDark ? AppTheme.cardDark2 : AppTheme.inputLight),
              ],
              stops: [
                (_heroShimmerCtrl.value - 0.3).clamp(0.0, 1.0),
                _heroShimmerCtrl.value,
                (_heroShimmerCtrl.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.storefront_outlined,
            size: 64,
            color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
          ),
          const SizedBox(height: 16),
          Text(
            'Karya tidak ditemukan.',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(
    bool isDark,
    double heroHeight,
    double parallaxOffset,
  ) {
    return SliverAppBar(
      expandedHeight: heroHeight,
      pinned: true,
      stretch: true,
      backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
      leading: _glassIconButton(
        icon: Icons.arrow_back_ios_new_rounded,
        isDark: isDark,
        onTap: () => Navigator.pop(context),
      ),
      actions: [
        _buildShareButton(isDark),
        _buildFavoriteButton(isDark),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Transform.translate(
              offset: Offset(0, -parallaxOffset),
              child: Container(
                height: heroHeight + parallaxOffset,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E1B2E), const Color(0xFF2D1B69)]
                        : [const Color(0xFFEDE9FE), const Color(0xFFDDD6FE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _heroShimmerCtrl,
              builder: (context, _) {
                return CustomPaint(
                  painter: _HeroPatternPainter(
                    animationValue: _heroShimmerCtrl.value,
                    accentColor: AppTheme.primaryPurple,
                    isDark: isDark,
                  ),
                  size: Size.infinite,
                );
              },
            ),
            if (_item?.media != null && _item!.media!.isNotEmpty)
              PageView.builder(
                itemCount: _item!.media!.length,
                itemBuilder: (context, index) {
                  final media = _item!.media![index];
                  if (media.fileType == 'video') {
                    return const Center(
                      child: Icon(
                        Icons.videocam,
                        size: 64,
                        color: Colors.white54,
                      ),
                    );
                  }
                  return Image.network(
                    media.filePath,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  );
                },
              )
            else
              Center(
                child: AnimatedEntrance(
                  duration: const Duration(milliseconds: 600),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryPurple.withValues(
                        alpha: isDark ? 0.2 : 0.15,
                      ),
                      border: Border.all(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      _categoryIcon(_item?.category ?? ''),
                      size: 44,
                      color: AppTheme.primaryPurple.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ),
            if (_item?.isFeatured == true)
              Positioned(
                top: 16,
                left: 16,
                child: AnimatedEntrance(
                  delay: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.workspace_premium,
                          size: 14,
                          color: Colors.white,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Unggulan',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _glassIconButton({
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (isDark ? Colors.black : Colors.white).withValues(
              alpha: 0.5,
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isDark ? Colors.white : AppTheme.textDark,
          ),
        ),
      ),
    );
  }

  Widget _buildShareButton(bool isDark) {
    return _glassIconButton(
      icon: Icons.share_outlined,
      isDark: isDark,
      onTap: _shareItem,
    );
  }

  Future<void> _shareItem() async {
    final item = _item;
    if (item == null) return;

    final text =
        '${item.title} — ${item.formattedPrice}\n'
        'Kategori: ${item.category}\n'
        'Kreator: ${item.creator?.name ?? '-'}'
        '${item.description != null && item.description!.isNotEmpty ? '\n\n${item.description!}' : ''}\n'
        'Lihat karya ini di Kreavana Marketplace!';

    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (e) {
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        AppSnackbar.success(context, 'Detail karya disalin ke clipboard');
      }
    }
  }

  Widget _buildFavoriteButton(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTap: _toggleFavorite,
        child: AnimatedBuilder(
          animation: _heartCtrl,
          builder: (context, child) {
            final scale = 1.0 + (_heartCtrl.value * 0.3);
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isDark ? Colors.black : Colors.white).withValues(
                    alpha: 0.5,
                  ),
                ),
                child: Icon(
                  _isFavorited ? Icons.favorite : Icons.favorite_border,
                  size: 20,
                  color: _isFavorited
                      ? AppTheme.error
                      : (isDark ? Colors.white : AppTheme.textDark),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTitleSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: AnimatedEntrance(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withValues(
                  alpha: isDark ? 0.15 : 0.1,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _item!.category,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryPurple,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _item!.title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.25,
                letterSpacing: -0.3,
                color: isDark ? AppTheme.textWhite : AppTheme.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatorSection(bool isDark) {
    final isOwn = _currentUserId != null && _item?.userId == _currentUserId;
    return AnimatedEntrance(
      delay: const Duration(milliseconds: 80),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark2 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight,
            ),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppTheme.primaryPurple.withValues(
                      alpha: 0.15,
                    ),
                    child: Text(
                      (_item!.creator?.name ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryPurple,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.success,
                        border: Border.all(
                          color: isDark ? AppTheme.cardDark2 : Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _item!.creator?.name ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.textWhite : AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${_item!.creator?.username ?? ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: isOwn ? null : _toggleFollow,
                icon: _followBusy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _isFollowing
                            ? Icons.check_rounded
                            : Icons.person_add_alt_1_rounded,
                        size: 16,
                        color: isOwn
                            ? AppTheme.textMuted
                            : (_isFollowing
                                  ? AppTheme.primaryPurple
                                  : Colors.white),
                      ),
                style: TextButton.styleFrom(
                  foregroundColor: isOwn
                      ? AppTheme.textMuted
                      : (_isFollowing ? AppTheme.primaryPurple : Colors.white),
                  backgroundColor: isOwn
                      ? Colors.transparent
                      : _isFollowing
                      ? AppTheme.primaryPurple.withValues(alpha: 0.08)
                      : AppTheme.primaryPurple,
                  side: isOwn
                      ? BorderSide(
                          color: isDark
                              ? AppTheme.inputBorder
                              : AppTheme.inputBorderLight,
                        )
                      : _isFollowing
                      ? const BorderSide(
                          color: AppTheme.primaryPurple,
                          width: 1.5,
                        )
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                label: Text(
                  isOwn
                      ? 'Karyamu'
                      : _isFollowing
                      ? 'Diikuti'
                      : 'Ikuti',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(bool isDark) {
    return AnimatedEntrance(
      delay: const Duration(milliseconds: 160),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(
          children: [
            _StatCard(
              icon: Icons.star_rounded,
              value: _item!.rating.toStringAsFixed(1),
              label: 'Rating',
              iconColor: const Color(0xFFF59E0B),
              isDark: isDark,
            ),
            const SizedBox(width: 10),
            _StatCard(
              icon: Icons.reviews_outlined,
              value: '${_item!.reviewCount}',
              label: 'Ulasan',
              iconColor: AppTheme.primaryPurple,
              isDark: isDark,
            ),
            const SizedBox(width: 10),
            _StatCard(
              icon: Icons.shopping_bag_outlined,
              value: '${_item!.orderCount}',
              label: 'Pesanan',
              iconColor: AppTheme.success,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection(bool isDark) {
    if (_item!.description == null || _item!.description!.isEmpty) {
      return const SizedBox.shrink();
    }
    return AnimatedEntrance(
      delay: const Duration(milliseconds: 240),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deskripsi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.textWhite : AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _item!.description!,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSection(bool isDark) {
    final reviews = _item!.reviews ?? [];
    if (reviews.isEmpty) return const SizedBox.shrink();
    return AnimatedEntrance(
      delay: const Duration(milliseconds: 320),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Ulasan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppTheme.textWhite : AppTheme.textDark,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withValues(
                      alpha: isDark ? 0.15 : 0.1,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${reviews.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryPurple,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...reviews.asMap().entries.map(
              (entry) => _ReviewCard(
                review: entry.value,
                index: entry.key,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWriteReviewSection(bool isDark) {
    return AnimatedEntrance(
      delay: const Duration(milliseconds: 400),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark2 : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _item?.hasReviewed == true ? 'Edit Ulasan' : 'Tulis Ulasan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.textWhite : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: List.generate(
                  5,
                  (i) => GestureDetector(
                    onTap: () {
                      setState(() => _selectedRating = i + 1);
                    },
                    child: AnimatedScale(
                      scale: i < _selectedRating ? 1.15 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      curve: AppMotion.spring,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          i < _selectedRating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 32,
                          color: i < _selectedRating
                              ? const Color(0xFFF59E0B)
                              : (isDark
                                    ? AppTheme.textMuted
                                    : AppTheme.textMutedLight),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _commentCtrl,
                maxLines: 3,
                style: TextStyle(
                  color: isDark ? AppTheme.textWhite : AppTheme.textDark,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Tulis ulasanmu tentang karya ini...',
                  hintStyle: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? AppTheme.inputDark
                      : AppTheme.surfaceLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark
                          ? AppTheme.inputBorder
                          : AppTheme.inputBorderLight,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark
                          ? AppTheme.inputBorder
                          : AppTheme.inputBorderLight,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryPurple,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: Pressable(
                  onTap: _isSubmitting ? null : _submitReview,
                  pressedScale: 0.96,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      gradient: _isSubmitting
                          ? null
                          : const LinearGradient(
                              colors: [
                                AppTheme.primaryPurple,
                                AppTheme.lightPurple,
                              ],
                            ),
                      color: _isSubmitting ? AppTheme.textMuted : null,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _isSubmitting
                          ? null
                          : [
                              BoxShadow(
                                color: AppTheme.primaryPurple.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Kirim Ulasan',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    final isOwn = _currentUserId != null && _item?.userId == _currentUserId;
    return AnimatedBuilder(
      animation: _bottomBarCtrl,
      builder: (context, child) {
        final slide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: _bottomBarCtrl, curve: AppMotion.easeOut),
            );
        return SlideTransition(
          position: slide,
          child: FadeTransition(
            opacity: _bottomBarCtrl,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.cardDark.withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.95),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Harga',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _item!.formattedPrice,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryPurple,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Pressable(
                      onTap: isOwn
                          ? null
                          : () {
                              if (_item!.type == 'paid' &&
                                  !_item!.hasPurchased) {
                                _purchaseItem();
                              } else {
                                AppSnackbar.info(
                                  context,
                                  'Fitur download belum tersedia.',
                                );
                              }
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: isOwn
                              ? null
                              : const LinearGradient(
                                  colors: [
                                    AppTheme.primaryPurple,
                                    AppTheme.lightPurple,
                                  ],
                                ),
                          color: isOwn
                              ? (isDark
                                    ? AppTheme.inputDark
                                    : AppTheme.inputLight)
                              : null,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: isOwn
                              ? null
                              : [
                                  BoxShadow(
                                    color: AppTheme.primaryPurple.withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isSubmitting)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            else ...[
                              Icon(
                                isOwn
                                    ? Icons.person_rounded
                                    : (_item!.type == 'paid' &&
                                              !_item!.hasPurchased
                                          ? Icons.shopping_cart_checkout_rounded
                                          : Icons.download_rounded),
                                size: 20,
                                color: isOwn
                                    ? AppTheme.textMuted
                                    : Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isOwn
                                    ? 'Karya Anda'
                                    : (_item!.type == 'paid' &&
                                              !_item!.hasPurchased
                                          ? 'Beli Sekarang'
                                          : 'Download'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: isOwn
                                      ? AppTheme.textMuted
                                      : Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Fotografi':
        return Icons.camera_alt_rounded;
      case 'Videografi':
        return Icons.videocam_rounded;
      case 'Desain':
        return Icons.palette_rounded;
      case 'Konten':
        return Icons.edit_note_rounded;
      case 'Branding':
        return Icons.branding_watermark_rounded;
      default:
        return Icons.palette_rounded;
    }
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark2 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? AppTheme.textWhite : AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Review Card ───────────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final MarketplaceReview review;
  final int index;
  final bool isDark;

  const _ReviewCard({
    required this.review,
    required this.index,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedEntrance(
      delay: Duration(milliseconds: 350 + index * 60),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark2 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.primaryPurple.withValues(
                    alpha: 0.15,
                  ),
                  child: Text(
                    (review.user?.name ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryPurple,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.user?.name ?? 'Anonymous',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppTheme.textWhite
                              : AppTheme.textDark,
                        ),
                      ),
                      if (review.createdAt != null)
                        Text(
                          _formatTime(review.createdAt!),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < review.rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 15,
                      color: i < review.rating
                          ? const Color(0xFFF59E0B)
                          : (isDark
                                ? AppTheme.textMuted
                                : AppTheme.textMutedLight),
                    ),
                  ),
                ),
              ],
            ),
            if (review.comment != null && review.comment!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                review.comment!,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Baru saja';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
      if (diff.inHours < 24) return '${diff.inHours}j lalu';
      if (diff.inDays < 7) return '${diff.inDays}h lalu';
      return '${(diff.inDays / 7).floor()}w lalu';
    } catch (_) {
      return '';
    }
  }
}

// ── Hero Pattern Painter ──────────────────────────────────────────────────────

class _HeroPatternPainter extends CustomPainter {
  final double animationValue;
  final Color accentColor;
  final bool isDark;

  _HeroPatternPainter({
    required this.animationValue,
    required this.accentColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final baseAlpha = isDark ? 0.06 : 0.08;

    for (var i = 0; i < 5; i++) {
      final offset = math.sin(animationValue * math.pi * 2 + i * 1.2) * 30;
      final radius =
          60.0 + i * 20 + math.cos(animationValue * math.pi * 2 + i) * 10;
      paint.color = accentColor.withValues(alpha: baseAlpha);
      canvas.drawCircle(
        Offset(
          size.width * (0.15 + i * 0.18) + offset,
          size.height *
              (0.3 + math.sin(animationValue * math.pi * 2 + i * 0.8) * 0.15),
        ),
        radius,
        paint,
      );
    }

    // Subtle diagonal lines
    final linePaint = Paint()
      ..color = accentColor.withValues(alpha: isDark ? 0.03 : 0.04)
      ..strokeWidth = 1;
    for (var i = -5; i < 15; i++) {
      final x = i * 40.0 + animationValue * 40;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x - size.height * 0.3, size.height),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeroPatternPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
