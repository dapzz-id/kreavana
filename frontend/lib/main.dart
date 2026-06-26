import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app/theme.dart';
import 'models/user_model.dart';
import 'services/auth_service.dart';
import 'services/push_notification_service.dart';
import 'services/call_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';
import 'widgets/global_call_overlay.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Transparent status bar for all pages on mobile
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  // Inisialisasi notifikasi di background — jangan blokir splash/login.
  unawaited(PushNotificationService.initialize());

  UserModel? initialUser;
  try {
    final loggedIn = await AuthService.isLoggedIn();
    if (loggedIn) {
      initialUser = await AuthService.getCurrentUser();
      if (initialUser != null) {
        CallService().initPusher();
      }
    }
  } catch (_) {
    // Session load failed, proceed to login screen
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    // Ignore GPU context lost errors
    if (details.toString().contains('context') || 
        details.toString().contains('LateInitializationError')) {
      return;
    }
    FlutterError.presentError(details);
  };

  runApp(KreavanaApp(initialUser: initialUser));
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class KreavanaApp extends StatelessWidget {
  final UserModel? initialUser;

  const KreavanaApp({super.key, this.initialUser});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Kreavana',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          builder: (context, child) {
            return Stack(
              children: [
                child ?? const SizedBox.shrink(),
                const GlobalCallOverlay(),
              ],
            );
          },
          home: initialUser != null
              ? MainNavigation(initialUser: initialUser!)
              : const LoginScreen(),
        );
      },
    );
  }
}
