import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../core/error/app_error_handler.dart';
import '../../../../core/services/msg91_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/ux_telemetry_service.dart';
import '../../../../shared/widgets/main_navigation_shell.dart';
import '../../data/repositories/auth_repository.dart';
import '../utils/otp_input_utils.dart';

/// OTP Verification Screen — Verifies OTP via Msg91.
class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String reqId;

  const OTPVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.reqId,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen>
    with TickerProviderStateMixin {
  static const int _otpLength = OtpInputUtils.otpLength;

  final List<TextEditingController> _otpControllers = List.generate(
    _otpLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    _otpLength,
    (_) => FocusNode(),
  );

  late final TextEditingController _phoneEditController;
  late String _activePhoneNumber;
  late String _activeReqId;

  final UxTelemetryService _telemetry = UxTelemetryService.instance;

  bool _isLoading = false;
  bool _isResending = false;
  final ValueNotifier<int> _resendCountdown = ValueNotifier<int>(30);
  final ValueNotifier<String?> _inlineError = ValueNotifier<String?>(null);
  Timer? _resendTimer;

  late AnimationController _enterController;
  late List<Animation<Offset>> _slideAnimations;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _activePhoneNumber = widget.phoneNumber;
    _activeReqId = widget.reqId;
    _phoneEditController = TextEditingController(text: _activePhoneNumber);
    _initAnimations();
    _startResendCountdown();
  }

  @override
  void dispose() {
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    _phoneEditController.dispose();
    _resendCountdown.dispose();
    _inlineError.dispose();
    _resendTimer?.cancel();
    _enterController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _initAnimations() {
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _slideAnimations = List.generate(_otpLength, (i) {
      return Tween<Offset>(
        begin: const Offset(0, 0.5),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _enterController,
          curve: Interval(i * 0.08, 0.7 + i * 0.04, curve: Curves.easeOutCubic),
        ),
      );
    });

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
          TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 8, end: -6), weight: 2),
          TweenSequenceItem(tween: Tween(begin: -6, end: 6), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 6, end: 0), weight: 1),
        ]).animate(
          CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
        );

    _enterController.forward();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown.value <= 0) {
        timer.cancel();
        return;
      }
      _resendCountdown.value = _resendCountdown.value - 1;
    });
  }

  String get _currentOtp => _otpControllers.map((c) => c.text).join();

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= _otpLength) {
      _fillOtpDigits(digits);
      _inlineError.value = null;
      _focusNodes[_otpLength - 1].requestFocus();
      await _verifyOTP();
    }
  }

  void _fillOtpDigits(String raw) {
    final digits = OtpInputUtils.takeOtpDigits(raw);
    if (digits.isEmpty) return;
    for (var i = 0; i < _otpLength; i++) {
      _otpControllers[i].text = i < digits.length ? digits[i] : '';
    }
  }

  Future<void> _verifyOTP() async {
    if (_isLoading || _isResending) return;

    final guard = Msg91Service.getRateLimitStatus(_activeReqId);
    if (guard.isLocked) {
      _showInlineError(
        'Too many failed attempts. Please wait a few minutes and try again.',
      );
      unawaited(
        _telemetry.trackAnonymous(
          eventName: 'otp_verify_locked',
          eventGroup: 'system',
          screen: 'otp_verification',
          metadata: {
            'max_attempts': guard.maxAttempts,
            'phone_suffix': _activePhoneNumber.length >= 4
                ? _activePhoneNumber.substring(_activePhoneNumber.length - 4)
                : _activePhoneNumber,
          },
        ),
      );
      return;
    }

    final verifyFlowWatch = Stopwatch()..start();
    final otp = _currentOtp;
    if (otp.length != _otpLength) {
      _showInlineError('Please enter the complete $_otpLength-digit OTP.');
      return;
    }

    setState(() {
      _isLoading = true;
    });
    _inlineError.value = null;

    try {
      final msg91Watch = Stopwatch()..start();
      final response = await Msg91Service.verifyOTP(
        reqId: _activeReqId,
        otp: otp,
      );
      msg91Watch.stop();
      debugPrint(
        '[OTPVerification][Perf] msg91VerifyMs=${msg91Watch.elapsedMilliseconds}',
      );

      final type = response['type']?.toString();
      if (type != 'success') {
        unawaited(
          _trackExpectedOtpFailure(
            eventName: 'otp_verify_failed',
            metadata: {
              'failure_type': type,
              'message': response['message']?.toString(),
            },
          ),
        );
        _shakeController.forward(from: 0);
        _showInlineError(_mapOtpError(response['message']?.toString()));
        setState(() => _isLoading = false);
        return;
      }

      final accessToken = _extractAccessToken(response);
      if (accessToken.trim().isEmpty) {
        unawaited(
          _trackExpectedOtpFailure(
            eventName: 'otp_verify_access_token_missing',
            metadata: {'response_keys': response.keys.toList()},
          ),
        );
        _showInlineError(
          'Verification failed: No access token received. Please try again.',
        );
        setState(() => _isLoading = false);
        return;
      }

      final exchangeWatch = Stopwatch()..start();
      final authRepo = await AuthRepository.init();
      final result = await authRepo.verifyAndSaveSession(
        phoneNumber: _activePhoneNumber,
        accessToken: accessToken.trim(),
      );
      exchangeWatch.stop();

      if (result.isSuccess) {
        final user = result.user ?? await authRepo.restoreSession();
        if (user != null && mounted) {
          try {
            await NotificationService.instance.onUserAuthenticated(
              user.id,
              user.role,
            );
          } catch (e) {
            debugPrint('[OTPVerification] notification setup failed: $e');
          }
          if (!mounted) return;
          final diagnostics = result.diagnostics ?? const <String, dynamic>{};
          unawaited(
            _telemetry.track(
              eventName: 'otp_verify_success',
              eventGroup: 'system',
              screen: 'otp_verification',
              user: user,
              metadata: {
                'msg91_verify_ms': msg91Watch.elapsedMilliseconds,
                'exchange_signin_ms': exchangeWatch.elapsedMilliseconds,
                'server_total_ms': diagnostics['total_ms'],
                'server_verify_token_ms': diagnostics['verify_token_ms'],
                'server_lookup_upsert_ms':
                    diagnostics['user_lookup_and_upsert_ms'],
              },
            ),
          );
          HapticFeedback.lightImpact();
          setState(() => _isLoading = false);
          Navigator.of(context).pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  MainNavigationShell(currentUser: user),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) =>
                      FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 400),
            ),
            (route) => false,
          );
          return;
        }
      }

      _shakeController.forward(from: 0);
      _showInlineError(
        result.errorMessage ?? 'Session setup failed. Please try again.',
      );
      AppErrorHandler.reportNonFatal(
        Exception(
          'otp_session_setup_failed message=${result.errorMessage ?? 'unknown'}',
        ),
      );
      setState(() => _isLoading = false);
    } catch (e) {
      final errorText = e.toString().toLowerCase();
      if (errorText.contains('temporarily locked')) {
        unawaited(
          _telemetry.trackAnonymous(
            eventName: 'otp_verify_locked',
            eventGroup: 'system',
            screen: 'otp_verification',
            metadata: {'source': 'verify_exception'},
          ),
        );
      }
      debugPrint('[OTPVerification] error: $e');
      AppErrorHandler.reportNonFatal(
        Exception('otp_verify_exception error=$e'),
      );
      if (mounted) {
        _shakeController.forward(from: 0);
        _showInlineError(_mapOtpError(e.toString()));
        setState(() => _isLoading = false);
        _clearOtpAndFocusFirst();
      }
    } finally {
      if (verifyFlowWatch.isRunning) {
        verifyFlowWatch.stop();
      }
    }
  }

  String _mapOtpError(String? message) {
    final msg = (message ?? '').toLowerCase();
    if (msg.contains('temporarily locked')) {
      return 'Too many failed attempts. Try again after a short wait.';
    }
    if (msg.contains('please wait')) {
      return message ?? 'Please wait before trying again.';
    }
    if (msg.contains('expired') || msg.contains('timeout')) {
      return 'OTP expired. Please resend and try again.';
    }
    if (msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('host lookup') ||
        msg.contains('timed out')) {
      return 'Network error. Please check your connection and try again.';
    }
    if (msg.contains('invalid') || msg.contains('incorrect')) {
      return 'Invalid OTP. Please try again.';
    }
    if (msg.trim().isNotEmpty) return message!;
    return 'Something went wrong. Please try again.';
  }

  void _showInlineError(String message) {
    _inlineError.value = message;
    HapticFeedback.mediumImpact();
  }

  Future<void> _trackExpectedOtpFailure({
    required String eventName,
    Map<String, dynamic>? metadata,
  }) {
    return _telemetry.trackAnonymous(
      eventName: eventName,
      eventGroup: 'system',
      screen: 'otp_verification',
      metadata: {
        'phone_suffix': _activePhoneNumber.length >= 4
            ? _activePhoneNumber.substring(_activePhoneNumber.length - 4)
            : _activePhoneNumber,
        ...?metadata,
      },
    );
  }

  void _clearOtpAndFocusFirst() {
    for (final c in _otpControllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
  }

  Future<void> _maybeAutoSubmit() async {
    if (OtpInputUtils.shouldAutoSubmit(
      otp: _currentOtp,
      isLoading: _isLoading,
      isResending: _isResending,
    )) {
      await _verifyOTP();
    }
  }

  String _extractAccessToken(Map<String, dynamic> response) {
    const tokenKeys = [
      'accessToken',
      'access_token',
      'access-token',
      'token',
      'authToken',
    ];
    for (final key in tokenKeys) {
      final value = response[key]?.toString().trim() ?? '';
      if (_looksLikeAccessToken(value)) return value;
    }
    final message = response['message']?.toString().trim() ?? '';
    if (_looksLikeAccessToken(message)) return message;
    return '';
  }

  bool _looksLikeAccessToken(String value) {
    if (value.isEmpty || value.contains(' ')) return false;
    if (value.toLowerCase().contains('otp')) return false;
    return value.length >= 20;
  }

  Future<void> _resendOTP() async {
    if (_isResending) return;
    if (_resendCountdown.value > 0) {
      _showInlineError(
        'Please wait ${_resendCountdown.value}s before resending OTP.',
      );
      unawaited(
        _telemetry.trackAnonymous(
          eventName: 'otp_retry_throttled',
          eventGroup: 'system',
          screen: 'otp_verification',
          metadata: {'seconds_remaining': _resendCountdown.value},
        ),
      );
      return;
    }

    setState(() {
      _isResending = true;
    });
    _inlineError.value = null;

    try {
      await Msg91Service.retryOTP(reqId: _activeReqId, retryChannel: 11);
      if (mounted) {
        _resendCountdown.value = 30;
        _startResendCountdown();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('OTP resent successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[OTPVerification] resendOTP error: $e');
      if (mounted) {
        if (e.toString().toLowerCase().contains('please wait')) {
          unawaited(
            _telemetry.trackAnonymous(
              eventName: 'otp_retry_throttled',
              eventGroup: 'system',
              screen: 'otp_verification',
              metadata: {'source': 'msg91_guard'},
            ),
          );
        }
        _showInlineError(_mapOtpError(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  bool _isValidPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length == 10;
  }

  Future<void> _updateNumberAndResend() async {
    final phone = _phoneEditController.text.trim().replaceAll(
      RegExp(r'\D'),
      '',
    );
    if (!_isValidPhone(phone)) {
      _showInlineError('Please enter a valid 10-digit mobile number.');
      return;
    }
    if (_isResending || _isLoading) return;

    setState(() {
      _isResending = true;
    });
    _inlineError.value = null;

    try {
      final response = await Msg91Service.sendOTP(phone);
      final reqId = response['request_id']?.toString() ?? '';
      if (reqId.isEmpty) {
        _showInlineError('Could not send OTP. Please try again.');
      } else {
        setState(() {
          _activePhoneNumber = phone;
          _activeReqId = reqId;
        });
        _resendCountdown.value = 30;
        _startResendCountdown();
        _clearOtpAndFocusFirst();
      }
    } catch (e) {
      _showInlineError(_mapOtpError(e.toString()));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop({'phone': _activePhoneNumber}),
            child: const Text('Wrong number?'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.screenPaddingHorizontal,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Enter OTP',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                  children: [
                    const TextSpan(text: 'Sent to '),
                    TextSpan(
                      text: '+91 $_activePhoneNumber',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              TextField(
                controller: _phoneEditController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                enabled: !_isLoading && !_isResending,
                decoration: InputDecoration(
                  counterText: '',
                  labelText: 'Phone number',
                  hintText: 'Edit number if needed',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: TextButton(
                    onPressed: (_isLoading || _isResending)
                        ? null
                        : _updateNumberAndResend,
                    child: const Text('Update & Resend'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<String?>(
                valueListenable: _inlineError,
                builder: (context, inlineError, _) {
                  return AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(_shakeAnimation.value, 0),
                      child: child,
                    ),
                    child: AutofillGroup(
                      child: LayoutBuilder(
                        builder: (context, boxConstraints) {
                          const gap = 8.0;
                          final boxWidth =
                              ((boxConstraints.maxWidth -
                                          ((_otpLength - 1) * gap)) /
                                      _otpLength)
                                  .clamp(44.0, 52.0);
                          final boxHeight = (boxWidth * 1.18).clamp(52.0, 62.0);
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(_otpLength, (index) {
                              return SlideTransition(
                                position: _slideAnimations[index],
                                child: _OtpBox(
                                  controller: _otpControllers[index],
                                  focusNode: _focusNodes[index],
                                  isDark: isDark,
                                  width: boxWidth,
                                  height: boxHeight,
                                  semanticsLabel: 'OTP digit ${index + 1}',
                                  hasError: inlineError != null,
                                  textInputAction: index == _otpLength - 1
                                      ? TextInputAction.done
                                      : TextInputAction.next,
                                  onSubmitted: (_) {
                                    if (index == _otpLength - 1) {
                                      _verifyOTP();
                                    } else {
                                      _focusNodes[index + 1].requestFocus();
                                    }
                                  },
                                  onKeyEvent: (node, event) {
                                    if (event is KeyDownEvent &&
                                        event.logicalKey ==
                                            LogicalKeyboardKey.backspace) {
                                      final prevIndex =
                                          OtpInputUtils.previousIndexOnBackspace(
                                            index: index,
                                            isCurrentEmpty:
                                                _otpControllers[index]
                                                    .text
                                                    .isEmpty,
                                          );
                                      if (prevIndex != null) {
                                        _focusNodes[prevIndex].requestFocus();
                                        _otpControllers[prevIndex].clear();
                                        return KeyEventResult.handled;
                                      }
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  onChanged: (value) {
                                    _inlineError.value = null;
                                    if (value.length > 1) {
                                      _fillOtpDigits(value);
                                      _focusNodes[_otpLength - 1]
                                          .requestFocus();
                                      _maybeAutoSubmit();
                                      return;
                                    }
                                    if (value.length == 1 &&
                                        index < _otpLength - 1) {
                                      _focusNodes[index + 1].requestFocus();
                                    } else if (value.isEmpty && index > 0) {
                                      _focusNodes[index - 1].requestFocus();
                                    }
                                    _maybeAutoSubmit();
                                  },
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
              ValueListenableBuilder<String?>(
                valueListenable: _inlineError,
                builder: (context, inlineError, _) {
                  return AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: inlineError != null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  size: 16,
                                  color: AppColors.error,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    inlineError,
                                    style: TextStyle(
                                      color: AppColors.error,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  );
                },
              ),
              const SizedBox(height: 28),
              Center(
                child: TextButton.icon(
                  onPressed: (_isLoading || _isResending)
                      ? null
                      : _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste_rounded, size: 16),
                  label: const Text('Paste OTP'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondaryOf(context),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 54,
                child: Semantics(
                  button: true,
                  label: 'Verify OTP',
                  child: ElevatedButton(
                    onPressed: (_isLoading || _isResending) ? null : _verifyOTP,
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
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              key: ValueKey('verify'),
                              'Verify OTP',
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
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive code? ",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: _resendCountdown,
                    builder: (context, resendCountdown, _) {
                      if (resendCountdown > 0) {
                        return Text(
                          'Resend in ${resendCountdown}s',
                          style: TextStyle(
                            color: AppColors.textSecondaryOf(
                              context,
                            ).withValues(alpha: 0.6),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }
                      return TextButton(
                        onPressed: _isResending ? null : _resendOTP,
                        child: Text(
                          _isResending ? 'Resending...' : 'Resend OTP',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtpBox extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final double width;
  final double height;
  final String semanticsLabel;
  final bool hasError;
  final TextInputAction textInputAction;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.width,
    required this.height,
    required this.semanticsLabel,
    required this.hasError,
    required this.textInputAction,
    required this.onChanged,
    this.onSubmitted,
    this.onKeyEvent,
  });

  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> {
  bool _hasFocus = false;
  late final VoidCallback _focusListener;

  @override
  void initState() {
    super.initState();
    _focusListener = () {
      if (!mounted) return;
      setState(() => _hasFocus = widget.focusNode.hasFocus);
    };
    widget.focusNode.addListener(_focusListener);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_focusListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filled = widget.controller.text.isNotEmpty;
    final baseColor = widget.isDark ? AppColors.surfaceDark : Colors.white;
    final borderColor = widget.hasError
        ? AppColors.error
        : _hasFocus
        ? AppColors.primary
        : filled
        ? AppColors.primary.withValues(alpha: 0.65)
        : AppColors.dividerOf(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.hasError
            ? AppColors.error.withValues(alpha: 0.08)
            : _hasFocus
            ? AppColors.primary.withValues(alpha: 0.08)
            : baseColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: _hasFocus ? 2.0 : 1.2),
        boxShadow: [
          if (_hasFocus || filled)
            BoxShadow(
              color: AppColors.primary.withValues(
                alpha: _hasFocus ? 0.22 : 0.1,
              ),
              blurRadius: _hasFocus ? 14 : 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Semantics(
        textField: true,
        label: widget.semanticsLabel,
        child: Focus(
          onKeyEvent: widget.onKeyEvent,
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            maxLength: 1,
            textInputAction: widget.textInputAction,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: widget.hasError ? AppColors.error : AppColors.primary,
            ),
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isCollapsed: true,
            ),
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
          ),
        ),
      ),
    );
  }
}
