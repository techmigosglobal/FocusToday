import 'package:flutter/foundation.dart';

import '../../../../core/services/cache_service.dart';
import '../../../../core/services/cloud_functions_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../shared/models/post.dart';
import '../../../../shared/models/user.dart';
import '../../../feed/data/repositories/post_repository.dart';

class SearchRepository {
  final PostRepository _postRepo = PostRepository();

  Future<List<Post>> searchPosts(
    String query, {
    String? category,
    ContentType? contentType,
    int limit = 30,
  }) async {
    if (query.trim().isEmpty) return [];
    return _postRepo.discoverPosts(
      query: query,
      category: category,
      contentType: contentType,
      limit: limit,
    );
  }

  Future<List<User>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    final normalized = query.trim().toLowerCase();
    final cacheKey = 'search_users_$normalized';
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
      debugPrint('[SearchRepo] searchUsers error: $e');
      return [];
    }
  }

  Future<List<String>> getTrendingHashtags() async {
    // Check cache first (60-second TTL).
    const cacheKey = 'trending_hashtags';
    final cached = CacheService.get(
      cacheKey,
      maxAge: const Duration(seconds: 60),
    );
    if (cached is List) {
      return cached.map((e) => e.toString()).toList(growable: false);
    }

    // Prefer Cloud Function for server-side aggregation.
    try {
      final result = await CloudFunctionsService.instance
          .httpsCallable('getTrendingHashtags')
          .call(<String, dynamic>{});
      final data = Map<String, dynamic>.from(result.data as Map);
      final hashtags = (data['hashtags'] as List? ?? [])
          .map((e) => (e as Map)['tag']?.toString() ?? '')
          .where((t) => t.isNotEmpty)
          .toList(growable: false);
      await CacheService.set(cacheKey, hashtags);
      return hashtags;
    } catch (e) {
      debugPrint(
        '[SearchRepo] getTrendingHashtags CF failed, falling back: $e',
      );
    }

    // Fallback: client-side aggregation from trending posts (limited set).
    final posts = await _postRepo.getTrendingPosts(limit: 30);
    if (posts.isEmpty) return [];

    final score = <String, int>{};
    for (final post in posts) {
      for (final tag in post.hashtags) {
        final normalized = tag.trim().toLowerCase();
        if (normalized.isEmpty) continue;
        score[normalized] = (score[normalized] ?? 0) + 1;
      }
      if (post.hashtags.isEmpty && post.category.trim().isNotEmpty) {
        final categoryTag = post.category.trim().toLowerCase();
        score[categoryTag] = (score[categoryTag] ?? 0) + 1;
      }
    }

    final sorted = score.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final result = sorted.take(12).map((e) => '#${e.key}').toList();
    await CacheService.set(cacheKey, result);
    return result;
  }

  Future<List<String>> getPopularHashtags() async => getTrendingHashtags();
  Future<List<Post>> getTrendingPosts({int limit = 15}) async =>
      _postRepo.getTrendingPosts(limit: limit);
  Future<List<Post>> getRecommendedPosts(
    String userId, {
    int limit = 15,
  }) async => _postRepo.getRecommendedPosts(userId, limit: limit);
  Future<List<Post>> getRelatedPosts(String postId, {int limit = 12}) async =>
      _postRepo.getRelatedPosts(postId, limit: limit);
  Future<List<Post>> getPostsByCategory(String category) async =>
      _postRepo.discoverPosts(category: category, limit: 30);

  Future<List<Post>> searchByHashtag(String hashtag) async {
    final normalized = hashtag.replaceAll('#', '').trim();
    if (normalized.isEmpty) return [];
    return _postRepo.discoverPosts(query: normalized, limit: 30);
  }

  Future<List<Map<String, String>>> getSuggestedUsers() async {
    const cacheKey = 'search_suggested_users';
    final cached = CacheService.get(
      cacheKey,
      maxAge: const Duration(minutes: 1),
    );
    if (cached is List) {
      return cached
          .whereType<Map>()
          .map(
            (row) => Map<String, String>.from(
              row.map((key, value) => MapEntry('$key', '$value')),
            ),
          )
          .toList(growable: false);
    }

    try {
      final snapshot = await FirestoreService.users
          .orderBy('created_at', descending: true)
          .limit(20)
          .get();
      final users = snapshot.docs
          .map(
            (d) => {
              'name': (d.data()['display_name'] ?? 'Unknown').toString(),
              'id': d.id,
            },
          )
          .toList(growable: false);
      await CacheService.set(cacheKey, users);
      return users;
    } catch (e) {
      debugPrint('[SearchRepo] getSuggestedUsers error: $e');
      return [];
    }
  }
}
