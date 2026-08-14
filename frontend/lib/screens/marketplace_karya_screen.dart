import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../app/app_animations.dart';
import '../models/marketplace_item.dart';
import '../models/user_model.dart';
import '../services/marketplace_service.dart';
import '../widgets/app_empty_state.dart';
import 'marketplace_detail_screen.dart';
import 'jual_karya_screen.dart';
import '../widgets/skeleton/skeleton_base.dart';
class MarketplaceKaryaScreen extends StatefulWidget {
  final UserModel? user;
  final ValueChanged<UserModel>? onUserUpdated;

  const MarketplaceKaryaScreen({super.key, this.user, this.onUserUpdated});

  @override
  State<MarketplaceKaryaScreen> createState() => _MarketplaceKaryaScreenState();
}

class _MarketplaceKaryaScreenState extends State<MarketplaceKaryaScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<MarketplaceItem> _items = [];
  List<MarketplaceItem> _featured = [];
  String _selectedCategory = 'Semua';
  String _sortBy = 'latest';
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMore = true;

  static const _allCategories = ['Semua', 'Fotografi', 'Videografi', 'Desain', 'Konten', 'Branding'];

  @override
  void initState() {
    super.initState();
    _loadAll();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200 &&
        !_isLoadingMore && _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        MarketplaceService.getFeatured(),
        MarketplaceService.getCategories(),
        MarketplaceService.getCategory(_selectedCategory, _searchCtrl.text, _sortBy, 1),
      ]);

      if (mounted) {
        final featuredRes = results[0];
        final catRes = results[1];
        final itemsRes = results[2];

        setState(() {
          if (featuredRes['status'] == true && featuredRes['data'] != null) {
            final data = featuredRes['data'];
            _featured = (data is List ? data : data['data'] ?? [])
                .map((e) => MarketplaceItem.fromJson(e))
                .toList();
          }
          if (catRes['status'] == true && catRes['data'] != null) {
            // Categories loaded (used for future filter expansion)
          }
          _parseItems(itemsRes);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCategoryItems() async {
    setState(() {
      _currentPage = 1;
      _hasMore = true;
      _items = [];
    });
    try {
      final selectedCategory = _selectedCategory.toLowerCase() == 'semua' ? null : _selectedCategory;
      final result = await MarketplaceService.getCategory(
          selectedCategory, _searchCtrl.text, _sortBy, 1);
      if (mounted) _parseItems(result);
    } catch (_) {}
  }

  Future<void> _loadMore() async {
    if (!_hasMore) return;
    setState(() => _isLoadingMore = true);
    _currentPage++;
    try {
      final result = await MarketplaceService.getCategory(
          _selectedCategory, _searchCtrl.text, _sortBy, _currentPage);
      if (mounted) {
        _parseItems(result);
        setState(() => _isLoadingMore = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _parseItems(Map<String, dynamic> result) {
    if (result['status'] == true && result['data'] != null) {
      final data = result['data'];
      final List<dynamic> itemList = data is Map ? (data['data'] ?? []) : (data is List ? data : []);
      final newItems = itemList.map((e) => MarketplaceItem.fromJson(e)).toList();
      setState(() {
        if (_currentPage == 1) {
          _items = newItems;
        } else {
          _items.addAll(newItems);
        }
        if (data is Map && data['last_page'] != null) {
          _hasMore = _currentPage < data['last_page'];
        } else {
          _hasMore = newItems.isNotEmpty;
        }
      });
    }
  }

  void _onSearch() => _loadCategoryItems();

  void _onCategoryTap(String cat) {
    if (_selectedCategory == cat) return;
    setState(() => _selectedCategory = cat);
    _loadCategoryItems();
  }

  void _onSortChange(String sort) {
    setState(() => _sortBy = sort);
    _loadCategoryItems();
  }

  void _openDetail(MarketplaceItem item) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => MarketplaceDetailScreen(itemId: item.id),
    ));
  }

  Future<void> _openJualKarya() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const JualKaryaScreen()),
    );
    if (created == true) {
      _loadAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.width < 800 ? 90 : 0,
        ),
        child: (widget.user != null && widget.user!.isCreator)
          ? FloatingActionButton.extended(
              heroTag: 'jual_karya',
              onPressed: _openJualKarya,
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Jual Karya',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      ),
      appBar: AppBar(
        toolbarHeight: 75,
        title: const Text('Marketplace Karya',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Temukan kreator lokal terbaik dan karya yang siap membantu kebutuhan promosi bisnismu.',
              style: TextStyle(fontSize: 13, color: isDark ? AppTheme.textMuted : Colors.grey.shade700),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? _buildSkeletonLoading(isDark, isWide)
          : RefreshIndicator(
              onRefresh: _loadAll,
              color: AppTheme.primaryPurple,
              child: CustomScrollView(
                controller: _scrollCtrl,
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(isWide ? 32 : 16, 20, isWide ? 32 : 16, 0),
                    sliver: SliverList.list(children: [
                      _buildSearchBar(isDark),
                      const SizedBox(height: 14),
                      _buildCategoryChips(isDark),
                      const SizedBox(height: 10),
                      _buildSortBar(isDark),
                    ]),
                  ),
                  if (_featured.isNotEmpty) ...[
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(isWide ? 32 : 16, 20, isWide ? 32 : 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: AnimatedEntrance(
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 20,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppTheme.primaryPurple, AppTheme.lightPurple],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text('Rekomendasi Karya',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                                      color: isDark ? AppTheme.textWhite : AppTheme.textDark)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.only(top: 14),
                      sliver: SliverToBoxAdapter(
                        child: SizedBox(
                          height: 240,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(horizontal: isWide ? 32 : 16),
                            itemCount: _featured.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 14),
                            itemBuilder: (ctx, i) => _buildFeaturedCard(_featured[i], isDark, i),
                          ),
                        ),
                      ),
                    ),
                  ],
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(isWide ? 32 : 16, 24, isWide ? 32 : 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: AnimatedEntrance(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [AppTheme.primaryPurple, AppTheme.lightPurple],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text('Semua Karya',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                                        color: isDark ? AppTheme.textWhite : AppTheme.textDark)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryPurple.withValues(alpha: isDark ? 0.15 : 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('${_items.length} karya',
                                  style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryPurple,
                                  )),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_items.isEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      sliver: SliverToBoxAdapter(
                        child: AnimatedEntrance(
                          child: AppEmptyState(
                            icon: Icons.storefront_outlined,
                            title: 'Belum Ada Karya',
                            subtitle: _searchCtrl.text.isNotEmpty
                                ? 'Tidak ada karya yang cocok dengan pencarian "${_searchCtrl.text}".'
                                : 'Karya kreator akan muncul di sini.',
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(isWide ? 32 : 16, 14, isWide ? 32 : 16, 20),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isWide ? 4 : 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.62,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _buildItemCard(_items[i], isDark, i),
                          childCount: _items.length,
                        ),
                      ),
                    ),
                  if (_isLoadingMore)
                    SliverPadding(
                      padding: const EdgeInsets.all(24),
                      sliver: SliverToBoxAdapter(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurple.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 12),
                                Text('Memuat lainnya...',
                                    style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
                ],
              ),
            ),
    );
  }

  Widget _buildSkeletonLoading(bool isDark, bool isWide) {
    return SkeletonAnimator(
      child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(isWide ? 32 : 16, 20, isWide ? 32 : 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _shimmerBox(isDark, 52, radius: 18),
              const SizedBox(height: 14),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 6,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _shimmerBox(isDark, 40, width: 80, radius: 12),
                ),
              ),
              const SizedBox(height: 24),
              _shimmerBox(isDark, 20, width: 160),
              const SizedBox(height: 14),
              SizedBox(
                height: 240,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (_, i) => _shimmerBox(isDark, 240, width: 250, radius: 22),
                ),
              ),
              const SizedBox(height: 24),
              _shimmerBox(isDark, 20, width: 120),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: isWide ? 4 : 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.62,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: List.generate(6, (_) => _shimmerBox(isDark, double.infinity, radius: 18)),
              ),
            ],
          ),
        )
    );
  }

  Widget _shimmerBox(bool isDark, double height, {double? width, double radius = 14}) {
    return SkeletonBox(
      width: width ?? double.infinity,
      height: height,
      borderRadius: radius,
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return AnimatedEntrance(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark2 : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _searchCtrl.text.isNotEmpty
                ? AppTheme.primaryPurple
                : (isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight),
            width: _searchCtrl.text.isNotEmpty ? 1.5 : 1,
          ),
          boxShadow: _searchCtrl.text.isNotEmpty
              ? [
                  BoxShadow(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onSubmitted: (_) => _onSearch(),
                onChanged: (_) => setState(() {}),
                style: TextStyle(
                  color: isDark ? AppTheme.textWhite : AppTheme.textDark,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Cari karya kreator, layanan, atau kategori...',
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted),
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            Pressable(
              onTap: _onSearch,
              pressedScale: 0.92,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryPurple, AppTheme.lightPurple],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.search_rounded, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips(bool isDark) {
    return AnimatedEntrance(
      delay: const Duration(milliseconds: 80),
      child: SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _allCategories.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (ctx, i) {
            final cat = _allCategories[i];
            final selected = cat == _selectedCategory;
            return Pressable(
              onTap: () => _onCategoryTap(cat),
              pressedScale: 0.95,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: AppMotion.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  gradient: selected ? const LinearGradient(
                    colors: [AppTheme.primaryPurple, AppTheme.lightPurple],
                  ) : null,
                  color: selected ? null : (isDark ? AppTheme.inputDark : AppTheme.inputLight),
                  borderRadius: BorderRadius.circular(12),
                  border: selected ? null : Border.all(
                    color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected) ...[
                      const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 5),
                    ],
                    Text(cat,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: selected
                              ? Colors.white
                              : (isDark ? AppTheme.textWhite : AppTheme.textDark),
                        )),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSortBar(bool isDark) {
    final options = {
      'latest': 'Terbaru',
      'popular': 'Terpopuler',
      'rating': 'Rating',
      'price_low': 'Harga ↑',
      'price_high': 'Harga ↓',
    };
    return AnimatedEntrance(
      delay: const Duration(milliseconds: 160),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Icon(Icons.sort_rounded, size: 18, color: AppTheme.textMuted),
            const SizedBox(width: 6),
            Text('Urutkan:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(width: 8),
            ...options.entries.map((e) {
              final selected = e.key == _sortBy;
              return Pressable(
                onTap: () => _onSortChange(e.key),
                pressedScale: 0.94,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primaryPurple.withValues(alpha: isDark ? 0.2 : 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: selected ? Border.all(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                    ) : null,
                  ),
                  child: Text(e.value, style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppTheme.primaryPurple : AppTheme.textMuted,
                  )),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedCard(MarketplaceItem item, bool isDark, int index) {
    return AnimatedEntrance(
      delay: Duration(milliseconds: 200 + index * 80),
      child: Pressable(
        onTap: () => _openDetail(item),
        child: HoverRaise(
          glowColor: AppTheme.primaryPurple,
          child: Container(
            width: 250,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardBg : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
              boxShadow: isDark ? AppTheme.cardShadowDark : AppTheme.cardShadowLight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF2D1B69), const Color(0xFF1E1B2E)]
                            : [const Color(0xFFEDE9FE), const Color(0xFFDDD6FE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(22),
                        topRight: Radius.circular(22),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: 12, top: 12,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurple.withValues(alpha: isDark ? 0.2 : 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.favorite_border, size: 16, color: AppTheme.primaryPurple),
                          ),
                        ),
                        Positioned(
                          left: 12, top: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurple.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(item.category,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryPurple,
                                )),
                          ),
                        ),
                        Center(
                          child: Icon(_categoryIcon(item.category),
                              size: 42, color: AppTheme.primaryPurple.withValues(alpha: isDark ? 0.6 : 0.5)),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Text(item.creator?.name ?? '',
                          style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMuted : Colors.grey.shade600)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.star_rounded, size: 14, color: Colors.amber.shade600),
                          const SizedBox(width: 4),
                          Text(item.rating.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          const Spacer(),
                          Text(item.formattedPrice,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
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
    );
  }

  Widget _buildItemCard(MarketplaceItem item, bool isDark, int index) {
    return AnimatedEntrance(
      delay: Duration(milliseconds: 300 + index * 50),
      child: Pressable(
        onTap: () => _openDetail(item),
        child: HoverRaise(
          glowColor: AppTheme.primaryPurple,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardBg : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
              boxShadow: isDark ? AppTheme.cardShadowDark : AppTheme.cardShadowLight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF2D1B69), const Color(0xFF1E1B2E)]
                            : [const Color(0xFFEDE9FE), const Color(0xFFDDD6FE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 10, top: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurple.withValues(alpha: isDark ? 0.2 : 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(item.category,
                                style: const TextStyle(
                                  color: AppTheme.primaryPurple,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                )),
                          ),
                        ),
                        Positioned(
                          right: 10, top: 10,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurple.withValues(alpha: isDark ? 0.2 : 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.favorite_border, size: 12, color: AppTheme.primaryPurple),
                          ),
                        ),
                        Center(
                          child: Icon(_categoryIcon(item.category),
                              size: 32, color: AppTheme.primaryPurple.withValues(alpha: isDark ? 0.6 : 0.5)),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(item.creator?.name ?? '',
                            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const Spacer(),
                        Row(
                          children: [
                            Icon(Icons.star_rounded, size: 12, color: Colors.amber.shade600),
                            const SizedBox(width: 3),
                            Text(item.rating.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            const Spacer(),
                            Text(item.formattedPrice,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryPurple,
                                )),
                          ],
                        ),
                        if (item.orderCount > 0) ...[
                          const SizedBox(height: 4),
                          Text('${item.orderCount} pesanan',
                              style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
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
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Fotografi': return Icons.camera_alt_rounded;
      case 'Videografi': return Icons.videocam_rounded;
      case 'Desain': return Icons.palette_rounded;
      case 'Konten': return Icons.edit_note_rounded;
      case 'Branding': return Icons.branding_watermark_rounded;
      default: return Icons.palette_rounded;
    }
  }
}
