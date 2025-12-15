import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

/// Profile Stats Widget
/// Displays user statistics (posts count, bookmarks count)
class ProfileStatsWidget extends StatelessWidget {
  final int postsCount;
  final int bookmarksCount;

  const ProfileStatsWidget({
    super.key,
    required this.postsCount,
    required this.bookmarksCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(
            context,
            label: 'Posts',
            value: postsCount,
            icon: Icons.article,
          ),
          Container(
            width: 1,
            height: 40,
            color: AppColors.divider,
          ),
          _buildStatItem(
            context,
            label: 'Bookmarks',
            value: bookmarksCount,
            icon: Icons.bookmark,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required String label,
    required int value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              value.toString(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}
