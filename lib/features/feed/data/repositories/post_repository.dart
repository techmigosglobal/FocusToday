import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/services/cache_service.dart';
import '../../../../core/services/cloud_functions_service.dart';
import '../../../../core/config/feature_flags.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/post_translation_service.dart';
import '../../../../core/services/post_sync_service.dart';
import '../../../../shared/models/post.dart';

class PostRepository {
  static Future<int>? _pendingCountInFlight;
  static final Map<String, Future<List<Post>>> _approvedFeedInFlight = {};
  static const String _defaultRejectionReason = 'Policy violation';

  /// Last document snapshot used for cursor-based pagination.
  DocumentSnapshot? _lastFeedDoc;

  /// Whether the last feed fetch returned fewer results than the page size,
  /// meaning there are no more pages to load.
  bool _feedExhausted = false;

  /// Number of posts per page.
  static const int feedPageSize = 20;
  static const int _parallelMapMinRows = 30;
  static const int _parallelMaxWorkers = 4;

  /// Whether there are more feed pages to load.
  bool get hasMoreFeedPages => !_feedExhausted;

  /// Reset pagination state (e.g. on pull-to-refresh).
  void resetPagination() {
    _lastFeedDoc = null;
    _feedExhausted = false;
  }

  Future<List<Post>> getApprovedPosts() async {
    return getApprovedPostsWithInteractions('', forceRefresh: false);
  }

  Future<List<Post>> getApprovedPostsWithInteractions(
    String userId, {
    bool forceRefresh = false,
    int? initialFetchLimit,
  }) async {
    final effectiveLimit = (initialFetchLimit ?? feedPageSize).clamp(
      1,
      feedPageSize,
    );

    // Full refresh resets pagination.
    resetPagination();

    final cacheKey = effectiveLimit == feedPageSize
        ? 'feed_$userId'
        : 'feed_${userId}_limit_$effectiveLimit';
    if (!forceRefresh) {
      final cached = CacheService.get(
        cacheKey,
        maxAge: const Duration(seconds: 20),
      );
      if (cached is List) {
        final parsed = cached
            .whereType<Map>()
            .map(
              (e) => _mapToPost(Map<String, dynamic>.from(e), userId: userId),
            )
            .toList();
        if (parsed.isNotEmpty) return parsed;
      }
    }

    final inFlightKey = '$userId|$forceRefresh|$effectiveLimit';
    final existing = _approvedFeedInFlight[inFlightKey];
    if (existing != null) return existing;

    final future = _fetchApprovedPostsWithInteractions(
      userId: userId,
      cacheKey: cacheKey,
      effectiveLimit: effectiveLimit,
    );
    _approvedFeedInFlight[inFlightKey] = future;
    try {
      return await future;
    } finally {
      if (identical(_approvedFeedInFlight[inFlightKey], future)) {
        _approvedFeedInFlight.remove(inFlightKey);
      }
    }
  }

  Future<List<Post>> _fetchApprovedPostsWithInteractions({
    required String userId,
    required String cacheKey,
    required int effectiveLimit,
  }) async {
    try {
      // News feed contract:
      // only approved posts are visible here. Pending/rejected posts remain
      // in moderation queues until backend moderation updates status.
      final snapshot = await FirestoreService.posts
          .where('status', isEqualTo: 'approved')
          .orderBy('published_at', descending: true)
          .limit(effectiveLimit)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _lastFeedDoc = snapshot.docs.last;
      }
      _feedExhausted = snapshot.docs.length < effectiveLimit;

      final rows = snapshot.docs
          .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
          .toList(growable: false);
      final preparedRows = await _prepareRowsForMapping(rows);
      final posts = userId.isEmpty
          ? preparedRows.map(_mapToPost).toList(growable: false)
          : await Future.wait(
              preparedRows.map((row) => _mapToPostWithInteraction(row, userId)),
            );

      await CacheService.set(
        cacheKey,
        posts.map((e) => _toCacheRow(e)).toList(growable: false),
      );
      return posts;
    } catch (e) {
      debugPrint('[PostRepo] getApprovedPostsWithInteractions error: $e');
      return [];
    }
  }

  /// Load the next page of approved posts (cursor-based pagination).
  Future<List<Post>> loadMoreApprovedPosts(String userId) async {
    if (_feedExhausted || _lastFeedDoc == null) return [];

    try {
      final snapshot = await FirestoreService.posts
          .where('status', isEqualTo: 'approved')
          .orderBy('published_at', descending: true)
          .startAfterDocument(_lastFeedDoc!)
          .limit(feedPageSize)
          .get();

      if (snapshot.docs.isEmpty) {
        _feedExhausted = true;
        return [];
      }

      _lastFeedDoc = snapshot.docs.last;
      _feedExhausted = snapshot.docs.length < feedPageSize;

      final rows = snapshot.docs
          .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
          .toList(growable: false);
      final preparedRows = await _prepareRowsForMapping(rows);
      final posts = userId.isEmpty
          ? preparedRows.map(_mapToPost).toList(growable: false)
          : await Future.wait(
              preparedRows.map((row) => _mapToPostWithInteraction(row, userId)),
            );

      return posts;
    } catch (e) {
      debugPrint('[PostRepo] loadMoreApprovedPosts error: $e');
      return [];
    }
  }

  Future<List<Post>> getPostsByStatus(PostStatus status) async {
    try {
      final snapshot = await FirestoreService.posts
          .where('status', isEqualTo: status.toStr())
          .orderBy('created_at', descending: true)
          .limit(200)
          .get();

      final rows = snapshot.docs
          .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
          .toList(growable: false);
      final preparedRows = await _prepareRowsForMapping(rows);
      return preparedRows.map(_mapToPost).toList();
    } catch (e) {
      debugPrint('[PostRepo] getPostsByStatus error: $e');
      return [];
    }
  }

  Future<CreatePostResult> createPost({
    required String authorId,
    required String authorName,
    String? authorRole,
    String? authorAvatar,
    required String caption,
    List<dynamic>? captionDelta,
    String? mediaUrl,
    required ContentType contentType,
    required String category,
    required PostStatus status,
    String? pdfFilePath,
    String? articleContent,
    List<dynamic>? articleContentDelta,
    List<String>? poemVerses,
  }) async {
    try {
      // Route through Cloud Function for server-side role validation.
      final payload = <String, dynamic>{
        'caption': caption,
        'contentType': contentType.toStr(),
        'category': category,
      };
      if (mediaUrl != null) payload['mediaUrl'] = mediaUrl;
      if (articleContent != null) payload['articleContent'] = articleContent;
      if (captionDelta != null) payload['captionDelta'] = captionDelta;
      if (articleContentDelta != null) {
        payload['articleContentDelta'] = articleContentDelta;
      }
      if (poemVerses != null) payload['poemVerses'] = poemVerses;

      final result = await CloudFunctionsService.instance
          .httpsCallable('createPost')
          .call(payload);
      final data = Map<String, dynamic>.from(result.data as Map);
      final postId = data['id'] as String? ?? '';
      final translationStatus =
          (data['translation_status'] as String?)?.trim().isNotEmpty == true
          ? (data['translation_status'] as String).trim()
          : 'ready';

      if (postId.isNotEmpty) {
        unawaited(
          _persistOnDeviceTranslationsForPost(
            postId: postId,
            caption: caption,
            articleContent: articleContent,
            poemVerses: poemVerses,
          ),
        );
      }
      await _invalidatePostCaches();
      PostSyncService.notify(
        reason: PostSyncReason.created,
        postId: postId,
        authorId: authorId,
      );
      return CreatePostResult(
        postId: postId,
        translationStatus: translationStatus,
        usedCloudFunction: true,
      );
    } catch (e) {
      debugPrint(
        '[PostRepo] createPost CF failed, falling back to direct write: $e',
      );
    }

    // Fallback: direct Firestore write (e.g. when CF is unreachable).
    final doc = FirestoreService.posts.doc();
    final now = DateTime.now();
    final translatedFields = await _buildOnDeviceTranslationFields(
      caption: caption,
      articleContent: articleContent,
      poemVerses: poemVerses,
    );
    final normalizedAuthorRole = _normalizeAuthorRole(authorRole);
    final canonicalAuthorName = _canonicalAuthorNameForWrite(
      normalizedAuthorRole,
      authorName,
    );
    await doc.set({
      'author_id': authorId,
      'author_role': normalizedAuthorRole,
      'author_name': canonicalAuthorName,
      'author_avatar': authorAvatar,
      'caption': caption,
      'caption_delta': captionDelta,
      'media_url': mediaUrl,
      'content_type': contentType.toStr(),
      'category': category,
      'hashtags': Post.extractHashtags(caption),
      'status': status.toStr(),
      'pdf_file_path': pdfFilePath,
      'article_content': articleContent,
      'article_content_delta': articleContentDelta,
      'poem_verses': poemVerses,
      'likes_count': 0,
      'bookmarks_count': 0,
      'shares_count': 0,
      'impressions_count': 0,
      'edit_count': 0,
      'created_at': Timestamp.fromDate(now),
      'published_at': Timestamp.fromDate(now),
      'updated_at': Timestamp.fromDate(now),
      'verification': {'verified_source': false, 'source_label': null},
      ...translatedFields,
      'translation_meta': translatedFields.isEmpty
          ? {'provider': 'none_client_fallback', 'status': 'pending_async_fill'}
          : {
              'provider': 'mlkit_on_device',
              'status': 'ready',
              'translated_at': FieldValue.serverTimestamp(),
            },
      'moderation_meta': {
        'sla_hours': 24,
        'status_note': status == PostStatus.pending
            ? 'Awaiting review'
            : 'Published',
      },
    });

    await _invalidatePostCaches();
    PostSyncService.notify(
      reason: PostSyncReason.created,
      postId: doc.id,
      authorId: authorId,
    );
    return CreatePostResult(
      postId: doc.id,
      translationStatus: 'pending_async_fill',
      usedCloudFunction: false,
    );
  }

  Future<void> updatePost({
    required String postId,
    String? caption,
    List<dynamic>? captionDelta,
    String? category,
    String? mediaUrl,
    ContentType? contentType,
    String? articleContent,
    List<dynamic>? articleContentDelta,
    String? authorId,
  }) async {
    final translatedFields = await _buildOnDeviceTranslationFields(
      caption: caption ?? '',
      articleContent: articleContent,
      poemVerses: null,
    );
    final data = <String, dynamic>{
      'updated_at': FieldValue.serverTimestamp(),
      'last_edited_at': FieldValue.serverTimestamp(),
      'edit_count': FieldValue.increment(1),
      ...translatedFields,
      'translation_meta': translatedFields.isEmpty
          ? {
              'provider': 'none_client_update',
              'status': 'pending_async_fill',
              'requested_at': FieldValue.serverTimestamp(),
            }
          : {
              'provider': 'mlkit_on_device',
              'status': 'ready',
              'translated_at': FieldValue.serverTimestamp(),
            },
    };
    if (caption != null) {
      data['caption'] = caption;
      data['hashtags'] = Post.extractHashtags(caption);
    }
    if (captionDelta != null) data['caption_delta'] = captionDelta;
    if (category != null) data['category'] = category;
    if (mediaUrl != null) data['media_url'] = mediaUrl;
    if (contentType != null) data['content_type'] = contentType.toStr();
    if (articleContent != null) data['article_content'] = articleContent;
    if (articleContentDelta != null) {
      data['article_content_delta'] = articleContentDelta;
    }

    await FirestoreService.posts.doc(postId).set(data, SetOptions(merge: true));
    debugPrint(
      '[PostRepo] updatePost postId=$postId translationStatus=pending_async_fill',
    );
    await _invalidatePostCaches();
    PostSyncService.notify(
      reason: PostSyncReason.updated,
      postId: postId,
      authorId: authorId,
    );
  }

  Future<void> updatePostStatus({
    required String postId,
    required PostStatus status,
    String? rejectionReason,
    String? authorId,
  }) async {
    final normalizedReason = rejectionReason?.trim() ?? '';
    if (FeatureFlags.roleManagementCallableEnabled) {
      final payload = <String, dynamic>{
        'postId': postId,
        'status': status.toStr(),
      };
      if (status == PostStatus.rejected) {
        payload['rejectionReason'] = normalizedReason.isNotEmpty
            ? normalizedReason
            : _defaultRejectionReason;
      } else if (normalizedReason.isNotEmpty) {
        payload['rejectionReason'] = normalizedReason;
      }

      await CloudFunctionsService.instance
          .httpsCallable('moderatePost')
          .call(payload);
    } else {
      await FirestoreService.posts.doc(postId).set({
        'status': status.toStr(),
        if (status == PostStatus.rejected)
          'rejection_reason': normalizedReason.isNotEmpty
              ? normalizedReason
              : _defaultRejectionReason
        else if (normalizedReason.isNotEmpty)
          'rejection_reason': normalizedReason
        else
          'rejection_reason': null,
        'updated_at': FieldValue.serverTimestamp(),
        'moderated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await _invalidatePostCaches();
    PostSyncService.notify(
      reason: PostSyncReason.statusChanged,
      postId: postId,
      authorId: authorId,
    );
  }

  Future<bool> resubmitPost({
    required String postId,
    String? caption,
    List<dynamic>? captionDelta,
    String? category,
    String? mediaUrl,
    ContentType? contentType,
    String? articleContent,
    List<dynamic>? articleContentDelta,
    String? authorId,
  }) async {
    try {
      final translatedFields = await _buildOnDeviceTranslationFields(
        caption: caption ?? '',
        articleContent: articleContent,
        poemVerses: null,
      );
      final data = <String, dynamic>{
        'status': PostStatus.pending.toStr(),
        'rejection_reason': null,
        'updated_at': FieldValue.serverTimestamp(),
        'last_edited_at': FieldValue.serverTimestamp(),
        'edit_count': FieldValue.increment(1),
        ...translatedFields,
        'translation_meta': translatedFields.isEmpty
            ? {
                'provider': 'none_client_update',
                'status': 'pending_async_fill',
                'requested_at': FieldValue.serverTimestamp(),
              }
            : {
                'provider': 'mlkit_on_device',
                'status': 'ready',
                'translated_at': FieldValue.serverTimestamp(),
              },
      };
      if (caption != null) {
        data['caption'] = caption;
        data['hashtags'] = Post.extractHashtags(caption);
      }
      if (captionDelta != null) data['caption_delta'] = captionDelta;
      if (category != null) data['category'] = category;
      if (mediaUrl != null) data['media_url'] = mediaUrl;
      if (contentType != null) data['content_type'] = contentType.toStr();
      if (articleContent != null) data['article_content'] = articleContent;
      if (articleContentDelta != null) {
        data['article_content_delta'] = articleContentDelta;
      }

      await FirestoreService.posts
          .doc(postId)
          .set(data, SetOptions(merge: true));
      debugPrint(
        '[PostRepo] resubmitPost postId=$postId translationStatus=pending_async_fill',
      );
      await _invalidatePostCaches();
      PostSyncService.notify(
        reason: PostSyncReason.resubmitted,
        postId: postId,
        authorId: authorId,
      );
      return true;
    } catch (e) {
      debugPrint('[PostRepo] resubmitPost error: $e');
      return false;
    }
  }

  Future<List<Post>> getRejectedPostsByAuthor(String authorId) async {
    try {
      final snapshot = await FirestoreService.posts
          .where('author_id', isEqualTo: authorId)
          .where('status', isEqualTo: PostStatus.rejected.toStr())
          .orderBy('updated_at', descending: true)
          .limit(100)
          .get();
      return snapshot.docs
          .map((d) => _mapToPost({'id': d.id, ...d.data()}))
          .toList();
    } catch (e) {
      debugPrint('[PostRepo] getRejectedPostsByAuthor error: $e');
      return [];
    }
  }

  Future<String?> uploadMedia(
    String filePath,
    String destination, {
    required String userId,
    int maxSizeMB = 50,
    List<String>? allowedExtensions,
    void Function(int, int)? onSendProgress,
  }) async {
    try {
      final file = File(filePath);
      final sizeMb = await file.length() / (1024 * 1024);
      if (sizeMb > maxSizeMB) {
        throw Exception('File too large ($sizeMb MB > $maxSizeMB MB)');
      }
      final ext = file.path.split('.').last.toLowerCase();
      if (allowedExtensions != null &&
          allowedExtensions.isNotEmpty &&
          !allowedExtensions.contains(ext)) {
        throw Exception('Unsupported file extension: .$ext');
      }

      final path =
          'posts/$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final task = FirebaseStorage.instance.ref(path).putFile(file);
      task.snapshotEvents.listen((event) {
        final total = event.totalBytes == 0 ? 1 : event.totalBytes;
        onSendProgress?.call(event.bytesTransferred, total);
      });
      await task;
      return FirebaseStorage.instance.ref(path).getDownloadURL();
    } catch (e) {
      debugPrint('[PostRepo] uploadMedia error: $e');
      return null;
    }
  }

  Future<ToggleInteractionResult> toggleLike(
    String postId,
    String userId,
  ) async {
    try {
      if (FeatureFlags.interactionCallableEnabled) {
        final result = await CloudFunctionsService.instance
            .httpsCallable('togglePostInteraction')
            .call(<String, dynamic>{'postId': postId, 'type': 'like'});
        final data = Map<String, dynamic>.from(result.data as Map);
        final isActive = data['active'] == true;
        final post = await FirestoreService.posts.doc(postId).get();
        final count = _toInt(post.data()?['likes_count']);
        await _invalidateFeedCaches();
        PostSyncService.notify(
          reason: PostSyncReason.interactionChanged,
          postId: postId,
        );
        return ToggleInteractionResult(
          success: true,
          isActive: isActive,
          count: count,
        );
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[PostRepo] toggleLike CF error: $e');
    } catch (e) {
      debugPrint('[PostRepo] toggleLike callable error: $e');
    }

    // Low-cost fallback: transaction-based toggle directly in Firestore.
    try {
      final postRef = FirestoreService.posts.doc(postId);
      final interactionRef = FirestoreService.postInteractions(
        postId,
      ).doc(userId);
      final isActive = await FirestoreService.db.runTransaction((tx) async {
        final interactionSnap = await tx.get(interactionRef);
        final currentlyActive = interactionSnap.data()?['liked'] == true;
        final next = !currentlyActive;
        tx.set(interactionRef, {
          'user_id': userId,
          'liked': next,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        tx.set(postRef, {
          'likes_count': FieldValue.increment(next ? 1 : -1),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return next;
      });
      final post = await postRef.get();
      final count = _toInt(post.data()?['likes_count']);
      await _invalidateFeedCaches();
      PostSyncService.notify(
        reason: PostSyncReason.interactionChanged,
        postId: postId,
      );
      return ToggleInteractionResult(
        success: true,
        isActive: isActive,
        count: count,
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[PostRepo] toggleLike fallback CF error: $e');
      return const ToggleInteractionResult(success: false);
    } catch (e) {
      debugPrint('[PostRepo] toggleLike fallback error: $e');
      return const ToggleInteractionResult(success: false);
    }
  }

  Future<ToggleInteractionResult> toggleBookmark(
    String postId,
    String userId,
  ) async {
    try {
      if (FeatureFlags.interactionCallableEnabled) {
        final result = await CloudFunctionsService.instance
            .httpsCallable('togglePostInteraction')
            .call(<String, dynamic>{'postId': postId, 'type': 'bookmark'});
        final data = Map<String, dynamic>.from(result.data as Map);
        final isActive = data['active'] == true;
        final post = await FirestoreService.posts.doc(postId).get();
        final count = _toInt(post.data()?['bookmarks_count']);
        await _invalidateFeedCaches();
        await CacheService.invalidate('bookmarks_$userId');
        PostSyncService.notify(
          reason: PostSyncReason.interactionChanged,
          postId: postId,
        );
        return ToggleInteractionResult(
          success: true,
          isActive: isActive,
          count: count,
        );
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[PostRepo] toggleBookmark CF error: $e');
    } catch (e) {
      debugPrint('[PostRepo] toggleBookmark callable error: $e');
    }

    try {
      final postRef = FirestoreService.posts.doc(postId);
      final interactionRef = FirestoreService.postInteractions(
        postId,
      ).doc(userId);
      final isActive = await FirestoreService.db.runTransaction((tx) async {
        final interactionSnap = await tx.get(interactionRef);
        final currentlyActive = interactionSnap.data()?['bookmarked'] == true;
        final next = !currentlyActive;
        tx.set(interactionRef, {
          'user_id': userId,
          'bookmarked': next,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        tx.set(postRef, {
          'bookmarks_count': FieldValue.increment(next ? 1 : -1),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return next;
      });
      final post = await postRef.get();
      final count = _toInt(post.data()?['bookmarks_count']);
      await _invalidateFeedCaches();
      await CacheService.invalidate('bookmarks_$userId');
      PostSyncService.notify(
        reason: PostSyncReason.interactionChanged,
        postId: postId,
      );
      return ToggleInteractionResult(
        success: true,
        isActive: isActive,
        count: count,
      );
    } catch (e) {
      debugPrint('[PostRepo] toggleBookmark fallback error: $e');
      return const ToggleInteractionResult(success: false);
    }
  }

  Future<CounterInteractionResult> trackShare(
    String postId, {
    required String userId,
  }) async {
    try {
      // Route through Cloud Function for server-side counter integrity.
      final result = await CloudFunctionsService.instance
          .httpsCallable('trackShareInteraction')
          .call(<String, dynamic>{'postId': postId});
      final data = Map<String, dynamic>.from(result.data as Map);
      final count = _toInt(data['count']);
      await _invalidateFeedCaches();
      PostSyncService.notify(
        reason: PostSyncReason.interactionChanged,
        postId: postId,
      );
      return CounterInteractionResult(success: true, count: count);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[PostRepo] trackShare CF error: $e');
      // Fallback: direct Firestore write if CF unavailable.
      try {
        await FirestoreService.posts.doc(postId).set({
          'shares_count': FieldValue.increment(1),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        final post = await FirestoreService.posts.doc(postId).get();
        final count = _toInt(post.data()?['shares_count']);
        await _invalidateFeedCaches();
        PostSyncService.notify(
          reason: PostSyncReason.interactionChanged,
          postId: postId,
        );
        return CounterInteractionResult(success: true, count: count);
      } catch (fallbackError) {
        debugPrint('[PostRepo] trackShare fallback error: $fallbackError');
        return const CounterInteractionResult(success: false);
      }
    } catch (e) {
      debugPrint('[PostRepo] trackShare error: $e');
      return const CounterInteractionResult(success: false);
    }
  }

  Future<CounterInteractionResult> trackImpression({
    required String postId,
    required String userId,
  }) async {
    try {
      final postRef = FirestoreService.posts.doc(postId);
      final interactionRef = FirestoreService.postInteractions(
        postId,
      ).doc(userId);

      final didIncrement = await FirestoreService.db.runTransaction((tx) async {
        final inter = await tx.get(interactionRef);
        final impressed = inter.data()?['impressed'] == true;
        if (impressed) return false;

        tx.set(interactionRef, {
          'user_id': userId,
          'impressed': true,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        tx.set(postRef, {
          'impressions_count': FieldValue.increment(1),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return true;
      });

      final post = await postRef.get();
      final count = _toInt(post.data()?['impressions_count']);
      if (didIncrement) {
        await _invalidateFeedCaches();
        PostSyncService.notify(
          reason: PostSyncReason.interactionChanged,
          postId: postId,
        );
      }
      return CounterInteractionResult(success: true, count: count);
    } catch (e) {
      debugPrint('[PostRepo] trackImpression error: $e');
      return const CounterInteractionResult(success: false);
    }
  }

  Future<Post?> getPostById(String postId) async {
    try {
      final doc = await FirestoreService.posts.doc(postId).get();
      if (!doc.exists || doc.data() == null) return null;
      return _mapToPost({'id': doc.id, ...doc.data()!});
    } catch (e) {
      debugPrint('[PostRepo] getPostById error: $e');
      return null;
    }
  }

  Future<void> deletePost(String postId, {String? authorId}) async {
    // Route through Cloud Function — validates ownership/admin role + cleans sub-collections.
    try {
      await CloudFunctionsService.instance.httpsCallable('deletePost').call(
        <String, dynamic>{'postId': postId},
      );
    } catch (e) {
      debugPrint('[PostRepo] deletePost CF failed, falling back: $e');
      await FirestoreService.posts.doc(postId).delete();
    }
    await _invalidatePostCaches();
    PostSyncService.notify(
      reason: PostSyncReason.deleted,
      postId: postId,
      authorId: authorId,
    );
  }

  Future<List<Post>> getPostsByAuthor(
    String authorId, {
    PostStatus? status,
  }) async {
    try {
      Query<Map<String, dynamic>> q = FirestoreService.posts
          .where('author_id', isEqualTo: authorId)
          .orderBy('created_at', descending: true)
          .limit(200);
      if (status != null) q = q.where('status', isEqualTo: status.toStr());
      final snapshot = await q.get();
      return snapshot.docs
          .map((d) => _mapToPost({'id': d.id, ...d.data()}))
          .toList();
    } catch (e) {
      debugPrint('[PostRepo] getPostsByAuthor error: $e');
      return [];
    }
  }

  Future<int> getPendingPostsCount({bool forceRefresh = false}) async {
    if (_pendingCountInFlight != null) return _pendingCountInFlight!;

    const cacheKey = 'pending_posts_count';
    if (!forceRefresh) {
      final cached = CacheService.get(
        cacheKey,
        maxAge: const Duration(seconds: 12),
      );
      if (cached is int) return cached;
      if (cached is num) return cached.toInt();
    }

    final future = _fetchPendingCount(cacheKey);
    _pendingCountInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_pendingCountInFlight, future)) {
        _pendingCountInFlight = null;
      }
    }
  }

  Future<List<Post>> searchPosts(String query, {int limit = 30}) async {
    return discoverPosts(query: query, limit: limit);
  }

  Future<List<Post>> discoverPosts({
    String? query,
    String? category,
    ContentType? contentType,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final snapshot = await FirestoreService.posts
          .where('status', isEqualTo: PostStatus.approved.toStr())
          .orderBy('published_at', descending: true)
          .limit((limit + offset).clamp(20, 300))
          .get();

      final normalizedQuery = query?.trim().toLowerCase();
      final normalizedCategory = category?.trim().toLowerCase();

      final filtered = snapshot.docs
          .map((d) => _mapToPost({'id': d.id, ...d.data()}))
          .where((post) {
            if (normalizedCategory != null &&
                normalizedCategory.isNotEmpty &&
                post.category.toLowerCase() != normalizedCategory) {
              return false;
            }
            if (contentType != null && post.contentType != contentType) {
              return false;
            }
            if (normalizedQuery != null && normalizedQuery.isNotEmpty) {
              final inCaption = post.caption.toLowerCase().contains(
                normalizedQuery,
              );
              final inCategory = post.category.toLowerCase().contains(
                normalizedQuery,
              );
              final inTags = post.hashtags.any(
                (tag) => tag.toLowerCase().contains(normalizedQuery),
              );
              if (!inCaption && !inCategory && !inTags) return false;
            }
            return true;
          })
          .toList();

      if (offset >= filtered.length) return [];
      final end = (offset + limit).clamp(0, filtered.length);
      return filtered.sublist(offset, end);
    } catch (e) {
      debugPrint('[PostRepo] discoverPosts error: $e');
      return [];
    }
  }

  Future<List<Post>> getTrendingPosts({int limit = 20}) async {
    try {
      final snapshot = await FirestoreService.posts
          .where('status', isEqualTo: PostStatus.approved.toStr())
          .orderBy('likes_count', descending: true)
          .orderBy('published_at', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs
          .map((d) => _mapToPost({'id': d.id, ...d.data()}))
          .toList();
    } catch (_) {
      return getApprovedPostsWithInteractions(
        '',
        forceRefresh: true,
      ).then((posts) => posts.take(limit).toList());
    }
  }

  Future<List<Post>> getRecommendedPosts(
    String userId, {
    int limit = 20,
  }) async {
    final posts = await getTrendingPosts(limit: limit * 2);
    return posts.take(limit).toList();
  }

  Future<List<Post>> getRelatedPosts(String postId, {int limit = 12}) async {
    try {
      final current = await getPostById(postId);
      if (current == null) return [];
      final snapshot = await FirestoreService.posts
          .where('status', isEqualTo: PostStatus.approved.toStr())
          .where('category', isEqualTo: current.category)
          .orderBy('published_at', descending: true)
          .limit(limit + 1)
          .get();
      return snapshot.docs
          .where((d) => d.id != postId)
          .map((d) => _mapToPost({'id': d.id, ...d.data()}))
          .take(limit)
          .toList();
    } catch (e) {
      debugPrint('[PostRepo] getRelatedPosts error: $e');
      return [];
    }
  }

  Future<List<Post>> getUserBookmarks(String userId) async {
    final cacheKey = 'bookmarks_$userId';
    final cached = CacheService.get(
      cacheKey,
      maxAge: const Duration(seconds: 20),
    );
    if (cached is List) {
      return cached
          .whereType<Map>()
          .map((row) => _mapToPost(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    }

    try {
      final bookmarkDocs = await FirestoreService.userBookmarks(
        userId,
      ).orderBy('created_at', descending: true).limit(200).get();
      if (bookmarkDocs.docs.isEmpty) return [];

      final orderedIds = bookmarkDocs.docs
          .map((doc) => doc.id)
          .toList(growable: false);
      final postMap = <String, Post>{};

      for (final chunk in _chunkList(orderedIds, 30)) {
        final snapshot = await FirestoreService.posts
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snapshot.docs) {
          postMap[doc.id] = _mapToPost({
            'id': doc.id,
            ...doc.data(),
            'is_bookmarked_by_me': true,
          });
        }
      }

      final posts = orderedIds
          .map((id) => postMap[id])
          .whereType<Post>()
          .toList(growable: false);
      await CacheService.set(
        cacheKey,
        posts.map(_toCacheRow).toList(growable: false),
      );
      return posts;
    } catch (e) {
      debugPrint('[PostRepo] getUserBookmarks error: $e');
      return [];
    }
  }

  Future<List<Post>> getPostsByContentType(
    String userId, {
    ContentType? contentType,
    PostStatus? status,
  }) async {
    try {
      Query<Map<String, dynamic>> q = FirestoreService.posts
          .where('author_id', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .limit(200);
      if (contentType != null) {
        q = q.where('content_type', isEqualTo: contentType.toStr());
      }
      if (status != null) {
        q = q.where('status', isEqualTo: status.toStr());
      }

      final snapshot = await q.get();
      return snapshot.docs
          .map((d) => _mapToPost({'id': d.id, ...d.data()}))
          .toList();
    } catch (e) {
      debugPrint('[PostRepo] getPostsByContentType error: $e');
      return [];
    }
  }

  Future<int> _fetchPendingCount(String cacheKey) async {
    final snapshot = await FirestoreService.posts
        .where('status', isEqualTo: PostStatus.pending.toStr())
        .count()
        .get();
    final count = snapshot.count ?? 0;
    await CacheService.set(cacheKey, count);
    return count;
  }

  Future<void> _invalidatePostCaches() async {
    await _invalidateFeedCaches();
    await CacheService.invalidate('pending_posts_count');
    await CacheService.invalidatePrefix('bookmarks_');
  }

  Future<void> _invalidateFeedCaches() async {
    await CacheService.invalidatePrefix('feed_');
  }

  Future<void> _persistOnDeviceTranslationsForPost({
    required String postId,
    required String caption,
    String? articleContent,
    List<String>? poemVerses,
  }) async {
    try {
      final translatedFields = await _buildOnDeviceTranslationFields(
        caption: caption,
        articleContent: articleContent,
        poemVerses: poemVerses,
      );
      if (translatedFields.isEmpty) return;
      await FirestoreService.posts.doc(postId).set({
        ...translatedFields,
        'translation_meta': {
          'provider': 'mlkit_on_device',
          'status': 'ready',
          'translated_at': FieldValue.serverTimestamp(),
        },
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[PostRepo] persist on-device translation failed: $e');
    }
  }

  Future<Map<String, dynamic>> _buildOnDeviceTranslationFields({
    required String caption,
    String? articleContent,
    List<String>? poemVerses,
  }) async {
    final output = <String, dynamic>{};
    final sourceCaption = caption.trim();
    if (sourceCaption.isNotEmpty) {
      final captionTe = await PostTranslationService.translate(
        text: sourceCaption,
        targetLanguageCode: 'te',
      );
      final captionHi = await PostTranslationService.translate(
        text: sourceCaption,
        targetLanguageCode: 'hi',
      );
      if (captionTe.trim().isNotEmpty) output['caption_te'] = captionTe.trim();
      if (captionHi.trim().isNotEmpty) output['caption_hi'] = captionHi.trim();
    }

    final sourceArticle = articleContent?.trim() ?? '';
    if (sourceArticle.isNotEmpty) {
      final articleTe = await PostTranslationService.translate(
        text: sourceArticle,
        targetLanguageCode: 'te',
      );
      final articleHi = await PostTranslationService.translate(
        text: sourceArticle,
        targetLanguageCode: 'hi',
      );
      if (articleTe.trim().isNotEmpty) {
        output['article_content_te'] = articleTe.trim();
      }
      if (articleHi.trim().isNotEmpty) {
        output['article_content_hi'] = articleHi.trim();
      }
    } else if (poemVerses != null && poemVerses.isNotEmpty) {
      final teVerses = <String>[];
      final hiVerses = <String>[];
      for (final verse in poemVerses) {
        final source = verse.trim();
        if (source.isEmpty) continue;
        final te = await PostTranslationService.translate(
          text: source,
          targetLanguageCode: 'te',
        );
        final hi = await PostTranslationService.translate(
          text: source,
          targetLanguageCode: 'hi',
        );
        if (te.trim().isNotEmpty) teVerses.add(te.trim());
        if (hi.trim().isNotEmpty) hiVerses.add(hi.trim());
      }
      if (teVerses.isNotEmpty) output['poem_verses_te'] = teVerses;
      if (hiVerses.isNotEmpty) output['poem_verses_hi'] = hiVerses;
    }

    return output;
  }

  Future<Post> _mapToPostWithInteraction(
    Map<String, dynamic> row,
    String userId,
  ) async {
    final base = _mapToPost(row);
    if (userId.isEmpty) return base;
    try {
      final doc = await FirestoreService.postInteractions(
        base.id,
      ).doc(userId).get();
      final liked = doc.data()?['liked'] == true;
      final bookmarked = doc.data()?['bookmarked'] == true;
      return base.copyWith(isLikedByMe: liked, isBookmarkedByMe: bookmarked);
    } catch (_) {
      return base;
    }
  }

  Post _mapToPost(Map<String, dynamic> row, {String? userId}) {
    final hashtagsRaw = row['hashtags'];
    final hashtags = hashtagsRaw is List
        ? hashtagsRaw.map((e) => e.toString()).toList()
        : (hashtagsRaw is String && hashtagsRaw.trim().isNotEmpty)
        ? hashtagsRaw
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList()
        : <String>[];

    return Post(
      id: (row['id'] ?? '').toString(),
      authorId: (row['author_id'] ?? '').toString(),
      authorName: _resolveAuthorDisplayName(row),
      authorAvatar: row['author_avatar']?.toString(),
      caption: (row['caption'] ?? '').toString(),
      captionTe: row['caption_te']?.toString(),
      captionHi: row['caption_hi']?.toString(),
      captionDelta: Post.parseDeltaValue(row['caption_delta']),
      mediaUrl: row['media_url']?.toString(),
      contentType: ContentTypeExtension.fromString(
        row['content_type']?.toString() ?? row['media_type']?.toString(),
      ),
      category: (row['category'] ?? 'News').toString(),
      hashtags: hashtags,
      status: PostStatusExtension.fromString(
        (row['status'] ?? 'pending').toString(),
      ),
      pdfFilePath: row['pdf_file_path']?.toString(),
      articleContent: row['article_content']?.toString(),
      articleContentDelta: Post.parseDeltaValue(row['article_content_delta']),
      articleContentTe: row['article_content_te']?.toString(),
      articleContentHi: row['article_content_hi']?.toString(),
      poemVerses: row['poem_verses'] is List
          ? (row['poem_verses'] as List).map((e) => e.toString()).toList()
          : null,
      poemVersesTe: row['poem_verses_te'] is List
          ? (row['poem_verses_te'] as List).map((e) => e.toString()).toList()
          : null,
      poemVersesHi: row['poem_verses_hi'] is List
          ? (row['poem_verses_hi'] as List).map((e) => e.toString()).toList()
          : null,
      likesCount: _toInt(row['likes_count']),
      bookmarksCount: _toInt(row['bookmarks_count']),
      sharesCount: _toInt(row['shares_count']),
      isLikedByMe: row['is_liked_by_me'] == true,
      isBookmarkedByMe: row['is_bookmarked_by_me'] == true,
      rejectionReason: row['rejection_reason']?.toString(),
      editCount: _toInt(row['edit_count']),
      lastEditedAt: row['last_edited_at'] == null
          ? null
          : FirestoreService.toDateTime(row['last_edited_at']),
      createdAt: FirestoreService.toDateTime(row['created_at']),
      publishedAt: FirestoreService.toDateTime(row['published_at']),
    );
  }

  Future<List<Map<String, dynamic>>> _prepareRowsForMapping(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return const <Map<String, dynamic>>[];

    final normalized = rows
        .map(_normalizeRowForBackground)
        .toList(growable: false);

    if (rows.length < _parallelMapMinRows || kIsWeb) {
      return _prepareRowsChunkForBackground(normalized);
    }

    final cpuCount = Platform.numberOfProcessors;
    final workers = (cpuCount - 1).clamp(2, _parallelMaxWorkers);
    final chunkSize = (normalized.length / workers).ceil().clamp(1, 120);
    final chunks = _chunkList(normalized, chunkSize);
    if (chunks.length <= 1) return _prepareRowsChunkForBackground(normalized);

    final futures = chunks
        .map(
          (chunk) => Isolate.run(() => _prepareRowsChunkForBackground(chunk)),
        )
        .toList(growable: false);
    final preparedChunks = await Future.wait(futures, eagerError: false);

    return preparedChunks.expand((chunk) => chunk).toList(growable: false);
  }

  Map<String, dynamic> _normalizeRowForBackground(Map<String, dynamic> row) {
    final normalized = Map<String, dynamic>.from(row);
    normalized['created_at'] = FirestoreService.toDateTime(
      row['created_at'],
    ).toIso8601String();
    normalized['published_at'] = FirestoreService.toDateTime(
      row['published_at'],
    ).toIso8601String();

    final lastEdited = row['last_edited_at'];
    if (lastEdited != null) {
      normalized['last_edited_at'] = FirestoreService.toDateTime(
        lastEdited,
      ).toIso8601String();
    } else {
      normalized['last_edited_at'] = null;
    }
    return normalized;
  }

  Map<String, dynamic> _toCacheRow(Post post) {
    return {
      'id': post.id,
      'author_id': post.authorId,
      'author_name': post.authorName,
      'author_avatar': post.authorAvatar,
      'caption': post.caption,
      'caption_te': post.captionTe,
      'caption_hi': post.captionHi,
      'caption_delta': post.captionDelta,
      'media_url': post.mediaUrl,
      'content_type': post.contentType.toStr(),
      'category': post.category,
      'hashtags': post.hashtags,
      'status': post.status.toStr(),
      'pdf_file_path': post.pdfFilePath,
      'article_content': post.articleContent,
      'article_content_delta': post.articleContentDelta,
      'article_content_te': post.articleContentTe,
      'article_content_hi': post.articleContentHi,
      'poem_verses': post.poemVerses,
      'poem_verses_te': post.poemVersesTe,
      'poem_verses_hi': post.poemVersesHi,
      'likes_count': post.likesCount,
      'bookmarks_count': post.bookmarksCount,
      'shares_count': post.sharesCount,
      'is_liked_by_me': post.isLikedByMe,
      'is_bookmarked_by_me': post.isBookmarkedByMe,
      'rejection_reason': post.rejectionReason,
      'edit_count': post.editCount,
      'last_edited_at': post.lastEditedAt?.toIso8601String(),
      'created_at': post.createdAt.toIso8601String(),
      'published_at': post.publishedAt.toIso8601String(),
    };
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _resolveAuthorDisplayName(Map<String, dynamic> row) {
    final role = (row['author_role'] ?? '').toString().trim().toLowerCase();
    if (role == 'admin' || role == 'super_admin') {
      return 'Focus Today';
    }
    final authorName = (row['author_name'] ?? '').toString().trim();
    if (authorName.isNotEmpty) return authorName;
    return 'Unknown';
  }

  String _normalizeAuthorRole(String? role) {
    final raw = (role ?? '').trim().toLowerCase().replaceAll('_', '');
    switch (raw) {
      case 'superadmin':
        return 'super_admin';
      case 'admin':
        return 'admin';
      case 'reporter':
        return 'reporter';
      case 'publicuser':
        return 'public_user';
      default:
        return 'public_user';
    }
  }

  String _canonicalAuthorNameForWrite(String role, String rawName) {
    if (role == 'admin' || role == 'super_admin') {
      return 'Focus Today';
    }
    final name = rawName.trim();
    return name.isNotEmpty ? name : 'Unknown';
  }

  List<List<T>> _chunkList<T>(List<T> input, int chunkSize) {
    if (input.isEmpty) return const [];

    final chunks = <List<T>>[];
    for (int index = 0; index < input.length; index += chunkSize) {
      final end = (index + chunkSize).clamp(0, input.length);
      chunks.add(input.sublist(index, end));
    }
    return chunks;
  }
}

List<Map<String, dynamic>> _prepareRowsChunkForBackground(
  List<Map<String, dynamic>> chunk,
) {
  return chunk
      .map((row) {
        final prepared = Map<String, dynamic>.from(row);

        final hashtagsRaw = prepared['hashtags'];
        prepared['hashtags'] = hashtagsRaw is List
            ? hashtagsRaw.map((e) => e.toString()).toList(growable: false)
            : (hashtagsRaw is String && hashtagsRaw.trim().isNotEmpty)
            ? hashtagsRaw
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList(growable: false)
            : const <String>[];

        final role = (prepared['author_role'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (role == 'admin' || role == 'super_admin') {
          prepared['author_name'] = 'Focus Today';
        } else {
          final authorName = (prepared['author_name'] ?? '').toString().trim();
          prepared['author_name'] = authorName.isNotEmpty
              ? authorName
              : 'Unknown';
        }

        return prepared;
      })
      .toList(growable: false);
}

class ToggleInteractionResult {
  final bool success;
  final bool queued;
  final bool? isActive;
  final int? count;

  const ToggleInteractionResult({
    required this.success,
    this.queued = false,
    this.isActive,
    this.count,
  });
}

class CounterInteractionResult {
  final bool success;
  final bool queued;
  final int? count;

  const CounterInteractionResult({
    required this.success,
    this.queued = false,
    this.count,
  });
}

class CreatePostResult {
  final String postId;
  final String translationStatus;
  final bool usedCloudFunction;

  const CreatePostResult({
    required this.postId,
    required this.translationStatus,
    required this.usedCloudFunction,
  });
}
