import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/feed/data/repositories/post_repository.dart';
import '../../features/profile/data/repositories/profile_repository.dart';
import '../../features/moderation/data/repositories/user_repository.dart';
import '../../features/search/data/repositories/search_repository.dart';
import '../../features/notifications/data/repositories/notification_repository.dart';

// ==================== Repository Providers ====================
// Single instances shared across the app via Riverpod DI.
// Widgets use: ref.read(postRepositoryProvider) instead of PostRepository().

final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepository();
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository();
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});
