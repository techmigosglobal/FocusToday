import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/services/cache_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../shared/models/post.dart';
import '../../../../shared/models/user.dart';
import '../../../feed/data/repositories/post_repository.dart';

class ProfileRepository {
  final PostRepository _postRepo = PostRepository();

  Future<User?> getUserById(String userId) async {
    final cacheKey = 'profile_user_$userId';
    final cached = CacheService.get(
      cacheKey,
      maxAge: const Duration(minutes: 1),
    );
    if (cached is Map) {
      return _mapToUser(Map<String, dynamic>.from(cached));
    }

    try {
      final doc = await FirestoreService.users.doc(userId).get();
      if (!doc.exists || doc.data() == null) return _fallbackUser(userId);
      final user = _mapToUser({'id': doc.id, ...doc.data()!});
      await CacheService.set(cacheKey, user.toJson());
      return user;
    } catch (e) {
      debugPrint('[ProfileRepo] getUserById error: $e');
      rethrow;
    }
  }

  Future<void> updateProfile({
    required String userId,
    String? displayName,
    String? bio,
    String? profilePicture,
    String? area,
    String? district,
    String? state,
  }) async {
    try {
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
      await _syncAuthoredContentProfileFields(
        userId: userId,
        displayName: displayName,
        profilePicture: profilePicture,
      );
      await _invalidateProfileCaches(userId);
    } catch (e) {
      debugPrint('[ProfileRepo] updateProfile error: $e');
    }
  }

  Future<int> getPostsCount(String userId) async =>
      (await _getUserStats(userId))['total_posts'] ?? 0;
  Future<int> getUserAllPostsCount(String userId) async =>
      (await _getUserStats(userId))['total_posts'] ?? 0;
  Future<int> getUserPostsCount(String userId) async =>
      (await _getUserStats(userId))['approved_posts'] ?? 0;
  Future<List<Post>> getUserPosts(String userId) async =>
      _postRepo.getPostsByAuthor(userId);
  Future<int> getUserBookmarksCount(String userId) async =>
      (await _getUserStats(userId))['bookmarks'] ?? 0;
  Future<List<Post>> getUserBookmarks(String userId) async =>
      _postRepo.getUserBookmarks(userId);

  Future<void> removeBookmark(String postId, String userId) async {
    final result = await _postRepo.toggleBookmark(postId, userId);
    if (!result.success) throw Exception('Failed to remove bookmark');
    await CacheService.invalidate('profile_stats_$userId');
  }

  Future<String?> uploadProfilePicture(String filePath, String userId) async {
    try {
      final file = File(filePath);
      final ext = file.path.split('.').last.toLowerCase();
      final path =
          'profiles/$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await FirebaseStorage.instance.ref(path).putFile(file);
      return FirebaseStorage.instance.ref(path).getDownloadURL();
    } catch (e) {
      debugPrint('[ProfileRepo] uploadProfilePicture error: $e');
      return null;
    }
  }

  Future<List<Post>> getUserStories(String userId) async =>
      _postRepo.getPostsByContentType(userId, contentType: ContentType.story);

  Future<List<Post>> getUserArticles(String userId) async =>
      _postRepo.getPostsByContentType(userId, contentType: ContentType.article);

  Future<List<Post>> getPostsByContentType(
    String userId, {
    ContentType? contentType,
    PostStatus? status,
  }) async {
    return _postRepo.getPostsByContentType(
      userId,
      contentType: contentType,
      status: status,
    );
  }

  Future<Map<String, int>> getContentTypeCounts(String userId) async {
    final stats = await _getUserStats(userId);
    return {
      'posts': stats['total_posts'] ?? 0,
      'stories': stats['stories'] ?? 0,
      'articles': stats['articles'] ?? 0,
      'bookmarks': stats['bookmarks'] ?? 0,
    };
  }

  Future<Map<String, dynamic>> _getUserStats(String userId) async {
    final cacheKey = 'profile_stats_$userId';
    final cached = CacheService.get(
      cacheKey,
      maxAge: const Duration(seconds: 30),
    );
    if (cached is Map) {
      return Map<String, dynamic>.from(cached);
    }

    try {
      final totalPosts = await FirestoreService.posts
          .where('author_id', isEqualTo: userId)
          .count()
          .get();
      final approvedPosts = await FirestoreService.posts
          .where('author_id', isEqualTo: userId)
          .where('status', isEqualTo: PostStatus.approved.toStr())
          .count()
          .get();
      final storyCount = await FirestoreService.posts
          .where('author_id', isEqualTo: userId)
          .where('content_type', isEqualTo: ContentType.story.toStr())
          .count()
          .get();
      final articleCount = await FirestoreService.posts
          .where('author_id', isEqualTo: userId)
          .where('content_type', isEqualTo: ContentType.article.toStr())
          .count()
          .get();
      final bookmarkCount = await FirestoreService.userBookmarks(
        userId,
      ).count().get();

      final stats = {
        'total_posts': totalPosts.count ?? 0,
        'approved_posts': approvedPosts.count ?? 0,
        'stories': storyCount.count ?? 0,
        'articles': articleCount.count ?? 0,
        'bookmarks': bookmarkCount.count ?? 0,
      };
      await CacheService.set(cacheKey, stats);
      return stats;
    } catch (e) {
      debugPrint('[ProfileRepo] _getUserStats error: $e');
      return {};
    }
  }

  User _mapToUser(Map<String, dynamic> row) {
    return User(
      id: (row['id'] ?? '').toString(),
      phoneNumber: (row['phone_number'] ?? '').toString(),
      displayName: (row['display_name'] ?? 'Unknown').toString(),
      email: row['email']?.toString(),
      bio: row['bio']?.toString(),
      profilePicture: row['profile_picture']?.toString(),
      role: UserRoleExtension.fromString((row['role'] ?? '').toString()),
      area: row['area']?.toString(),
      district: row['district']?.toString(),
      state: row['state']?.toString(),
      createdAt: FirestoreService.toDateTime(row['created_at']),
      postsCount: row['posts_count'] is int ? row['posts_count'] as int : 0,
    );
  }

  User _fallbackUser(String userId) {
    return User(
      id: userId,
      phoneNumber: '+91 9876543210',
      displayName: 'Demo User',
      role: UserRole.publicUser,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    );
  }

  Future<void> _invalidateProfileCaches(String userId) async {
    await CacheService.invalidate('profile_user_$userId');
    await CacheService.invalidate('profile_stats_$userId');
    await CacheService.invalidatePrefix('feed_');
    await CacheService.invalidatePrefix('bookmarks_');
    await CacheService.invalidatePrefix('search_users_');
    await CacheService.invalidate('search_suggested_users');
  }

  Future<void> _syncAuthoredContentProfileFields({
    required String userId,
    String? displayName,
    String? profilePicture,
  }) async {
    final postUpdates = <String, dynamic>{
      'updated_at': FieldValue.serverTimestamp(),
    };
    final commentUpdates = <String, dynamic>{
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (displayName != null) {
      postUpdates['author_name'] = displayName;
      commentUpdates['author_name'] = displayName;
    }
    if (profilePicture != null) {
      postUpdates['author_avatar'] = profilePicture;
    }

    final futures = <Future<void>>[];
    if (postUpdates.length > 1) {
      futures.add(
        _bulkUpdateByQuery(
          FirestoreService.posts.where('author_id', isEqualTo: userId),
          postUpdates,
        ),
      );
    }
    if (displayName != null) {
      futures.add(
        _bulkUpdateByQuery(
          FirestoreService.db
              .collectionGroup('comments')
              .where('author_id', isEqualTo: userId),
          commentUpdates,
        ),
      );
      futures.add(
        _bulkUpdateByQuery(
          FirestoreService.db
              .collectionGroup('replies')
              .where('author_id', isEqualTo: userId),
          commentUpdates,
        ),
      );
    }
    if (futures.isEmpty) return;
    await Future.wait(futures);
  }

  Future<void> _bulkUpdateByQuery(
    Query<Map<String, dynamic>> baseQuery,
    Map<String, dynamic> updates,
  ) async {
    if (updates.isEmpty) return;
    DocumentSnapshot<Map<String, dynamic>>? cursor;

    while (true) {
      Query<Map<String, dynamic>> query = baseQuery.limit(250);
      if (cursor != null) {
        query = query.startAfterDocument(cursor);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) break;

      final batch = FirestoreService.db.batch();
      for (final doc in snapshot.docs) {
        batch.set(doc.reference, updates, SetOptions(merge: true));
      }
      await batch.commit();

      if (snapshot.docs.length < 250) break;
      cursor = snapshot.docs.last;
    }
  }
}
