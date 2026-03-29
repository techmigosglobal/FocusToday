import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../core/services/language_service.dart';
import '../../../../shared/models/post.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/page_transitions.dart';
import '../../../feed/presentation/screens/post_detail_screen.dart';
import '../../../../main.dart';

/// Bookmarks Grid View
/// Displays bookmarked posts in a grid layout
class BookmarksGridView extends StatefulWidget {
  final List<Post> bookmarks;
  final Function(Post) onRemoveBookmark;
  final User currentUser;

  const BookmarksGridView({
    super.key,
    required this.bookmarks,
    required this.onRemoveBookmark,
    required this.currentUser,
  });

  @override
  State<BookmarksGridView> createState() => _BookmarksGridViewState();
}

class _BookmarksGridViewState extends State<BookmarksGridView> {
  @override
  Widget build(BuildContext context) {
    if (widget.bookmarks.isEmpty) {
      return EmptyStateWidget.noBookmarks();
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: AppDimensions.responsiveGridCount(context),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: widget.bookmarks.length,
      itemBuilder: (context, index) {
        final post = widget.bookmarks[index];
        return _buildBookmarkTile(context, post);
      },
    );
  }

  Widget _buildBookmarkTile(BuildContext context, Post post) {
    return GestureDetector(
      onTap: () async {
        final languageService =
            FocusTodayApp.languageService ?? await LanguageService.init();
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
      onLongPress: () => _showRemoveDialog(post),
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

          // Bookmark indicator
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bookmark,
                color: AppColors.onPrimaryOf(context),
                size: 16,
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
              color: AppColors.textPrimaryOf(context).withValues(alpha: 0.7),
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

  void _showRemoveDialog(Post post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Bookmark'),
        content: const Text('Do you want to remove this post from bookmarks?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onRemoveBookmark(post);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
