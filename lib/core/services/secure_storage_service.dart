import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure Storage Service — Stores auth tokens and sensitive credentials
/// using platform-specific secure storage (Keychain on iOS, EncryptedSharedPreferences on Android).
class SecureStorageService {
  SecureStorageService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Key constants
  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyTokenExpiry = 'token_expiry';
  static const _keyUserId = 'secure_user_id';

  // ==================== Token Management ====================

  /// Store authentication tokens securely
  static Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiry,
  }) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _keyRefreshToken, value: refreshToken);
    }
    if (expiry != null) {
      await _storage.write(
        key: _keyTokenExpiry,
        value: expiry.toIso8601String(),
      );
    }
  }

  /// Get stored access token
  static Future<String?> getAccessToken() async {
    return _storage.read(key: _keyAccessToken);
  }

  /// Get stored refresh token
  static Future<String?> getRefreshToken() async {
    return _storage.read(key: _keyRefreshToken);
  }

  /// Check if token is expired
  static Future<bool> isTokenExpired() async {
    final expiryStr = await _storage.read(key: _keyTokenExpiry);
    if (expiryStr == null) return true;
    final expiry = DateTime.tryParse(expiryStr);
    if (expiry == null) return true;
    return DateTime.now().isAfter(expiry);
  }

  /// Check if we have a valid (non-expired) token
  static Future<bool> hasValidToken() async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) return false;
    return !(await isTokenExpired());
  }

  // ==================== User ID ====================

  /// Store user ID securely
  static Future<void> saveUserId(String userId) async {
    await _storage.write(key: _keyUserId, value: userId);
  }

  /// Get stored user ID
  static Future<String?> getUserId() async {
    return _storage.read(key: _keyUserId);
  }

  // ==================== Cleanup ====================

  /// Clear all secure storage on logout
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Clear only tokens (keep user ID for re-auth)
  static Future<void> clearTokens() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyTokenExpiry);
  }
}
