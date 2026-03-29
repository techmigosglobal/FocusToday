import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/config/feature_flags.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/models/post.dart';
import '../../data/repositories/profile_repository.dart';
import '../widgets/profile_stats_widget.dart';
import '../widgets/bookmarks_grid_view.dart';
import 'edit_profile_screen.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/post_sync_service.dart';
import '../../../../core/services/user_sync_service.dart';
import '../../../../shared/widgets/page_transitions.dart';
import '../../../../shared/widgets/slice_surface.dart';
import '../../../enrollment/presentation/screens/reporter_application_screen.dart';
import '../../../../main.dart';

/// Profile Screen
/// Displays user profile with stats, posts, and bookmarks
class ProfileScreen extends StatefulWidget {
  final User currentUser;
  final User? profileUser; // If viewing another user's profile

  const ProfileScreen({super.key, required this.currentUser, this.profileUser});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  final ProfileRepository _profileRepo = ProfileRepository();
  int _bookmarksCount = 0;
  List<Post> _bookmarks = [];
  bool _isLoading = true;
  bool _hasError = false;
  AppLanguage _currentLanguage = AppLanguage.english;
  LanguageService? _languageService;
  bool _isLanguageListenerAttached = false;
  StreamSubscription<PostSyncEvent>? _postSyncSubscription;
  StreamSubscription<UserSyncEvent>? _userSyncSubscription;
  Timer? _refreshDebounce;
  DateTime? _lastLoadedAt;
  User? _latestDisplayUser;

  User get displayUser =>
      _latestDisplayUser ?? widget.profileUser ?? widget.currentUser;
  bool get isOwnProfile =>
      widget.profileUser == null ||
      widget.profileUser!.id == widget.currentUser.id;

  List<String> get _missingProfileFields {
    final missing = <String>[];
    if (displayUser.bio == null || displayUser.bio!.trim().isEmpty) {
      missing.add('Bio');
    }
    if (displayUser.area == null || displayUser.area!.trim().isEmpty) {
      missing.add('Area');
    }
    if (displayUser.district == null || displayUser.district!.trim().isEmpty) {
      missing.add('District');
    }
    if (displayUser.state == null || displayUser.state!.trim().isEmpty) {
      missing.add('State');
    }
    if (displayUser.profilePicture == null ||
        displayUser.profilePicture!.trim().isEmpty) {
      missing.add('Profile Photo');
    }
    return missing;
  }

  int get _profileCompleteness {
    const total = 5;
    final filled = total - _missingProfileFields.length;
    return ((filled / total) * 100).round();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenToPostSync();
    _listenToUserSync();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileData();
      _loadLanguage();
    });
  }

  Future<void> _loadLanguage() async {
    final languageService =
        FocusTodayApp.languageService ?? await LanguageService.init();
    FocusTodayApp.languageService ??= languageService;
    _languageService = languageService;
    if (!_isLanguageListenerAttached) {
      languageService.addListener(_handleLanguageChange);
      _isLanguageListenerAttached = true;
    }
    if (!mounted) return;
    setState(() => _currentLanguage = languageService.currentLanguage);
  }

  void _handleLanguageChange() {
    final languageService = _languageService;
    if (!mounted || languageService == null) return;
    final nextLanguage = languageService.currentLanguage;
    if (nextLanguage == _currentLanguage) return;
    setState(() => _currentLanguage = nextLanguage);
  }

  @override
  void dispose() {
    if (_isLanguageListenerAttached && _languageService != null) {
      _languageService!.removeListener(_handleLanguageChange);
      _isLanguageListenerAttached = false;
    }
    WidgetsBinding.instance.removeObserver(this);
    _postSyncSubscription?.cancel();
    _userSyncSubscription?.cancel();
    _refreshDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final lastLoaded = _lastLoadedAt;
    if (lastLoaded != null &&
        DateTime.now().difference(lastLoaded) < const Duration(seconds: 10)) {
      return;
    }
    _loadProfileData();
  }

  void _listenToPostSync() {
    _postSyncSubscription = PostSyncService.stream.listen((event) {
      if (!mounted) return;
      if (event.reason == PostSyncReason.interactionChanged && !isOwnProfile) {
        return;
      }
      final isAdminOwnProfile =
          isOwnProfile &&
          (displayUser.role == UserRole.superAdmin ||
              displayUser.role == UserRole.admin);
      if (!isAdminOwnProfile &&
          event.authorId != null &&
          event.authorId != displayUser.id) {
        return;
      }

      _refreshDebounce?.cancel();
      _refreshDebounce = Timer(const Duration(milliseconds: 300), () {
        if (mounted) _loadProfileData();
      });
    });
  }

  void _listenToUserSync() {
    _userSyncSubscription = UserSyncService.stream.listen((event) {
      if (!mounted) return;
      final targetId = displayUser.id;
      if (event.userId != null && event.userId != targetId) return;
      _refreshDebounce?.cancel();
      _refreshDebounce = Timer(const Duration(milliseconds: 220), () {
        if (mounted) _loadProfileData();
      });
    });
  }

  Future<void> _loadProfileData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Load all data in parallel for better performance
      final futures = <String, Future>{};

      futures['user'] = _profileRepo.getUserById(displayUser.id);
      futures['bookmarksCount'] = _profileRepo.getUserBookmarksCount(
        displayUser.id,
      );
      futures['bookmarks'] = _profileRepo.getUserBookmarks(displayUser.id);

      // Await all in parallel
      final results = <String, dynamic>{};
      final keys = futures.keys.toList();
      final values = await Future.wait(futures.values);
      for (int i = 0; i < keys.length; i++) {
        results[keys[i]] = values[i];
      }

      final latestUser = results['user'] as User?;
      final bookmarksCount = results['bookmarksCount'] as int? ?? 0;
      final bookmarks = results['bookmarks'] as List<Post>? ?? [];

      if (!mounted) return;
      setState(() {
        _latestDisplayUser = latestUser ?? _latestDisplayUser;
        _bookmarksCount = bookmarksCount;
        _bookmarks = bookmarks;
        _isLoading = false;
        _hasError = false;
        _lastLoadedAt = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations(_currentLanguage).errorLoadingProfile}: $e',
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleRemoveBookmark(Post post) async {
    try {
      await _profileRepo.removeBookmark(post.id, displayUser.id);
      await _loadProfileData(); // Reload to update counts

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations(_currentLanguage).bookmarkRemoved),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations(_currentLanguage).errorRemovingBookmark}: $e',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          isOwnProfile
              ? AppLocalizations(_currentLanguage).profile
              : displayUser.displayName,
        ),
        actions: [
          if (isOwnProfile)
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  SmoothPageRoute(
                    builder: (_) => EditProfileScreen(
                      currentUser: widget.currentUser,
                      currentLanguage: _currentLanguage,
                    ),
                  ),
                );
                if (result == true) _loadProfileData();
              },
              tooltip: AppLocalizations(_currentLanguage).editProfile,
            ),
        ],
      ),
      body: SliceBackground(
        child:
            _buildRestrictedGuard() ??
            Builder(
              builder: (ctx) {
                if (_isLoading) {
                  return _buildProfileSkeleton();
                }
                if (_hasError) {
                  return Center(
                    child: SliceCard(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: AppColors.textSecondaryOf(ctx),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            AppLocalizations(
                              _currentLanguage,
                            ).failedToLoadProfile,
                            style: TextStyle(
                              color: AppColors.textSecondaryOf(ctx),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () {
                              setState(() => _hasError = false);
                              _loadProfileData();
                            },
                            icon: const Icon(Icons.refresh),
                            label: Text(
                              AppLocalizations(_currentLanguage).retry,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _loadProfileData,
                  child: Column(
                    children: [
                      _buildProfileHeader(),
                      if (FeatureFlags.publicPremiumRedesign &&
                          isOwnProfile &&
                          _missingProfileFields.isNotEmpty)
                        _buildProfileCompletenessCard(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: SliceCard(
                          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                          child: ProfileStatsWidget(
                            postsCount: 0,
                            bookmarksCount: _bookmarksCount,
                            currentLanguage: _currentLanguage,
                            userRole: displayUser.role,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(child: _buildBookmarksTab()),
                    ],
                  ),
                );
              },
            ),
      ),
    );
  }

  Widget _buildBookmarksTab() {
    return BookmarksGridView(
      bookmarks: _bookmarks,
      onRemoveBookmark: _handleRemoveBookmark,
      currentUser: widget.currentUser,
    );
  }

  Widget _buildProfileSkeleton() {
    final muted = AppColors.textSecondaryOf(context).withValues(alpha: 0.18);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            height: 146,
            decoration: BoxDecoration(
              color: muted,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 84,
            decoration: BoxDecoration(
              color: muted,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: muted,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Returns a restricted-access widget if the current user can't view this
  /// profile, or null if access is allowed.
  Widget? _buildRestrictedGuard() {
    if (isOwnProfile) return null;
    final role = widget.currentUser.role;
    if (role == UserRole.superAdmin || role == UserRole.admin) return null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_rounded,
              size: 64,
              color: AppColors.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Profile Restricted',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'You do not have permission to view other users\' profiles.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondaryOf(context)),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final roleColor = _getRoleColor();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: SliceCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          children: [
            // Avatar row
            Row(
              children: [
                // Avatar with gradient ring
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [roleColor, roleColor.withValues(alpha: 0.5)],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 38,
                    backgroundColor: AppColors.surfaceOf(context),
                    child: displayUser.profilePicture != null
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: displayUser.profilePicture!,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                              memCacheWidth: 160,
                              errorWidget: (_, _, _) => Icon(
                                Icons.person,
                                size: 36,
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ),
                          )
                        : Text(
                            displayUser.displayName.isNotEmpty
                                ? displayUser.displayName[0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: roleColor,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),

                // Name and role badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayUser.displayName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_getRoleIcon(), size: 14, color: roleColor),
                            const SizedBox(width: 4),
                            Text(
                              _getRoleText(),
                              style: TextStyle(
                                color: roleColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Bio
            if (displayUser.bio != null && displayUser.bio!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  displayUser.bio!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ),
            ],

            // Location
            if (_hasLocation()) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 15,
                    color: AppColors.textSecondaryOf(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _buildLocationText(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Apply as Reporter – visible only on own profile for publicUser
            if (isOwnProfile &&
                widget.currentUser.role == UserRole.publicUser) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  SmoothPageRoute(
                    builder: (_) => ReporterApplicationScreen(
                      currentUser: widget.currentUser,
                    ),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.12),
                        AppColors.primary.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Apply as Reporter',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              'Build your public credibility as a contributor',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCompletenessCard() {
    final missing = _missingProfileFields;
    final title = missing.take(2).join(', ');
    final suffix = missing.length > 2 ? ' +${missing.length - 2} more' : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: SliceCard(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Profile Completion $_profileCompleteness%',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      SmoothPageRoute(
                        builder: (_) => EditProfileScreen(
                          currentUser: widget.currentUser,
                          currentLanguage: _currentLanguage,
                        ),
                      ),
                    );
                    if (result == true) {
                      _loadProfileData();
                    }
                  },
                  child: const Text('Complete'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: _profileCompleteness / 100,
              minHeight: 6,
              borderRadius: BorderRadius.circular(99),
              backgroundColor: AppColors.surfaceTier2Of(context),
              color: AppColors.primary,
            ),
            const SizedBox(height: 8),
            Text(
              'Missing: $title$suffix',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getRoleIcon() {
    switch (displayUser.role) {
      case UserRole.superAdmin:
        return Icons.shield_rounded;
      case UserRole.admin:
        return Icons.admin_panel_settings_rounded;
      case UserRole.reporter:
        return Icons.newspaper_rounded;
      case UserRole.publicUser:
        return Icons.person_rounded;
    }
  }

  String _getRoleText() {
    switch (displayUser.role) {
      case UserRole.superAdmin:
        return AppLocalizations(_currentLanguage).superAdminLabel;
      case UserRole.admin:
        return AppLocalizations(_currentLanguage).admin.toUpperCase();
      case UserRole.reporter:
        return AppLocalizations(_currentLanguage).reporter.toUpperCase();
      case UserRole.publicUser:
        return AppLocalizations(_currentLanguage).publicUser.toUpperCase();
    }
  }

  Color _getRoleColor() {
    switch (displayUser.role) {
      case UserRole.superAdmin:
        return AppColors.errorOf(context);
      case UserRole.admin:
        return AppColors.destructiveFgOf(context);
      case UserRole.reporter:
        return AppColors.successOf(context);
      case UserRole.publicUser:
        return AppColors.primaryOf(context);
    }
  }

  bool _hasLocation() {
    return (displayUser.area != null && displayUser.area!.isNotEmpty) ||
        (displayUser.district != null && displayUser.district!.isNotEmpty) ||
        (displayUser.state != null && displayUser.state!.isNotEmpty);
  }

  String _buildLocationText() {
    final parts = <String>[];
    if (displayUser.area != null && displayUser.area!.isNotEmpty) {
      parts.add(displayUser.area!);
    }
    if (displayUser.district != null && displayUser.district!.isNotEmpty) {
      parts.add(displayUser.district!);
    }
    if (displayUser.state != null && displayUser.state!.isNotEmpty) {
      parts.add(displayUser.state!);
    }
    return parts.join(', ');
  }
}
