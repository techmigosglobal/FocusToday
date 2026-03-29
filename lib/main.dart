import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'app/theme/app_theme.dart';
import 'features/auth/presentation/screens/splash_screen.dart';
import 'core/services/language_service.dart';
import 'core/services/theme_service.dart';
import 'core/services/permission_service.dart';
import 'core/services/cache_service.dart';
import 'core/services/notification_service.dart'
    show NotificationService, firebaseMessagingBackgroundHandler;
import 'core/error/app_error_handler.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/msg91_service.dart';
import 'core/services/post_interaction_sync_service.dart';

/// Focus Today - Firebase-first backend (Firestore/Storage/Functions)
void main() {
  AppErrorHandler.runGuarded(() async {
    // Load environment variables from .env
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      debugPrint('Warning: .env file not found or failed to load: $e');
    }

    // Phase 1 — Critical init required before runApp.
    // Firebase must be initialized before anything else.
    await _initializeFirebaseCore();

    // Phase 2 — Lightweight services that are fast to init.
    await Future.wait([
      CacheService.init(),
      ConnectivityService().init(),
    ], eagerError: false);

    // Launch the app immediately — defer heavy init to after first frame.
    runApp(const ProviderScope(child: FocusTodayApp()));
  });
}

/// Initialize Firebase core only (no messaging/crashlytics yet).
Future<void> _initializeFirebaseCore() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Warning: Firebase core initialization failed: $e');
  }
}

/// Deferred heavy initialization — called after first frame renders.
Future<void> _deferredInit() async {
  await Future.wait([
    _initializeMsg91(),
    _initializeFirebaseMessagingAndCrashlytics(),
  ], eagerError: false);

  // Initialize queued interaction replay after API/connectivity are ready.
  await PostInteractionSyncService.instance.init();
}

class FocusTodayApp extends StatefulWidget {
  const FocusTodayApp({super.key});

  // Static accessor for theme service
  static ThemeService? themeService;
  static LanguageService? languageService;

  @override
  State<FocusTodayApp> createState() => _FocusTodayAppState();
}

class _FocusTodayAppState extends State<FocusTodayApp> {
  ThemeService? _themeService;
  LanguageService? _languageService;
  final PermissionService _permissionService = PermissionService();
  bool _deferredInitStarted = false;

  @override
  void initState() {
    super.initState();
    _initServices();
    // Kick off deferred heavy init after the first frame renders.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runDeferredInit();
      _requestNotificationPermission();
    });
  }

  Future<void> _runDeferredInit() async {
    if (_deferredInitStarted) return;
    _deferredInitStarted = true;
    await _deferredInit();
  }

  Future<void> _initServices() async {
    final langService = await LanguageService.init();
    final themeService = await ThemeService.init();
    setState(() {
      _languageService = langService;
      _themeService = themeService;
      FocusTodayApp.languageService = langService;
      FocusTodayApp.themeService = themeService;
    });
  }

  /// Request notification permission after a delay
  Future<void> _requestNotificationPermission() async {
    // Wait a bit to not overwhelm user with permissions immediately
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // Use navigator context (inside MaterialApp) so MaterialLocalizations are available.
    final dialogContext = NotificationService.navigatorKey.currentContext;
    if (dialogContext == null || !dialogContext.mounted) return;

    try {
      await _permissionService.requestNotificationPermission(dialogContext);
    } catch (e) {
      debugPrint('Warning: Notification permission prompt failed safely: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_languageService == null || _themeService == null) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return ListenableBuilder(
      listenable: Listenable.merge([_languageService!, _themeService!]),
      builder: (context, child) {
        return MaterialApp(
          title: 'Focus Today',
          debugShowCheckedModeBanner: false,
          navigatorKey: NotificationService.navigatorKey,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('hi'), Locale('te')],

          // Theme
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: _themeService!.isDarkMode
              ? ThemeMode.dark
              : ThemeMode.light,

          // Localization
          locale: Locale(_languageService!.currentLanguage.code),

          // Home
          home: const SplashScreen(),
        );
      },
    );
  }
}

Future<void> _initializeMsg91() async {
  try {
    await Msg91Service.initialize();
  } catch (e) {
    debugPrint('Warning: Msg91 initialization failed: $e');
  }
}

Future<void> _initializeFirebaseMessagingAndCrashlytics() async {
  try {
    // Enable Crashlytics — pass all Flutter errors in release mode
    if (!kDebugMode) {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
    }

    if (!_isBackgroundHandlerRegistered) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      _isBackgroundHandlerRegistered = true;
    }
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('Warning: Firebase messaging/crashlytics init failed: $e');
  }
}

bool _isBackgroundHandlerRegistered = false;
