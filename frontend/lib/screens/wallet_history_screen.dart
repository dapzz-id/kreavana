import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/wallet_transaction_model.dart';
import '../app/theme.dart';

class WalletHistoryScreen extends StatefulWidget {
  const WalletHistoryScreen({super.key});

  @override
  State<WalletHistoryScreen> createState() => _WalletHistoryScreenState();
}

class _WalletHistoryScreenState extends State<WalletHistoryScreen> {
  final List<WalletTransactionModel> _transactions = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  int _selectedYear = DateTime.now().year;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchHistory();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoading && _hasMore) {
        _fetchHistory();
      }
    });
  }

  Future<void> _fetchHistory({bool reset = false}) async {
    if (_isLoading) return;

    if (reset) {
      setState(() {
        _currentPage = 1;
        _transactions.clear();
        _hasMore = true;
      });
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.get('profile/history?page=$_currentPage&year=$_selectedYear');
      if ((response['success'] == true || response['status'] == true) && response['data'] != null) {
        final data = response['data']['data'] as List;
        final currentTransactions = data.map((tx) => WalletTransactionModel.fromJson(tx)).toList();
        
        setState(() {
          _transactions.addAll(currentTransactions);
          _currentPage++;
          _hasMore = response['data']['next_page_url'] != null;
        });
      }
    } catch (e) {
      debugPrint('Error fetching history: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatRupiah(double amount) {
    final formatCurrency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatCurrency.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.filter_list),
            onSelected: (year) {
              if (year != _selectedYear) {
                _selectedYear = year;
                _fetchHistory(reset: true);
              }
            },
            itemBuilder: (context) {
              final currentYear = DateTime.now().year;
              return List.generate(5, (index) {
                final year = currentYear - index;
                return PopupMenuItem(
                  value: year,
                  child: Text(year.toString()),
                );
              });
            },
          ),
        ],
      ),
      body: _transactions.isEmpty && !_isLoading
          ? Center(
              child: Text(
                'Tidak ada transaksi di tahun $_selectedYear',
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _transactions.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _transactions.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final tx = _transactions[index];
                final isCredit = tx.isCredit;
                final amountSign = isCredit ? '+' : '-';
                final amountColor = isCredit ? Colors.green.shade600 : Colors.red.shade600;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardBg : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppTheme.inputBorder : Colors.grey.shade100,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isCredit
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.red.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isCredit
                              ? (tx.type == 'topup' ? Icons.add_rounded : Icons.call_received_rounded)
                              : Icons.call_made_rounded,
                          color: amountColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx.typeLabel,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tx.description ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tx.createdAt.split('T').first,
                              style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$amountSign ${_formatRupiah(tx.amount)}',
                            style: TextStyle(color: amountColor, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: tx.status == 'success'
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : tx.status == 'pending'
                                      ? Colors.orange.withValues(alpha: 0.1)
                                      : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tx.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: tx.status == 'success'
                                    ? Colors.green.shade700
                                    : tx.status == 'pending'
                                        ? Colors.orange.shade700
                                        : Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
