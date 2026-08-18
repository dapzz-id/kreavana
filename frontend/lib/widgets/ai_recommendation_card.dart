import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../services/ai_service.dart';

/// Monochromatic Violet AI Recommendation Card Widget.
/// Uses tints/shades of AppTheme.primaryPurple for an ultra-clean, unified aesthetic.
class AiRecommendationCard extends StatefulWidget {
  final String role;
  final String niche;

  const AiRecommendationCard({
    super.key,
    this.role = 'creator',
    this.niche = 'Kreatif',
  });

  @override
  State<AiRecommendationCard> createState() => _AiRecommendationCardState();
}

class _AiRecommendationCardState extends State<AiRecommendationCard> {
  bool _isLoading = false;
  List<dynamic>? _recommendations;

  Future<void> _fetchRecommendations() async {
    setState(() => _isLoading = true);

    final res = await AiService.getRecommendations(
      role: widget.role,
      niche: widget.niche,
    );

    if (!mounted) return;

    if (res != null && AiService.isProSubscriptionRequiredError(res)) {
      setState(() => _isLoading = false);
      AiService.promptProUpgrade(context);
      return;
    }

    if (res != null && res['status'] == true && res['data'] != null) {
      final recs = res['data']['recommendations'] as List?;
      setState(() {
        _isLoading = false;
        _recommendations = recs;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = AppTheme.primaryPurple;
    final cardBg = isDark ? const Color(0xFF13111F) : const Color(0xFFFAF9FE);
    final borderColor = isDark
        ? const Color(0xFF2D264A)
        : const Color(0xFFE4DEF6);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.12 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rekomendasi AI Strategis',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Saran personalisasi untuk mempercepat hasil kerja (${widget.niche})',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Padding(
            padding: const EdgeInsets.all(16),
            child: _recommendations == null
                ? SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _fetchRecommendations,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: accent,
                              ),
                            )
                          : const Icon(
                              Icons.auto_awesome_rounded,
                              size: 16,
                              color: accent,
                            ),
                      label: Text(
                        _isLoading
                            ? 'Menganalisis Rekomendasi...'
                            : 'Dapatkan Rekomendasi AI',
                        style: const TextStyle(
                          color: accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: accent, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  )
                : Column(
                    children: _recommendations!.map((rec) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1B182B)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.stars_rounded,
                                  color: accent,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    rec['title'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              rec['reason'] ?? '',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Dampak: ${rec['impact'] ?? ''}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
