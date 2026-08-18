import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../services/ai_service.dart';

/// Monochromatic Violet AI Report Summary Widget.
/// Uses tints/shades of AppTheme.primaryPurple for an ultra-clean, unified aesthetic.
class AiReportSummaryWidget extends StatefulWidget {
  final String title;
  final String content;
  final String contextType;

  const AiReportSummaryWidget({
    super.key,
    required this.title,
    required this.content,
    this.contextType = 'report',
  });

  @override
  State<AiReportSummaryWidget> createState() => _AiReportSummaryWidgetState();
}

class _AiReportSummaryWidgetState extends State<AiReportSummaryWidget> {
  bool _isLoading = false;
  Map<String, dynamic>? _aiData;
  String? _error;

  Future<void> _generateSummary() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final res = await AiService.summarizeReport(
      title: widget.title,
      content: widget.content,
      context: widget.contextType,
    );

    if (!mounted) return;

    if (res != null && AiService.isProSubscriptionRequiredError(res)) {
      setState(() {
        _isLoading = false;
        _error = 'Pro Subscription Required';
      });
      AiService.promptProUpgrade(context);
      return;
    }

    if (res != null && res['status'] == true && res['data'] != null) {
      setState(() {
        _isLoading = false;
        _aiData = res['data'];
      });
    } else {
      setState(() {
        _isLoading = false;
        _error = res?['message'] ?? 'Gagal membuat ringkasan AI.';
      });
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
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.18 : 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: accent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Ringkasan Laporan AI',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
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
                    'PRO / SUPER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: _aiData == null
                ? Column(
                    children: [
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.redAccent,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        'Dapatkan analisis mendalam dan ringkasan eksekutif laporan proyek secara instan menggunakan AI Service.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.white70 : Colors.black87,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _generateSummary,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 16,
                                ),
                          label: Text(
                            _isLoading
                                ? 'Memproses AI...'
                                : 'Buat Ringkasan AI',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary Paragraph
                      Text(
                        _aiData!['summary'] ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Highlights
                      if (_aiData!['key_highlights'] != null) ...[
                        const Text(
                          'Poin Kunci & Sorotan:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...(_aiData!['key_highlights'] as List).map(
                          (point) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '• ',
                                  style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    point.toString(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Action Item & Provider
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: isDark ? 0.12 : 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              color: accent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _aiData!['recommended_action'] ??
                                    'Rekomendasi disetujui.',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
