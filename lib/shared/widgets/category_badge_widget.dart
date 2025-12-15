import 'package:flutter/material.dart';

/// Category Badge Widget
/// Colored category badge for content cards
class CategoryBadgeWidget extends StatelessWidget {
  final String category;

  const CategoryBadgeWidget({
    super.key,
    required this.category,
  });

  Color _getCategoryColor() {
    switch (category.toLowerCase()) {
      case 'news':
        return Colors.blue;
      case 'entertainment':
        return Colors.purple;
      case 'sports':
        return Colors.green;
      case 'politics':
        return Colors.red;
      case 'technology':
        return Colors.cyan;
      case 'health':
        return Colors.pink;
      case 'business':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getCategoryColor(),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        category,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
