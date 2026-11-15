import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app/theme.dart';
import '../services/user_store.dart';
import '../services/wallet_service.dart';
import '../widgets/auth_guard_dialog.dart';

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
  final bool showForgotPin;

  const WalletPinDialog({
    super.key,
    this.title = 'Konfirmasi PIN Wallet',
    this.subtitle = 'Masukkan PIN wallet kamu untuk melanjutkan.',
    this.showForgotPin = true,
  });

  /// Shows the dialog. Returns the entered PIN string if the user confirms,
  /// or null if cancelled / wallet not activated.
  ///
  /// Pass [checkPinFirst] = true (default) to hit GET /wallet/has-pin before
  /// showing the input — shows an activation prompt if not set.
  static Future<String?> show(
    BuildContext context, {
    String title = 'Konfirmasi PIN Wallet',
    String subtitle = 'Masukkan PIN wallet kamu untuk melanjutkan.',
    bool checkPinFirst = true,
  }) async {
    final user = currentUserNotifier.value;
    if (user == null || user.isGuest) {
      if (context.mounted) {
        AuthGuardDialog.show(context, actionName: 'melakukan transaksi dompet');
      }
      return null;
    }

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
      builder: (_) => WalletPinDialog(
        title: title,
        subtitle: subtitle,
        showForgotPin: checkPinFirst,
      ),
    );
  }

  @override
  State<WalletPinDialog> createState() => _WalletPinDialogState();
}

class _WalletPinDialogState extends State<WalletPinDialog> {
  static const int _pinLength = 6;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onConfirm() {
    final pin = _controller.text.trim();
    if (pin.length < _pinLength) return;
    Navigator.pop(context, pin);
  }

  Future<void> _handleForgotPin() async {
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    bool resetObscure = true;
    String? resetError;
    bool isSubmitting = false;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1A33) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.lock_reset_rounded, color: Color(0xFF4F46E5), size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Atur Ulang PIN Dompet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Masukkan 6 digit angka baru untuk mereset PIN dompet Anda.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: newPinController,
                      autofocus: true,
                      obscureText: resetObscure,
                      keyboardType: TextInputType.number,
                      maxLength: _pinLength,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(_pinLength),
                      ],
                      decoration: InputDecoration(
                        labelText: 'PIN Baru (6 Digit)',
                        counterText: '',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            resetObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 18,
                          ),
                          onPressed: () => setDialogState(() => resetObscure = !resetObscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPinController,
                      obscureText: resetObscure,
                      keyboardType: TextInputType.number,
                      maxLength: _pinLength,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(_pinLength),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Konfirmasi PIN Baru',
                        counterText: '',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    if (resetError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        resetError!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx, null),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final p1 = newPinController.text.trim();
                        final p2 = confirmPinController.text.trim();
                        if (p1.length != _pinLength) {
                          setDialogState(() => resetError = 'PIN wajib 6 digit angka.');
                          return;
                        }
                        if (p1 != p2) {
                          setDialogState(() => resetError = 'Konfirmasi PIN tidak cocok.');
                          return;
                        }
                        setDialogState(() {
                          isSubmitting = true;
                          resetError = null;
                        });
                        try {
                          await WalletService.resetPin(p1);
                          if (ctx.mounted) Navigator.pop(ctx, p1);
                        } catch (e) {
                          setDialogState(() {
                            isSubmitting = false;
                            resetError = e.toString().replaceAll('Exception: ', '');
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(isSubmitting ? 'Menyimpan...' : 'Simpan PIN Baru'),
              ),
            ],
          );
        },
      ),
    );

    newPinController.dispose();
    confirmPinController.dispose();

    if (result != null && mounted) {
      _controller.text = result;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN dompet berhasil diatur ulang.'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _onConfirm();
    } else if (mounted) {
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.cardBg : Colors.white;
    final text = _controller.text;

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
                    const Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
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
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context, null),
                      tooltip: 'Batal',
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
                child: Column(
                  children: [
                    // ── Native Keyboard Input + Interactive PIN Cells ──────────
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _focusNode.requestFocus(),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(_pinLength, (i) {
                              final filled = i < text.length;
                              final isCurrent = i == text.length && _focusNode.hasFocus;
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 5),
                                width: 42,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E1A33) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCurrent
                                        ? AppTheme.primaryPurple
                                        : (filled
                                            ? AppTheme.primaryPurple.withValues(alpha: 0.6)
                                            : (isDark ? Colors.grey.shade600 : Colors.grey.shade300)),
                                    width: isCurrent ? 2.0 : 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: filled
                                      ? (_obscure
                                          ? Container(
                                              width: 11,
                                              height: 11,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: AppTheme.primaryPurple,
                                              ),
                                            )
                                          : Text(
                                              text[i],
                                              style: TextStyle(
                                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ))
                                      : (isCurrent
                                          ? Container(
                                              width: 2,
                                              height: 18,
                                              color: AppTheme.primaryPurple,
                                            )
                                          : null),
                                ),
                              );
                            }),
                          ),
                        ),
                        Opacity(
                          opacity: 0.0,
                          child: SizedBox(
                            width: 300,
                            height: 48,
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              autofocus: true,
                              keyboardType: TextInputType.number,
                              showCursor: false,
                              enableInteractiveSelection: false,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(_pinLength),
                              ],
                              onChanged: (val) {
                                setState(() {});
                                if (val.length == _pinLength) {
                                  _onConfirm();
                                }
                              },
                              onSubmitted: (val) {
                                if (val.length == _pinLength) {
                                  _onConfirm();
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── Tampilkan PIN & Lupa PIN ──────────────────────────────
                    Row(
                      mainAxisAlignment: widget.showForgotPin
                          ? MainAxisAlignment.spaceBetween
                          : MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 15,
                            color: AppTheme.primaryPurple.withValues(alpha: 0.85),
                          ),
                          label: Text(
                            _obscure ? 'Tampilkan PIN' : 'Sembunyikan PIN',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryPurple.withValues(alpha: 0.85),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        if (widget.showForgotPin)
                          TextButton(
                            onPressed: _handleForgotPin,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Lupa PIN?',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Action Buttons ────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, null),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(
                                color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Batal',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: text.length == _pinLength ? _onConfirm : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryPurple,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.3),
                              disabledForegroundColor: Colors.white54,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Konfirmasi',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}
