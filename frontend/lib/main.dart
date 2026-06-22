import 'package:flutter/material.dart';
import 'app/theme.dart';
import 'models/user_model.dart';
import 'services/auth_service.dart';
import 'services/push_notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotificationService.initialize();
  
  UserModel? initialUser;
  try {
    final loggedIn = await AuthService.isLoggedIn();
    if (loggedIn) {
      initialUser = await AuthService.getCurrentUser();
    }
  } catch (_) {
    // Session load failed, proceed to login screen
  }

  runApp(KreavanaApp(initialUser: initialUser));
}

class KreavanaApp extends StatelessWidget {
  final UserModel? initialUser;

  const KreavanaApp({super.key, this.initialUser});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Kreavana',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          home: initialUser != null
              ? MainNavigation(initialUser: initialUser!)
              : const LoginScreen(),
        );
      },
    );
  }
}
