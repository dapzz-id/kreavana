import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../app/app_animations.dart';
import '../widgets/animated_input_field.dart';
import '../widgets/gradient_button.dart';
import '../widgets/social_button.dart';
import '../widgets/auth_divider.dart';
import '../services/theme_transition_service.dart';
import '../services/google_auth_service.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _agreedToTerms = false;
  String? _errorMessage;

  int _passwordStrength = 0;

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
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();

    _passwordController.addListener(_checkPasswordStrength);
  }

  void _checkPasswordStrength() {
    final p = _passwordController.text;
    int strength = 0;
    if (p.length >= 8) strength++;
    if (RegExp(r'[A-Z]').hasMatch(p)) strength++;
    if (RegExp(r'[0-9]').hasMatch(p)) strength++;
    if (RegExp(r'[!@#\$&*~._\-]').hasMatch(p)) strength++;
    if (_passwordStrength != strength) {
      setState(() => _passwordStrength = strength);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    setState(() => _errorMessage = null);
    if (!_agreedToTerms) {
      setState(() =>
          _errorMessage = 'Anda harus menyetujui syarat & ketentuan terlebih dahulu.');
      return;
    }
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final result = await AuthService.register(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (result['status'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Pendaftaran berhasil! Silakan masuk.'),
                ],
              ),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, a, _) => const LoginScreen(),
              transitionsBuilder: (_, a, _, child) =>
                  FadeTransition(opacity: a, child: child),
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
        } else {
          setState(() {
            _errorMessage = result['message']?.toString() ??
                'Pendaftaran gagal. Coba lagi.';
          });
        }
      }
    }
  }

  void _handleGoogleSignIn() async {
    if (!_agreedToTerms) {
      setState(() => _errorMessage =
          'Anda harus menyetujui syarat & ketentuan terlebih dahulu.');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isGoogleLoading = true;
    });

    final result = await GoogleAuthService.signInWithGoogle();

    if (mounted) {
      setState(() => _isGoogleLoading = false);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Akun berhasil dibuat dengan Google! Silakan masuk.'),
            ]),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, a, _) => const LoginScreen(),
            transitionsBuilder: (_, a, _, child) =>
                FadeTransition(opacity: a, child: child),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      } else {
        setState(() {
          _errorMessage = result['message']?.toString() ??
              'Pendaftaran dengan Google gagal. Coba lagi.';
        });
      }
    }
  }

  Color get _strengthColor {
    switch (_passwordStrength) {
      case 1: return AppTheme.error;
      case 2: return AppTheme.warning;
      case 3: return Colors.blue;
      case 4: return AppTheme.success;
      default: return Colors.grey.shade300;
    }
  }

  String get _strengthLabel {
    switch (_passwordStrength) {
      case 1: return 'Lemah';
      case 2: return 'Sedang';
      case 3: return 'Kuat';
      case 4: return 'Sangat Kuat';
      default: return '';
    }
  }

  IconData get _strengthIcon {
    switch (_passwordStrength) {
      case 1: return Icons.report_gmailerrorred_rounded;
      case 2: return Icons.help_outline_rounded;
      case 3: return Icons.check_circle_outline_rounded;
      case 4: return Icons.verified_rounded;
      default: return Icons.lock_open_rounded;
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
          // ── Theme toggle ─────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: _buildThemeToggleButton(isDark),
          ),

          // ── Content ──────────────────────────────────────────────────────
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
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),

                            // ── Logo ────────────────────────────────────────
                            _staggered(
                              Center(
                                child: Hero(
                                  tag: 'app-logo',
                                  child: Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      gradient: AppTheme.primaryGradient,
                                      boxShadow: AppTheme.primaryShadow,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Image.asset(
                                        'assets/brandlogo.png',
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => const Icon(
                                          Icons.auto_awesome,
                                          color: Colors.white,
                                          size: 36,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              0,
                            ),
                            const SizedBox(height: 24),

                            // ── Title ───────────────────────────────────────
                            _staggered(
                              Text(
                                'Buat Akun Baru',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onSurface,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              1,
                            ),
                            const SizedBox(height: 6),
                            _staggered(
                              Text(
                                'Bergabunglah dengan ribuan kreator & klien di Kreavana.',
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
                            const SizedBox(height: 28),

                            // ── Error banner ────────────────────────────────
                            _staggered(
                              AnimatedSize(
                                duration: const Duration(milliseconds: 250),
                                curve: AppMotion.easeOut,
                                child: _ErrorBanner(message: _errorMessage),
                              ),
                              3,
                            ),
                            const SizedBox(height: 16),

                            // ── Name ────────────────────────────────────────
                            _staggered(
                              AnimatedInputField(
                                controller: _nameController,
                                label: 'Nama Lengkap',
                                hint: 'John Doe',
                                icon: Icons.person_outline_rounded,
                                textInputAction: TextInputAction.next,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Masukkan nama lengkap';
                                  }
                                  if (v.trim().length < 2) {
                                    return 'Nama minimal 2 karakter';
                                  }
                                  return null;
                                },
                              ),
                              4,
                            ),
                            const SizedBox(height: 14),

                            // ── Username ────────────────────────────────────
                            _staggered(
                              AnimatedInputField(
                                controller: _usernameController,
                                label: 'Username',
                                hint: 'johndoe',
                                icon: Icons.alternate_email_rounded,
                                textInputAction: TextInputAction.next,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Masukkan username';
                                  }
                                  if (v.trim().length < 3) {
                                    return 'Username minimal 3 karakter';
                                  }
                                  if (!RegExp(r'^[a-zA-Z0-9_\.]+$')
                                      .hasMatch(v.trim())) {
                                    return 'Hanya huruf, angka, titik, underscore';
                                  }
                                  return null;
                                },
                              ),
                              5,
                            ),
                            const SizedBox(height: 14),

                            // ── Email ───────────────────────────────────────
                            _staggered(
                              AnimatedInputField(
                                controller: _emailController,
                                label: 'Alamat Email',
                                hint: 'john@email.com',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Masukkan alamat email';
                                  }
                                  if (!RegExp(
                                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                      .hasMatch(v)) {
                                    return 'Format email tidak valid';
                                  }
                                  return null;
                                },
                              ),
                              6,
                            ),
                            const SizedBox(height: 14),

                            // ── Password ────────────────────────────────────
                            _staggered(
                              AnimatedInputField(
                                controller: _passwordController,
                                label: 'Kata Sandi',
                                hint: 'Min. 8 karakter',
                                icon: Icons.lock_outline_rounded,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.next,
                                onChanged: (_) => _checkPasswordStrength(),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                    color: isDark
                                        ? AppTheme.textMuted
                                        : AppTheme.textMutedLight,
                                  ),
                                  onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Masukkan kata sandi';
                                  }
                                  if (v.length < 8) {
                                    return 'Kata sandi minimal 8 karakter';
                                  }
                                  return null;
                                },
                              ),
                              7,
                            ),
                            // ── Password strength bar ───────────────────────
                            if (_passwordController.text.isNotEmpty)
                              _staggered(
                                _PasswordStrengthBar(
                                  strength: _passwordStrength,
                                  color: _strengthColor,
                                  label: _strengthLabel,
                                  icon: _strengthIcon,
                                  isDark: isDark,
                                ),
                                8,
                              ),
                            const SizedBox(height: 14),

                            // ── Confirm password ────────────────────────────
                            _staggered(
                              AnimatedInputField(
                                controller: _confirmPasswordController,
                                label: 'Konfirmasi Kata Sandi',
                                hint: 'Ulangi kata sandi',
                                icon: Icons.lock_outline_rounded,
                                obscureText: _obscureConfirmPassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _handleRegister(),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                    color: isDark
                                        ? AppTheme.textMuted
                                        : AppTheme.textMutedLight,
                                  ),
                                  onPressed: () => setState(() =>
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Ulangi kata sandi';
                                  }
                                  if (v != _passwordController.text) {
                                    return 'Kata sandi tidak cocok';
                                  }
                                  return null;
                                },
                              ),
                              9,
                            ),
                            const SizedBox(height: 20),

                            // ── Terms & conditions ──────────────────────────
                            _staggered(
                              Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _AnimatedCheckbox(
                                  value: _agreedToTerms,
                                  onChanged: (v) => setState(
                                      () => _agreedToTerms = v ?? false),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                        color: isDark
                                            ? AppTheme.textMuted
                                            : AppTheme.textMutedLight,
                                        height: 1.5,
                                      ),
                                      children: [
                                        const TextSpan(
                                            text: 'Saya menyetujui '),
                                        TextSpan(
                                          text: 'Syarat & Ketentuan',
                                          style: TextStyle(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const TextSpan(text: ' dan '),
                                        TextSpan(
                                          text: 'Kebijakan Privasi',
                                          style: TextStyle(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const TextSpan(text: ' Kreavana.'),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              ),
                              10,
                            ),
                            const SizedBox(height: 28),

                            // ── Register button ─────────────────────────────
                            _staggered(
                              GradientButton(
                                text: 'Daftar Sekarang',
                                onPressed: _handleRegister,
                                isLoading: _isLoading,
                              ),
                              11,
                            ),
                            const SizedBox(height: 28),

                            // ── Divider ─────────────────────────────────────
                            _staggered(
                              const AuthDivider(text: 'atau daftar dengan'),
                              12,
                            ),
                            const SizedBox(height: 20),

                            // ── Google ──────────────────────────────────────
                            _staggered(
                              GoogleSignInButton(
                                text: 'Lanjutkan dengan Google',
                                isLoading: _isGoogleLoading,
                                onPressed: _handleGoogleSignIn,
                              ),
                              13,
                            ),
                            const SizedBox(height: 32),

                            // ── Login link ──────────────────────────────────
                            _staggered(
                              Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Sudah punya akun? ',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: isDark
                                        ? AppTheme.textMuted
                                        : AppTheme.textMutedLight,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () =>
                                      Navigator.of(context).pushReplacement(
                                    PageRouteBuilder(
                                      pageBuilder: (_, a, _) =>
                                          const LoginScreen(),
                                      transitionsBuilder: (_, a, _, child) =>
                                          FadeTransition(
                                              opacity: a, child: child),
                                      transitionDuration:
                                          const Duration(milliseconds: 300),
                                    ),
                                  ),
                                  child: Text(
                                    'Masuk di sini',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                              ),
                              14,
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
          ),
        ],
      ),
    );
  }

  Widget _staggered(Widget child, int index) {
    final start = (index * 0.05).clamp(0.0, 0.9);
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

  Widget _buildThemeToggleButton(bool isDark) {
    return Material(
      color: Colors.transparent,
      child: IconButton.filledTonal(
        key: _themeBtnKey,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => RotationTransition(
            turns: Tween(begin: 0.75, end: 1.0).animate(anim),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            key: ValueKey(isDark),
            size: 20,
          ),
        ),
        style: IconButton.styleFrom(
          backgroundColor: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.6),
        ),
        onPressed: () {
          final box =
              _themeBtnKey.currentContext?.findRenderObject() as RenderBox?;
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

// ── Password strength bar ────────────────────────────────────────────────────

class _PasswordStrengthBar extends StatelessWidget {
  final int strength;
  final Color color;
  final String label;
  final IconData icon;
  final bool isDark;

  const _PasswordStrengthBar({
    required this.strength,
    required this.color,
    required this.label,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          ...List.generate(4, (i) {
            final active = i < strength;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: AppMotion.easeOut,
                height: 4,
                margin: EdgeInsets.only(right: i < 3 ? 5 : 0),
                decoration: BoxDecoration(
                  color: active
                      ? color
                      : (isDark ? AppTheme.inputBorder : Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: active
                      ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6)]
                      : null,
                ),
              ),
            );
          }),
          const SizedBox(width: 12),
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: Text(
              label,
              key: ValueKey(strength),
              style: TextStyle(
                fontSize: 11.5,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error banner with shake ──────────────────────────────────────────────────

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

// ── Animated checkbox ────────────────────────────────────────────────────────

class _AnimatedCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _AnimatedCheckbox({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: value ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: value
                ? theme.colorScheme.primary
                : (theme.brightness == Brightness.dark
                    ? AppTheme.inputBorder
                    : AppTheme.inputBorderLight),
            width: 1.5,
          ),
        ),
        child: value
            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
            : null,
      ),
    );
  }
}
