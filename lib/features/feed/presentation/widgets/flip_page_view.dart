import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../../../../shared/models/post.dart';

/// Parallax layer configuration for depth effect during flip
class ParallaxLayer {
  final double parallaxFactor;
  final Widget child;
  final bool applyOpacity;

  const ParallaxLayer({
    required this.parallaxFactor,
    required this.child,
    this.applyOpacity = true,
  });
}

/// FlipPageView Widget - Enhanced with Parallax Layers and Velocity-Based Animation
///
/// Core widget implementing the 3D page-flip animation effect with:
/// - Parallax layer depth effect (different layers move at different speeds)
/// - Velocity-based animation timing
/// - Spring physics for snap-back
/// - Intensity-based haptic feedback
class FlipPageView extends StatelessWidget {
  final Post currentPost;
  final Post? nextPost;
  final Post? previousPost;
  final double dragProgress;
  final Widget Function(Post post) cardBuilder;

  /// Velocity of the drag gesture (for animation duration calculation)
  final double? dragVelocity;

  const FlipPageView({
    super.key,
    required this.currentPost,
    this.nextPost,
    this.previousPost,
    required this.dragProgress,
    required this.cardBuilder,
    this.dragVelocity,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final width = constraints.maxWidth;
        final halfHeight = height / 2;

        // Normalize progress values
        final upProgress = dragProgress.clamp(0.0, 1.0);
        final downProgress = (-dragProgress).clamp(0.0, 1.0);
        final easedUpProgress = Curves.easeOutCubic.transform(upProgress);
        final easedDownProgress = Curves.easeOutCubic.transform(downProgress);
        final revealNextOpacity = ((upProgress - 0.02) / 0.7).clamp(0.0, 1.0);
        final revealPrevOpacity = ((downProgress - 0.02) / 0.7).clamp(0.0, 1.0);

        return ClipRRect(
          borderRadius: BorderRadius.circular(0),
          child: Stack(
            children: [
              // ========== IDLE STATE (no swiping) ==========
              if (dragProgress == 0)
                Positioned.fill(
                  child: RepaintBoundary(child: cardBuilder(currentPost)),
                ),

              // ========== SWIPE UP (go to next) ==========
              if (dragProgress > 0) ...[
                // 1. Next card underneath (bottom half visible initially)
                if (nextPost != null)
                  Positioned(
                    top: halfHeight,
                    left: 0,
                    right: 0,
                    height: halfHeight,
                    child: Opacity(
                      opacity: revealNextOpacity,
                      child: _buildParallaxCardHalf(
                        post: nextPost!,
                        isTopHalf: false,
                        cardHeight: height,
                        cardWidth: width,
                        progress: upProgress,
                        isUnderneath: true,
                      ),
                    ),
                  ),

                // 2. Current card - TOP half with parallax effect
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: halfHeight,
                  child: Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.identity()
                      ..scaleByDouble(
                        1.0 - easedUpProgress * 0.015,
                        1.0 - easedUpProgress * 0.015,
                        1.0,
                        1.0,
                      ),
                    child: _buildParallaxCardHalf(
                      post: currentPost,
                      isTopHalf: true,
                      cardHeight: height,
                      cardWidth: width,
                      progress: easedUpProgress,
                      isUnderneath: false,
                    ),
                  ),
                ),

                // 4. Current card - BOTTOM half flips up
                Positioned(
                  top: halfHeight,
                  left: 0,
                  right: 0,
                  height: halfHeight,
                  child: Transform(
                    alignment: Alignment.topCenter,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0008)
                      ..rotateX(-easedUpProgress * math.pi / 2),
                    child: _buildParallaxCardHalf(
                      post: currentPost,
                      isTopHalf: false,
                      cardHeight: height,
                      cardWidth: width,
                      progress: easedUpProgress,
                      isUnderneath: false,
                    ),
                  ),
                ),
              ],

              // ========== SWIPE DOWN (go to previous) ==========
              if (dragProgress < 0) ...[
                // 1. Previous card underneath (top half visible initially)
                if (previousPost != null)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: halfHeight,
                    child: Opacity(
                      opacity: revealPrevOpacity,
                      child: _buildParallaxCardHalf(
                        post: previousPost!,
                        isTopHalf: true,
                        cardHeight: height,
                        cardWidth: width,
                        progress: downProgress,
                        isUnderneath: true,
                      ),
                    ),
                  ),

                // 2. Current card - BOTTOM half with parallax effect
                Positioned(
                  top: halfHeight,
                  left: 0,
                  right: 0,
                  height: halfHeight,
                  child: Transform(
                    alignment: Alignment.topCenter,
                    transform: Matrix4.identity()
                      ..scaleByDouble(
                        1.0 - easedDownProgress * 0.015,
                        1.0 - easedDownProgress * 0.015,
                        1.0,
                        1.0,
                      ),
                    child: _buildParallaxCardHalf(
                      post: currentPost,
                      isTopHalf: false,
                      cardHeight: height,
                      cardWidth: width,
                      progress: easedDownProgress,
                      isUnderneath: false,
                    ),
                  ),
                ),

                // 4. Current card - TOP half flips down
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: halfHeight,
                  child: Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0008)
                      ..rotateX(easedDownProgress * math.pi / 2),
                    child: _buildParallaxCardHalf(
                      post: currentPost,
                      isTopHalf: true,
                      cardHeight: height,
                      cardWidth: width,
                      progress: easedDownProgress,
                      isUnderneath: false,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Build a clipped half of the card with parallax layer support
  Widget _buildParallaxCardHalf({
    required Post post,
    required bool isTopHalf,
    required double cardHeight,
    required double cardWidth,
    required double progress,
    required bool isUnderneath,
  }) {
    final halfHeight = cardHeight / 2;

    return ClipRect(
      child: SizedBox(
        height: halfHeight,
        width: cardWidth,
        child: OverflowBox(
          alignment: isTopHalf ? Alignment.topCenter : Alignment.bottomCenter,
          maxHeight: cardHeight,
          minHeight: cardHeight,
          child: RepaintBoundary(
            child: Stack(
              children: [
                // Main card content
                cardBuilder(post),

                // Intentionally minimal layering in flip halves for smoother rendering.
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Velocity analyzer for animation timing
class VelocityAnalyzer {
  /// Calculate animation duration based on gesture velocity
  /// Slow drag: 400-500ms
  /// Medium drag: 250-300ms
  /// Fast flick: 100-150ms
  static Duration calculateAnimationDuration(
    double velocity,
    double screenHeight,
  ) {
    // Normalize velocity (0.0 to 1.0 based on screen height)
    final normalizedVelocity = (velocity.abs() / screenHeight).clamp(0.0, 1.0);

    // Map to duration: 320ms at slow, 180ms at fast for smoother completion.
    final durationMs = (320 - (normalizedVelocity * 140)).toInt();

    return Duration(milliseconds: durationMs.clamp(180, 320));
  }

  /// Determine the animation curve based on gesture velocity
  /// Slow drag: smoother curve (easeOutCubic)
  /// Fast flick: snappy curve (easeOutQuart)
  static Curve calculateAnimationCurve(double velocity, double screenHeight) {
    final normalizedVelocity = (velocity.abs() / screenHeight).clamp(0.0, 1.0);

    if (normalizedVelocity < 0.7) {
      return Curves.easeOutCubic;
    }
    return const Cubic(0.2, 0.8, 0.2, 1.0);
  }

  /// Calculate spring snap-back curve
  static Curve get springSnapBackCurve => Curves.elasticOut;

  /// Get haptic feedback intensity based on velocity
  static void triggerHapticFeedback(
    double velocity,
    double screenHeight, {
    double previousProgress = 0.0,
    double currentProgress = 0.0,
  }) {
    final normalizedVelocity = (velocity.abs() / screenHeight).clamp(0.0, 1.0);

    // Determine intensity
    if (normalizedVelocity > 0.7) {
      HapticFeedback.heavyImpact();
    } else if (normalizedVelocity > 0.4) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    // Add "flip point" haptic when passing 50% progress
    if (previousProgress < 0.5 && currentProgress >= 0.5) {
      HapticFeedback.selectionClick();
    } else if (previousProgress > -0.5 && currentProgress <= -0.5) {
      HapticFeedback.selectionClick();
    }
  }
}
