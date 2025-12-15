import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../shared/models/user.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/subscription_service.dart';
import '../../domain/constants/auth_constants.dart';

/// Authentication Repository
/// Manages user sessions and authentication state
class AuthRepository {
  static const String _keySessionToken = 'session_token';
  static const String _keyUserId = 'user_id';
  static const String _keyPhoneNumber = 'phone_number';
  static const String _keyDisplayName = 'display_name';
  static const String _keyRole = 'user_role';
  static const String _keyIsSubscribed = 'is_subscribed';
  static const String _keyPreferredLanguage = 'preferred_language';

  final SharedPreferences _prefs;
  final DatabaseService _db = DatabaseService.instance;

  AuthRepository(this._prefs);

  /// Initialize AuthRepository
  static Future<AuthRepository> init() async {
    final prefs = await SharedPreferences.getInstance();
    return AuthRepository(prefs);
  }

  /// Check if user is logged in
  bool isLoggedIn() {
    return _prefs.containsKey(_keySessionToken) &&
        _prefs.containsKey(_keyUserId);
  }

  /// Save user session
  Future<void> saveSession({
    required String phoneNumber,
    required String displayName,
    required UserRole role,
    bool isSubscribed = false,
    String preferredLanguage = 'en',
  }) async {
    // Generate session token and user ID
    const uuid = Uuid();
    final sessionToken = uuid.v4();
    final userId = uuid.v4();

    // Save to SharedPreferences
    await _prefs.setString(_keySessionToken, sessionToken);
    await _prefs.setString(_keyUserId, userId);
    await _prefs.setString(_keyPhoneNumber, phoneNumber);
    await _prefs.setString(_keyDisplayName, displayName);
    await _prefs.setString(_keyRole, role.toStr());
    await _prefs.setBool(_keyIsSubscribed, isSubscribed);
    await _prefs.setString(_keyPreferredLanguage, preferredLanguage);

    // Save user to database
    final user = User(
      id: userId,
      phoneNumber: phoneNumber,
      displayName: displayName,
      role: role,
      isSubscribed: isSubscribed,
      createdAt: DateTime.now(),
      preferredLanguage: preferredLanguage,
    );

    final db = await _db.database;
    await db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Session saved for user: $displayName ($phoneNumber)
  }

  /// Restore session and get current user
  Future<User?> restoreSession() async {
    if (!isLoggedIn()) return null;

    try {
      final userId = _prefs.getString(_keyUserId);
      if (userId == null) return null;

      // Try to get from database first
      final db = await _db.database;
      final results = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (results.isNotEmpty) {
        return User.fromMap(results.first);
      }

      // If not in database, recreate from SharedPreferences
      final phoneNumber = _prefs.getString(_keyPhoneNumber);
      final displayName = _prefs.getString(_keyDisplayName);
      final roleStr = _prefs.getString(_keyRole);
      final isSubscribed = _prefs.getBool(_keyIsSubscribed) ?? false;
      final preferredLanguage = _prefs.getString(_keyPreferredLanguage) ?? 'en';

      if (phoneNumber == null || displayName == null || roleStr == null) {
        return null;
      }

      final user = User(
        id: userId,
        phoneNumber: phoneNumber,
        displayName: displayName,
        role: UserRoleExtension.fromString(roleStr),
        isSubscribed: isSubscribed,
        createdAt: DateTime.now(),
        preferredLanguage: preferredLanguage,
      );

      // Save back to database
      await db.insert(
        'users',
        user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return user;
    } catch (_) {
      return null;
    }
  }

  /// Get session token
  String? getSessionToken() {
    return _prefs.getString(_keySessionToken);
  }

  /// Get current user ID
  String? getCurrentUserId() {
    return _prefs.getString(_keyUserId);
  }

  /// Logout - clear session and subscription
  Future<void> logout() async {
    // Clear subscription first
    try {
      final subscriptionService = await SubscriptionService.init();
      await subscriptionService.clearSubscription();
    } catch (_) {
      // Error clearing subscription - ignore
    }

    // Clear session
    await _prefs.remove(_keySessionToken);
    await _prefs.remove(_keyUserId);
    await _prefs.remove(_keyPhoneNumber);
    await _prefs.remove(_keyDisplayName);
    await _prefs.remove(_keyRole);
    await _prefs.remove(_keyIsSubscribed);
    await _prefs.remove(_keyPreferredLanguage);

    // User logged out successfully
  }

  /// Update user profile
  Future<void> updateProfile({
    String? displayName,
    String? bio,
    String? profilePicture,
    String? preferredLanguage,
  }) async {
    final userId = getCurrentUserId();
    if (userId == null) return;

    final db = await _db.database;

    // Build update map
    final Map<String, dynamic> updates = {};
    if (displayName != null) {
      updates['display_name'] = displayName;
      await _prefs.setString(_keyDisplayName, displayName);
    }
    if (bio != null) updates['bio'] = bio;
    if (profilePicture != null) updates['profile_picture'] = profilePicture;
    if (preferredLanguage != null) {
      updates['preferred_language'] = preferredLanguage;
      await _prefs.setString(_keyPreferredLanguage, preferredLanguage);
    }

    if (updates.isNotEmpty) {
      await db.update('users', updates, where: 'id = ?', whereArgs: [userId]);
    }
  }

  /// Assign role based on phone number
  /// Returns the appropriate role for the given phone number
  static UserRole assignRoleByPhoneNumber(String phoneNumber) {
    final roleStr = AuthConstants.getRoleForPhoneNumber(phoneNumber);
    return UserRoleExtension.fromString(roleStr);
  }
}
