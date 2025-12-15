import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/models/post.dart';
import '../../../../shared/models/user.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/localization/app_localizations.dart';

/// Post Options Bottom Sheet
/// Shows action options for a post
class PostOptionsBottomSheet extends StatelessWidget {
  final Post post;
  final User currentUser;
  final AppLanguage currentLanguage;

  const PostOptionsBottomSheet({
    super.key,
    required this.post,
    required this.currentUser,
    required this.currentLanguage,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations(currentLanguage);
    final isOwnPost = post.authorId == currentUser.id;
    final isAdmin = currentUser.role == UserRole.admin;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  localizations.more,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),

          // Copy Link
          _buildOption(
            context,
            icon: Icons.link,
            title: 'Copy Link',
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Link copied to clipboard!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),

          // Share
          _buildOption(
            context,
            icon: Icons.share,
            title: localizations.share,
            onTap: () {
              Navigator.pop(context);
              // Share handled by parent
            },
          ),

          // Report (if not own post)
          if (!isOwnPost)
            _buildOption(
              context,
              icon: Icons.flag_outlined,
              title: 'Report Post',
              onTap: () {
                Navigator.pop(context);
                _showReportDialog(context);
              },
            ),

          // Hide Post (if not own post)
          if (!isOwnPost)
            _buildOption(
              context,
              icon: Icons.visibility_off_outlined,
              title: 'Hide Post',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Post hidden from feed'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),

          // Delete (if own post or admin)
          if (isOwnPost || isAdmin)
            _buildOption(
              context,
              icon: Icons.delete_outline,
              title: localizations.delete,
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(context);
              },
            ),

          // Block User (Admin only, not own post)
          if (isAdmin && !isOwnPost)
            _buildOption(
              context,
              icon: Icons.block,
              title: 'Block User',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _showBlockDialog(context);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    Color? color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.textPrimary),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? AppColors.textPrimary,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Post'),
        content: const Text('Are you sure you want to report this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Post reported. Thank you for your feedback.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Post deleted'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Text('Are you sure you want to block ${post.authorName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${post.authorName} has been blocked'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }
}
