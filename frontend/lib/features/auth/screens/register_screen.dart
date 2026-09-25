import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../services/theme_transition_service.dart';
import '../services/google_auth_service.dart';
import '../services/auth_service.dart';
import '../../../services/call_service.dart';
import '../../../services/push_notification_service.dart';
import '../../../services/user_store.dart';
import '../../../services/app_router.dart';
import '../../../widgets/social_button.dart';
import 'package:go_router/go_router.dart';

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
      setState(
        () => _errorMessage =
            'Anda harus menyetujui syarat & ketentuan terlebih dahulu.',
      );
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
                  Expanded(
                    child: Text(
                      'Pendaftaran berhasil! Silakan verifikasi email Anda.',
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          context.go(
            AppRoutes.verifyEmail,
            extra: {'email': _emailController.text.trim(), 'autoResend': false},
          );
        } else {
          setState(() {
            _errorMessage =
                result['message']?.toString() ??
                'Pendaftaran gagal. Silakan periksa kembali data Anda.';
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
        if (result['is_new_user'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Akun berhasil dibuat. Password sementara telah dikirim ke email Anda.',
                ),
                backgroundColor: AppTheme.success,
              ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 860;

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
                    const Color(0xFF2563EB).withValues(alpha: isDark ? 0.2 : 0.12),
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
                    const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.18 : 0.1),
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

  // ── Desktop Split-Card Layout ────────────────────────────────────────────
  Widget _buildDesktopCard(bool isDark) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 920),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Left Hero Panel (36%) ──
              Expanded(
                flex: 36,
                child: _buildLeftHeroPanel(),
              ),

              // ── Right Form Panel (64%) ──
              Expanded(
                flex: 64,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 36,
                    vertical: 32,
                  ),
                  child: _buildFormContent(isDark, isDesktop: true),
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
      constraints: const BoxConstraints(maxWidth: 480),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
                vertical: 24,
              ),
              child: _buildFormContent(isDark, isDesktop: false),
            ),
          ],
        ),
      ),
    );
  }

  // ── Left Hero Panel ──────────────────────────────────────────────────────
  Widget _buildLeftHeroPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF2563EB),
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
                    'Pendaftaran Akun Resmi\nTalenta & Klien',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bergabung bersama ribuan kreator, vendor, dan pelaku industri kreatif di seluruh Indonesia.',
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
                        Icons.app_registration_rounded,
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
                  'Data terenkripsi dan terlindungi. Verifikasi identitas dapat dilengkapi setelah pendaftaran.',
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
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
                  'Pendaftaran Akun Baru',
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
  Widget _buildFormContent(bool isDark, {required bool isDesktop}) {
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
          Text(
            'Daftar Akun Baru',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: titleColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Lengkapi formulir di bawah ini untuk memulai di Kreavana',
            style: TextStyle(
              fontSize: 12.5,
              color: subtitleColor,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 18),

          // Error Banner
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
            const SizedBox(height: 12),
          ],

          // Row 1: Nama Lengkap & Username (Side-by-Side on Desktop)
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTextField(
                    title: 'Nama Lengkap *',
                    controller: _nameController,
                    hint: 'Nama Lengkap Anda',
                    icon: Icons.badge_outlined,
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                    fieldBorderColor: fieldBorderColor,
                    fieldFillColor: fieldFillColor,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildTextField(
                    title: 'Username *',
                    controller: _usernameController,
                    hint: 'username_anda',
                    icon: Icons.alternate_email_rounded,
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                    fieldBorderColor: fieldBorderColor,
                    fieldFillColor: fieldFillColor,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                      if (v.trim().length < 3) return 'Min 3 karakter';
                      return null;
                    },
                  ),
                ),
              ],
            )
          else ...[
            _buildTextField(
              title: 'Nama Lengkap *',
              controller: _nameController,
              hint: 'Nama Lengkap Anda',
              icon: Icons.badge_outlined,
              titleColor: titleColor,
              subtitleColor: subtitleColor,
              fieldBorderColor: fieldBorderColor,
              fieldFillColor: fieldFillColor,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              title: 'Username *',
              controller: _usernameController,
              hint: 'username_anda',
              icon: Icons.alternate_email_rounded,
              titleColor: titleColor,
              subtitleColor: subtitleColor,
              fieldBorderColor: fieldBorderColor,
              fieldFillColor: fieldFillColor,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                if (v.trim().length < 3) return 'Min 3 karakter';
                return null;
              },
            ),
          ],
          const SizedBox(height: 12),

          // Row 2: Alamat Email
          _buildTextField(
            title: 'Alamat Email *',
            controller: _emailController,
            hint: 'email@domain.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            titleColor: titleColor,
            subtitleColor: subtitleColor,
            fieldBorderColor: fieldBorderColor,
            fieldFillColor: fieldFillColor,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Wajib diisi';
              if (!v.contains('@') || !v.contains('.')) return 'Email tidak valid';
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Row 3: Kata Sandi & Konfirmasi Sandi (Side-by-Side on Desktop)
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildPasswordField(
                    title: 'Kata Sandi *',
                    controller: _passwordController,
                    obscure: _obscurePassword,
                    onToggle: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                    fieldBorderColor: fieldBorderColor,
                    fieldFillColor: fieldFillColor,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                      if (v.length < 6) return 'Min 6 karakter';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildPasswordField(
                    title: 'Konfirmasi Sandi *',
                    controller: _confirmPasswordController,
                    obscure: _obscureConfirmPassword,
                    onToggle: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                    fieldBorderColor: fieldBorderColor,
                    fieldFillColor: fieldFillColor,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                      if (v != _passwordController.text) {
                        return 'Sandi tidak cocok';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            )
          else ...[
            _buildPasswordField(
              title: 'Kata Sandi *',
              controller: _passwordController,
              obscure: _obscurePassword,
              onToggle: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              titleColor: titleColor,
              subtitleColor: subtitleColor,
              fieldBorderColor: fieldBorderColor,
              fieldFillColor: fieldFillColor,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                if (v.length < 6) return 'Min 6 karakter';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildPasswordField(
              title: 'Konfirmasi Sandi *',
              controller: _confirmPasswordController,
              obscure: _obscureConfirmPassword,
              onToggle: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
              titleColor: titleColor,
              subtitleColor: subtitleColor,
              fieldBorderColor: fieldBorderColor,
              fieldFillColor: fieldFillColor,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                if (v != _passwordController.text) return 'Sandi tidak cocok';
                return null;
              },
            ),
          ],
          const SizedBox(height: 12),

          // Terms Checkbox
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: _agreedToTerms,
                  onChanged: (val) =>
                      setState(() => _agreedToTerms = val ?? false),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  activeColor: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Saya menyetujui Syarat & Ketentuan Layanan Kreavana',
                  style: TextStyle(
                    fontSize: 12,
                    color: subtitleColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
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
                      'Daftar Sekarang',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),

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
          const SizedBox(height: 12),

          // Google Sign-In
          GoogleSignInButton(
            text: 'Daftar dengan Google',
            isLoading: _isGoogleLoading,
            onPressed: _handleGoogleSignIn,
          ),
          const SizedBox(height: 14),

          // Footer Link to Login
          Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Sudah punya akun? ',
                  style: TextStyle(
                    fontSize: 12,
                    color: subtitleColor,
                  ),
                ),
                InkWell(
                  onTap: () => context.go(AppRoutes.login),
                  borderRadius: BorderRadius.circular(4),
                  child: const Text(
                    'Masuk',
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

  Widget _buildTextField({
    required String title,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color titleColor,
    required Color subtitleColor,
    required Color fieldBorderColor,
    required Color fieldFillColor,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: TextInputAction.next,
          style: TextStyle(fontSize: 13, color: titleColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 12, color: subtitleColor),
            prefixIcon: Icon(icon, size: 17, color: subtitleColor),
            filled: true,
            fillColor: fieldFillColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
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
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required String title,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    required Color titleColor,
    required Color subtitleColor,
    required Color fieldBorderColor,
    required Color fieldFillColor,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          textInputAction: TextInputAction.next,
          style: TextStyle(fontSize: 13, color: titleColor),
          decoration: InputDecoration(
            hintText: 'Minimal 6 karakter',
            hintStyle: TextStyle(fontSize: 12, color: subtitleColor),
            prefixIcon: Icon(Icons.lock_outline_rounded, size: 17, color: subtitleColor),
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 17,
                color: subtitleColor,
              ),
              onPressed: onToggle,
            ),
            filled: true,
            fillColor: fieldFillColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
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
          validator: validator,
        ),
      ],
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
