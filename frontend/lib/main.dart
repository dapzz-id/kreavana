import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/theme.dart';
import 'models/user_model.dart';
import 'services/auth_session_state.dart';
import 'services/auth_service.dart';
import 'services/push_notification_service.dart';
import 'services/call_service.dart';
import 'services/badge_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';
import 'widgets/global_call_overlay.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved theme preference (if any) and apply before building the app.
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('theme_mode') ?? 'light';
    themeNotifier.value = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
  } catch (_) {
    // ignore errors and keep default
  }

  // Transparent status bar for all pages on mobile — set according to theme.
  final isDark = themeNotifier.value == ThemeMode.dark;
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    ),
  );

  // Inisialisasi notifikasi di background — jangan blokir splash/login.
  unawaited(PushNotificationService.initialize());

  UserModel? initialUser;
  try {
    final loggedIn = await AuthService.isLoggedIn();
    if (loggedIn) {
      initialUser = await AuthService.getCurrentUser();
      if (initialUser != null) {
        CallService().initPusher();
        BadgeService().startPolling();
      }
    }
  } catch (_) {
    // Session load failed, proceed to login screen
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    // Ignore only known-benign GPU/engine hiccups — NOT everything with 'context'.
    final msg = details.exceptionAsString().toLowerCase();
    if (msg.contains('gpu context lost') ||
        msg.contains('lateinitializationerror') ||
        (msg.contains('context') && msg.contains('surface'))) {
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
          home: ValueListenableBuilder<bool>(
            valueListenable: authSignedOutNotifier,
            builder: (context, isSignedOut, child) {
              if (initialUser != null && !isSignedOut) {
                return MainNavigation(initialUser: initialUser!);
              }

              return const LoginScreen();
            },
          ),
        );
      },
    );
  }
}
