import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

/// Poetry Viewer Widget
/// Displays poetry with proper verse formatting
class PoetryViewerWidget extends StatelessWidget {
  final List<String> verses;
  final String title;
  final bool isPreview;

  const PoetryViewerWidget({
    super.key,
    required this.verses,
    required this.title,
    this.isPreview = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isPreview) {
      return _buildPreview(context);
    }

    return _buildFullPoem(context);
  }

  Widget _buildPreview(BuildContext context) {
    // Show first 4 verses for preview
    final previewVerses = verses.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.secondary.withValues(alpha: 0.15),
            AppColors.primary.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.auto_stories,
            size: 48,
            color: AppColors.secondary,
          ),
          const SizedBox(height: 24),
          ...previewVerses.map((verse) {
            if (verse.trim().isEmpty) {
              return const SizedBox(height: 8);
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                verse,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  fontStyle: FontStyle.italic,
                  color: Colors.black87,
                ),
              ),
            );
          }),
          if (verses.length > 4) ...[
            const SizedBox(height: 16),
            Text(
              '...',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const Spacer(),
          Text(
            'Tap to read full poem',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullPoem(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Poetry'),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 32),
            ...verses.map((verse) {
              if (verse.trim().isEmpty) {
                return const SizedBox(height: 24);
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  verse,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.8,
                    fontStyle: FontStyle.italic,
                    color: Colors.black87,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
