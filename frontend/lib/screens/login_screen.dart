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
import 'register_screen.dart';
import 'main_navigation.dart';
import '../services/auth_service.dart';
import '../services/call_service.dart';
import '../services/push_notification_service.dart';
import '../utils/app_errors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameOrEmailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _rememberMe = false;
  String? _errorMessage;

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
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameOrEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    setState(() => _errorMessage = null);
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final result = await AuthService.login(
        usernameOrEmail: _usernameOrEmailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (result['success'] == true) {
          CallService().initPusher();
          PushNotificationService.initialize();

          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, a, _) =>
                  MainNavigation(initialUser: result['user']),
              transitionsBuilder: (_, a, _, child) =>
                  FadeTransition(opacity: a, child: child),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
        } else {
          setState(() {
            _errorMessage = AppErrors.messageFromResult(result);
          });
        }
      }
    }
  }

  void _handleGoogleSignIn() async {
    setState(() {
      _errorMessage = null;
      _isGoogleLoading = true;
    });

    final result = await GoogleAuthService.signInWithGoogle();

    if (mounted) {
      setState(() => _isGoogleLoading = false);

      if (result['success'] == true) {
        CallService().initPusher();
        PushNotificationService.initialize();

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, a, _) =>
                MainNavigation(initialUser: result['user']),
            transitionsBuilder: (_, a, _, child) =>
                FadeTransition(opacity: a, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      } else {
        setState(() {
          _errorMessage = result['message']?.toString() ??
              'Login dengan Google gagal. Coba lagi.';
        });
      }
    }
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Reset Kata Sandi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan email Anda. Kami akan mengirimkan link reset kata sandi.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Alamat Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Link reset telah dikirim ke ${emailCtrl.text.trim()}',
                  ),
                  backgroundColor: AppTheme.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
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
            child: _ThemeToggleButton(themeBtnKey: _themeBtnKey),
          ),

          // ── Main content ─────────────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
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
                            const SizedBox(height: 16),
                            // ── Logo ────────────────────────────────────────
                            _staggered(
                              Center(
                                child: Hero(
                                  tag: 'app-logo',
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(22),
                                      gradient: AppTheme.primaryGradient,
                                      boxShadow: AppTheme.primaryShadow,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(22),
                                      child: Image.asset(
                                        'assets/brandlogo.png',
                                        width: 80,
                                        height: 80,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, _, _) => const Center(
                                            child: Icon(
                                              Icons.auto_awesome,
                                              color: Colors.white,
                                              size: 40,
                                            ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              0,
                            ),
                            const SizedBox(height: 32),
                            // ── Title ───────────────────────────────────────
                            _staggered(
                              Text(
                                'Masuk ke Kreavana',
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
                                'Selamat datang kembali! Silakan masuk ke akun Anda.',
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
                            const SizedBox(height: 36),

                            // ── Error banner with shake ─────────────────────
                            _staggered(
                              AnimatedSize(
                                duration: const Duration(milliseconds: 250),
                                curve: AppMotion.easeOut,
                                child: _ErrorBanner(message: _errorMessage),
                              ),
                              3,
                            ),
                            const SizedBox(height: 16),

                            // ── Username / Email ───────────────────────────
                            _staggered(
                              AnimatedInputField(
                                controller: _usernameOrEmailController,
                                label: 'Username atau Email',
                                hint: 'user@email.com',
                                icon: Icons.person_outline_rounded,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Masukkan username atau email';
                                  }
                                  if (v.trim().length < 3) {
                                    return 'Minimal 3 karakter';
                                  }
                                  return null;
                                },
                              ),
                              4,
                            ),
                            const SizedBox(height: 16),

                            // ── Password ───────────────────────────────────
                            _staggered(
                              AnimatedInputField(
                                controller: _passwordController,
                                label: 'Kata Sandi',
                                hint: '••••••••',
                                icon: Icons.lock_outline_rounded,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _handleLogin(),
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
                                  return null;
                                },
                              ),
                              5,
                            ),
                            const SizedBox(height: 10),

                            // ── Remember me + Forgot password ──────────────
                            _staggered(
                              Row(
                              children: [
                                _AnimatedCheckbox(
                                  value: _rememberMe,
                                  onChanged: (v) => setState(
                                      () => _rememberMe = v ?? false),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Ingat saya',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: _showForgotPasswordDialog,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                  ),
                                  child: const Text(
                                    'Lupa kata sandi?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              ),
                              6,
                            ),
                            const SizedBox(height: 24),

                            // ── Login button ───────────────────────────────
                            _staggered(
                              GradientButton(
                                text: 'Masuk Sekarang',
                                onPressed: _handleLogin,
                                isLoading: _isLoading,
                              ),
                              7,
                            ),
                            const SizedBox(height: 28),

                            // ── Divider ────────────────────────────────────
                            _staggered(const AuthDivider(text: 'atau masuk dengan'), 8),
                            const SizedBox(height: 20),

                            // ── Google ─────────────────────────────────────
                            _staggered(
                              GoogleSignInButton(
                                text: 'Lanjutkan dengan Google',
                                isLoading: _isGoogleLoading,
                                onPressed: _handleGoogleSignIn,
                              ),
                              9,
                            ),
                            const SizedBox(height: 32),

                            // ── Register link ──────────────────────────────
                            _staggered(
                              Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Belum punya akun? ',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: isDark
                                        ? AppTheme.textMuted
                                        : AppTheme.textMutedLight,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.of(context)
                                      .pushReplacement(
                                    PageRouteBuilder(
                                      pageBuilder: (_, a, _) =>
                                          const RegisterScreen(),
                                      transitionsBuilder: (_, a, _, child) =>
                                          FadeTransition(
                                              opacity: a, child: child),
                                      transitionDuration:
                                          const Duration(milliseconds: 300),
                                    ),
                                  ),
                                  child: Text(
                                    'Daftar sekarang',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                              ),
                              10,
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

// ── Theme toggle ─────────────────────────────────────────────────────────────

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
