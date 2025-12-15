import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Professional Flip Card Animation
/// Provides smooth, premium Way2News-style transitions for vertical content cards
class FlipCardAnimation extends StatelessWidget {
  final Widget child;
  final int index;
  final double scrollOffset;
  final double viewportHeight;

  const FlipCardAnimation({
    super.key,
    required this.child,
    required this.index,
    required this.scrollOffset,
    this.viewportHeight = 0,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = viewportHeight > 0
        ? viewportHeight
        : MediaQuery.of(context).size.height;

    // Calculate the position of this card relative to the viewport
    final cardPosition = index * screenHeight;
    final difference = scrollOffset - cardPosition;

    // Normalized offset: -1 = above viewport, 0 = centered, 1 = below viewport
    final normalizedOffset = (difference / screenHeight).clamp(-1.5, 1.5);

    // Calculate transformations based on scroll position
    final opacity = _calculateOpacity(normalizedOffset);
    final scale = _calculateScale(normalizedOffset);
    final translateY = _calculateTranslateY(normalizedOffset, screenHeight);

    return Transform.translate(
      offset: Offset(0, translateY),
      child: Transform.scale(
        scale: scale,
        child: Opacity(opacity: opacity, child: child),
      ),
    );
  }

  /// Calculate opacity based on scroll position
  /// Full opacity when centered, fade out when scrolling away
  double _calculateOpacity(double normalizedOffset) {
    final absOffset = normalizedOffset.abs();
    if (absOffset < 0.3) {
      return 1.0;
    } else if (absOffset < 1.0) {
      return 1.0 - ((absOffset - 0.3) / 0.7) * 0.5;
    }
    return 0.5;
  }

  /// Calculate scale based on scroll position
  /// Slightly smaller when not centered for depth effect
  double _calculateScale(double normalizedOffset) {
    final absOffset = normalizedOffset.abs();
    if (absOffset < 0.1) {
      return 1.0;
    } else if (absOffset < 1.0) {
      return 1.0 - (absOffset * 0.05);
    }
    return 0.95;
  }

  /// Calculate vertical translation for parallax effect
  double _calculateTranslateY(double normalizedOffset, double screenHeight) {
    // Slight parallax effect
    return normalizedOffset * 20;
  }
}

/// Premium Page View Physics
/// Smooth, snappy scrolling with professional feel
class SnapPageScrollPhysics extends ScrollPhysics {
  const SnapPageScrollPhysics({super.parent});

  @override
  SnapPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SnapPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring =>
      const SpringDescription(mass: 50, stiffness: 120, damping: 1.2);

  @override
  double get dragStartDistanceMotionThreshold => 3.5;
}

/// Premium Page Controller Wrapper
/// Handles smooth transitions with haptic feedback
class PremiumFeedController {
  late PageController pageController;
  int _currentPage = 0;

  PremiumFeedController({int initialPage = 0}) {
    _currentPage = initialPage;
    pageController = PageController(
      initialPage: initialPage,
      viewportFraction: 1.0,
    );
  }

  int get currentPage => _currentPage;

  void onPageChanged(int page) {
    if (page != _currentPage) {
      _currentPage = page;
      // Haptic feedback on page change
      HapticFeedback.selectionClick();
    }
  }

  void dispose() {
    pageController.dispose();
  }
}

/// Animated Page Indicator
/// Shows current position in feed with smooth animation
class FeedPageIndicator extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final Color activeColor;
  final Color inactiveColor;

  const FeedPageIndicator({
    super.key,
    required this.currentPage,
    required this.totalPages,
    this.activeColor = Colors.white,
    this.inactiveColor = Colors.white30,
  });

  @override
  Widget build(BuildContext context) {
    // Only show indicator if more than 1 page and less than 20 pages
    if (totalPages <= 1 || totalPages > 20) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        totalPages.clamp(0, 10), // Max 10 dots shown
        (index) {
          final isActive = index == currentPage.clamp(0, 9);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: isActive ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? activeColor : inactiveColor,
              borderRadius: BorderRadius.circular(3),
            ),
          );
        },
      ),
    );
  }
}
