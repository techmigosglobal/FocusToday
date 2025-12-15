import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

/// Article/Story Viewer Widget
/// Displays long-form text content with proper formatting
class ArticleViewerWidget extends StatelessWidget {
  final String content;
  final String title;
  final bool isPreview;

  const ArticleViewerWidget({
    super.key,
    required this.content,
    required this.title,
    this.isPreview = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isPreview) {
      return _buildPreview(context);
    }

    return _buildFullArticle(context);
  }

  Widget _buildPreview(BuildContext context) {
    // Show first 200 characters for preview
    final previewText = content.length > 200
        ? '${content.substring(0, 200)}...'
        : content;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.secondary.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.article_outlined,
            size: 48,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          Text(
            previewText,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Colors.black87,
            ),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Center(
            child: Text(
              'Tap to read full article',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullArticle(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Article'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bookmarked!')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share feature coming soon!')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  _calculateReadTime(),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            Text(
              content,
              style: const TextStyle(
                fontSize: 16,
                height: 1.8,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _calculateReadTime() {
    final wordCount = content.split(' ').length;
    final minutes = (wordCount / 200).ceil(); // Average reading speed: 200 words/min
    return '$minutes min read';
  }
}
