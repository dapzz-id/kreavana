import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/wallet_service.dart';
import '../app/theme.dart';

class WithdrawScreen extends StatefulWidget {
  final UserModel user;
  final double currentBalance;

  const WithdrawScreen({
    super.key,
    required this.user,
    required this.currentBalance,
  });

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final _amountController = TextEditingController();
  final _accountController = TextEditingController();
  bool _isLoading = false;

  String _selectedMethod = 'bank_transfer'; // bank_transfer, e_wallet
  String _selectedProvider = 'BCA';

  final List<double> _quickAmounts = [50000, 100000, 200000, 500000, 1000000];

  final List<Map<String, String>> _banks = [
    {'name': 'BCA', 'code': 'bca'},
    {'name': 'Mandiri', 'code': 'mandiri'},
    {'name': 'BNI', 'code': 'bni'},
    {'name': 'BRI', 'code': 'bri'},
  ];

  final List<Map<String, String>> _ewallets = [
    {'name': 'GoPay', 'code': 'gopay'},
    {'name': 'OVO', 'code': 'ovo'},
    {'name': 'DANA', 'code': 'dana'},
  ];

  double _amount = 0.0;
  double _tax = 0.0;
  double _netAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_updateCalculations);
  }

  @override
  void dispose() {
    _amountController.removeListener(_updateCalculations);
    _amountController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  void _updateCalculations() {
    final amountText = _amountController.text.trim();
    final parsedAmount = double.tryParse(amountText) ?? 0.0;
    setState(() {
      _amount = parsedAmount;
      _tax = _amount * 0.05; // 5% Pajak Platform
      _netAmount = _amount - _tax;
      if (_netAmount < 0) _netAmount = 0;
    });
  }

  void _onQuickAmountSelected(double val) {
    setState(() {
      _amountController.text = val.toStringAsFixed(0);
    });
  }

  Future<void> _handleWithdraw() async {
    final amountText = _amountController.text.trim();
    final accountText = _accountController.text.trim();

    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal pencairan wajib diisi.')),
      );
      return;
    }

    if (accountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_selectedMethod == 'bank_transfer'
              ? 'Nomor rekening bank wajib diisi.'
              : 'Nomor HP e-wallet wajib diisi.'),
        ),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount < 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimal pencairan adalah Rp 10.000.')),
      );
      return;
    }

    if (amount > widget.currentBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saldo Anda tidak mencukupi.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await WalletService.withdraw(
      amount: amount,
      paymentMethod: _selectedMethod,
      paymentProvider: _selectedProvider,
      accountNumber: accountText,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        // Show success sheet/dialog
        _showSuccessBottomSheet(result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal memproses penarikan saldo.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _showSuccessBottomSheet(Map<String, dynamic> result) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return PopScope(
          canPop: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Pencairan Berhasil!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Saldo Anda berhasil dicairkan ke rekening tujuan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardBg : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow('Tujuan', '$_selectedProvider ($_selectedMethod)'),
                      const SizedBox(height: 10),
                      _buildDetailRow('Nomor Tujuan', _accountController.text),
                      const SizedBox(height: 10),
                      _buildDetailRow('Jumlah Cair', _formatRupiah(_amount)),
                      const SizedBox(height: 10),
                      _buildDetailRow('Pajak Platform (5%)', _formatRupiah(_tax), isRed: true),
                      const Divider(height: 20),
                      _buildDetailRow(
                        'Total Diterima',
                        _formatRupiah(_netAmount),
                        isBold: true,
                        customColor: Colors.green,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close bottom sheet
                      Navigator.pop(this.context, true); // Return success to wallet screen
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Selesai'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String val,
      {bool isBold = false, bool isRed = false, Color? customColor}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
          ),
        ),
        Text(
          val,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: customColor ??
                (isRed
                    ? Colors.red.shade600
                    : (isDark ? Colors.white : Colors.black87)),
          ),
        ),
      ],
    );
  }

  String _formatRupiah(double val) {
    final str = val.toStringAsFixed(0);
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return 'Rp ' + str.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Cairkan Saldo'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Balance Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardBg : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Saldo Tersedia',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatRupiah(widget.currentBalance),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Amount Input
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardBg : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nominal Pencairan',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      prefixText: 'Rp ',
                      hintText: '0',
                      prefixStyle: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quick Amount Selector
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _quickAmounts.length,
                itemBuilder: (context, index) {
                  final amount = _quickAmounts[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(_formatRupiah(amount)),
                      onPressed: () => _onQuickAmountSelected(amount),
                      backgroundColor: isDark ? AppTheme.cardBg : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Destination Number/Account Input
            const Text(
              'Detail Rekening / E-Wallet Tujuan',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _accountController,
              keyboardType: _selectedMethod == 'e_wallet'
                  ? TextInputType.phone
                  : TextInputType.number,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: _selectedMethod == 'bank_transfer'
                    ? 'Nomor Rekening Bank'
                    : 'Nomor HP Akun E-Wallet',
                hintText: _selectedMethod == 'bank_transfer'
                    ? 'Contoh: 1234567890'
                    : 'Contoh: 081234567890',
                filled: true,
                fillColor: isDark ? AppTheme.cardBg : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Payment Method Section
            const Text(
              'Pilih Metode Pencairan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Bank Transfer Options
            const Text(
              'Transfer Bank',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ..._banks.map((bank) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildMethodTile(
                  type: 'bank_transfer',
                  provider: bank['name']!,
                  title: bank['name']!,
                  subtitle: 'Proses pencairan instan',
                  providerCode: bank['code']!,
                  theme: theme,
                ),
              );
            }),
            const SizedBox(height: 12),

            // E-Wallet Options
            const Text(
              'E-Wallet',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ..._ewallets.map((wallet) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildMethodTile(
                  type: 'e_wallet',
                  provider: wallet['name']!,
                  title: wallet['name']!,
                  subtitle: 'Proses pencairan instan',
                  providerCode: wallet['code']!,
                  theme: theme,
                ),
              );
            }),

            const SizedBox(height: 24),

            // Summary Panel with Tax / Platform Fee Details
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardBg : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ringkasan Penarikan',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 14),
                  _buildDetailRow('Nominal Penarikan', _formatRupiah(_amount)),
                  const SizedBox(height: 8),
                  _buildDetailRow('Pajak Platform (5%)', _formatRupiah(_tax), isRed: true),
                  const Divider(height: 24),
                  _buildDetailRow(
                    'Total Bersih Diterima',
                    _formatRupiah(_netAmount),
                    isBold: true,
                    customColor: Colors.green,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleWithdraw,
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
                        'Cairkan Sekarang',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a branded logo widget for each payment provider using official brand colors.
  Widget _buildBrandLogo(String providerCode) {
    switch (providerCode) {
      case 'bca':
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF003D79),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Text(
              'BCA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ),
        );

      case 'mandiri':
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF003366),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            children: [
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 8,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFCC00),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                    ),
                  ),
                ),
              ),
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    'mandiri',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

      case 'bni':
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF15A22),
                Color(0xFF005F3B),
              ],
              stops: [0.5, 0.5],
            ),
          ),
          child: const Center(
            child: Text(
              'BNI',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        );

      case 'bri':
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF00529C),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Text(
              'BRI',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ),
        );

      case 'gopay':
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF00AED6), width: 1.5),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_balance_wallet_rounded,
                    color: Color(0xFF00AED6), size: 18),
                Text(
                  'GoPay',
                  style: TextStyle(
                    color: Color(0xFF00AED6),
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );

      case 'ovo':
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF4C2A86),
                Color(0xFF6B3FA0),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Text(
              'OVO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ),
        );

      case 'dana':
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF108EE9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Text(
              'DANA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
        );

      default:
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Icon(Icons.payment, color: Colors.grey, size: 24),
          ),
        );
    }
  }

  Widget _buildMethodTile({
    required String type,
    required String provider,
    required String title,
    required String subtitle,
    required String providerCode,
    required ThemeData theme,
  }) {
    final isSelected = _selectedMethod == type && _selectedProvider == provider;
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedMethod = type;
          _selectedProvider = provider;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardBg : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : (isDark ? AppTheme.inputBorder : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            _buildBrandLogo(providerCode),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Radio<bool>(
              value: true,
              groupValue: isSelected,
              onChanged: (_) {
                setState(() {
                  _selectedMethod = type;
                  _selectedProvider = provider;
                });
              },
              activeColor: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
