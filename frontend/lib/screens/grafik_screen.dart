import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../widgets/desktop_sidebar_layout.dart';
import '../services/user_store.dart';

class GrafikScreen extends StatefulWidget {
  final UserModel? user;

  const GrafikScreen({super.key, this.user});

  @override
  State<GrafikScreen> createState() => _GrafikScreenState();
}

class _GrafikScreenState extends State<GrafikScreen> {
  String _selectedPeriod = 'Bulan Ini';
  int _selectedChartTab = 0; // 0: Tren Finansial, 1: Volume Proyek, 2: Kategori & Status
  int _touchedPieIndex = -1;

  bool get _isCreator =>
      widget.user?.role == 'creator' || widget.user?.isCreator == true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = _isCreator ? const Color(0xFF7C3AED) : const Color(0xFF2563EB);
    final effectiveUser = widget.user ?? currentUserNotifier.value;

    final scaffold = Scaffold(
      backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.insert_chart_rounded, color: accentColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isCreator ? 'Grafik & Analisis Kreator' : 'Grafik & Analisis Proyek',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    'Klik metrik atau grafik mana pun untuk melihat rincian lengkap',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPeriod,
                dropdownColor: isDark ? AppTheme.cardDark : Colors.white,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                items: ['7 Hari Terakhir', 'Bulan Ini', 'Kuartal Ini', 'Tahun Ini']
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPeriod = val);
                },
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── TOP SUMMARY CARDS (CLICKABLE) ──────────────────────────────
            _buildInteractiveSummaryCards(isDark, accentColor),
            const SizedBox(height: 20),

            // ── CHART TABS SWITCHER ─────────────────────────────────────────
            _buildChartTabs(isDark, accentColor),
            const SizedBox(height: 16),

            // ── MAIN CHART CONTAINER (CLICKABLE) ───────────────────────────
            _buildMainActiveChart(isDark, accentColor),
            const SizedBox(height: 24),

            // ── CATEGORY & STATUS DISTRIBUTION ──────────────────────────────
            _buildDistributionSection(isDark, accentColor),
            const SizedBox(height: 24),

            // ── ECOSYSTEM BENCHMARK COMPARISON ─────────────────────────────
            _buildEcosystemComparison(isDark, accentColor),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );

    if (effectiveUser != null) {
      return DesktopSidebarLayout(
        user: effectiveUser,
        activeRoute: 'grafik',
        child: scaffold,
      );
    }

    return scaffold;
  }

  // ── 1. KPI SUMMARY CARDS ───────────────────────────────────────────────────
  Widget _buildInteractiveSummaryCards(bool isDark, Color accentColor) {
    final kpis = _isCreator
        ? [
            {
              'title': 'Pendapatan Bersih',
              'value': 'Rp 18.450.000',
              'trend': '↑ +24.5%',
              'trendColor': const Color(0xFF10B981),
              'icon': Icons.account_balance_wallet_rounded,
              'color': const Color(0xFF7C3AED),
              'details': [
                'Pembayaran Selesai: Rp 14.200.000 (8 transaksi)',
                'Dana Tertahan Escrow: Rp 4.250.000 (2 kontrak aktif)',
                'Rata-rata Nilai Kontrak: Rp 1.845.000 / proyek',
              ],
              'insight': 'Pendapatan Anda meningkat stabil berkat kenaikan repeat order 18% bulan ini.',
            },
            {
              'title': 'Proyek Selesai',
              'value': '14 Proyek',
              'trend': '↑ +4 proyek',
              'trendColor': const Color(0xFF10B981),
              'icon': Icons.task_alt_rounded,
              'color': const Color(0xFF10B981),
              'details': [
                'On-Time Delivery Rate: 98.2%',
                'Revisi Rata-rata: 1.1x per pekerjaan',
                'Status: 14 Selesai, 3 Sedang Berjalan',
              ],
              'insight': 'Kecepatan penyelesaian kerja Anda masuk dalam top 5% kreator di sub-role Anda.',
            },
            {
              'title': 'Win Rate Proposal',
              'value': '72.4%',
              'trend': '↑ +8.1%',
              'trendColor': const Color(0xFF10B981),
              'icon': Icons.bolt_rounded,
              'color': const Color(0xFFF59E0B),
              'details': [
                'Proposal Terkirim: 29 pengajuan',
                'Diterima Klien: 21 proyek',
                'Waktu Respons Klien Rata-rata: 3.5 jam',
              ],
              'insight': 'Pitching yang menyertakan tautan portofolio terbukti menaikkan konversi hingga 3x lipat.',
            },
            {
              'title': 'Kepuasan & Rating',
              'value': '4.92 / 5.0',
              'trend': '★ 38 Ulasan',
              'trendColor': const Color(0xFFD97706),
              'icon': Icons.star_rounded,
              'color': const Color(0xFFEC4899),
              'details': [
                'Bintang 5: 35 ulasan (92%)',
                'Bintang 4: 3 ulasan (8%)',
                'Indeks Klien Puas: 99.4%',
              ],
              'insight': 'Klien sangat mengapresiasi komunikasi cepat dan kejelasan revisi dari Anda.',
            },
          ]
        : [
            {
              'title': 'Total Pengeluaran',
              'value': 'Rp 22.800.000',
              'trend': '↓ -12% efisien',
              'trendColor': const Color(0xFF10B981),
              'icon': Icons.payments_rounded,
              'color': const Color(0xFF2563EB),
              'details': [
                'Terbayar ke Kreator: Rp 16.500.000',
                'Dana Diamankan Escrow: Rp 6.300.000',
                'Efisiensi Anggaran: 12% di bawah batas pagu',
              ],
              'insight': 'Anggaran proyek terkendali dengan sangat baik melalui sistem pembayaran bertahap Kreavana.',
            },
            {
              'title': 'Kebutuhan & Proyek',
              'value': '9 Kebutuhan',
              'trend': '↑ +2 minggu ini',
              'trendColor': const Color(0xFF2563EB),
              'icon': Icons.assignment_turned_in_rounded,
              'color': const Color(0xFF10B981),
              'details': [
                'Proyek Berjalan: 4 event/kontrak',
                'Proyek Selesai: 5 kebutuhan',
                'Kebutuhan Terbuka: 2 kebutuhan baru',
              ],
              'insight': 'Sebagian besar proyek Anda selesai sesuai tenggat waktu rundown yang ditentukan.',
            },
            {
              'title': 'Kreator Terhubung',
              'value': '16 Kreator',
              'trend': '✦ 5 Sub-Role',
              'trendColor': const Color(0xFF8B5CF6),
              'icon': Icons.people_alt_rounded,
              'color': const Color(0xFF7C3AED),
              'details': [
                'Fotografer & Videografer: 8 orang',
                'Event / Wedding Organizer: 4 tim',
                'Editor & Desainer: 4 orang',
              ],
              'insight': 'Kreator favorit Anda tersedia untuk direct repeat order tanpa seleksi proposal ulang.',
            },
            {
              'title': 'Efisiensi Waktu Hire',
              'value': '1.8 Hari',
              'trend': '⚡ 40% lebih cepat',
              'trendColor': const Color(0xFF10B981),
              'icon': Icons.speed_rounded,
              'color': const Color(0xFFF59E0B),
              'details': [
                'Rata-rata Waktu Dapat Kreator: 42 jam',
                'Proposal Masuk per Kebutuhan: 6-8 pelamar',
                'Keamanan Transaksi: 100% Escrow Garansi',
              ],
              'insight': 'Penggunaan fitur AI matchmaker mempercepat pencarian talenta secara signifikan.',
            },
          ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;
        final cardWidth = isMobile
            ? (constraints.maxWidth - 10) / 2
            : (constraints.maxWidth - 36) / 4;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: kpis.map((kpi) {
            return SizedBox(
              width: cardWidth,
              child: Material(
                color: isDark ? AppTheme.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                elevation: 0,
                child: InkWell(
                  onTap: () => _showKpiDetailDialog(kpi, isDark),
                  borderRadius: BorderRadius.circular(16),
                  hoverColor: (kpi['color'] as Color).withValues(alpha: 0.08),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (kpi['color'] as Color).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                kpi['icon'] as IconData,
                                color: kpi['color'] as Color,
                                size: 18,
                              ),
                            ),
                            Icon(Icons.info_outline_rounded,
                                size: 16,
                                color: isDark ? Colors.white38 : Colors.grey.shade400),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          kpi['title'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            kpi['value'] as String,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              kpi['trend'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: kpi['trendColor'] as Color,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Klik info →',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.white38 : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ── 2. CHART TABS ──────────────────────────────────────────────────────────
  Widget _buildChartTabs(bool isDark, Color accentColor) {
    final tabs = [
      {'label': _isCreator ? 'Tren Pendapatan' : 'Tren Pengeluaran', 'icon': Icons.trending_up_rounded},
      {'label': 'Volume Proyek', 'icon': Icons.bar_chart_rounded},
      {'label': 'Komposisi Kategori', 'icon': Icons.pie_chart_outline_rounded},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: List.generate(tabs.length, (idx) {
          final isSelected = _selectedChartTab == idx;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedChartTab = idx),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? accentColor.withValues(alpha: 0.3) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected && !isDark
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tabs[idx]['icon'] as IconData,
                      size: 16,
                      color: isSelected ? accentColor : (isDark ? AppTheme.textMuted : Colors.grey.shade600),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        tabs[idx]['label'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? (isDark ? Colors.white : accentColor)
                              : (isDark ? AppTheme.textMuted : Colors.grey.shade700),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── 3. MAIN ACTIVE CHART CONTAINER ─────────────────────────────────────────
  Widget _buildMainActiveChart(bool isDark, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedChartTab == 0
                        ? (_isCreator ? 'Grafik Pertumbuhan Finansial (Rp)' : 'Grafik Alokasi Dana Proyek (Rp)')
                        : (_selectedChartTab == 1
                            ? 'Distribusi Volume & Status Proyek Bulanan'
                            : 'Komposisi Kategori Layanan'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Sentuh titik / bar untuk rincian data detail',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app_rounded, size: 14, color: accentColor),
                    const SizedBox(width: 4),
                    Text(
                      'Interaktif',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accentColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 240,
            child: _selectedChartTab == 0
                ? _buildFinancialLineChart(isDark, accentColor)
                : (_selectedChartTab == 1
                    ? _buildProjectVolumeBarChart(isDark, accentColor)
                    : _buildCategoryPieChart(isDark, accentColor)),
          ),
        ],
      ),
    );
  }

  // Financial Line Chart
  Widget _buildFinancialLineChart(bool isDark, Color accentColor) {
    final spots = [
      const FlSpot(0, 8.5),
      const FlSpot(1, 10.2),
      const FlSpot(2, 9.8),
      const FlSpot(3, 14.5),
      const FlSpot(4, 15.8),
      const FlSpot(5, 18.45),
    ];
    final months = ['Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt'];

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 5,
        minY: 0,
        maxY: 24,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 6,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: 6,
              getTitlesWidget: (val, _) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  '${val.toInt()}Jt',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (val, _) {
                final idx = val.toInt();
                if (idx >= 0 && idx < months.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      months[idx],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchCallback: (event, response) {
            if (event is FlTapUpEvent && response?.lineBarSpots != null && response!.lineBarSpots!.isNotEmpty) {
              final spot = response.lineBarSpots!.first;
              final idx = spot.spotIndex;
              final monthName = months[idx];
              final amountStr = 'Rp ${spot.y.toStringAsFixed(1)} Juta';
              _showChartDataDetailDialog(
                title: 'Data Finansial Bulan $monthName',
                subtitle: _isCreator ? 'Pendapatan Bersih Kreator' : 'Pengeluaran Klien',
                value: amountStr,
                growthText: idx > 0 ? '+${((spot.y - spots[idx - 1].y) / spots[idx - 1].y * 100).toStringAsFixed(1)}% vs bulan lalu' : 'Periode dasar',
                tips: _isCreator
                    ? 'Bulan $monthName memiliki volume transaksi tinggi berkat proyek event dan repeat order teratur.'
                    : 'Pengeluaran proyek pada bulan $monthName dialokasikan secara aman melalui escrow sistem Kreavana.',
                isDark: isDark,
              );
            }
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((s) {
                return LineTooltipItem(
                  '${months[s.spotIndex]}: Rp ${s.y} Juta\n(Klik untuk detail)',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: accentColor,
            barWidth: 3.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 5,
                color: Colors.white,
                strokeWidth: 3,
                strokeColor: accentColor,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  accentColor.withValues(alpha: 0.35),
                  accentColor.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Project Volume Bar Chart
  Widget _buildProjectVolumeBarChart(bool isDark, Color accentColor) {
    final months = ['Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt'];
    final completed = [4.0, 6.0, 5.0, 9.0, 11.0, 14.0];
    final active = [2.0, 3.0, 2.0, 4.0, 3.0, 3.0];

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 20,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 5,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 5,
              getTitlesWidget: (v, _) => Text(
                '${v.toInt()}',
                style: TextStyle(fontSize: 10, color: isDark ? AppTheme.textMuted : Colors.grey.shade600),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx >= 0 && idx < months.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      months[idx],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchCallback: (event, response) {
            if (event is FlTapUpEvent && response?.spot != null) {
              final idx = response!.spot!.touchedBarGroupIndex;
              final mName = months[idx];
              final cVal = completed[idx].toInt();
              final aVal = active[idx].toInt();
              _showChartDataDetailDialog(
                title: 'Volume Proyek Bulan $mName',
                subtitle: 'Aktivitas Ekosistem Proyek',
                value: '$cVal Selesai + $aVal Sedang Berjalan',
                growthText: 'Total: ${cVal + aVal} proyek ditangani',
                tips: 'Tingkat penyelesaian sukses mencapai 94%. Mempertahankan komunikasi rutin mempercepat serah terima file.',
                isDark: isDark,
              );
            }
          },
        ),
        barGroups: List.generate(months.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: completed[i],
                color: accentColor,
                width: 14,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
              BarChartRodData(
                toY: active[i],
                color: const Color(0xFF10B981),
                width: 14,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          );
        }),
      ),
    );
  }

  // Category Pie Chart
  Widget _buildCategoryPieChart(bool isDark, Color accentColor) {
    final categories = [
      {'name': 'Fotografi & Dokumentasi', 'pct': 38.0, 'color': const Color(0xFF7C3AED)},
      {'name': 'Videografi & Reels', 'pct': 28.0, 'color': const Color(0xFF3B82F6)},
      {'name': 'Event & Wedding Planner', 'pct': 20.0, 'color': const Color(0xFF10B981)},
      {'name': 'Desain & Editing Grafis', 'pct': 14.0, 'color': const Color(0xFFF59E0B)},
    ];

    return Row(
      children: [
        Expanded(
          flex: 5,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 36,
              sections: List.generate(categories.length, (i) {
                final isSelected = _touchedPieIndex == i;
                final cat = categories[i];
                return PieChartSectionData(
                  value: cat['pct'] as double,
                  color: cat['color'] as Color,
                  radius: isSelected ? 48 : 40,
                  title: '${(cat['pct'] as double).toInt()}%',
                  titleStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }),
              pieTouchData: PieTouchData(
                touchCallback: (event, pieResponse) {
                  setState(() {
                    if (event is FlTapUpEvent && pieResponse?.touchedSection != null) {
                      _touchedPieIndex = pieResponse!.touchedSection!.touchedSectionIndex;
                      final cat = categories[_touchedPieIndex];
                      _showChartDataDetailDialog(
                        title: 'Kategori: ${cat['name']}',
                        subtitle: 'Pangsa Kontrak & Proyek',
                        value: '${cat['pct']}% dari total pekerjaan',
                        growthText: 'Paling diminati oleh klien bisnis & UMKM',
                        tips: 'Kategori ini memiliki permintaan repeat order tertinggi di Kreavana bulan ini.',
                        isDark: isDark,
                      );
                    } else if (event is! FlPointerHoverEvent) {
                      _touchedPieIndex = -1;
                    }
                  });
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: categories.map((cat) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: InkWell(
                  onTap: () {
                    _showChartDataDetailDialog(
                      title: 'Kategori: ${cat['name']}',
                      subtitle: 'Pangsa Kontrak & Proyek',
                      value: '${cat['pct']}% dari total pekerjaan',
                      growthText: 'Paling diminati oleh klien bisnis & UMKM',
                      tips: 'Kategori ini memiliki permintaan repeat order tertinggi di Kreavana bulan ini.',
                      isDark: isDark,
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: cat['color'] as Color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            cat['name'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${(cat['pct'] as double).toInt()}%',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── 4. CATEGORY DISTRIBUTION SECTION ───────────────────────────────────────
  Widget _buildDistributionSection(bool isDark, Color accentColor) {
    final statusItems = [
      {'status': 'Selesai & Lunas', 'count': '14', 'color': const Color(0xFF10B981), 'share': '70%'},
      {'status': 'Sedang Berjalan (In Progress)', 'count': '4', 'color': const Color(0xFF3B82F6), 'share': '20%'},
      {'status': 'Dalam Review & Revisi', 'count': '1', 'color': const Color(0xFFF59E0B), 'share': '5%'},
      {'status': 'Menunggu Konfirmasi', 'count': '1', 'color': const Color(0xFF8B5CF6), 'share': '5%'},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Status & Pipeline Pekerjaan',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Text(
                'Total: 20 Proyek',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            children: statusItems.map((item) {
              return InkWell(
                onTap: () {
                  _showChartDataDetailDialog(
                    title: 'Status: ${item['status']}',
                    subtitle: 'Rincian Status Proyek',
                    value: '${item['count']} Pekerjaan (${item['share']})',
                    growthText: 'Kelola alur pekerjaan agar terus lancar',
                    tips: 'Pastikan upload file hasil kerja tepat waktu untuk mempercepat pelepasan dana escrow.',
                    isDark: isDark,
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: item['color'] as Color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item['status'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (item['color'] as Color).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${item['count']} item (${item['share']})',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: item['color'] as Color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right_rounded,
                          size: 16, color: isDark ? Colors.white38 : Colors.grey.shade400),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── 5. ECOSYSTEM BENCHMARK COMPARISON ──────────────────────────────────────
  Widget _buildEcosystemComparison(bool isDark, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.insights_rounded, color: AppTheme.primaryPurple, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Performa & Rata-rata Industri',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Top 10% Kreavana',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Bandingkan indikator performa Anda dengan standar kreator profesional di ekosistem Kreavana:',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          _buildBenchmarkRow(
            label: 'On-Time Delivery',
            myValue: '98.2%',
            avgValue: '88.5%',
            isBetter: true,
            isDark: isDark,
          ),
          const Divider(height: 20),
          _buildBenchmarkRow(
            label: 'Rata-rata Rating Klien',
            myValue: '4.92 / 5.0',
            avgValue: '4.65 / 5.0',
            isBetter: true,
            isDark: isDark,
          ),
          const Divider(height: 20),
          _buildBenchmarkRow(
            label: 'Tingkat Repeat Order',
            myValue: '34.5%',
            avgValue: '21.0%',
            isBetter: true,
            isDark: isDark,
          ),
          const Divider(height: 20),
          _buildBenchmarkRow(
            label: 'Kecepatan Respon Pesan',
            myValue: '12 menit',
            avgValue: '45 menit',
            isBetter: true,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildBenchmarkRow({
    required String label,
    required String myValue,
    required String avgValue,
    required bool isBetter,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () {
        _showChartDataDetailDialog(
          title: 'Benchmark: $label',
          subtitle: 'Perbandingan dengan Industri',
          value: 'Pencapaian Anda: $myValue',
          growthText: 'Standar Industri Rata-rata: $avgValue',
          tips: 'Pencapaian Anda berada di atas rata-rata platform. Klien memprioritaskan profil dengan metrik prima ini.',
          isDark: isDark,
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                myValue,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                'Rata-rata: $avgValue',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                ),
              ),
            ),
            const Icon(Icons.info_outline_rounded, size: 15, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ── DIALOG FOR KPI CLICK (POINT 3) ─────────────────────────────────────────
  void _showKpiDetailDialog(Map<String, dynamic> kpi, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (kpi['color'] as Color).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(kpi['icon'] as IconData, color: kpi['color'] as Color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                kpi['title'] as String,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (kpi['color'] as Color).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: (kpi['color'] as Color).withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Nilai Saat Ini', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Text(
                          kpi['value'] as String,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: kpi['color'] as Color,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (kpi['trendColor'] as Color).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        kpi['trend'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: kpi['trendColor'] as Color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Rincian Komponen Metrik:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...((kpi['details'] as List<String>?) ?? []).map(
                (d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(d, style: const TextStyle(fontSize: 12))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_rounded, size: 16, color: Colors.amber.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        kpi['insight'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  // ── DIALOG FOR CHART ELEMENT CLICK (POINT 3) ───────────────────────────────
  void _showChartDataDetailDialog({
    required String title,
    required String subtitle,
    required String value,
    required String growthText,
    required String tips,
    required bool isDark,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.analytics_rounded, color: AppTheme.primaryPurple),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Data Tercatat', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryPurple,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      growthText,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Analisis & Catatan Sistem:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                tips,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}
