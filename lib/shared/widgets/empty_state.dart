import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

/// A reusable empty-state widget shown when lists have no data.
///
/// Provides an icon, title, subtitle, and optional action button.
/// Adapts to dark/light themes automatically.
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.textSecondaryOf(
                  context,
                ).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: AppColors.textSecondaryOf(
                  context,
                ).withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondaryOf(context),
                  height: 1.4,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== Common Presets ====================

  /// Empty feed
  static EmptyStateWidget noFeed({VoidCallback? onRefresh}) {
    return EmptyStateWidget(
      icon: Icons.article_outlined,
      title: 'No Posts Yet',
      subtitle: 'Pull down to refresh or check back later for new content.',
      actionLabel: onRefresh != null ? 'Refresh' : null,
      onAction: onRefresh,
    );
  }

  /// Empty notifications
  static EmptyStateWidget noNotifications() {
    return const EmptyStateWidget(
      icon: Icons.notifications_none_rounded,
      title: 'No Notifications',
      subtitle: 'You\'re all caught up! New notifications will appear here.',
    );
  }

  /// Empty search results
  static EmptyStateWidget noSearchResults() {
    return const EmptyStateWidget(
      icon: Icons.search_off_rounded,
      title: 'No Results Found',
      subtitle: 'Try searching with different keywords.',
    );
  }

  /// Empty comments
  static EmptyStateWidget noComments() {
    return const EmptyStateWidget(
      icon: Icons.chat_bubble_outline_rounded,
      title: 'No Comments Yet',
      subtitle: 'Be the first to share your thoughts!',
    );
  }

  /// Empty bookmarks
  static EmptyStateWidget noBookmarks() {
    return const EmptyStateWidget(
      icon: Icons.bookmark_border_rounded,
      title: 'No Bookmarks',
      subtitle: 'Save posts you want to read later.',
    );
  }

  /// Empty meetings
  static EmptyStateWidget noMeetings({VoidCallback? onCreate}) {
    return EmptyStateWidget(
      icon: Icons.event_busy_rounded,
      title: 'No Meetings Found',
      subtitle: 'Create your first meeting to notify users.',
      actionLabel: onCreate != null ? 'Create Meeting' : null,
      onAction: onCreate,
    );
  }

  /// No internet connection
  static EmptyStateWidget offline({VoidCallback? onRetry}) {
    return EmptyStateWidget(
      icon: Icons.wifi_off_rounded,
      title: 'No Internet Connection',
      subtitle: 'Please check your connection and try again.',
      actionLabel: onRetry != null ? 'Retry' : null,
      onAction: onRetry,
    );
  }

  /// Error state
  static EmptyStateWidget error({String? message, VoidCallback? onRetry}) {
    return EmptyStateWidget(
      icon: Icons.error_outline_rounded,
      title: 'Something Went Wrong',
      subtitle: message ?? 'An unexpected error occurred. Please try again.',
      actionLabel: onRetry != null ? 'Retry' : null,
      onAction: onRetry,
    );
  }
}
