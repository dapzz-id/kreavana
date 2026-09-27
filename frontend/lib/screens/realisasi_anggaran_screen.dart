import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../models/user_model.dart';
import '../models/job_contract.dart';
import '../services/job_contract_service.dart';
import '../widgets/desktop_sidebar_layout.dart';

class RealisasiAnggaranScreen extends StatefulWidget {
  final UserModel? user;
  final ValueChanged<UserModel>? onUserUpdated;

  const RealisasiAnggaranScreen({super.key, this.user, this.onUserUpdated});

  @override
  State<RealisasiAnggaranScreen> createState() => _RealisasiAnggaranScreenState();
}

class _RealisasiAnggaranScreenState extends State<RealisasiAnggaranScreen> {
  bool _isLoading = true;
  double _paguTotal = 0;
  double _terealisasi = 0;
  double _persentase = 0;
  List<Map<String, dynamic>> _data = [];

  @override
  void initState() {
    super.initState();
    _fetchAnggaranData();
  }

  Future<void> _fetchAnggaranData() async {
    try {
      final List<JobContract> contracts = await JobContractService.getUserContracts();
      double total = 0;
      double realized = 0;
      final items = <Map<String, dynamic>>[];

      for (final c in contracts) {
        total += c.agreedPrice;
        final isCompleted = c.workStatus == 'completed';
        final isInProgress = c.workStatus == 'in_progress';
        if (isCompleted) {
          realized += c.agreedPrice;
        }

        int percent = isCompleted ? 100 : (isInProgress ? 60 : 25);
        items.add({
          'name': c.title,
          'percent': percent,
          'pagu': 'Rp ${c.agreedPrice.toStringAsFixed(0)}',
          'realisasi': isCompleted ? 'Rp ${c.agreedPrice.toStringAsFixed(0)}' : 'Rp 0',
          'color': isCompleted ? const Color(0xFF10B981) : const Color(0xFF2563EB),
        });
      }

      if (mounted) {
        setState(() {
          _paguTotal = total;
          _terealisasi = realized;
          _persentase = total > 0 ? (realized / total) * 100 : 0;
          _data = items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final content = Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        automaticallyImplyLeading: MediaQuery.of(context).size.width <= 900,
        title: const Text(
          'Realisasi Anggaran',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchAnggaranData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.cardBg : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ringkasan Anggaran Proyek',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _buildStat('Pagu Total', 'Rp ${_paguTotal.toStringAsFixed(0)}', isDark),
                              const SizedBox(width: 16),
                              _buildStat('Terealisasi', 'Rp ${_terealisasi.toStringAsFixed(0)}', isDark),
                              const SizedBox(width: 16),
                              _buildStat('Persentase', '${_persentase.toStringAsFixed(1)}%', isDark),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_data.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.cardBg : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 48,
                              color: isDark ? AppTheme.textMuted : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Belum Ada Realisasi Anggaran',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Alokasi anggaran dan pengeluaran proyek Anda akan tercatat otomatis di sini.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._data.map(
                        (d) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.cardBg : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: d['color'] as Color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      d['name'] as String,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${d['percent']}%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: d['color'] as Color,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: (d['percent'] as int) / 100,
                                  minHeight: 8,
                                  backgroundColor: isDark
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation(d['color'] as Color),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Pagu: ${d['pagu']}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppTheme.textMuted
                                          : Colors.grey.shade500,
                                    ),
                                  ),
                                  Text(
                                    'Realisasi: ${d['realisasi']}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppTheme.textMuted
                                          : Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );

    if (widget.user != null) {
      return DesktopSidebarLayout(
        user: widget.user!,
        activeRoute: 'realisasi_anggaran',
        onUserUpdated: widget.onUserUpdated,
        child: content,
      );
    }

    return content;
  }

  Widget _buildStat(String label, String value, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
