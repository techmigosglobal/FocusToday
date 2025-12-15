import '../../../../shared/models/post.dart';
import '../../../../shared/models/user.dart';
import '../../../../core/services/database_service.dart';

/// Search Repository
/// Handles all search-related database queries
class SearchRepository {
  final DatabaseService _db = DatabaseService.instance;

  /// Search posts by caption or hashtags
  Future<List<Post>> searchPosts(String query) async {
    if (query.trim().isEmpty) return [];

    final db = await _db.database;
    final searchTerm = '%${query.toLowerCase()}%';

    final results = await db.rawQuery('''
      SELECT * FROM posts 
      WHERE status = 'approved' 
      AND (LOWER(caption) LIKE ? OR LOWER(hashtags) LIKE ?)
      ORDER BY created_at DESC
      LIMIT 50
    ''', [searchTerm, searchTerm]);

    return results.map((map) => Post.fromMap(map)).toList();
  }

  /// Search users by display name
  Future<List<User>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];

    final db = await _db.database;
    final searchTerm = '%${query.toLowerCase()}%';

    final results = await db.rawQuery('''
      SELECT * FROM users 
      WHERE LOWER(display_name) LIKE ? OR LOWER(phone_number) LIKE ?
      ORDER BY display_name ASC
      LIMIT 20
    ''', [searchTerm, searchTerm]);

    return results.map((map) => User.fromMap(map)).toList();
  }

  /// Get posts by specific hashtag
  Future<List<Post>> searchByHashtag(String hashtag) async {
    final db = await _db.database;
    final tag = hashtag.replaceAll('#', '').toLowerCase();

    final results = await db.rawQuery('''
      SELECT * FROM posts 
      WHERE status = 'approved' 
      AND LOWER(hashtags) LIKE ?
      ORDER BY created_at DESC
      LIMIT 50
    ''', ['%$tag%']);

    return results.map((map) => Post.fromMap(map)).toList();
  }

  /// Get posts by category
  Future<List<Post>> getPostsByCategory(String category) async {
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

  /// Get popular hashtags (hashtags with most posts)
  Future<List<Map<String, dynamic>>> getPopularHashtags({int limit = 10}) async {
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
      return {
        'hashtag': entry.key,
        'count': entry.value,
      };
    }).toList();
  }

  /// Get trending posts (most liked in last 7 days)
  Future<List<Post>> getTrendingPosts({int limit = 10}) async {
    final db = await _db.database;
    final sevenDaysAgo = DateTime.now()
        .subtract(const Duration(days: 7))
        .millisecondsSinceEpoch;

    final results = await db.query(
      'posts',
      where: 'status = ? AND created_at >= ?',
      whereArgs: ['approved', sevenDaysAgo],
      orderBy: 'likes_count DESC, created_at DESC',
      limit: limit,
    );

    return results.map((map) => Post.fromMap(map)).toList();
  }

  /// Get post count by category
  Future<int> getCategoryPostCount(String category) async {
    final db = await _db.database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM posts WHERE status = ? AND category = ?',
      ['approved', category],
    );

    return (result.first['count'] as int?) ?? 0;
  }

  /// Get all categories with post counts
  Future<Map<String, int>> getAllCategoryCounts() async {
    final categories = [
      'News',
      'Entertainment',
      'Sports',
      'Politics',
      'Technology',
      'Health',
      'Business',
      'Other',
    ];

    final Map<String, int> counts = {};
    for (final category in categories) {
      counts[category] = await getCategoryPostCount(category);
    }

    return counts;
  }
}
