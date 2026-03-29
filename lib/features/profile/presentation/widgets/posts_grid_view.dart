import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../shared/models/post.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/widgets/page_transitions.dart';
import '../../../feed/presentation/screens/post_detail_screen.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../main.dart';

/// Posts Grid View
/// Displays user's posts in a grid layout
class PostsGridView extends StatefulWidget {
  final List<Post> posts;
  final bool isOwnProfile;
  final VoidCallback? onPostTap;
  final User currentUser;
  final String? emptyMessage;

  const PostsGridView({
    super.key,
    required this.posts,
    this.isOwnProfile = false,
    this.onPostTap,
    required this.currentUser,
    this.emptyMessage,
  });

  @override
  State<PostsGridView> createState() => _PostsGridViewState();
}

class _PostsGridViewState extends State<PostsGridView> {
  AppLanguage _currentLanguage = AppLanguage.english;
  LanguageService? _languageService;
  bool _isLanguageListenerAttached = false;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  @override
  void dispose() {
    if (_isLanguageListenerAttached && _languageService != null) {
      _languageService!.removeListener(_handleLanguageChange);
      _isLanguageListenerAttached = false;
    }
    super.dispose();
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
    if (mounted) {
      setState(() {
        _currentLanguage = languageService.currentLanguage;
      });
    }
  }

  void _handleLanguageChange() {
    final languageService = _languageService;
    if (!mounted || languageService == null) return;
    final nextLanguage = languageService.currentLanguage;
    if (nextLanguage == _currentLanguage) return;
    setState(() => _currentLanguage = nextLanguage);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations(_currentLanguage);

    if (widget.posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              widget.emptyMessage ?? localizations.noPostsYet,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            if (widget.isOwnProfile) ...[
              const SizedBox(height: 8),
              Text(
                localizations.startCreatingContent,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: AppDimensions.responsiveGridCount(context),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: widget.posts.length,
      itemBuilder: (context, index) {
        final post = widget.posts[index];
        return _buildPostTile(context, post);
      },
    );
  }

  Widget _buildPostTile(BuildContext context, Post post) {
    return GestureDetector(
      onTap: () async {
        final languageService =
            _languageService ??
            FocusTodayApp.languageService ??
            await LanguageService.init();
        FocusTodayApp.languageService ??= languageService;
        if (context.mounted) {
          Navigator.push(
            context,
            SmoothPageRoute(
              builder: (_) => PostDetailScreen(
                post: post,
                currentUser: widget.currentUser,
                currentLanguage: languageService.currentLanguage,
              ),
            ),
          );
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Post thumbnail
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child:
                post.contentType == ContentType.image && post.mediaUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: post.mediaUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      memCacheWidth: 360,
                      fadeInDuration: const Duration(milliseconds: 150),
                      errorWidget: (_, _, _) => _buildDefaultThumbnail(post),
                    ),
                  )
                : post.contentType == ContentType.video && post.mediaUrl != null
                ? _buildVideoThumbnail()
                : _buildDefaultThumbnail(post),
          ),

          // Status indicator for own profile
          if (widget.isOwnProfile && post.status != PostStatus.approved)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: post.status == PostStatus.pending
                      ? AppColors.warning
                      : AppColors.destructiveFgOf(context),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  post.status == PostStatus.pending ? 'Pending' : 'Rejected',
                  style: TextStyle(
                    color: AppColors.onPrimaryOf(context),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // Like count overlay
          if (post.likesCount > 0)
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.overlayStrongOf(context),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite,
                      color: AppColors.onPrimaryOf(context),
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      post.likesCount.toString(),
                      style: TextStyle(
                        color: AppColors.onPrimaryOf(context),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultThumbnail(Post post) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.secondary.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            post.getLocalizedCaption(_currentLanguage.code).length > 50
                ? '${post.getLocalizedCaption(_currentLanguage.code).substring(0, 50)}...'
                : post.getLocalizedCaption(_currentLanguage.code),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(
                context,
              ).textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoThumbnail() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.overlayStrongOf(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          Icons.play_circle_outline,
          size: 32,
          color: AppColors.onPrimaryOf(context).withValues(alpha: 0.9),
        ),
      ),
    );
  }
}
