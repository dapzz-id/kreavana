import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/wallet_service.dart';
import '../app/theme.dart';
import 'topup_details_screen.dart';

class TopUpScreen extends StatefulWidget {
  final UserModel user;

  const TopUpScreen({super.key, required this.user});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  final _amountController = TextEditingController();
  bool _isLoading = false;

  String _selectedMethod = 'qris'; // bank_transfer, e_wallet, qris
  String _selectedProvider = 'QRIS';

  final List<double> _quickAmounts = [20000, 50000, 100000, 200000, 500000];

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

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _onQuickAmountSelected(double val) {
    setState(() {
      _amountController.text = val.toStringAsFixed(0);
    });
  }

  Future<void> _handleTopUp() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal pengisian wajib diisi.')),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount < 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimal pengisian adalah Rp 10.000.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await WalletService.topUp(
      amount: amount,
      paymentMethod: _selectedMethod,
      paymentProvider: _selectedProvider,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        // Open details
        final didPay = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TopUpDetailsScreen(
              transaction: result['transaction'],
              paymentDetails: result['payment_details'],
            ),
          ),
        );
        
        if (didPay == true) {
          Navigator.pop(context, true);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal memproses top up.'),
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
        title: const Text('Isi Saldo'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Amount Input
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
                  const Text(
                    'Masukkan Nominal',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
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

            // 2. Quick amount selection
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
                      label: Text('Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}'),
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
            const SizedBox(height: 32),

            // 3. Payment Method Section
            const Text(
              'Metode Pembayaran',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // QRIS Option
            _buildMethodTile(
              type: 'qris',
              provider: 'QRIS',
              title: 'QRIS (Gopay, OVO, Dana, LinkAja)',
              subtitle: 'Scan QR Code instan',
              providerCode: 'qris',
              theme: theme,
            ),
            const SizedBox(height: 12),

            // Bank Transfer Options
            const Text(
              'Transfer Bank Virtual Account',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ..._banks.map((bank) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildMethodTile(
                  type: 'bank_transfer',
                  provider: bank['name']!,
                  title: 'Virtual Account ${bank['name']}',
                  subtitle: 'Konfirmasi instan otomatis',
                  providerCode: bank['code']!,
                  theme: theme,
                ),
              );
            }),
            const SizedBox(height: 12),

            // E-Wallet Options
            const Text(
              'E-Wallet Direct',
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
                  subtitle: 'Pembayaran e-wallet langsung',
                  providerCode: wallet['code']!,
                  theme: theme,
                ),
              );
            }),

            const SizedBox(height: 40),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleTopUp,
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
                        'Lanjut Pembayaran',
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
      case 'qris':
        // QRIS - Official blue with white text
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF00529C),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 20),
                Text(
                  'QRIS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 7,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        );

      case 'bca':
        // BCA - Dark blue background, white text
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
        // Mandiri - Navy with gold accent stripe
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
        // BNI - Orange top, green bottom
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
        // BRI - Blue background with white text
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
        // GoPay - White bg with teal/green text + green icon
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
        // OVO - Purple background with white text
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
        // DANA - Blue background with white text
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
