import '../../../../shared/models/user.dart';
import '../../../../shared/models/post.dart';
import '../../../../core/services/database_service.dart';

/// Profile Repository
/// Manages user profile data and related operations
class ProfileRepository {
  final DatabaseService _db = DatabaseService.instance;

  /// Update user profile
  Future<void> updateProfile({
    required String userId,
    String? displayName,
    String? bio,
    String? profilePicture,
  }) async {
    final db = await _db.database;

    final Map<String, dynamic> updates = {};
    if (displayName != null) updates['display_name'] = displayName;
    if (bio != null) updates['bio'] = bio;
    if (profilePicture != null) updates['profile_picture'] = profilePicture;

    if (updates.isNotEmpty) {
      await db.update('users', updates, where: 'id = ?', whereArgs: [userId]);

      // Profile updated for user: $userId
    }
  }

  /// Get user by ID
  Future<User?> getUserById(String userId) async {
    final db = await _db.database;
    final results = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return User.fromMap(results.first);
  }

  /// Get user's posts count
  Future<int> getUserPostsCount(String userId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM posts WHERE author_id = ? AND status = ?',
      [userId, 'approved'],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Get user's all posts count (including pending for own profile)
  Future<int> getUserAllPostsCount(String userId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM posts WHERE author_id = ?',
      [userId],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Get user's posts
  Future<List<Post>> getUserPosts(
    String userId, {
    bool includeAll = false,
  }) async {
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

  /// Get user's bookmarked posts
  Future<List<Post>> getUserBookmarks(String userId) async {
    final db = await _db.database;

    // Join posts with user_interactions where is_bookmarked = 1
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

  /// Get user's bookmarks count
  Future<int> getUserBookmarksCount(String userId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM user_interactions WHERE user_id = ? AND is_bookmarked = 1',
      [userId],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Toggle bookmark on a post
  Future<void> toggleBookmark(String postId, String userId) async {
    final db = await _db.database;

    // Check if interaction exists
    final existing = await db.query(
      'user_interactions',
      where: 'user_id = ? AND post_id = ?',
      whereArgs: [userId, postId],
      limit: 1,
    );

    if (existing.isEmpty) {
      // Create new interaction
      await db.insert('user_interactions', {
        'id': '${userId}_$postId',
        'user_id': userId,
        'post_id': postId,
        'is_liked': 0,
        'is_bookmarked': 1,
        'interacted_at': DateTime.now().millisecondsSinceEpoch,
        'is_synced': 0,
      });

      // Update post bookmark count
      await db.rawUpdate(
        'UPDATE posts SET bookmarks_count = bookmarks_count + 1 WHERE id = ?',
        [postId],
      );
    } else {
      final isBookmarked = existing.first['is_bookmarked'] == 1;

      // Toggle bookmark
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

      // Update post bookmark count
      await db.rawUpdate(
        'UPDATE posts SET bookmarks_count = bookmarks_count + ? WHERE id = ?',
        [isBookmarked ? -1 : 1, postId],
      );
    }

    // Bookmark toggled for post: $postId
  }

  /// Check if post is bookmarked by user
  Future<bool> isPostBookmarked(String postId, String userId) async {
    final db = await _db.database;
    final results = await db.query(
      'user_interactions',
      where: 'user_id = ? AND post_id = ? AND is_bookmarked = 1',
      whereArgs: [userId, postId],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  /// Remove bookmark
  Future<void> removeBookmark(String postId, String userId) async {
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

    // Update post bookmark count
    await db.rawUpdate(
      'UPDATE posts SET bookmarks_count = bookmarks_count - 1 WHERE id = ?',
      [postId],
    );

    // Bookmark removed for post: $postId
  }
}
