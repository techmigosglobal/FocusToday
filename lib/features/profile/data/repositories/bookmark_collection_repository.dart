import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/services/firestore_service.dart';
import '../../../../shared/models/post.dart';

/// A named bookmark collection belonging to a user.
class BookmarkCollection {
  final String id;
  final String name;
  final String? description;
  final int itemCount;
  final DateTime? createdAt;

  const BookmarkCollection({
    required this.id,
    required this.name,
    this.description,
    this.itemCount = 0,
    this.createdAt,
  });

  factory BookmarkCollection.fromJson(String id, Map<String, dynamic> json) {
    return BookmarkCollection(
      id: id,
      name: json['name'] ?? '',
      description: json['description'],
      itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] is Timestamp
          ? (json['created_at'] as Timestamp).toDate()
          : DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

/// Repository for managing named bookmark collections (GAP-006).
/// Data path: users/{uid}/bookmark_collections/{collId}/items/{postId}
class BookmarkCollectionRepository {
  // ─── Collections CRUD ────────────────────────────────────────────────────

  Future<List<BookmarkCollection>> getCollections(String userId) async {
    try {
      final snap = await FirestoreService.userBookmarkCollections(userId)
          .orderBy('created_at', descending: true)
          .limit(100)
          .get();
      return snap.docs
          .map((d) => BookmarkCollection.fromJson(d.id, d.data()))
          .toList(growable: false);
    } catch (e) {
      debugPrint('[BookmarkCollRepo] getCollections error: $e');
      return [];
    }
  }

  Future<String?> createCollection(
    String userId, {
    required String name,
    String? description,
  }) async {
    try {
      final ref = FirestoreService.userBookmarkCollections(userId).doc();
      await ref.set({
        'name': name.trim(),
        'description': description?.trim(),
        'item_count': 0,
        'created_at': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (e) {
      debugPrint('[BookmarkCollRepo] createCollection error: $e');
      return null;
    }
  }

  Future<bool> deleteCollection(String userId, String collId) async {
    try {
      // Delete items subcollection in batches first
      final items = await FirestoreService.userBookmarkCollectionItems(
        userId,
        collId,
      ).limit(500).get();
      if (items.docs.isNotEmpty) {
        final batch = FirestoreService.db.batch();
        for (final doc in items.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
      await FirestoreService.userBookmarkCollections(userId)
          .doc(collId)
          .delete();
      return true;
    } catch (e) {
      debugPrint('[BookmarkCollRepo] deleteCollection error: $e');
      return false;
    }
  }

  Future<bool> renameCollection(
    String userId,
    String collId, {
    required String name,
    String? description,
  }) async {
    try {
      await FirestoreService.userBookmarkCollections(userId).doc(collId).update(
        {
          'name': name.trim(),
          if (description != null) 'description': description.trim(),
        },
      );
      return true;
    } catch (e) {
      debugPrint('[BookmarkCollRepo] renameCollection error: $e');
      return false;
    }
  }

  // ─── Items CRUD ──────────────────────────────────────────────────────────

  Future<List<String>> getPostIdsInCollection(
    String userId,
    String collId,
  ) async {
    try {
      final snap = await FirestoreService.userBookmarkCollectionItems(
        userId,
        collId,
      ).orderBy('added_at', descending: true).limit(500).get();
      return snap.docs.map((d) => d.id).toList(growable: false);
    } catch (e) {
      debugPrint('[BookmarkCollRepo] getPostIds error: $e');
      return [];
    }
  }

  Future<bool> addToCollection(
    String userId,
    String collId,
    Post post,
  ) async {
    try {
      final itemRef = FirestoreService.userBookmarkCollectionItems(
        userId,
        collId,
      ).doc(post.id);
      await FirestoreService.db.runTransaction((tx) async {
        final exists = await tx.get(itemRef);
        if (exists.exists) return; // Already in collection
        tx.set(itemRef, {
          'post_id': post.id,
          'caption_snippet': post.caption.length > 100
              ? post.caption.substring(0, 100)
              : post.caption,
          'added_at': FieldValue.serverTimestamp(),
        });
        tx.update(
          FirestoreService.userBookmarkCollections(userId).doc(collId),
          {'item_count': FieldValue.increment(1)},
        );
      });
      return true;
    } catch (e) {
      debugPrint('[BookmarkCollRepo] addToCollection error: $e');
      return false;
    }
  }

  Future<bool> removeFromCollection(
    String userId,
    String collId,
    String postId,
  ) async {
    try {
      final itemRef = FirestoreService.userBookmarkCollectionItems(
        userId,
        collId,
      ).doc(postId);
      await FirestoreService.db.runTransaction((tx) async {
        final exists = await tx.get(itemRef);
        if (!exists.exists) return;
        tx.delete(itemRef);
        tx.update(
          FirestoreService.userBookmarkCollections(userId).doc(collId),
          {'item_count': FieldValue.increment(-1)},
        );
      });
      return true;
    } catch (e) {
      debugPrint('[BookmarkCollRepo] removeFromCollection error: $e');
      return false;
    }
  }

  Future<bool> isPostInCollection(
    String userId,
    String collId,
    String postId,
  ) async {
    try {
      final doc = await FirestoreService.userBookmarkCollectionItems(
        userId,
        collId,
      ).doc(postId).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }
}
