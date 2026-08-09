import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/theme.dart';
import 'services/auth_session_state.dart';
import 'features/auth/services/auth_service.dart';
import 'features/auth/screens/login_screen.dart';
import 'services/realtime_service.dart';
import 'services/fcm_service.dart';
import 'services/push_notification_service.dart';
import 'services/call_service.dart';
import 'services/badge_service.dart';
import 'services/user_store.dart';
import 'services/app_router.dart';
import 'services/secure_storage_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'widgets/global_call_overlay.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'services/navigator_key.dart';
export 'services/navigator_key.dart' show navigatorKey;

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pakai path-based URL (/login) bukan hash-based (/#/login)
  usePathUrlStrategy();

  const String env = String.fromEnvironment('ENV', defaultValue: kReleaseMode ? 'production' : 'development');
  await dotenv.load(fileName: ".env.$env");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Aktivasi Firebase App Check
  await FirebaseAppCheck.instance.activate(
    providerWeb: ReCaptchaV3Provider(dotenv.env['RECAPTCHA_SITE_KEY'] ?? ''),
    providerAndroid: env == 'development' ? AndroidDebugProvider() : AndroidPlayIntegrityProvider(),
    providerApple: AppleAppAttestProvider(),
  );

  // Aktivasi Crashlytics hanya untuk Mobile (Non-Web)
  if (!kIsWeb) {
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

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

  // Restore session dari local storage → set ke global user notifier
  try {
    final loggedIn = await AuthService.isLoggedIn();
    if (loggedIn) {
      final user = await AuthService.getCurrentUser();
      if (user != null) {
        currentUserNotifier.value = user;
        authSignedOutNotifier.value = false;
        CallService().initPusher();
        
        final token = await SecureStorageService().getToken();
        if (token != null) {
          RealtimeService().init(user.id ?? '', token);
        }
        
        FCMService().init();
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
    
    // Laporkan ke Crashlytics jika bukan di web
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    }
    
    FlutterError.presentError(details);
  };

  runApp(const KreavanaApp());
}

class KreavanaApp extends StatelessWidget {
  const KreavanaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp.router(
          routerConfig: appRouter,
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
        );
      },
    );
  }
}
