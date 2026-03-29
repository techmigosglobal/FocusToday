import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/services/cache_service.dart';
import '../../../../core/config/feature_flags.dart';
import '../../../../core/services/cloud_functions_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/user_sync_service.dart';
import '../../../../core/utils/phone_number_utils.dart';
import '../../../../shared/models/user.dart';

class UserRepository {
  // Cursor-based pagination state keyed by role filter.
  final Map<String, DocumentSnapshot?> _lastDocCursors = {};

  Future<Map<String, dynamic>> getAllUsers({
    int page = 1,
    int limit = 20,
    String? role,
  }) async {
    final normalizedRole = role != null && role.isNotEmpty
        ? _normalizeRoleForApi(role)
        : '';
    final cacheKey = 'users_page_${page}_limit_${limit}_role_$normalizedRole';
    final cached = CacheService.get(
      cacheKey,
      maxAge: const Duration(seconds: 15),
    );
    if (cached is Map) {
      final rawUsers = List<Map<String, dynamic>>.from(
        (cached['users'] as List? ?? const []),
      );
      final users = rawUsers.map(User.fromMap).toList(growable: false);
      return {
        'users': users,
        'total': (cached['total'] as num?)?.toInt() ?? users.length,
        'page': (cached['page'] as num?)?.toInt() ?? page,
        'total_pages':
            (cached['total_pages'] as num?)?.toInt() ??
            (users.length / limit.clamp(1, 50)).ceil().clamp(1, 99999),
      };
    }

    try {
      final safeLimit = limit.clamp(1, 50);

      // --- Count total matching docs (cached separately) ---
      int totalDocs = 0;
      final countCacheKey = 'users_count_role_$normalizedRole';
      final cachedCount = CacheService.get(
        countCacheKey,
        maxAge: const Duration(seconds: 30),
      );
      if (cachedCount is int) {
        totalDocs = cachedCount;
      } else {
        AggregateQuery countQuery;
        if (normalizedRole.isNotEmpty) {
          countQuery = FirestoreService.users
              .where('role', isEqualTo: normalizedRole)
              .count();
        } else {
          countQuery = FirestoreService.users.count();
        }
        final countSnap = await countQuery.get();
        totalDocs = countSnap.count ?? 0;
        await CacheService.set(countCacheKey, totalDocs);
      }

      // --- Fetch the requested page using cursor-based pagination ---
      Query<Map<String, dynamic>> query = FirestoreService.users.orderBy(
        'created_at',
        descending: true,
      );
      if (normalizedRole.isNotEmpty) {
        query = query.where('role', isEqualTo: normalizedRole);
      }

      // For page > 1, use cursor from previous page if available.
      final cursorKey = '${normalizedRole}_page_${page - 1}';
      if (page > 1 && _lastDocCursors.containsKey(cursorKey)) {
        query = query.startAfterDocument(_lastDocCursors[cursorKey]!);
      } else if (page > 1) {
        // Fallback: skip by fetching offset docs (less efficient but correct).
        final skipCount = (page - 1) * safeLimit;
        final skipSnap = await query.limit(skipCount).get();
        if (skipSnap.docs.isNotEmpty) {
          query = query.startAfterDocument(skipSnap.docs.last);
        }
      }

      final snapshot = await query.limit(safeLimit).get();
      final users = snapshot.docs
          .map((d) => User.fromMap({'id': d.id, ...d.data()}))
          .toList();

      // Store cursor for next page.
      if (snapshot.docs.isNotEmpty) {
        final nextCursorKey = '${normalizedRole}_page_$page';
        _lastDocCursors[nextCursorKey] = snapshot.docs.last;
      }

      final totalPages = (totalDocs / safeLimit).ceil().clamp(1, 99999);
      final result = {
        'users': users,
        'total': totalDocs,
        'page': page,
        'total_pages': totalPages,
      };
      await CacheService.set(cacheKey, {
        'users': users.map((user) => user.toJson()).toList(growable: false),
        'total': totalDocs,
        'page': page,
        'total_pages': totalPages,
      });

      return result;
    } catch (e) {
      debugPrint('UserRepository.getAllUsers error: $e');
      return {'users': <User>[], 'total': 0, 'page': page, 'total_pages': 1};
    }
  }

  /// Reset pagination cursors (call when data changes).
  void resetPagination() {
    _lastDocCursors.clear();
  }

  Future<List<User>> getAllUsersFlat({
    String? role,
    int pageSize = 50,
    int maxPages = 20,
  }) async {
    resetPagination();
    final first = await getAllUsers(page: 1, limit: pageSize, role: role);
    final users = <User>[...(first['users'] as List<User>? ?? const <User>[])];
    final totalPages = (first['total_pages'] as int? ?? 1).clamp(1, maxPages);

    for (int page = 2; page <= totalPages; page++) {
      final next = await getAllUsers(page: page, limit: pageSize, role: role);
      users.addAll(next['users'] as List<User>? ?? const <User>[]);
    }
    return users;
  }

  Future<bool> updateUserRole(String userId, UserRole newRole) async {
    if (!FeatureFlags.roleManagementCallableEnabled) {
      try {
        // Low-cost fallback: update Firestore role directly.
        // Note: custom auth claims are not updated in this path.
        await FirestoreService.users.doc(userId).set({
          'role': newRole.toApiString(),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await _invalidateCaches(userId: userId);
        resetPagination();
        UserSyncService.notify(
          reason: UserSyncReason.roleChanged,
          userId: userId,
        );
        return true;
      } catch (e) {
        debugPrint('UserRepository.updateUserRole fallback error: $e');
        return false;
      }
    }
    try {
      // Route solely through Cloud Function — it validates admin role,
      // updates Firestore, sets custom claims, and creates an audit log.
      await CloudFunctionsService.instance.httpsCallable('updateUserRole').call(
        {'userId': userId, 'role': newRole.toApiString()},
      );

      await _invalidateCaches(userId: userId);
      resetPagination();
      UserSyncService.notify(
        reason: UserSyncReason.roleChanged,
        userId: userId,
      );
      return true;
    } catch (e) {
      debugPrint('UserRepository.updateUserRole error: $e');
      return false;
    }
  }

  Future<bool> deleteUser(String userId) async {
    try {
      await FirestoreService.users.doc(userId).delete();
      await _invalidateCaches(userId: userId);
      resetPagination();
      UserSyncService.notify(reason: UserSyncReason.deleted, userId: userId);
      return true;
    } catch (e) {
      debugPrint('UserRepository.deleteUser error: $e');
      return false;
    }
  }

  Future<List<User>> searchUsers(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return [];

    final cacheKey = 'users_search_$normalized';
    final cached = CacheService.get(
      cacheKey,
      maxAge: const Duration(seconds: 20),
    );
    if (cached is List) {
      return cached
          .whereType<Map>()
          .map((row) => User.fromMap(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    }

    try {
      final snapshot = await FirestoreService.users
          .orderBy('created_at', descending: true)
          .limit(250)
          .get();
      final users = snapshot.docs
          .map((d) => User.fromMap({'id': d.id, ...d.data()}))
          .where((u) {
            final name = u.displayName.toLowerCase();
            final email = (u.email ?? '').toLowerCase();
            final phone = u.phoneNumber.toLowerCase();
            return name.contains(normalized) ||
                email.contains(normalized) ||
                phone.contains(normalized);
          })
          .toList(growable: false);
      await CacheService.set(
        cacheKey,
        users.map((user) => user.toJson()).toList(growable: false),
      );
      return users;
    } catch (e) {
      debugPrint('UserRepository.searchUsers error: $e');
      return [];
    }
  }

  Future<User?> createUser({
    required String id,
    required String displayName,
    required String phoneNumber,
    String? email,
    required UserRole role,
  }) async {
    try {
      final normalizedPhone = PhoneNumberUtils.normalizeIndianPhone(
        phoneNumber,
      );

      // Use Cloud Function for proper user creation (handles dedup, Auth, claims).
      try {
        final response = await CloudFunctionsService.instance
            .httpsCallable('createUserWithRole')
            .call({
              'phoneNumber': normalizedPhone,
              'displayName': displayName,
              'email': email ?? '',
              'role': role.toApiString(),
            });
        final data = Map<String, dynamic>.from(
          (response.data as Map?) ?? const <String, dynamic>{},
        );
        if (data['ok'] == true && data['user'] is Map) {
          final userMap = Map<String, dynamic>.from(data['user'] as Map);
          await _invalidateCaches(userId: userMap['id']?.toString() ?? id);
          resetPagination();
          final userId = userMap['id']?.toString() ?? id;
          UserSyncService.notify(
            reason: UserSyncReason.created,
            userId: userId,
          );
          return User.fromMap(userMap);
        }
      } catch (cfError) {
        debugPrint(
          'UserRepository.createUser CF fallback to direct write: $cfError',
        );
      }

      // Fallback: direct Firestore write (for when CF is not deployed yet).
      final userId = 'phone_$normalizedPhone';
      await FirestoreService.users.doc(userId).set({
        'display_name': displayName,
        'phone_number': PhoneNumberUtils.toE164Indian(phoneNumber),
        'phone_normalized': normalizedPhone,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        'role': role.toApiString(),
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _invalidateCaches(userId: userId);
      resetPagination();
      UserSyncService.notify(reason: UserSyncReason.created, userId: userId);
      return getUserById(userId);
    } catch (e) {
      debugPrint('UserRepository.createUser error: $e');
      return null;
    }
  }

  Future<User?> getUserById(String userId) async {
    final cacheKey = 'user_detail_$userId';
    final cached = CacheService.get(
      cacheKey,
      maxAge: const Duration(minutes: 1),
    );
    if (cached is Map) {
      return User.fromMap(Map<String, dynamic>.from(cached));
    }

    try {
      final doc = await FirestoreService.users.doc(userId).get();
      if (!doc.exists || doc.data() == null) return null;
      final user = User.fromMap({'id': doc.id, ...doc.data()!});
      await CacheService.set(cacheKey, user.toJson());
      return user;
    } catch (e) {
      debugPrint('UserRepository.getUserById error: $e');
      return null;
    }
  }

  String _normalizeRoleForApi(String role) {
    final normalized = role
        .trim()
        .toLowerCase()
        .replaceAll('_', '')
        .replaceAll(' ', '');
    switch (normalized) {
      case 'superadmin':
        return 'super_admin';
      case 'admin':
      case 'administrator':
      case 'admins':
        return 'admin';
      case 'reporter':
      case 'reporters':
        return 'reporter';
      case 'publicuser':
        return 'public_user';
      default:
        return role;
    }
  }

  Future<void> _invalidateCaches({String? userId}) async {
    await CacheService.invalidatePrefix('users_');
    if (userId != null && userId.isNotEmpty) {
      await CacheService.invalidate('user_detail_$userId');
    }
  }
}
