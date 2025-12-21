import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/models/post.dart';
import '../../data/repositories/profile_repository.dart';
import '../widgets/profile_stats_widget.dart';
import '../widgets/posts_grid_view.dart';
import '../widgets/bookmarks_grid_view.dart';
import 'edit_profile_screen.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/presentation/screens/phone_login_screen.dart';
import '../../../subscription/presentation/screens/subscription_plans_screen.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/language_toggle_widget.dart';

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
    with SingleTickerProviderStateMixin {
  final ProfileRepository _profileRepo = ProfileRepository();
  late TabController _tabController;

  int _postsCount = 0;
  int _bookmarksCount = 0;
  List<Post> _posts = [];
  List<Post> _bookmarks = [];
  bool _isLoading = true;
  LanguageService? _languageService;
  AppLanguage _currentLanguage = AppLanguage.english;

  User get displayUser => widget.profileUser ?? widget.currentUser;
  bool get isOwnProfile =>
      widget.profileUser == null ||
      widget.profileUser!.id == widget.currentUser.id;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: isOwnProfile ? 2 : 1, vsync: this);
    _loadLanguage();
    _loadProfileData();
  }

  Future<void> _loadLanguage() async {
    _languageService = await LanguageService.init();
    if (mounted) {
      setState(() {
        _currentLanguage = _languageService!.currentLanguage;
      });
    }
  }

  Future<void> _toggleLanguage() async {
    if (_languageService == null) return;
    await _languageService!.cycleLanguage();
    if (mounted) {
      setState(() {
        _currentLanguage = _languageService!.currentLanguage;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);

    try {
      // Load posts count and posts
      final postsCount = isOwnProfile
          ? await _profileRepo.getUserAllPostsCount(displayUser.id)
          : await _profileRepo.getUserPostsCount(displayUser.id);

      final posts = await _profileRepo.getUserPosts(
        displayUser.id,
        includeAll: isOwnProfile,
      );

      // Load bookmarks only for own profile
      int bookmarksCount = 0;
      List<Post> bookmarks = [];
      if (isOwnProfile) {
        bookmarksCount = await _profileRepo.getUserBookmarksCount(
          displayUser.id,
        );
        bookmarks = await _profileRepo.getUserBookmarks(displayUser.id);
      }

      setState(() {
        _postsCount = postsCount;
        _bookmarksCount = bookmarksCount;
        _posts = posts;
        _bookmarks = bookmarks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    }
  }

  Future<void> _handleRemoveBookmark(Post post) async {
    try {
      await _profileRepo.removeBookmark(post.id, displayUser.id);
      await _loadProfileData(); // Reload to update counts

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bookmark removed'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error removing bookmark: $e')));
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authRepo = await AuthRepository.init();
      await authRepo.logout();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations(_currentLanguage);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isOwnProfile ? localizations.profile : displayUser.displayName,
        ),
        actions: [
          if (isOwnProfile) ...[
            Center(
              child: LanguageToggleWidget(
                currentLanguage: _currentLanguage,
                onTap: _toggleLanguage,
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (isOwnProfile)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _handleLogout,
              tooltip: localizations.logout,
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : Column(
              children: [
                // Profile header
                _buildProfileHeader(),
                const SizedBox(height: 8),

                // Stats
                ProfileStatsWidget(
                  postsCount: _postsCount,
                  bookmarksCount: _bookmarksCount,
                ),
                const Divider(),

                // Tabs
                if (isOwnProfile)
                  TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primary,
                    indicatorColor: AppColors.primary,
                    tabs: [
                      Tab(text: localizations.posts, icon: Icon(Icons.grid_on)),
                      Tab(
                        text: localizations.bookmarks,
                        icon: Icon(Icons.bookmark),
                      ),
                    ],
                  ),

                // Tab views
                Expanded(
                  child: isOwnProfile
                      ? TabBarView(
                          controller: _tabController,
                          children: [
                            PostsGridView(
                              posts: _posts,
                              isOwnProfile: isOwnProfile,
                              currentUser: widget.currentUser,
                            ),
                            BookmarksGridView(
                              bookmarks: _bookmarks,
                              onRemoveBookmark: _handleRemoveBookmark,
                            ),
                          ],
                        )
                      : PostsGridView(
                          posts: _posts,
                          isOwnProfile: isOwnProfile,
                          currentUser: widget.currentUser,
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildProfileHeader() {
    final localizations = AppLocalizations(_currentLanguage);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Avatar and edit button
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primary,
                child: displayUser.profilePicture != null
                    ? ClipOval(
                        child: Image.network(
                          displayUser.profilePicture!,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.person,
                            size: 40,
                            color: AppColors.background,
                          ),
                        ),
                      )
                    : Icon(Icons.person, size: 40, color: AppColors.background),
              ),
              const SizedBox(width: 16),

              // Name and role
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
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getRoleColor().withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getRoleText(),
                        style: TextStyle(
                          color: _getRoleColor(),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Edit button
              if (isOwnProfile)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            EditProfileScreen(currentUser: widget.currentUser),
                      ),
                    );

                    if (result == true) {
                      // Reload profile data after edit
                      _loadProfileData();
                    }
                  },
                ),
            ],
          ),

          // Bio
          if (displayUser.bio != null && displayUser.bio!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              displayUser.bio!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],

          // Subscription button for public users
          if (isOwnProfile && displayUser.role == UserRole.publicUser) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SubscriptionPlansScreen(userId: displayUser.id),
                  ),
                );
              },
              icon: const Icon(Icons.star),
              label: Text(localizations.upgradeToPremium),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getRoleText() {
    switch (displayUser.role) {
      case UserRole.admin:
        return 'ADMIN';
      case UserRole.reporter:
        return 'REPORTER';
      case UserRole.publicUser:
        return 'PUBLIC USER';
    }
  }

  Color _getRoleColor() {
    switch (displayUser.role) {
      case UserRole.admin:
        return Colors.red;
      case UserRole.reporter:
        return AppColors.secondary;
      case UserRole.publicUser:
        return AppColors.primary;
    }
  }
}
