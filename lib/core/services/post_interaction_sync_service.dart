import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_functions_service.dart';
import 'connectivity_service.dart';

enum InteractionType { like, bookmark, share, impression }

/// Offline interaction queue with Cloud Function replay.
///
/// When the device is offline, interactions are persisted to SharedPreferences.
/// On reconnection the queue is flushed through the appropriate Cloud Functions
/// to maintain server-side counter integrity.
class PostInteractionSyncService {
  PostInteractionSyncService._();

  static final PostInteractionSyncService instance =
      PostInteractionSyncService._();

  static const String _storageKey = 'pending_post_interactions_v3';
  final List<Map<String, dynamic>> _queue = [];
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await _loadQueue();

    ConnectivityService().onConnectivityChanged.listen((online) {
      if (online) {
        flush();
      }
    });

    if (ConnectivityService().isOnline) {
      flush();
    }
  }

  Future<void> enqueueToggle({
    required InteractionType type,
    required String postId,
    required String userId,
  }) async {
    await _enqueue(type: type, postId: postId, userId: userId, mode: 'toggle');
  }

  Future<void> enqueueIncrement({
    required InteractionType type,
    required String postId,
    required String userId,
    int amount = 1,
  }) async {
    await _enqueue(
      type: type,
      postId: postId,
      userId: userId,
      mode: 'increment',
      amount: amount,
    );
  }

  Future<void> _enqueue({
    required InteractionType type,
    required String postId,
    required String userId,
    required String mode,
    int amount = 1,
  }) async {
    _queue.add({
      'type': type.name,
      'post_id': postId,
      'user_id': userId,
      'mode': mode,
      'amount': amount,
      'queued_at': DateTime.now().toIso8601String(),
    });
    await _saveQueue();
    debugPrint('[InteractionSync] Queued ${type.name} for $postId');
  }

  Future<void> flush() async {
    if (_queue.isEmpty) return;

    final items = List<Map<String, dynamic>>.from(_queue);
    final processed = <int>[];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      try {
        final type = item['type'] as String? ?? '';
        final postId = item['post_id'] as String? ?? '';
        final mode = item['mode'] as String? ?? 'toggle';

        if (postId.isEmpty) {
          processed.add(i);
          continue;
        }

        if (mode == 'toggle') {
          if (type == 'like' || type == 'bookmark') {
            // Replay via Cloud Function
            await _replayToggle(postId, type);
          }
        } else if (mode == 'increment') {
          if (type == 'share') {
            await _replayShare(postId);
          }
        }
        processed.add(i);
      } catch (e) {
        debugPrint('[InteractionSync] Failed to flush item $i: $e');
        // Stop processing — remaining items will retry next time.
        break;
      }
    }

    // Remove successfully processed items.
    for (final idx in processed.reversed) {
      _queue.removeAt(idx);
    }
    await _saveQueue();
  }

  Future<void> _replayToggle(String postId, String type) async {
    await CloudFunctionsService.instance
        .httpsCallable('togglePostInteraction')
        .call(<String, dynamic>{'postId': postId, 'type': type});
  }

  Future<void> _replayShare(String postId) async {
    await CloudFunctionsService.instance
        .httpsCallable('trackShareInteraction')
        .call(<String, dynamic>{'postId': postId});
  }

  Future<void> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.trim().isEmpty) return;
      final parsed = jsonDecode(raw);
      if (parsed is List) {
        _queue
          ..clear()
          ..addAll(
            parsed.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
          );
      }
    } catch (e) {
      debugPrint('[InteractionSync] Failed to load queue: $e');
    }
  }

  Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_queue));
    } catch (e) {
      debugPrint('[InteractionSync] Failed to save queue: $e');
    }
  }
}
