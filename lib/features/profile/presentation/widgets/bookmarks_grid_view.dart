import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/models/post.dart';

/// Bookmarks Grid View
/// Displays bookmarked posts in a grid layout
class BookmarksGridView extends StatefulWidget {
  final List<Post> bookmarks;
  final Function(Post) onRemoveBookmark;

  const BookmarksGridView({
    super.key,
    required this.bookmarks,
    required this.onRemoveBookmark,
  });

  @override
  State<BookmarksGridView> createState() => _BookmarksGridViewState();
}

class _BookmarksGridViewState extends State<BookmarksGridView> {
  @override
  Widget build(BuildContext context) {
    if (widget.bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No bookmarks yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bookmark posts to save them here',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
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
      itemCount: widget.bookmarks.length,
      itemBuilder: (context, index) {
        final post = widget.bookmarks[index];
        return _buildBookmarkTile(context, post);
      },
    );
  }

  Widget _buildBookmarkTile(BuildContext context, Post post) {
    return GestureDetector(
      onTap: () {
        // Future: Navigate to post detail
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post detail coming soon!'),
            duration: Duration(seconds: 1),
          ),
        );
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
            child: post.contentType == ContentType.image && post.mediaUrl != null
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
              child: const Icon(
                Icons.bookmark,
                color: Colors.white,
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
