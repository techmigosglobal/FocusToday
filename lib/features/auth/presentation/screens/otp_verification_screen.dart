import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../data/repositories/auth_repository.dart';
import '../../../feed/presentation/screens/feed_screen.dart';

/// OTP Verification Screen
/// User enters the OTP sent to their phone number
class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;

  const OTPVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _isResending = false;
  int _resendCountdown = 30;
  late String _currentVerificationId; // Store current verification ID

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.verificationId; // Initialize with provided ID
    _startResendCountdown();
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  /// Start resend countdown timer
  void _startResendCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendCountdown > 0) {
        setState(() => _resendCountdown--);
        _startResendCountdown();
      }
    });
  }

  /// Verify OTP
  Future<void> _verifyOTP() async {
    // Get entered OTP
    final otp = _otpControllers.map((c) => c.text).join();

    if (otp.length != 6) {
      _showError('Please enter complete OTP');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authRepo = await AuthRepository.init();
      final userCredential = await authRepo.verifyOTP(
        verificationId: _currentVerificationId, // Use current verification ID
        smsCode: otp,
      );

      if (userCredential.user != null) {
        // Auto-assign role based on phone number
        final role = AuthRepository.assignRoleByPhoneNumber(widget.phoneNumber);

        // Save session with auto-assigned role and Firebase UID
        await authRepo.saveSession(
          phoneNumber: widget.phoneNumber,
          displayName:
              'User ${widget.phoneNumber.length > 4 ? widget.phoneNumber.substring(widget.phoneNumber.length - 4) : ""}',
          role: role,
          firebaseUserId: userCredential.user!.uid,
        );

        // Get current user
        final user = await authRepo.restoreSession();

        if (user != null && mounted) {
          setState(() => _isLoading = false);
          // Navigate directly to feed
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => FeedScreen(currentUser: user)),
            (route) => false,
          );
        } else if (mounted) {
          setState(() => _isLoading = false);
          _showError('Failed to create session');
        }
      } else {
        setState(() => _isLoading = false);
        _showError('Verification failed');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Invalid OTP. Please try again.');
        // Clear OTP fields
        for (var controller in _otpControllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
      }
    }
  }

  /// Resend OTP
  Future<void> _resendOTP() async {
    setState(() => _isResending = true);

    try {
      final authRepo = await AuthRepository.init();
      await authRepo.signInWithPhoneNumber(
        phoneNumber: widget.phoneNumber,
        onCodeSent: (newVerificationId) {
          if (mounted) {
            setState(() {
              _currentVerificationId = newVerificationId; // Update verification ID
              _isResending = false;
              _resendCountdown = 30;
            });
            _startResendCountdown();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('OTP sent successfully')),
            );
          }
        },
        onVerificationFailed: (e) {
          if (mounted) {
            setState(() => _isResending = false);
            _showError(e.message ?? 'Failed to resend OTP');
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isResending = false);
        _showError('Failed to resend OTP. Please try again.');
      }
    }
  }

  /// Show error message
  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify OTP'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.screenPaddingHorizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              // Icon
              Icon(
                Icons.mark_email_read_outlined,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Enter OTP',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                'We sent a code to +91 ${widget.phoneNumber}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary.withValues(alpha: 0.7),
                ),
              ),

              const SizedBox(height: 40),

              // OTP Input Fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 45,
                    child: TextField(
                      controller: _otpControllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                      ),
                      onChanged: (value) {
                        if (value.length == 1 && index < 5) {
                          _focusNodes[index + 1].requestFocus();
                        } else if (value.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }

                        // Auto-verify when all digits entered
                        if (index == 5 && value.isNotEmpty) {
                          _verifyOTP();
                        }
                      },
                    ),
                  );
                }),
              ),

              const SizedBox(height: 32),

              // Verify Button
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyOTP,
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text('Verify OTP'),
              ),

              const SizedBox(height: 24),

              // Resend OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive code? ",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (_resendCountdown > 0)
                    Text(
                      'Resend in ${_resendCountdown}s',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary.withValues(alpha: 0.5),
                      ),
                    )
                  else
                    TextButton(
                      onPressed: _isResending ? null : _resendOTP,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: _isResending
                          ? SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                              ),
                            )
                          : const Text('Resend OTP'),
                    ),
                ],
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
