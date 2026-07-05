import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../services/dashboard_service.dart';
import 'stat_card.dart';

class DashboardStatsCharts extends StatefulWidget {
  final List<Map<String, dynamic>> subRoleList;
  final Map<String, List<Map<String, String>>> allSubRoleStats;
  final String selectedSubRole;
  final String currentRole;
  final bool isDark;

  const DashboardStatsCharts({
    super.key,
    required this.subRoleList,
    required this.allSubRoleStats,
    required this.selectedSubRole,
    required this.currentRole,
    required this.isDark,
  });

  @override
  State<DashboardStatsCharts> createState() => _DashboardStatsChartsState();
}

class _DashboardStatsChartsState extends State<DashboardStatsCharts> {
  late String _detailSelectedSlug;

  @override
  void initState() {
    super.initState();
    _detailSelectedSlug = widget.selectedSubRole;
  }

  @override
  void didUpdateWidget(DashboardStatsCharts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedSubRole != oldWidget.selectedSubRole) {
      setState(() {
        _detailSelectedSlug = widget.selectedSubRole;
      });
    }
  }

  List<Map<String, String>> _statsFor(String slug) =>
      widget.allSubRoleStats[slug] ?? [];

  Color _colorFor(String slug) {
    final match = widget.subRoleList.firstWhere(
      (p) => p['slug'] == slug,
      orElse: () => widget.subRoleList.first,
    );
    return match['color'] as Color;
  }

  String _nameFor(String slug) {
    final match = widget.subRoleList.firstWhere(
      (p) => p['slug'] == slug,
      orElse: () => widget.subRoleList.first,
    );
    return match['name'] as String;
  }

  @override
  Widget build(BuildContext context) {
    final selectedStats = _statsFor(widget.selectedSubRole);
    final detailStats = _statsFor(_detailSelectedSlug);
    final roleLabel = widget.currentRole == 'creator' ? 'Creator' : 'Klien';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selectedStats.isNotEmpty) ...[
          Text(
            'Grafik ${_nameFor(widget.selectedSubRole)} ($roleLabel)',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _SelectedCategoryChart(
            stats: selectedStats,
            accentColor: _colorFor(widget.selectedSubRole),
            isDark: widget.isDark,
          ),
          const SizedBox(height: 28),
        ],
        Text(
          'Perbandingan Semua Kategori ($roleLabel)',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Metrik utama setiap kategori subRole/peran',
          style: TextStyle(
            fontSize: 12,
            color: widget.isDark ? AppTheme.textMuted : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 12),
        _AllCategoriesBarChart(
          subRoleList: widget.subRoleList,
          allSubRoleStats: widget.allSubRoleStats,
          selectedSubRole: widget.selectedSubRole,
          isDark: widget.isDark,
        ),
        const SizedBox(height: 28),
        Text(
          'Detail Statistik per Kategori',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _CategorySlider(
          subRoleList: widget.subRoleList,
          allSubRoleStats: widget.allSubRoleStats,
          selectedSlug: _detailSelectedSlug,
          onCategorySelected: (slug) {
            setState(() {
              _detailSelectedSlug = slug;
            });
          },
          isDark: widget.isDark,
        ),
        const SizedBox(height: 16),
        if (detailStats.isNotEmpty)
          _CategoryDetailPanel(
            name: _nameFor(_detailSelectedSlug),
            slug: _detailSelectedSlug,
            color: _colorFor(_detailSelectedSlug),
            icon:
                widget.subRoleList.firstWhere(
                      (p) => p['slug'] == _detailSelectedSlug,
                      orElse: () => widget.subRoleList.first,
                    )['icon']
                    as IconData,
            stats: detailStats,
            isDark: widget.isDark,
          ),
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
        : (values.reduce((a, b) => a > b ? a : b) * 1.2).clamp(
            1.0,
            double.infinity,
          );

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
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (v, _) => Text(
                  v >= 1000
                      ? '${(v / 1000).toStringAsFixed(0)}k'
                      : v.toInt().toString(),
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
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
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
  final List<Map<String, dynamic>> subRoleList;
  final Map<String, List<Map<String, String>>> allSubRoleStats;
  final String selectedSubRole;
  final bool isDark;

  const _AllCategoriesBarChart({
    required this.subRoleList,
    required this.allSubRoleStats,
    required this.selectedSubRole,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final entries = subRoleList.map((p) {
      final slug = p['slug'] as String;
      final stats = allSubRoleStats[slug] ?? [];
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

    final maxValue = entries.isEmpty
        ? 0.0
        : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final maxX = maxValue <= 0
        ? 10.0
        : (maxValue * 1.15).clamp(1.0, double.infinity);

    return Container(
      height: isMobile ? 200 : 280,
      padding: EdgeInsets.fromLTRB(
        isMobile ? 4 : 8,
        isMobile ? 8 : 12,
        isMobile ? 8 : 16,
        isMobile ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: isMobile
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: entries.length * 60.0,
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
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: isMobile ? 40 : 56,
                          getTitlesWidget: (i, _) {
                            final index = i.toInt();
                            if (index >= entries.length)
                              return const SizedBox.shrink();
                            final e = entries[index];
                            return Padding(
                              padding: EdgeInsets.only(top: isMobile ? 4 : 6),
                              child: SizedBox(
                                width: isMobile ? 40 : 52,
                                child: Text(
                                  e.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: isMobile ? 7 : 8,
                                    fontWeight: e.slug == selectedSubRole
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: e.slug == selectedSubRole
                                        ? e.color
                                        : (isDark
                                              ? Colors.white70
                                              : Colors.grey.shade700),
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
                          reservedSize: isMobile ? 28 : 36,
                          getTitlesWidget: (v, _) => Text(
                            v >= 1000
                                ? '${(v / 1000).toStringAsFixed(0)}k'
                                : v.toInt().toString(),
                            style: TextStyle(
                              fontSize: isMobile ? 8 : 10,
                              color: isDark
                                  ? AppTheme.textMuted
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    barGroups: List.generate(entries.length, (i) {
                      final e = entries[i];
                      final isSelected = e.slug == selectedSubRole;
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: e.value,
                            color: e.color.withValues(
                              alpha: isSelected ? 1.0 : 0.55,
                            ),
                            width: isMobile
                                ? (isSelected ? 14 : 10)
                                : (isSelected ? 20 : 16),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(5),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            )
          : BarChart(
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
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: isMobile ? 40 : 56,
                      getTitlesWidget: (i, _) {
                        final index = i.toInt();
                        if (index >= entries.length)
                          return const SizedBox.shrink();
                        final e = entries[index];
                        return Padding(
                          padding: EdgeInsets.only(top: isMobile ? 4 : 6),
                          child: SizedBox(
                            width: isMobile ? 40 : 52,
                            child: Text(
                              e.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isMobile ? 7 : 8,
                                fontWeight: e.slug == selectedSubRole
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: e.slug == selectedSubRole
                                    ? e.color
                                    : (isDark
                                          ? Colors.white70
                                          : Colors.grey.shade700),
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
                      reservedSize: isMobile ? 28 : 36,
                      getTitlesWidget: (v, _) => Text(
                        v >= 1000
                            ? '${(v / 1000).toStringAsFixed(0)}k'
                            : v.toInt().toString(),
                        style: TextStyle(
                          fontSize: isMobile ? 8 : 10,
                          color: isDark
                              ? AppTheme.textMuted
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ),
                barGroups: List.generate(entries.length, (i) {
                  final e = entries[i];
                  final isSelected = e.slug == selectedSubRole;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: e.value,
                        color: e.color.withValues(
                          alpha: isSelected ? 1.0 : 0.55,
                        ),
                        width: isMobile
                            ? (isSelected ? 14 : 10)
                            : (isSelected ? 20 : 16),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5),
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

class _CategorySlider extends StatelessWidget {
  final List<Map<String, dynamic>> subRoleList;
  final Map<String, List<Map<String, String>>> allSubRoleStats;
  final String selectedSlug;
  final Function(String) onCategorySelected;
  final bool isDark;

  const _CategorySlider({
    required this.subRoleList,
    required this.allSubRoleStats,
    required this.selectedSlug,
    required this.onCategorySelected,
    required this.isDark,
  });

  List<Map<String, String>> _statsFor(String slug) =>
      allSubRoleStats[slug] ?? [];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: subRoleList.length,
        itemBuilder: (context, index) {
          final item = subRoleList[index];
          final slug = item['slug'] as String;
          final stats = _statsFor(slug);
          final isSelected = slug == selectedSlug;
          final color = item['color'] as Color;

          if (stats.isEmpty) return const SizedBox.shrink();

          return GestureDetector(
            onTap: () => onCategorySelected(slug),
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.15)
                    : (isDark ? AppTheme.cardBg : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? color
                      : (isDark ? AppTheme.inputBorder : Colors.transparent),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item['icon'] as IconData,
                    color: isSelected ? color : Colors.grey.shade600,
                    size: 20,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['name'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? (isDark ? Colors.white : color)
                          : (isDark
                                ? AppTheme.textMuted
                                : Colors.grey.shade700),
                    ),
                  ),
                  Text(
                    '${stats.length} metrik',
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryDetailPanel extends StatelessWidget {
  final String name;
  final String slug;
  final Color color;
  final IconData icon;
  final List<Map<String, String>> stats;
  final bool isDark;

  const _CategoryDetailPanel({
    required this.name,
    required this.slug,
    required this.color,
    required this.icon,
    required this.stats,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossCount = screenWidth > 900 ? 4 : 2;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${stats.length} metrik',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: _MiniSparklineChart(
              stats: stats,
              color: color,
              isDark: isDark,
            ),
          ),
          const SizedBox(height: 16),
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
    final finalMinY = safeMinY >= safeMaxY
        ? (safeMaxY > 0 ? 0.0 : -1.0)
        : safeMinY;
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
              getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
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
