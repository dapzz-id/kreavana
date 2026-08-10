import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../services/portfolio_service.dart';
import '../services/api_service.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/skeleton_loader.dart';

class PortfolioScreen extends StatefulWidget {
  final UserModel? user;
  
  const PortfolioScreen({super.key, this.user});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  List<PortfolioItemModel> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPortfolio();
  }

  Future<void> _loadPortfolio() async {
    setState(() => _isLoading = true);
    try {
      final items = await PortfolioService.getPortfolio();
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('Portfolio Saya', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? AppTheme.cardBg : Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Tambah Portfolio',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fitur tambah portfolio belum tersedia secara penuh di halaman ini.')),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? GridView.builder(
              padding: const EdgeInsets.all(16),
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: 6,
              itemBuilder: (context, index) {
                return const SkeletonLoader(
                  height: double.infinity,
                  borderRadius: 16,
                );
              },
            )
          : _items.isEmpty
              ? AppEmptyState(
                  icon: Icons.photo_library_outlined,
                  title: 'Belum Ada Portfolio',
                  subtitle: 'Anda belum menambahkan karya apapun ke portfolio.',
                  onAction: _loadPortfolio,
                  actionLabel: 'Muat Ulang',
                )
              : RefreshIndicator(
                  onRefresh: _loadPortfolio,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _buildPortfolioCard(item, isDark);
                    },
                  ),
                ),
    );
  }

  Widget _buildPortfolioCard(PortfolioItemModel item, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: item.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: ApiService.resolveAssetUrl(item.imageUrl!),
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const SkeletonLoader(
                      height: double.infinity,
                      borderRadius: 0,
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey.withValues(alpha: 0.2),
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  )
                : Container(
                    color: Colors.grey.withValues(alpha: 0.2),
                    child: const Icon(Icons.image_outlined, color: Colors.grey, size: 40),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.category != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.category!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
