import 'package:flutter/foundation.dart';
import 'package:sendotp_flutter_sdk/sendotp_flutter_sdk.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OtpRateLimitStatus {
  final bool isLocked;
  final int attemptsUsed;
  final int maxAttempts;
  final int remainingAttempts;
  final DateTime? lockedUntil;
  final Duration? retryAfter;

  const OtpRateLimitStatus({
    required this.isLocked,
    required this.attemptsUsed,
    required this.maxAttempts,
    required this.remainingAttempts,
    this.lockedUntil,
    this.retryAfter,
  });
}

/// Msg91 OTP Service — Wraps the SendOTP Flutter SDK for phone OTP verification.
///
/// Usage:
///   await Msg91Service.initialize();
///   final reqId = await Msg91Service.sendOTP(phoneNumber);
///   final token = await Msg91Service.verifyOTP(reqId: reqId, otp: otp);
class Msg91Service {
  Msg91Service._();

  static String get _widgetId => (dotenv.env['MSG91_WIDGET_ID'] ?? '').trim();
  static String get _tokenAuth {
    final tokenAuth = (dotenv.env['MSG91_TOKEN_AUTH'] ?? '').trim();
    if (tokenAuth.isNotEmpty) return tokenAuth;
    return (dotenv.env['MSG91_AUTH_KEY'] ?? '').trim();
  }

  static bool _initialized = false;
  static const int otpLength = 4;
  static const int maxVerifyAttempts = 5;
  static const Duration retryCooldown = Duration(seconds: 30);
  static const Duration temporaryLockDuration = Duration(minutes: 10);

  static final Map<String, int> _verifyAttemptsByReqId = <String, int>{};
  static final Map<String, DateTime> _lockedUntilByReqId = <String, DateTime>{};
  static final Map<String, DateTime> _lastRetryAtByReqId = <String, DateTime>{};

  /// Initialize the OTP widget — call once on app start or before first use.
  /// NOTE: Does NOT make any network calls. Safe to call from main().
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      if (_widgetId.isEmpty) {
        throw StateError('MSG91_WIDGET_ID is missing in .env');
      }
      if (_tokenAuth.isEmpty) {
        throw StateError(
          'Msg91 widget token is missing. Set MSG91_TOKEN_AUTH in .env',
        );
      }
      OTPWidget.initializeWidget(_widgetId, _tokenAuth);
      _initialized = true;
      debugPrint('[Msg91Service] Initialized (widgetId=${_mask(_widgetId)})');
    } catch (e) {
      debugPrint('[Msg91Service] Initialization error: $e');
      rethrow;
    }
  }

  /// Send OTP to a phone number.
  /// [phoneNumber] must be exactly 10 digits (no country code, no +).
  /// The SDK prepends '91' (India) automatically via the identifier field.
  /// Returns the response map from Msg91 — includes 'request_id' on success.
  static Future<Map<String, dynamic>> sendOTP(String phoneNumber) async {
    if (!_initialized) await initialize();

    // Strip any accidental non-digit characters the caller might have passed
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) {
      throw ArgumentError(
        'sendOTP expects a 10-digit phone number, got: "$phoneNumber"',
      );
    }

    // Msg91 widget requires country code without '+', e.g. "919876543210"
    final identifier = '91$digits';
    debugPrint('[Msg91Service] Sending OTP to identifier=$identifier');

    try {
      final response = await OTPWidget.sendOTP({'identifier': identifier});
      debugPrint('[Msg91Service] sendOTP raw response: $response');

      if (response == null) {
        throw StateError(
          'Msg91 widget is not initialized. Check widgetId and tokenAuth.',
        );
      }

      final type = response['type']?.toString().toLowerCase() ?? '';
      final code = response['code']?.toString() ?? '';
      final message = response['message']?.toString() ?? '';

      if (type == 'error' || code == '401') {
        throw StateError(
          'Msg91 credential error (code $code): $message. '
          'Verify MSG91_WIDGET_ID and MSG91_TOKEN_AUTH in .env.',
        );
      }

      // Normalize response: ensure request_id is present
      final normalized = Map<String, dynamic>.from(response);

      // If request_id is missing, try to get it from the message field or other fields
      if ((normalized['request_id'] ?? '').toString().isEmpty) {
        // Try common field names Msg91 might use
        final possibleIds = [
          normalized['requestId'],
          normalized['reqId'],
          normalized['message'],
          normalized['id'],
        ];

        for (var id in possibleIds) {
          if (id != null && id.toString().isNotEmpty) {
            normalized['request_id'] = id.toString();
            debugPrint(
              '[Msg91Service] Using $id as request_id (from alternative field)',
            );
            break;
          }
        }
      }

      final requestId = (normalized['request_id'] ?? '').toString().trim();
      if (requestId.isNotEmpty) {
        _resetRateLimitState(requestId);
        _lastRetryAtByReqId[requestId] = DateTime.now();
      }

      return normalized;
    } on StateError {
      rethrow;
    } on ArgumentError {
      rethrow;
    } catch (e) {
      debugPrint('[Msg91Service] sendOTP exception: $e');
      // Wrap with a user-friendly prefix but preserve the original message
      throw Exception('Msg91 sendOTP failed: $e');
    }
  }

  /// Retry OTP via a specific channel.
  static Future<Map<String, dynamic>> retryOTP({
    required String reqId,
    int? retryChannel,
  }) async {
    if (!_initialized) await initialize();
    try {
      final now = DateTime.now();
      final lockedUntil = _lockedUntilByReqId[reqId];
      if (lockedUntil != null && lockedUntil.isAfter(now)) {
        final waitSec = lockedUntil.difference(now).inSeconds;
        throw StateError(
          'OTP verification is temporarily locked. Try again in ${waitSec}s.',
        );
      }
      final lastRetryAt = _lastRetryAtByReqId[reqId];
      if (lastRetryAt != null) {
        final elapsed = now.difference(lastRetryAt);
        if (elapsed < retryCooldown) {
          final waitSec = (retryCooldown - elapsed).inSeconds.clamp(1, 9999);
          throw StateError('Please wait ${waitSec}s before resending OTP.');
        }
      }
      debugPrint('[Msg91Service] Retrying OTP: reqId=$reqId');
      final data = <String, dynamic>{'reqId': reqId};
      if (retryChannel != null) data['retryChannel'] = retryChannel;
      final response = await OTPWidget.retryOTP(data);
      debugPrint('[Msg91Service] retryOTP response: $response');
      _lastRetryAtByReqId[reqId] = now;
      if (response is Map<String, dynamic>) return response;
      return {'response': response};
    } catch (e) {
      debugPrint('[Msg91Service] retryOTP error: $e');
      rethrow;
    }
  }

  /// Verify OTP entered by the user.
  /// Returns the response map — on success it contains an access token.
  static Future<Map<String, dynamic>> verifyOTP({
    required String reqId,
    required String otp,
  }) async {
    if (!_initialized) await initialize();
    final now = DateTime.now();
    final lockedUntil = _lockedUntilByReqId[reqId];
    if (lockedUntil != null && lockedUntil.isAfter(now)) {
      final waitSec = lockedUntil.difference(now).inSeconds;
      throw StateError(
        'OTP verification is temporarily locked. Try again in ${waitSec}s.',
      );
    }

    final digits = otp.replaceAll(RegExp(r'\D'), '');
    if (digits.length != otpLength) {
      throw ArgumentError('OTP must be exactly $otpLength digits.');
    }

    try {
      debugPrint('[Msg91Service] Verifying OTP: reqId=$reqId');
      final response = await OTPWidget.verifyOTP({
        'reqId': reqId,
        'otp': digits,
      });
      if (response is Map<String, dynamic>) {
        final type = response['type']?.toString() ?? 'unknown';
        final token = response['message']?.toString() ?? '';
        final tokenInfo = _looksLikeAccessToken(token)
            ? _mask(token)
            : '<not-token>';
        debugPrint(
          '[Msg91Service] verifyOTP response: {type: $type, token: $tokenInfo}',
        );
        if (type.toLowerCase() == 'success') {
          _resetRateLimitState(reqId);
        } else {
          _recordFailedVerifyAttempt(reqId);
        }
        return response;
      }
      _recordFailedVerifyAttempt(reqId);
      return {'response': response};
    } catch (e) {
      final errorText = e.toString().toLowerCase();
      final likelyOtpAttemptFailure =
          errorText.contains('invalid') ||
          errorText.contains('incorrect') ||
          errorText.contains('otp') ||
          errorText.contains('code');
      if (likelyOtpAttemptFailure) {
        _recordFailedVerifyAttempt(reqId);
      }
      debugPrint('[Msg91Service] verifyOTP error: $e');
      rethrow;
    }
  }

  static OtpRateLimitStatus getRateLimitStatus(String reqId) {
    final now = DateTime.now();
    final lockedUntil = _lockedUntilByReqId[reqId];
    final isLocked = lockedUntil != null && lockedUntil.isAfter(now);
    final lastRetryAt = _lastRetryAtByReqId[reqId];
    final retryAfter = lastRetryAt == null
        ? null
        : retryCooldown - now.difference(lastRetryAt);
    final attempts = _verifyAttemptsByReqId[reqId] ?? 0;
    return OtpRateLimitStatus(
      isLocked: isLocked,
      attemptsUsed: attempts,
      maxAttempts: maxVerifyAttempts,
      remainingAttempts: (maxVerifyAttempts - attempts).clamp(
        0,
        maxVerifyAttempts,
      ),
      lockedUntil: isLocked ? lockedUntil : null,
      retryAfter: retryAfter != null && retryAfter.isNegative
          ? null
          : retryAfter,
    );
  }

  static void _recordFailedVerifyAttempt(String reqId) {
    final now = DateTime.now();
    final lockedUntil = _lockedUntilByReqId[reqId];
    if (lockedUntil != null && lockedUntil.isAfter(now)) return;
    final next = (_verifyAttemptsByReqId[reqId] ?? 0) + 1;
    _verifyAttemptsByReqId[reqId] = next;
    if (next >= maxVerifyAttempts) {
      _lockedUntilByReqId[reqId] = now.add(temporaryLockDuration);
      _verifyAttemptsByReqId[reqId] = 0;
    }
  }

  static void _resetRateLimitState(String reqId) {
    _verifyAttemptsByReqId.remove(reqId);
    _lockedUntilByReqId.remove(reqId);
    _lastRetryAtByReqId.remove(reqId);
  }

  // ==================== Utility Methods ====================

  static String _mask(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '<empty>';
    if (trimmed.length <= 8) return '${trimmed.substring(0, 2)}****';
    return '${trimmed.substring(0, 4)}****${trimmed.substring(trimmed.length - 4)}';
  }

  static bool _looksLikeAccessToken(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.contains(' ')) return false;
    if (trimmed.toLowerCase().contains('otp')) return false;
    return trimmed.length >= 20;
  }
}
