import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app/theme.dart';
import '../services/wallet_service.dart';

/// Reusable Wallet PIN dialog — mirip ShopeePay.
///
/// Cara pakai:
/// ```dart
/// final pin = await WalletPinDialog.show(context);
/// if (pin != null) { /* lanjutkan transaksi */ }
/// ```
///
/// Jika wallet belum diaktifkan (PIN belum diset), dialog menampilkan
/// pesan aktivasi dan mengembalikan null.
class WalletPinDialog extends StatefulWidget {
  final String title;
  final String subtitle;

  const WalletPinDialog({
    super.key,
    this.title = 'Konfirmasi PIN Wallet',
    this.subtitle = 'Masukkan PIN wallet kamu untuk melanjutkan.',
  });

  /// Shows the dialog. Returns the entered PIN string if the user confirms,
  /// or null if cancelled / wallet not activated.
  ///
  /// Pass [checkPinFirst] = true (default) to hit GET /wallet/has-pin before
  /// showing the keypad — shows an activation prompt if not set.
  static Future<String?> show(
    BuildContext context, {
    String title = 'Konfirmasi PIN Wallet',
    String subtitle = 'Masukkan PIN wallet kamu untuk melanjutkan.',
    bool checkPinFirst = true,
  }) async {
    if (checkPinFirst) {
      // Lightweight check: does user have a wallet PIN?
      final hasPinSetup = await WalletService.hasPin();
      if (!hasPinSetup) {
        if (!context.mounted) return null;
        // Show activation prompt — no PIN = wallet not activated
        final result = await showDialog<String>(
          context: context,
          builder: (ctx) => _WalletNotActivatedDialog(),
        );
        return result;
      }
    }

    if (!context.mounted) return null;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WalletPinDialog(title: title, subtitle: subtitle),
    );
  }

  @override
  State<WalletPinDialog> createState() => _WalletPinDialogState();
}

class _WalletPinDialogState extends State<WalletPinDialog> {
  static const int _pinLength = 6;
  final List<String> _digits = [];
  bool _obscure = true;

  void _onDigit(String d) {
    if (_digits.length >= _pinLength) return;
    setState(() => _digits.add(d));
  }

  void _onDelete() {
    if (_digits.isEmpty) return;
    setState(() => _digits.removeLast());
  }

  void _onConfirm() {
    if (_digits.length < _pinLength) return;
    Navigator.pop(context, _digits.join());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.cardBg : Colors.white;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──────────────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context, null),
                      tooltip: 'Batal',
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: Column(
                  children: [
                    // ── PIN dots ──────────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pinLength, (i) {
                        final filled = i < _digits.length;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled
                                ? AppTheme.primaryPurple
                                : (isDark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300),
                            border: Border.all(
                              color: filled
                                  ? AppTheme.primaryPurple
                                  : (isDark
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade400),
                              width: 1.5,
                            ),
                          ),
                          child: filled && !_obscure
                              ? Center(
                                  child: Text(
                                    _digits[i],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                        );
                      }),
                    ),

                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => setState(() => _obscure = !_obscure),
                      child: Text(
                        _obscure ? 'Tampilkan PIN' : 'Sembunyikan PIN',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.primaryPurple.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Numpad ────────────────────────────────────────────────
                    _Numpad(
                      onDigit: _onDigit,
                      onDelete: _onDelete,
                      onConfirm: _digits.length == _pinLength ? _onConfirm : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Custom numpad ────────────────────────────────────────────────────────────
class _Numpad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onConfirm;

  const _Numpad({
    required this.onDigit,
    required this.onDelete,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget key(String label, {VoidCallback? onTap, bool isAction = false}) {
      return Expanded(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap?.call();
          },
          child: Container(
            margin: const EdgeInsets.all(4),
            height: 56,
            decoration: BoxDecoration(
              color: isAction
                  ? (onTap != null
                      ? AppTheme.primaryPurple
                      : AppTheme.primaryPurple.withValues(alpha: 0.3))
                  : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: label == '⌫'
                  ? Icon(Icons.backspace_rounded,
                      size: 20,
                      color: isDark ? Colors.white70 : Colors.black54)
                  : Text(
                      label,
                      style: TextStyle(
                        fontSize: isAction ? 14 : 20,
                        fontWeight: FontWeight.w600,
                        color: isAction
                            ? Colors.white
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(children: [
          key('1', onTap: () => onDigit('1')),
          key('2', onTap: () => onDigit('2')),
          key('3', onTap: () => onDigit('3')),
        ]),
        Row(children: [
          key('4', onTap: () => onDigit('4')),
          key('5', onTap: () => onDigit('5')),
          key('6', onTap: () => onDigit('6')),
        ]),
        Row(children: [
          key('7', onTap: () => onDigit('7')),
          key('8', onTap: () => onDigit('8')),
          key('9', onTap: () => onDigit('9')),
        ]),
        Row(children: [
          key('⌫', onTap: onDelete),
          key('0', onTap: () => onDigit('0')),
          key('OK', onTap: onConfirm, isAction: true),
        ]),
      ],
    );
  }
}

// ─── Wallet not activated prompt ──────────────────────────────────────────────
class _WalletNotActivatedDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: const [
          Icon(Icons.wallet_rounded, color: Color(0xFF4F46E5)),
          SizedBox(width: 10),
          Text('Wallet Belum Aktif'),
        ],
      ),
      content: const Text(
        'Kamu belum mengaktifkan Wallet Kreavana.\n\n'
        'Aktifkan wallet dan atur PIN terlebih dahulu di menu Wallet untuk bisa melakukan transaksi, seperti pembelian paket atau transfer saldo.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Nanti'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context, 'GO_WALLET');
          },
          icon: const Icon(Icons.wallet_rounded, size: 16),
          label: const Text('Ke Wallet'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}
