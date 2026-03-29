import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/models/post.dart';
import '../../../../shared/models/user.dart';
import '../../../../core/localization/app_localizations.dart';
import '../widgets/vertical_content_card.dart';
import '../widgets/flip_page_view.dart';
import '../utils/feed_cycle_logic.dart';
import '../utils/feed_image_viewer_builder.dart';
import '../utils/image_shape_type.dart';
import '../../../workspace/presentation/screens/workspace_screen.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';
import 'pdf_viewer_screen.dart';
import 'video_player_screen.dart';
import '../../data/repositories/post_repository.dart';
import '../../data/repositories/post_translation_repository.dart';
import '../../data/services/post_prefetch_service.dart';
import '../../data/services/feed_video_controller_service.dart';
import '../../../../core/services/language_service.dart';
import '../../../comments/presentation/widgets/comments_bottom_sheet.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../../shared/widgets/offline_banner.dart';
import '../../../notifications/data/repositories/notification_repository.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/post_sync_service.dart';
import '../../../../core/services/share_link_service.dart';
import '../../../../core/services/ux_telemetry_service.dart';
import '../../../focus_landing/presentation/screens/focus_landing_screen.dart';
import '../../../focus_landing/data/repositories/focus_landing_repository.dart';
import '../../../meetings/presentation/screens/meetings_list_screen.dart';
import '../../../moderation/presentation/screens/moderation_screen.dart';
import '../../../../shared/widgets/breaking_news_banner.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../../../shared/widgets/page_transitions.dart';
import '../../../../main.dart';

import '../../../../shared/widgets/slice_surface.dart';
import '../../../profile/presentation/widgets/save_to_collection_sheet.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';

/// Feed Screen - Way2News Style Flip Animation
/// Clean, minimal design with 3D flip effect
class FeedScreen extends StatefulWidget {
  final User currentUser;
  final bool showProfilePrompt;

  const FeedScreen({
    super.key,
    required this.currentUser,
    this.showProfilePrompt = false,
  });

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with
        TickerProviderStateMixin,
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin {
  static final Map<String, String> _lastVisiblePostIdByUser = {};
  static final Map<String, int> _lastVisibleIndexByUser = {};
  static final Map<String, int> _lastSeenPublishedAtMsByUser = {};

  List<Post> _posts = [];
  bool _isLoading = true;
  int _pendingCount = 0;

  int _currentIndex = 0;
  late AnimationController _flipController;

  // Enhanced flip animation state
  double _previousProgress = 0.0;

  // Constants for velocity-based animation
  static const double _flipCommitProgressThreshold = 0.13;
  static const double _flipCommitVelocityThreshold = 0.35;

  final PostRepository _postRepo = PostRepository();
  final NotificationRepository _notifRepo = NotificationRepository();
  final UxTelemetryService _telemetry = UxTelemetryService.instance;
  LanguageService? _languageService;
  bool _isLanguageListenerAttached = false;
  AppLanguage _currentLanguage = AppLanguage.english;
  int _unreadNotifCount = 0;

  /// Track liked posts by ID (not index) to avoid filter-related bugs
  final Set<String> _likedPostIds = {};

  /// Track bookmarked posts by ID (not index) to avoid filter-related bugs
  final Set<String> _bookmarkedPostIds = {};
  final Set<String> _trackedImpressionPostIds = {};
  final Map<String, int> _postIndexById = {};
  final Map<String, LocalizedPostText> _localizedPostText = {};
  final Set<String> _translationInFlight = {};
  Map<String, dynamic>? _breakingNews;
  StreamSubscription<PostSyncEvent>? _postSyncSubscription;
  StreamSubscription<InAppNotificationEvent>? _foregroundNotifSubscription;
  Timer? _refreshDebounce;
  Timer? _translationWarmDebounce;
  Timer? _silentRefreshTimer;
  bool _isAutoLandingCheckInFlight = false;
  bool _didRunAutoLandingCheckThisSession = false;
  bool _isForeground = true;
  bool _isPostsLoadInFlight = false;
  bool _isPhasedHydrationInFlight = false;
  bool _didUsePhasedInitialLoad = false;
  bool _hasQueuedForcedPostRefresh = false;
  bool _isPendingCountInFlight = false;
  bool _isUnreadCountInFlight = false;
  bool _isBreakingNewsInFlight = false;
  bool _hasAppliedInitialStartIndex = false;
  bool _hasQueuedPublishedPostRefresh = false;
  final Set<String> _queuedPublishedPostIds = <String>{};
  final Map<String, ImageShapeType> _imageShapeByUrl =
      <String, ImageShapeType>{};
  bool _isBackgroundRefreshing = false;
  DateTime? _lastPendingCountLoadedAt;
  DateTime? _lastUnreadCountLoadedAt;
  DateTime? _lastBreakingNewsLoadedAt;

  /// GAP-005: currently selected category filter; null = All
  String? _selectedCategory;

  double get _dragProgress => _flipController.value;

  void _setDragProgress(double value) {
    _flipController.value = value.clamp(-1.0, 1.0);
  }

  /// Filtered posts for the currently selected category
  List<Post> get _filteredPosts {
    if (_selectedCategory == null) return _posts;
    return _posts.where((p) => p.category == _selectedCategory).toList();
  }

  int _indexOfPostId(String postId) {
    return _postIndexById[postId] ??
        _posts.indexWhere((post) => post.id == postId);
  }

  String get _feedMemoryKey => widget.currentUser.id;
  String get _lastSeenPostIdPrefKey => 'feed_last_seen_post_id_$_feedMemoryKey';
  String get _lastSeenPublishedAtPrefKey =>
      'feed_last_seen_published_at_ms_$_feedMemoryKey';

  Future<void> _loadPersistedFeedCheckpoint() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSeenPostId = prefs.getString(_lastSeenPostIdPrefKey);
    final lastSeenPublishedAtMs = prefs.getInt(_lastSeenPublishedAtPrefKey);

    if (lastSeenPostId != null && lastSeenPostId.isNotEmpty) {
      _lastVisiblePostIdByUser[_feedMemoryKey] = lastSeenPostId;
    }
    if (lastSeenPublishedAtMs != null) {
      _lastSeenPublishedAtMsByUser[_feedMemoryKey] = lastSeenPublishedAtMs;
    }
  }

  Future<void> _persistSeenCheckpoint(Post post, {required int index}) async {
    final lastSeenPublishedAtMs = post.publishedAt.millisecondsSinceEpoch;
    _lastVisibleIndexByUser[_feedMemoryKey] = index;
    _lastVisiblePostIdByUser[_feedMemoryKey] = post.id;
    _lastSeenPublishedAtMsByUser[_feedMemoryKey] = lastSeenPublishedAtMs;

    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_lastSeenPostIdPrefKey, post.id),
      prefs.setInt(_lastSeenPublishedAtPrefKey, lastSeenPublishedAtMs),
    ]);
  }

  void _rememberVisiblePost(List<Post> visiblePosts) {
    if (visiblePosts.isEmpty) return;
    final safeIndex = _currentIndex.clamp(0, visiblePosts.length - 1);
    final post = visiblePosts[safeIndex];
    _lastVisibleIndexByUser[_feedMemoryKey] = safeIndex;
    _lastVisiblePostIdByUser[_feedMemoryKey] = post.id;
    unawaited(_persistSeenCheckpoint(post, index: safeIndex));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      lowerBound: -1.0,
      upperBound: 1.0,
      value: 0.0,
    );

    _listenToPostSync();
    _listenToForegroundNotificationEvents();
    // Defer data loading to after the first frame to reduce startup jank
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initLanguage();
      await _loadPersistedFeedCheckpoint();
      await _loadPosts();
      unawaited(_refreshLiveData(forceRefresh: true));
      unawaited(_checkPendingNotification());
      _startSilentRefreshTimer();
      // Show profile completion prompt if needed
      if (widget.showProfilePrompt) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) _showProfileCompletionPrompt();
        });
      }
    });
  }

  Future<void> _initLanguage() async {
    final sharedLanguageService =
        FocusTodayApp.languageService ?? await LanguageService.init();
    FocusTodayApp.languageService ??= sharedLanguageService;
    _languageService = sharedLanguageService;
    if (!_isLanguageListenerAttached) {
      _languageService!.addListener(_handleLanguageChange);
      _isLanguageListenerAttached = true;
    }
    if (!mounted) return;
    setState(() => _currentLanguage = _languageService!.currentLanguage);
    _scheduleWarmLocalizedTextWindow(includePrev: true);
  }

  void _handleLanguageChange() {
    final languageService = _languageService;
    if (!mounted || languageService == null) return;
    final nextLanguage = languageService.currentLanguage;
    if (nextLanguage == _currentLanguage) return;
    setState(() => _currentLanguage = nextLanguage);
    _scheduleWarmLocalizedTextWindow(includePrev: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    _isForeground = resumed;
    if (resumed) {
      _loadPosts(forceRefresh: true);
      _refreshLiveData(forceRefresh: true);
      _checkPendingNotification();
    }
  }

  bool _isFresh(DateTime? timestamp, Duration maxAge) {
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < maxAge;
  }

  Future<void> _refreshLiveData({bool forceRefresh = false}) async {
    final futures = <Future<void>>[
      _loadUnreadCount(forceRefresh: forceRefresh),
      _loadBreakingNews(forceRefresh: forceRefresh),
    ];
    if (widget.currentUser.canModerate) {
      futures.add(_loadPendingCount(forceRefresh: forceRefresh));
    }

    await Future.wait(futures, eagerError: false);
  }

  Future<void> _loadBreakingNews({bool forceRefresh = false}) async {
    if (_isBreakingNewsInFlight) return;
    if (!forceRefresh &&
        _isFresh(_lastBreakingNewsLoadedAt, const Duration(seconds: 20))) {
      return;
    }
    try {
      _isBreakingNewsInFlight = true;
      _lastBreakingNewsLoadedAt = DateTime.now();
      final snapshot = await FirestoreService.breakingNews
          .where('is_active', isEqualTo: true)
          .orderBy('published_at', descending: true)
          .limit(1)
          .get();
      if (!mounted) return;
      setState(() {
        if (snapshot.docs.isEmpty) {
          _breakingNews = null;
          return;
        }
        _breakingNews = {
          'id': snapshot.docs.first.id,
          ...snapshot.docs.first.data(),
        };
      });
    } catch (e) {
      debugPrint('[FeedScreen] Breaking news load error: $e');
    } finally {
      _isBreakingNewsInFlight = false;
    }
  }

  Future<void> _loadUnreadCount({bool forceRefresh = false}) async {
    if (_isUnreadCountInFlight) return;
    if (!forceRefresh &&
        _isFresh(_lastUnreadCountLoadedAt, const Duration(seconds: 15))) {
      return;
    }
    try {
      _isUnreadCountInFlight = true;
      _lastUnreadCountLoadedAt = DateTime.now();
      final count = await _notifRepo.getUnreadCount(
        widget.currentUser.id,
        forceRefresh: forceRefresh,
      );
      if (mounted) setState(() => _unreadNotifCount = count);
    } catch (_) {
    } finally {
      _isUnreadCountInFlight = false;
    }
  }

  /// Check for pending notification navigation (app opened via push notification)
  Future<void> _checkPendingNotification() async {
    final data = NotificationService.instance.consumePendingNavigation();
    if (data == null || !mounted) return;

    final type = (data['type'] ?? '').toString().trim();
    final postId = data['post_id']?.toString();
    if (postId != null && postId.isNotEmpty) {
      final isAdmin =
          widget.currentUser.role == UserRole.superAdmin ||
          widget.currentUser.role == UserRole.admin;
      final isPendingReviewType =
          type == 'new_post_pending' || type == 'post_resubmitted';
      if (isAdmin && isPendingReviewType) {
        Navigator.push(
          context,
          SmoothPageRoute(
            builder: (_) => ModerationScreen(currentUser: widget.currentUser),
          ),
        );
        return;
      }
      try {
        final post = await _postRepo.getPostById(postId);
        if (post != null && mounted) {
          _focusPost(post.id);
          return;
        }
      } catch (e) {
        debugPrint('[FeedScreen] Pending notification nav error: $e');
      }
    }

    if (!mounted) return;
    if (type == 'meeting_created' ||
        type == 'meeting_interest' ||
        type == 'meeting_reminder') {
      Navigator.push(
        context,
        SmoothPageRoute(
          builder: (_) => MeetingsListScreen(currentUser: widget.currentUser),
        ),
      );
      return;
    }
    if (type == 'breaking_news') {
      final newsId = (data['news_id'] ?? '').toString().trim();
      if (newsId.isNotEmpty) {
        try {
          final newsDoc = await FirestoreService.breakingNews.doc(newsId).get();
          final linkedPostId = newsDoc.data()?['post_id']?.toString();
          if (linkedPostId != null && linkedPostId.isNotEmpty && mounted) {
            final post = await _postRepo.getPostById(linkedPostId);
            if (post != null && mounted) {
              _focusPost(post.id);
              return;
            }
          }
        } catch (e) {
          debugPrint(
            '[FeedScreen] Breaking news deep-link resolution failed: $e',
          );
        }
      }
    }

    if (!mounted) return;
    Navigator.push(
      context,
      SmoothPageRoute(
        builder: (_) => NotificationsScreen(currentUser: widget.currentUser),
      ),
    );
  }

  @override
  void dispose() {
    _rememberVisiblePost(_filteredPosts);
    if (_isLanguageListenerAttached && _languageService != null) {
      _languageService!.removeListener(_handleLanguageChange);
      _isLanguageListenerAttached = false;
    }
    WidgetsBinding.instance.removeObserver(this);
    _postSyncSubscription?.cancel();
    _foregroundNotifSubscription?.cancel();
    _refreshDebounce?.cancel();
    _translationWarmDebounce?.cancel();
    _silentRefreshTimer?.cancel();
    PostPrefetchService.clear();
    FeedVideoControllerService.instance.disposeAll();
    _flipController.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    final visiblePosts = _filteredPosts;
    if (visiblePosts.isEmpty) return;
    _flipController.stop();
    _previousProgress = 0.0;

    // Prefetch video for next post when user starts dragging
    final nextIndex =
        _nextVisibleIndexForCurrent(visiblePosts) ?? (_currentIndex + 1);
    if (nextIndex >= 0 && nextIndex < visiblePosts.length) {
      final nextPost = visiblePosts[nextIndex];
      if (nextPost.contentType == ContentType.video &&
          nextPost.mediaUrl != null) {
        PostPrefetchService.prefetchMedia(nextPost.mediaUrl!);
      }
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final visiblePosts = _filteredPosts;
    if (visiblePosts.isEmpty) return;

    final height = MediaQuery.of(context).size.height;
    final previousProgress = _dragProgress;
    final targetProgress = _dragProgress - (details.delta.dy / height) * 0.92;
    var nextProgress =
        previousProgress + ((targetProgress - previousProgress) * 0.85);

    final canWrapForward = _canWrapForward(visiblePosts);
    final canWrapBackward = _canWrapBackward(visiblePosts);

    // Bounds checking
    if (_currentIndex == 0 && nextProgress < 0 && !canWrapBackward) {
      nextProgress = 0;
    }
    if (_currentIndex == visiblePosts.length - 1 &&
        nextProgress > 0 &&
        !canWrapForward) {
      nextProgress = 0;
    }

    _previousProgress = previousProgress;
    _setDragProgress(nextProgress);

    // Trigger haptic at flip point (50%)
    if (_previousProgress < 0.5 && nextProgress >= 0.5) {
      HapticFeedback.selectionClick();
    } else if (_previousProgress > -0.5 && nextProgress <= -0.5) {
      HapticFeedback.selectionClick();
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    final visiblePosts = _filteredPosts;
    if (visiblePosts.isEmpty) return;

    final primaryVelocity = details.primaryVelocity ?? 0.0;
    final velocity = -primaryVelocity / MediaQuery.of(context).size.height;
    final screenHeight = MediaQuery.of(context).size.height;

    // Calculate velocity-based animation duration
    final animationDuration = VelocityAnalyzer.calculateAnimationDuration(
      primaryVelocity,
      screenHeight,
    );
    final animationCurve = VelocityAnalyzer.calculateAnimationCurve(
      primaryVelocity,
      screenHeight,
    );

    if (_dragProgress > _flipCommitProgressThreshold ||
        velocity > _flipCommitVelocityThreshold) {
      final wrapForwardIndex = resolveCyclicTargetIndex(
        currentIndex: _currentIndex,
        visibleCount: visiblePosts.length,
        direction: FeedSwipeDirection.forward,
        cycleEnabled: _isCycleEnabledForVisiblePosts(visiblePosts),
      );
      if (_currentIndex < visiblePosts.length - 1 || wrapForwardIndex != null) {
        // Trigger haptic for flip completion
        VelocityAnalyzer.triggerHapticFeedback(
          primaryVelocity,
          screenHeight,
          previousProgress: _previousProgress,
          currentProgress: _dragProgress,
        );

        _flipController.value = _dragProgress;
        _flipController
            .animateTo(1.0, duration: animationDuration, curve: animationCurve)
            .then((_) {
              if (mounted) {
                setState(() {
                  _currentIndex = wrapForwardIndex ?? (_currentIndex + 1);
                  _setDragProgress(0.0);
                  _previousProgress = 0.0;
                });
                _onPageChanged(_currentIndex);
                _setDragProgress(0.0);
              }
            });
      } else {
        if (_selectedCategory == null && _postRepo.hasMoreFeedPages) {
          _loadMorePosts();
        }
        _snapBack();
      }
    } else if (_dragProgress < -_flipCommitProgressThreshold ||
        velocity < -_flipCommitVelocityThreshold) {
      final wrapBackwardIndex = resolveCyclicTargetIndex(
        currentIndex: _currentIndex,
        visibleCount: visiblePosts.length,
        direction: FeedSwipeDirection.backward,
        cycleEnabled: _isCycleEnabledForVisiblePosts(visiblePosts),
      );
      if (_currentIndex > 0 || wrapBackwardIndex != null) {
        // Trigger haptic for flip completion
        VelocityAnalyzer.triggerHapticFeedback(
          primaryVelocity,
          screenHeight,
          previousProgress: _previousProgress,
          currentProgress: _dragProgress,
        );

        _flipController.value = _dragProgress;
        _flipController
            .animateTo(-1.0, duration: animationDuration, curve: animationCurve)
            .then((_) {
              if (mounted) {
                setState(() {
                  _currentIndex = wrapBackwardIndex ?? (_currentIndex - 1);
                  _setDragProgress(0.0);
                  _previousProgress = 0.0;
                });
                _onPageChanged(_currentIndex);
                _setDragProgress(0.0);
              }
            });
      } else {
        _snapBack();
      }
    } else {
      _snapBack();
      // Light haptic for snap-back
      HapticFeedback.lightImpact();
    }
  }

  void _snapBack() {
    final distance = _dragProgress.abs();
    final durationMs = (130 + (distance * 160)).round().clamp(130, 260);
    // Keep snap-back smooth and controlled (no bounce) for a buttery feed feel.
    _flipController.animateTo(
      0.0,
      duration: Duration(milliseconds: durationMs),
      curve: Curves.easeOutQuart,
    );
  }

  void _listenToPostSync() {
    _postSyncSubscription = PostSyncService.stream.listen((event) {
      if (!mounted) return;
      if (event.reason == PostSyncReason.interactionChanged) return;

      _refreshDebounce?.cancel();
      _refreshDebounce = Timer(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        _loadPosts(forceRefresh: true);
        _refreshLiveData(forceRefresh: true);
      });
    });
  }

  void _listenToForegroundNotificationEvents() {
    _foregroundNotifSubscription = NotificationService.instance.events.listen((
      event,
    ) {
      if (!mounted) return;
      final isPublishedSignal =
          event.type == 'post_published_digest' ||
          event.type == 'post_published';
      if (!isPublishedSignal) return;
      final postId = event.postId?.trim();
      if (postId != null && postId.isNotEmpty) {
        _queuedPublishedPostIds.add(postId);
      }
      _hasQueuedPublishedPostRefresh = true;
    });
  }

  Future<void> _openFocusLanding() async {
    await _telemetry.trackHeaderAction(
      user: widget.currentUser,
      screen: 'feed',
      action: 'focus_landing_open',
    );
    if (!mounted) return;
    await Navigator.push(
      context,
      SmoothPageRoute(
        builder: (_) => FocusLandingScreen(
          currentUser: widget.currentUser,
          currentLanguage: _currentLanguage,
        ),
      ),
    );
  }

  void _resetFeedToTop({bool refresh = false}) {
    if (_posts.isNotEmpty) _flipController.value = 0.0;
    setState(() => _currentIndex = 0);
    if (refresh) {
      _loadPosts(forceRefresh: true);
    }
    unawaited(
      _telemetry.trackHeaderAction(
        user: widget.currentUser,
        screen: 'feed',
        action: 'feed_reset_to_top',
      ),
    );
  }

  void _applyQueuedPublishedPostRefreshAfterSwipe() {
    if (!_hasQueuedPublishedPostRefresh || !mounted) return;
    _hasQueuedPublishedPostRefresh = false;
    _queuedPublishedPostIds.clear();
    _rememberVisiblePost(_filteredPosts);
    _loadPosts(forceRefresh: true);
  }

  void _startSilentRefreshTimer() {
    _silentRefreshTimer?.cancel();
    _silentRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted || !_isForeground) return;
      _refreshLiveData();
    });
  }

  Future<void> _loadPendingCount({bool forceRefresh = false}) async {
    if (!mounted) return;
    if (widget.currentUser.role != UserRole.superAdmin &&
        widget.currentUser.role != UserRole.admin) {
      return;
    }
    if (_isPendingCountInFlight) return;
    if (!forceRefresh &&
        _isFresh(_lastPendingCountLoadedAt, const Duration(seconds: 8))) {
      return;
    }
    try {
      _isPendingCountInFlight = true;
      _lastPendingCountLoadedAt = DateTime.now();
      final count = await _postRepo.getPendingPostsCount(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _pendingCount = count;
      });
    } catch (e) {
      debugPrint('[FeedScreen] Failed to load pending count: $e');
    } finally {
      _isPendingCountInFlight = false;
    }
  }

  Future<void> _loadPosts({bool forceRefresh = false}) async {
    if (!mounted) return;
    if (_isPostsLoadInFlight) {
      if (forceRefresh) _hasQueuedForcedPostRefresh = true;
      return;
    }
    _isPostsLoadInFlight = true;
    final shouldShowBackgroundRefresh = _posts.isNotEmpty;
    if (shouldShowBackgroundRefresh && mounted) {
      setState(() => _isBackgroundRefreshing = true);
    }
    if (_posts.isEmpty && !_isLoading) {
      setState(() => _isLoading = true);
    }

    try {
      // Feed lifecycle guardrail:
      // - Reporter-created posts are stored as pending and excluded from feed
      //   until moderation approves.
      // - Admin/super-admin posts can be auto-approved by backend callable logic.
      // Keep feed queries constrained to approved content only.
      final shouldUsePhasedInitialLoad =
          !forceRefresh && !_didUsePhasedInitialLoad && _posts.isEmpty;
      if (shouldUsePhasedInitialLoad) {
        final firstPost = await _postRepo.getApprovedPostsWithInteractions(
          widget.currentUser.id,
          forceRefresh: false,
          initialFetchLimit: 1,
        );
        if (!mounted) return;
        _applyLoadedPosts(firstPost);
        _didUsePhasedInitialLoad = true;
        unawaited(_hydrateFeedAfterInitialPaint());
        return;
      }

      final posts = await _postRepo.getApprovedPostsWithInteractions(
        widget.currentUser.id,
        forceRefresh: forceRefresh,
      );

      if (!mounted) return;
      _applyLoadedPosts(posts);
    } catch (e) {
      debugPrint('[FeedScreen] Failed to load posts: $e');
      if (!mounted) return;
      setState(() {
        _posts = [];
        _isLoading = false;
      });
    } finally {
      _isPostsLoadInFlight = false;
      if (mounted && _isBackgroundRefreshing) {
        setState(() => _isBackgroundRefreshing = false);
      }
      if (_hasQueuedForcedPostRefresh && mounted) {
        _hasQueuedForcedPostRefresh = false;
        _loadPosts(forceRefresh: true);
      }
    }
  }

  void _applyLoadedPosts(List<Post> posts) {
    setState(() {
      _posts = posts;
      _postIndexById
        ..clear()
        ..addEntries(
          posts.asMap().entries.map(
            (entry) => MapEntry(entry.value.id, entry.key),
          ),
        );
      final visibleCount = _selectedCategory == null
          ? _posts.length
          : _posts.where((post) => post.category == _selectedCategory).length;
      final rememberedPostId = _lastVisiblePostIdByUser[_feedMemoryKey];
      final rememberedIndex = _lastVisibleIndexByUser[_feedMemoryKey];
      final lastSeenPublishedAtMs =
          _lastSeenPublishedAtMsByUser[_feedMemoryKey];
      if (!_hasAppliedInitialStartIndex && visibleCount > 0) {
        final visiblePosts = _selectedCategory == null
            ? _posts
            : _posts
                  .where((post) => post.category == _selectedCategory)
                  .toList(growable: false);
        final unseenIndex = lastSeenPublishedAtMs == null
            ? -1
            : visiblePosts.indexWhere(
                (post) =>
                    post.publishedAt.millisecondsSinceEpoch >
                    lastSeenPublishedAtMs,
              );
        _currentIndex = unseenIndex >= 0 ? unseenIndex : 0;
        _hasAppliedInitialStartIndex = true;
      } else if (rememberedPostId != null && visibleCount > 0) {
        final visiblePosts = _selectedCategory == null
            ? _posts
            : _posts
                  .where((post) => post.category == _selectedCategory)
                  .toList(growable: false);
        final restoredIndex = visiblePosts.indexWhere(
          (post) => post.id == rememberedPostId,
        );
        if (restoredIndex != -1) {
          _currentIndex = restoredIndex;
        } else if (rememberedIndex != null &&
            rememberedIndex >= 0 &&
            rememberedIndex < visibleCount) {
          _currentIndex = rememberedIndex;
        }
      }
      if (visibleCount == 0) {
        _currentIndex = 0;
      } else if (_currentIndex >= visibleCount) {
        _currentIndex = visibleCount - 1;
      }
      _isLoading = false;
      _likedPostIds.clear();
      _bookmarkedPostIds.clear();
      for (final post in posts) {
        if (post.isLikedByMe) _likedPostIds.add(post.id);
        if (post.isBookmarkedByMe) _bookmarkedPostIds.add(post.id);
      }
      _trackedImpressionPostIds.removeWhere(
        (postId) => !posts.any((post) => post.id == postId),
      );
      _localizedPostText.removeWhere(
        (cacheKey, _) => !_postIndexById.containsKey(cacheKey.split('|').first),
      );
      _translationInFlight.removeWhere(
        (cacheKey) => !_postIndexById.containsKey(cacheKey.split('|').first),
      );
    });
    final visiblePosts = _filteredPosts;
    if (visiblePosts.isNotEmpty && _currentIndex < visiblePosts.length) {
      _trackImpressionForPostId(visiblePosts[_currentIndex].id);
    }
    _prefetchUpcomingPosts();
    _scheduleWarmLocalizedTextWindow(includePrev: true);
    unawaited(_primeTranslationsForLoadedPosts());
    unawaited(_maybeShowScheduledLanding());
    unawaited(_syncVideoWindowControllers());
  }

  Future<void> _hydrateFeedAfterInitialPaint() async {
    if (_isPhasedHydrationInFlight || !mounted) return;
    _isPhasedHydrationInFlight = true;
    try {
      final morePosts = await _postRepo.loadMoreApprovedPosts(
        widget.currentUser.id,
      );
      if (!mounted || morePosts.isEmpty) return;
      final merged = [..._posts];
      final existingIds = merged.map((post) => post.id).toSet();
      for (final post in morePosts) {
        if (existingIds.add(post.id)) {
          merged.add(post);
        }
      }
      if (!mounted) return;
      _applyLoadedPosts(merged);
    } catch (e) {
      debugPrint('[FeedScreen] Initial feed hydration failed: $e');
    } finally {
      _isPhasedHydrationInFlight = false;
    }
  }

  Future<void> _primeTranslationsForLoadedPosts() async {
    if (!mounted || _currentLanguage == AppLanguage.english) return;
    final visible = _filteredPosts;
    if (visible.isEmpty) return;
    final langCode = _currentLanguage.code;
    final candidates = visible.take(18).toList(growable: false);
    for (final post in candidates) {
      if (!mounted) return;
      try {
        await PostTranslationRepository.getLocalizedText(
          post: post,
          targetLanguageCode: langCode,
        );
      } catch (_) {
        // Best effort.
      }
    }
  }

  Future<void> _maybeShowScheduledLanding() async {
    if (!mounted) return;
    final role = widget.currentUser.role;
    final canAutoShowLanding =
        role == UserRole.publicUser ||
        role == UserRole.reporter ||
        role == UserRole.admin ||
        role == UserRole.superAdmin;
    if (!canAutoShowLanding) {
      return;
    }
    if (_isAutoLandingCheckInFlight || _didRunAutoLandingCheckThisSession) {
      return;
    }

    _isAutoLandingCheckInFlight = true;
    _didRunAutoLandingCheckThisSession = true;
    try {
      final content = await FocusLandingRepository().getContent();
      if (!content.autoShowForPublicUsers) return;

      final now = DateTime.now();
      final intervalHours = _slotIntervalHoursForFrequency(
        content.autoShowFrequencyPerDay,
      );
      final slotStart = _currentSlotStart(
        now: now,
        startHour24: content.autoShowStartHour24,
        intervalHours: intervalHours,
      );

      final prefs = await SharedPreferences.getInstance();
      final key =
          'focus_landing_last_auto_shown_${widget.currentUser.id}_${widget.currentUser.role.toStr()}';
      final lastShownMillis = prefs.getInt(key);
      if (lastShownMillis != null) {
        final lastShown = DateTime.fromMillisecondsSinceEpoch(lastShownMillis);
        if (!lastShown.isBefore(slotStart)) return;
      }

      if (!mounted) return;
      await Navigator.push(
        context,
        SmoothPageRoute(
          builder: (_) => FocusLandingScreen(
            currentUser: widget.currentUser,
            currentLanguage: _currentLanguage,
            autoMode: true,
            showSkipButton: true,
            autoCloseSeconds: content.autoShowDurationSeconds,
          ),
        ),
      );
      await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[FeedScreen] auto landing check failed: $e');
    } finally {
      _isAutoLandingCheckInFlight = false;
    }
  }

  DateTime _currentSlotStart({
    required DateTime now,
    required int startHour24,
    required int intervalHours,
  }) {
    var slot = DateTime(now.year, now.month, now.day, startHour24);
    final interval = Duration(hours: intervalHours);
    while (slot.isAfter(now)) {
      slot = slot.subtract(interval);
    }
    while (!slot.add(interval).isAfter(now)) {
      slot = slot.add(interval);
    }
    return slot;
  }

  int _slotIntervalHoursForFrequency(int frequencyPerDay) {
    final safeFrequency = frequencyPerDay.clamp(1, 6);
    final computed = (24 / safeFrequency).floor();
    return computed.clamp(1, 24);
  }

  /// Load more posts when user nears the end of the list (pagination).
  bool _isLoadingMore = false;

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_postRepo.hasMoreFeedPages || !mounted) return;
    _isLoadingMore = true;

    try {
      final morePosts = await _postRepo.loadMoreApprovedPosts(
        widget.currentUser.id,
      );
      if (!mounted || morePosts.isEmpty) return;
      setState(() {
        final existingIds = _posts.map((post) => post.id).toSet();
        for (final post in morePosts) {
          if (!existingIds.add(post.id)) continue;
          _postIndexById[post.id] = _posts.length;
          _posts.add(post);
          if (post.isLikedByMe) _likedPostIds.add(post.id);
          if (post.isBookmarkedByMe) _bookmarkedPostIds.add(post.id);
        }
      });
    } catch (e) {
      debugPrint('[FeedScreen] Failed to load more posts: $e');
    } finally {
      _isLoadingMore = false;
    }
  }

  // ==================== GESTURE HANDLING ====================

  void _onPageChanged(int index) {
    if (!mounted) return;
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
    }
    final visiblePosts = _filteredPosts;
    if (visiblePosts.isNotEmpty && _currentIndex < visiblePosts.length) {
      _trackImpressionForPostId(visiblePosts[_currentIndex].id);
      _rememberVisiblePost(visiblePosts);
    }
    _prefetchUpcomingPosts();
    _scheduleWarmLocalizedTextWindow(includePrev: true);
    unawaited(_syncVideoWindowControllers());

    // Trigger pagination when nearing end of the current visible list.
    if (_selectedCategory == null &&
        _currentIndex >= _filteredPosts.length - 5) {
      _loadMorePosts();
    }
    _applyQueuedPublishedPostRefreshAfterSwipe();
  }

  bool _isCycleEnabledForVisiblePosts(List<Post> visiblePosts) {
    return canEnableFeedCycle(
      isPrimaryFeed: _selectedCategory == null,
      visibleCount: visiblePosts.length,
      hasMoreFeedPages: _postRepo.hasMoreFeedPages,
    );
  }

  bool _canWrapForward(List<Post> visiblePosts) {
    return resolveCyclicTargetIndex(
          currentIndex: _currentIndex,
          visibleCount: visiblePosts.length,
          direction: FeedSwipeDirection.forward,
          cycleEnabled: _isCycleEnabledForVisiblePosts(visiblePosts),
        ) !=
        null;
  }

  bool _canWrapBackward(List<Post> visiblePosts) {
    return resolveCyclicTargetIndex(
          currentIndex: _currentIndex,
          visibleCount: visiblePosts.length,
          direction: FeedSwipeDirection.backward,
          cycleEnabled: _isCycleEnabledForVisiblePosts(visiblePosts),
        ) !=
        null;
  }

  int? _nextVisibleIndexForCurrent(List<Post> visiblePosts) {
    if (_currentIndex < visiblePosts.length - 1) {
      return _currentIndex + 1;
    }
    return resolveCyclicTargetIndex(
      currentIndex: _currentIndex,
      visibleCount: visiblePosts.length,
      direction: FeedSwipeDirection.forward,
      cycleEnabled: _isCycleEnabledForVisiblePosts(visiblePosts),
    );
  }

  int? _previousVisibleIndexForCurrent(List<Post> visiblePosts) {
    if (_currentIndex > 0) {
      return _currentIndex - 1;
    }
    return resolveCyclicTargetIndex(
      currentIndex: _currentIndex,
      visibleCount: visiblePosts.length,
      direction: FeedSwipeDirection.backward,
      cycleEnabled: _isCycleEnabledForVisiblePosts(visiblePosts),
    );
  }

  void _prefetchUpcomingPosts() {
    final visiblePosts = _filteredPosts;
    if (!mounted || visiblePosts.isEmpty) return;
    // Background prefetch (parallel) for upcoming media posts.
    PostPrefetchService.prefetchUpcoming(
      context: context,
      posts: visiblePosts,
      currentIndex: _currentIndex,
      aheadCount: 4,
    );
  }

  String _localizedKey(Post post, String languageCode) {
    return '${post.id}|$languageCode';
  }

  void _scheduleWarmLocalizedTextWindow({
    bool includePrev = true,
    Duration delay = const Duration(milliseconds: 90),
  }) {
    _translationWarmDebounce?.cancel();
    _translationWarmDebounce = Timer(delay, () {
      if (!mounted) return;
      unawaited(_warmLocalizedTextWindow(includePrev: includePrev));
    });
  }

  Future<void> _warmLocalizedTextWindow({bool includePrev = true}) async {
    final visiblePosts = _filteredPosts;
    if (!mounted || visiblePosts.isEmpty) return;
    final langCode = _currentLanguage.code;

    final indexes = <int>{
      _currentIndex,
      _currentIndex + 1,
      _currentIndex + 2,
      if (includePrev) _currentIndex - 1,
    };

    final posts = indexes
        .where((i) => i >= 0 && i < visiblePosts.length)
        .map((i) => visiblePosts[i])
        .toList(growable: false);
    final pending = <String, Future<LocalizedPostText>>{};
    final postIdByKey = <String, String>{};
    for (final post in posts) {
      final key = _localizedKey(post, langCode);
      if (_localizedPostText.containsKey(key) ||
          _translationInFlight.contains(key)) {
        continue;
      }
      _translationInFlight.add(key);
      pending[key] = PostTranslationRepository.getLocalizedText(
        post: post,
        targetLanguageCode: langCode,
      );
      postIdByKey[key] = post.id;
    }
    if (pending.isEmpty) return;

    final resolved = await Future.wait(
      pending.entries.map((entry) async {
        try {
          final value = await entry.value;
          return MapEntry(entry.key, value);
        } catch (e) {
          debugPrint(
            '[FeedScreen] Translation cache error for ${postIdByKey[entry.key]}: $e',
          );
          return null;
        }
      }),
    );

    if (!mounted) return;
    final updates = <String, LocalizedPostText>{};
    for (final entry in resolved) {
      if (entry != null) {
        updates[entry.key] = entry.value;
      }
    }
    if (updates.isNotEmpty) {
      setState(() {
        _localizedPostText.addAll(updates);
      });
    }
    for (final key in pending.keys) {
      _translationInFlight.remove(key);
    }
  }

  Future<void> _syncVideoWindowControllers() async {
    final visiblePosts = _filteredPosts;
    if (visiblePosts.isEmpty) {
      await FeedVideoControllerService.instance.trimTo({});
      return;
    }

    final keepKeys = <String>{};

    void addIfVideo(int index) {
      if (index < 0 || index >= visiblePosts.length) return;
      final post = visiblePosts[index];
      final url = post.mediaUrl?.trim();
      if (post.contentType == ContentType.video &&
          url != null &&
          url.isNotEmpty) {
        keepKeys.add(
          FeedVideoControllerService.buildKey(postId: post.id, mediaUrl: url),
        );
      }
    }

    addIfVideo(_currentIndex);
    addIfVideo(_currentIndex + 1);

    await FeedVideoControllerService.instance.trimTo(keepKeys);
  }

  // ==================== ACTIONS ====================

  Future<void> _toggleLanguage() async {
    final languageService = _languageService;
    if (languageService == null) return;
    await languageService.cycleLanguage();
    if (!mounted) return;
    final currentLanguage = languageService.currentLanguage;
    unawaited(
      _telemetry.trackHeaderAction(
        user: widget.currentUser,
        screen: 'feed',
        action: 'language_toggle',
        metadata: {'language': currentLanguage.code},
      ),
    );
  }

  Future<void> _toggleLikeByPostId(String targetPostId) async {
    final postIndex = _indexOfPostId(targetPostId);
    if (postIndex < 0 || postIndex >= _posts.length) return;
    final post = _posts[postIndex];
    final postId = post.id;
    final wasLiked = _likedPostIds.contains(postId);

    setState(() {
      if (wasLiked) {
        _likedPostIds.remove(postId);
        _posts[postIndex] = post.copyWith(
          likesCount: post.likesCount > 0 ? post.likesCount - 1 : 0,
          isLikedByMe: false,
        );
      } else {
        _likedPostIds.add(postId);
        _posts[postIndex] = post.copyWith(
          likesCount: post.likesCount + 1,
          isLikedByMe: true,
        );
      }
    });

    HapticFeedback.lightImpact();
    unawaited(
      _telemetry.trackEngagement(
        user: widget.currentUser,
        screen: 'feed',
        action: 'like_toggle',
        postId: postId,
        metadata: {'was_liked': wasLiked, 'post_index': postIndex},
      ),
    );

    final result = await _postRepo.toggleLike(postId, widget.currentUser.id);
    final currentIndex = _indexOfPostId(postId);
    if (!result.success &&
        mounted &&
        currentIndex >= 0 &&
        currentIndex < _posts.length) {
      // Rollback optimistic UI for non-retryable failures.
      setState(() {
        if (wasLiked) {
          _likedPostIds.add(postId);
          _posts[currentIndex] = _posts[currentIndex].copyWith(
            likesCount: _posts[currentIndex].likesCount + 1,
            isLikedByMe: true,
          );
        } else {
          _likedPostIds.remove(postId);
          _posts[currentIndex] = _posts[currentIndex].copyWith(
            likesCount: _posts[currentIndex].likesCount > 0
                ? _posts[currentIndex].likesCount - 1
                : 0,
            isLikedByMe: false,
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations(_currentLanguage).failedToUpdateLikeTryAgain,
          ),
        ),
      );
      return;
    }

    final freshIndex = _indexOfPostId(postId);
    if (!mounted || freshIndex < 0 || freshIndex >= _posts.length) return;
    if (result.isActive != null || result.count != null) {
      setState(() {
        final current = _posts[freshIndex];
        final isLiked = result.isActive ?? _likedPostIds.contains(postId);
        if (isLiked) {
          _likedPostIds.add(postId);
        } else {
          _likedPostIds.remove(postId);
        }
        _posts[freshIndex] = current.copyWith(
          isLikedByMe: isLiked,
          likesCount: result.count ?? current.likesCount,
        );
      });
    }
  }

  Future<void> _toggleBookmarkByPostId(String targetPostId) async {
    final postIndex = _indexOfPostId(targetPostId);
    if (postIndex < 0 || postIndex >= _posts.length) return;
    final post = _posts[postIndex];
    final postId = post.id;
    final wasBookmarked = _bookmarkedPostIds.contains(postId);

    setState(() {
      if (wasBookmarked) {
        _bookmarkedPostIds.remove(postId);
        _posts[postIndex] = post.copyWith(
          bookmarksCount: post.bookmarksCount > 0 ? post.bookmarksCount - 1 : 0,
          isBookmarkedByMe: false,
        );
      } else {
        _bookmarkedPostIds.add(postId);
        _posts[postIndex] = post.copyWith(
          bookmarksCount: post.bookmarksCount + 1,
          isBookmarkedByMe: true,
        );
      }
    });

    HapticFeedback.mediumImpact();
    unawaited(
      _telemetry.trackEngagement(
        user: widget.currentUser,
        screen: 'feed',
        action: 'bookmark_toggle',
        postId: postId,
        metadata: {'was_bookmarked': wasBookmarked, 'post_index': postIndex},
      ),
    );

    final result = await _postRepo.toggleBookmark(
      postId,
      widget.currentUser.id,
    );
    final currentIndex = _indexOfPostId(postId);
    if (!result.success &&
        mounted &&
        currentIndex >= 0 &&
        currentIndex < _posts.length) {
      // Rollback optimistic UI for non-retryable failures.
      setState(() {
        if (wasBookmarked) {
          _bookmarkedPostIds.add(postId);
          _posts[currentIndex] = _posts[currentIndex].copyWith(
            bookmarksCount: _posts[currentIndex].bookmarksCount + 1,
            isBookmarkedByMe: true,
          );
        } else {
          _bookmarkedPostIds.remove(postId);
          _posts[currentIndex] = _posts[currentIndex].copyWith(
            bookmarksCount: _posts[currentIndex].bookmarksCount > 0
                ? _posts[currentIndex].bookmarksCount - 1
                : 0,
            isBookmarkedByMe: false,
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations(_currentLanguage).failedToUpdateBookmarkTryAgain,
          ),
        ),
      );
      return;
    }

    final freshIndex = _indexOfPostId(postId);
    if (!mounted || freshIndex < 0 || freshIndex >= _posts.length) return;
    if (result.isActive != null || result.count != null) {
      setState(() {
        final current = _posts[freshIndex];
        final isBookmarked =
            result.isActive ?? _bookmarkedPostIds.contains(postId);
        if (isBookmarked) {
          _bookmarkedPostIds.add(postId);
        } else {
          _bookmarkedPostIds.remove(postId);
        }
        _posts[freshIndex] = current.copyWith(
          isBookmarkedByMe: isBookmarked,
          bookmarksCount: result.count ?? current.bookmarksCount,
        );
      });
    }
  }

  Future<void> _showSaveToCollectionSheet(Post post) async {
    HapticFeedback.lightImpact();
    await showSaveToCollectionSheet(
      context: context,
      post: post,
      userId: widget.currentUser.id,
    );
  }

  Future<void> _sharePostByPostId(String targetPostId) async {
    final postIndex = _indexOfPostId(targetPostId);
    if (postIndex < 0 || postIndex >= _posts.length) return;
    final post = _posts[postIndex];
    final localizations = AppLocalizations(_currentLanguage);
    final shareUrl = ShareLinkService.postUrl(post.id);

    await SharePlus.instance.share(
      ShareParams(
        text:
            '${localizations.checkOutPost} ${post.getLocalizedCaption(_currentLanguage.code)}\n\n$shareUrl',
      ),
    );
    unawaited(
      _telemetry.trackEngagement(
        user: widget.currentUser,
        screen: 'feed',
        action: 'share_tap',
        postId: post.id,
        metadata: {'post_index': postIndex},
      ),
    );

    if (!mounted) return;
    final currentIndex = _indexOfPostId(post.id);
    if (currentIndex < 0 || currentIndex >= _posts.length) return;
    setState(() {
      _posts[currentIndex] = _posts[currentIndex].copyWith(
        sharesCount: _posts[currentIndex].sharesCount + 1,
      );
    });
    final result = await _postRepo.trackShare(
      post.id,
      userId: widget.currentUser.id,
    );
    final freshIndex = _indexOfPostId(post.id);
    if (!result.success &&
        mounted &&
        freshIndex >= 0 &&
        freshIndex < _posts.length) {
      setState(() {
        _posts[freshIndex] = _posts[freshIndex].copyWith(
          sharesCount: _posts[freshIndex].sharesCount > 0
              ? _posts[freshIndex].sharesCount - 1
              : 0,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations(_currentLanguage).failedToTrackShareTryAgain,
          ),
        ),
      );
      return;
    }

    if (!mounted || freshIndex < 0 || freshIndex >= _posts.length) return;
    if (result.count != null) {
      setState(() {
        _posts[freshIndex] = _posts[freshIndex].copyWith(
          sharesCount: result.count!,
        );
      });
    }
  }

  Future<void> _trackImpressionForPostId(String postId) async {
    if (postId.isEmpty || _trackedImpressionPostIds.contains(postId)) return;

    _trackedImpressionPostIds.add(postId);
    final result = await _postRepo.trackImpression(
      postId: postId,
      userId: widget.currentUser.id,
    );
    if (!result.success) {
      _trackedImpressionPostIds.remove(postId);
    }
  }

  Future<ImageShapeType> _resolveImageShapeCached(String mediaUrl) async {
    final cached = _imageShapeByUrl[mediaUrl];
    if (cached != null) return cached;
    final shape = await resolveImageShapeFromUrl(mediaUrl);
    _imageShapeByUrl[mediaUrl] = shape;
    return shape;
  }

  void _openContentViewer(Post post) async {
    HapticFeedback.lightImpact();
    _trackImpressionForPostId(post.id);
    unawaited(
      _telemetry.trackNavigation(
        user: widget.currentUser,
        screen: 'feed',
        destination: 'post_detail',
        metadata: {'post_id': post.id},
      ),
    );

    final mediaUrl = post.mediaUrl;
    final isPdf =
        post.contentType == ContentType.pdf ||
        post.pdfFilePath != null ||
        (mediaUrl != null && _isPdfUrl(mediaUrl));
    final isVideo =
        post.contentType == ContentType.video ||
        (mediaUrl != null && _isVideoUrl(mediaUrl));
    final isImage =
        post.contentType == ContentType.image ||
        (mediaUrl != null && _isImageUrl(mediaUrl));

    if (isPdf) {
      // Open PDF viewer directly — skip the detail screen for PDFs.
      Navigator.push(
        context,
        SmoothPageRoute(
          builder: (_) =>
              PdfViewerScreen(post: post, currentLanguage: _currentLanguage),
        ),
      );
    } else if (isVideo) {
      Navigator.push(
        context,
        SmoothPageRoute(builder: (_) => VideoPlayerScreen(post: post)),
      );
    } else if (isImage && mediaUrl != null) {
      final shape = await _resolveImageShapeCached(mediaUrl);
      if (!mounted) return;
      Navigator.push(
        context,
        SmoothPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: Center(
              child: buildFeedImageViewer(
                mediaUrl: mediaUrl,
                imageShape: shape,
              ),
            ),
          ),
        ),
      );
    }
  }

  void _openPostDetail(Post post) {
    HapticFeedback.lightImpact();
    _trackImpressionForPostId(post.id);

    // Bypass Post Detail Screen for PDFs
    final mediaUrl = post.mediaUrl;
    final isPdf =
        post.contentType == ContentType.pdf ||
        post.pdfFilePath != null ||
        (mediaUrl != null && _isPdfUrl(mediaUrl));

    if (isPdf) {
      unawaited(
        _telemetry.trackNavigation(
          user: widget.currentUser,
          screen: 'feed',
          destination: 'pdf_viewer',
          metadata: {'post_id': post.id},
        ),
      );
      Navigator.push(
        context,
        SmoothPageRoute(
          builder: (_) =>
              PdfViewerScreen(post: post, currentLanguage: _currentLanguage),
        ),
      );
      return;
    }

    unawaited(
      _telemetry.trackNavigation(
        user: widget.currentUser,
        screen: 'feed',
        destination: 'post_detail',
        metadata: {'post_id': post.id},
      ),
    );
    Navigator.push(
      context,
      SmoothPageRoute(
        builder: (_) => PostDetailScreen(
          post: post,
          currentUser: widget.currentUser,
          currentLanguage: _currentLanguage,
        ),
      ),
    );
  }

  void _focusPost(String postId) {
    final visiblePosts = _filteredPosts;
    if (visiblePosts.isEmpty) return;
    final visibleIndex = visiblePosts.indexWhere((post) => post.id == postId);
    if (visibleIndex == -1) return;

    setState(() {
      _currentIndex = visibleIndex;
      _setDragProgress(0.0);
      _previousProgress = 0.0;
    });
    _rememberVisiblePost(visiblePosts);
    _trackImpressionForPostId(postId);
    _scheduleWarmLocalizedTextWindow(includePrev: true);
    unawaited(_syncVideoWindowControllers());
  }

  bool _isVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv') ||
        lower.contains('video') ||
        lower.contains('watch');
  }

  bool _isImageUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.contains('image') ||
        lower.contains('img');
  }

  bool _isPdfUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.pdf') || lower.contains('pdf');
  }

  void _openComments(Post post) {
    unawaited(
      _telemetry.trackEngagement(
        user: widget.currentUser,
        screen: 'feed',
        action: 'open_comments',
        postId: post.id,
      ),
    );
    CommentsBottomSheet.show(
      context,
      post,
      widget.currentUser,
      _currentLanguage,
    );
  }

  Widget _buildPostCard(Post post, int index, bool isCurrent) {
    final localized =
        _localizedPostText[_localizedKey(post, _currentLanguage.code)];

    final shouldPrepareVideo =
        index == _currentIndex || index == _currentIndex + 1;

    return Stack(
      children: [
        VerticalContentCard(
          post: post,
          currentUser: widget.currentUser,
          currentLanguage: _currentLanguage,
          flipProgress: isCurrent ? _dragProgress : 0.0,
          onLanguageToggle: _toggleLanguage,
          onLike: () => _toggleLikeByPostId(post.id),
          onComment: () => _openComments(post),
          onBookmark: () => _toggleBookmarkByPostId(post.id),
          onBookmarkLongPress: () => _showSaveToCollectionSheet(post),
          onShare: () => _sharePostByPostId(post.id),
          isLiked: _likedPostIds.contains(post.id),
          isBookmarked: _bookmarkedPostIds.contains(post.id),
          likeCount: post.likesCount,
          bookmarkCount: post.bookmarksCount,
          shareCount: post.sharesCount,
          isVisible: isCurrent,
          shouldPrepareVideo: shouldPrepareVideo,
          translatedCaption: localized?.caption,
          translatedSnippet: localized?.snippet,
          postIndex: index,
          totalPosts: _posts.length,
          showPostCounter:
              widget.currentUser.role == UserRole.superAdmin ||
              widget.currentUser.role == UserRole.admin,
          onTap: () => _openPostDetail(post),
          onReadMore: null,
          onMediaTap: () => _openContentViewer(post),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isContentCreator =
        widget.currentUser.role == UserRole.superAdmin ||
        widget.currentUser.role == UserRole.admin ||
        widget.currentUser.role == UserRole.reporter;
    final visiblePosts = _filteredPosts;
    final visibleIndexById = {
      for (final entry in visiblePosts.asMap().entries)
        entry.value.id: entry.key,
    };

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      body: OfflineBanner(
        child: SliceBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildThinTopBar(isContentCreator),

                // Breaking news flash banner
                if (_breakingNews != null)
                  BreakingNewsBanner(
                    title: _breakingNews!['title'] ?? '',
                    currentLanguage: _currentLanguage,
                    subtitle: _breakingNews!['subtitle'],
                    onTap: () async {
                      final postId = _breakingNews!['post_id']?.toString();
                      if (postId != null && postId.isNotEmpty) {
                        try {
                          final post = await _postRepo.getPostById(postId);
                          if (!context.mounted) return;
                          if (post != null) _focusPost(post.id);
                        } catch (_) {}
                      }
                    },
                    onDismiss: () {
                      if (mounted) setState(() => _breakingNews = null);
                    },
                  ),

                // Main content area
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _isLoading
                            ? const FeedShimmer()
                            : visiblePosts.isEmpty
                            ? _buildEmptyState()
                            : GestureDetector(
                                onVerticalDragStart: _handleDragStart,
                                onVerticalDragUpdate: _handleDragUpdate,
                                onVerticalDragEnd: _handleDragEnd,
                                child: RepaintBoundary(
                                  child: AnimatedBuilder(
                                    animation: _flipController,
                                    builder: (context, _) {
                                      final nextIndex =
                                          _nextVisibleIndexForCurrent(
                                            visiblePosts,
                                          );
                                      final previousIndex =
                                          _previousVisibleIndexForCurrent(
                                            visiblePosts,
                                          );
                                      return FlipPageView(
                                        currentPost:
                                            visiblePosts[_currentIndex.clamp(
                                              0,
                                              visiblePosts.length - 1,
                                            )],
                                        nextPost: nextIndex == null
                                            ? null
                                            : visiblePosts[nextIndex],
                                        previousPost: previousIndex == null
                                            ? null
                                            : visiblePosts[previousIndex],
                                        dragProgress: _dragProgress,
                                        cardBuilder: (post) {
                                          final index =
                                              visibleIndexById[post.id] ?? 0;
                                          return _buildPostCard(
                                            post,
                                            index,
                                            index ==
                                                _currentIndex.clamp(
                                                  0,
                                                  visiblePosts.length - 1,
                                                ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                      ),
                      if (isContentCreator) _buildFloatingCreateButton(),
                      if (_isBackgroundRefreshing && !_isLoading)
                        Positioned(
                          top: 10,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceOf(
                                  context,
                                ).withValues(alpha: 0.96),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    height: 14,
                                    width: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Refreshing feed...',
                                    style: TextStyle(
                                      color: AppColors.textSecondaryOf(context),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  Widget _buildThinTopBar(bool isContentCreator) {
    final hasWorkspaceAccess =
        widget.currentUser.canModerate ||
        widget.currentUser.role == UserRole.reporter;

    return Container(
      height: 52,
      margin: const EdgeInsets.fromLTRB(10, 2, 10, 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dividerOf(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _openFocusLanding(),
              child: Row(
                children: [
                  Image.asset(
                    'Focus_Today_icon.png',
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.newspaper_rounded, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Focus Today',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimaryOf(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasWorkspaceAccess) _buildAdminToolsMenu(),
              _buildTopIconAction(
                icon: Icons.vertical_align_top_rounded,
                semanticLabel: 'Reset feed to top',
                onTap: () => _resetFeedToTop(),
              ),
              const SizedBox(width: 6),
              _buildTopIconAction(
                icon: Icons.translate_rounded,
                semanticLabel: AppLocalizations(
                  _currentLanguage,
                ).changeLanguageLabel,
                onTap: _toggleLanguage,
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    SmoothPageRoute(
                      builder: (_) =>
                          NotificationsScreen(currentUser: widget.currentUser),
                    ),
                  );
                  _loadUnreadCount();
                },
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          Icons.notifications_rounded,
                          color: AppColors.textPrimaryOf(context),
                          size: 19,
                        ),
                      ),
                      if (_unreadNotifCount > 0)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    SmoothPageRoute(
                      builder: (_) =>
                          ProfileScreen(currentUser: widget.currentUser),
                    ),
                  );
                  _loadPosts(forceRefresh: true);
                },
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: _buildHeaderProfileAvatar(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopIconAction({
    required IconData icon,
    required String semanticLabel,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.dividerOf(context)),
          ),
          child: Icon(icon, color: AppColors.textPrimaryOf(context), size: 18),
        ),
      ),
    );
  }

  Widget _buildFloatingCreateButton() {
    return Positioned(
      right: 14,
      bottom: 16,
      child: GestureDetector(
        onTap: () async {
          await Navigator.push(
            context,
            SmoothPageRoute(
              builder: (_) => CreatePostScreen(currentUser: widget.currentUser),
            ),
          );
          _loadPosts(forceRefresh: true);
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildAdminToolsMenu() {
    final hasWorkspaceAccess =
        widget.currentUser.canModerate ||
        widget.currentUser.role == UserRole.reporter;

    if (!hasWorkspaceAccess) return const SizedBox();

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        unawaited(
          _telemetry.trackHeaderAction(
            user: widget.currentUser,
            screen: 'feed',
            action: 'workspace_open',
          ),
        );
        Navigator.push(
          context,
          SmoothPageRoute(
            builder: (_) => WorkspaceScreen(
              currentUser: widget.currentUser,
              currentLanguage: _currentLanguage,
            ),
          ),
        );
      },
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            const Center(
              child: Icon(
                Icons.admin_panel_settings_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            if (_pendingCount > 0 && widget.currentUser.canModerate)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$_pendingCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildAppBar(bool isContentCreator) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _openFocusLanding(),
              child: Row(
                children: [
                  Image.asset(
                    'Focus_Today_icon.png',
                    width: 28,
                    height: 28,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.newspaper_rounded, size: 24),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Focus Today',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimaryOf(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildAdminToolsMenu(),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _toggleLanguage,
            child: Semantics(
              button: true,
              label: AppLocalizations(_currentLanguage).changeLanguageLabel,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.translate_rounded,
                  color: AppColors.textPrimaryOf(context),
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                SmoothPageRoute(
                  builder: (_) =>
                      NotificationsScreen(currentUser: widget.currentUser),
                ),
              );
              _loadUnreadCount();
            },
            child: Semantics(
              button: true,
              label: AppLocalizations(_currentLanguage).openNotificationsLabel,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.notifications_rounded,
                        color: AppColors.textPrimaryOf(context),
                        size: 22,
                      ),
                    ),
                    if (_unreadNotifCount > 0)
                      Positioned(
                        top: 5,
                        right: 5,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.surfaceOf(context),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                SmoothPageRoute(
                  builder: (_) =>
                      ProfileScreen(currentUser: widget.currentUser),
                ),
              );
              _loadPosts(forceRefresh: true);
            },
            child: Semantics(
              button: true,
              label: AppLocalizations(_currentLanguage).openProfileLabel,
              child: _buildHeaderProfileAvatar(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderProfileAvatar() {
    final imageUrl = widget.currentUser.profilePicture?.trim();
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildHeaderProfileFallback(),
        ),
      );
    }
    return _buildHeaderProfileFallback();
  }

  Widget _buildHeaderProfileFallback() {
    final display = widget.currentUser.displayName.trim();
    final initial = display.isNotEmpty ? display[0].toUpperCase() : 'U';
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surfaceTier2Of(context),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: AppColors.textPrimaryOf(context),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildEditorialDiscoveryBar() {
    final dynamicCategories = _posts
        .map((e) => e.category)
        .toSet()
        .toList(growable: false);
    final categories = [
      'Top Stories',
      'Trending Topics',
      'Local To You',
      'Explainers',
      ...dynamicCategories.take(4),
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final label = categories[index];
          final selected =
              _selectedCategory == label ||
              (_selectedCategory == null && label == 'Top Stories');
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              unawaited(
                _telemetry.trackDiscoveryTap(
                  user: widget.currentUser,
                  screen: 'feed',
                  railLabel: label,
                  selected: selected,
                ),
              );
              setState(() {
                if (label == 'Top Stories' ||
                    label == 'Trending Topics' ||
                    label == 'Local To You' ||
                    label == 'Explainers') {
                  _selectedCategory = null;
                } else {
                  _selectedCategory = selected ? null : label;
                }
                _currentIndex = 0;
                _setDragProgress(0.0);
              });
              _scheduleWarmLocalizedTextWindow(includePrev: false);
              unawaited(_syncVideoWindowControllers());
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.14)
                    : AppColors.surfaceTier2Of(context),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.4)
                      : AppColors.dividerOf(context),
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? AppColors.primary
                        : AppColors.textMutedOf(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: categories.length,
      ),
    );
  }

  // ignore: unused_element
  Widget _buildBottomNav(bool isContentCreator) {
    if (_posts.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        children: [
          // Page counter pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.textSecondaryOf(context).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${_currentIndex + 1}',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: ' / ${_posts.length}',
                    style: TextStyle(
                      color: AppColors.textSecondaryOf(context),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Swipe hint (subtle)
          Row(
            children: [
              Icon(
                Icons.swipe_vertical_rounded,
                color: AppColors.textSecondaryOf(
                  context,
                ).withValues(alpha: 0.4),
                size: 15,
              ),
              const SizedBox(width: 4),
              Text(
                AppLocalizations(_currentLanguage).scrollToRead,
                style: TextStyle(
                  color: AppColors.textSecondaryOf(
                    context,
                  ).withValues(alpha: 0.4),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Create button for content creators
          if (isContentCreator)
            GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  SmoothPageRoute(
                    builder: (_) =>
                        CreatePostScreen(currentUser: widget.currentUser),
                  ),
                );
                _loadPosts(forceRefresh: true);
              },
              child: Semantics(
                button: true,
                label: AppLocalizations(_currentLanguage).createPost,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showProfileCompletionPrompt() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.person_add_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations(_currentLanguage).completeYourAccount,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    AppLocalizations(
                      _currentLanguage,
                    ).addNamePhotoPreferencesInSettings,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: AppLocalizations(_currentLanguage).openSettingsLabel,
          textColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              SmoothPageRoute(
                builder: (_) => SettingsScreen(currentUser: widget.currentUser),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isContentCreator =
        widget.currentUser.role == UserRole.superAdmin ||
        widget.currentUser.role == UserRole.admin ||
        widget.currentUser.role == UserRole.reporter;

    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.15),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isContentCreator
                      ? Icons.edit_note_rounded
                      : Icons.article_outlined,
                  size: 72,
                  color: AppColors.textSecondaryOf(
                    context,
                  ).withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations(_currentLanguage).noPostsYet,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
                if (isContentCreator) ...[
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations(_currentLanguage).tapToCreateFirstPost,
                    style: TextStyle(
                      color: AppColors.textSecondaryOf(
                        context,
                      ).withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        SmoothPageRoute(
                          builder: (_) =>
                              CreatePostScreen(currentUser: widget.currentUser),
                        ),
                      );
                      _loadPosts(forceRefresh: true);
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: Text(AppLocalizations(_currentLanguage).createPost),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations(_currentLanguage).pullDownToRefresh,
                    style: TextStyle(
                      color: AppColors.textSecondaryOf(
                        context,
                      ).withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
