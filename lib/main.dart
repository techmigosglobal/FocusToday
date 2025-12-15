import 'package:flutter/material.dart';
import 'app/theme/app_theme.dart';
import 'features/auth/presentation/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize database
  // await DatabaseService.instance.database;
  
  runApp(const EagleTVApp());
}

class EagleTVApp extends StatelessWidget {
  const EagleTVApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EagleTV',
      debugShowCheckedModeBanner: false,
      
      // Theme
      theme: AppTheme.lightTheme,
      darkTheme:AppTheme.darkTheme,
      themeMode: ThemeMode.light, // Future: Make this dynamic based on user preference
      
      // Home
      home: const SplashScreen(),
    );
  }
}
