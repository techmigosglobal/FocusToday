import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/models/post.dart';
import '../../../../core/services/database_service.dart';

/// Post Repository
/// Manages post CRUD operations and queries
class PostRepository {
  final DatabaseService _db = DatabaseService.instance;

  /// Create a new post
  Future<String> createPost({
    required String authorId,
    required String authorName,
    String? authorAvatar,
    required String caption,
    String? mediaUrl,
    ContentType contentType = ContentType.none,
    required String category,
    PostStatus status = PostStatus.pending,
  }) async {
    const uuid = Uuid();
    final postId = uuid.v4();
    final now = DateTime.now();

    final post = Post(
      id: postId,
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      caption: caption,
      mediaUrl: mediaUrl,
      contentType: contentType,
      category: category,
      hashtags: Post.extractHashtags(caption),
      status: status,
      createdAt: now,
      publishedAt: now,
      isSynced: false, // Will sync to backend later
    );

    final db = await _db.database;
    await db.insert(
      'posts',
      post.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Post created: $postId
    return postId;
  }

  /// Get posts by status
  Future<List<Post>> getPostsByStatus(PostStatus status) async {
    final db = await _db.database;
    final results = await db.query(
      'posts',
      where: 'status = ?',
      whereArgs: [status.toStr()],
      orderBy: 'created_at DESC',
    );

    return results.map((map) => Post.fromMap(map)).toList();
  }

  /// Get all approved posts
  Future<List<Post>> getApprovedPosts({int? limit}) async {
    final db = await _db.database;
    final results = await db.query(
      'posts',
      where: 'status = ?',
      whereArgs: ['approved'],
      orderBy: 'published_at DESC',
      limit: limit,
    );

    return results.map((map) => Post.fromMap(map)).toList();
  }

  /// Get posts by author
  Future<List<Post>> getPostsByAuthor(String authorId) async {
    final db = await _db.database;
    final results = await db.query(
      'posts',
      where: 'author_id = ?',
      whereArgs: [authorId],
      orderBy: 'created_at DESC',
    );

    return results.map((map) => Post.fromMap(map)).toList();
  }

  /// Update post status
  Future<void> updatePostStatus({
    required String postId,
    required PostStatus status,
    String? rejectionReason,
  }) async {
    final db = await _db.database;

    final updates = <String, dynamic>{'status': status.toStr()};

    if (status == PostStatus.approved) {
      updates['published_at'] = DateTime.now().millisecondsSinceEpoch;
    }

    if (rejectionReason != null) {
      updates['rejection_reason'] = rejectionReason;
    }

    await db.update('posts', updates, where: 'id = ?', whereArgs: [postId]);

    // Post $postId updated to ${status.toStr()}
  }

  /// Delete post
  Future<void> deletePost(String postId) async {
    final db = await _db.database;
    await db.delete('posts', where: 'id = ?', whereArgs: [postId]);
    // Post deleted: $postId
  }

  /// Get post by ID
  Future<Post?> getPostById(String postId) async {
    final db = await _db.database;
    final results = await db.query(
      'posts',
      where: 'id = ?',
      whereArgs: [postId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return Post.fromMap(results.first);
  }

  /// Get pending posts count
  Future<int> getPendingPostsCount() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM posts WHERE status = ?',
      ['pending'],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
