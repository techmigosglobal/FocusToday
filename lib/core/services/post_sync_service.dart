import 'dart:async';

/// Broadcasts post-related mutations so screens can refresh immediately.
class PostSyncService {
  PostSyncService._();

  static final StreamController<PostSyncEvent> _controller =
      StreamController<PostSyncEvent>.broadcast();

  static Stream<PostSyncEvent> get stream => _controller.stream;

  static void notify({
    required PostSyncReason reason,
    String? postId,
    String? authorId,
  }) {
    if (_controller.isClosed) return;
    _controller.add(
      PostSyncEvent(
        reason: reason,
        postId: postId,
        authorId: authorId,
        timestamp: DateTime.now(),
      ),
    );
  }
}

enum PostSyncReason {
  created,
  updated,
  deleted,
  statusChanged,
  resubmitted,
  interactionChanged,
}

class PostSyncEvent {
  final PostSyncReason reason;
  final String? postId;
  final String? authorId;
  final DateTime timestamp;

  const PostSyncEvent({
    required this.reason,
    this.postId,
    this.authorId,
    required this.timestamp,
  });
}
