import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/cloud_functions_service.dart';
import '../../../../shared/models/comment.dart';

/// Comment repository backed by Firestore.
class CommentRepository {
  /// Get comments for a post
  Future<List<Comment>> getComments(String postId) async {
    try {
      final snapshot = await FirestoreService.postComments(postId)
          .orderBy('created_at', descending: false)
          .limit(200)
          .get();
      return snapshot.docs.map((doc) {
        return _mapToComment({
          'id': doc.id,
          'post_id': postId,
          ...doc.data(),
        });
      }).toList();
    } catch (e) {
      debugPrint('[CommentRepo] getComments error: $e');
      return [];
    }
  }

  /// Add a comment via Cloud Function (server validates auth + sanitizes).
  Future<Comment> addComment({
    required String postId,
    required String authorId,
    required String authorName,
    String? authorAvatar,
    required String content,
  }) async {
    try {
      final result = await CloudFunctionsService.instance
          .httpsCallable('createComment')
          .call(<String, dynamic>{
        'postId': postId,
        'content': content,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      return Comment(
        id: data['id'] as String? ?? '',
        postId: postId,
        authorId: authorId,
        authorName: authorName,
        authorAvatar: authorAvatar,
        content: content,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[CommentRepo] addComment CF failed, falling back: $e');
      // Fallback: direct Firestore write.
      final now = DateTime.now();
      final ref = await FirestoreService.postComments(postId).add({
        'author_id': authorId,
        'author_name': authorName,
        'author_avatar': authorAvatar,
        'content': content,
        'likes_count': 0,
        'created_at': Timestamp.fromDate(now),
      });
      return Comment(
        id: ref.id,
        postId: postId,
        authorId: authorId,
        authorName: authorName,
        authorAvatar: authorAvatar,
        content: content,
        createdAt: now,
      );
    }
  }

  /// Get replies for a specific comment
  Future<List<Comment>> getReplies(String postId, String commentId) async {
    try {
      final snapshot = await FirestoreService.commentReplies(postId, commentId)
          .orderBy('created_at', descending: false)
          .limit(50)
          .get();
      return snapshot.docs.map((doc) {
        return _mapToComment({
          'id': doc.id,
          'post_id': postId,
          ...doc.data(),
        });
      }).toList();
    } catch (e) {
      debugPrint('[CommentRepo] getReplies error: $e');
      return [];
    }
  }

  /// Add a reply to a comment
  Future<Comment> addReply({
    required String postId,
    required String commentId,
    required String authorId,
    required String authorName,
    String? authorAvatar,
    required String content,
  }) async {
    try {
      final now = DateTime.now();
      
      // Update comment reply count
      await FirestoreService.postComments(postId)
          .doc(commentId)
          .update({'reply_count': FieldValue.increment(1)});
          
      final ref = await FirestoreService.commentReplies(postId, commentId).add({
        'author_id': authorId,
        'author_name': authorName,
        'author_avatar': authorAvatar,
        'content': content,
        'likes_count': 0,
        'created_at': Timestamp.fromDate(now),
      });

      return Comment(
        id: ref.id,
        postId: postId,
        authorId: authorId,
        authorName: authorName,
        authorAvatar: authorAvatar,
        content: content,
        createdAt: now,
      );
    } catch (e) {
      debugPrint('[CommentRepo] addReply error: $e');
      rethrow;
    }
  }

  /// Delete a comment
  Future<void> deleteComment(String commentId, String postId) async {
    try {
      await FirestoreService.postComments(postId).doc(commentId).delete();
    } catch (e) {
      debugPrint('[CommentRepo] deleteComment error: $e');
    }
  }

  /// Get comments count for a post
  Future<int> getCommentsCount(String postId) async {
    try {
      final snapshot = await FirestoreService.postComments(postId).count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('[CommentRepo] getCommentsCount error: $e');
      return 0;
    }
  }

  // ==================== HELPERS ====================

  Comment _mapToComment(Map<String, dynamic> row) {
    return Comment(
      id: row['id'] ?? '',
      postId: row['post_id'] ?? '',
      authorId: row['author_id'] ?? '',
      authorName: row['author_name'] ?? 'Unknown',
      authorAvatar: row['author_avatar'],
      content: row['content'] ?? '',
      createdAt: FirestoreService.toDateTime(row['created_at']),
      likesCount: row['likes_count'] is int
          ? row['likes_count']
          : int.tryParse(row['likes_count']?.toString() ?? '0') ?? 0,
      replyCount: row['reply_count'] is int
          ? row['reply_count']
          : int.tryParse(row['reply_count']?.toString() ?? '0') ?? 0,
    );
  }
}
