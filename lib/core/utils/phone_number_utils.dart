class PhoneNumberUtils {
  PhoneNumberUtils._();

  static String normalizeIndianPhone(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('91') && digits.length > 10) {
      digits = digits.substring(2);
    }
    if (digits.length > 10) {
      digits = digits.substring(digits.length - 10);
    }
    return digits;
  }

  static String toE164Indian(String input) {
    final normalized = normalizeIndianPhone(input);
    if (normalized.isEmpty) return '';
    return '+91$normalized';
  }

  static bool isValidIndianPhone(String input) {
    final normalized = normalizeIndianPhone(input);
    return RegExp(r'^\d{10}$').hasMatch(normalized);
  }
}
