import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../../../shared/models/post.dart';
import '../../../../shared/models/user.dart';
import '../../../../core/services/database_service.dart';

/// Search Repository
/// Handles all search-related queries using Supabase
class SearchRepository {
  final DatabaseService _db = DatabaseService.instance;
  final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;
  static const String _postsTable = 'posts';
  static const String _usersTable = 'users';

  /// Search posts by caption or hashtags
  Future<List<Post>> searchPosts(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final List<dynamic> response = await _supabase
          .from(_postsTable)
          .select()
          .eq('status', 'approved')
          .or('caption.ilike.%$query%,hashtags.ilike.%$query%')
          .order('created_at', ascending: false)
          .limit(50);
      
      // Alternative if .or() doesn't work: Use textSearch or filter
      // final response = await _supabase
      //   .from(_postsTable)
      //   .select()
      //   .eq('status', 'approved')
      //   .or('caption.ilike.%$query%,hashtags.ilike.%$query%')
      //   .order('created_at', ascending: false)
      //   .limit(50);

      return response.map((data) => Post.fromMap(data)).toList();
    } catch (e) {
      // Fallback to local
      final db = await _db.database;
      final searchTerm = '%${query.toLowerCase()}%';
      final results = await db.rawQuery(
        '''
        SELECT * FROM posts 
        WHERE status = 'approved' 
        AND (LOWER(caption) LIKE ? OR LOWER(hashtags) LIKE ?)
        ORDER BY created_at DESC
        LIMIT 50
      ''',
        [searchTerm, searchTerm],
      );
      return results.map((map) => Post.fromMap(map)).toList();
    }
  }

  /// Search users by display name
  Future<List<User>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final List<dynamic> response = await _supabase
          .from(_usersTable)
          .select()
          .or('display_name.ilike.%$query%,phone_number.ilike.%$query%')
          .order('display_name', ascending: true)
          .limit(20);

      return response.map((data) => User.fromMap(data)).toList();
    } catch (e) {
      // Fallback to local
      final db = await _db.database;
      final searchTerm = '%${query.toLowerCase()}%';
      final results = await db.rawQuery(
        '''
        SELECT * FROM users 
        WHERE LOWER(display_name) LIKE ? OR LOWER(phone_number) LIKE ?
        ORDER BY display_name ASC
        LIMIT 20
      ''',
        [searchTerm, searchTerm],
      );
      return results.map((map) => User.fromMap(map)).toList();
    }
  }

  /// Get posts by specific hashtag
  Future<List<Post>> searchByHashtag(String hashtag) async {
    final tag = hashtag.replaceAll('#', '');

    try {
      final List<dynamic> response = await _supabase
          .from(_postsTable)
          .select()
          .eq('status', 'approved')
          .ilike('hashtags', '%$tag%')
          .order('created_at', ascending: false)
          .limit(50);

      return response.map((data) => Post.fromMap(data)).toList();
    } catch (e) {
      // Fallback to local
      final db = await _db.database;
      final results = await db.rawQuery(
        '''
        SELECT * FROM posts 
        WHERE status = 'approved' 
        AND LOWER(hashtags) LIKE ?
        ORDER BY created_at DESC
        LIMIT 50
      ''',
        ['%$tag%'],
      );
      return results.map((map) => Post.fromMap(map)).toList();
    }
  }

  /// Get posts by category
  Future<List<Post>> getPostsByCategory(String category) async {
    try {
      final List<dynamic> response = await _supabase
          .from(_postsTable)
          .select()
          .eq('status', 'approved')
          .eq('category', category)
          .order('created_at', ascending: false)
          .limit(50);

      return response.map((data) => Post.fromMap(data)).toList();
    } catch (e) {
      final db = await _db.database;
      final results = await db.query(
        'posts',
        where: 'status = ? AND category = ?',
        whereArgs: ['approved', category],
        orderBy: 'created_at DESC',
        limit: 50,
      );
      return results.map((map) => Post.fromMap(map)).toList();
    }
  }

  /// Get popular hashtags (hashtags with most posts)
  Future<List<Map<String, dynamic>>> getPopularHashtags({
    int limit = 10,
  }) async {
    // This is better done with a custom RPC in Supabase,
    // but for demo we can fetch and process or fallback to local
    final db = await _db.database;

    // Get all approved posts with hashtags
    final results = await db.query(
      'posts',
      columns: ['hashtags'],
      where: 'status = ? AND hashtags IS NOT NULL AND hashtags != ?',
      whereArgs: ['approved', ''],
    );

    // Count hashtag occurrences
    final Map<String, int> hashtagCounts = {};
    for (final row in results) {
      final hashtagsStr = row['hashtags'] as String?;
      if (hashtagsStr != null && hashtagsStr.isNotEmpty) {
        final tags = hashtagsStr.split(',');
        for (final tag in tags) {
          if (tag.isNotEmpty) {
            hashtagCounts[tag] = (hashtagCounts[tag] ?? 0) + 1;
          }
        }
      }
    }

    // Sort by count and return top hashtags
    final sorted = hashtagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).map((entry) {
      return {'hashtag': entry.key, 'count': entry.value};
    }).toList();
  }

  /// Get trending posts (most liked in last 7 days)
  Future<List<Post>> getTrendingPosts({int limit = 10}) async {
    try {
      final sevenDaysAgo = DateTime.now()
          .subtract(const Duration(days: 7))
          .toIso8601String();

      final List<dynamic> response = await _supabase
          .from(_postsTable)
          .select()
          .eq('status', 'approved')
          .gte('created_at', sevenDaysAgo)
          .order('likes_count', ascending: false)
          .limit(limit);

      return response.map((data) => Post.fromMap(data)).toList();
    } catch (e) {
      final db = await _db.database;
      final sevenDaysAgoEpoch = DateTime.now()
          .subtract(const Duration(days: 7))
          .millisecondsSinceEpoch;

      final results = await db.query(
        'posts',
        where: 'status = ? AND created_at >= ?',
        whereArgs: ['approved', sevenDaysAgoEpoch],
        orderBy: 'likes_count DESC, created_at DESC',
        limit: limit,
      );

      return results.map((map) => Post.fromMap(map)).toList();
    }
  }
}
