import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

/// Category Badge Widget
/// Colored category badge for content cards
class CategoryBadgeWidget extends StatelessWidget {
  final String category;

  const CategoryBadgeWidget({super.key, required this.category});

  Color _getCategoryColor() {
    switch (category.toLowerCase()) {
      case 'news':
        return AppColors.primary;

      case 'sports':
        return AppColors.secondary;
      case 'politics':
        return Colors.red;
      case 'technology':
        return Colors.cyan;
      case 'health':
        return Colors.pink;
      case 'business':
        return AppColors.accent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getCategoryColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        category,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
