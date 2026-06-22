import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../widgets/gradient_button.dart';
import '../widgets/social_button.dart';
import '../widgets/auth_divider.dart';
import '../main.dart';
import 'register_screen.dart';
import 'main_navigation.dart';
import '../services/auth_service.dart';

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
  bool _rememberMe = false;

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
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
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
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final result = await AuthService.login(
        usernameOrEmail: _usernameOrEmailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Login berhasil!'),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => MainNavigation(initialUser: result['user']),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Login gagal.'),
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
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
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

                            // Title (Material 3 Typography style)
                            Center(
                              child: Text(
                                'Masuk Kreavana',
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
                                'Selamat datang kembali! Silakan masuk ke akun Anda.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: textMutedColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 36),

                            // Username/Email Field
                            TextFormField(
                              controller: _usernameOrEmailController,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Username atau Email',
                                floatingLabelBehavior: FloatingLabelBehavior.auto,
                                labelStyle: TextStyle(color: textMutedColor, fontSize: 14),
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
                                    ? colorScheme.surfaceContainerHighest.withOpacity(0.5) 
                                    : colorScheme.surfaceContainerHighest.withOpacity(0.3),
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
                                  return 'Masukkan username atau email';
                                }
                                if (value.trim().length < 3) {
                                  return 'Minimal 3 karakter';
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
                                floatingLabelBehavior: FloatingLabelBehavior.auto,
                                labelStyle: TextStyle(color: textMutedColor, fontSize: 14),
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
                                    ? colorScheme.surfaceContainerHighest.withOpacity(0.5) 
                                    : colorScheme.surfaceContainerHighest.withOpacity(0.3),
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
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _handleLogin(),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Masukkan kata sandi';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // Remember me & Forgot password
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _rememberMe,
                                      onChanged: (val) {
                                        setState(() {
                                          _rememberMe = val ?? false;
                                        });
                                      },
                                      activeColor: colorScheme.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      side: BorderSide(
                                        color: textMutedColor,
                                        width: 1.5,
                                      ),
                                    ),
                                    Text(
                                      'Ingat saya',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton(
                                  onPressed: () {
                                    // Handle forgot password
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: colorScheme.primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
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
                            const SizedBox(height: 24),

                            // Login Button
                            GradientButton(
                              text: 'Masuk Sekarang',
                              onPressed: _handleLogin,
                              isLoading: _isLoading,
                            ),
                            const SizedBox(height: 32),

                            // Divider
                            const AuthDivider(text: 'Atau masuk dengan'),
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
                                  'Belum punya akun? ',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: textMutedColor,
                                  ),
                                ),
                                InkWell(
                                  borderRadius: BorderRadius.circular(4),
                                  onTap: () {
                                    Navigator.of(context).pushReplacement(
                                      PageRouteBuilder(
                                        pageBuilder: (context, animation, secondaryAnimation) =>
                                            const RegisterScreen(),
                                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                          return FadeTransition(
                                            opacity: animation,
                                            child: child,
                                          );
                                        },
                                        transitionDuration: const Duration(milliseconds: 300),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Text(
                                      'Daftar di sini',
                                      style: theme.textTheme.bodyMedium?.copyWith(
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
                  backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                ),
                onPressed: () {
                  themeNotifier.value =
                      isDark ? ThemeMode.light : ThemeMode.dark;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}