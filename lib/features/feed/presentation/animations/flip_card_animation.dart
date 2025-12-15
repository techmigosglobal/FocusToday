import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Flip Card Animation Controller
/// Provides smooth 3D flip animation for vertical content cards
class FlipCardAnimation extends StatefulWidget {
  final Widget child;
  final int index;
  final double scrollOffset;
  
  const FlipCardAnimation({
    super.key,
    required this.child,
    required this.index,
    required this.scrollOffset,
  });

  @override
  State<FlipCardAnimation> createState() => _FlipCardAnimationState();
}

class _FlipCardAnimationState extends State<FlipCardAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(FlipCardAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.scrollOffset != oldWidget.scrollOffset) {
      final progress = _calculateProgress();
      _controller.animateTo(progress, duration: const Duration(milliseconds: 100));
    }
  }

  double _calculateProgress() {
    // Calculate how close this card is to being centered
    final screenHeight = MediaQuery.of(context).size.height;
    final cardOffset = widget.index * screenHeight - widget.scrollOffset;
    final centerOffset = cardOffset.abs() / screenHeight;
    
    // Return 0 when centered, 1 when far away
    return (centerOffset * 2).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final progress = _animation.value;
        final rotationAngle = progress * (math.pi / 12); // Max 15 degrees
        
        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // Perspective
            ..rotateX(rotationAngle),
          alignment: Alignment.center,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Custom Page View Physics for Snap Effect
class SnapPageScrollPhysics extends ScrollPhysics {
  const SnapPageScrollPhysics({super.parent});

  @override
  SnapPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SnapPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 80,
        stiffness: 100,
        damping: 1,
      );
}
