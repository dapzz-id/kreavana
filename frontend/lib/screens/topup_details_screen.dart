import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/wallet_transaction_model.dart';
import '../services/wallet_service.dart';
import '../app/theme.dart';

class TopUpDetailsScreen extends StatefulWidget {
  final WalletTransactionModel transaction;
  final Map<String, dynamic> paymentDetails;

  const TopUpDetailsScreen({
    super.key,
    required this.transaction,
    required this.paymentDetails,
  });

  @override
  State<TopUpDetailsScreen> createState() => _TopUpDetailsScreenState();
}

class _TopUpDetailsScreenState extends State<TopUpDetailsScreen> {
  bool _isLoading = false;

  String _formatRupiah(double val) {
    final str = val.toStringAsFixed(0);
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return 'Rp ' + str.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleSimulatePay() async {
    setState(() => _isLoading = true);
    final result = await WalletService.simulatePayment(widget.transaction.referenceNumber);
    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Pembayaran Berhasil! 🎉'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Saldo Anda berhasil ditambahkan.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _formatRupiah(widget.transaction.amount),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context, true); // Go back with refresh trigger
                },
                child: const Text('Selesai'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal memproses simulasi pembayaran.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tx = widget.transaction;
    final details = widget.paymentDetails;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Instruksi Pembayaran'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Transaction Info Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardBg : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Nominal Tagihan',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatRupiah(tx.amount),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  _buildRowInfo('Metode Pembayaran', tx.typeLabel + ' (' + tx.paymentProvider! + ')', theme),
                  const SizedBox(height: 8),
                  _buildRowInfo('Nomor Referensi', tx.referenceNumber, theme),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. Custom Method Details Card
            const Text(
              'Detail Pembayaran',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardBg : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  // BANK TRANSFER FLOW
                  if (tx.paymentMethod == 'bank_transfer') ...[
                    Text(
                      'Silakan transfer ke nomor Virtual Account ${details['bank_name']}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SelectableText(
                            details['va_number'] ?? '',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 20),
                            onPressed: () => _copyToClipboard(
                              details['va_number'] ?? '',
                              'Nomor Virtual Account disalin.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildRowInfo('Nama Rekening', details['account_name'] ?? '', theme),
                  ]
                  // QRIS & E-WALLET FLOW
                  else ...[
                    const Text(
                      'Scan QR Code berikut menggunakan aplikasi e-wallet Anda',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    if (details['qr_url'] != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(12),
                          child: Image.network(
                            details['qr_url'],
                            width: 180,
                            height: 180,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.qr_code_2_rounded,
                              size: 150,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    if (tx.paymentMethod == 'e_wallet') ...[
                      const SizedBox(height: 16),
                      Text(
                        'Nomor E-Wallet: ${details['phone_number']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 3. Instruction Guide
            const Text(
              'Cara Pembayaran',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildStep('1', 'Buka aplikasi e-wallet / banking Anda.', theme),
            _buildStep('2', tx.paymentMethod == 'bank_transfer' ? 'Pilih menu Transfer ke Virtual Account.' : 'Pilih menu Scan QRIS / Unggah Kode QR.', theme),
            _buildStep('3', tx.paymentMethod == 'bank_transfer' ? 'Masukkan nomor VA di atas.' : 'Arahkan kamera ke QR Code.', theme),
            _buildStep('4', 'Detail transaksi akan muncul, pastikan nominal sesuai.', theme),
            _buildStep('5', 'Konfirmasi dan masukkan PIN Anda.', theme),

            const SizedBox(height: 40),

            // 4. Sandbox Simulator Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                border: Border.all(color: Colors.amber.shade300),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.science_rounded, color: Colors.amber.shade800),
                      const SizedBox(width: 8),
                      Text(
                        'Sandbox Simulator',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Anda berada di lingkungan simulasi lokal. Tekan tombol di bawah untuk menyimulasikan pembayaran berhasil secara instan.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSimulatePay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade800,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Simulasikan Bayar Sukses',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRowInfo(String label, String value, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStep(String index, String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              index,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
