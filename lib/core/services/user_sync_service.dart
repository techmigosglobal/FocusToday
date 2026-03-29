import 'dart:async';

/// Broadcasts user-related mutations so user modules can refresh immediately.
class UserSyncService {
  UserSyncService._();

  static final StreamController<UserSyncEvent> _controller =
      StreamController<UserSyncEvent>.broadcast();

  static Stream<UserSyncEvent> get stream => _controller.stream;

  static void notify({required UserSyncReason reason, String? userId}) {
    if (_controller.isClosed) return;
    _controller.add(
      UserSyncEvent(reason: reason, userId: userId, timestamp: DateTime.now()),
    );
  }
}

enum UserSyncReason { created, updated, roleChanged, deleted }

class UserSyncEvent {
  final UserSyncReason reason;
  final String? userId;
  final DateTime timestamp;

  const UserSyncEvent({
    required this.reason,
    this.userId,
    required this.timestamp,
  });
}
