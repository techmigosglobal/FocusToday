class OtpInputUtils {
  OtpInputUtils._();
  static const int otpLength = 4;

  static String sanitizeDigits(String raw) {
    return raw.replaceAll(RegExp(r'\D'), '');
  }

  static String takeOtpDigits(String raw) {
    final digits = sanitizeDigits(raw);
    if (digits.isEmpty) return '';
    return digits.length > otpLength ? digits.substring(0, otpLength) : digits;
  }

  static int? previousIndexOnBackspace({
    required int index,
    required bool isCurrentEmpty,
  }) {
    if (!isCurrentEmpty || index <= 0) return null;
    return index - 1;
  }

  static bool shouldAutoSubmit({
    required String otp,
    required bool isLoading,
    required bool isResending,
  }) {
    return !isLoading && !isResending && otp.length == otpLength;
  }
}
