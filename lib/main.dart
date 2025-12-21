import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'app/theme/app_theme.dart';
import 'features/auth/presentation/screens/splash_screen.dart';
import 'core/services/language_service.dart';
import 'core/services/permission_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Supabase with environment variables
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize database
  // await DatabaseService.instance.database;

  runApp(const EagleTVApp());
}

class EagleTVApp extends StatefulWidget {
  const EagleTVApp({super.key});

  @override
  State<EagleTVApp> createState() => _EagleTVAppState();
}

class _EagleTVAppState extends State<EagleTVApp> {
  LanguageService? _languageService;
  final PermissionService _permissionService = PermissionService();

  @override
  void initState() {
    super.initState();
    _initLanguage();
    _requestNotificationPermission();
  }

  Future<void> _initLanguage() async {
    final service = await LanguageService.init();
    setState(() {
      _languageService = service;
    });
  }

  /// Request notification permission after a delay
  Future<void> _requestNotificationPermission() async {
    // Wait a bit to not overwhelm user with permissions immediately
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      await _permissionService.requestNotificationPermission(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_languageService == null) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return AnimatedBuilder(
      animation: _languageService!,
      builder: (context, child) {
        return MaterialApp(
          title: 'EagleTV',
          debugShowCheckedModeBanner: false,

          // Theme
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light, // Future: Make this dynamic
          // Localization
          locale: Locale(_languageService!.currentLanguage.code),

          // Home
          home: const SplashScreen(),
        );
      },
    );
  }
}
