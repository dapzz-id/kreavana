import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app/theme.dart';
import '../app/app_animations.dart';
import '../services/payment_method_service.dart';
import '../utils/app_errors.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/gradient_button.dart';
import '../widgets/animated_input_field.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  List<PaymentMethod> _methods = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final methods = await PaymentMethodService.getMethods();
      if (mounted) {
        setState(() {
          _methods = methods;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackbar.error(context, AppErrors.friendly(e));
      }
    }
  }

  Future<void> _openForm({PaymentMethod? method}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentMethodFormSheet(method: method),
    );
    if (saved == true) {
      await _load();
    }
  }

  Future<void> _confirmDelete(PaymentMethod method) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Metode?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('${method.provider} •••• ${method.accountNumber.length > 4 ? method.accountNumber.substring(method.accountNumber.length - 4) : method.accountNumber} akan dihapus dari metode pembayaran Anda.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final result = await PaymentMethodService.deleteMethod(method.id);
      if (!mounted) return;
      if (result['status'] == true) {
        AppSnackbar.success(context, 'Metode pembayaran dihapus');
        await _load();
      } else {
        AppSnackbar.error(context, AppErrors.messageFromResult(result));
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppErrors.friendly(e));
    }
  }

  Future<void> _setDefault(PaymentMethod method) async {
    try {
      final result = await PaymentMethodService.setDefault(method.id);
      if (!mounted) return;
      if (result['status'] == true) {
        AppSnackbar.success(context, '${method.provider} kini menjadi metode utama');
        await _load();
      } else {
        AppSnackbar.error(context, AppErrors.messageFromResult(result));
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppErrors.friendly(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_payment',
        onPressed: _openForm,
        backgroundColor: AppTheme.primaryPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      appBar: AppBar(
        toolbarHeight: 70,
        title: const Text('Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple))
          : _methods.isEmpty
              ? RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primaryPurple,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      AppEmptyState(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Belum Ada Metode Pembayaran',
                        subtitle: 'Tambahkan rekening bank atau e-wallet untuk transaksi di Kreavana.',
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primaryPurple,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                    itemCount: _methods.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) => AnimatedEntrance(
                      delay: Duration(milliseconds: 80 + i * 70),
                      child: _buildCard(_methods[i], isDark),
                    ),
                  ),
                ),
    );
  }

  Widget _buildCard(PaymentMethod method, bool isDark) {
    final isBank = method.type == 'bank';
    final color = isBank ? const Color(0xFF3B82F6) : const Color(0xFF10B981);
    final last4 = method.accountNumber.length > 4
        ? method.accountNumber.substring(method.accountNumber.length - 4)
        : method.accountNumber;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: method.isDefault
              ? AppTheme.primaryPurple.withValues(alpha: 0.5)
              : (isDark ? AppTheme.inputBorder : Colors.grey.shade200),
          width: method.isDefault ? 1.5 : 1,
        ),
        boxShadow: isDark ? AppTheme.cardShadowDark : AppTheme.cardShadowLight,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(isBank ? Icons.account_balance_rounded : Icons.phone_iphone_rounded,
                    color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(method.provider,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        if (method.isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurple.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('UTAMA',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(method.accountName,
                        style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text('•••• $last4',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () async {
                            await Clipboard.setData(ClipboardData(text: method.accountNumber));
                            if (mounted) AppSnackbar.success(context, 'Nomor rekening disalin');
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: isDark ? AppTheme.cardBg : Colors.white,
                onSelected: (v) {
                  if (v == 'edit') _openForm(method: method);
                  if (v == 'default') _setDefault(method);
                  if (v == 'delete') _confirmDelete(method);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: const Row(children: [
                    Icon(Icons.edit_outlined, size: 18), SizedBox(width: 10), Text('Ubah')
                  ])),
                  PopupMenuItem(value: 'default', child: const Row(children: [
                    Icon(Icons.star_outline_rounded, size: 18), SizedBox(width: 10), Text('Jadikan Utama')
                  ])),
                  PopupMenuItem(value: 'delete', child: Row(children: [
                    const Icon(Icons.delete_outline, size: 18), const SizedBox(width: 10),
                    Text('Hapus', style: TextStyle(color: AppTheme.error))
                  ])),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodFormSheet extends StatefulWidget {
  final PaymentMethod? method;

  const _PaymentMethodFormSheet({this.method});

  @override
  State<_PaymentMethodFormSheet> createState() => _PaymentMethodFormSheetState();
}

class _PaymentMethodFormSheetState extends State<_PaymentMethodFormSheet> {
  late final TextEditingController _providerCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _numberCtrl;
  String _type = 'bank';
  bool _isDefault = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.method?.type ?? 'bank';
    _isDefault = widget.method?.isDefault ?? false;
    _providerCtrl = TextEditingController(text: widget.method?.provider ?? '');
    _nameCtrl = TextEditingController(text: widget.method?.accountName ?? '');
    _numberCtrl = TextEditingController(text: widget.method?.accountNumber ?? '');
  }

  @override
  void dispose() {
    _providerCtrl.dispose();
    _nameCtrl.dispose();
    _numberCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final provider = _providerCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final number = _numberCtrl.text.trim();

    if (provider.isEmpty || name.isEmpty || number.isEmpty) {
      AppSnackbar.error(context, 'Lengkapi semua kolom terlebih dahulu.');
      return;
    }
    if (number.length < 6) {
      AppSnackbar.error(context, 'Nomor rekening / e-wallet minimal 6 digit.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final result = widget.method == null
          ? await PaymentMethodService.addMethod(
              type: _type, provider: provider, accountName: name, accountNumber: number, isDefault: _isDefault)
          : await PaymentMethodService.updateMethod(
              id: widget.method!.id,
              type: _type, provider: provider, accountName: name, accountNumber: number, isDefault: _isDefault);
      if (!mounted) return;
      if (result['status'] == true) {
        Navigator.pop(context, true);
      } else {
        setState(() => _isSaving = false);
        AppSnackbar.error(context, AppErrors.messageFromResult(result));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppSnackbar.error(context, AppErrors.friendly(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEdit = widget.method != null;

    return Container(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(isEdit ? 'Ubah Metode Pembayaran' : 'Tambah Metode Pembayaran',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _typeChip('bank', 'Bank', Icons.account_balance_rounded, isDark),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _typeChip('ewallet', 'E-Wallet', Icons.phone_iphone_rounded, isDark),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AnimatedInputField(
              controller: _providerCtrl,
              label: 'Penyedia',
              hint: 'Contoh: BCA, Mandiri, BNI, OVO, GoPay, DANA',
              icon: Icons.business_rounded,
            ),
            const SizedBox(height: 12),
            AnimatedInputField(
              controller: _nameCtrl,
              label: 'Nama Pemilik',
              hint: 'Nama sesuai rekening / akun',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 12),
            AnimatedInputField(
              controller: _numberCtrl,
              label: 'Nomor Rekening / Akun',
              hint: 'Nomor tanpa spasi',
              icon: Icons.pin_outlined,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Jadikan metode utama', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              subtitle: Text(
                'Diprioritaskan untuk pembayaran & penarikan dana',
                style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight),
              ),
              value: _isDefault,
              activeThumbColor: AppTheme.primaryPurple,
              onChanged: (v) => setState(() => _isDefault = v),
            ),
            const SizedBox(height: 14),
            GradientButton(
              isLoading: _isSaving,
              onPressed: _save,
              text: isEdit ? 'Simpan Perubahan' : 'Simpan Metode',
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(String type, String label, IconData icon, bool isDark) {
    final selected = _type == type;
    return GestureDetector(
      onTap: () => setState(() => _type = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [AppTheme.primaryPurple, AppTheme.lightPurple])
              : null,
          color: selected ? null : (isDark ? AppTheme.inputDark : AppTheme.inputLight),
          borderRadius: BorderRadius.circular(14),
          border: selected ? null : Border.all(color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? Colors.white : AppTheme.textMuted),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : (isDark ? AppTheme.textWhite : AppTheme.textDark),
                )),
          ],
        ),
      ),
    );
  }
}
