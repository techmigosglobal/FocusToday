import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/models/post.dart';
import '../../../../core/services/database_service.dart';

/// Post Repository
/// Manages post CRUD operations using Supabase Database and Storage
class PostRepository {
  final DatabaseService _db = DatabaseService.instance;
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _tableName = 'posts';
  static const String _bucketName = 'media';

  /// Upload media to Supabase Storage
  /// Returns the public download URL
  Future<String> uploadMedia(String filePath, String destination) async {
    final file = File(filePath);

    // Validate file exists
    if (!file.existsSync()) {
      throw Exception('File does not exist: $filePath');
    }

    try {
      // Upload to Supabase Storage
      await _supabase.storage
          .from(_bucketName)
          .upload(
            destination,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      // Get public URL
      return _supabase.storage.from(_bucketName).getPublicUrl(destination);
    } catch (e) {
      throw Exception('Failed to upload media to Supabase: $e');
    }
  }

  /// Create a new post
  Future<String> createPost({
    required String authorId,
    required String authorName,
    String? authorAvatar,
    required String caption,
    String? captionTe,
    String? captionHi,
    String? mediaUrl,
    ContentType contentType = ContentType.none,
    required String category,
    PostStatus status = PostStatus.pending,
    String? pdfFilePath,
    String? articleContent,
    List<String>? poemVerses,
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
      captionTe: captionTe,
      captionHi: captionHi,
      mediaUrl: mediaUrl,
      contentType: contentType,
      category: category,
      hashtags: Post.extractHashtags(caption),
      status: status,
      createdAt: now,
      publishedAt: now,
      pdfFilePath: pdfFilePath,
      articleContent: articleContent,
      poemVerses: poemVerses,
      isSynced: true,
    );

    // 1. Save to Supabase Database
    await _supabase.from(_tableName).insert(post.toMap());

    // 2. Save to local database for offline access
    final db = await _db.database;
    await db.insert(
      'posts',
      post.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return postId;
  }

  /// Get approved posts from Supabase
  Future<List<Post>> getApprovedPosts({int? limit}) async {
    try {
      var query = _supabase
          .from(_tableName)
          .select()
          .eq('status', 'approved')
          .order('published_at', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      final List<dynamic> response = await query;
      final posts = response.map((data) => Post.fromMap(data)).toList();

      // Update local database
      final db = await _db.database;
      for (var post in posts) {
        await db.insert(
          'posts',
          post.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      return posts;
    } catch (e) {
      // Fallback to local
      return await _getLocalApprovedPosts(limit: limit);
    }
  }

  Future<List<Post>> _getLocalApprovedPosts({int? limit}) async {
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

  /// Get posts by author from Supabase
  Future<List<Post>> getPostsByAuthor(String authorId) async {
    try {
      final List<dynamic> response = await _supabase
          .from(_tableName)
          .select()
          .eq('author_id', authorId)
          .order('created_at', ascending: false);

      return response.map((data) => Post.fromMap(data)).toList();
    } catch (e) {
      // Fallback to local
      final db = await _db.database;
      final results = await db.query(
        'posts',
        where: 'author_id = ?',
        whereArgs: [authorId],
        orderBy: 'created_at DESC',
      );
      return results.map((map) => Post.fromMap(map)).toList();
    }
  }

  /// Get posts by status from Supabase
  Future<List<Post>> getPostsByStatus(PostStatus status) async {
    try {
      final List<dynamic> response = await _supabase
          .from(_tableName)
          .select()
          .eq('status', status.toStr())
          .order('created_at', ascending: false);

      return response.map((data) => Post.fromMap(data)).toList();
    } catch (e) {
      // Fallback to local
      final db = await _db.database;
      final results = await db.query(
        'posts',
        where: 'status = ?',
        whereArgs: [status.toStr()],
        orderBy: 'created_at DESC',
      );
      return results.map((map) => Post.fromMap(map)).toList();
    }
  }

  /// Update post status in Supabase
  Future<void> updatePostStatus({
    required String postId,
    required PostStatus status,
    String? rejectionReason,
  }) async {
    final updates = <String, dynamic>{'status': status.toStr()};

    if (status == PostStatus.approved) {
      updates['published_at'] = DateTime.now().millisecondsSinceEpoch;
    }

    if (rejectionReason != null) {
      updates['rejection_reason'] = rejectionReason;
    }

    // 1. Update Supabase
    await _supabase.from(_tableName).update(updates).eq('id', postId);

    // 2. Update local
    final db = await _db.database;
    await db.update('posts', updates, where: 'id = ?', whereArgs: [postId]);
  }

  /// Delete post from Supabase Database and Storage
  Future<void> deletePost(String postId) async {
    // 1. Get post to find media path
    final post = await getPostById(postId);

    // 2. Delete media from Supabase Storage if exists
    if (post?.mediaUrl != null && post!.mediaUrl!.contains('supabase')) {
      try {
        // Extract path from public URL
        final path = post.mediaUrl!.split('/').last;
        await _supabase.storage.from(_bucketName).remove([path]);
      } catch (_) {}
    }

    if (post?.pdfFilePath != null && post!.pdfFilePath!.contains('supabase')) {
      try {
        final path = post.pdfFilePath!.split('/').last;
        await _supabase.storage.from(_bucketName).remove([path]);
      } catch (_) {}
    }

    // 3. Delete from Supabase Database
    await _supabase.from(_tableName).delete().eq('id', postId);

    // 4. Delete from local
    final db = await _db.database;
    await db.delete('posts', where: 'id = ?', whereArgs: [postId]);
  }

  /// Get post by ID from Supabase
  Future<Post?> getPostById(String postId) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('id', postId)
          .single();

      return Post.fromMap(response);
    } catch (e) {
      // Fallback to local
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
  }

  /// Get pending posts count from Supabase
  Future<int> getPendingPostsCount() async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('id')
          .eq('status', 'pending');

      return (response as List).length;
    } catch (e) {
      // Fallback to local
      final db = await _db.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM posts WHERE status = ?',
        ['pending'],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    }
  }
}
