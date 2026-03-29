import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/models/post.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/page_transitions.dart';
import '../../data/repositories/post_repository.dart';
import 'edit_resubmit_screen.dart';

/// Rejected Posts Screen — Shows reporter's rejected posts with edit & resubmit option
class RejectedPostsScreen extends StatefulWidget {
  final User currentUser;

  const RejectedPostsScreen({super.key, required this.currentUser});

  @override
  State<RejectedPostsScreen> createState() => _RejectedPostsScreenState();
}

class _RejectedPostsScreenState extends State<RejectedPostsScreen> {
  final PostRepository _postRepo = PostRepository();
  List<Post> _rejectedPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRejectedPosts();
  }

  Future<void> _loadRejectedPosts() async {
    setState(() => _isLoading = true);
    try {
      final posts = await _postRepo.getRejectedPostsByAuthor(
        widget.currentUser.id,
      );
      if (mounted) {
        setState(() {
          _rejectedPosts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rejected Posts'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _rejectedPosts.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
                onRefresh: _loadRejectedPosts,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _rejectedPosts.length,
                  itemBuilder: (context, index) =>
                      _buildPostCard(_rejectedPosts[index]),
                ),
              ),
      ),
    );
  }

  Widget _buildPostCard(Post post) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status badge
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getContentTypeIcon(post.contentType),
                  color: Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    post.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'REJECTED',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Rejection reason
          if (post.rejectionReason != null &&
              post.rejectionReason!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Rejection Reason:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            post.rejectionReason!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Meta info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.category, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  post.category,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  _formatDate(post.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (post.editCount > 0) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.edit, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    'Edited ${post.editCount}x',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deletePost(post),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => _editAndResubmit(post),
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: const Text('Edit & Resubmit'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editAndResubmit(Post post) async {
    HapticFeedback.lightImpact();
    final result = await Navigator.push(
      context,
      SmoothPageRoute(
        builder: (_) =>
            EditResubmitScreen(post: post, currentUser: widget.currentUser),
      ),
    );
    if (result == true) {
      _loadRejectedPosts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post resubmitted for review!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _deletePost(Post post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post?'),
        content: const Text(
          'This action cannot be undone. The post will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _postRepo.deletePost(post.id, authorId: post.authorId);
      _loadRejectedPosts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post deleted'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Widget _buildEmptyState() {
    return const EmptyStateWidget(
      icon: Icons.check_circle_outline,
      title: 'No Rejected Posts',
      subtitle: 'All your posts are approved or pending review.',
    );
  }

  IconData _getContentTypeIcon(ContentType type) {
    switch (type) {
      case ContentType.image:
        return Icons.image;
      case ContentType.video:
        return Icons.videocam;
      case ContentType.article:
        return Icons.article;
      case ContentType.story:
        return Icons.auto_stories;
      case ContentType.poetry:
        return Icons.format_quote;
      case ContentType.pdf:
        return Icons.picture_as_pdf;
      case ContentType.none:
        return Icons.text_snippet;
    }
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }
}
