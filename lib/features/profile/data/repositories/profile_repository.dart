import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../shared/models/user.dart' as app_models;
import '../../../../shared/models/post.dart';
import '../../../../core/services/database_service.dart';

/// Profile Repository
/// Manages user profile data and related operations using Supabase
class ProfileRepository {
  final DatabaseService _db = DatabaseService.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Update user profile
  Future<void> updateProfile({
    required String userId,
    String? displayName,
    String? bio,
    String? profilePicture,
  }) async {
    final Map<String, dynamic> updates = {};
    if (displayName != null) updates['display_name'] = displayName;
    if (bio != null) updates['bio'] = bio;
    if (profilePicture != null) updates['profile_picture'] = profilePicture;

    if (updates.isNotEmpty) {
      // 1. Update Supabase
      try {
        await _supabase.from('users').update(updates).eq('id', userId);
      } catch (_) {}

      // 2. Update local database
      final db = await _db.database;
      await db.update('users', updates, where: 'id = ?', whereArgs: [userId]);
    }
  }

  /// Get user by ID
  Future<app_models.User?> getUserById(String userId) async {
    try {
      final data = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      if (data != null) {
        final user = app_models.User.fromMap(data);
        // Cache to local
        final db = await _db.database;
        await db.insert(
          'users',
          user.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return user;
      }
    } catch (_) {}

    // Fallback to local
    final db = await _db.database;
    final results = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return app_models.User.fromMap(results.first);
  }

  /// Get user's posts count (approved only)
  Future<int> getUserPostsCount(String userId) async {
    try {
      final response = await _supabase
          .from('posts')
          .select('id')
          .eq('author_id', userId)
          .eq('status', 'approved');
      return (response as List).length;
    } catch (e) {
      final db = await _db.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM posts WHERE author_id = ? AND status = ?',
        [userId, 'approved'],
      );
      return (result.first['count'] as int?) ?? 0;
    }
  }

  /// Get user's all posts count (including pending/rejected for own profile)
  Future<int> getUserAllPostsCount(String userId) async {
    try {
      final response = await _supabase
          .from('posts')
          .select('id')
          .eq('author_id', userId);
      return (response as List).length;
    } catch (e) {
      final db = await _db.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM posts WHERE author_id = ?',
        [userId],
      );
      return (result.first['count'] as int?) ?? 0;
    }
  }

  /// Get user's posts
  Future<List<Post>> getUserPosts(
    String userId, {
    bool includeAll = false,
  }) async {
    try {
      var query = _supabase.from('posts').select().eq('author_id', userId);
      if (!includeAll) {
        query = query.eq('status', 'approved');
      }

      final List<dynamic> response = await query.order(
        'created_at',
        ascending: false,
      );
      return response.map((data) => Post.fromMap(data)).toList();
    } catch (e) {
      final db = await _db.database;
      final results = includeAll
          ? await db.query(
              'posts',
              where: 'author_id = ?',
              whereArgs: [userId],
              orderBy: 'created_at DESC',
            )
          : await db.query(
              'posts',
              where: 'author_id = ? AND status = ?',
              whereArgs: [userId, 'approved'],
              orderBy: 'created_at DESC',
            );

      return results.map((map) => Post.fromMap(map)).toList();
    }
  }

  /// Get user's bookmarked posts
  Future<List<Post>> getUserBookmarks(String userId) async {
    try {
      // In Supabase, we use a join or a second query. For simplicity here:
      final List<dynamic> interactions = await _supabase
          .from('user_interactions')
          .select('post_id')
          .eq('user_id', userId)
          .eq('is_bookmarked', true);

      if (interactions.isEmpty) return [];

      final postIds = interactions.map((i) => i['post_id']).toList();
      final List<dynamic> posts = await _supabase
          .from('posts')
          .select()
          .inFilter('id', postIds);

      return posts.map((data) => Post.fromMap(data)).toList();
    } catch (e) {
      final db = await _db.database;
      final results = await db.rawQuery(
        '''
        SELECT p.* FROM posts p
        INNER JOIN user_interactions ui ON p.id = ui.post_id
        WHERE ui.user_id = ? AND ui.is_bookmarked = 1
        ORDER BY ui.interacted_at DESC
      ''',
        [userId],
      );

      return results.map((map) => Post.fromMap(map)).toList();
    }
  }

  /// Get user's bookmarks count
  Future<int> getUserBookmarksCount(String userId) async {
    try {
      final response = await _supabase
          .from('user_interactions')
          .select('post_id')
          .eq('user_id', userId)
          .eq('is_bookmarked', true);
      return (response as List).length;
    } catch (e) {
      final db = await _db.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM user_interactions WHERE user_id = ? AND is_bookmarked = 1',
        [userId],
      );
      return (result.first['count'] as int?) ?? 0;
    }
  }

  /// Toggle bookmark on a post
  Future<void> toggleBookmark(String postId, String userId) async {
    try {
      // 1. Check existing interaction in Supabase
      final existing = await _supabase
          .from('user_interactions')
          .select()
          .eq('user_id', userId)
          .eq('post_id', postId)
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('user_interactions').insert({
          'id': '${userId}_$postId',
          'user_id': userId,
          'post_id': postId,
          'is_liked': false,
          'is_bookmarked': true,
          'interacted_at': DateTime.now().toIso8601String(),
        });

        // Update post bookmark count (better handled via Supabase function/trigger)
        await _supabase.rpc(
          'increment_bookmark_count',
          params: {'post_id': postId},
        );
      } else {
        final isBookmarked = existing['is_bookmarked'] == true;
        await _supabase
            .from('user_interactions')
            .update({
              'is_bookmarked': !isBookmarked,
              'interacted_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existing['id']);

        final increment = isBookmarked ? -1 : 1;
        await _supabase.rpc(
          'update_bookmark_count',
          params: {'p_post_id': postId, 'p_increment': increment},
        );
      }
    } catch (_) {
      // Local fallback
      final db = await _db.database;
      final existing = await db.query(
        'user_interactions',
        where: 'user_id = ? AND post_id = ?',
        whereArgs: [userId, postId],
        limit: 1,
      );

      if (existing.isEmpty) {
        await db.insert('user_interactions', {
          'id': '${userId}_$postId',
          'user_id': userId,
          'post_id': postId,
          'is_liked': 0,
          'is_bookmarked': 1,
          'interacted_at': DateTime.now().millisecondsSinceEpoch,
          'is_synced': 0,
        });
        await db.rawUpdate(
          'UPDATE posts SET bookmarks_count = bookmarks_count + 1 WHERE id = ?',
          [postId],
        );
      } else {
        final isBookmarked = existing.first['is_bookmarked'] == 1;
        await db.update(
          'user_interactions',
          {
            'is_bookmarked': isBookmarked ? 0 : 1,
            'interacted_at': DateTime.now().millisecondsSinceEpoch,
            'is_synced': 0,
          },
          where: 'user_id = ? AND post_id = ?',
          whereArgs: [userId, postId],
        );
        await db.rawUpdate(
          'UPDATE posts SET bookmarks_count = bookmarks_count + ? WHERE id = ?',
          [isBookmarked ? -1 : 1, postId],
        );
      }
    }
  }

  /// Remove bookmark
  Future<void> removeBookmark(String postId, String userId) async {
    try {
      await _supabase
          .from('user_interactions')
          .update({
            'is_bookmarked': false,
            'interacted_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('post_id', postId);

      await _supabase.rpc(
        'update_bookmark_count',
        params: {'p_post_id': postId, 'p_increment': -1},
      );
    } catch (_) {
      final db = await _db.database;
      await db.update(
        'user_interactions',
        {
          'is_bookmarked': 0,
          'interacted_at': DateTime.now().millisecondsSinceEpoch,
          'is_synced': 0,
        },
        where: 'user_id = ? AND post_id = ?',
        whereArgs: [userId, postId],
      );
      await db.rawUpdate(
        'UPDATE posts SET bookmarks_count = bookmarks_count - 1 WHERE id = ?',
        [postId],
      );
    }
  }

  /// Upload profile picture to Supabase Storage
  Future<String?> uploadProfilePicture({
    required String userId,
    required String filePath,
  }) async {
    final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final destination = 'profiles/$userId/$fileName';

    try {
      await _supabase.storage
          .from('media')
          .upload(
            destination,
            File(filePath),
            fileOptions: const FileOptions(upsert: true),
          );
      return _supabase.storage.from('media').getPublicUrl(destination);
    } catch (e) {
      debugPrint('Error uploading profile picture: $e');
      return null;
    }
  }
}
