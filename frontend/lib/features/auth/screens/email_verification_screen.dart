import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme.dart';
import '../../../app/app_animations.dart';
import '../../../services/theme_transition_service.dart';
import '../services/auth_service.dart';
import '../../../services/app_router.dart';
import 'package:go_router/go_router.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final bool autoResend;
  const EmailVerificationScreen({super.key, required this.email, this.autoResend = false});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  bool _isResending = false;
  bool _isSuccess = false;
  String? _errorMessage;

  int _resendCountdown = 60;
  Timer? _countdownTimer;

  final GlobalKey _themeBtnKey = GlobalKey();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();

    _startCountdown();

    // Auto-focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _otpFocusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _countdownTimer?.cancel();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _resendCountdown = 180;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  String get _otpValue =>
      _otpControllers.map((c) => c.text).join();

  void _onOtpChanged(int index, String value) {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }

    if (value.length == 1 && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    }

    // Handle paste: if user pastes 6 digits into any field
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length >= 6) {
        _fillOtp(digits.substring(0, 6));
        return;
      }
    }

    if (_otpValue.length == 6) {
      _handleVerify();
    }
  }

  void _onOtpKeyDown(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _otpControllers[index].text.isEmpty &&
        index > 0) {
      _otpControllers[index - 1].clear();
      _otpFocusNodes[index - 1].requestFocus();
    }
  }

  void _fillOtp(String code) {
    for (int i = 0; i < 6; i++) {
      _otpControllers[i].text = code[i];
    }
    _otpFocusNodes[5].requestFocus();
    _handleVerify();
  }

  void _clearOtp() {
    for (final c in _otpControllers) {
      c.clear();
    }
    _otpFocusNodes[0].requestFocus();
  }

  void _handleVerify() async {
    final code = _otpValue;
    if (code.length != 6 || _isVerifying || _isSuccess) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final result = await AuthService.verifyEmail(
      email: widget.email,
      code: code,
    );

    if (!mounted) return;

    setState(() => _isVerifying = false);

    if (result['status'] == true) {
      setState(() => _isSuccess = true);
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Email berhasil diverifikasi! Silakan masuk.'),
              ],
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        context.go(AppRoutes.login);
      }
    } else {
      final errorCode = result['error_code']?.toString() ?? '';
      String message;
      switch (errorCode) {
        case 'verification_code_expired':
          message =
              'Kode verifikasi sudah kedaluwarsa. Silakan minta kode baru.';
          break;
        case 'verification_attempts_exceeded':
          message =
              'Terlalu banyak percobaan. Silakan minta kode verifikasi baru.';
          break;
        case 'invalid_verification_code':
          message = 'Kode verifikasi tidak valid.';
          break;
        default:
          message =
              result['message']?.toString() ?? 'Verifikasi gagal. Coba lagi.';
      }
      setState(() => _errorMessage = message);
      _clearOtp();
    }
  }

  void _handleResend() async {
    if (_resendCountdown > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    final result = await AuthService.resendVerificationCode(
      email: widget.email,
    );

    if (!mounted) return;

    setState(() => _isResending = false);

    if (result['status'] == true) {
      _startCountdown();
      _clearOtp();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Kode verifikasi baru telah dikirim.'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } else {
      final errorCode = result['error_code']?.toString() ?? '';
      if (errorCode == 'verification_resend_rate_limited') {
        setState(() =>
            _errorMessage = 'Mohon tunggu sebelum meminta kode verifikasi baru.');
      } else {
        setState(() => _errorMessage =
            result['message']?.toString() ?? 'Gagal mengirim ulang kode.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // ── Theme toggle ──────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: _ThemeToggleButton(themeBtnKey: _themeBtnKey),
          ),

          // ── Back button ──────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: colorScheme.onSurface,
              ),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go(AppRoutes.login);
                }
              },
            ),
          ),

          // ── Main content ──────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Center(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 40),

                          // ── Icon ─────────────────────────────────
                          _staggered(
                            Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                child: _isSuccess
                                    ? Container(
                                        key: const ValueKey('success'),
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [
                                              AppTheme.success,
                                              AppTheme.success
                                                  .withValues(alpha: 0.8),
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.success
                                                  .withValues(alpha: 0.3),
                                              blurRadius: 20,
                                              spreadRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 44,
                                        ),
                                      )
                                    : Container(
                                        key: const ValueKey('email'),
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: AppTheme.primaryGradient,
                                          boxShadow: AppTheme.primaryShadow,
                                        ),
                                        child: const Icon(
                                          Icons.mark_email_unread_rounded,
                                          color: Colors.white,
                                          size: 40,
                                        ),
                                      ),
                              ),
                            ),
                            0,
                          ),
                          const SizedBox(height: 32),

                          // ── Title ─────────────────────────────────
                          _staggered(
                            Text(
                              _isSuccess
                                  ? 'Email Terverifikasi!'
                                  : 'Verifikasi Email',
                              textAlign: TextAlign.center,
                              style:
                                  theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colorScheme.onSurface,
                                letterSpacing: -0.5,
                              ),
                            ),
                            1,
                          ),
                          const SizedBox(height: 8),
                          _staggered(
                            Text(
                              _isSuccess
                                  ? 'Email Anda berhasil diverifikasi.'
                                  : 'Kami telah mengirim kode verifikasi 6 digit ke:',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark
                                    ? AppTheme.textMuted
                                    : AppTheme.textMutedLight,
                                height: 1.4,
                              ),
                            ),
                            2,
                          ),
                          if (!_isSuccess) ...[
                            const SizedBox(height: 4),
                            _staggered(
                              Text(
                                widget.email,
                                textAlign: TextAlign.center,
                                style:
                                    theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.primary,
                                ),
                              ),
                              2,
                            ),
                            const SizedBox(height: 4),
                            _staggered(
                              Text(
                                'Kode berlaku selama 15 menit.',
                                textAlign: TextAlign.center,
                                style:
                                    theme.textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? AppTheme.textMuted
                                      : AppTheme.textMutedLight,
                                ),
                              ),
                              2,
                            ),
                          ],
                          const SizedBox(height: 36),

                          // ── Error banner ──────────────────────────
                          _staggered(
                            AnimatedSize(
                              duration: const Duration(milliseconds: 250),
                              curve: AppMotion.easeOut,
                              child: _ErrorBanner(message: _errorMessage),
                            ),
                            3,
                          ),
                          if (_errorMessage != null)
                            const SizedBox(height: 16),

                          // ── OTP Input ──────────────────────────────
                          if (!_isSuccess)
                            _staggered(
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: List.generate(6, (index) {
                                  return Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        left: index == 0 ? 0 : 5,
                                        right: index == 5 ? 0 : 5,
                                      ),
                                      child: KeyboardListener(
                                        focusNode: FocusNode(),
                                        onKeyEvent: (event) =>
                                            _onOtpKeyDown(index, event),
                                        child: _OtpBox(
                                          controller:
                                              _otpControllers[index],
                                          focusNode:
                                              _otpFocusNodes[index],
                                          onChanged: (value) =>
                                              _onOtpChanged(index, value),
                                          hasError:
                                              _errorMessage != null,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                              4,
                            ),
                          const SizedBox(height: 28),

                          // ── Verify button ──────────────────────────
                          if (!_isSuccess)
                            _staggered(
                              _VerifyButton(
                                isLoading: _isVerifying,
                                onPressed: _otpValue.length == 6
                                    ? _handleVerify
                                    : null,
                              ),
                              5,
                            ),
                          const SizedBox(height: 24),

                          // ── Resend ──────────────────────────────
                          if (!_isSuccess)
                            _staggered(
                              Center(
                                child: _isResending
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : _resendCountdown > 0
                                        ? Text(
                                            'Kirim ulang dalam ${_resendCountdown ~/ 60}:${(_resendCountdown % 60).toString().padLeft(2, '0')}',
                                            style: theme
                                                .textTheme.bodySmall
                                                ?.copyWith(
                                              color: isDark
                                                  ? AppTheme.textMuted
                                                  : AppTheme
                                                      .textMutedLight,
                                            ),
                                          )
                                        : GestureDetector(
                                            onTap: _handleResend,
                                            child: Text(
                                              'Kirim Ulang Kode',
                                              style: theme
                                                  .textTheme.bodyMedium
                                                  ?.copyWith(
                                                color:
                                                    colorScheme.primary,
                                                fontWeight:
                                                    FontWeight.w700,
                                              ),
                                            ),
                                          ),
                              ),
                              6,
                            ),
                          const SizedBox(height: 32),

                          // ── Back to login ──────────────────────────
                          _staggered(
                            Center(
                              child: GestureDetector(
                                onTap: () => context.go(AppRoutes.login),
                                child: Text(
                                  'Kembali ke Halaman Login',
                                  style:
                                      theme.textTheme.bodyMedium?.copyWith(
                                    color: isDark
                                        ? AppTheme.textMuted
                                        : AppTheme.textMutedLight,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                            7,
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _staggered(Widget child, int index) {
    final start = (index * 0.06).clamp(0.0, 0.9);
    final end = (start + 0.6).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
      parent: _animController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }
}

// ── OTP Input Box ────────────────────────────────────────────────────────────

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool hasError;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, child) {
        final focused = focusNode.hasFocus;
        final hasTxt = controller.text.isNotEmpty;

        Color borderColor;
        if (hasError) {
          borderColor = AppTheme.error;
        } else if (focused) {
          borderColor = colorScheme.primary;
        } else if (hasTxt) {
          borderColor = colorScheme.primary.withValues(alpha: 0.4);
        } else {
          borderColor =
              isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight;
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 58,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.inputDark : AppTheme.inputLight,
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            border: Border.all(
              color: borderColor,
              width: focused ? 2 : 1.5,
            ),
            boxShadow: focused
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 6, // Allow paste of full code
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.onSurface,
          letterSpacing: 2,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: onChanged,
      ),
    );
  }
}

// ── Verify Button (gradient, like GradientButton) ────────────────────────────

class _VerifyButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  const _VerifyButton({this.isLoading = false, this.onPressed});

  @override
  State<_VerifyButton> createState() => _VerifyButtonState();
}

class _VerifyButtonState extends State<_VerifyButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.97,
      upperBound: 1.0,
    )..value = 1.0;
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pressController,
      child: GestureDetector(
        onTapDown: (_) {
          if (!widget.isLoading && widget.onPressed != null) {
            _pressController.reverse();
          }
        },
        onTapUp: (_) => _pressController.forward(),
        onTapCancel: () => _pressController.forward(),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            gradient: AppTheme.primaryGradient,
            boxShadow: widget.isLoading || widget.onPressed == null
                ? null
                : AppTheme.primaryShadow,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              onTap: widget.isLoading ? null : widget.onPressed,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: widget.isLoading
                      ? const SizedBox(
                          key: ValueKey('loading'),
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Row(
                          key: ValueKey('content'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded,
                                color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Verifikasi',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Error banner (reused from LoginScreen pattern) ───────────────────────────

class _ErrorBanner extends StatefulWidget {
  final String? message;
  const _ErrorBanner({this.message});

  @override
  State<_ErrorBanner> createState() => _ErrorBannerState();
}

class _ErrorBannerState extends State<_ErrorBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeCtrl;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.message != null) _shakeCtrl.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant _ErrorBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message != null && widget.message != oldWidget.message) {
      _shakeCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    if (message == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _shakeCtrl,
      builder: (context, child) {
        final t = _shakeCtrl.value;
        final dx = math.sin(t * math.pi * 8) * 8 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.error.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: AppTheme.error, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Theme toggle (consistent with LoginScreen / RegisterScreen) ──────────────

class _ThemeToggleButton extends StatelessWidget {
  final GlobalKey themeBtnKey;
  const _ThemeToggleButton({required this.themeBtnKey});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: IconButton.filledTonal(
        key: themeBtnKey,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => RotationTransition(
            turns: Tween(begin: 0.75, end: 1.0).animate(anim),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            key: ValueKey(isDark),
            color: colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ),
        style: IconButton.styleFrom(
          backgroundColor:
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        ),
        onPressed: () {
          final box =
              themeBtnKey.currentContext?.findRenderObject() as RenderBox?;
          final origin = box != null
              ? box.localToGlobal(box.size.center(Offset.zero))
              : Offset.zero;
          ThemeTransitionService.animateToggle(
            origin: origin,
            toDark: !isDark,
          );
        },
      ),
    );
  }
}
