import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../app/app_animations.dart';
import '../models/opportunity_model.dart';
import '../services/opportunity_service.dart';
import '../widgets/app_status_widgets.dart';
import '../widgets/app_empty_state.dart';

class DaftarKebutuhanScreen extends StatefulWidget {
  const DaftarKebutuhanScreen({super.key});

  @override
  State<DaftarKebutuhanScreen> createState() => _DaftarKebutuhanScreenState();
}

class _DaftarKebutuhanScreenState extends State<DaftarKebutuhanScreen> {
  List<OpportunityModel> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await OpportunityService.getOpportunities(
        type: 'project',
        limit: 50,
      );
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal memuat kebutuhan. Silakan coba lagi.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Daftar Kebutuhan',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_loading) {
      return const AppLoadingState(message: 'Memuat kebutuhan...');
    }

    if (_error != null) {
      return AppErrorState(
        message: _error!,
        onRetry: _load,
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 48,
                  color: AppTheme.primaryPurple.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Belum ada kebutuhan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kebutuhan yang Anda buat akan muncul di sini.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primaryPurple,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _items.length,
        itemBuilder: (ctx, i) {
          return AnimatedEntrance(
            delay: Duration(milliseconds: 50 * i),
            child: _KebutuhanCard(item: _items[i]),
          );
        },
      ),
    );
  }
}

// ─── Kebutuhan Card ───────────────────────────────────────────────────────────

class _KebutuhanCard extends StatelessWidget {
  final OpportunityModel item;
  const _KebutuhanCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Pressable(
      onTap: () {
        // TODO: navigate to detail
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(
            color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: Kategori badge + Status ──
            Row(
              children: [
                _KategoriBadge(slug: item.subRoleSlug),
                const Spacer(),
                _StatusBadge(status: item.status),
              ],
            ),
            const SizedBox(height: 12),

            // ── Title ──
            Text(
              item.title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // ── Description ──
            if (item.description != null && item.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                item.description!,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : Colors.grey.shade500,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),

            // ── Meta row ──
            Row(
              children: [
                if (item.budgetRange != null) ...[
                  _MetaChip(
                    icon: Icons.payments_rounded,
                    label: item.budgetRange!,
                  ),
                  const SizedBox(width: 8),
                ],
                if (item.deadline != null)
                  _MetaChip(
                    icon: Icons.event_rounded,
                    label: item.deadline!,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Kategori Badge ───────────────────────────────────────────────────────────

class _KategoriBadge extends StatelessWidget {
  final String slug;
  const _KategoriBadge({required this.slug});

  @override
  Widget build(BuildContext context) {
    final label = _labelFromSlug(slug);
    final color = _colorFromSlug(slug);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  String _labelFromSlug(String slug) {
    switch (slug) {
      case 'fotografi':
        return 'Fotografi';
      case 'videografi':
        return 'Videografi';
      case 'desain-grafis':
        return 'Desain Grafis';
      case 'konten-kreator':
        return 'Konten Kreator';
      default:
        return slug.isNotEmpty ? slug[0].toUpperCase() + slug.substring(1) : 'Lainnya';
    }
  }

  Color _colorFromSlug(String slug) {
    switch (slug) {
      case 'fotografi':
        return const Color(0xFF3B82F6);
      case 'videografi':
        return const Color(0xFFEC4899);
      case 'desain-grafis':
        return const Color(0xFFF59E0B);
      case 'konten-kreator':
        return const Color(0xFF10B981);
      default:
        return AppTheme.primaryPurple;
    }
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == 'open' ? AppTheme.success : AppTheme.textMuted;
    final label = status == 'open' ? 'Aktif' : 'Selesai';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Meta Chip ────────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white54 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
