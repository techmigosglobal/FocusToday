import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/cache_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/post_sync_service.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../core/services/user_sync_service.dart';
import '../../../../core/utils/phone_number_utils.dart';
import '../../../feed/data/repositories/post_repository.dart';
import '../../../../shared/models/user.dart';

class AuthRepository {
  final SharedPreferences _prefs;

  AuthRepository._(this._prefs);

  static AuthRepository? _instance;

  static Future<AuthRepository> init() async {
    if (_instance != null) return _instance!;
    final prefs = await SharedPreferences.getInstance();
    _instance = AuthRepository._(prefs);
    return _instance!;
  }

  Future<User?> restoreSession() async {
    final userId = _prefs.getString('user_id');
    if (userId == null) return null;

    final firebaseUser = _safeCurrentUser();
    if (firebaseUser == null || firebaseUser.uid != userId) {
      await clearSession();
      return null;
    }

    try {
      final doc = await FirestoreService.users.doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final remoteUser = User.fromMap({'id': doc.id, ...doc.data()!});
        await _persistLocalSession(remoteUser);
        unawaited(_warmFeedCache(remoteUser.id));
        return remoteUser;
      }
    } catch (e) {
      debugPrint('[AuthRepo] restoreSession remote read failed: $e');
    }

    final localUser = _restoreLocalUser();
    if (localUser != null) {
      unawaited(_warmFeedCache(localUser.id));
    }
    return localUser;
  }

  Future<void> clearSession() async {
    final userId = _prefs.getString('user_id');
    if (userId != null && userId.trim().isNotEmpty) {
      try {
        await NotificationService.instance.deleteToken(userId: userId);
      } catch (e) {
        debugPrint('[AuthRepo] token cleanup during logout failed: $e');
      }
    }

    await _prefs.remove('user_id');
    await _prefs.remove('phone_number');
    await _prefs.remove('display_name');
    await _prefs.remove('role');
    await _prefs.remove('profile_picture');
    await _prefs.remove('created_at');
    await _prefs.remove('bio');
    await _prefs.remove('area');
    await _prefs.remove('district');
    await _prefs.remove('state');
    await _prefs.remove('email');
    try {
      await fa.FirebaseAuth.instance.signOut();
    } catch (_) {}
    await SecureStorageService.clearAll();
  }

  bool isLoggedIn() => _prefs.getString('user_id') != null;

  /// Verifies the Msg91 access token via Cloud Function and creates a Firebase session.
  ///
  /// Returns a [AuthResult] with success/failure and error details.
  Future<AuthResult> verifyAndSaveSession({
    required String phoneNumber,
    String? accessToken,
  }) async {
    final totalWatch = Stopwatch()..start();
    final normalizedPhone = PhoneNumberUtils.normalizeIndianPhone(phoneNumber);
    final verifiedAccessToken = accessToken?.trim() ?? '';
    if (!PhoneNumberUtils.isValidIndianPhone(normalizedPhone) ||
        verifiedAccessToken.isEmpty) {
      return AuthResult.failure(
        'Invalid phone number or missing access token.',
      );
    }

    try {
      debugPrint(
        '[AuthRepo] Calling verifyMsg91OtpAndExchangeToken (asia-south1)',
      );

      // Cloud Functions are deployed to asia-south1 region.
      final response =
          await FirebaseFunctions.instanceFor(region: 'asia-south1')
              .httpsCallable(
                'verifyMsg91OtpAndExchangeToken',
                options: HttpsCallableOptions(
                  timeout: const Duration(seconds: 30),
                ),
              )
              .call({
                'phone_number': normalizedPhone,
                'access_token': verifiedAccessToken,
              });

      final data = Map<String, dynamic>.from(
        (response.data as Map?) ?? const <String, dynamic>{},
      );
      final serverDebug = data['debug'] is Map
          ? Map<String, dynamic>.from(data['debug'] as Map)
          : null;
      final customToken = (data['custom_token'] ?? '').toString().trim();
      if (customToken.isEmpty) {
        debugPrint('[AuthRepo] Missing Firebase custom token in auth response');
        return AuthResult.failure(
          'Authentication incomplete: No session token received. Please try again.',
        );
      }

      final rawUser = Map<String, dynamic>.from(
        (data['user'] as Map?) ?? const <String, dynamic>{},
      );
      final targetUid = (rawUser['id'] ?? rawUser['uid'] ?? '').toString();
      final current = _safeCurrentUser();
      if (current != null && targetUid.isNotEmpty && current.uid != targetUid) {
        await fa.FirebaseAuth.instance.signOut();
      }

      final credential = await fa.FirebaseAuth.instance.signInWithCustomToken(
        customToken,
      );
      final signedInUid = credential.user?.uid.isNotEmpty == true
          ? credential.user!.uid
          : targetUid;
      if (signedInUid.isEmpty) {
        debugPrint('[AuthRepo] Firebase sign-in succeeded without a uid');
        return AuthResult.failure('Sign-in failed: User ID missing.');
      }

      final userMap = <String, dynamic>{
        'id': signedInUid,
        'phone_number': rawUser['phone_number'] ?? normalizedPhone,
        'display_name': rawUser['display_name'] ?? 'User',
        'role': rawUser['role'] ?? 'public_user',
        'email': rawUser['email'],
        'profile_picture': rawUser['profile_picture'],
        'bio': rawUser['bio'],
        'area': rawUser['area'],
        'district': rawUser['district'],
        'state': rawUser['state'],
        'created_at': rawUser['created_at'] ?? DateTime.now().toIso8601String(),
      };
      final user = User.fromMap(userMap);
      await _persistLocalSession(user);
      await SecureStorageService.saveUserId(signedInUid);
      unawaited(_warmFeedCache(signedInUid));
      totalWatch.stop();
      debugPrint(
        '[AuthRepo][Perf] verifyAndSaveSession totalMs=${totalWatch.elapsedMilliseconds} '
        'serverDebug=${serverDebug ?? const <String, dynamic>{}}',
      );
      return AuthResult.success(user: user, diagnostics: serverDebug);
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        '[AuthRepo] FirebaseFunctionsException: ${e.code} — ${e.message}',
      );
      final msg = switch (e.code) {
        'unauthenticated' =>
          'OTP verification failed. The code may have expired — please request a new one.',
        'invalid-argument' => 'Invalid data sent to server. Please try again.',
        'permission-denied' =>
          'Your account has been disabled. Contact support.',
        'not-found' =>
          'Authentication service not found. Please update the app.',
        'unavailable' =>
          'Service temporarily unavailable. Please try again in a moment.',
        'deadline-exceeded' =>
          'Request timed out. Check your internet connection and try again.',
        _ => 'Verification failed (${e.code}). Please try again.',
      };
      return AuthResult.failure(msg);
    } catch (e) {
      debugPrint('[AuthRepo] verifyAndSaveSession error: $e');
      final errStr = e.toString();
      if (errStr.contains('network') ||
          errStr.contains('timeout') ||
          errStr.contains('connection')) {
        return AuthResult.failure(
          'Network error. Please check your internet connection.',
        );
      }
      return AuthResult.failure('Verification failed. Please try again.');
    }
  }

  Future<void> logout() async {
    await clearSession();
  }

  Future<void> updateProfile({
    String? displayName,
    String? bio,
    String? profilePicture,
    String? area,
    String? district,
    String? state,
    bool syncRemote = true,
    bool notifyUserSync = true,
  }) async {
    final userId = _prefs.getString('user_id');
    if (displayName != null) {
      await _prefs.setString('display_name', displayName);
    }
    if (bio != null) await _prefs.setString('bio', bio);
    if (profilePicture != null) {
      await _prefs.setString('profile_picture', profilePicture);
    }
    if (area != null) await _prefs.setString('area', area);
    if (district != null) await _prefs.setString('district', district);
    if (state != null) await _prefs.setString('state', state);

    if (userId != null && syncRemote) {
      final data = <String, dynamic>{
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (displayName != null) data['display_name'] = displayName;
      if (bio != null) data['bio'] = bio;
      if (profilePicture != null) data['profile_picture'] = profilePicture;
      if (area != null) data['area'] = area;
      if (district != null) data['district'] = district;
      if (state != null) data['state'] = state;

      await FirestoreService.users
          .doc(userId)
          .set(data, SetOptions(merge: true));
    }

    if (userId != null) {
      await CacheService.invalidate('profile_user_$userId');
      await CacheService.invalidate('profile_stats_$userId');
      if (notifyUserSync) {
        UserSyncService.notify(reason: UserSyncReason.updated, userId: userId);
      }
      PostSyncService.notify(reason: PostSyncReason.updated, authorId: userId);
    }
  }

  Future<void> _persistLocalSession(User user) async {
    await _prefs.setString('user_id', user.id);
    await _prefs.setString('phone_number', user.phoneNumber);
    await _prefs.setString('display_name', user.displayName);
    await _prefs.setString('role', user.role.toStr());
    if (user.profilePicture != null) {
      await _prefs.setString('profile_picture', user.profilePicture!);
    } else {
      await _prefs.remove('profile_picture');
    }
    if (user.email != null) {
      await _prefs.setString('email', user.email!);
    } else {
      await _prefs.remove('email');
    }
    if (user.bio != null) {
      await _prefs.setString('bio', user.bio!);
    } else {
      await _prefs.remove('bio');
    }
    if (user.area != null) {
      await _prefs.setString('area', user.area!);
    } else {
      await _prefs.remove('area');
    }
    if (user.district != null) {
      await _prefs.setString('district', user.district!);
    } else {
      await _prefs.remove('district');
    }
    if (user.state != null) {
      await _prefs.setString('state', user.state!);
    } else {
      await _prefs.remove('state');
    }
    await _prefs.setString('created_at', user.createdAt.toIso8601String());
  }

  User? _restoreLocalUser() {
    final userId = _prefs.getString('user_id');
    if (userId == null) return null;

    final role = UserRoleExtension.fromString(_prefs.getString('role'));
    return User(
      id: userId,
      phoneNumber: _prefs.getString('phone_number') ?? '',
      email: _prefs.getString('email'),
      displayName: _prefs.getString('display_name') ?? 'User',
      role: role,
      profilePicture: _prefs.getString('profile_picture'),
      bio: _prefs.getString('bio'),
      area: _prefs.getString('area'),
      district: _prefs.getString('district'),
      state: _prefs.getString('state'),
      createdAt:
          DateTime.tryParse(_prefs.getString('created_at') ?? '') ??
          DateTime.now(),
    );
  }

  fa.User? _safeCurrentUser() {
    try {
      return fa.FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  Future<void> _warmFeedCache(String userId) async {
    if (userId.isEmpty) return;
    try {
      await PostRepository().getApprovedPostsWithInteractions(
        userId,
        forceRefresh: false,
      );
    } catch (_) {
      // Best effort background warmup.
    }
  }
}

/// Result of an authentication attempt.
class AuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final User? user;
  final Map<String, dynamic>? diagnostics;

  const AuthResult._({
    required this.isSuccess,
    this.errorMessage,
    this.user,
    this.diagnostics,
  });

  factory AuthResult.success({User? user, Map<String, dynamic>? diagnostics}) =>
      AuthResult._(isSuccess: true, user: user, diagnostics: diagnostics);
  factory AuthResult.failure(String message) =>
      AuthResult._(isSuccess: false, errorMessage: message);
}
