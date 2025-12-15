// Authentication Constants
// Defines role-based phone numbers for admin and reporter roles

class AuthConstants {
  AuthConstants._(); // Private constructor to prevent instantiation

  /// Admin phone numbers (without country code, 10 digits)
  /// These users will automatically get Admin role
  static const List<String> adminPhoneNumbers = [
    '9876543210', // Admin 1
    '9876543211', // Admin 2
    '9876543212', // Admin 3
  ];

  /// Reporter phone numbers (without country code, 10 digits)
  /// These users will automatically get Reporter role
  static const List<String> reporterPhoneNumbers = [
    '9123456780', // Reporter 1
    '9123456781', // Reporter 2
    '9123456782', // Reporter 3
  ];

  /// Check if phone number is an admin number
  static bool isAdminNumber(String phoneNumber) {
    final cleanNumber = _cleanPhoneNumber(phoneNumber);
    return adminPhoneNumbers.contains(cleanNumber);
  }

  /// Check if phone number is a reporter number
  static bool isReporterNumber(String phoneNumber) {
    final cleanNumber = _cleanPhoneNumber(phoneNumber);
    return reporterPhoneNumbers.contains(cleanNumber);
  }

  /// Get role based on phone number
  /// Returns: 'admin', 'reporter', or 'publicUser'
  static String getRoleForPhoneNumber(String phoneNumber) {
    if (isAdminNumber(phoneNumber)) {
      return 'admin';
    } else if (isReporterNumber(phoneNumber)) {
      return 'reporter';
    } else {
      return 'publicUser';
    }
  }

  /// Clean phone number by removing spaces, dashes, and country code
  static String _cleanPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    String cleaned = phoneNumber.replaceAll(RegExp(r'\D'), '');

    // If starts with country code (91), remove it
    if (cleaned.startsWith('91') && cleaned.length > 10) {
      cleaned = cleaned.substring(2);
    }

    // Get last 10 digits
    if (cleaned.length > 10) {
      cleaned = cleaned.substring(cleaned.length - 10);
    }

    return cleaned;
  }

  /// Validate phone number format
  static bool isValidPhoneNumber(String phoneNumber) {
    final cleaned = _cleanPhoneNumber(phoneNumber);
    return cleaned.length == 10 && RegExp(r'^\d{10}$').hasMatch(cleaned);
  }
}
