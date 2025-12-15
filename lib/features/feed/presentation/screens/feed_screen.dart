import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/models/post.dart';
import '../../../../shared/models/user.dart';
import '../widgets/vertical_content_card.dart';
import '../animations/flip_card_animation.dart';
import '../../data/sample_post_data_enhanced.dart';
import 'create_post_screen.dart';
import '../../../moderation/presentation/screens/moderation_screen.dart';
import '../../data/repositories/post_repository.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../search/presentation/screens/explore_screen.dart';
import '../../../../core/services/language_service.dart';
import '../../../../shared/widgets/skeleton_loader_widget.dart';

/// Feed Screen - Vertical flip feed inspired by Way2News
class FeedScreen extends StatefulWidget {
  final User currentUser;

  const FeedScreen({super.key, required this.currentUser});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Post> _posts = [];
  bool _isLoading = true;
  int _pendingCount = 0;
  late PageController _pageController;
  final PostRepository _postRepo = PostRepository();
  late LanguageService _languageService;
  AppLanguage _currentLanguage = AppLanguage.english;
  double _scrollOffset = 0.0;

  final Set<int> _likedPosts = {};

  // Language change listener
  VoidCallback? _languageListener;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(() {
      setState(() {
        _scrollOffset = _pageController.offset;
      });
    });
    _initLanguage();
    _loadPosts();
  }

  Future<void> _initLanguage() async {
    _languageService = await LanguageService.init();
    // Define listener
    _languageListener = () {
      if (mounted) {
        setState(() {
          _currentLanguage = _languageService.currentLanguage;
        });
      }
    };
    // Add listener
    _languageService.addListener(_languageListener!);
    // Initial language
    setState(() {
      _currentLanguage = _languageService.currentLanguage;
    });
  }

  @override
  void dispose() {
    // Remove language listener
    if (_languageListener != null) {
      _languageService.removeListener(_languageListener!);
    }
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);

    try {
      final posts = await _postRepo.getApprovedPosts(limit: 50);

      // Load pending count for admin
      if (widget.currentUser.role == UserRole.admin) {
        final pending = await _postRepo.getPendingPostsCount();
        setState(() => _pendingCount = pending);
      }

      setState(() {
        _posts = posts.isNotEmpty ? posts : _generateSamplePosts();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _posts = _generateSamplePosts();
        _isLoading = false;
      });
    }
  }

  List<Post> _generateSamplePosts() {
    // Import and use enhanced sample data
    return SamplePostDataEnhanced.generateSamplePosts();
  }

  Future<void> _toggleLanguage() async {
    await _languageService.cycleLanguage();
    setState(() {
      _currentLanguage = _languageService.currentLanguage;
    });
  }

  void _toggleLike(int postIndex) {
    // Add haptic feedback for premium feel
    HapticFeedback.lightImpact();
    setState(() {
      if (_likedPosts.contains(postIndex)) {
        _likedPosts.remove(postIndex);
      } else {
        _likedPosts.add(postIndex);
      }
    });
    // Future: Persist to database and update post
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const FeedCardSkeleton()
          : _posts.isEmpty
          ? _buildEmptyState()
          : Stack(
              children: [
                // Vertical PageView with Custom Physics
                PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  physics: const SnapPageScrollPhysics(),
                  itemCount: _posts.length,
                  itemBuilder: (context, index) {
                    return FlipCardAnimation(
                      index: index,
                      scrollOffset: _scrollOffset,
                      child: VerticalContentCard(
                        post: _posts[index],
                        currentLanguage: _currentLanguage,
                        onLike: () => _toggleLike(index),
                        onComment: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Comments coming soon!'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        isLiked: _likedPosts.contains(index),
                      ),
                    );
                  },
                ),

                // Top overlay with icons
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.only(
                      top: 50,
                      left: 16,
                      right: 16,
                      bottom: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.4),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // App icon/logo
                        const Icon(Icons.tv, color: Colors.white, size: 28),

                        // Action icons
                        Row(
                          children: [
                            // Moderation badge (Admin only)
                            if (widget.currentUser.role == UserRole.admin)
                              Stack(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.admin_panel_settings,
                                      color: Colors.white,
                                    ),
                                    onPressed: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ModerationScreen(
                                            currentUser: widget.currentUser,
                                          ),
                                        ),
                                      );
                                      _loadPosts();
                                    },
                                  ),
                                  if (_pendingCount > 0)
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 16,
                                          minHeight: 16,
                                        ),
                                        child: Text(
                                          _pendingCount.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                            // Profile icon
                            IconButton(
                              icon: const Icon(
                                Icons.person_outline,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProfileScreen(
                                      currentUser: widget.currentUser,
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Language toggle icon
                            IconButton(
                              icon: const Icon(
                                Icons.language,
                                color: Colors.white,
                              ),
                              onPressed: _toggleLanguage,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom navigation
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNavItem(Icons.home, 'Home', true, () {}),
                        _buildNavItem(
                          Icons.explore_outlined,
                          'Explore',
                          false,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ExploreScreen(
                                  currentUser: widget.currentUser,
                                ),
                              ),
                            );
                          },
                        ),
                        _buildNavItem(
                          Icons.person_outline,
                          'Profile',
                          false,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProfileScreen(
                                  currentUser: widget.currentUser,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

      // FAB for create post (Admin/Reporter)
      floatingActionButton:
          (widget.currentUser.role == UserRole.admin ||
              widget.currentUser.role == UserRole.reporter)
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CreatePostScreen(currentUser: widget.currentUser),
                  ),
                );
                _loadPosts();
              },
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.article_outlined,
            size: 64,
            color: AppColors.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No posts yet',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
