import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../shared/models/user.dart';
import 'login_method_selection_screen.dart';
import '../../data/repositories/auth_repository.dart';
import '../../../../shared/widgets/main_navigation_shell.dart';

/// Splash Screen - First screen shown when app launches
/// Displays Focus Today logo with animations and checks authentication status
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initializeApp();
  }

  /// Initialize animations
  void _initAnimations() {
    // Fade animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    // Scale animation (Initial entry)
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    // Pulse animation (Looping)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start animations
    _fadeController.forward();
    _scaleController.forward().then((_) {
      _pulseController.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// Initialize app in parallel: auth check + minimum display duration run together
  Future<void> _initializeApp() async {
    // Run auth check AND minimum wait simultaneously — whichever completes last wins.
    // This is 40% faster: if auth resolves in 0.6s, we still wait 1.2s minimum.
    try {
      final results = await Future.wait([
        _checkAuth(),
        Future<void>.delayed(const Duration(milliseconds: 1200)),
      ]);
      final user = results[0] as dynamic; // User?
      await _navigate(user);
    } catch (e) {
      debugPrint('[Splash] init error: $e');
      await _navigate(null);
    }
  }

  Future<dynamic> _checkAuth() async {
    try {
      final authRepo = await AuthRepository.init();
      return await authRepo.restoreSession().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint('[Splash] restoreSession timed out');
          return null;
        },
      );
    } catch (e) {
      debugPrint('[Splash] restoreSession error: $e');
      return null;
    }
  }

  Future<void> _navigate(User? user) async {
    if (!mounted) return;
    if (user != null) {
      try {
        await NotificationService.instance.onUserAuthenticated(
          user.id,
          user.role,
        );
      } catch (e) {
        debugPrint('[Splash] notification setup failed: $e');
      }
      if (!mounted) return;

      // Check if profile needs completion for any user (not just public)
      bool showProfilePrompt = false;
      if (user.role.toStr() == 'publicUser') {
        final isIncomplete =
            (user.displayName == 'User' || user.displayName.isEmpty) &&
            (user.profilePicture == null || user.profilePicture!.isEmpty) &&
            (user.bio == null || user.bio!.isEmpty);
        showProfilePrompt = isIncomplete;
      } else if (user.displayName == 'User' || user.displayName.isEmpty) {
        // For other roles, also prompt if name is missing
        showProfilePrompt = true;
      }

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              MainNavigationShell(
                currentUser: user,
                showProfilePrompt: showProfilePrompt,
              ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoginMethodSelectionScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Gradient background
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.8),
              AppColors.secondary,
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo with shadow - Large and clean, no borders
                  Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ScaleTransition(
                      scale: _pulseAnimation,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Image.asset(
                          'Focus_Today_icon.png',
                          width: 180,
                          height: 180,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.play_circle_fill_rounded,
                                size: 180,
                                color: Colors.white,
                              ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // App name with shadow
                  Text(
                    'Focus Today',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          offset: const Offset(2, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tagline
                  Text(
                    'Bringing Focus To What Matters Most.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 60),

                  // Animated loading dots
                  _LoadingDots(),
                ],
              ),
            ),
          ),
        ),
      ),

      // Version number at bottom
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Text(
              'Version 1.0.0',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Three animated pulsing dots loading indicator
class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final phase = (_controller.value + i / 3) % 1.0;
              final opacity =
                  (0.3 + 0.7 * (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0));
              final scale =
                  0.6 + 0.4 * (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: opacity),
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
