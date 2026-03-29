import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

/// Profile Stats Widget
/// Displays user statistics with animated counters
import '../../../../core/services/language_service.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/models/user.dart';

/// Profile Stats Widget
/// Displays user statistics with animated counters
class ProfileStatsWidget extends StatefulWidget {
  final int postsCount;
  final int bookmarksCount;
  final AppLanguage currentLanguage;
  final UserRole? userRole;

  const ProfileStatsWidget({
    super.key,
    required this.postsCount,
    required this.bookmarksCount,
    required this.currentLanguage,
    this.userRole,
  });

  @override
  State<ProfileStatsWidget> createState() => _ProfileStatsWidgetState();
}

class _ProfileStatsWidgetState extends State<ProfileStatsWidget> {
  /// Whether to show followers/following (hidden for public and reporter roles)

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations(widget.currentLanguage);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: _buildStatItem(
            context,
            label: localizations.saved,
            value: widget.bookmarksCount,
            icon: Icons.bookmark_rounded,
            color: AppColors.accent,
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required String label,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              _formatNumber(animatedValue),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: 11,
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
