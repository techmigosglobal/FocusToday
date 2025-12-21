import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/models/post.dart';
import '../../../../shared/models/user.dart';
import '../../../feed/presentation/screens/post_detail_screen.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/localization/app_localizations.dart';

/// Posts Grid View
/// Displays user's posts in a grid layout
class PostsGridView extends StatefulWidget {
  final List<Post> posts;
  final bool isOwnProfile;
  final VoidCallback? onPostTap;
  final User currentUser; // Added currentUser field

  const PostsGridView({
    super.key,
    required this.posts,
    this.isOwnProfile = false,
    this.onPostTap,
    required this.currentUser, // Added currentUser to constructor
  });

  @override
  State<PostsGridView> createState() => _PostsGridViewState();
}

class _PostsGridViewState extends State<PostsGridView> {
  AppLanguage _currentLanguage = AppLanguage.english;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final languageService = await LanguageService.init();
    if (mounted) {
      setState(() {
        _currentLanguage = languageService.currentLanguage;
      });
    }
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
              color: AppColors.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              localizations.noPostsYet,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
            ),
            if (widget.isOwnProfile) ...[
              const SizedBox(height: 8),
              Text(
                localizations.startCreatingContent,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
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
        final languageService = await LanguageService.init();
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
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
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.divider),
            ),
            child:
                post.contentType == ContentType.image && post.mediaUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      post.mediaUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _buildDefaultThumbnail(post),
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
                      : Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  post.status == PostStatus.pending ? 'Pending' : 'Rejected',
                  style: const TextStyle(
                    color: Colors.white,
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
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      post.likesCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
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
            post.caption.length > 50
                ? '${post.caption.substring(0, 50)}...'
                : post.caption,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textPrimary.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoThumbnail() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          Icons.play_circle_outline,
          size: 32,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}
