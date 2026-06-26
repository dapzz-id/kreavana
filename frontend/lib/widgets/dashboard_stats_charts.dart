import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../services/dashboard_service.dart';
import 'stat_card.dart';

class DashboardStatsCharts extends StatelessWidget {
  final List<Map<String, dynamic>> pihakList;
  final Map<String, List<Map<String, String>>> allPihakStats;
  final String selectedPihak;
  final String currentRole;
  final bool isDark;

  const DashboardStatsCharts({
    super.key,
    required this.pihakList,
    required this.allPihakStats,
    required this.selectedPihak,
    required this.currentRole,
    required this.isDark,
  });

  List<Map<String, String>> _statsFor(String slug) =>
      allPihakStats[slug] ?? [];

  Color _colorFor(String slug) {
    final match = pihakList.firstWhere(
      (p) => p['slug'] == slug,
      orElse: () => pihakList.first,
    );
    return match['color'] as Color;
  }

  String _nameFor(String slug) {
    final match = pihakList.firstWhere(
      (p) => p['slug'] == slug,
      orElse: () => pihakList.first,
    );
    return match['name'] as String;
  }

  @override
  Widget build(BuildContext context) {
    final selectedStats = _statsFor(selectedPihak);
    final roleLabel = currentRole == 'creator' ? 'Creator' : 'Klien';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selectedStats.isNotEmpty) ...[
          Text(
            'Grafik ${_nameFor(selectedPihak)} ($roleLabel)',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _SelectedCategoryChart(
            stats: selectedStats,
            accentColor: _colorFor(selectedPihak),
            isDark: isDark,
          ),
          const SizedBox(height: 28),
        ],
        Text(
          'Perbandingan Semua Kategori ($roleLabel)',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Metrik utama setiap kategori pihak/peran',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 12),
        _AllCategoriesBarChart(
          pihakList: pihakList,
          allPihakStats: allPihakStats,
          selectedPihak: selectedPihak,
          isDark: isDark,
        ),
        const SizedBox(height: 28),
        Text(
          'Detail Statistik per Kategori',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...pihakList.map((pihak) {
          final slug = pihak['slug'] as String;
          final stats = _statsFor(slug);
          if (stats.isEmpty) return const SizedBox.shrink();
          return _CategoryStatsPanel(
            name: pihak['name'] as String,
            slug: slug,
            color: pihak['color'] as Color,
            stats: stats,
            isSelected: slug == selectedPihak,
            isDark: isDark,
          );
        }),
      ],
    );
  }
}

class _SelectedCategoryChart extends StatelessWidget {
  final List<Map<String, String>> stats;
  final Color accentColor;
  final bool isDark;

  const _SelectedCategoryChart({
    required this.stats,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final values = stats
        .map((s) => DashboardService.parseStatNumeric(s['value'] ?? '0'))
        .toList();
    final maxY = values.isEmpty
        ? 10.0
        : (values.reduce((a, b) => a > b ? a : b) * 1.2).clamp(1.0, double.infinity);

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY / 4) > 0 ? (maxY / 4) : 1.0,
            getDrawingHorizontalLine: (v) => FlLine(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (v, _) => Text(
                  v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toInt().toString(),
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                getTitlesWidget: (i, _) {
                  if (i.toInt() >= stats.length) return const SizedBox.shrink();
                  final label = stats[i.toInt()]['label'] ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: 56,
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(stats.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  color: accentColor.withValues(alpha: 0.85),
                  width: 22,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY,
                    color: accentColor.withValues(alpha: 0.08),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _AllCategoriesBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> pihakList;
  final Map<String, List<Map<String, String>>> allPihakStats;
  final String selectedPihak;
  final bool isDark;

  const _AllCategoriesBarChart({
    required this.pihakList,
    required this.allPihakStats,
    required this.selectedPihak,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final entries = pihakList.map((p) {
      final slug = p['slug'] as String;
      final stats = allPihakStats[slug] ?? [];
      final value = stats.isEmpty
          ? 0.0
          : DashboardService.parseStatNumeric(stats.first['value'] ?? '0');
      return (
        slug: slug,
        name: p['name'] as String,
        color: p['color'] as Color,
        value: value,
        label: stats.isEmpty ? '-' : (stats.first['label'] ?? ''),
      );
    }).toList();

    final maxValue = entries.isEmpty ? 0.0 : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final maxX = maxValue <= 0
        ? 10.0
        : (maxValue * 1.15).clamp(1.0, double.infinity);

    return Container(
      height: 280,
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxX,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxX > 0 ? maxX / 4 : 1.0,
            getDrawingHorizontalLine: (v) => FlLine(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 56,
                getTitlesWidget: (i, _) {
                  final index = i.toInt();
                  if (index >= entries.length) return const SizedBox.shrink();
                  final e = entries[index];
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: SizedBox(
                      width: 52,
                      child: Text(
                        e.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: e.slug == selectedPihak
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: e.slug == selectedPihak
                              ? e.color
                              : (isDark ? Colors.white70 : Colors.grey.shade700),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (v, _) => Text(
                  v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toInt().toString(),
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ),
          barGroups: List.generate(entries.length, (i) {
            final e = entries[i];
            final isSelected = e.slug == selectedPihak;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: e.value,
                  color: e.color.withValues(alpha: isSelected ? 1.0 : 0.55),
                  width: isSelected ? 20 : 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _CategoryStatsPanel extends StatelessWidget {
  final String name;
  final String slug;
  final Color color;
  final List<Map<String, String>> stats;
  final bool isSelected;
  final bool isDark;

  const _CategoryStatsPanel({
    required this.name,
    required this.slug,
    required this.color,
    required this.stats,
    required this.isSelected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossCount = screenWidth > 900 ? 4 : 2;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? color : (isDark ? AppTheme.inputBorder : Colors.grey.shade200),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isSelected,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.insights, color: color, size: 20),
          ),
          title: Text(
            name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? color : null,
            ),
          ),
          subtitle: Text(
            '${stats.length} metrik • ketuk untuk lihat grafik & angka',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          children: [
            SizedBox(
              height: 140,
              child: _MiniSparklineChart(stats: stats, color: color, isDark: isDark),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossCount,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: screenWidth > 900 ? 2.2 : 1.6,
              ),
              itemCount: stats.length,
              itemBuilder: (context, index) {
                final stat = stats[index];
                return StatCard(
                  label: stat['label'] ?? '',
                  value: stat['value'] ?? '',
                  iconName: stat['icon'] ?? '',
                  accentColor: color,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniSparklineChart extends StatelessWidget {
  final List<Map<String, String>> stats;
  final Color color;
  final bool isDark;

  const _MiniSparklineChart({
    required this.stats,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final spots = stats.asMap().entries.map((e) {
      return FlSpot(
        e.key.toDouble(),
        DashboardService.parseStatNumeric(e.value['value'] ?? '0'),
      );
    }).toList();

    if (spots.isEmpty) return const SizedBox.shrink();

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);

    final safeMinY = (minY * 0.9).clamp(0.0, double.infinity);
    final safeMaxY = maxY > 0 ? maxY * 1.1 : 10.0;
    
    // Ensure minY < maxY as required by fl_chart
    final finalMinY = safeMinY >= safeMaxY ? (safeMaxY > 0 ? 0.0 : -1.0) : safeMinY;
    final finalMaxY = safeMinY >= safeMaxY && safeMaxY == 0 ? 10.0 : safeMaxY;

    return LineChart(
      LineChartData(
        minY: finalMinY,
        maxY: finalMaxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: finalMaxY > 0 ? finalMaxY / 4 : 1.0,
          getDrawingHorizontalLine: (v) => FlLine(
            color: isDark ? Colors.white10 : Colors.grey.shade100,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 4,
                color: color,
                strokeWidth: 2,
                strokeColor: isDark ? AppTheme.cardBg : Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
