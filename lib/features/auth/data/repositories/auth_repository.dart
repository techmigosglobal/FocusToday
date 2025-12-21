import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../shared/models/user.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/subscription_service.dart';
import '../../domain/constants/auth_constants.dart';

/// Authentication Repository
/// Manages user sessions and authentication state using Firebase and Supabase
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
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;

  AuthRepository(this._prefs);

  /// Initialize AuthRepository
  static Future<AuthRepository> init() async {
    final prefs = await SharedPreferences.getInstance();
    return AuthRepository(prefs);
  }

  /// Check if user is logged in
  bool isLoggedIn() {
    return _auth.currentUser != null ||
        (_prefs.containsKey(_keySessionToken) &&
            _prefs.containsKey(_keyUserId));
  }

  /// Send OTP to phone number
  Future<void> signInWithPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(firebase_auth.FirebaseAuthException e)
    onVerificationFailed,
  }) async {
    // Add +91 prefix if not present
    String formattedPhone = phoneNumber;
    if (!phoneNumber.startsWith('+')) {
      formattedPhone = '+91$phoneNumber';
    }

    await _auth.verifyPhoneNumber(
      phoneNumber: formattedPhone,
      verificationCompleted:
          (firebase_auth.PhoneAuthCredential credential) async {
            await _auth.signInWithCredential(credential);
          },
      verificationFailed: onVerificationFailed,
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  /// Verify OTP and sign in
  Future<firebase_auth.UserCredential> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    firebase_auth.PhoneAuthCredential credential =
        firebase_auth.PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: smsCode,
        );

    return await _auth.signInWithCredential(credential);
  }

  /// Save user session and local profile
  Future<void> saveSession({
    required String phoneNumber,
    required String displayName,
    required UserRole role,
    bool isSubscribed = false,
    String preferredLanguage = 'en',
    String? firebaseUserId,
  }) async {
    const uuid = Uuid();
    final sessionToken = uuid.v4();
    final userId = firebaseUserId ?? uuid.v4();

    // 1. Save to SharedPreferences
    await _prefs.setString(_keySessionToken, sessionToken);
    await _prefs.setString(_keyUserId, userId);
    await _prefs.setString(_keyPhoneNumber, phoneNumber);
    await _prefs.setString(_keyDisplayName, displayName);
    await _prefs.setString(_keyRole, role.toStr());
    await _prefs.setBool(_keyIsSubscribed, isSubscribed);
    await _prefs.setString(_keyPreferredLanguage, preferredLanguage);

    final user = User(
      id: userId,
      phoneNumber: phoneNumber,
      displayName: displayName,
      role: role,
      isSubscribed: isSubscribed,
      createdAt: DateTime.now(),
      preferredLanguage: preferredLanguage,
    );

    // 2. Save to Supabase
    try {
      await _supabase.from('users').upsert(user.toMap());
    } catch (_) {}

    // 3. Save to local database
    final db = await _db.database;
    await db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Restore session and get current user
  Future<User?> restoreSession() async {
    final firebaseUser = _auth.currentUser;

    try {
      String? userId;
      if (firebaseUser != null) {
        userId = firebaseUser.uid;
      } else {
        userId = _prefs.getString(_keyUserId);
      }

      if (userId == null) return null;

      // Try to get from Supabase first
      try {
        final data = await _supabase
            .from('users')
            .select()
            .eq('id', userId)
            .single();
        final user = User.fromMap(data);
        // Sync to local
        final db = await _db.database;
        await db.insert(
          'users',
          user.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return user;
      } catch (_) {}

      // Fallback to local database
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

      // If not in database but we have firebase user, create a profile
      if (firebaseUser != null) {
        final phoneNumber = firebaseUser.phoneNumber ?? '';
        final role = assignRoleByPhoneNumber(phoneNumber);
        final displayName =
            'User ${phoneNumber.length > 4 ? phoneNumber.substring(phoneNumber.length - 4) : "New"}';

        final user = User(
          id: userId,
          phoneNumber: phoneNumber,
          displayName: displayName,
          role: role,
          createdAt: DateTime.now(),
        );

        // Save to Supabase and Local
        try {
          await _supabase.from('users').upsert(user.toMap());
        } catch (_) {}
        await db.insert('users', user.toMap());
        return user;
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// Logout
  Future<void> logout() async {
    await _auth.signOut();

    try {
      final subscriptionService = await SubscriptionService.init();
      await subscriptionService.clearSubscription();
    } catch (_) {}

    // Clear local session
    await _prefs.clear(); // Simpler than remove each if we want full logout
  }

  /// Get current user ID
  String? getCurrentUserId() =>
      _auth.currentUser?.uid ?? _prefs.getString(_keyUserId);

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
    final Map<String, dynamic> updates = {};
    if (displayName != null) updates['display_name'] = displayName;
    if (bio != null) updates['bio'] = bio;
    if (profilePicture != null) updates['profile_picture'] = profilePicture;
    if (preferredLanguage != null)
      updates['preferred_language'] = preferredLanguage;

    if (updates.isNotEmpty) {
      // 1. Update Supabase
      try {
        await _supabase.from('users').update(updates).eq('id', userId);
      } catch (_) {}

      // 2. Update Local
      await db.update('users', updates, where: 'id = ?', whereArgs: [userId]);

      // 3. Update Prefs if needed
      if (displayName != null)
        await _prefs.setString(_keyDisplayName, displayName);
      if (preferredLanguage != null)
        await _prefs.setString(_keyPreferredLanguage, preferredLanguage);
    }
  }

  /// Assign role based on phone number
  static UserRole assignRoleByPhoneNumber(String phoneNumber) {
    final roleStr = AuthConstants.getRoleForPhoneNumber(phoneNumber);
    return UserRoleExtension.fromString(roleStr);
  }
}
