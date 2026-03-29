import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../core/error/app_error_handler.dart';
import '../../../../core/services/msg91_service.dart';
import 'otp_verification_screen.dart';

/// Phone Login Screen — Enter phone number and request OTP
class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;

  late AnimationController _enterController;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<Offset>> _slideAnimations;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _enterController.forward();
  }

  void _initAnimations() {
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimations = List.generate(4, (i) {
      return CurvedAnimation(
        parent: _enterController,
        curve: Interval(i * 0.1, 0.5 + i * 0.1, curve: Curves.easeOut),
      );
    });

    _slideAnimations = List.generate(4, (i) {
      return Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _enterController,
          curve: Interval(i * 0.1, 0.5 + i * 0.1, curve: Curves.easeOutCubic),
        ),
      );
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    _enterController.dispose();
    super.dispose();
  }

  bool _isValidPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length == 10;
  }

  Future<void> _sendOTP() async {
    final sendWatch = Stopwatch()..start();
    final phoneRaw = _phoneController.text.trim();
    final phone = phoneRaw.replaceAll(RegExp(r'\D'), '');

    if (!_isValidPhone(phone)) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Please enter a valid 10-digit mobile number.';
      });
      HapticFeedback.mediumImpact();
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    _phoneFocusNode.unfocus();

    try {
      final response = await Msg91Service.sendOTP(phone);
      sendWatch.stop();
      debugPrint(
        '[PhoneLogin][Perf] sendOtpMs=${sendWatch.elapsedMilliseconds}',
      );
      final reqId = response['request_id']?.toString() ?? '';

      if (!mounted) return;

      if (reqId.isEmpty) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Failed to send OTP. Please try again.';
        });
        return;
      }

      setState(() => _isLoading = false);
      final navWatch = Stopwatch()..start();
      final navResult = await Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              OTPVerificationScreen(phoneNumber: phone, reqId: reqId),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(1, 0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: child,
              ),
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
      navWatch.stop();
      debugPrint(
        '[PhoneLogin][Perf] otpScreenNavigationMs=${navWatch.elapsedMilliseconds}',
      );
      if (!mounted) return;
      if (navResult is Map && navResult['phone'] is String) {
        final updated = (navResult['phone'] as String).trim();
        if (updated.isNotEmpty) {
          _phoneController.text = updated;
          _phoneController.selection = TextSelection.collapsed(
            offset: updated.length,
          );
          _phoneFocusNode.requestFocus();
        }
      }
    } catch (e) {
      if (sendWatch.isRunning) sendWatch.stop();
      debugPrint('[PhoneLogin] sendOTP error: $e');
      AppErrorHandler.reportNonFatal(Exception('send_otp_failed error=$e'));
      if (mounted) {
        // Extract real error message to help diagnose issues
        String displayMsg;
        final errorStr = e.toString();
        if (errorStr.contains('401') ||
            errorStr.contains('credential') ||
            errorStr.contains('tokenAuth')) {
          displayMsg = 'OTP service credential error. Contact support.';
        } else if (errorStr.contains('SocketException') ||
            errorStr.contains('Failed host lookup')) {
          displayMsg =
              'Cannot reach OTP server. Check your internet connection.';
        } else if (errorStr.contains('TimeoutException') ||
            errorStr.contains('timed out')) {
          displayMsg = 'OTP request timed out. Please try again.';
        } else if (errorStr.contains('ArgumentError') ||
            errorStr.contains('10-digit')) {
          displayMsg = 'Please enter a valid 10-digit mobile number.';
        } else {
          // Show the actual error so the user/developer can see what's wrong
          displayMsg =
              'Failed to send OTP: ${errorStr.replaceAll('Exception: ', '').replaceAll('StateError: ', '')}';
        }
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = displayMsg;
        });
        HapticFeedback.mediumImpact();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.screenPaddingHorizontal,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),

                    // ── Logo + brand
                    _FadeSlide(
                      animation: _fadeAnimations[0],
                      slide: _slideAnimations[0],
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'Focus_Today_icon.png',
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (context, exception, stackTrace) =>
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    Icons.phone_android_rounded,
                                    size: 40,
                                    color: Colors.white,
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Heading
                    _FadeSlide(
                      animation: _fadeAnimations[1],
                      slide: _slideAnimations[1],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Enter your mobile number',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'We\'ll send you a 4-digit verification code.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.textSecondaryOf(context),
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ── Phone input
                    _FadeSlide(
                      animation: _fadeAnimations[2],
                      slide: _slideAnimations[2],
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: _hasError
                              ? [
                                  BoxShadow(
                                    color: AppColors.error.withValues(
                                      alpha: 0.15,
                                    ),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Semantics(
                          textField: true,
                          label: 'Phone number input, 10 digits',
                          child: TextField(
                            controller: _phoneController,
                            focusNode: _phoneFocusNode,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (_) {
                              if (_hasError) setState(() => _hasError = false);
                            },
                            onSubmitted: (_) => _sendOTP(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                            ),
                            decoration: InputDecoration(
                              hintText: '98765 43210',
                              hintStyle: TextStyle(
                                color: AppColors.textSecondaryOf(
                                  context,
                                ).withValues(alpha: 0.5),
                                fontWeight: FontWeight.w400,
                                letterSpacing: 1,
                              ),
                              errorText: _errorMessage,
                              counterText: '',
                              prefixIcon: Container(
                                margin: const EdgeInsets.only(
                                  left: 14,
                                  right: 10,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '🇮🇳 +91',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 0,
                                minHeight: 0,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 18,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: AppColors.divider,
                                  width: 1.5,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? AppColors.textSecondaryDark.withValues(
                                          alpha: 0.3,
                                        )
                                      : AppColors.divider,
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: AppColors.error,
                                  width: 1.5,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: AppColors.error,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Send OTP button
                    _FadeSlide(
                      animation: _fadeAnimations[3],
                      slide: _slideAnimations[3],
                      child: SizedBox(
                        height: 54,
                        child: Semantics(
                          button: true,
                          label: 'Send OTP',
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _sendOTP,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: _isLoading ? 0 : 2,
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _isLoading
                                  ? const SizedBox(
                                      key: ValueKey('loading'),
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Text(
                                      key: ValueKey('send'),
                                      'Send OTP',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Terms note
                    FadeTransition(
                      opacity: _fadeAnimations[3],
                      child: Text(
                        'By continuing, you agree to our Terms of Service and Privacy Policy.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondaryOf(
                            context,
                          ).withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Helper widget for fade + slide-up entrance animations
class _FadeSlide extends StatelessWidget {
  final Animation<double> animation;
  final Animation<Offset> slide;
  final Widget child;

  const _FadeSlide({
    required this.animation,
    required this.slide,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(position: slide, child: child),
    );
  }
}
