import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme.dart';
import '../../../services/theme_transition_service.dart';
import '../services/google_auth_service.dart';
import '../services/auth_service.dart';
import '../../../services/call_service.dart';
import '../../../services/push_notification_service.dart';
import '../../../services/user_store.dart';
import '../../../services/app_router.dart';
import '../../../widgets/social_button.dart';
import '../../../widgets/app_sweet_alert.dart';
import '../../../utils/app_errors.dart';
import 'package:go_router/go_router.dart';

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
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
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
        if (result['success'] == true) {
          currentUserNotifier.value = result['user'];
          if (mounted) context.go(AppRoutes.beranda);
          Future.microtask(() {
            try {
              CallService().initPusher();
              PushNotificationService.initialize();
            } catch (_) {}
          });
        } else {
          final errorCode = result['error_code']?.toString() ?? '';
          if (errorCode == 'email_not_verified') {
            final email =
                result['data']?['email']?.toString() ??
                _usernameOrEmailController.text.trim();
            setState(() => _isLoading = false);
            await AuthService.resendVerificationCode(email: email);
            if (mounted) {
              context.go(
                AppRoutes.verifyEmail,
                extra: {'email': email, 'autoResend': true},
              );
            }
          } else {
            setState(() {
              _isLoading = false;
              _errorMessage = AppErrors.messageFromResult(result);
            });
          }
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
        if (result['is_new_user'] == true) {
          if (mounted) {
            AppSweetAlert.success(
              context,
              'Akun berhasil dibuat. Password sementara telah dikirim ke email Anda.',
              title: 'Akun Dibuat',
            );
          }
          _completeGoogleSignIn(result['user']);
        } else {
          _completeGoogleSignIn(result['user']);
        }
      } else {
        setState(() {
          _errorMessage =
              result['message']?.toString() ??
              'Login dengan Google gagal. Coba lagi.';
        });
      }
    }
  }

  void _completeGoogleSignIn(dynamic user) {
    currentUserNotifier.value = user;
    if (mounted) context.go(AppRoutes.beranda);
    Future.microtask(() {
      try {
        CallService().initPusher();
        PushNotificationService.initialize();
      } catch (_) {}
    });
  }

  void _showForgotPasswordDialog() {
    final prefilled = _usernameOrEmailController.text.trim();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ForgotPasswordDialog(
        initialEmail: prefilled.contains('@') ? prefilled : '',
        onResetSuccess: (email, message) {
          if (!mounted) return;
          _usernameOrEmailController.text = email;
          AppSweetAlert.success(
            context,
            message,
            title: 'Kata Sandi Diperbarui',
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 820;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          // ── Background Ambient Accents ──────────────────────────────────
          Positioned(
            top: -120,
            left: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.2 : 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.18 : 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Theme toggle ─────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 20,
            child: _ThemeToggleButton(themeBtnKey: _themeBtnKey),
          ),

          // ── Main Card Container ──────────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 24 : 16,
                  vertical: 24,
                ),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: isDesktop
                        ? _buildDesktopCard(isDark)
                        : _buildMobileCard(isDark),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Desktop Split-Card Layout (3:2 Proportional) ──────────────────────────
  Widget _buildDesktopCard(bool isDark) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 860),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Left Hero Panel (38%) ──
              Expanded(
                flex: 38,
                child: _buildLeftHeroPanel(),
              ),

              // ── Right Form Panel (62%) ──
              Expanded(
                flex: 62,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 36,
                    vertical: 36,
                  ),
                  child: _buildFormContent(isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Mobile / Tablet Card Layout ──────────────────────────────────────────
  Widget _buildMobileCard(bool isDark) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            _buildMobileHeroHeader(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 28,
              ),
              child: _buildFormContent(isDark),
            ),
          ],
        ),
      ),
    );
  }

  // ── Left Hero Panel (Institutional, Formal & Clean) ──────────────────────
  Widget _buildLeftHeroPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF2563EB), // Official Blue
            Color(0xFF1D4ED8),
            Color(0xFF1E40AF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(32),
      child: Stack(
        children: [
          // Background Geometric Accents
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),

          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Brand
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/brandlogo.png',
                          width: 22,
                          height: 22,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.layers_rounded,
                            size: 22,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'KREAVANA',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Ekosistem Resmi\nKreator & Industri',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sistem kolaborasi terpadu penghubung kreator profesional, peluang proyek, dan instansi.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),

              // Center Emblem Badge
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      'assets/brandlogo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.verified_user_rounded,
                        color: Color(0xFF2563EB),
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom Verification Text
              Container(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'Layanan autentikasi resmi Kreavana. Gunakan akun terverifikasi Anda untuk mengakses sistem.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Mobile Header Hero ───────────────────────────────────────────────────
  Widget _buildMobileHeroHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.asset(
              'assets/brandlogo.png',
              width: 24,
              height: 24,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.layers_rounded,
                size: 24,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KREAVANA',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  'Ekosistem Kolaborasi & Proyek Kreatif',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Right Form Content ───────────────────────────────────────────────────
  Widget _buildFormContent(bool isDark) {
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final fieldBorderColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final fieldFillColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title & Subtitle
          Text(
            'Selamat datang!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: titleColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Masuk ke akun Kreavana Anda untuk mengelola proyek & kolaborasi',
            style: TextStyle(
              fontSize: 12.5,
              color: subtitleColor,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 20),

          // Error Message Banner
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Field: Email / Username
          Text(
            'Email atau Username *',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _usernameOrEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: TextStyle(fontSize: 13.5, color: titleColor),
            decoration: InputDecoration(
              hintText: 'nama@email.com atau username',
              hintStyle: TextStyle(fontSize: 12.5, color: subtitleColor),
              prefixIcon: Icon(
                Icons.mail_outline_rounded,
                size: 18,
                color: subtitleColor,
              ),
              filled: true,
              fillColor: fieldFillColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: fieldBorderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: fieldBorderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFF2563EB),
                  width: 1.5,
                ),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Masukkan username atau email Anda';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Field: Kata Sandi
          Text(
            'Kata Sandi *',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleLogin(),
            style: TextStyle(fontSize: 13.5, color: titleColor),
            decoration: InputDecoration(
              hintText: 'Masukkan kata sandi',
              hintStyle: TextStyle(fontSize: 12.5, color: subtitleColor),
              prefixIcon: Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: subtitleColor,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: subtitleColor,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor: fieldFillColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: fieldBorderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: fieldBorderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFF2563EB),
                  width: 1.5,
                ),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Masukkan kata sandi';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),

          // Remember Me & Forgot Password
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: _rememberMe,
                      onChanged: (val) =>
                          setState(() => _rememberMe = val ?? false),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      activeColor: const Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() => _rememberMe = !_rememberMe),
                    child: Text(
                      'Ingat saya',
                      style: TextStyle(
                        fontSize: 12,
                        color: subtitleColor,
                      ),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _showForgotPasswordDialog,
                borderRadius: BorderRadius.circular(4),
                child: const Text(
                  'Lupa kata sandi?',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Primary Submit Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 1,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Masuk',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),

          // Divider
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'atau',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: subtitleColor,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Google Sign In Button
          GoogleSignInButton(
            text: 'Lanjutkan dengan Google',
            isLoading: _isGoogleLoading,
            onPressed: _handleGoogleSignIn,
          ),
          const SizedBox(height: 16),

          // Footer Register Link
          Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Belum punya akun? ',
                  style: TextStyle(
                    fontSize: 12,
                    color: subtitleColor,
                  ),
                ),
                InkWell(
                  onTap: () => context.go(AppRoutes.register),
                  borderRadius: BorderRadius.circular(4),
                  child: const Text(
                    'Daftar sekarang',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Theme Toggle Button ─────────────────────────────────────────────────────
class _ThemeToggleButton extends StatelessWidget {
  final GlobalKey themeBtnKey;
  const _ThemeToggleButton({required this.themeBtnKey});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: IconButton.filledTonal(
        key: themeBtnKey,
        icon: Icon(
          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          color: isDark ? Colors.amber : const Color(0xFF475569),
          size: 18,
        ),
        style: IconButton.styleFrom(
          backgroundColor: isDark
              ? const Color(0xFF1E293B)
              : Colors.white.withValues(alpha: 0.9),
          elevation: 1,
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

class _ForgotPasswordDialog extends StatefulWidget {
  final String initialEmail;
  final void Function(String email, String message) onResetSuccess;

  const _ForgotPasswordDialog({
    required this.initialEmail,
    required this.onResetSuccess,
  });

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _emailCtrl;
  final TextEditingController _otpCtrl = TextEditingController();
  final TextEditingController _newPasswordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();

  bool _codeSent = false;
  bool _isSubmitting = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSendCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Masukkan alamat email yang valid.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
      _info = null;
    });

    final res = await AuthService.forgotPassword(email: email);
    if (!mounted) return;

    if (res['status'] == true) {
      setState(() {
        _isSubmitting = false;
        _codeSent = true;
        _info =
            res['message']?.toString() ??
            'Kode reset kata sandi 6 digit telah dikirim ke $email.';
      });
    } else {
      setState(() {
        _isSubmitting = false;
        _error = AppErrors.messageFromResult(
          res,
          fallback: 'Gagal mengirim kode reset kata sandi.',
        );
      });
    }
  }

  Future<void> _handleConfirmReset() async {
    final email = _emailCtrl.text.trim();
    final code = _otpCtrl.text.trim();
    final pass = _newPasswordCtrl.text;
    final confirmPass = _confirmPasswordCtrl.text;

    if (code.length != 6) {
      setState(() => _error = 'Masukkan kode verifikasi 6 digit angka.');
      return;
    }
    if (pass.length < 8) {
      setState(() => _error = 'Kata sandi baru minimal 8 karakter.');
      return;
    }
    if (pass != confirmPass) {
      setState(() => _error = 'Konfirmasi kata sandi tidak cocok.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final res = await AuthService.resetPassword(
      email: email,
      code: code,
      password: pass,
      passwordConfirmation: confirmPass,
    );
    if (!mounted) return;

    if (res['status'] == true) {
      final msg =
          res['message']?.toString() ??
          'Kata sandi berhasil diatur ulang. Silakan masuk dengan kata sandi baru Anda.';
      Navigator.pop(context);
      widget.onResetSuccess(email, msg);
    } else {
      setState(() {
        _isSubmitting = false;
        _error = AppErrors.messageFromResult(
          res,
          fallback: 'Gagal mengatur ulang kata sandi.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          const Icon(
            Icons.lock_reset_rounded,
            color: Color(0xFF2563EB),
            size: 22,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _codeSent ? 'Verifikasi Kode & Sandi Baru' : 'Reset Kata Sandi',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _codeSent
                    ? 'Masukkan kode 6 digit yang dikirim ke ${_emailCtrl.text.trim()} beserta kata sandi baru Anda.'
                    : 'Masukkan email akun terdaftar Anda. Kami akan mengirimkan kode verifikasi 6 digit untuk mereset kata sandi.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 14),
              if (_info != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    _info!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF059669),
                    ),
                  ),
                ),
              ],
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
              if (!_codeSent)
                TextField(
                  controller: _emailCtrl,
                  enabled: !_isSubmitting,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Alamat Email',
                    hintText: 'nama@email.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                )
              else ...[
                TextField(
                  controller: _otpCtrl,
                  enabled: !_isSubmitting,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Kode Verifikasi (6 Digit)',
                    counterText: '',
                    prefixIcon: const Icon(Icons.pin_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newPasswordCtrl,
                  enabled: !_isSubmitting,
                  obscureText: _obscureNew,
                  decoration: InputDecoration(
                    labelText: 'Kata Sandi Baru (Min. 8 karakter)',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNew
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPasswordCtrl,
                  enabled: !_isSubmitting,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Konfirmasi Kata Sandi Baru',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        if (_codeSent)
          TextButton(
            onPressed: _isSubmitting ? null : _handleSendCode,
            child: const Text('Kirim Ulang Kode'),
          ),
        ElevatedButton(
          onPressed: _isSubmitting
              ? null
              : (_codeSent ? _handleConfirmReset : _handleSendCode),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(_codeSent ? 'Simpan Kata Sandi' : 'Kirim Kode'),
        ),
      ],
    );
  }
}
