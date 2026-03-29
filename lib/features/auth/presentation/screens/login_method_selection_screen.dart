import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import 'phone_login_screen.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/page_transitions.dart';
import '../../../legal/presentation/screens/legal_screens.dart';
import '../../../../main.dart';

/// Login Method Selection Screen
/// OTP-only authentication entry screen.
class LoginMethodSelectionScreen extends StatefulWidget {
  const LoginMethodSelectionScreen({super.key});

  @override
  State<LoginMethodSelectionScreen> createState() =>
      _LoginMethodSelectionScreenState();
}

class _LoginMethodSelectionScreenState extends State<LoginMethodSelectionScreen>
    with SingleTickerProviderStateMixin {
  AppLanguage _currentLanguage = AppLanguage.english;
  LanguageService? _languageService;
  bool _isLanguageListenerAttached = false;
  late final AnimationController _enterController;
  late final List<Animation<double>> _fades;
  late final List<Animation<Offset>> _slides;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fades = List.generate(
      5,
      (i) => CurvedAnimation(
        parent: _enterController,
        curve: Interval(i * 0.08, 0.5 + i * 0.08, curve: Curves.easeOut),
      ),
    );
    _slides = List.generate(
      5,
      (i) =>
          Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
            CurvedAnimation(
              parent: _enterController,
              curve: Interval(
                i * 0.08,
                0.5 + i * 0.08,
                curve: Curves.easeOutCubic,
              ),
            ),
          ),
    );
    _enterController.forward();
    _loadLanguage();
  }

  @override
  void dispose() {
    if (_isLanguageListenerAttached && _languageService != null) {
      _languageService!.removeListener(_handleLanguageChange);
      _isLanguageListenerAttached = false;
    }
    _enterController.dispose();
    super.dispose();
  }

  Future<void> _loadLanguage() async {
    final languageService =
        FocusTodayApp.languageService ?? await LanguageService.init();
    FocusTodayApp.languageService ??= languageService;
    _languageService = languageService;
    if (!_isLanguageListenerAttached) {
      languageService.addListener(_handleLanguageChange);
      _isLanguageListenerAttached = true;
    }
    if (mounted) {
      setState(() {
        _currentLanguage = languageService.currentLanguage;
      });
    }
  }

  void _handleLanguageChange() {
    final languageService = _languageService;
    if (!mounted || languageService == null) return;
    final nextLanguage = languageService.currentLanguage;
    if (nextLanguage == _currentLanguage) return;
    setState(() => _currentLanguage = nextLanguage);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations(_currentLanguage);
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmall = screenHeight < 700;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: AppDimensions.responsivePadding(context),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: screenHeight - MediaQuery.of(context).padding.vertical,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: isSmall ? 40 : 60),

                // Logo
                _FadeSlide(
                  fade: _fades[0],
                  slide: _slides[0],
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'Focus_Today_icon.png',
                        width: isSmall ? 100 : 120,
                        height: isSmall ? 100 : 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: isSmall ? 100 : 120,
                          height: isSmall ? 100 : 120,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.connected_tv,
                            size: 56,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: isSmall ? 20 : 28),

                // Title
                _FadeSlide(
                  fade: _fades[1],
                  slide: _slides[1],
                  child: Column(
                    children: [
                      Text(
                        localizations.welcomeTo,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in using your phone number',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: isSmall ? 32 : 48),

                // Phone OTP Login
                _FadeSlide(
                  fade: _fades[2],
                  slide: _slides[2],
                  child: _buildLoginOption(
                    icon: Icons.phone_android_rounded,
                    title: 'Phone Number',
                    subtitle: 'Quick sign in with OTP',
                    isPrimary: true,
                    onTap: () {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const PhoneLoginScreen(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) =>
                                  FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                          transitionDuration: const Duration(milliseconds: 300),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 48),

                // Language selector
                _FadeSlide(
                  fade: _fades[3],
                  slide: _slides[3],
                  child: Center(
                    child: Wrap(
                      spacing: 8,
                      children: [
                        _buildLangChip('English', AppLanguage.english),
                        _buildLangChip('తెలుగు', AppLanguage.telugu),
                        _buildLangChip('हिन्दी', AppLanguage.hindi),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: isSmall ? 20 : 32),

                // Privacy policy link
                _FadeSlide(
                  fade: _fades[4],
                  slide: _slides[4],
                  child: Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          SmoothPageRoute(
                            builder: (_) => const PrivacyPolicyScreen(),
                          ),
                        );
                      },
                      child: Text(
                        localizations.privacyPolicy,
                        style: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLangChip(String label, AppLanguage language) {
    final isSelected = _currentLanguage == language;
    return GestureDetector(
      onTap: () async {
        final service = _languageService;
        if (service == null) return;
        await service.setLanguage(language);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusCard),
        splashColor: AppColors.primary.withValues(alpha: 0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusCard),
            border: Border.all(
              color: isPrimary
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.dividerOf(context),
              width: isPrimary ? 1.5 : 1,
            ),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isPrimary
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isPrimary ? Colors.white : AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppColors.textSecondaryOf(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable fade + slide-up entrance animation widget
class _FadeSlide extends StatelessWidget {
  final Animation<double> fade;
  final Animation<Offset> slide;
  final Widget child;

  const _FadeSlide({
    required this.fade,
    required this.slide,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: fade,
    child: SlideTransition(position: slide, child: child),
  );
}
