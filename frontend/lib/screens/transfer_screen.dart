import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/wallet_service.dart';
import '../app/theme.dart';

class TransferScreen extends StatefulWidget {
  final UserModel user;
  final String? preFilledUsername;
  final ValueChanged<UserModel>? onUserUpdated;

  const TransferScreen({
    super.key,
    required this.user,
    this.preFilledUsername,
    this.onUserUpdated,
  });

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _usernameController = TextEditingController();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  bool _isLoading = false;

  double _amount = 0.0;
  double _tax = 0.0;
  double _netReceived = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.preFilledUsername != null) {
      _usernameController.text = widget.preFilledUsername!;
    }
    _amountController.addListener(_calculateCosts);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _calculateCosts() {
    final text = _amountController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _amount = 0.0;
        _tax = 0.0;
        _netReceived = 0.0;
      });
      return;
    }

    final parsed = double.tryParse(text) ?? 0.0;
    setState(() {
      _amount = parsed;
      _tax = parsed * 0.05; // 5% pajak platform
      _netReceived = parsed - _tax;
    });
  }

  String _formatRupiah(double val) {
    final str = val.toStringAsFixed(0);
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return 'Rp ' + str.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }

  Future<void> _handleTransfer() async {
    final username = _usernameController.text.trim();
    final amountText = _amountController.text.trim();

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username penerima wajib diisi.')),
      );
      return;
    }

    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah transfer wajib diisi.')),
      );
      return;
    }

    final amount = double.tryParse(amountText) ?? 0.0;
    if (amount < 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimal transfer adalah Rp 10.000.')),
      );
      return;
    }

    if (amount > widget.user.balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saldo Anda tidak mencukupi.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await WalletService.transfer(
      receiverUsername: username,
      amount: amount,
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        // Update user model state
        final updatedUser = widget.user.copyWith(balance: result['sender_balance']);
        if (widget.onUserUpdated != null) {
          widget.onUserUpdated!(updatedUser);
        }

        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Transfer Sukses! 🚀'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'Saldo sebesar ${_formatRupiah(amount)} berhasil dikirim ke @$username.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Pajak Platform (5%): ${_formatRupiah(result['fee'])}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context, {
                    'success': true,
                    'amount': amount,
                    'fee': result['fee'] != null ? double.parse(result['fee'].toString()) : (amount * 0.05),
                  }); // Go back with transaction details
                },
                child: const Text('Selesai'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Transfer gagal.'),
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Kirim Saldo'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Available Balance Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Saldo Anda:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    _formatRupiah(widget.user.balance),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. Transfer Form
            Container(
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Receiver Username
                  const Text(
                    'Username Penerima',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _usernameController,
                    readOnly: widget.preFilledUsername != null,
                    decoration: InputDecoration(
                      hintText: 'Masukkan username...',
                      prefixIcon: const Icon(Icons.alternate_email_rounded),
                      filled: widget.preFilledUsername != null,
                      fillColor: widget.preFilledUsername != null
                          ? (isDark ? Colors.grey.shade900 : Colors.grey.shade100)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Amount
                  const Text(
                    'Nominal Transfer',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '0',
                      prefixText: 'Rp ',
                      prefixIcon: Icon(Icons.wallet_rounded),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Description
                  const Text(
                    'Catatan (Opsional)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descController,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      hintText: 'Tulis catatan transaksi...',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. Billing Breakdown Card
            if (_amount > 0) ...[
              const Text(
                'Rincian Transaksi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
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
                    _buildRowBreakdown('Jumlah Kirim', _formatRupiah(_amount), theme, isBold: true),
                    const SizedBox(height: 8),
                    _buildRowBreakdown('Pajak Platform (5%)', _formatRupiah(_tax), theme),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    _buildRowBreakdown(
                      'Penerima Menerima',
                      _formatRupiah(_netReceived),
                      theme,
                      isBold: true,
                      valueColor: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '*Penerima akan menerima jumlah bersih setelah dipotong biaya pajak platform 5%.',
                      style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 40),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleTransfer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Konfirmasi & Kirim',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRowBreakdown(
    String label,
    String value,
    ThemeData theme, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
