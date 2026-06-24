import 'package:flutter/material.dart';
import '../widgets/gradient_button.dart';
import '../widgets/social_button.dart';
import '../widgets/auth_divider.dart';
import '../main.dart';
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

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
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
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Pendaftaran berhasil! Silakan masuk.'),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Pendaftaran gagal.'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Warna teks dan border yang lebih soft untuk Material 3
    final textMutedColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final borderColor = isDark ? Colors.white24 : Colors.black12;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Logo
                            Center(
                              child: Image.asset(
                                'assets/brandlogo.png',
                                width: 84,
                                height: 84,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Title
                            Center(
                              child: Text(
                                'Daftar Kreavana',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onSurface,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: Text(
                                'Buat akun baru untuk memulai.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: textMutedColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 36),

                            // Name Field
                            TextFormField(
                              controller: _nameController,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Nama Lengkap',
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.auto,
                                labelStyle: TextStyle(color: textMutedColor),
                                floatingLabelStyle: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                                prefixIcon: Icon(
                                  Icons.person_outline_rounded,
                                  color: textMutedColor,
                                  size: 22,
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.5)
                                    : colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: borderColor,
                                    width: 1.0,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: colorScheme.primary,
                                    width: 1.5,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                              ),
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Masukkan nama lengkap';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Username Field
                            TextFormField(
                              controller: _usernameController,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Username',
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.auto,
                                labelStyle: TextStyle(color: textMutedColor),
                                floatingLabelStyle: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                                prefixIcon: Icon(
                                  Icons.alternate_email_rounded,
                                  color: textMutedColor,
                                  size: 22,
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.5)
                                    : colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: borderColor,
                                    width: 1.0,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: colorScheme.primary,
                                    width: 1.5,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                              ),
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Masukkan username';
                                }
                                if (value.trim().length < 3) {
                                  return 'Username minimal 3 karakter';
                                }
                                if (!RegExp(
                                  r'^[a-zA-Z0-9_\.]+$',
                                ).hasMatch(value.trim())) {
                                  return 'Hanya huruf, angka, titik, atau underscore';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Email Field
                            TextFormField(
                              controller: _emailController,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Alamat Email',
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.auto,
                                labelStyle: TextStyle(color: textMutedColor),
                                floatingLabelStyle: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                                prefixIcon: Icon(
                                  Icons.email_outlined,
                                  color: textMutedColor,
                                  size: 22,
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.5)
                                    : colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: borderColor,
                                    width: 1.0,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: colorScheme.primary,
                                    width: 1.5,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Masukkan alamat email';
                                }
                                if (!RegExp(
                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                ).hasMatch(value)) {
                                  return 'Format email tidak valid';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Password Field
                            TextFormField(
                              controller: _passwordController,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Kata Sandi',
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.auto,
                                labelStyle: TextStyle(color: textMutedColor),
                                floatingLabelStyle: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                                prefixIcon: Icon(
                                  Icons.lock_outline_rounded,
                                  color: textMutedColor,
                                  size: 22,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: textMutedColor,
                                    size: 22,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.5)
                                    : colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: borderColor,
                                    width: 1.0,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: colorScheme.primary,
                                    width: 1.5,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                              ),
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Masukkan kata sandi';
                                }
                                if (value.length < 8) {
                                  return 'Kata sandi minimal 8 karakter';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Confirm Password Field
                            TextFormField(
                              controller: _confirmPasswordController,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Konfirmasi Kata Sandi',
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.auto,
                                labelStyle: TextStyle(color: textMutedColor),
                                floatingLabelStyle: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                                prefixIcon: Icon(
                                  Icons.lock_outline_rounded,
                                  color: textMutedColor,
                                  size: 22,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: textMutedColor,
                                    size: 22,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
                                    });
                                  },
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.5)
                                    : colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: borderColor,
                                    width: 1.0,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: colorScheme.primary,
                                    width: 1.5,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                              ),
                              obscureText: _obscureConfirmPassword,
                              textInputAction: TextInputAction.done,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Ulangi kata sandi';
                                }
                                if (value != _passwordController.text) {
                                  return 'Kata sandi tidak cocok';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 32),

                            // Register Button
                            GradientButton(
                              text: 'Daftar Sekarang',
                              onPressed: _handleRegister,
                              isLoading: _isLoading,
                            ),
                            const SizedBox(height: 32),

                            // Divider
                            const AuthDivider(text: 'Atau daftar dengan'),
                            const SizedBox(height: 24),

                            // Google Button
                            GoogleSignInButton(
                              text: 'Lanjutkan dengan Google',
                              onPressed: () {
                                // Handle Google sign-in
                              },
                            ),
                            const SizedBox(height: 32),

                            // Footer Link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Sudah punya akun? ',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: textMutedColor,
                                  ),
                                ),
                                InkWell(
                                  borderRadius: BorderRadius.circular(4),
                                  onTap: () {
                                    Navigator.of(context).pushReplacement(
                                      PageRouteBuilder(
                                        pageBuilder:
                                            (
                                              context,
                                              animation,
                                              secondaryAnimation,
                                            ) => const LoginScreen(),
                                        transitionsBuilder:
                                            (
                                              context,
                                              animation,
                                              secondaryAnimation,
                                              child,
                                            ) {
                                              return FadeTransition(
                                                opacity: animation,
                                                child: child,
                                              );
                                            },
                                        transitionDuration: const Duration(
                                          milliseconds: 300,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      'Masuk di sini',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Theme Toggle Button
            Positioned(
              top: 16,
              right: 16,
              child: IconButton.filledTonal(
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                ),
                onPressed: () {
                  themeNotifier.value = isDark
                      ? ThemeMode.light
                      : ThemeMode.dark;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
