import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/models/post.dart';
import '../../../../core/providers/app_providers.dart';
import '../../data/repositories/profile_repository.dart';

/// Profile data state with proper error handling (fixes #8)
class ProfileState {
  final User? user;
  final int postsCount;
  final int bookmarksCount;
  final List<Post> posts;
  final List<Post> bookmarks;
  final List<Post> articles;
  final List<Post> stories;
  final bool isLoading;
  final String? error;

  const ProfileState({
    this.user,
    this.postsCount = 0,

    this.bookmarksCount = 0,
    this.posts = const [],
    this.bookmarks = const [],
    this.articles = const [],
    this.stories = const [],
    this.isLoading = false,
    this.error,
  });

  ProfileState copyWith({
    User? user,
    int? postsCount,
    int? bookmarksCount,
    List<Post>? posts,
    List<Post>? bookmarks,
    List<Post>? articles,
    List<Post>? stories,
    bool? isLoading,
    String? error,
  }) {
    return ProfileState(
      user: user ?? this.user,
      postsCount: postsCount ?? this.postsCount,
      bookmarksCount: bookmarksCount ?? this.bookmarksCount,
      posts: posts ?? this.posts,
      bookmarks: bookmarks ?? this.bookmarks,
      articles: articles ?? this.articles,
      stories: stories ?? this.stories,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get hasError => error != null;
}

/// Profile provider parameterized by userId.
/// Auto-loads profile data on creation.
/// Usage: ref.watch(profileProvider(userId))
final profileProvider =
    StateNotifierProvider.family<ProfileNotifier, ProfileState, String>((
      ref,
      userId,
    ) {
      final profileRepo = ref.read(profileRepositoryProvider);
      return ProfileNotifier(profileRepo, userId);
    });

class ProfileNotifier extends StateNotifier<ProfileState> {
  final ProfileRepository _profileRepo;
  final String _userId;

  ProfileNotifier(this._profileRepo, this._userId)
    : super(const ProfileState(isLoading: true)) {
    loadProfile();
  }

  /// Load all profile data in parallel (fixes #8 — proper error propagation)
  Future<void> loadProfile() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Load everything in parallel for best performance
      final results = await Future.wait([
        _profileRepo.getUserById(_userId),
        _profileRepo.getUserAllPostsCount(_userId),
        _profileRepo.getUserBookmarksCount(_userId),
        _profileRepo.getUserPosts(_userId),
        _profileRepo.getUserBookmarks(_userId),
        _profileRepo.getUserStories(_userId),
        _profileRepo.getUserArticles(_userId),
      ]);

      if (!mounted) return;

      if (!mounted) return;

      state = state.copyWith(
        user: results[0] as User?,
        postsCount: results[1] as int,
        bookmarksCount: results[2] as int,
        posts: results[3] as List<Post>,
        bookmarks: results[4] as List<Post>,
        stories: results[5] as List<Post>,
        articles: results[6] as List<Post>,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('[ProfileNotifier] loadProfile error: $e');
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load profile: ${e.toString()}',
      );
    }
  }

  /// Refresh profile data
  Future<void> refresh() => loadProfile();

  /// Update profile locally after edit
  void updateUser(User updatedUser) {
    state = state.copyWith(user: updatedUser);
  }
}
