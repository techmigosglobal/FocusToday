import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:shared_preferences/shared_preferences.dart';

/// Authorization Service
/// Provides helper methods to validate user authorization for operations
/// Works with Firebase Auth and ensures app-level authorization
class AuthorizationService {
  static const String _keyUserId = 'user_id';

  final SharedPreferences _prefs;
  firebase_auth.FirebaseAuth get _auth => firebase_auth.FirebaseAuth.instance;

  AuthorizationService._(this._prefs);

  /// Initialize service
  static Future<AuthorizationService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return AuthorizationService._(prefs);
  }

  /// Get current user ID from Firebase or SharedPreferences
  String? getCurrentUserId() {
    // Try Firebase first; if unavailable or null, fall back to SharedPreferences
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) return uid;
    } catch (_) {
      // Firebase not initialized in test or platform context; ignore
    }
    return _prefs.getString(_keyUserId);
  }

  /// Check if user is authenticated
  bool isAuthenticated() {
    return getCurrentUserId() != null;
  }

  /// Validate that the operation is for the current user
  /// Throws exception if validation fails
  void validateCurrentUser(String userId, {String operation = 'operation'}) {
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }
    if (currentUserId != userId) {
      throw Exception(
        'Unauthorized: Cannot perform $operation for another user',
      );
    }
  }

  /// Validate user is authenticated
  /// Throws exception if not authenticated
  void requireAuthentication({String operation = 'operation'}) {
    if (!isAuthenticated()) {
      throw Exception('Authentication required for $operation');
    }
  }

  /// Get current Firebase user
  firebase_auth.User? getFirebaseUser() {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }
}
